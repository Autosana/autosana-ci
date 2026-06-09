#!/usr/bin/env bats

setup() {
    load 'test_helper/common-setup'
    _common_setup
    export PLATFORM=""
    export CODE_SYNC="plan"
    export CODE_SYNC_PATH=".autosana"
    export CODE_SYNC_FAIL_ON_CONFLICT="true"
    export MOCK_AUTOSANA_LOG="$BATS_TEST_TMPDIR/autosana.log"
}

@test "code-sync plan can run without platform" {
    run bash "$ENTRYPOINT"

    assert_success
    assert_output --partial "Sync-only workflow detected"
    assert_output --partial "Code sync complete"
    run cat "$MOCK_AUTOSANA_LOG"
    assert_output --partial "sync plan"
    assert_output --partial "--path .autosana"
    assert_output --partial "--repo-full-name myorg/myrepo"
    assert_output --partial "--commit-sha fakegitsha1234567890"
    assert_output --partial "--branch-name main"
}

@test "pull request event uses PR head SHA" {
    export GITHUB_EVENT_PATH="$PROJECT_ROOT/tests/fixtures/github_event_pr.json"

    run bash "$ENTRYPOINT"

    assert_success
    run cat "$MOCK_AUTOSANA_LOG"
    assert_output --partial "--commit-sha pr-head-sha-abcdef123456"
}

@test "push event falls back to git HEAD" {
    export GITHUB_EVENT_PATH="$PROJECT_ROOT/tests/fixtures/github_event_push.json"

    run bash "$ENTRYPOINT"

    assert_success
    run cat "$MOCK_AUTOSANA_LOG"
    assert_output --partial "--commit-sha fakegitsha1234567890"
}

@test "code-sync import calls CLI import command" {
    export CODE_SYNC="import"

    run bash "$ENTRYPOINT"

    assert_success
    run cat "$MOCK_AUTOSANA_LOG"
    assert_output --partial "sync import"
}

@test "code-sync can opt out of conflict failure" {
    export CODE_SYNC_FAIL_ON_CONFLICT="false"

    run bash "$ENTRYPOINT"

    assert_success
    run cat "$MOCK_AUTOSANA_LOG"
    assert_output --partial "--no-fail-on-conflict"
}

@test "upload-only web workflow does not call CLI" {
    export PLATFORM="web"
    export CODE_SYNC="off"
    export APP_ID="my-app"
    export URL="https://example.com"

    run bash "$ENTRYPOINT"

    assert_success
    assert_output --partial "Web URL registered successfully"
    [ ! -f "$MOCK_AUTOSANA_LOG" ]
}
