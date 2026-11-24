#!/usr/bin/env bats

setup() {
    load 'test_helper/common-setup'
    _common_setup
    export FLOW_IDS="uuid-1"
    export MOCK_CURL_CAPTURE_DIR="$BATS_TEST_TMPDIR/requests"
    export MOCK_CURL_CALL_LOG="$BATS_TEST_TMPDIR/calls.log"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"
}

_use_web() {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://preview.example.com"
}

_assert_run_sends() {
    run jq -e --argjson cap "$1" '.max_tests_at_once == $cap and (.max_tests_at_once | type) == "number"' \
        "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

_assert_key_absent() {
    run jq -e 'has("max_tests_at_once") | not' "$MOCK_CURL_CAPTURE_DIR/$1.json"
    assert_success
}

@test "android: max-concurrency is sent to the run request as max_tests_at_once, a number" {
    export MAX_CONCURRENCY="3"

    run bash "$ENTRYPOINT"

    assert_success
    _assert_run_sends 3
    _assert_key_absent CONFIRM_UPLOAD
}

@test "web: max-concurrency is sent to the run request as max_tests_at_once, a number" {
    _use_web
    export MAX_CONCURRENCY="3"

    run bash "$ENTRYPOINT"

    assert_success
    _assert_run_sends 3
    _assert_key_absent UPLOAD_WEB
}

@test "ios without a build: max-concurrency is sent to the run request" {
    export PLATFORM="ios"
    export BUILD_PATH=""
    export MAX_CONCURRENCY="3"

    run bash "$ENTRYPOINT"

    assert_success
    _assert_run_sends 3
}

@test "max-concurrency accepts 1 and 1000" {
    for value in 1 1000; do
        export MAX_CONCURRENCY="$value"
        run bash "$ENTRYPOINT"
        assert_success
        _assert_run_sends "$value"
    done
}

@test "max-concurrency is trimmed like other inputs" {
    for value in " 3" "3 " $' \t3\n'; do
        export MAX_CONCURRENCY="$value"
        run bash "$ENTRYPOINT"
        assert_success
        _assert_run_sends 3
    done
}

@test "a whitespace-only max-concurrency is treated as unset" {
    export MAX_CONCURRENCY=$' \t '

    run bash "$ENTRYPOINT"

    assert_success
    _assert_key_absent RUN_FLOWS
}

@test "android: max_tests_at_once is omitted when max-concurrency is empty" {
    run bash "$ENTRYPOINT"

    assert_success
    _assert_key_absent RUN_FLOWS
}

@test "web: max_tests_at_once is omitted when max-concurrency is unset" {
    _use_web
    unset MAX_CONCURRENCY

    run bash "$ENTRYPOINT"

    assert_success
    _assert_key_absent RUN_FLOWS
}

@test "invalid max-concurrency values fail before any request" {
    for value in "0" "1001" "9999" "abc" "2.5" "-1" "03" "1e3" "+3" "3 4"; do
        rm -f "$MOCK_CURL_CALL_LOG"
        export MAX_CONCURRENCY="$value"

        run bash "$ENTRYPOINT"

        assert_failure
        assert_output --partial "❌ ERROR: 'max-concurrency' must be a whole number from 1 to 1000."
        assert_output --partial "Provided: '$value'"
        [ ! -e "$MOCK_CURL_CALL_LOG" ]
    done
}

@test "upload-only step warns that max-concurrency is ignored" {
    export FLOW_IDS=""
    export MAX_CONCURRENCY="3"

    run bash "$ENTRYPOINT"

    assert_success
    assert_output --partial "⚠️  The action ignores 'max-concurrency' because this step selects no flow, suite, folder, or label."
    assert_output --partial "Runs that the upload starts use the limit saved on each automation."
    _assert_key_absent CONFIRM_UPLOAD
    [ ! -e "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json" ]
}
