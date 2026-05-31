const { randomUUID } = require('crypto');
const path = require('path');
const fs = require('fs');
const { db } = require('./firebase');
const { removeFile } = require('./uploads');
const { sendMediaMessage } = require('./whatsapp');

const queues = new Map();
const campaigns = new Map();
const scheduledCampaigns = new Map();
const dailyUsage = new Map();

function safetyConfig() {
  return {
    dailyLimit: Number(process.env.DAILY_SEND_LIMIT || 150),
    minDelayMs: Number(process.env.MIN_MESSAGE_DELAY_MS || process.env.MESSAGE_DELAY_MS || 30000),
    maxDelayMs: Number(process.env.MAX_MESSAGE_DELAY_MS || 90000),
    videoMinDelayMs: Number(process.env.MIN_VIDEO_DELAY_MS || process.env.VIDEO_DELAY_MS || 45000),
    videoMaxDelayMs: Number(process.env.MAX_VIDEO_DELAY_MS || 120000),
    stopAfterFailures: Number(process.env.STOP_AFTER_FAILURES || 8),
    stopFailureRate: Number(process.env.STOP_FAILURE_RATE || 0.55),
  };
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function randomDelay(minMs, maxMs) {
  const min = Math.max(0, Math.min(minMs, maxMs));
  const max = Math.max(min, maxMs);
  return Math.round(min + Math.random() * (max - min));
}

function todayKey(accountId = 'default') {
  return `${accountId}:${new Date().toISOString().slice(0, 10)}`;
}

function getDailySent(accountId = 'default') {
  return dailyUsage.get(todayKey(accountId)) || 0;
}

function incrementDailySent(accountId = 'default') {
  const key = todayKey(accountId);
  dailyUsage.set(key, (dailyUsage.get(key) || 0) + 1);
}

function normalizePhone(phone) {
  return String(phone || '').replace(/\D/g, '').replace(/^0+/, '');
}

function sanitizeContacts(contacts) {
  const seen = new Set();
  const validContacts = [];
  const rejected = [];

  for (const contact of contacts || []) {
    const phone = normalizePhone(contact.phone);
    const name = String(contact.name || 'Contact').trim() || 'Contact';
    if (!/^[1-9]\d{8,14}$/.test(phone)) {
      rejected.push({ ...contact, name, phone, reason: 'Invalid phone number' });
      continue;
    }
    if (seen.has(phone)) {
      rejected.push({ ...contact, name, phone, reason: 'Duplicate phone number' });
      continue;
    }
    seen.add(phone);
    validContacts.push({
      id: contact.id || `${Date.now()}-${validContacts.length}`,
      name,
      phone,
      status: contact.status || 'pending',
    });
  }

  return { validContacts, rejected };
}

function publicCampaign(campaign) {
  return {
    id: campaign.id,
    name: campaign.name,
    caption: campaign.caption,
    mediaType: campaign.mediaType,
    createdAt: campaign.createdAt,
    scheduledFor: campaign.scheduledFor,
    startedAt: campaign.startedAt,
    completedAt: campaign.completedAt,
    status: campaign.status,
    sent: campaign.sent,
    failed: campaign.failed,
    total: campaign.total,
    rejected: campaign.rejected,
    stoppedReason: campaign.stoppedReason,
    safety: campaign.safety,
    contacts: campaign.contacts,
  };
}

async function persistCampaign(campaign) {
  const firestore = db();
  if (!firestore) return;
  await firestore.collection('campaigns').doc(campaign.id).set(publicCampaign(campaign), {
    merge: true,
  });
}

function getCampaign(campaignId) {
  return campaigns.get(campaignId);
}

function getCampaigns() {
  return [...campaigns.values()]
    .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
    .map(publicCampaign);
}

function createCampaign({
  contacts,
  mediaPath,
  mediaType,
  caption,
  name = 'Untitled Campaign',
  scheduledFor,
  io,
}) {
  const { validContacts, rejected } = sanitizeContacts(contacts);
  const safety = safetyConfig();
  const campaignId = randomUUID();
  const campaign = {
    id: campaignId,
    name,
    caption,
    mediaPath,
    mediaType,
    createdAt: new Date().toISOString(),
    scheduledFor: scheduledFor || null,
    startedAt: null,
    completedAt: null,
    status: scheduledFor ? 'scheduled' : 'running',
    sent: 0,
    failed: 0,
    total: validContacts.length,
    rejected,
    stoppedReason: null,
    safety,
    contacts: validContacts.map((contact) => ({
      ...contact,
      status: 'pending',
      error: null,
    })),
  };
  campaigns.set(campaignId, campaign);
  persistCampaign(campaign).catch(() => {});

  if (scheduledFor) {
    const delayMs = Math.max(0, new Date(scheduledFor).getTime() - Date.now());
    const timer = setTimeout(() => {
      scheduledCampaigns.delete(campaignId);
      startQueue({ campaign, io });
    }, delayMs);
    scheduledCampaigns.set(campaignId, timer);
    return campaignId;
  }

  startQueue({ campaign, io });
  return campaignId;
}

function startQueue({ campaign, io }) {
  const queue = {
    id: campaign.id,
    cancelled: false,
    paused: false,
  };
  queues.set(campaign.id, queue);
  campaign.status = 'running';
  campaign.startedAt = campaign.startedAt || new Date().toISOString();
  persistCampaign(campaign).catch(() => {});

  runQueue({ queue, campaign, io }).finally(() => {
    if (campaign.mediaPath && (campaign.failed === 0 || campaign.status === 'cancelled')) {
      removeFile(campaign.mediaPath);
    }
  });
}

function pauseCampaign(campaignId) {
  const queue = queues.get(campaignId);
  if (!queue) return false;
  queue.paused = true;
  return true;
}

function resumeCampaign(campaignId) {
  const queue = queues.get(campaignId);
  if (!queue) return false;
  queue.paused = false;
  return true;
}

function cancelCampaign(campaignId) {
  const scheduled = scheduledCampaigns.get(campaignId);
  if (scheduled) {
    clearTimeout(scheduled);
    scheduledCampaigns.delete(campaignId);
    const campaign = campaigns.get(campaignId);
    if (campaign) {
      campaign.status = 'cancelled';
      campaign.completedAt = new Date().toISOString();
      persistCampaign(campaign).catch(() => {});
    }
    return true;
  }
  const queue = queues.get(campaignId);
  if (!queue) return false;
  queue.cancelled = true;
  return true;
}

async function retryFailedCampaign(campaignId, io) {
  const source = campaigns.get(campaignId);
  if (!source) return null;
  const failedContacts = source.contacts.filter((contact) => contact.status === 'failed');
  if (!failedContacts.length) return null;
  let retryMediaPath = null;
  if (source.mediaPath) {
    if (!fs.existsSync(source.mediaPath)) return null;
    const extension = path.extname(source.mediaPath);
    retryMediaPath = source.mediaPath.replace(extension, `-retry-${Date.now()}${extension}`);
    fs.copyFileSync(source.mediaPath, retryMediaPath);
  }

  return createCampaign({
    contacts: failedContacts.map((contact) => ({
      id: contact.id,
      name: contact.name,
      phone: contact.phone,
      status: 'pending',
    })),
    mediaPath: retryMediaPath,
    mediaType: source.mediaType,
    caption: source.caption,
    name: `${source.name} Retry`,
    io,
  });
}

async function runQueue({ queue, campaign, io }) {
  const safety = campaign.safety || safetyConfig();
  const minDelay = campaign.mediaType === 'video' ? safety.videoMinDelayMs : safety.minDelayMs;
  const maxDelay = campaign.mediaType === 'video' ? safety.videoMaxDelayMs : safety.maxDelayMs;

  for (const contact of campaign.contacts) {
    if (queue.cancelled) break;
    while (queue.paused && !queue.cancelled) {
      await wait(500);
    }
    if (queue.cancelled) break;

    try {
      io.emit('campaign:progress', {
        campaignId: queue.id,
        status: 'sending',
        contact,
        sent: campaign.sent,
        failed: campaign.failed,
        total: campaign.total,
      });

      if (getDailySent() >= safety.dailyLimit) {
        contact.status = 'failed';
        contact.error = `Daily safety limit reached (${safety.dailyLimit}).`;
        campaign.failed += 1;
        campaign.stoppedReason = contact.error;
        queue.cancelled = true;
        break;
      }

      await sendMediaMessage({
        phone: contact.phone,
        mediaPath: campaign.mediaPath,
        caption: campaign.caption,
      });
      campaign.sent += 1;
      incrementDailySent();
      contact.status = 'sent';
      contact.error = null;
      io.emit('campaign:progress', {
        campaignId: queue.id,
        status: 'sent',
        contact,
        sent: campaign.sent,
        failed: campaign.failed,
        total: campaign.total,
      });
    } catch (error) {
      campaign.failed += 1;
      contact.status = 'failed';
      contact.error = error.message;
      if (error.code === 'WHATSAPP_ENGINE_TIMEOUT') {
        campaign.stoppedReason = error.message;
        queue.cancelled = true;
      }
      console.error(`Failed to send to ${contact.phone}:`, error);
      io.emit('campaign:progress', {
        campaignId: queue.id,
        status: 'failed',
        contact,
        error: error.message,
        sent: campaign.sent,
        failed: campaign.failed,
        total: campaign.total,
      });
    }
    persistCampaign(campaign).catch(() => {});

    if (campaign.failed >= safety.stopAfterFailures) {
      const attempted = campaign.sent + campaign.failed;
      const failureRate = attempted === 0 ? 0 : campaign.failed / attempted;
      if (failureRate >= safety.stopFailureRate) {
        campaign.stoppedReason = 'Stopped because too many messages failed. Check WhatsApp connection and contact numbers.';
        queue.cancelled = true;
        break;
      }
    }

    await wait(randomDelay(minDelay, maxDelay));
  }

  campaign.status = queue.cancelled && campaign.stoppedReason ? 'stopped' : queue.cancelled ? 'cancelled' : 'complete';
  campaign.completedAt = new Date().toISOString();
  persistCampaign(campaign).catch(() => {});
  io.emit('campaign:complete', {
    campaignId: queue.id,
    sent: campaign.sent,
    failed: campaign.failed,
    total: campaign.total,
    cancelled: queue.cancelled,
  });
  queues.delete(queue.id);
}

module.exports = {
  cancelCampaign,
  createCampaign,
  getCampaign,
  getCampaigns,
  getDailySent,
  safetyConfig,
  pauseCampaign,
  retryFailedCampaign,
  resumeCampaign,
  sanitizeContacts,
};
