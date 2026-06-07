const express = require('express');
const {
  getWhatsAppStatus,
  getWhatsAppContacts,
  initWhatsApp,
  requestPairingCode,
  requestQrCode,
} = require('../services/whatsapp');
const { sanitizeContacts } = require('../services/messageQueue');

const router = express.Router();

router.post('/pairing-code', async (req, res) => {
  try {
    const { phoneNumber } = req.body;
    initWhatsApp(req.app.get('io'));
    const code = await requestPairingCode(phoneNumber);
    res.json({ code });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

router.get('/qr', async (req, res) => {
  try {
    initWhatsApp(req.app.get('io'));
    const data = await requestQrCode({ reset: req.query.reset === '1' });
    res.json(data);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

router.get('/qr-page', (_req, res) => {
  res.type('html').send(`<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Bulker WhatsApp QR</title>
    <style>
      body {
        margin: 0;
        min-height: 100vh;
        display: grid;
        place-items: center;
        background: #f7f8fa;
        color: #05060f;
        font-family: Inter, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      }
      main {
        width: min(94vw, 520px);
        background: white;
        border: 1px solid #dfe4ea;
        border-radius: 14px;
        padding: 24px;
        box-shadow: 0 18px 40px rgba(16, 19, 31, .08);
        text-align: center;
      }
      .brand {
        display: flex;
        align-items: center;
        gap: 10px;
        justify-content: center;
        font-size: 20px;
        font-weight: 900;
      }
      .mark {
        width: 34px;
        height: 34px;
        border-radius: 9px;
        display: grid;
        place-items: center;
        background: #25d366;
        color: white;
        font-weight: 900;
      }
      h1 { margin: 22px 0 8px; font-size: 28px; }
      p { color: #5f6673; line-height: 1.5; }
      #qrWrap {
        margin: 22px auto 14px;
        min-height: 276px;
        display: grid;
        place-items: center;
      }
      img {
        width: 276px;
        height: 276px;
        image-rendering: pixelated;
        border: 10px solid white;
        box-shadow: 0 0 0 1px #dfe4ea;
      }
      button {
        min-height: 46px;
        border: 0;
        border-radius: 8px;
        padding: 0 16px;
        background: #25d366;
        color: #10351b;
        font: inherit;
        font-weight: 900;
        cursor: pointer;
      }
      .secondary { background: #05060f; color: white; margin-left: 8px; }
      #status {
        margin-top: 14px;
        padding: 12px;
        border-radius: 8px;
        background: #f3f6f8;
        font-weight: 800;
        white-space: pre-wrap;
      }
      ol {
        margin: 20px auto 0;
        text-align: left;
        max-width: 360px;
        line-height: 1.6;
      }
    </style>
  </head>
  <body>
    <main>
      <div class="brand"><div class="mark">B</div> Bulker</div>
      <h1>Scan WhatsApp QR</h1>
      <p>Use this page to link the Railway backend to your WhatsApp account.</p>
      <div id="qrWrap">Loading QR code...</div>
      <div>
        <button onclick="loadQr(false)">Refresh QR</button>
        <button class="secondary" onclick="loadQr(true)">Restart QR</button>
      </div>
      <div id="status">Waiting...</div>
      <ol>
        <li>Open WhatsApp on your phone.</li>
        <li>Tap Menu or Settings.</li>
        <li>Tap Linked devices.</li>
        <li>Tap Link a device.</li>
        <li>Scan the QR code shown here.</li>
      </ol>
    </main>
    <script src="/socket.io/socket.io.js"></script>
    <script>
      const qrWrap = document.querySelector('#qrWrap');
      const statusBox = document.querySelector('#status');
      const qrImageUrl = (qr) => 'https://api.qrserver.com/v1/create-qr-code/?size=276x276&margin=8&data=' + encodeURIComponent(qr);

      async function loadQr(reset) {
        statusBox.textContent = reset ? 'Restarting WhatsApp QR...' : 'Loading QR...';
        qrWrap.textContent = 'Loading QR code...';
        try {
          const response = await fetch('/api/whatsapp/qr' + (reset ? '?reset=1' : ''));
          const data = await response.json();
          if (!response.ok) throw new Error(data.error || 'Could not load QR');
          if (data.connected) {
            qrWrap.textContent = 'WhatsApp is already connected.';
            statusBox.textContent = 'Connected';
            return;
          }
          if (!data.qr) {
            qrWrap.textContent = 'No QR code yet. Click Restart QR.';
            statusBox.textContent = 'Waiting for QR...';
            return;
          }
          qrWrap.innerHTML = '<img alt="WhatsApp QR code" src="' + qrImageUrl(data.qr) + '" />';
          statusBox.textContent = 'QR ready. Generated at ' + (data.generatedAt || 'now');
        } catch (error) {
          qrWrap.textContent = 'QR failed to load.';
          statusBox.textContent = error.message;
        }
      }

      const socket = io();
      socket.on('whatsapp:status', (data) => {
        statusBox.textContent = data.message || JSON.stringify(data);
        if (data.connected) qrWrap.textContent = 'WhatsApp connected.';
        if (data.qrAvailable) loadQr(false);
      });

      loadQr(false);
    </script>
  </body>
</html>`);
});

router.get('/status', (_req, res) => {
  res.json(getWhatsAppStatus());
});

router.get('/contacts', async (_req, res) => {
  try {
    const contacts = await getWhatsAppContacts();
    const { validContacts, rejected } = sanitizeContacts(contacts);
    res.json({ contacts: validContacts, rejected });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

module.exports = router;
