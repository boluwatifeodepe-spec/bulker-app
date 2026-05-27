const admin = require('firebase-admin');

function initFirebase() {
  if (admin.apps.length) return admin.firestore();

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

  if (projectId && clientEmail && privateKey) {
    admin.initializeApp({
      credential: admin.credential.cert({ projectId, clientEmail, privateKey }),
    });
    return admin.firestore();
  }

  console.warn('Firebase Admin credentials missing; Firestore writes are disabled.');
  return null;
}

function db() {
  if (!admin.apps.length) return null;
  return admin.firestore();
}

module.exports = { initFirebase, db };
