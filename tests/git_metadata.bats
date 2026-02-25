#!/usr/bin/env bats

setup() {
    load 'test_helper/common-setup'
    _common_setup
}

@test "extracts PR head SHA from event file" {
    export GITHUB_EVENT_PATH="$PROJECT_ROOT/tests/fixtures/github_event_pr.json"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "COMMIT_SHA: pr-head-sha-abcdef123456"
}

@test "falls back to git rev-parse when no PR event" {
    export GITHUB_EVENT_PATH="$PROJECT_ROOT/tests/fixtures/github_event_push.json"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "COMMIT_SHA: fakegitsha1234567890"
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
