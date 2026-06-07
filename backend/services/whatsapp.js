const fs = require('fs');
const path = require('path');
const { Client, LocalAuth, MessageMedia } = require('whatsapp-web.js');

let client;
let ioRef;
let ready = false;
let initializing = false;
let initPromise;
let initError;
const readyWaiters = [];
const loginWaiters = [];
const qrWaiters = [];
const ackWaiters = new Map();
let loginAvailable = false;
let latestQr = null;
let latestQrAt = null;

function timeoutError(message) {
  const error = new Error(message);
  error.code = 'WHATSAPP_TIMEOUT';
  return error;
}

function isProtocolTimeout(error) {
  const message = error?.message || '';
  return message.includes('Runtime.callFunctionOn timed out') ||
    message.includes('Protocol error') ||
    error?.code === 'WHATSAPP_TIMEOUT';
}

function isDetachedFrameError(error) {
  const message = error?.message || '';
  return message.includes('detached Frame') ||
    message.includes('Execution context was destroyed') ||
    message.includes('Cannot find context with specified id');
}

function isBrowserAlreadyRunningError(error) {
  return (error?.message || '').includes('The browser is already running for');
}

function withTimeout(promise, timeoutMs, message) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(timeoutError(message)), timeoutMs);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

function settleReadyWaiters(error) {
  while (readyWaiters.length) {
    const waiter = readyWaiters.shift();
    if (error) {
      waiter.reject(error);
    } else {
      waiter.resolve();
    }
  }
}

function settleLoginWaiters(error) {
  while (loginWaiters.length) {
    const waiter = loginWaiters.shift();
    if (error) {
      waiter.reject(error);
    } else {
      waiter.resolve();
    }
  }
}

function settleQrWaiters(error) {
  while (qrWaiters.length) {
    const waiter = qrWaiters.shift();
    if (error) {
      waiter.reject(error);
    } else {
      waiter.resolve(latestQr);
    }
  }
}

function initWhatsApp(io) {
  ioRef = io || ioRef;
  if (client || initializing) return client;
  initializing = true;
  initError = null;

  client = new Client({
    authStrategy: new LocalAuth({ clientId: 'bulker' }),
    puppeteer: {
      headless: true,
      executablePath:
        process.env.PUPPETEER_EXECUTABLE_PATH ||
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-extensions',
        '--disable-gpu',
        '--disable-background-timer-throttling',
        '--disable-backgrounding-occluded-windows',
      ],
      protocolTimeout: Number(process.env.WHATSAPP_PROTOCOL_TIMEOUT_MS || 180000),
    },
    authTimeoutMs: Number(process.env.WHATSAPP_AUTH_TIMEOUT_MS || 180000),
    takeoverOnConflict: true,
    takeoverTimeoutMs: 0,
  });

  client.on('ready', () => {
    ready = true;
    initializing = false;
    loginAvailable = false;
    latestQr = null;
    latestQrAt = null;
    ioRef?.emit('whatsapp:status', {
      message: 'STATUS: WHATSAPP CONNECTED',
      connected: true,
    });
    settleReadyWaiters();
  });

  client.on('authenticated', () => {
    loginAvailable = false;
    ioRef?.emit('whatsapp:status', {
      message: 'STATUS: WHATSAPP AUTHENTICATED',
    });
  });

  client.on('loading_screen', () => {
    loginAvailable = true;
    ioRef?.emit('whatsapp:status', {
      message: 'STATUS: WHATSAPP LOGIN SCREEN OPENING',
    });
    settleLoginWaiters();
  });

  client.on('qr', (qr) => {
    loginAvailable = true;
    latestQr = qr;
    latestQrAt = new Date().toISOString();
    ioRef?.emit('whatsapp:status', {
      message: 'STATUS: READY FOR QR CODE OR PAIRING CODE',
      qrAvailable: true,
    });
    settleLoginWaiters();
    settleQrWaiters();
  });

  client.on('auth_failure', (message) => {
    ready = false;
    initializing = false;
    loginAvailable = false;
    initError = new Error(`WhatsApp authentication failed: ${message}`);
    ioRef?.emit('whatsapp:status', {
      message: `STATUS: WHATSAPP AUTH FAILED (${message})`,
      connected: false,
    });
  });

  client.on('message_ack', (message, ack) => {
    const id = message?.id?.id || message?.id?._serialized;
    if (!id) return;
    const waiter = ackWaiters.get(id);
    if (!waiter) return;
    if (ack >= waiter.minimumAck) {
      clearTimeout(waiter.timer);
      ackWaiters.delete(id);
      waiter.resolve({ message, ack });
    }
  });

  client.on('disconnected', (reason) => {
    ready = false;
    initializing = false;
    loginAvailable = false;
    ioRef?.emit('whatsapp:status', {
      message: `STATUS: WHATSAPP DISCONNECTED (${reason})`,
      connected: false,
    });
    settleReadyWaiters(new Error(`WhatsApp disconnected: ${reason}`));
    settleLoginWaiters(new Error(`WhatsApp disconnected: ${reason}`));
    settleQrWaiters(new Error(`WhatsApp disconnected: ${reason}`));
  });

  initPromise = client.initialize().catch(async (error) => {
    if (isBrowserAlreadyRunningError(error)) {
      console.warn(`Stale WhatsApp browser lock detected. Clearing auth session and restarting: ${error.message}`);
      await resetWhatsAppClient({ clearAuth: true });
      initWhatsApp(ioRef);
      return;
    }
    initError = error;
    initializing = false;
    ready = false;
    loginAvailable = false;
    client = null;
    settleReadyWaiters(error);
    settleLoginWaiters(error);
    settleQrWaiters(error);
    ioRef?.emit('whatsapp:status', {
      message: `STATUS: WHATSAPP ENGINE ERROR (${error.message})`,
      connected: false,
    });
  });
  return client;
}

