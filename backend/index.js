require('dotenv').config();

process.on('unhandledRejection', (error) => {
  console.error('Unhandled rejection:', error);
});

const cors = require('cors');
const express = require('express');
const http = require('http');
const path = require('path');
const { Server } = require('socket.io');

const contactsRoutes = require('./routes/contacts');
const sendRoutes = require('./routes/send');
const settingsRoutes = require('./routes/settings');
const whatsappRoutes = require('./routes/whatsapp');
const { ensureUploadDir, upload } = require('./services/uploads');
const { initFirebase } = require('./services/firebase');
const { createCampaign } = require('./services/messageQueue');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

ensureUploadDir();
initFirebase();

app.set('io', io);
app.use(cors());
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true }));
app.use('/uploads', express.static(path.resolve(process.env.UPLOAD_DIR || './uploads')));

app.get('/', (_req, res) => {
  res.type('html').send(`<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Bulker Backend</title>
    <style>
      :root {
        color-scheme: light;
        --green: #25d366;
        --ink: #10131f;
        --muted: #5f6673;
        --line: #dfe4ea;
        --bg: #f8f9fa;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        min-height: 100vh;
        display: grid;
        place-items: center;
        background: var(--bg);
        color: var(--ink);
        font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      }
      main {
        width: min(92vw, 560px);
        background: #fff;
        border: 1px solid var(--line);
        border-radius: 12px;
        padding: 28px;
        box-shadow: 0 18px 40px rgba(16, 19, 31, 0.08);
      }
      .brand {
        display: flex;
        align-items: center;
        gap: 10px;
        font-weight: 900;
        font-size: 18px;
      }
      .mark {
        width: 32px;
        height: 32px;
        display: grid;
        place-items: center;
        border-radius: 8px;
        background: var(--ink);
        color: white;
      }
      h1 {
        margin: 26px 0 8px;
        font-size: 32px;
        line-height: 1.05;
        letter-spacing: 0;
      }
      p {
        margin: 0;
        color: var(--muted);
        line-height: 1.55;
      }
      .status {
        margin-top: 24px;
        display: inline-flex;
        align-items: center;
        gap: 10px;
        padding: 10px 14px;
        border-radius: 999px;
        background: #e8f9ed;
        color: #287a35;
        font-weight: 800;
        font-size: 14px;
      }
      .dot {
        width: 9px;
        height: 9px;
        border-radius: 999px;
        background: var(--green);
      }
      .links {
        margin-top: 24px;
        display: grid;
        gap: 10px;
      }
      a {
        color: var(--ink);
        font-weight: 800;
        text-decoration: none;
        border: 1px solid var(--line);
        border-radius: 8px;
        padding: 12px 14px;
      }
      a:hover { border-color: var(--green); }
      code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
      form {
        margin-top: 24px;
        display: grid;
        gap: 10px;
        padding-top: 22px;
        border-top: 1px solid var(--line);
      }
      label {
        font-weight: 900;
        font-size: 13px;
      }
      input {
        width: 100%;
        min-height: 46px;
        border: 1px solid var(--line);
        border-radius: 8px;
        padding: 0 12px;
        font: inherit;
      }
      textarea {
        width: 100%;
        min-height: 90px;
        border: 1px solid var(--line);
        border-radius: 8px;
        padding: 12px;
        font: inherit;
        resize: vertical;
      }
      button {
        min-height: 46px;
        border: 0;
        border-radius: 8px;
        background: var(--green);
        color: #10351b;
        font: inherit;
        font-weight: 900;
        cursor: pointer;
      }
      pre {
        display: block;
        margin: 12px 0 0;
        padding: 12px;
        white-space: pre-wrap;
        border-radius: 8px;
        background: #10131f;
        color: #fff;
        font-size: 13px;
      }
      .step {
        margin-top: 24px;
        padding: 12px 14px;
        border-radius: 8px;
        background: #f3f6f8;
        color: var(--ink);
        font-weight: 900;
      }
    </style>
  </head>
  <body>
    <main>
      <div class="brand"><div class="mark">⌗</div> Bulker</div>
      <h1>Backend is running</h1>
      <p>This is the local Node.js + Express server for the Bulker Flutter app. Keep this server open while testing the mobile app.</p>
      <div class="status"><span class="dot"></span> Server online on port ${port}</div>
      <div class="links">
        <a href="/health">Open <code>/health</code></a>
        <a href="/api/whatsapp/status">Open <code>/api/whatsapp/status</code></a>
      </div>
      <div class="step">Step 1: Link WhatsApp</div>
      <form id="pairing-form">
        <label for="phoneNumber">Your WhatsApp number</label>
        <input id="phoneNumber" name="phoneNumber" placeholder="2348101391180" inputmode="numeric" />
        <button type="submit">Generate Pairing Code</button>
        <p>Use country code, no plus sign, no first zero. After you link, do not restart this backend before sending.</p>
        <pre id="pairing-result">WhatsApp is not linked yet.</pre>
      </form>
      <div class="step">Step 2: Send Test Batch</div>
      <form id="send-form" method="post" action="/test-send" enctype="multipart/form-data">
        <label for="testContacts">Send a small test batch</label>
        <textarea id="testContacts" name="contactsList" placeholder="2348012345678&#10;2348098765432"></textarea>
        <textarea name="caption" placeholder="Type a short test message">Bulker test message</textarea>
        <input name="media" type="file" accept="image/*,video/*" />
        <button type="submit">Send Test Batch</button>
        <p>Put one phone number per line. Test with 2 or 3 consenting numbers first. Use country code and no plus sign.</p>
        <pre id="send-result"></pre>
      </form>
    </main>
    <script>
      const pairingForm = document.querySelector('#pairing-form');
      const pairingResult = document.querySelector('#pairing-result');
      pairingForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        pairingResult.textContent = 'Generating code...';
        try {
          const response = await fetch('/api/whatsapp/pairing-code', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              phoneNumber: new FormData(pairingForm).get('phoneNumber'),
            }),
          });
          const data = await response.json();
          pairingResult.textContent = JSON.stringify(data, null, 2);
        } catch (error) {
          pairingResult.textContent = error.message;
        }
      });
      const events = document.createElement('script');
      events.src = '/socket.io/socket.io.js';
      events.onload = () => {
        const socket = io();
        const liveEvents = [];
        socket.on('campaign:progress', (data) => {
          liveEvents.unshift(data);
          sendResult.style.display = 'block';
          sendResult.textContent = JSON.stringify(liveEvents, null, 2);
        });
        socket.on('campaign:complete', (data) => {
          liveEvents.unshift(data);
          sendResult.style.display = 'block';
          sendResult.textContent = JSON.stringify(liveEvents, null, 2);
        });
        socket.on('whatsapp:status', (data) => {
          liveEvents.unshift(data);
          pairingResult.textContent = JSON.stringify(liveEvents, null, 2);
        });
      };
      document.body.appendChild(events);
      const sendForm = document.querySelector('#send-form');
      const sendResult = document.querySelector('#send-result');
      sendForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        sendResult.style.display = 'block';
        sendResult.textContent = 'Sending...';
        const body = new FormData(sendForm);
        const contactsList = String(body.get('contactsList') || '')
          .split(/\\n|,/)
          .map((phone) => phone.trim())
          .filter(Boolean);
        if (contactsList.length === 0) {
          sendResult.style.display = 'block';
          sendResult.textContent = 'Add at least one phone number in the top box.';
          return;
        }
        if (!body.get('media') || !body.get('media').name) {
          sendResult.style.display = 'block';
          sendResult.textContent = 'Choose an image or video file before sending.';
          return;
        }
        const caption = body.get('caption');
        body.delete('contactsList');
        body.delete('caption');
        body.append('caption', caption);
        body.append('mediaType', (body.get('media')?.type || '').startsWith('video/') ? 'video' : 'image');
        body.append('contacts', JSON.stringify(contactsList.map((phone, index) => ({
          name: 'Test Contact ' + (index + 1),
          phone,
          status: 'pending',
        }))));
        try {
          const response = await fetch('/api/send', { method: 'POST', body });
          const data = await response.json();
          sendResult.textContent = JSON.stringify(data, null, 2);
        } catch (error) {
          sendResult.textContent = error.message;
        }
      });
    </script>
  </body>
</html>`);
});

