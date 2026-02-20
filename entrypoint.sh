#!/bin/bash
set -e

echo "🚀 ========================================"
echo "🚀 Autosana CI Upload Script Starting"
echo "🚀 ========================================"
echo "📅 Timestamp: $(date)"
echo "🔧 Script Version: 3.1"
echo ""

# API Base URL - can be overridden for testing (staging, ngrok, etc.)
# Default: production
API_BASE_URL="${AUTOSANA_API_URL:-https://backend.autosana.ai}"
echo "🌐 API Base URL: $API_BASE_URL"
echo "🎯 Platform: $PLATFORM"
echo ""

# Check common required inputs
if [ -z "$AUTOSANA_KEY" ] || [ -z "$PLATFORM" ]; then
  echo "❌ ERROR: Missing required inputs."
  echo "   - AUTOSANA_KEY: ${AUTOSANA_KEY:+SET}${AUTOSANA_KEY:-NOT SET}"
  echo "   - PLATFORM: ${PLATFORM:+SET}${PLATFORM:-NOT SET}"
  exit 1
fi

# Validate platform and check platform-specific inputs
if [ "$PLATFORM" = "web" ]; then
  echo "🌐 Web platform detected"
  echo "🔍 Checking web-specific environment variables..."
  echo "   AUTOSANA_KEY: ${AUTOSANA_KEY:0:10}... (${#AUTOSANA_KEY} chars)"
  echo "   APP_ID: $APP_ID"
  echo "   URL: $URL"
  echo "   APP_NAME: ${APP_NAME:-<not set>}"
  echo ""

  if [ -z "$APP_ID" ] || [ -z "$URL" ]; then
    echo "❌ ERROR: Missing required inputs for web platform."
    echo "   Required variables:"
    echo "   - AUTOSANA_KEY: ${AUTOSANA_KEY:+SET}${AUTOSANA_KEY:-NOT SET}"
    echo "   - APP_ID: ${APP_ID:+SET}${APP_ID:-NOT SET}"
    echo "   - URL: ${URL:+SET}${URL:-NOT SET}"
    exit 1
  fi

  # Validate app-id format: lowercase alphanumeric with hyphens only
  if ! echo "$APP_ID" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
    echo "❌ ERROR: Invalid app-id format."
    echo "   app-id must be lowercase alphanumeric with hyphens only."
    echo "   Examples: 'my-web-app', 'staging', 'preview-app-123'"
    echo "   Invalid: 'My-App', 'my_app', 'my app'"
    echo "   Provided: '$APP_ID'"
    exit 1
  fi

  # Validate URL format
  if ! echo "$URL" | grep -qE '^https?://'; then
    echo "❌ ERROR: Invalid URL format."
    echo "   URL must start with http:// or https://"
    echo "   Provided: '$URL'"
    exit 1
  fi
elif [ "$PLATFORM" = "android" ] || [ "$PLATFORM" = "ios" ]; then
  echo "📱 Mobile platform detected: $PLATFORM"
  echo "🔍 Checking mobile-specific environment variables..."
  echo "   AUTOSANA_KEY: ${AUTOSANA_KEY:0:10}... (${#AUTOSANA_KEY} chars)"
  echo "   BUNDLE_ID: $BUNDLE_ID"
  echo "   PLATFORM: $PLATFORM"
  echo "   BUILD_PATH: $BUILD_PATH"
  echo "   APP_NAME: ${APP_NAME:-<not set>}"
  echo ""

  if [ -z "$BUNDLE_ID" ] || [ -z "$BUILD_PATH" ]; then
    echo "❌ ERROR: Missing required inputs for mobile platform."
    echo "   Required variables:"
    echo "   - AUTOSANA_KEY: ${AUTOSANA_KEY:+SET}${AUTOSANA_KEY:-NOT SET}"
    echo "   - BUNDLE_ID: ${BUNDLE_ID:+SET}${BUNDLE_ID:-NOT SET}"
    echo "   - PLATFORM: ${PLATFORM:+SET}${PLATFORM:-NOT SET}"
    echo "   - BUILD_PATH: ${BUILD_PATH:+SET}${BUILD_PATH:-NOT SET}"
    exit 1
  fi
else
  echo "❌ ERROR: Invalid platform '$PLATFORM'. Must be 'android', 'ios', or 'web'."
  exit 1
fi

echo "✅ All required environment variables are set"
echo ""

# Install jq
echo "📦 Ensuring jq is available..."
echo "   Current directory: $(pwd)"

