#!/usr/bin/env bats

# Tests for the `variables` input feature.
# Verifies that VARIABLES is included in API payloads when set,
# and omitted when empty (backward compatibility).

setup() {
    load 'test_helper/common-setup'
    _common_setup
}

# ===========================================================
# Web platform — variables in upload-web-build payload
# ===========================================================

@test "web: variables included in payload when set" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://preview.example.com"
    export VARIABLES="PR_NUMBER=42,BRANCH=main"

    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial '"variables"'
    assert_output --partial 'PR_NUMBER=42,BRANCH=main'
}

@test "web: variables omitted from payload when empty" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://preview.example.com"
    export VARIABLES=""

    run bash "$ENTRYPOINT"
    assert_success
    # The payload dump should NOT contain a variables field
    # (jq conditional adds {} when empty, so the key doesn't appear)
    refute_output --partial '"variables"'
}

# ===========================================================
# Mobile platform — variables in confirm-upload payload
# ===========================================================

@test "mobile: variables included in confirm payload when set" {
    export VARIABLES="DEPLOY_ENV=staging,VERSION=1.2.3"

    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial '"variables"'
    assert_output --partial 'DEPLOY_ENV=staging,VERSION=1.2.3'
}

@test "mobile: variables omitted from confirm payload when empty" {
    export VARIABLES=""

    run bash "$ENTRYPOINT"
    assert_success
    # Should not have variables in the confirm payload output
    # (the start-upload payload never includes variables, only confirm does)
    # Check that the confirm payload section doesn't have variables
    refute_output --partial '"variables"'
}

# ===========================================================
# Flow execution — variables in run-flows payload
# ===========================================================

@test "flow execution web: variables included when set" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://preview.example.com"
    export FLOW_IDS="uuid-1"
    export VARIABLES="PR_NUMBER=42"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"

    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial '"variables"'
}

@test "flow execution mobile: variables included when set" {
    export FLOW_IDS="uuid-1"
    export VARIABLES="BRANCH=feature/test"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"

    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial '"variables"'
}

@test "flow execution: variables omitted when empty" {
    export FLOW_IDS="uuid-1"
    export VARIABLES=""
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"

    run bash "$ENTRYPOINT"
    assert_success
    # The run-flows payload should not contain variables
    # Note: we can't easily isolate just the run-flows payload, but since
    # VARIABLES is empty, no payload in the entire output should have it
    refute_output --partial '"variables"'
}

# ===========================================================
# Backward compatibility — no VARIABLES env var at all
# ===========================================================

@test "web: succeeds without VARIABLES set at all" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://preview.example.com"
    unset VARIABLES

    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "Web URL registered successfully"
    refute_output --partial '"variables"'
}

@test "mobile: succeeds without VARIABLES set at all" {
    unset VARIABLES

    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "Upload completed successfully"
    refute_output --partial '"variables"'
}