async function waitForQr(timeoutMs = 60000) {
  if (latestQr) return latestQr;
  if (ready) return null;
  if (!client) initWhatsApp(ioRef);
  if (initError) throw initError;

  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error('WhatsApp QR code did not appear yet. Refresh and try again.'));
    }, timeoutMs);

    qrWaiters.push({
      resolve: () => {
        clearTimeout(timer);
        resolve();
      },
      reject: (error) => {
        clearTimeout(timer);
        reject(error);
      },
    });
  });

  return latestQr;
}

async function requestQrCode({ reset = false } = {}) {
  if (ready) {
    return { connected: true, qr: null, generatedAt: null };
  }
  if (reset || initError) {
    await resetWhatsAppClient();
  }
  if (!client) initWhatsApp(ioRef);
  const qr = await waitForQr(Number(process.env.WHATSAPP_QR_TIMEOUT_MS || 90000));
  return {
    connected: false,
    qr,
    generatedAt: latestQrAt,
  };
}

async function waitForLoginAvailable(timeoutMs = 60000) {
  if (ready || loginAvailable) return;
  if (!client) initWhatsApp(ioRef);
  if (initError) throw initError;

  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error('WhatsApp pairing screen did not open. Restart the backend and try again.'));
    }, timeoutMs);

    loginWaiters.push({
      resolve: () => {
        clearTimeout(timer);
        resolve();
      },
      reject: (error) => {
        clearTimeout(timer);
        reject(error);
      },
    });
  });
}

async function waitForClientPage(timeoutMs = 90000) {
  if (!client) initWhatsApp(ioRef);
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    if (initError) throw initError;
    if (client?.pupPage) return;
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error('WhatsApp browser did not open. Restart the backend and try again.');
}

async function waitForReady(timeoutMs = 60000) {
  if (ready) return;
  if (!client) initWhatsApp(ioRef);
  if (initError) throw initError;

  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error('WhatsApp is not connected yet. Re-link your phone, then try again.'));
    }, timeoutMs);

    readyWaiters.push({
      resolve: () => {
        clearTimeout(timer);
        resolve();
      },
      reject: (error) => {
        clearTimeout(timer);
        reject(error);
      },
    });
  });
}

async function requestPairingCode(phoneNumber) {
  if (ready) {
    throw new Error('WhatsApp is already connected.');
  }
  if (initError) {
    const message = initError.message || '';
    if (message.includes('Runtime.callFunctionOn timed out') ||
      message.includes('Protocol error') ||
      isBrowserAlreadyRunningError(initError)) {
      await resetWhatsAppClient({ clearAuth: isBrowserAlreadyRunningError(initError) });
    } else {
      throw initError;
    }
  }
  const normalized = normalizePhone(phoneNumber);
  if (!normalized) {
    throw new Error('Phone number must include a country code.');
  }
  if (!client) initWhatsApp(ioRef);

  await waitForClientPage(Number(process.env.WHATSAPP_PAIRING_TIMEOUT_MS || 180000));
  await waitForLoginAvailable(45000).catch(() => {});

  const requestCode = () => withTimeout(
    client.requestPairingCode(normalized, true),
    Number(process.env.WHATSAPP_PAIRING_REQUEST_TIMEOUT_MS || 60000),
    'WhatsApp pairing code request timed out. Try again.',
  );

  try {
    return await requestCode();
  } catch (error) {
    if (!isProtocolTimeout(error)) throw error;
    await resetWhatsAppClient();
    initWhatsApp(ioRef);
    await waitForClientPage(Number(process.env.WHATSAPP_PAIRING_TIMEOUT_MS || 180000));
    await waitForLoginAvailable(45000).catch(() => {});
    return requestCode();
  }
}