app.get('/health', (_req, res) => {
  res.json({ ok: true, service: 'bulker-backend' });
});

app.post('/test-send', upload.single('media'), (req, res) => {
  const contacts = String(req.body.contactsList || '')
    .split(/\n|,/)
    .map((phone) => phone.trim())
    .filter(Boolean)
    .map((phone, index) => ({
      name: `Test Contact ${index + 1}`,
      phone,
      status: 'pending',
    }));

  if (!contacts.length || !req.file) {
    return res.status(400).type('html').send(`
      <h1>Bulker test send failed</h1>
      <p>Add at least one phone number and choose an image or video.</p>
      <p><a href="/">Go back</a></p>
    `);
  }

  const campaignId = createCampaign({
    contacts,
    mediaPath: req.file.path,
    mediaType: req.file.mimetype.startsWith('video/') ? 'video' : 'image',
    caption: req.body.caption || '',
    io: req.app.get('io'),
  });

  return res.type('html').send(`
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Bulker Test Sending</title>
        <style>
          body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #f8f9fa; color: #10131f; font-family: Inter, system-ui, sans-serif; }
          main { width: min(92vw, 560px); background: #fff; border: 1px solid #dfe4ea; border-radius: 12px; padding: 28px; box-shadow: 0 18px 40px rgba(16, 19, 31, .08); }
          h1 { margin: 0 0 8px; font-size: 28px; }
          p { color: #5f6673; line-height: 1.5; }
          pre { padding: 12px; white-space: pre-wrap; border-radius: 8px; background: #10131f; color: #fff; font-size: 13px; }
          a { color: #10131f; font-weight: 800; }
        </style>
      </head>
      <body>
        <main>
          <h1>Sending started</h1>
          <p>Campaign <strong>${campaignId}</strong> has been queued. Watch this box for the live result.</p>
          <pre id="result">Waiting for WhatsApp...</pre>
          <p><a href="/">Send another test</a></p>
        </main>
        <script src="/socket.io/socket.io.js"></script>
        <script>
          const result = document.querySelector('#result');
          const socket = io();
          const events = [];
          socket.on('campaign:progress', (data) => {
            events.unshift(data);
            result.textContent = JSON.stringify(events, null, 2);
          });
          socket.on('campaign:complete', (data) => {
            events.unshift(data);
            result.textContent = JSON.stringify(events, null, 2);
          });
          socket.on('whatsapp:status', (data) => {
            result.textContent = JSON.stringify(data, null, 2);
          });
        </script>
      </body>
    </html>
  `);
});

app.use('/api/whatsapp', whatsappRoutes);
app.use('/api/contacts', contactsRoutes);
app.use('/api/send', sendRoutes);
app.use('/api/settings', settingsRoutes);

io.on('connection', (socket) => {
  socket.emit('whatsapp:status', {
    message: 'STATUS: CONNECTED TO BULKER SERVER',
  });
});

const port = Number(process.env.PORT || 5000);
server.listen(port, () => {
  console.log(`Bulker backend listening on ${port}`);
});
