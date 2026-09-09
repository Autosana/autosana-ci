#!/usr/bin/env bats

setup() {
    load 'test_helper/common-setup'
    _common_setup
}

@test "extracts PR head SHA from event file" {
    export GITHUB_EVENT_PATH="$PROJECT_ROOT/tests/fixtures/github_event_pr.json"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "COMMIT_SHA: abcdef0123456789abcdef0123456789abcdef01"
}

@test "falls back to git rev-parse when no PR event" {
    export GITHUB_EVENT_PATH="$PROJECT_ROOT/tests/fixtures/github_event_push.json"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "COMMIT_SHA: 0123456789abcdef0123456789abcdef01234567"
}

@test "falls back to GITHUB_SHA when git fails" {
    export GITHUB_EVENT_PATH="$PROJECT_ROOT/tests/fixtures/github_event_push.json"
    export MOCK_GIT_FAIL=1
    export GITHUB_SHA="fallback-sha-999"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "COMMIT_SHA: fallback-sha-999"
}

@test "BRANCH_NAME prefers GITHUB_HEAD_REF over GITHUB_REF_NAME" {
    export GITHUB_HEAD_REF="feature/my-branch"
    export GITHUB_REF_NAME="main"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "BRANCH_NAME: feature/my-branch"
}

@test "explicit PR metadata overrides the trusted checkout and event" {
    export INPUT_COMMIT_SHA="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    export INPUT_BRANCH_NAME="feature/actual-pr"
    export INPUT_REPO_FULL_NAME="Autosana/AutosanaDashboard"
    export GITHUB_EVENT_PATH="$PROJECT_ROOT/tests/fixtures/github_event_pr.json"
    export PLATFORM="web" APP_ID="preview" URL="https://preview.example.com"
    export LABELS="smoke"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "COMMIT_SHA: $INPUT_COMMIT_SHA"
    assert_output --partial "BRANCH_NAME: $INPUT_BRANCH_NAME"
    assert_output --partial "REPO_FULL_NAME: $INPUT_REPO_FULL_NAME"
    assert_output --partial '"ref": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
}

@test "web run pins the registered build despite concurrent preview registrations" {
    export PLATFORM="web" APP_ID="preview" URL="https://preview.example.com" LABELS="smoke"
    export MOCK_CURL_BODY_UPLOAD_WEB='{"status":"success","build_id":"12345678-1234-1234-1234-123456789abc"}'
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial '"app_build_id": "12345678-1234-1234-1234-123456789abc"'
}

@test "deployment_status uses deployed SHA instead of trusted checkout" {
    export GITHUB_EVENT_NAME="deployment_status"
    export GITHUB_EVENT_PATH="$BATS_TEST_TMPDIR/deployment.json"
    printf '%s' '{"deployment":{"sha":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}}' > "$GITHUB_EVENT_PATH"
    export PLATFORM="web" APP_ID="preview" URL="https://preview.example.com" LABELS="smoke"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial '"commit_sha": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"'
    assert_output --partial '"ref": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"'
}

@test "deployment event falls back to GITHUB_SHA when payload is unavailable" {
    export GITHUB_EVENT_NAME="deployment"
    export GITHUB_EVENT_PATH="$BATS_TEST_TMPDIR/missing.json"
    export GITHUB_SHA="cccccccccccccccccccccccccccccccccccccccc"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "COMMIT_SHA: $GITHUB_SHA"
}

@test "explicit commit still wins over deployment autodetection" {
    export GITHUB_EVENT_NAME="deployment_status"
    export GITHUB_SHA="cccccccccccccccccccccccccccccccccccccccc"
    export INPUT_COMMIT_SHA="dddddddddddddddddddddddddddddddddddddddd"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "COMMIT_SHA: $INPUT_COMMIT_SHA"
}

@test "push workflows retain intentional checkout SHA instead of event SHA" {
    export GITHUB_EVENT_NAME="push"
    export GITHUB_SHA="cccccccccccccccccccccccccccccccccccccccc"
    export MOCK_GIT_SHA="eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "COMMIT_SHA: $MOCK_GIT_SHA"
}

@test "manual workflows retain checkout behavior without an override" {
    export GITHUB_EVENT_NAME="workflow_dispatch"
    export GITHUB_SHA="cccccccccccccccccccccccccccccccccccccccc"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "COMMIT_SHA: 0123456789abcdef0123456789abcdef01234567"
}
