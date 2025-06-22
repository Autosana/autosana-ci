#!/bin/bash
set -e

# Check required inputs
if [ -z "$AUTOSANA_KEY" ] || [ -z "$BUNDLE_ID" ] || [ -z "$PLATFORM" ] || [ -z "$BUILD_PATH" ]; then
  echo "Missing required inputs."
  exit 1
fi

# Install jq
sudo apt-get update
sudo apt-get install -y jq

# Extract filename from build path for API calls
FILENAME=$(basename "$BUILD_PATH")
echo "Starting upload for $FILENAME (from $BUILD_PATH) to Autosana..."

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

# Step 2: Verify build file exists
if [ ! -f "$BUILD_PATH" ]; then
  echo "Build file not found at: $BUILD_PATH"
  exit 1
fi

APK_PATH="$BUILD_PATH"
echo "Found build file at: $APK_PATH"

# Step 3: Upload
echo "Uploading $APK_PATH..."
UPLOAD_RESPONSE=$(curl -s -X PUT "$UPLOAD_URL" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"$APK_PATH")

echo "Upload response: $UPLOAD_RESPONSE"

# Step 4: Confirm
echo "Confirming upload..."
CONFIRM_RESPONSE=$(curl -s -X POST https://backend.autosana.ai/api/ci/confirm-upload \
  -H "X-API-Key: $AUTOSANA_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"bundle_id\": \"$BUNDLE_ID\", \"platform\": \"$PLATFORM\", \"uploaded_file_path\": \"$FILE_PATH\"}")

echo "Confirm response: $CONFIRM_RESPONSE"

# Check if confirmation was successful
if echo "$CONFIRM_RESPONSE" | jq -e '.detail' > /dev/null 2>&1; then
  ERROR_DETAIL=$(echo "$CONFIRM_RESPONSE" | jq -r '.detail')
  echo "❌ Upload failed: $ERROR_DETAIL"
  exit 1
fi

echo "✅ Upload complete."