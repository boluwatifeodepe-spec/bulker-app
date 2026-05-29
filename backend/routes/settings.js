const express = require('express');
const { disconnectWhatsApp, getWhatsAppStatus } = require('../services/whatsapp');
const { getDailySent, safetyConfig } = require('../services/messageQueue');

const router = express.Router();

router.get('/', (_req, res) => {
  res.json({
    appName: 'Bulker',
    version: process.env.APP_VERSION || '1.0.0',
    whatsapp: getWhatsAppStatus(),
    safety: {
      ...safetyConfig(),
      sentToday: getDailySent(),
    },
    accounts: [
      {
        id: 'default',
        name: 'Primary WhatsApp',
        active: true,
        status: getWhatsAppStatus().ready ? 'connected' : 'disconnected',
      },
    ],
  });
});

router.post('/disconnect-whatsapp', async (_req, res) => {
  res.json({ ok: await disconnectWhatsApp() });
});

module.exports = router;
