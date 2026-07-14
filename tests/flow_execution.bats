#!/usr/bin/env bats

setup() {
    load 'test_helper/common-setup'
    _common_setup
}

# --- Upload environment payloads ---

@test "chrome-extension upload omits ignored environment from start and confirm payloads" {
    export PLATFORM="chrome-extension"
    export BUNDLE_ID="my-extension"
    export BUILD_PATH="$BATS_TEST_TMPDIR/extension.zip"
    export ENVIRONMENT="does-not-exist"
    touch "$BUILD_PATH"

    run bash "$ENTRYPOINT"

    assert_success
    assert_output --partial "Starting upload process"
    assert_output --partial "Confirming upload"
    refute_output --regexp '"environment"[[:space:]]*:'
}

@test "mobile upload preserves environment in payloads" {
    export ENVIRONMENT="staging"

    run bash "$ENTRYPOINT"

    assert_success
    assert_output --partial '"environment": "staging"'
}

@test "web upload preserves environment in payload" {
    export PLATFORM="web"
    export APP_ID="my-web-app"
    export URL="https://example.com"
    export ENVIRONMENT="staging"

    run bash "$ENTRYPOINT"

    assert_success
    assert_output --partial '"environment": "staging"'
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

# --- Labels ---

@test "LABELS alone triggers flow execution" {
    export LABELS="smoke"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "Running Flows"
    assert_output --partial "Triggered"
}

@test "LABELS are sent to run-flows as a JSON array of names" {
    export LABELS="smoke, regression"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial '"labels"'
    assert_output --partial '"smoke"'
    assert_output --partial '"regression"'
}

@test "LABELS combine with FLOW_IDS (union) in the payload" {
    export LABELS="smoke"
    export FLOW_IDS="uuid-1"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial '"smoke"'
    assert_output --partial '"uuid-1"'
}

@test "empty labels omit the run step (no LABELS/SUITE_IDS/FLOW_IDS exits 0)" {
    export LABELS=""
    run bash "$ENTRYPOINT"
    assert_success
    refute_output --partial "Running Flows"
}

# The backend resolves an unknown label to an empty match and returns a 4xx;
# the action must surface that as a failure rather than exit green.
@test "unknown label (backend 4xx / empty match) fails the action" {
    export LABELS="does-not-exist"
    export MOCK_CURL_STATUS_RUN_FLOWS=422
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Failed to trigger flows"
}

@test "web platform forwards labels in the run payload" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://example.com"
    export LABELS="smoke"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial '"labels"'
    assert_output --partial '"smoke"'
}

# --- No-wait (fire-and-forget) mode ---

@test "wait=false triggers flows then exits 0 without polling for results" {
    export FLOW_IDS="uuid-1"
    export WAIT="false"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "Triggered"
    assert_output --partial "Not waiting for results (wait: false)"
    # It must NOT enter the polling loop or print a results summary.
    refute_output --partial "Waiting for results..."
    refute_output --partial "Results Summary"
}

@test "wait=false ignores failing flow status and still exits 0" {
    # Fire-and-forget means CI is not gated on results. The initial status GET
    # (best-effort, for printing links) returns a fixture where a flow has
    # already failed — proven by the failed flow's link appearing in output —
    # yet the action must still exit 0 and never run the pass/fail gate.
    export FLOW_IDS="uuid-1"
    export WAIT="false"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_some_failed.json"
    run bash "$ENTRYPOINT"
    assert_success
    # The failure-shaped status was actually fetched on the path we reached.
    assert_output --partial "Checkout Flow"
    # ...but no gating / summary logic ran.
    assert_output --partial "Not waiting for results (wait: false)"
    refute_output --partial "did not pass"
    refute_output --partial "Results Summary"
}

@test "invalid wait value fails fast with a clear error" {
    export FLOW_IDS="uuid-1"
    export WAIT="nope"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Unsupported 'wait' value"
    # Must not have triggered flows with a bad config.
    refute_output --partial "Triggering flows"
}

@test "wait flag is case-insensitive (False)" {
    export FLOW_IDS="uuid-1"
    export WAIT="False"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "Not waiting for results (wait: false)"
}