async function sendMediaMessage({ phone, mediaPath, caption }) {
  await waitForReady();
  const normalized = normalizePhone(phone);
  if (!/^[1-9]\d{8,14}$/.test(normalized)) {
    const error = new Error('Invalid phone number. Use country code and no plus sign.');
    error.code = 'WHATSAPP_INVALID_NUMBER';
    throw error;
  }
  const chatId = `${normalized}@c.us`;
  const timeoutMs = Number(process.env.WHATSAPP_SEND_TIMEOUT_MS || 150000);
  let recoveredFrame = false;

  while (true) {
    try {
      await ensureWhatsAppPageReady();
      const sentMessage = await sendMessageOnce({
        chatId,
        mediaPath,
        caption,
        timeoutMs,
      });

      await waitForMessageAck(sentMessage, Number(process.env.WHATSAPP_ACK_TIMEOUT_MS || 8000)).catch((error) => {
        console.warn(`Message accepted by WhatsApp Web but ack was not observed for ${normalized}: ${error.message}`);
      });
      return sentMessage;
    } catch (error) {
      if (isDetachedFrameError(error) && !recoveredFrame) {
        recoveredFrame = true;
        console.warn(`WhatsApp Web frame detached while sending to ${normalized}. Recovering page and retrying once.`);
        await recoverWhatsAppPage();
        continue;
      }
      if (isProtocolTimeout(error)) {
        await resetWhatsAppClient();
        ioRef?.emit('whatsapp:status', {
          message: 'STATUS: WHATSAPP ENGINE RESET - RE-LINK REQUIRED',
          connected: false,
          error: error.message,
        });
        const friendly = new Error('WhatsApp engine timed out. Re-link WhatsApp, keep your phone online, then send again.');
        friendly.code = 'WHATSAPP_ENGINE_TIMEOUT';
        throw friendly;
      }
      throw error;
    }
  }
}

async function sendMessageOnce({ chatId, mediaPath, caption, timeoutMs }) {
  try {
    if (!mediaPath) {
      return await withTimeout(
        client.sendMessage(chatId, caption),
        timeoutMs,
        'WhatsApp send timed out. Re-link WhatsApp and try again.',
      );
    }
    const media = MessageMedia.fromFilePath(mediaPath);
    return await withTimeout(
      client.sendMessage(chatId, media, { caption }),
      timeoutMs,
      'WhatsApp media send timed out. Re-link WhatsApp and try again.',
    );
  } catch (error) {
    if (isProtocolTimeout(error)) {
      error.code = 'WHATSAPP_TIMEOUT';
    }
    throw error;
  }
}

async function ensureWhatsAppPageReady() {
  await waitForReady();
  if (!client?.pupPage || client.pupPage.isClosed()) {
    const error = new Error('WhatsApp browser page is not available. Re-link WhatsApp.');
    error.code = 'WHATSAPP_ENGINE_TIMEOUT';
    throw error;
  }
  const state = await client.getState().catch(() => null);
  if (state && state !== 'CONNECTED') {
    ready = false;
    const error = new Error(`WhatsApp is not ready to send. Current state: ${state}.`);
    error.code = 'WHATSAPP_NOT_READY';
    throw error;
  }
}

async function recoverWhatsAppPage() {
  if (!client?.pupPage || client.pupPage.isClosed()) {
    await resetWhatsAppClient();
    initWhatsApp(ioRef);
    await waitForReady(Number(process.env.WHATSAPP_RECOVERY_TIMEOUT_MS || 90000));
    return;
  }
  await client.pupPage.reload({ waitUntil: 'domcontentloaded', timeout: 60000 }).catch(() => {});
  await new Promise((resolve) => setTimeout(resolve, 5000));
  const state = await client.getState().catch(() => null);
  if (state === 'CONNECTED') {
    ready = true;
    return;
  }
  const error = new Error(`WhatsApp page recovered but is not connected (${state || 'unknown'}). Re-link WhatsApp.`);
  error.code = 'WHATSAPP_NOT_READY';
  throw error;
}

