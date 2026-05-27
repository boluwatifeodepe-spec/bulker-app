#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../mobile"

BACKEND_URL="${BACKEND_URL:-http://127.0.0.1:5000}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed or not on PATH."
  echo "Install it from https://docs.flutter.dev/get-started/install/macos"
  exit 1
fi

if [ ! -d android ] || [ ! -d ios ]; then
  android_firebase_file=""
  ios_firebase_file=""
  if [ -f android/app/google-services.json ]; then
    android_firebase_file="$(mktemp)"
    cp android/app/google-services.json "$android_firebase_file"
  fi
  if [ -f ios/Runner/GoogleService-Info.plist ]; then
    ios_firebase_file="$(mktemp)"
    cp ios/Runner/GoogleService-Info.plist "$ios_firebase_file"
  fi
  flutter create . --platforms android,ios
  if [ -n "$android_firebase_file" ]; then
    mkdir -p android/app
    cp "$android_firebase_file" android/app/google-services.json
  fi
  if [ -n "$ios_firebase_file" ]; then
    mkdir -p ios/Runner
    cp "$ios_firebase_file" ios/Runner/GoogleService-Info.plist
  fi
fi

flutter pub get
flutter run --dart-define=BACKEND_URL="$BACKEND_URL"
