#!/usr/bin/env bats

setup() {
    load 'test_helper/common-setup'
    _common_setup
}

_mock_jq_discovery() {
    export MOCK_JQ_PROBE_MODE="$1"
    export MOCK_PACKAGE_MANAGER="$2"
    export MOCK_UNAME="${3:-Linux}"
    export JQ_PROBE_COUNT=0

    command() {
        if [ "$1" = "-v" ]; then
            case "$2" in
                jq)
                    JQ_PROBE_COUNT=$((JQ_PROBE_COUNT + 1))
                    export JQ_PROBE_COUNT
                    case "$MOCK_JQ_PROBE_MODE" in
                        after-install) [ "$JQ_PROBE_COUNT" -gt 1 ] ;;
                        never) return 1 ;;
                    esac
                    return
                    ;;
                brew|apt-get|apk|yum|dnf)
                    [ "$2" = "$MOCK_PACKAGE_MANAGER" ]
                    return
                    ;;
            esac
        fi
        builtin command "$@"
    }
    sudo() { return 0; }
    brew() { return 0; }
    apk() { return 0; }
    yum() { return 0; }
    dnf() { return 0; }
    uname() { echo "$MOCK_UNAME"; }
    export -f command sudo brew apk yum dnf uname
}

@test "jq bootstrap supports Homebrew" {
    _mock_jq_discovery after-install brew Darwin

    run bash "$ENTRYPOINT"

    assert_success
    assert_output --partial "Attempting installation for OS: Darwin"
    assert_output --partial "jq installed successfully"
}

@test "jq bootstrap fails clearly when Homebrew is unavailable on macOS" {
    _mock_jq_discovery never none Darwin

    run bash "$ENTRYPOINT"

    assert_failure
    assert_output --partial "Homebrew not found on macOS runner"
}

@test "jq bootstrap supports Linux package managers" {
    local manager
    for manager in apt-get apk yum dnf; do
        _mock_jq_discovery after-install "$manager" Linux

        run bash "$ENTRYPOINT"

        assert_success
        assert_output --partial "jq installed successfully"
    done
}

@test "jq bootstrap rejects unsupported environments" {
    _mock_jq_discovery never none Linux

    run bash "$ENTRYPOINT"

    assert_failure
    assert_output --partial "Unsupported environment"
}

@test "jq bootstrap fails when installation does not provide jq" {
    _mock_jq_discovery never apt-get Linux

    run bash "$ENTRYPOINT"

    assert_failure
    assert_output --partial "Failed to install jq"
}

@test "start-upload warnings are surfaced" {
    export MOCK_CURL_BODY_START_UPLOAD='{"upload_url":"https://s3.mock/upload","file_path":"builds/test/dummy.apk","warnings":["start warning"]}'

    run bash "$ENTRYPOINT"

    assert_success
    assert_output --partial "⚠️  start warning"
}

@test "confirm-upload warnings are surfaced" {
    export MOCK_CURL_BODY_CONFIRM_UPLOAD='{"status":"confirmed","app_id":"app-123","warnings":["confirm warning"]}'

    run bash "$ENTRYPOINT"

    assert_success
    assert_output --partial "⚠️  confirm warning"
}

@test "ios ipa rejects an invalid keychain remapping value" {
    export PLATFORM="ios"
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/dummy.ipa"
    export ENABLE_IOS_KEYCHAIN_ACCESS_GROUP_REMAPPING="sometimes"

    run bash "$ENTRYPOINT"

    assert_failure
    assert_output --partial "enable-ios-keychain-access-group-remapping must be true or false"
    refute_output --partial '"enable_ios_keychain_access_group_remapping"'
}

@test "wait=false falls back to the batch link when the initial status response is invalid" {
    export FLOW_IDS="uuid-1"
    export WAIT="false"
    export MOCK_CURL_BODY_POLL_STATUS="not-json"

    run bash "$ENTRYPOINT"

    assert_success
    assert_output --partial "track them in the dashboard (batch batch-001)"
    refute_output --partial "links above"
}

@test "polling recovers from invalid responses and prints newly completed groups once" {
    export FLOW_IDS="uuid-1"
    export MOCK_POLL_RESPONSE_SEQUENCE_DIR="$PROJECT_ROOT/tests/fixtures/poll_sequence"
    export MOCK_POLL_RESPONSE_COUNTER_FILE="$BATS_TEST_TMPDIR/poll-counter"

    run bash "$ENTRYPOINT"

    assert_success
    assert_output --partial "Warning: Invalid response from status API, retrying"
    assert_output --partial "Initial Suite"
    assert_output --partial "Later Suite"
    assert_output --partial "All flows passed"
}
