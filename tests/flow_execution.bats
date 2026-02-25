#!/usr/bin/env bats

setup() {
    load 'test_helper/common-setup'
    _common_setup
}

# --- No flow IDs means skip ---

@test "no SUITE_IDS or FLOW_IDS exits 0 without running flows" {
    run bash "$ENTRYPOINT"
    assert_success
    refute_output --partial "Running Flows"
}

# --- Flow triggering ---

@test "FLOW_IDS triggers flow execution" {
    export FLOW_IDS="uuid-1,uuid-2"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "Running Flows"
    assert_output --partial "Triggered"
}

@test "SUITE_IDS triggers flow execution" {
    export SUITE_IDS="suite-1"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "Running Flows"
}

# --- run-flows API errors ---

@test "run-flows API returns HTTP 500" {
    export FLOW_IDS="uuid-1"
    export MOCK_CURL_STATUS_RUN_FLOWS=500
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Failed to trigger flows"
}

@test "run-flows returns invalid JSON" {
    export FLOW_IDS="uuid-1"
    export MOCK_CURL_BODY_RUN_FLOWS="bad-json"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Invalid JSON response from run-flows"
}

@test "run-flows returns null batch_id" {
    export FLOW_IDS="uuid-1"
    export MOCK_CURL_BODY_RUN_FLOWS='{"batch_id":null,"flow_run_count":0}'
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Failed to retrieve batch ID"
}

# --- Flow results ---

@test "all flows pass exits 0" {
    export FLOW_IDS="uuid-1"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "All flows passed"
}

@test "some flows fail exits 1" {
    export FLOW_IDS="uuid-1"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_some_failed.json"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "did not pass"
}

@test "summary shows correct pass count" {
    export FLOW_IDS="uuid-1"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "Flows:   2/2 passed"
}

@test "summary shows failed count when flows fail" {
    export FLOW_IDS="uuid-1"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_some_failed.json"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Failed:  1"
}

@test "web platform flow payload uses app_id not bundle_id" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://example.com"
    export FLOW_IDS="uuid-1"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial '"app_id"'
}
