#!/bin/bash
set -e

# Check required inputs
if [ -z "$AUTOSANA_KEY" ] || [ -z "$BUNDLE_ID" ] || [ -z "$PLATFORM" ] || [ -z "$FILENAME" ]; then
  echo "Missing required inputs."
  exit 1
fi

# Install jq
sudo apt-get update
sudo apt-get install -y jq

echo "Starting upload for $FILENAME to Autosana..."

# Step 1: Start Upload
RESPONSE=$(curl -s -X POST https://backend.autosana.ai/api/ci/start-upload \
  -H "X-API-Key: $AUTOSANA_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"bundle_id\": \"$BUNDLE_ID\", \"platform\": \"$PLATFORM\", \"filename\": \"$FILENAME\"}")

UPLOAD_URL=$(echo "$RESPONSE" | jq -r '.upload_url')
FILE_PATH=$(echo "$RESPONSE" | jq -r '.file_path')

if [ -z "$UPLOAD_URL" ] || [ "$UPLOAD_URL" == "null" ]; then
  echo "Failed to retrieve upload URL"
  exit 1
fi

# Step 2: Find APK/IPA
APK_PATH=""
for path in \
  android/app/build/outputs/apk/release/$FILENAME \
  android/app/build/outputs/flutter-apk/$FILENAME \
  build/app/outputs/flutter-apk/$FILENAME \
  build/app/outputs/apk/release/$FILENAME
do
  if [ -f "$path" ]; then
    APK_PATH="$path"
    break
  fi
done

if [ -z "$APK_PATH" ]; then
  echo "File $FILENAME not found."
  exit 1
fi

# Step 3: Upload
curl -X PUT "$UPLOAD_URL" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"$APK_PATH"

# Step 4: Confirm
curl -X POST https://backend.autosana.ai/api/ci/confirm-upload \
  -H "X-API-Key: $AUTOSANA_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"bundle_id\": \"$BUNDLE_ID\", \"platform\": \"$PLATFORM\", \"uploaded_file_path\": \"$FILE_PATH\"}"

echo "✅ Upload complete."