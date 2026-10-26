#!/usr/bin/env bats

setup() {
    load 'test_helper/common-setup'
    _common_setup
    export MOCK_CURL_CAPTURE_DIR="$BATS_TEST_TMPDIR/requests"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"
}

_use_web() {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://preview.example.com"
}

@test "web: location is sent to registration and run requests, trimmed and uppercased" {
    _use_web
    export LOCATION=" mx "
    export FLOW_IDS="uuid-1"

    run bash "$ENTRYPOINT"

    assert_success
    run jq -e '.location == "MX"' "$MOCK_CURL_CAPTURE_DIR/UPLOAD_WEB.json"
    assert_success
    run jq -e '.location == "MX"' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "web: location is omitted when unset" {
    _use_web
    export FLOW_IDS="uuid-1"

    run bash "$ENTRYPOINT"

    assert_success
    run jq -e 'has("location") | not' "$MOCK_CURL_CAPTURE_DIR/UPLOAD_WEB.json"
    assert_success
    run jq -e 'has("location") | not' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "web: blank location is omitted" {
    _use_web
    export LOCATION="   "

    run bash "$ENTRYPOINT"

    assert_success
    run jq -e 'has("location") | not' "$MOCK_CURL_CAPTURE_DIR/UPLOAD_WEB.json"
    assert_success
}

@test "android: location is sent to confirm and run requests" {
    export LOCATION="mx"
    export FLOW_IDS="uuid-1"

    run bash "$ENTRYPOINT"

    assert_success
    run jq -e '.location == "MX"' "$MOCK_CURL_CAPTURE_DIR/CONFIRM_UPLOAD.json"
    assert_success
    run jq -e '.location == "MX"' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
    run jq -e 'has("location") | not' "$MOCK_CURL_CAPTURE_DIR/START_UPLOAD.json"
    assert_success
}

@test "android: location is omitted when unset" {
    export FLOW_IDS="uuid-1"

    run bash "$ENTRYPOINT"

    assert_success
    run jq -e 'has("location") | not' "$MOCK_CURL_CAPTURE_DIR/CONFIRM_UPLOAD.json"
    assert_success
    run jq -e 'has("location") | not' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "ios: location is sent and the backend's refusal fails the step" {
    export PLATFORM="ios"
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/dummy.ipa"
    export LOCATION="MX"
    export MOCK_CURL_BODY_CONFIRM_UPLOAD='{"detail":"Location is not available for iOS runs yet."}'

    run bash "$ENTRYPOINT"

    assert_failure
    assert_output --partial "Location is not available for iOS runs yet."
    run jq -e '.location == "MX"' "$MOCK_CURL_CAPTURE_DIR/CONFIRM_UPLOAD.json"
    assert_success
}

@test "chrome-extension: location is rejected before upload" {
    export PLATFORM="chrome-extension"
    export BUNDLE_ID="my-extension"
    export BUILD_PATH="$BATS_TEST_TMPDIR/extension.zip"
    export LOCATION="MX"
    touch "$BUILD_PATH"

    run bash "$ENTRYPOINT"

    assert_failure
    assert_output --partial "'location' is not supported for Chrome extension uploads"
    [ ! -e "$MOCK_CURL_CAPTURE_DIR/START_UPLOAD.json" ]
}
