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

_assert_refused_before_run() {
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "$1"
    refute_output --partial "Triggering flows"
}

_assert_run_device() {
    run bash "$ENTRYPOINT"
    assert_success
    run jq -e --argjson device "$1" '.device == $device and (has("devices") | not)' \
        "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}

_assert_run_devices() {
    run bash "$ENTRYPOINT"
    assert_success
    run jq -e --argjson devices "$1" '.devices == $devices and (has("device") | not)' \
        "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}
OTHER_UUID="7a2b9c1d-4e5f-4a6b-8c7d-9e0f1a2b3c4d"

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
    refute_output --partial "For a two-device flow, remove 'private-device' instead and name each private device in a devices entry."
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

@test "devices: a private_device_id entry is sent trimmed and lowercased, next to a shared device" {
    export DEVICES='[{"private_device_id": "  3F1C2A4E-9B7D-4C1A-8E2F-0A1B2C3D4E5F "}, {"physical": true, "model": "Pixel 10 Pro"}]'
    _assert_run_devices "[{\"private_device_id\": \"$DEVICE_UUID\"}, {\"physical\": true, \"model\": \"Pixel 10 Pro\"}]"
}

@test "ios devices: two private names are sent trimmed with case kept; physical true is allowed" {
    export PLATFORM="ios"
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/dummy.ipa"
    export DEVICES='[{"physical": true, "private_device_name": " QA iPhone 15 "}, {"private_device_name": "QA iPhone 16"}]'
    _assert_run_devices '[{"physical": true, "private_device_name": "QA iPhone 15"}, {"private_device_name": "QA iPhone 16"}]'
}

@test "devices: a shared Device 1 and a private Device 2 keep their order" {
    export DEVICES="[{\"physical\": true}, {\"private_device_id\": \"$OTHER_UUID\"}]"
    _assert_run_devices "$DEVICES"
}

@test "devices: an entry with both private_device_id and private_device_name is refused" {
    export DEVICES="[{\"private_device_id\": \"$DEVICE_UUID\", \"private_device_name\": \"QA Pixel\"}, {\"physical\": true}]"
    _assert_refused_before_run "a device may set private_device_id or private_device_name, not both"
}

@test "devices: a private entry refuses model, os_version, match, and physical false" {
    for extra in '"model": "Pixel 10 Pro"' '"os_version": "15"' '"match": {"model": "exact"}' '"physical": false'; do
        export DEVICES="[{\"private_device_id\": \"$DEVICE_UUID\", $extra}, {\"physical\": true}]"
        _assert_refused_before_run "a private device cannot set model, os_version, or match, or physical: false"
    done
}

@test "devices: a private_device_id that is not a UUID is refused" {
    export DEVICES='[{"private_device_id": "QA Pixel"}, {"physical": true}]'
    _assert_refused_before_run "private_device_id must be a device ID"
    for value in 123 null; do
        export DEVICES="[{\"private_device_id\": $value}, {\"physical\": true}]"
        _assert_refused_before_run "each device may only contain physical, model, os_version, match, private_device_id, and private_device_name"
    done
}

@test "devices: private_device_name limits" {
    export DEVICES='[{"private_device_name": " \t "}, {"physical": true}]'
    _assert_refused_before_run "private_device_name is blank"

    export DEVICES="[{\"private_device_name\": \"$(printf 'a%.0s' $(seq 1 101))\"}, {\"physical\": true}]"
    _assert_refused_before_run "private_device_name is longer than 100 characters"

    for udid in "00008110-001a2D3E4F56801E" "0123456789abcdefABCDEF0123456789abcdef01"; do
        export DEVICES="[{\"private_device_name\": \"$udid\"}, {\"physical\": true}]"
        _assert_refused_before_run "private_device_name looks like a UDID"
    done

    NAME=$(printf 'é%.0s' $(seq 1 100))
    export LC_ALL=C
    export DEVICES="[{\"private_device_name\": \"$NAME\"}, {\"physical\": true}]"
    _assert_run_devices "$DEVICES"
}

@test "devices: the same private device in both entries is refused" {
    export DEVICES="[{\"private_device_id\": \"$DEVICE_UUID\"}, {\"private_device_id\": \" 3F1C2A4E-9B7D-4C1A-8E2F-0A1B2C3D4E5F\"}]"
    _assert_refused_before_run "both devices name the same private device"

    export DEVICES='[{"private_device_name": "QA Pixel"}, {"private_device_name": " qa pixel"}]'
    _assert_refused_before_run "both devices name the same private device"
}

@test "devices: a private devices entry cannot be combined with location" {
    export DEVICES="[{\"private_device_id\": \"$DEVICE_UUID\"}, {\"physical\": true}]"
    export LOCATION="US"
    _assert_refused_before_run "A private device in 'devices' cannot be combined with 'location'."
    assert_output --partial "Private devices do not support a run location yet. Remove 'location' from this step."
}

@test "devices: location with a shared-only devices pair is not refused by the action" {
    export DEVICES='[{"physical": true}, {"physical": false}]'
    export LOCATION="US"

    run bash "$ENTRYPOINT"

    assert_success
    refute_output --partial "A private device in 'devices' cannot be combined with 'location'."
}

@test "devices: a private device cannot be paired with an emulator" {
    for partner in '{"model": "Pixel 9"}' '{"physical": false}'; do
        export DEVICES="[{\"private_device_id\": \"$DEVICE_UUID\"}, $partner]"
        _assert_refused_before_run "A private device can only be paired with another private device or a shared real device."
        assert_output --partial 'Set "physical": true on the other devices entry.'
    done
}

@test "private-device cannot be combined with a private devices entry" {
    export PRIVATE_DEVICE="$DEVICE_UUID"
    export DEVICES="[{\"private_device_id\": \"$OTHER_UUID\"}, {\"physical\": true}]"
    _assert_refused_before_upload "'private-device' cannot be combined with 'devices'"
    assert_output --partial "For a two-device flow, remove 'private-device' instead and name each private device in a devices entry."
}

@test "web: a private devices entry is ignored with the mobile-only warning" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://example.com"
    export DEVICES="[{\"private_device_id\": \"$DEVICE_UUID\"}, {\"physical\": true}]"

    run bash "$ENTRYPOINT"

    assert_success
    assert_output --partial "device selection inputs are mobile-only"
    run jq -e 'has("devices") | not' "$MOCK_CURL_CAPTURE_DIR/RUN_FLOWS.json"
    assert_success
}