if command -v jq >/dev/null 2>&1; then
  echo "✅ jq already installed: $(jq --version)"
else
  OS_NAME="$(uname -s)"
  echo "   jq not found. Attempting installation for OS: $OS_NAME"
  if [ "$OS_NAME" = "Darwin" ]; then
    if command -v brew >/dev/null 2>&1; then
      brew install jq
    else
      echo "❌ Homebrew not found on macOS runner; cannot install jq."
      echo "   Please install Homebrew or preinstall jq."
      exit 1
    fi
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y jq
  elif command -v apk >/dev/null 2>&1; then
    sudo apk add --no-cache jq || apk add --no-cache jq
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y jq
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y jq
  else
    echo "❌ Unsupported environment. Please install jq manually."
    exit 1
  fi

  if command -v jq >/dev/null 2>&1; then
    echo "✅ jq installed successfully: $(jq --version)"
  else
    echo "❌ Failed to install jq"
    exit 1
  fi
fi
echo ""

# Capture GitHub environment variables for PR integration
# For pull_request events, git rev-parse HEAD returns a merge commit SHA, not the PR head.
# Extract the PR head SHA from the event payload instead.
PR_HEAD_SHA=$(jq -r '.pull_request.head.sha // empty' "$GITHUB_EVENT_PATH" 2>/dev/null)
COMMIT_SHA="${PR_HEAD_SHA:-$(git rev-parse HEAD 2>/dev/null || echo "${GITHUB_SHA:-}")}"
BRANCH_NAME="${GITHUB_HEAD_REF:-$GITHUB_REF_NAME}"
REPO_FULL_NAME="${GITHUB_REPOSITORY:-}"

echo "📦 Git Metadata (for PR integration):"
echo "   COMMIT_SHA: ${COMMIT_SHA:-not set}"
echo "   BRANCH_NAME: ${BRANCH_NAME:-not set}"
echo "   REPO_FULL_NAME: ${REPO_FULL_NAME:-not set}"
echo ""

# ============================================================
# WEB PLATFORM FLOW
# ============================================================
if [ "$PLATFORM" = "web" ]; then
  echo "🌐 Starting web URL registration..."
  echo ""

  WEB_PAYLOAD=$(jq -n \
    --arg app_id "$APP_ID" \
    --arg url "$URL" \
    --arg name "$APP_NAME" \
    --arg commit_sha "$COMMIT_SHA" \
    --arg branch_name "$BRANCH_NAME" \
    --arg repo_full_name "$REPO_FULL_NAME" \
    '{app_id: $app_id, url: $url, name: $name, commit_sha: $commit_sha, branch_name: $branch_name, repo_full_name: $repo_full_name}')

  echo "🔄 Registering web build with Autosana..."
  echo "   API Endpoint: $API_BASE_URL/api/ci/upload-web-build"
  echo "   Request Payload:"
  echo "$WEB_PAYLOAD" | jq '.'
  echo ""

  RESPONSE=$(curl -s -X POST "$API_BASE_URL/api/ci/upload-web-build" \
    --connect-timeout 30 \
    --max-time 60 \
    -H "X-API-Key: $AUTOSANA_KEY" \
    -H "Content-Type: application/json" \
    -d "$WEB_PAYLOAD" \
    -w "\nHTTP Status: %{http_code}\nTotal Time: %{time_total}s\n")

  echo "📡 API Response:"
  echo "$RESPONSE"
  echo ""

  # Extract JSON response
  JSON_RESPONSE=$(echo "$RESPONSE" | head -n 1)
  HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP Status:" | cut -d' ' -f3)

  echo "🔍 Parsed response:"
  echo "   JSON Response: $JSON_RESPONSE"
  echo "   HTTP Status: $HTTP_STATUS"
  echo ""

  # Check HTTP status
  if [ "$HTTP_STATUS" != "200" ]; then
    echo "❌ ERROR: API request failed with HTTP status $HTTP_STATUS"
    echo "   Response body: $JSON_RESPONSE"
    exit 1
  fi

  # Validate JSON
  if ! echo "$JSON_RESPONSE" | jq empty 2>/dev/null; then
    echo "❌ ERROR: API returned invalid JSON"
    echo "   Response body: $JSON_RESPONSE"
    exit 1
  fi

  # Check for error detail
  if echo "$JSON_RESPONSE" | jq -e '.detail' > /dev/null 2>&1; then
    ERROR_DETAIL=$(echo "$JSON_RESPONSE" | jq -r '.detail')
    echo "❌ ERROR: Web URL registration failed"
    echo "   Error detail: $ERROR_DETAIL"
    exit 1
  fi

  # Success
  echo "🎉 ========================================"
  echo "🎉 Web URL registered successfully!"
  echo "🎉 ========================================"
  echo "📊 Summary:"
  echo "   App ID: $APP_ID"
  echo "   URL: $URL"
  echo "   Commit SHA: ${COMMIT_SHA:-not set}"
  echo "   Branch: ${BRANCH_NAME:-not set}"
  echo "   Repository: ${REPO_FULL_NAME:-not set}"
  echo "   Completed at: $(date)"
  echo ""
  echo "✅ Registration complete."
