const express = require('express');
const {
  cancelCampaign,
  createCampaign,
  getCampaign,
  getCampaigns,
  pauseCampaign,
  retryFailedCampaign,
  resumeCampaign,
} = require('../services/messageQueue');
const { upload } = require('../services/uploads');

const router = express.Router();

router.post('/', upload.single('media'), (req, res) => {
  try {
    const contacts = JSON.parse(req.body.contacts || '[]');
    if (!req.file) {
      return res.status(400).json({ error: 'Media file is required.' });
    }
    if (!contacts.length) {
      return res.status(400).json({ error: 'At least one contact is required.' });
    }

    const campaignId = createCampaign({
      contacts,
      mediaPath: req.file.path,
      mediaType: req.body.mediaType,
      caption: req.body.caption || '',
      name: req.body.name || 'Untitled Campaign',
      scheduledFor: req.body.scheduledFor || null,
      io: req.app.get('io'),
    });
    return res.json({ campaignId, scheduled: Boolean(req.body.scheduledFor) });
  } catch (error) {
    return res.status(400).json({ error: error.message });
  }
});

router.get('/history', (_req, res) => {
  res.json({ campaigns: getCampaigns() });
});

router.get('/:campaignId', (req, res) => {
  const campaign = getCampaign(req.params.campaignId);
  if (!campaign) return res.status(404).json({ error: 'Campaign not found' });
  return res.json({ campaign });
});

router.post('/:campaignId/retry-failed', async (req, res) => {
  const campaignId = await retryFailedCampaign(req.params.campaignId, req.app.get('io'));
  if (!campaignId) {
    return res.status(400).json({
      error: 'No failed contacts to retry, campaign missing, or original media was deleted.',
    });
  }
  return res.json({ campaignId });
});

router.post('/:campaignId/pause', (req, res) => {
  res.json({ ok: pauseCampaign(req.params.campaignId) });
});

router.post('/:campaignId/resume', (req, res) => {
  res.json({ ok: resumeCampaign(req.params.campaignId) });
});

router.post('/:campaignId/cancel', (req, res) => {
  res.json({ ok: cancelCampaign(req.params.campaignId) });
});

module.exports = router;
