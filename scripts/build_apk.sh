#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../mobile"

BACKEND_URL="${BACKEND_URL:-}"

if [ -z "$BACKEND_URL" ]; then
  echo "Set BACKEND_URL first, for example:"
  echo "BACKEND_URL=https://your-app.railway.app ./scripts/build_apk.sh"
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed or not on PATH."
  echo "Install it from https://docs.flutter.dev/get-started/install/macos"
  exit 1
fi

if [ ! -d android ]; then
  android_firebase_file=""
  if [ -f android/app/google-services.json ]; then
    android_firebase_file="$(mktemp)"
    cp android/app/google-services.json "$android_firebase_file"
  fi
  flutter create . --platforms android,ios
  if [ -n "$android_firebase_file" ]; then
    mkdir -p android/app
    cp "$android_firebase_file" android/app/google-services.json
  fi
fi

flutter pub get
flutter build apk --release --dart-define=BACKEND_URL="$BACKEND_URL"

echo "APK created at mobile/build/app/outputs/flutter-apk/app-release.apk"
