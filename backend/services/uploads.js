const fs = require('fs');
const path = require('path');
const multer = require('multer');

const uploadDir = path.resolve(process.env.UPLOAD_DIR || './uploads');

function ensureUploadDir() {
  fs.mkdirSync(uploadDir, { recursive: true });
}

function removeFile(filePath) {
  if (!filePath) return;
  fs.promises.unlink(filePath).catch(() => {});
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    ensureUploadDir();
    cb(null, uploadDir);
  },
  filename: (_req, file, cb) => {
    const safeName = file.originalname.replace(/[^a-zA-Z0-9._-]/g, '-');
    cb(null, `${Date.now()}-${safeName}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: Number(process.env.MAX_UPLOAD_MB || 100) * 1024 * 1024 },
});

module.exports = { ensureUploadDir, removeFile, upload, uploadDir };
