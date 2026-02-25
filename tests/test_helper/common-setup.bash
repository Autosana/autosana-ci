#!/usr/bin/env bash

_common_setup() {
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." >/dev/null 2>&1 && pwd)"

    load "$PROJECT_ROOT/tests/lib/bats-support/load"
    load "$PROJECT_ROOT/tests/lib/bats-assert/load"
    ENTRYPOINT="$PROJECT_ROOT/entrypoint.sh"

    # Put mocks at the front of PATH so they shadow real commands
    PATH="$PROJECT_ROOT/tests/mocks:$PATH"
    export PATH

    # Default environment variables that entrypoint.sh expects
    export AUTOSANA_KEY="test-api-key-1234567890"
    export PLATFORM="android"
    export BUNDLE_ID="com.example.app"
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/dummy.apk"
    export APP_ID=""
    export URL=""
    export APP_NAME=""
    export ENVIRONMENT=""
    export AUTOSANA_API_URL="http://mock-api.local"
    export SUITE_IDS=""
    export FLOW_IDS=""

    # GitHub env vars (mocked)
    export GITHUB_EVENT_PATH="$PROJECT_ROOT/tests/fixtures/github_event_push.json"
    export GITHUB_SHA="abc123def456"
    export GITHUB_HEAD_REF=""
    export GITHUB_REF_NAME="main"
    export GITHUB_REPOSITORY="myorg/myrepo"

    # Reset mock overrides
    unset MOCK_CURL_STATUS_START_UPLOAD
    unset MOCK_CURL_STATUS_CONFIRM_UPLOAD
    unset MOCK_CURL_STATUS_UPLOAD_WEB
    unset MOCK_CURL_STATUS_UPLOAD_FILE
    unset MOCK_CURL_STATUS_RUN_FLOWS
    unset MOCK_CURL_STATUS_POLL_STATUS
    unset MOCK_CURL_BODY_START_UPLOAD
    unset MOCK_CURL_BODY_CONFIRM_UPLOAD
    unset MOCK_CURL_BODY_UPLOAD_WEB
    unset MOCK_CURL_BODY_UPLOAD_FILE
    unset MOCK_CURL_BODY_RUN_FLOWS
    unset MOCK_CURL_BODY_POLL_STATUS
    unset MOCK_POLL_RESPONSE_FILE
    unset MOCK_GIT_FAIL
}
