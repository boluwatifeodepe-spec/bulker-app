# Bulker

Bulker is a Flutter mobile app with a Node.js + Express backend for sending WhatsApp media campaigns to contact lists.

## What is included

- `mobile/` Flutter and Dart app source.
- `backend/` Railway-ready Express API.
- WhatsApp pairing-code flow through `whatsapp-web.js`.
- Firebase Auth and Firestore service hooks.
- Socket.IO progress updates for active campaigns.
- CSV import, manual contacts, media upload, pause, cancel, and dashboard UI.

## Mobile setup

Flutter was not available in this environment, so the Dart source and Flutter project files were created manually. On your Flutter machine, run:

```bash
./scripts/run_mobile.sh
```

Add Firebase files after creating the Firebase project:

- Android: `mobile/android/app/google-services.json`
- iOS: `mobile/ios/Runner/GoogleService-Info.plist`

The current Firebase files are configured for:

```text
Firebase project: bulker-84727
Android package: com.bulker.app
iOS bundle id: com.bulker.app
```

Run the app against a deployed backend:

```bash
BACKEND_URL=https://your-app.railway.app ./scripts/run_mobile.sh
```

For a real Android phone on the same Wi-Fi, use your Mac IP:

```bash
BACKEND_URL=http://YOUR_MAC_IP:5000 ./scripts/run_mobile.sh
```

## Generate Android APK

```bash
BACKEND_URL=https://your-app.railway.app ./scripts/build_apk.sh
```

The APK will be generated at:

```text
mobile/build/app/outputs/flutter-apk/app-release.apk
```

## Backend setup

```bash
./scripts/run_backend.sh
```

Then open:

```text
http://127.0.0.1:5000/
http://127.0.0.1:5000/health
```

If `localhost:5000` does not show in the Codex in-app browser, use `127.0.0.1:5000`.

Required Railway environment variables:

```text
PORT=5000
UPLOAD_DIR=./uploads
MESSAGE_DELAY_MS=4000
VIDEO_DELAY_MS=7000
MAX_UPLOAD_MB=100
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@example.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
```

Deploy the repo to Railway using the included `backend/Dockerfile`; it installs Chromium for `whatsapp-web.js`. Keep `npm start` as the start command.

For local Mac testing, you can override the browser path:

```bash
PUPPETEER_EXECUTABLE_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" npm start
```

## WhatsApp flow

The mobile app posts the phone number to:

```text
POST /api/whatsapp/pairing-code
```

The backend calls `client.requestPairingCode(phoneNumber)` from `whatsapp-web.js`. The user then opens WhatsApp on the same phone, goes to Linked Devices, chooses phone-number linking, and enters the code.
