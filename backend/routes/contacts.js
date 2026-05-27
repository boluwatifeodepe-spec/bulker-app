const express = require('express');
const { parse } = require('csv-parse/sync');
const { upload, removeFile } = require('../services/uploads');

const router = express.Router();

router.post('/import', upload.single('file'), async (req, res) => {
  try {
    const csv = require('fs').readFileSync(req.file.path, 'utf8');
    const records = parse(csv, {
      columns: true,
      skip_empty_lines: true,
      trim: true,
    });
    res.json({
      contacts: records.map((record, index) => ({
        id: `${Date.now()}-${index}`,
        name: record.Name || record.name,
        phone: record.Phone || record.phone,
        status: 'pending',
      })),
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  } finally {
    removeFile(req.file?.path);
  }
});

module.exports = router;
