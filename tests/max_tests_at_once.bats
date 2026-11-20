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

@test "android: max-tests-at-once is sent to the run request as a number" {
    export MAX_TESTS_AT_ONCE="3"

    run bash "$ENTRYPOINT"

    assert_success
    _assert_run_sends 3
    _assert_key_absent CONFIRM_UPLOAD
}

@test "web: max-tests-at-once is sent to the run request as a number" {
    _use_web
    export MAX_TESTS_AT_ONCE="3"

    run bash "$ENTRYPOINT"

    assert_success
    _assert_run_sends 3
    _assert_key_absent UPLOAD_WEB
}

@test "ios without a build: max-tests-at-once is sent to the run request" {
    export PLATFORM="ios"
    export BUILD_PATH=""
    export MAX_TESTS_AT_ONCE="3"

    run bash "$ENTRYPOINT"

    assert_success
    _assert_run_sends 3
}

@test "max-tests-at-once accepts 1 and 1000" {
    for value in 1 1000; do
        export MAX_TESTS_AT_ONCE="$value"
        run bash "$ENTRYPOINT"
        assert_success
        _assert_run_sends "$value"
    done
}

@test "android: max_tests_at_once is omitted when the input is empty" {
    run bash "$ENTRYPOINT"

    assert_success
    _assert_key_absent RUN_FLOWS
}

@test "web: max_tests_at_once is omitted when the input is unset" {
    _use_web
    unset MAX_TESTS_AT_ONCE

    run bash "$ENTRYPOINT"

    assert_success
    _assert_key_absent RUN_FLOWS
}

@test "invalid max-tests-at-once values fail before any request" {
    for value in "0" "1001" "9999" "abc" "2.5" "-1" " 3" "3 " "03" "1e3" "+3" $'3\n'; do
        rm -f "$MOCK_CURL_CALL_LOG"
        export MAX_TESTS_AT_ONCE="$value"

        run bash "$ENTRYPOINT"

        assert_failure
        assert_output --partial "❌ ERROR: max-tests-at-once must be a whole number from 1 to 1000."
        assert_output --partial "Provided: '$value'"
        [ ! -e "$MOCK_CURL_CALL_LOG" ]
    done
}

@test "upload-only step warns that max-tests-at-once is ignored" {
    export FLOW_IDS=""
    export MAX_TESTS_AT_ONCE="3"

    run bash "$ENTRYPOINT"

    assert_success
    assert_output --partial "⚠️  'max-tests-at-once' applies only when tests are selected; ignoring it"
    _assert_key_absent CONFIRM_UPLOAD
    [ ! -e "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json" ]
}
