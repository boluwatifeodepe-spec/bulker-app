const express = require('express');
const {
  getWhatsAppStatus,
  initWhatsApp,
  requestPairingCode,
} = require('../services/whatsapp');

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

router.get('/status', (_req, res) => {
  res.json(getWhatsAppStatus());
});

module.exports = router;