fi

# ============================================================
# MOBILE PLATFORM FLOW (android/ios)
# ============================================================
if [ "$PLATFORM" != "web" ]; then

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
echo "   API Endpoint: $API_BASE_URL/api/ci/start-upload"

START_PAYLOAD=$(jq -n \
  --arg bundle_id "$BUNDLE_ID" \
  --arg platform "$PLATFORM" \
  --arg filename "$FILENAME" \
  --arg name "$APP_NAME" \
  '{bundle_id: $bundle_id, platform: $platform, filename: $filename, name: $name}')

echo "   Request Payload:"
echo "$START_PAYLOAD" | jq '.'
echo ""

RESPONSE=$(curl -s -X POST "$API_BASE_URL/api/ci/start-upload" \
  --connect-timeout 30 \
  --max-time 60 \
  -H "X-API-Key: $AUTOSANA_KEY" \
  -H "Content-Type: application/json" \
  -d "$START_PAYLOAD" \
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

# Check HTTP status before parsing JSON
if [ "$HTTP_STATUS" != "200" ]; then
  echo "❌ ERROR: API request failed with HTTP status $HTTP_STATUS"
  echo "   Response body: $JSON_RESPONSE"
  echo "   This may indicate a server error or network issue."
  echo "   Please check the Autosana API status and try again."
  exit 1
fi

# Validate JSON before parsing
if ! echo "$JSON_RESPONSE" | jq empty 2>/dev/null; then
  echo "❌ ERROR: API returned invalid JSON"
  echo "   Response body: $JSON_RESPONSE"
  exit 1
fi

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
  --connect-timeout 30 \
  --max-time 600 \
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
echo "   API Endpoint: $API_BASE_URL/api/ci/confirm-upload"

# Build the confirm payload with git metadata for PR integration
CONFIRM_PAYLOAD=$(jq -n \
  --arg bundle_id "$BUNDLE_ID" \
  --arg platform "$PLATFORM" \
  --arg file_path "$FILE_PATH" \
  --arg name "$APP_NAME" \
  --arg commit_sha "$COMMIT_SHA" \
  --arg branch_name "$BRANCH_NAME" \
  --arg repo_full_name "$REPO_FULL_NAME" \
  '{
    bundle_id: $bundle_id,
    platform: $platform,
    uploaded_file_path: $file_path,
    name: $name,
    commit_sha: $commit_sha,
    branch_name: $branch_name,
    repo_full_name: $repo_full_name
  }')

echo "   Request Payload:"
echo "$CONFIRM_PAYLOAD" | jq '.'
echo ""

CONFIRM_START_TIME=$(date +%s)
CONFIRM_RESPONSE=$(curl -s -X POST "$API_BASE_URL/api/ci/confirm-upload" \
  --connect-timeout 30 \
  --max-time 60 \
  -H "X-API-Key: $AUTOSANA_KEY" \
  -H "Content-Type: application/json" \
  -d "$CONFIRM_PAYLOAD" \
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

# Check HTTP status before parsing JSON
if [ "$CONFIRM_HTTP_STATUS" != "200" ]; then
  echo "❌ ERROR: Confirm upload API request failed with HTTP status $CONFIRM_HTTP_STATUS"
  echo "   Response body: $CONFIRM_JSON_RESPONSE"
  echo "   This may indicate a server error or network issue."
  echo "   Please check the Autosana API status and try again."
  exit 1
fi

# Validate JSON before parsing
if ! echo "$CONFIRM_JSON_RESPONSE" | jq empty 2>/dev/null; then
  echo "❌ ERROR: Confirm upload API returned invalid JSON"
  echo "   Response body: $CONFIRM_JSON_RESPONSE"
  exit 1
fi

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
echo "   Commit SHA: ${COMMIT_SHA:-not set}"
echo "   Branch: ${BRANCH_NAME:-not set}"
echo "   Repository: ${REPO_FULL_NAME:-not set}"
echo "   Total time: $((UPLOAD_DURATION + CONFIRM_DURATION)) seconds"
echo "   Completed at: $(date)"
echo ""

echo "✅ Upload complete."
fi

# ============================================================
# FLOW EXECUTION (optional — runs when suite-ids or flow-ids are provided)
# ============================================================

if [ -z "$SUITE_IDS" ] && [ -z "$FLOW_IDS" ]; then
  exit 0
fi

echo ""
echo "🔬 ========================================"
echo "🔬 Running Flows"
echo "🔬 ========================================"
echo ""

# Convert comma-separated IDs to JSON arrays (strip whitespace)
if [ -n "$FLOW_IDS" ]; then
  FLOW_IDS_JSON=$(echo "$FLOW_IDS" | tr -d ' ' | tr ',' '\n' | sed '/^$/d' | jq -R . | jq -s .)
else
  FLOW_IDS_JSON="[]"
fi

if [ -n "$SUITE_IDS" ]; then
  SUITE_IDS_JSON=$(echo "$SUITE_IDS" | tr -d ' ' | tr ',' '\n' | sed '/^$/d' | jq -R . | jq -s .)
else
  SUITE_IDS_JSON="[]"
fi

# Build the run-flows payload based on platform
if [ "$PLATFORM" = "web" ]; then
  RUN_PAYLOAD=$(jq -n \
    --arg app_id "$APP_ID" \
    --argjson flow_ids "$FLOW_IDS_JSON" \
    --argjson suite_ids "$SUITE_IDS_JSON" \
    '{app_id: $app_id, flow_ids: $flow_ids, suite_ids: $suite_ids}')
else
  RUN_PAYLOAD=$(jq -n \
    --arg bundle_id "$BUNDLE_ID" \
    --arg platform "$PLATFORM" \
    --argjson flow_ids "$FLOW_IDS_JSON" \
    --argjson suite_ids "$SUITE_IDS_JSON" \
    '{bundle_id: $bundle_id, platform: $platform, flow_ids: $flow_ids, suite_ids: $suite_ids}')
fi

echo "🔄 Triggering flows..."
echo "   API Endpoint: $API_BASE_URL/api/v1/flows/run"
echo ""

RESPONSE=$(curl -s -X POST "$API_BASE_URL/api/v1/flows/run" \
  --connect-timeout 30 \
  --max-time 60 \
  -H "X-API-Key: $AUTOSANA_KEY" \
  -H "Content-Type: application/json" \
  -d "$RUN_PAYLOAD" \
  -w "\nHTTP Status: %{http_code}\n")

JSON_RESPONSE=$(echo "$RESPONSE" | head -n 1)
HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP Status:" | cut -d' ' -f3)

if [ "$HTTP_STATUS" != "200" ]; then
  echo "❌ ERROR: Failed to trigger flows (HTTP $HTTP_STATUS)"
  echo "   Response: $JSON_RESPONSE"
  exit 1
fi

if ! echo "$JSON_RESPONSE" | jq empty 2>/dev/null; then
  echo "❌ ERROR: Invalid JSON response from run-flows"
  echo "   Response: $JSON_RESPONSE"
  exit 1
fi

BATCH_ID=$(echo "$JSON_RESPONSE" | jq -r '.batch_id')
FLOW_RUN_COUNT=$(echo "$JSON_RESPONSE" | jq -r '.flow_run_count')

if [ -z "$BATCH_ID" ] || [ "$BATCH_ID" = "null" ]; then
  echo "❌ ERROR: Failed to retrieve batch ID from response"
  echo "   Response: $JSON_RESPONSE"
  exit 1
fi

echo "✅ Triggered $FLOW_RUN_COUNT flow(s)"
echo "   Batch ID: $BATCH_ID"
echo ""
echo "⏳ Waiting for results..."
echo ""

# Polling configuration
POLL_INTERVAL=15
PRINTED_IDS_FILE=$(mktemp)
trap "rm -f $PRINTED_IDS_FILE" EXIT

while true; do
  STATUS_RESPONSE=$(curl -s -X GET "$API_BASE_URL/api/v1/runs/status?batch_id=$BATCH_ID" \
    --connect-timeout 30 \
    --max-time 30 \
    -H "X-API-Key: $AUTOSANA_KEY" || true)

  if ! echo "$STATUS_RESPONSE" | jq empty 2>/dev/null; then
    echo "   ⚠ Warning: Invalid response from status API, retrying..."
    sleep "$POLL_INTERVAL"
    continue
  fi

  # Print newly completed flows grouped by suite (streaming output)
  echo "$STATUS_RESPONSE" | jq -c '.run_groups[]' 2>/dev/null | while IFS= read -r group; do
    GROUP_NAME=$(echo "$group" | jq -r '.name')
    GROUP_STATUS=$(echo "$group" | jq -r '.status')

    echo "$group" | jq -c '.runs[]' 2>/dev/null | while IFS= read -r flow; do
      FLOW_STATUS=$(echo "$flow" | jq -r '.status')
      FLOW_ID=$(echo "$flow" | jq -r '.id')

      case "$FLOW_STATUS" in
        passed|failed|error|terminated|skipped) ;;
        *) continue ;;
      esac

      if grep -q "$FLOW_ID" "$PRINTED_IDS_FILE" 2>/dev/null; then
        continue
      fi

      # Print group header on first flow from this group
      if ! grep -q "group:$GROUP_NAME" "$PRINTED_IDS_FILE" 2>/dev/null; then
        echo "group:$GROUP_NAME" >> "$PRINTED_IDS_FILE"
        echo ""
        echo "  $GROUP_NAME"
      fi

      echo "$FLOW_ID" >> "$PRINTED_IDS_FILE"

      FLOW_NAME=$(echo "$flow" | jq -r '.name')
      FLOW_URL=$(echo "$flow" | jq -r '.url')

      case "$FLOW_STATUS" in
        passed)     printf "    ✓ %-40s PASSED   %s\n" "$FLOW_NAME" "$FLOW_URL" ;;
        failed)     printf "    ✗ %-40s FAILED   %s\n" "$FLOW_NAME" "$FLOW_URL" ;;
        error)      printf "    ⚠ %-40s ERROR    %s\n" "$FLOW_NAME" "$FLOW_URL" ;;
        terminated) printf "    ■ %-40s TERMINATED\n" "$FLOW_NAME" ;;
        skipped)    printf "    → %-40s SKIPPED\n" "$FLOW_NAME" ;;
      esac

      REVIEW_SUMMARY=$(echo "$flow" | jq -r '.summary // empty')
      if [ -n "$REVIEW_SUMMARY" ]; then
        echo "      $REVIEW_SUMMARY"
      fi
    done
  done

  IS_COMPLETE=$(echo "$STATUS_RESPONSE" | jq -r '.is_complete')
  if [ "$IS_COMPLETE" = "true" ]; then
    break
  fi

  sleep "$POLL_INTERVAL"
