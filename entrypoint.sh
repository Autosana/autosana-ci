#!/bin/bash
set -e

echo "🚀 ========================================"
echo "🚀 Autosana CI Upload Script Starting"
echo "🚀 ========================================"
echo "📅 Timestamp: $(date)"
echo "🔧 Script Version: 1.0"
echo ""

# Check required inputs
echo "🔍 Checking required environment variables..."
echo "   AUTOSANA_KEY: ${AUTOSANA_KEY:0:10}... (${#AUTOSANA_KEY} chars)"
echo "   BUNDLE_ID: $BUNDLE_ID"
echo "   PLATFORM: $PLATFORM"
echo "   BUILD_PATH: $BUILD_PATH"
echo ""

if [ -z "$AUTOSANA_KEY" ] || [ -z "$BUNDLE_ID" ] || [ -z "$PLATFORM" ] || [ -z "$BUILD_PATH" ]; then
  echo "❌ ERROR: Missing required inputs."
  echo "   Required variables:"
  echo "   - AUTOSANA_KEY: ${AUTOSANA_KEY:+SET}${AUTOSANA_KEY:-NOT SET}"
  echo "   - BUNDLE_ID: ${BUNDLE_ID:+SET}${BUNDLE_ID:-NOT SET}"
  echo "   - PLATFORM: ${PLATFORM:+SET}${PLATFORM:-NOT SET}"
  echo "   - BUILD_PATH: ${BUILD_PATH:+SET}${BUILD_PATH:-NOT SET}"
  exit 1
fi

echo "✅ All required environment variables are set"
echo ""

# Install jq
echo "📦 Installing jq for JSON parsing..."
echo "   Current directory: $(pwd)"
echo "   Available packages: $(apt list --installed | grep jq || echo 'jq not installed')"

sudo apt-get update
sudo apt-get install -y jq

if command -v jq &> /dev/null; then
    echo "✅ jq installed successfully: $(jq --version)"
else
    echo "❌ Failed to install jq"
    exit 1
fi
echo ""

# Extract filename from build path for API calls
FILENAME=$(basename "$BUILD_PATH")
echo "📁 File Information:"
echo "   Original BUILD_PATH: $BUILD_PATH"
echo "   Extracted FILENAME: $FILENAME"
echo "   File size: $(ls -lh "$BUILD_PATH" 2>/dev/null | awk '{print $5}' || echo 'File not found')"
echo "   File permissions: $(ls -la "$BUILD_PATH" 2>/dev/null | awk '{print $1}' || echo 'File not found')"
echo ""

echo "🎯 Starting upload for $FILENAME (from $BUILD_PATH) to Autosana..."
echo ""

# Step 1: Start Upload
echo "🔄 Step 1: Starting upload process..."
echo "   API Endpoint: https://backend.autosana.ai/api/ci/start-upload"
echo "   Request Payload:"
echo "   {"
echo "     \"bundle_id\": \"$BUNDLE_ID\","
echo "     \"platform\": \"$PLATFORM\","
echo "     \"filename\": \"$FILENAME\""
echo "   }"
echo ""

RESPONSE=$(curl -s -X POST https://backend.autosana.ai/api/ci/start-upload \
  -H "X-API-Key: $AUTOSANA_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"bundle_id\": \"$BUNDLE_ID\", \"platform\": \"$PLATFORM\", \"filename\": \"$FILENAME\"}" \
  -w "\nHTTP Status: %{http_code}\nTotal Time: %{time_total}s\n")

echo "📡 API Response:"
echo "$RESPONSE"
echo ""

# Extract JSON response (everything before the first newline)
JSON_RESPONSE=$(echo "$RESPONSE" | head -n 1)
HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP Status:" | cut -d' ' -f3)
TOTAL_TIME=$(echo "$RESPONSE" | grep "Total Time:" | cut -d' ' -f3)

echo "🔍 Parsed response:"
echo "   JSON Response: $JSON_RESPONSE"
echo "   HTTP Status: $HTTP_STATUS"
echo "   Total Time: ${TOTAL_TIME}s"
echo ""

UPLOAD_URL=$(echo "$JSON_RESPONSE" | jq -r '.upload_url')
FILE_PATH=$(echo "$JSON_RESPONSE" | jq -r '.file_path')

echo "🔍 Extracted values:"
echo "   UPLOAD_URL: $UPLOAD_URL"
echo "   FILE_PATH: $FILE_PATH"
echo ""

if [ -z "$UPLOAD_URL" ] || [ "$UPLOAD_URL" == "null" ]; then
  echo "❌ ERROR: Failed to retrieve upload URL"
  echo "   Response parsing failed or upload_url is null"
  echo "   Full response was: $RESPONSE"
  exit 1
fi

echo "✅ Upload URL retrieved successfully"
echo ""

