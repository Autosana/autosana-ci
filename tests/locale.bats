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

@test "web: locale is sent to registration and run requests, trimmed" {
    _use_web
    export LOCALE=" de-DE "
    export FLOW_IDS="uuid-1"

    run bash "$ENTRYPOINT"

    assert_success
    run jq -e '.locale == "de-DE"' "$MOCK_CURL_CAPTURE_DIR/UPLOAD_WEB.json"
    assert_success
    run jq -e '.locale == "de-DE"' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "web: locale case is passed through unchanged" {
    _use_web
    export LOCALE="de-de"

    run bash "$ENTRYPOINT"

    assert_success
    run jq -e '.locale == "de-de"' "$MOCK_CURL_CAPTURE_DIR/UPLOAD_WEB.json"
    assert_success
}

@test "web: locale is omitted when unset" {
    _use_web
    export FLOW_IDS="uuid-1"

    run bash "$ENTRYPOINT"

    assert_success
    run jq -e 'has("locale") | not' "$MOCK_CURL_CAPTURE_DIR/UPLOAD_WEB.json"
    assert_success
    run jq -e 'has("locale") | not' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "web: blank locale is omitted" {
    _use_web
    export LOCALE="   "
    export FLOW_IDS="uuid-1"

    run bash "$ENTRYPOINT"

    assert_success
    run jq -e 'has("locale") | not' "$MOCK_CURL_CAPTURE_DIR/UPLOAD_WEB.json"
    assert_success
    run jq -e 'has("locale") | not' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "android: locale is sent to confirm and run requests" {
    export LOCALE="de-DE"
    export FLOW_IDS="uuid-1"

    run bash "$ENTRYPOINT"

    assert_success
    run jq -e '.locale == "de-DE"' "$MOCK_CURL_CAPTURE_DIR/CONFIRM_UPLOAD.json"
    assert_success
    run jq -e '.locale == "de-DE"' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
    run jq -e 'has("locale") | not' "$MOCK_CURL_CAPTURE_DIR/START_UPLOAD.json"
    assert_success
}

@test "android: locale is omitted when unset" {
    export FLOW_IDS="uuid-1"

    run bash "$ENTRYPOINT"

    assert_success
    run jq -e 'has("locale") | not' "$MOCK_CURL_CAPTURE_DIR/CONFIRM_UPLOAD.json"
    assert_success
    run jq -e 'has("locale") | not' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "ios: locale is sent to confirm and run requests" {
    export PLATFORM="ios"
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/dummy.ipa"
    export LOCALE="de-DE"
    export FLOW_IDS="uuid-1"

    run bash "$ENTRYPOINT"

    assert_success
    run jq -e '.locale == "de-DE"' "$MOCK_CURL_CAPTURE_DIR/CONFIRM_UPLOAD.json"
    assert_success
    run jq -e '.locale == "de-DE"' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "ios without build-path: locale is sent to the run request" {
    export PLATFORM="ios"
    export BUILD_PATH=""
    export LABELS="critical"
    export GITHUB_EVENT_NAME="pull_request"
    export GITHUB_EVENT_PATH="$PROJECT_ROOT/tests/fixtures/github_event_pr.json"
    export LOCALE="de-DE"

    run bash "$ENTRYPOINT"

    assert_success
    [ ! -e "$MOCK_CURL_CAPTURE_DIR/CONFIRM_UPLOAD.json" ]
    run jq -e '.locale == "de-DE"' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "chrome-extension: locale is refused" {
    export PLATFORM="chrome-extension"
    export BUNDLE_ID="my-extension"
    export BUILD_PATH="$BATS_TEST_TMPDIR/extension.zip"
    export LOCALE="de-DE"
    touch "$BUILD_PATH"

    run bash "$ENTRYPOINT"

    assert_failure
    assert_output --partial "'locale' is not supported for Chrome extension uploads."
    [ ! -e "$MOCK_CURL_CAPTURE_DIR/START_UPLOAD.json" ]
}

@test "locale and location are sent together" {
    _use_web
    export LOCALE="de-DE"
    export LOCATION="mx"
    export FLOW_IDS="uuid-1"

    run bash "$ENTRYPOINT"

    assert_success
    run jq -e '.locale == "de-DE" and .location == "MX"' "$MOCK_CURL_CAPTURE_DIR/UPLOAD_WEB.json"
    assert_success
    run jq -e '.locale == "de-DE" and .location == "MX"' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}
