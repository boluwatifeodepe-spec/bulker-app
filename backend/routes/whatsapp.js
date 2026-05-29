const express = require('express');
const {
  getWhatsAppStatus,
  getWhatsAppContacts,
  initWhatsApp,
  requestPairingCode,
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
