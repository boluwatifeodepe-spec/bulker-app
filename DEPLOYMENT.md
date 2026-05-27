# Bulker Deployment Checklist

## 1. Backend on Railway

1. Push this repo to GitHub.
2. Create a Railway project from the GitHub repo.
3. Railway will use `backend/railway.json` and `backend/Dockerfile`.
4. Add environment variables:

```text
PORT=5000
UPLOAD_DIR=./uploads
MESSAGE_DELAY_MS=4000
VIDEO_DELAY_MS=7000
MAX_UPLOAD_MB=100
PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@example.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

5. Deploy and open:

```text
https://your-app.railway.app/health
```

## 2. Link WhatsApp

Open the Railway app URL and use Step 1 to generate a pairing code. Link the phone from WhatsApp Linked Devices.

Do not restart the Railway service after linking unless you are ready to relink.

## 3. Firebase

Create a Firebase project with:

- Firebase Auth enabled.
- Firestore enabled.
- Android app registered for the Flutter package name.
- iOS app registered if you plan to ship iOS.

Download:

- `google-services.json` into `mobile/android/app/google-services.json`
- `GoogleService-Info.plist` into `mobile/ios/Runner/GoogleService-Info.plist`

## 4. Build APK

Install Flutter locally, then run:

```bash
BACKEND_URL=https://your-app.railway.app ./scripts/build_apk.sh
```

APK output:

```text
mobile/build/app/outputs/flutter-apk/app-release.apk
```

## 5. First Real Test

Use only one or two consenting numbers first.

If sending fails, check:

```text
https://your-app.railway.app/api/whatsapp/status
```

`ready` must be `true` before sending.