@test "wait defaults to blocking when unset" {
    export FLOW_IDS="uuid-1"
    unset WAIT
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "Waiting for results..."
    assert_output --partial "All flows passed"
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

# Regression: a customer reported a run with 0/72 flows passed and 37
# terminated still exited 0 with "✅ All flows passed!". Terminated flows
# (worker crash, infra issue, manual kill) are not passes — they must
# fail the action so CI surfaces the breakage instead of merging green.
@test "all flows terminated exits 1 (regression)" {
    export FLOW_IDS="uuid-1"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_terminated.json"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Terminated: 2"
    assert_output --partial "did not pass"
    assert_output --partial "terminated: 2"
    refute_output --partial "All flows passed"
}

# Skipped flows are intentional (e.g. platform filter), so they shouldn't
# fail the action. A run where every non-skipped flow passed should exit 0.
@test "passed plus skipped flows exits 0" {
    export FLOW_IDS="uuid-1"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_passed_with_skipped.json"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "Skipped: 1"
    assert_output --partial "All flows passed (1/2)"
}

# A real-world failing run usually has multiple buckets populated. Lock in
# that the failure-message string surfaces all counts (PR-bot ask).
@test "mixed results (failed+error+terminated+skipped) exits 1 with itemized counts" {
    export FLOW_IDS="uuid-1"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_mixed_results.json"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "did not pass (failed: 1, error: 1, terminated: 1)"
    assert_output --partial "Failed:  1"
    assert_output --partial "Error:   1"
    assert_output --partial "Terminated: 1"
    assert_output --partial "Skipped: 1"
}

# A matrix CI job (e.g. `platform: ios`) can legitimately skip every flow
# when the suite is android-only and vice versa. That should stay a green
# build — but the previous message read "✅ All flows passed (0/2)." which
# is self-contradictory (Cursor Bugbot Medium finding on 4c156b4). Assert
# we still exit 0 and that the message is no longer a contradiction.
@test "all flows skipped exits 0 with non-contradictory message" {
    export FLOW_IDS="uuid-1"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_skipped.json"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "No applicable flows ran (0 passed, 2 skipped)"
    refute_output --partial "All flows passed (0/"
}

# Defense in depth: if total_flows is 0 (empty batch / API glitch), the
# action must NOT print "All flows passed (0/0)" and exit 0. This was a
# fail-open class flagged in PR review.
@test "empty batch (TOTAL=0) fails closed instead of claiming success" {
    export FLOW_IDS="uuid-1"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_empty_batch.json"
    run bash "$ENTRYPOINT"
    assert_failure
    refute_output --partial "All flows passed"
    assert_output --partial "No flows ran"
}

# Defense in depth: if the backend returns inconsistent counters such that
# PASSED + SKIPPED > TOTAL (e.g. mismatched `// 0` fallbacks), a naive
# subtraction would go negative and silently exit 0. Make sure we fail
# closed AND emit a sensible message instead of "❌ -1 flow(s) did not
# pass" — PR-bot regression (Cursor Bugbot Low finding on cf50cf0).
@test "inconsistent counters (PASSED+SKIPPED > TOTAL) fails closed with a sensible message" {
    export FLOW_IDS="uuid-1"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_inconsistent_counters.json"
    run bash "$ENTRYPOINT"
    assert_failure
    refute_output --partial "All flows passed"
    assert_output --partial "Inconsistent run summary"
    refute_output --regexp '❌ -[0-9]+ flow'
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

# --- Per-run web dependency overrides ---

@test "web run omits dependencies when input is omitted" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://example.com"
    export FLOW_IDS="uuid-1"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"
    run bash "$ENTRYPOINT"
    assert_success
    refute_output --partial '"dependencies"'
}

@test "web run sends explicit empty dependencies array" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://example.com"
    export FLOW_IDS="uuid-1"
    export DEPENDENCIES='[]'
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial '"dependencies": []'
}

@test "web run preserves dependency IDs and build pins as JSON" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://example.com"
    export LABELS="smoke"
    export DEPENDENCIES='["11111111-1111-1111-1111-111111111111",{"app_id":"22222222-2222-2222-2222-222222222222","app_build_id":"33333333-3333-3333-3333-333333333333"}]'
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial '"dependencies": ['
    assert_output --partial '"11111111-1111-1111-1111-111111111111"'
    assert_output --partial '"app_id": "22222222-2222-2222-2222-222222222222"'
    assert_output --partial '"app_build_id": "33333333-3333-3333-3333-333333333333"'
    refute_output --partial '"dependencies": "['
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
