#!/usr/bin/env bats

setup() {
    load 'test_helper/common-setup'
    _common_setup
    export BUILD_PATH=""
    export LABELS="critical"
    export GITHUB_EVENT_NAME="pull_request"
    export GITHUB_EVENT_PATH="$PROJECT_ROOT/tests/fixtures/github_event_pr.json"
    export MOCK_CURL_CALL_LOG="$BATS_TEST_TMPDIR/calls.log"
    export MOCK_CURL_CAPTURE_DIR="$BATS_TEST_TMPDIR/payloads"
}

@test "no build-path skips the upload and runs on the commit's build" {
    export PLATFORM="ios"
    export DEVICE_MODEL="iPad Pro 13-inch (M5)"
    export ENVIRONMENT="dev"

    run bash "$ENTRYPOINT"

    assert_success
    run grep -cxE 'START_UPLOAD|UPLOAD_FILE|CONFIRM_UPLOAD' "$MOCK_CURL_CALL_LOG"
    assert_output "0"
    [ "$(grep -cx RUN_FLOWS "$MOCK_CURL_CALL_LOG")" -eq 1 ]
    run jq -c '{ref, repo_full_name, platform, labels, environment, device}' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_output '{"ref":"abcdef0123456789abcdef0123456789abcdef01","repo_full_name":"myorg/myrepo","platform":"ios","labels":["critical"],"environment":"dev","device":{"physical":false,"model":"iPad Pro 13-inch (M5)"}}'
    run jq 'has("app_build_id")' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_output "false"
}

@test "no build-path retries while the commit's build is missing, then passes" {
    export MOCK_RUN_FLOWS_STATUS_SEQUENCE="404,404,200"

    run bash "$ENTRYPOINT"

    assert_success
    [ "$(grep -cx RUN_FLOWS "$MOCK_CURL_CALL_LOG")" -eq 3 ]
    assert_output --partial "Waiting for the build of commit abcdef0123456789abcdef0123456789abcdef01"
    assert_output --partial "Triggered 2 flow(s)"
}

@test "no build-path retries while the app does not exist yet" {
    export MOCK_RUN_FLOWS_STATUS_SEQUENCE="404,200"
    export MOCK_RUN_FLOWS_404_BODY='{"detail":"App not found. Upload a build first."}'

    run bash "$ENTRYPOINT"

    assert_success
    [ "$(grep -cx RUN_FLOWS "$MOCK_CURL_CALL_LOG")" -eq 2 ]
}

@test "no build-path fails after the wait when no build appears" {
    export MOCK_RUN_FLOWS_STATUS_SEQUENCE="404"

    run bash "$ENTRYPOINT"

    assert_failure
    assert_output --partial "No build for commit abcdef0123456789abcdef0123456789abcdef01"
    [ "$(grep -cx RUN_FLOWS "$MOCK_CURL_CALL_LOG")" -eq 40 ]
}

@test "no build-path does not retry a 404 that is not about the build" {
    export MOCK_RUN_FLOWS_STATUS_SEQUENCE="404,200"
    export MOCK_RUN_FLOWS_404_BODY='{"detail":"No active suites or flows carry the requested label(s): critical"}'

    run bash "$ENTRYPOINT"

    assert_failure
    assert_output --partial "Failed to trigger flows (HTTP 404)"
    [ "$(grep -cx RUN_FLOWS "$MOCK_CURL_CALL_LOG")" -eq 1 ]
}

@test "build-path set uploads once and does not retry a missing build" {
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/dummy.apk"
    export MOCK_RUN_FLOWS_STATUS_SEQUENCE="404,200"

    run bash "$ENTRYPOINT"

    assert_failure
    run cat "$MOCK_CURL_CALL_LOG"
    assert_output "$(printf 'START_UPLOAD\nUPLOAD_FILE\nCONFIRM_UPLOAD\nRUN_FLOWS')"
}

@test "build-path set keeps today's upload, confirm and run sequence" {
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/dummy.apk"

    run bash "$ENTRYPOINT"

    assert_success
    run grep -vx POLL_STATUS "$MOCK_CURL_CALL_LOG"
    assert_output "$(printf 'START_UPLOAD\nUPLOAD_FILE\nCONFIRM_UPLOAD\nRUN_FLOWS')"
}
