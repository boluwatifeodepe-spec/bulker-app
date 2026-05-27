const { randomUUID } = require('crypto');
const path = require('path');
const fs = require('fs');
const { db } = require('./firebase');
const { removeFile } = require('./uploads');
const { sendMediaMessage } = require('./whatsapp');

const queues = new Map();
const campaigns = new Map();
const scheduledCampaigns = new Map();

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
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
    total: contacts.length,
    contacts: contacts.map((contact) => ({
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
    if (campaign.failed === 0 || campaign.status === 'cancelled') {
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
  if (!source.mediaPath || !fs.existsSync(source.mediaPath)) return null;

  const extension = path.extname(source.mediaPath);
  const retryMediaPath = source.mediaPath.replace(extension, `-retry-${Date.now()}${extension}`);
  fs.copyFileSync(source.mediaPath, retryMediaPath);

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
  const delay = Number(
    campaign.mediaType === 'video'
      ? process.env.VIDEO_DELAY_MS || 7000
      : process.env.MESSAGE_DELAY_MS || 4000,
  );

  for (const contact of campaign.contacts) {
    if (queue.cancelled) break;
    while (queue.paused && !queue.cancelled) {
      await wait(500);
    }
    if (queue.cancelled) break;

    try {
      await sendMediaMessage({
        phone: contact.phone,
        mediaPath: campaign.mediaPath,
        caption: campaign.caption,
      });
      campaign.sent += 1;
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

    await wait(delay);
  }

  campaign.status = queue.cancelled ? 'cancelled' : 'complete';
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
  pauseCampaign,
  retryFailedCampaign,
  resumeCampaign,
};
