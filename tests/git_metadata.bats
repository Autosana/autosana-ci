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

@test "explicit git metadata overrides scheduled workflow defaults" {
    export COMMIT_SHA_OVERRIDE="fedcba9876543210fedcba9876543210fedcba98"
    export BRANCH_NAME_OVERRIDE="feature/scheduled-preview"
    export REPO_FULL_NAME_OVERRIDE="Autosana/AutosanaDashboard"

    run bash "$ENTRYPOINT"

    assert_success
    assert_output --partial "COMMIT_SHA: fedcba9876543210fedcba9876543210fedcba98"
    assert_output --partial "BRANCH_NAME: feature/scheduled-preview"
    assert_output --partial "REPO_FULL_NAME: Autosana/AutosanaDashboard"
}
