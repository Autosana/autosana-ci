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

_assert_run_device() {
    run bash "$ENTRYPOINT"
    assert_success
    run jq -e --argjson device "$1" '.device == $device and (has("devices") | not)' \
        "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "android: a UUID private-device sends the ID, trimmed and lowercased" {
    export PRIVATE_DEVICE="  3F1C2A4E-9B7D-4C1A-8E2F-0A1B2C3D4E5F "
    _assert_run_device "{\"physical\": true, \"private_device_id\": \"$DEVICE_UUID\"}"
}

@test "ios: private-device accepts physical-device true" {
    export PLATFORM="ios"
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/dummy.ipa"
    export PHYSICAL_DEVICE="true"
    export PRIVATE_DEVICE="$DEVICE_UUID"
    _assert_run_device "{\"physical\": true, \"private_device_id\": \"$DEVICE_UUID\"}"
}

@test "a non-UUID private-device sends the name trimmed, with its case kept" {
    export PRIVATE_DEVICE=$'  QA Pixel 8 Pro \t'
    _assert_run_device '{"physical": true, "private_device_name": "QA Pixel 8 Pro"}'
}

@test "a UUID with a space inside it is sent as a name" {
    export PRIVATE_DEVICE="3f1c2a4e-9b7d-4c1a-8e2f 0a1b2c3d4e5f"
    _assert_run_device '{"physical": true, "private_device_name": "3f1c2a4e-9b7d-4c1a-8e2f 0a1b2c3d4e5f"}'
}

@test "a 100-character name is accepted, counting characters rather than bytes" {
    NAME=$(printf 'é%.0s' $(seq 1 100))
    export PRIVATE_DEVICE="$NAME"
    export LC_ALL=C
    _assert_run_device "{\"physical\": true, \"private_device_name\": \"$NAME\"}"
}

@test "a name longer than 100 characters is refused" {
    export PRIVATE_DEVICE=$(printf 'a%.0s' $(seq 1 101))
    _assert_refused_before_upload "'private-device' name is longer than 100 characters"
}

@test "a name with quotes and a backslash is sent escaped" {
    export PRIVATE_DEVICE=$'Amrit\'s "QA" \\ phone'
    _assert_run_device '{"physical": true, "private_device_name": "Amrit'\''s \"QA\" \\ phone"}'
}

@test "a name that contains hex is sent as a name" {
    export PRIVATE_DEVICE="Pixel 00008110-001A2D3E4F56801E"
    _assert_run_device '{"physical": true, "private_device_name": "Pixel 00008110-001A2D3E4F56801E"}'
}

@test "private-device refuses true and false" {
    for value in "true" " TRUE " "False"; do
        export PRIVATE_DEVICE="$value"
        _assert_refused_before_upload "private-device takes a device ID or name, not true/false."
    done
}

@test "private-device refuses a modern iOS UDID" {
    export PRIVATE_DEVICE="00008110-001a2D3E4F56801E"
    _assert_refused_before_upload "'private-device' looks like a UDID"
    assert_output --partial "A UDID is neither the device's ID nor its name."
}

@test "private-device refuses a legacy iOS UDID" {
    export PRIVATE_DEVICE="  0123456789abcdefABCDEF0123456789abcdef01 "
    _assert_refused_before_upload "'private-device' looks like a UDID"
}

@test "a whitespace-only private-device is refused" {
    export PRIVATE_DEVICE=$' \t '
    _assert_refused_before_upload "'private-device' is blank"
}

@test "flow-keys runs send flow_keys with the private device" {
    export FLOW_IDS=""
    export FLOW_KEYS="auth/login"
    export PRIVATE_DEVICE="$DEVICE_UUID"

    run bash "$ENTRYPOINT"

    assert_success
    run jq -e --arg id "$DEVICE_UUID" '
      .flow_keys == ["auth/login"]
      and (has("flow_ids") | not)
      and .device == {physical: true, private_device_id: $id}
    ' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

@test "upload-only step warns that private-device is ignored" {
    export FLOW_IDS=""
    export PRIVATE_DEVICE="QA Pixel"

    run bash "$ENTRYPOINT"

    assert_success
    assert_output --partial "⚠️  'private-device' applies only when tests are selected; ignoring it"
    [ ! -e "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json" ]
}

@test "private-device cannot be combined with location" {
    export PRIVATE_DEVICE="$DEVICE_UUID"
    export LOCATION="mx"
    _assert_refused_before_upload "'private-device' cannot be combined with 'location'"
}

@test "private-device cannot be combined with devices" {
    export PRIVATE_DEVICE="$DEVICE_UUID"
    export DEVICES='[{"physical": true}, {"physical": true}]'
    _assert_refused_before_upload "'private-device' cannot be combined with 'devices'"
}

@test "private-device cannot be combined with device-model" {
    export PRIVATE_DEVICE="QA Pixel"
    export DEVICE_MODEL="latest"
    _assert_refused_before_upload "'private-device' cannot be combined with 'device-model'"
}

@test "private-device cannot be combined with os-version" {
    export PRIVATE_DEVICE="$DEVICE_UUID"
    export OS_VERSION="17"
    _assert_refused_before_upload "'private-device' cannot be combined with 'os-version'"
}

@test "private-device cannot be combined with model-match" {
    export PRIVATE_DEVICE="$DEVICE_UUID"
    export MODEL_MATCH="exact"
    _assert_refused_before_upload "'private-device' cannot be combined with 'model-match'"
}

@test "private-device cannot be combined with os-version-match" {
    export PRIVATE_DEVICE="$DEVICE_UUID"
    export OS_VERSION_MATCH="similar"
    _assert_refused_before_upload "'private-device' cannot be combined with 'os-version-match'"
}

@test "whitespace-only device inputs do not conflict with private-device" {
    export PRIVATE_DEVICE="$DEVICE_UUID"
    export DEVICE_MODEL="   "
    export DEVICES=$'\n\t'
    _assert_run_device "{\"physical\": true, \"private_device_id\": \"$DEVICE_UUID\"}"
}

@test "web: private-device is refused before registration" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://example.com"
    export PRIVATE_DEVICE="$DEVICE_UUID"
    _assert_refused_before_upload "'private-device' is supported only for Android and iOS"
}

@test "chrome-extension: private-device is refused before upload" {
    export PLATFORM="chrome-extension"
    export BUNDLE_ID="my-extension"
    export BUILD_PATH="$BATS_TEST_TMPDIR/extension.zip"
    export FLOW_IDS=""
    export PRIVATE_DEVICE="$DEVICE_UUID"
    touch "$BUILD_PATH"
    _assert_refused_before_upload "'private-device' is supported only for Android and iOS"
}