done

# Final summary
echo ""
echo "========================================"
echo "  Results Summary"
echo "========================================"

TOTAL_GROUPS=$(echo "$STATUS_RESPONSE" | jq -r '.summary.total_groups')
PASSED_GROUPS=$(echo "$STATUS_RESPONSE" | jq -r '.summary.passed_groups')

TOTAL=$(echo "$STATUS_RESPONSE" | jq -r '.summary.total_flows')
PASSED=$(echo "$STATUS_RESPONSE" | jq -r '.summary.passed_flows')
FAILED=$(echo "$STATUS_RESPONSE" | jq -r '.summary.failed_flows')
ERROR_COUNT=$(echo "$STATUS_RESPONSE" | jq -r '.summary.error_flows')
TERMINATED=$(echo "$STATUS_RESPONSE" | jq -r '.summary.terminated_flows')
SKIPPED=$(echo "$STATUS_RESPONSE" | jq -r '.summary.skipped_flows')

echo "   Suites:  $PASSED_GROUPS/$TOTAL_GROUPS passed"
echo "   Flows:   $PASSED/$TOTAL passed"
[ "$FAILED" != "0" ] && echo "   Failed:  $FAILED"
[ "$ERROR_COUNT" != "0" ] && echo "   Error:   $ERROR_COUNT"
[ "$TERMINATED" != "0" ] && echo "   Terminated: $TERMINATED"
[ "$SKIPPED" != "0" ] && echo "   Skipped: $SKIPPED"
echo ""

UNSUCCESSFUL=$((FAILED + ERROR_COUNT))
if [ "$UNSUCCESSFUL" -gt 0 ]; then
  echo "❌ $UNSUCCESSFUL flow(s) did not pass."
  exit 1
else
  echo "✅ All flows passed!"
  exit 0
fi