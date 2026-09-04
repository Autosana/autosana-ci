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

@test "explicit PR identity reaches web registration and selected runs from a trusted checkout" {
    export PLATFORM="web" APP_ID="my-app" URL="https://preview.example.com"
    export AUTOSANA_COMMIT_SHA="c8f3a5530b020bec1ccd61cea491c4e67edafd94"
    export AUTOSANA_BRANCH_NAME="feature/physical-device-gate"
    export AUTOSANA_REPO_FULL_NAME="Autosana/AutosanaDashboard"
    export LABELS="smoke" GITHUB_REF_NAME="staging"
    # An unrelated event head must not override the explicitly selected PR.
    export GITHUB_EVENT_PATH="$PROJECT_ROOT/tests/fixtures/github_event_pr.json"
    export MOCK_CURL_CAPTURE_DIR="$BATS_TEST_TMPDIR/requests"

    run bash "$ENTRYPOINT"
    assert_success
    run jq -e '.commit_sha == env.AUTOSANA_COMMIT_SHA
        and .branch_name == env.AUTOSANA_BRANCH_NAME
        and .repo_full_name == env.AUTOSANA_REPO_FULL_NAME' \
        "$MOCK_CURL_CAPTURE_DIR/UPLOAD_WEB.json"
    assert_success
    run jq -e '.ref == env.AUTOSANA_COMMIT_SHA
        and .repo_full_name == env.AUTOSANA_REPO_FULL_NAME
        and .labels == ["smoke"]' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "explicit PR identity reaches mobile upload confirmation and selected runs" {
    export AUTOSANA_COMMIT_SHA="c8f3a5530b020bec1ccd61cea491c4e67edafd94"
    export AUTOSANA_BRANCH_NAME='feature/quoted-"branch-$(false)'
    export AUTOSANA_REPO_FULL_NAME="Autosana/Mobile"
    export FLOW_KEYS="auth/login"
    export MOCK_CURL_CAPTURE_DIR="$BATS_TEST_TMPDIR/requests"

    run bash "$ENTRYPOINT"
    assert_success
    run jq -e '.commit_sha == env.AUTOSANA_COMMIT_SHA
        and .branch_name == env.AUTOSANA_BRANCH_NAME
        and .repo_full_name == env.AUTOSANA_REPO_FULL_NAME' \
        "$MOCK_CURL_CAPTURE_DIR/CONFIRM_UPLOAD.json"
    assert_success
    run jq -e '.ref == env.AUTOSANA_COMMIT_SHA
        and .repo_full_name == env.AUTOSANA_REPO_FULL_NAME
        and .flow_keys == ["auth/login"]' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "partial metadata override preserves automatic branch and repository defaults" {
    export AUTOSANA_COMMIT_SHA="c8f3a5530b020bec1ccd61cea491c4e67edafd94"
    export GITHUB_HEAD_REF="feature/default-branch"
    export MOCK_CURL_CAPTURE_DIR="$BATS_TEST_TMPDIR/requests"

    run bash "$ENTRYPOINT"
    assert_success
    run jq -e '.commit_sha == env.AUTOSANA_COMMIT_SHA
        and .branch_name == env.GITHUB_HEAD_REF
        and .repo_full_name == env.GITHUB_REPOSITORY' \
        "$MOCK_CURL_CAPTURE_DIR/CONFIRM_UPLOAD.json"
    assert_success
}

@test "invalid explicit commit is rejected before upload even without test selectors" {
    export MOCK_CURL_CAPTURE_DIR="$BATS_TEST_TMPDIR/requests"
    for invalid_sha in "short-sha" " " $'c8f3a5530b020bec1ccd61cea491c4e67edafd94\nextra'; do
        export AUTOSANA_COMMIT_SHA="$invalid_sha"
        run bash "$ENTRYPOINT"
        assert_failure
        assert_output --partial "commit-sha must be a full 40-character Git commit SHA"
        [ ! -e "$MOCK_CURL_CAPTURE_DIR/CONFIRM_UPLOAD.json" ]
        [ ! -e "$MOCK_CURL_CAPTURE_DIR/UPLOAD_WEB.json" ]
        [ ! -e "$MOCK_CURL_CAPTURE_DIR/START_UPLOAD.json" ]
    done
}
