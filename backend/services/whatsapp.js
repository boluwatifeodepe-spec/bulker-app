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
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    },
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

  client.on('qr', () => {
    loginAvailable = true;
    ioRef?.emit('whatsapp:status', {
      message: 'STATUS: READY FOR PAIRING CODE',
    });
    settleLoginWaiters();
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
  if (!client) initWhatsApp(ioRef);
  if (initError) {
    throw initError;
  }
  const normalized = normalizePhone(phoneNumber);
  if (!normalized) {
    throw new Error('Phone number must include a country code.');
  }
  await waitForLoginAvailable();
  return client.requestPairingCode(normalized);
}

async function sendMediaMessage({ phone, mediaPath, caption }) {
  await waitForReady();
  const chatId = `${normalizePhone(phone)}@c.us`;
  const media = MessageMedia.fromFilePath(mediaPath);
  return client.sendMessage(chatId, media, { caption });
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
};