# Step 2: Verify build file exists
echo "🔄 Step 2: Verifying build file..."
echo "   Checking file: $BUILD_PATH"
echo "   File exists: $([ -f "$BUILD_PATH" ] && echo 'YES' || echo 'NO')"
echo "   File readable: $([ -r "$BUILD_PATH" ] && echo 'YES' || echo 'NO')"
echo "   File size: $(ls -lh "$BUILD_PATH" 2>/dev/null | awk '{print $5}' || echo 'N/A')"
echo ""

if [ ! -f "$BUILD_PATH" ]; then
  echo "❌ ERROR: Build file not found at: $BUILD_PATH"
  echo "   Current directory: $(pwd)"
  echo "   Directory contents:"
  ls -la "$(dirname "$BUILD_PATH")" 2>/dev/null || echo "   Cannot list directory"
  exit 1
fi

APK_PATH="$BUILD_PATH"
echo "✅ Found build file at: $APK_PATH"
echo "   File details: $(file "$APK_PATH")"
echo ""

# Step 3: Upload
echo "🔄 Step 3: Uploading file..."
echo "   Source: $APK_PATH"
echo "   Destination: $UPLOAD_URL"
echo "   File size: $(ls -lh "$APK_PATH" | awk '{print $5}')"
echo "   Starting upload at: $(date)"
echo ""

UPLOAD_START_TIME=$(date +%s)
UPLOAD_RESPONSE=$(curl -s -X PUT "$UPLOAD_URL" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"$APK_PATH" \
  -w "\nHTTP Status: %{http_code}\nTotal Time: %{time_total}s\nUpload Speed: %{speed_upload} bytes/sec\n")
UPLOAD_END_TIME=$(date +%s)
UPLOAD_DURATION=$((UPLOAD_END_TIME - UPLOAD_START_TIME))

echo "📤 Upload completed at: $(date)"
echo "   Duration: ${UPLOAD_DURATION} seconds"
echo "   Upload response: $UPLOAD_RESPONSE"
echo ""

# Check upload response for errors
if echo "$UPLOAD_RESPONSE" | grep -q "HTTP Status: [45]"; then
    echo "❌ ERROR: Upload failed with HTTP error"
    echo "   Full response: $UPLOAD_RESPONSE"
    exit 1
fi

echo "✅ File upload completed successfully"
echo ""

# Step 4: Confirm
echo "🔄 Step 4: Confirming upload..."
echo "   API Endpoint: https://backend.autosana.ai/api/ci/confirm-upload"
echo "   Request Payload:"
echo "   {"
echo "     \"bundle_id\": \"$BUNDLE_ID\","
echo "     \"platform\": \"$PLATFORM\","
echo "     \"uploaded_file_path\": \"$FILE_PATH\""
echo "   }"
echo ""

CONFIRM_START_TIME=$(date +%s)
CONFIRM_RESPONSE=$(curl -s -X POST https://backend.autosana.ai/api/ci/confirm-upload \
  -H "X-API-Key: $AUTOSANA_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"bundle_id\": \"$BUNDLE_ID\", \"platform\": \"$PLATFORM\", \"uploaded_file_path\": \"$FILE_PATH\"}" \
  -w "\nHTTP Status: %{http_code}\nTotal Time: %{time_total}s\n")
CONFIRM_END_TIME=$(date +%s)
CONFIRM_DURATION=$((CONFIRM_END_TIME - CONFIRM_START_TIME))

echo "📡 Confirm response received at: $(date)"
echo "   Duration: ${CONFIRM_DURATION} seconds"
echo "   Response: $CONFIRM_RESPONSE"
echo ""

# Extract JSON response for confirmation
CONFIRM_JSON_RESPONSE=$(echo "$CONFIRM_RESPONSE" | head -n 1)
CONFIRM_HTTP_STATUS=$(echo "$CONFIRM_RESPONSE" | grep "HTTP Status:" | cut -d' ' -f3)

echo "🔍 Parsed confirm response:"
echo "   JSON Response: $CONFIRM_JSON_RESPONSE"
echo "   HTTP Status: $CONFIRM_HTTP_STATUS"
echo ""

# Check if confirmation was successful
if echo "$CONFIRM_JSON_RESPONSE" | jq -e '.detail' > /dev/null 2>&1; then
  ERROR_DETAIL=$(echo "$CONFIRM_JSON_RESPONSE" | jq -r '.detail')
  echo "❌ ERROR: Upload confirmation failed"
  echo "   Error detail: $ERROR_DETAIL"
  echo "   Full response: $CONFIRM_RESPONSE"
  echo "   HTTP Status: $CONFIRM_HTTP_STATUS"
  exit 1
fi

# Final success message
echo "🎉 ========================================"
echo "🎉 Upload completed successfully!"
echo "🎉 ========================================"
echo "📊 Summary:"
echo "   Bundle ID: $BUNDLE_ID"
echo "   Platform: $PLATFORM"
echo "   File: $FILENAME"
echo "   File Path: $FILE_PATH"
echo "   Total time: $((UPLOAD_DURATION + CONFIRM_DURATION)) seconds"
echo "   Completed at: $(date)"
echo ""

echo "✅ Upload complete."