function waitForMessageAck(message, timeoutMs) {
  const id = message?.id?.id || message?.id?._serialized;
  if (!id || message?.ack >= 1) return Promise.resolve(message);
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      ackWaiters.delete(id);
      const error = new Error('WhatsApp did not confirm the message was sent. Try re-linking WhatsApp.');
      error.code = 'WHATSAPP_ACK_TIMEOUT';
      reject(error);
    }, timeoutMs);
    ackWaiters.set(id, {
      minimumAck: 1,
      timer,
      resolve,
      reject,
    });
  });
}

async function getWhatsAppContacts() {
  await waitForReady();
  const byPhone = new Map();

  const addContact = (contact, fallbackName) => {
    const serialized = contact?.id?._serialized || '';
    const rawPhone = contact?.number || serialized.split('@')[0] || '';
    const phone = normalizePhone(rawPhone);
    if (!phone || phone.length < 9 || contact?.isMe) return;
    const name = contact?.name || contact?.pushname || contact?.shortName || fallbackName || phone;
    byPhone.set(phone, {
      id: serialized || phone,
      name,
      phone,
      status: 'pending',
    });
  };

  const contacts = await withTimeout(
    client.getContacts(),
    Number(process.env.WHATSAPP_CONTACTS_TIMEOUT_MS || 45000),
    'WhatsApp contacts took too long to load.',
  ).catch(() => []);
  for (const contact of contacts) {
    if (contact?.isUser) addContact(contact);
  }

  const chats = await withTimeout(
    client.getChats(),
    Number(process.env.WHATSAPP_CONTACTS_TIMEOUT_MS || 45000),
    'WhatsApp chats took too long to load.',
  ).catch(() => []);
  for (const chat of chats) {
    if (chat?.isGroup) continue;
    const contact = await chat.getContact().catch(() => null);
    addContact(contact, chat?.name);
  }

  return [...byPhone.values()].sort((a, b) => a.name.localeCompare(b.name));
}

async function resetWhatsAppClient({ clearAuth = false } = {}) {
  for (const [id, waiter] of ackWaiters.entries()) {
    clearTimeout(waiter.timer);
    waiter.reject(new Error('WhatsApp engine reset before message was confirmed.'));
    ackWaiters.delete(id);
  }
  if (client) {
    await client.destroy().catch(() => {});
  }
  client = null;
  ready = false;
  initializing = false;
  loginAvailable = false;
  latestQr = null;
  latestQrAt = null;
  initPromise = null;
  initError = null;
  if (clearAuth) {
    await clearWhatsAppAuthSession();
  }
}

async function clearWhatsAppAuthSession() {
  const root = path.resolve(process.env.WWEBJS_AUTH_DIR || '.wwebjs_auth');
  const session = path.join(root, 'session-bulker');
  await fs.promises.rm(session, { recursive: true, force: true }).catch(() => {});
}

async function disconnectWhatsApp() {
  if (!client) return false;
  await client.logout().catch(() => {});
  await client.destroy().catch(() => {});
  client = null;
  ready = false;
  initializing = false;
  loginAvailable = false;
  latestQr = null;
  latestQrAt = null;
  initPromise = null;
  initError = null;
  ioRef?.emit('whatsapp:status', {
    message: 'STATUS: WHATSAPP DISCONNECTED',
    connected: false,
  });
  return true;
}

function normalizePhone(phoneNumber) {
  return String(phoneNumber || '').replace(/\D/g, '').replace(/^0+/, '');
}

function getWhatsAppStatus() {
  if (!ready && client?.info?.wid) {
    ready = true;
  }
  return {
    initialized: Boolean(client),
    ready,
    initializing,
    loginAvailable,
    qrAvailable: Boolean(latestQr),
    qrGeneratedAt: latestQrAt,
    error: initError?.message || null,
  };
}

module.exports = {
  getWhatsAppStatus,
  disconnectWhatsApp,
  initWhatsApp,
  requestPairingCode,
  requestQrCode,
  sendMediaMessage,
  waitForReady,
  normalizePhone,
  getWhatsAppContacts,
  isProtocolTimeout,
};
