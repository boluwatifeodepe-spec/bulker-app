const { Client, LocalAuth, MessageMedia } = require('whatsapp-web.js');

let client;
let ioRef;
let ready = false;
let initializing = false;
let initPromise;
let initError;
const readyWaiters = [];
const loginWaiters = [];
let loginAvailable = false;

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
      ],
      protocolTimeout: Number(process.env.WHATSAPP_PROTOCOL_TIMEOUT_MS || 90000),
    },
    authTimeoutMs: Number(process.env.WHATSAPP_AUTH_TIMEOUT_MS || 180000),
    takeoverOnConflict: true,
    takeoverTimeoutMs: 0,
  });

  client.on('ready', () => {
    ready = true;
    initializing = false;
    ioRef?.emit('whatsapp:status', {
      message: 'STATUS: WHATSAPP CONNECTED',
      connected: true,
    });
    settleReadyWaiters();
  });

  client.on('authenticated', () => {
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

  client.on('qr', () => {
    loginAvailable = true;
    ioRef?.emit('whatsapp:status', {
      message: 'STATUS: READY FOR PAIRING CODE',
    });
    settleLoginWaiters();
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
  });

  initPromise = client.initialize().catch((error) => {
    initError = error;
    initializing = false;
    ready = false;
    loginAvailable = false;
    client = null;
    settleReadyWaiters(error);
    settleLoginWaiters(error);
    ioRef?.emit('whatsapp:status', {
      message: `STATUS: WHATSAPP ENGINE ERROR (${error.message})`,
      connected: false,
    });
  });
  return client;
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
    if (message.includes('Runtime.callFunctionOn timed out') || message.includes('Protocol error')) {
      await resetWhatsAppClient();
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
  const chatId = `${normalizePhone(phone)}@c.us`;
  const timeoutMs = Number(process.env.WHATSAPP_SEND_TIMEOUT_MS || 75000);
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

async function resetWhatsAppClient() {
  if (client) {
    await client.destroy().catch(() => {});
  }
  client = null;
  ready = false;
  initializing = false;
  loginAvailable = false;
  initPromise = null;
  initError = null;
}

async function disconnectWhatsApp() {
  if (!client) return false;
  await client.logout().catch(() => {});
  await client.destroy().catch(() => {});
  client = null;
  ready = false;
  initializing = false;
  loginAvailable = false;
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
    error: initError?.message || null,
  };
}

module.exports = {
  getWhatsAppStatus,
  disconnectWhatsApp,
  initWhatsApp,
  requestPairingCode,
  sendMediaMessage,
  waitForReady,
  normalizePhone,
  getWhatsAppContacts,
  isProtocolTimeout,
};
