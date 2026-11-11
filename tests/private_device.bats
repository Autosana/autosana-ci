#!/usr/bin/env bats

setup() {
    load 'test_helper/common-setup'
    _common_setup
    export FLOW_IDS="uuid-1"
    export MOCK_CURL_CAPTURE_DIR="$BATS_TEST_TMPDIR/requests"
    export MOCK_POLL_RESPONSE_FILE="$PROJECT_ROOT/tests/fixtures/poll_all_passed.json"
}

DEVICE_UUID="3f1c2a4e-9b7d-4c1a-8e2f-0a1b2c3d4e5f"

_assert_refused_before_upload() {
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "$1"
    refute_output --partial "Starting upload process"
    refute_output --partial "Registering web build"
    refute_output --partial "Triggering flows"
}

@test "android: private-device-id sends a physical private device, trimmed and lowercased" {
    export PRIVATE_DEVICE_ID="  3F1C2A4E-9B7D-4C1A-8E2F-0A1B2C3D4E5F "

    run bash "$ENTRYPOINT"

    assert_success
    run jq -e --arg id "$DEVICE_UUID" \
        '.device == {physical: true, private_device_id: $id} and (has("devices") | not)' \
        "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "ios: private-device-id accepts physical-device true" {
    export PLATFORM="ios"
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/dummy.ipa"
    export PHYSICAL_DEVICE="true"
    export PRIVATE_DEVICE_ID="$DEVICE_UUID"

    run bash "$ENTRYPOINT"

    assert_success
    run jq -e --arg id "$DEVICE_UUID" '.device == {physical: true, private_device_id: $id}' \
        "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "private-device-id rejects a value that is not a UUID" {
    export PRIVATE_DEVICE_ID="my-pixel"
    _assert_refused_before_upload "'private-device-id' must be a device UUID"
}

@test "private-device-id rejects a UUID with spaces inside it" {
    export PRIVATE_DEVICE_ID="3f1c2a4e-9b7d-4c1a-8e2f 0a1b2c3d4e5f"
    _assert_refused_before_upload "'private-device-id' must be a device UUID"
}

@test "private-device-id cannot be combined with devices" {
    export PRIVATE_DEVICE_ID="$DEVICE_UUID"
    export DEVICES='[{"physical": true}, {"physical": true}]'
    _assert_refused_before_upload "'private-device-id' cannot be combined with 'devices'"
}

@test "private-device-id cannot be combined with device-model" {
    export PRIVATE_DEVICE_ID="$DEVICE_UUID"
    export DEVICE_MODEL="latest"
    _assert_refused_before_upload "'private-device-id' cannot be combined with 'device-model'"
}

@test "private-device-id cannot be combined with os-version" {
    export PRIVATE_DEVICE_ID="$DEVICE_UUID"
    export OS_VERSION="17"
    _assert_refused_before_upload "'private-device-id' cannot be combined with 'os-version'"
}

@test "private-device-id cannot be combined with model-match" {
    export PRIVATE_DEVICE_ID="$DEVICE_UUID"
    export MODEL_MATCH="exact"
    _assert_refused_before_upload "'private-device-id' cannot be combined with 'model-match'"
}

@test "private-device-id cannot be combined with os-version-match" {
    export PRIVATE_DEVICE_ID="$DEVICE_UUID"
    export OS_VERSION_MATCH="similar"
    _assert_refused_before_upload "'private-device-id' cannot be combined with 'os-version-match'"
}

@test "whitespace-only device inputs do not conflict with private-device-id" {
    export PRIVATE_DEVICE_ID="$DEVICE_UUID"
    export DEVICE_MODEL="   "
    export DEVICES=$'\n\t'

    run bash "$ENTRYPOINT"

    assert_success
    run jq -e --arg id "$DEVICE_UUID" '.device == {physical: true, private_device_id: $id}' \
        "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "web: private-device-id is refused before registration" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://example.com"
    export PRIVATE_DEVICE_ID="$DEVICE_UUID"
    _assert_refused_before_upload "'private-device-id' is supported only for Android and iOS"
}

@test "chrome-extension: private-device-id is refused before upload" {
    export PLATFORM="chrome-extension"
    export BUNDLE_ID="my-extension"
    export BUILD_PATH="$BATS_TEST_TMPDIR/extension.zip"
    export FLOW_IDS=""
    export PRIVATE_DEVICE_ID="$DEVICE_UUID"
    touch "$BUILD_PATH"
    _assert_refused_before_upload "'private-device-id' is supported only for Android and iOS"
}
