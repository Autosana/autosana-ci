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

# --- Browser engine selection (web only) ---

@test "web payload includes web_browser when WEB_BROWSER is set" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://example.com"
    export FLOW_IDS="uuid-1"
    export WEB_BROWSER="firefox"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial '"web_browser": "firefox"'
}

@test "web payload omits web_browser when WEB_BROWSER is empty (backend default)" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://example.com"
    export FLOW_IDS="uuid-1"
    export WEB_BROWSER=""
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"
    run bash "$ENTRYPOINT"
    assert_success
    refute_output --partial '"web_browser"'
}

@test "mobile payload never includes web_browser even when WEB_BROWSER is set" {
    export PLATFORM="android"
    export BUNDLE_ID="com.example.app"
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/dummy.apk"
    export FLOW_IDS="uuid-1"
    export WEB_BROWSER="firefox"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"
    run bash "$ENTRYPOINT"
    assert_success
    # Sanity check that we actually reached the run-flows step (otherwise an
    # early-exit would make `refute_output` pass vacuously).
    assert_output --partial "Running Flows"
    # And the warning fires so users see the silent-drop avoided.
    assert_output --partial "'web-browser' is web-only"
    # web_browser is only meaningful for web; mobile must not leak it.
    refute_output --partial '"web_browser"'
}

@test "validation rejects unknown web-browser values with a clear error" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://example.com"
    export FLOW_IDS="uuid-1"
    export WEB_BROWSER="firfox"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Unsupported 'web-browser' value"
    # Did not reach the API call.
    refute_output --partial "Triggering flows"
}

@test "invalid web-browser on mobile warns but doesn't hard-fail (cursor[bot] regression)" {
    # Regression for cursor[bot] Medium finding: validation must NOT run on
    # mobile platforms — action.yml + README document web-browser as
    # "ignored for mobile", so a typo there should warn-and-continue, not
    # hard-fail the upload. Previously the validation block ran
    # unconditionally and a misconfigured matrix workflow with
    # `web-browser: firfox` + `platform: android` would fail the upload.
    export PLATFORM="android"
    export BUNDLE_ID="com.example.app"
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/dummy.apk"
    export FLOW_IDS="uuid-1"
    export WEB_BROWSER="firfox"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"
    run bash "$ENTRYPOINT"
    assert_success
    # The warning fires.
    assert_output --partial "'web-browser' is web-only"
    # And we proceed to the upload + run-flows step (mobile contract).
    assert_output --partial "Running Flows"
    # And we did NOT hard-fail with the validation error.
    refute_output --partial "Unsupported 'web-browser' value"
    # And the mobile payload still doesn't leak web_browser into the API call.
    refute_output --partial '"web_browser"'
}

@test "validation accepts web-browser aliases (chrome, msedge)" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://example.com"
    export FLOW_IDS="uuid-1"
    export WEB_BROWSER="msedge"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"
    run bash "$ENTRYPOINT"
    assert_success
    # Forwarded as-is; the backend's normalize_web_browser maps to canonical.
    assert_output --partial '"web_browser": "msedge"'
}
