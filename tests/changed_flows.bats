#!/usr/bin/env bats

setup() {
    load 'test_helper/common-setup'
    _common_setup
    unset RUN_CHANGED_FLOWS
    export MOCK_CURL_CAPTURE_DIR="$BATS_TEST_TMPDIR/requests"
    export MOCK_CURL_LOG="$BATS_TEST_TMPDIR/requests.log"
    export GITHUB_STEP_SUMMARY="$BATS_TEST_TMPDIR/summary.md"
    export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/outputs"
    export GITHUB_RUN_ID="12345" GITHUB_RUN_ATTEMPT="2" GITHUB_JOB="test-app"
}

@test "changed flows run by default without selectors on mobile and pin uploaded build" {
    export MOCK_CURL_BODY_CONFIRM_UPLOAD='{"status":"confirmed","app_id":"app-123","build_id":"mobile-build"}'
    run bash "$ENTRYPOINT"
    assert_success
    run jq -e '.run_changed_flows == true and .app_build_id == "mobile-build" and .report_to_github == true and .ci == {workflow_run_id:"12345",workflow_run_attempt:"2",job:"test-app"}' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "changed web flows include PR number exact commit and registered build" {
    export PLATFORM=web APP_ID=my-web-app URL=https://example.com
    export GITHUB_EVENT_PATH="$BATS_TEST_TMPDIR/pr.json"
    printf '%s' '{"number":42,"pull_request":{"number":42,"head":{"sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}}' > "$GITHUB_EVENT_PATH"
    export MOCK_CURL_BODY_UPLOAD_WEB='{"build_id":"web-build"}'
    run bash "$ENTRYPOINT"
    assert_success
    run jq -e '.run_changed_flows == true and .pr_number == 42 and .app_build_id == "web-build" and .ref == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" and .repo_full_name == "myorg/myrepo"' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "changed flows false leaves a selector-free upload only" {
    export RUN_CHANGED_FLOWS=false
    run bash "$ENTRYPOINT"
    assert_success
    [ ! -e "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json" ]
}

@test "explicit selections still report when changed flows are disabled" {
    export RUN_CHANGED_FLOWS=false FLOW_IDS=flow-1
    run bash "$ENTRYPOINT"
    assert_success
    run jq -e '.run_changed_flows == false and .flow_ids == ["flow-1"] and .report_to_github == true and (has("pr_number") | not)' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "invalid changed flows boolean fails before upload" {
    export RUN_CHANGED_FLOWS=maybe
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Unsupported 'run-changed-flows' value"
    [ ! -e "$MOCK_CURL_LOG" ]
}

@test "extension uploads never run changed flows" {
    export PLATFORM=chrome-extension BUNDLE_ID=my-extension BUILD_PATH="$BATS_TEST_TMPDIR/extension.zip"
    touch "$BUILD_PATH"
    run bash "$ENTRYPOINT"
    assert_success
    [ ! -e "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json" ]
}

@test "legitimate changed-flow no-op succeeds without polling" {
    export MOCK_CURL_BODY_RUN_FLOWS='{"batch_id":null,"flow_run_count":0,"skipped":true,"reason":"No changed flows"}'
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "No changed flows"
    ! grep -q POLL_STATUS "$MOCK_CURL_LOG"
    grep -q 'Skipped' "$GITHUB_STEP_SUMMARY"
    grep -q 'No changed flows' "$GITHUB_STEP_SUMMARY"
}

@test "zero flow response without skipped marker still fails" {
    export MOCK_CURL_BODY_RUN_FLOWS='{"batch_id":null,"flow_run_count":0}'
    run bash "$ENTRYPOINT"
    assert_failure
    grep -q 'Failed' "$GITHUB_STEP_SUMMARY"
}

@test "no-wait summary reports submitted with result link and outputs" {
    export WAIT=false
    export MOCK_CURL_BODY_RUN_FLOWS='{"batch_id":"batch-001","batch_url":"https://app.autosana.ai/batches/batch-001","flow_run_count":2}'
    run bash "$ENTRYPOINT"
    assert_success
    grep -q 'Submitted' "$GITHUB_STEP_SUMMARY"
    ! grep -qi 'passed' "$GITHUB_STEP_SUMMARY"
    grep -q 'https://app.autosana.ai/batches/batch-001' "$GITHUB_STEP_SUMMARY"
    grep -q '^batch-id=batch-001$' "$GITHUB_OUTPUT"
    grep -q '^batch-url=https://app.autosana.ai/batches/batch-001$' "$GITHUB_OUTPUT"
}

@test "failed test summary includes failure and results link" {
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_some_failed.json"
    export MOCK_CURL_BODY_RUN_FLOWS='{"batch_id":"batch-001","batch_url":"https://app.autosana.ai/batches/batch-001","flow_run_count":2}'
    run bash "$ENTRYPOINT"
    assert_failure
    grep -q 'Failed' "$GITHUB_STEP_SUMMARY"
    grep -q 'https://app.autosana.ai/batches/batch-001' "$GITHUB_STEP_SUMMARY"
}

@test "passed tests appear in job summary" {
    run bash "$ENTRYPOINT"
    assert_success
    grep -q 'Passed' "$GITHUB_STEP_SUMMARY"
}

@test "explicit keys and changed flows share one run request" {
    export FLOW_KEYS=auth/login SUITE_KEYS=smoke
    run bash "$ENTRYPOINT"
    assert_success
    run jq -e '.flow_keys == ["auth/login"] and .suite_keys == ["smoke"] and .run_changed_flows == true and (has("flow_ids") | not)' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
    [ "$(grep -c '^RUN_FLOWS$' "$MOCK_CURL_LOG")" -eq 1 ]
}

@test "changed web flows support dependency overrides without selectors" {
    export PLATFORM=web APP_ID=my-web-app URL=https://example.com DEPENDENCIES='[]'
    run bash "$ENTRYPOINT"
    assert_success
    run jq -e '.run_changed_flows == true and .dependencies == []' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "deployment changed flows preserve deployment SHA and omit absent PR number" {
    export GITHUB_EVENT_NAME=deployment_status
    export GITHUB_EVENT_PATH="$BATS_TEST_TMPDIR/deployment.json"
    printf '%s' '{"deployment":{"sha":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}}' > "$GITHUB_EVENT_PATH"
    run bash "$ENTRYPOINT"
    assert_success
    run jq -e '.ref == "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" and .run_changed_flows == true and (has("pr_number") | not)' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "commit override omits unrelated event PR number" {
    export GITHUB_EVENT_PATH="$BATS_TEST_TMPDIR/pr.json"
    printf '%s' '{"number":42,"pull_request":{"head":{"sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}}' > "$GITHUB_EVENT_PATH"
    export INPUT_COMMIT_SHA=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
    run bash "$ENTRYPOINT"
    assert_success
    run jq -e '.ref == "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" and (has("pr_number") | not)' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "repository override omits unrelated event PR number" {
    export GITHUB_EVENT_PATH="$BATS_TEST_TMPDIR/pr.json"
    printf '%s' '{"number":42,"pull_request":{"head":{"sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}}' > "$GITHUB_EVENT_PATH"
    export INPUT_REPO_FULL_NAME=other/repository
    run bash "$ENTRYPOINT"
    assert_success
    run jq -e '.repo_full_name == "other/repository" and (has("pr_number") | not)' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "partial dispatch waits for submitted tests but still fails and links results" {
    export MOCK_CURL_BODY_RUN_FLOWS='{"batch_id":"batch-001","batch_url":"https://app.autosana.ai/batches/batch-001","flow_run_count":2,"errors":["Could not dispatch checkout"]}'
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Could not dispatch checkout"
    refute_output --partial "All flows passed"
    grep -q POLL_STATUS "$MOCK_CURL_LOG"
    grep -q 'Failed' "$GITHUB_STEP_SUMMARY"
    grep -q 'Could not dispatch checkout' "$GITHUB_STEP_SUMMARY"
    grep -q 'https://app.autosana.ai/batches/batch-001' "$GITHUB_STEP_SUMMARY"
}

@test "partial submission with wait false fails without claiming success" {
    export WAIT=false
    export MOCK_CURL_BODY_RUN_FLOWS='{"batch_id":"batch-001","batch_url":"https://app.autosana.ai/batches/batch-001","flow_run_count":2,"errors":[{"flow_id":"flow-2","error":"No supported device"}]}'
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "No supported device"
    ! grep -q POLL_STATUS "$MOCK_CURL_LOG"
    grep -q 'Failed' "$GITHUB_STEP_SUMMARY"
    grep -q 'No supported device' "$GITHUB_STEP_SUMMARY"
    grep -q 'https://app.autosana.ai/batches/batch-001' "$GITHUB_STEP_SUMMARY"
}

@test "literal null mobile build ID is omitted" {
    export MOCK_CURL_BODY_CONFIRM_UPLOAD='{"build_id":"null"}'
    run bash "$ENTRYPOINT"
    assert_success
    run jq -e 'has("app_build_id") | not' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "literal null web build ID is omitted" {
    export PLATFORM=web APP_ID=my-web-app URL=https://example.com
    export MOCK_CURL_BODY_UPLOAD_WEB='{"build_id":"null"}'
    run bash "$ENTRYPOINT"
    assert_success
    run jq -e 'has("app_build_id") | not' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}
