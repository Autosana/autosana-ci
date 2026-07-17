#!/usr/bin/env bats

# iOS keychain access-group remapping preference on confirm-upload.

setup() {
    load 'test_helper/common-setup'
    _common_setup
    export PLATFORM="ios"
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/dummy.ipa"
}

@test "ios ipa: remapping preference omitted by default" {
    run bash "$ENTRYPOINT"
    assert_success
    refute_output --partial '"ios_keychain_access_group_remapping_enabled"'
    assert_output --partial "using saved app preference"
}

@test "ios ipa: remapping preference included when enabled" {
    export IOS_KEYCHAIN_ACCESS_GROUP_REMAPPING_ENABLED="true"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial '"ios_keychain_access_group_remapping_enabled": true'
}

@test "ios ipa: remapping preference included when disabled" {
    export IOS_KEYCHAIN_ACCESS_GROUP_REMAPPING_ENABLED="false"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial '"ios_keychain_access_group_remapping_enabled": false'
}

@test "ios zip: remapping preference not sent for simulator builds" {
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/dummy.app.zip"
    export IOS_KEYCHAIN_ACCESS_GROUP_REMAPPING_ENABLED="true"
    run bash "$ENTRYPOINT"
    assert_success
    refute_output --partial '"ios_keychain_access_group_remapping_enabled"'
}

@test "android: remapping preference not sent" {
    export PLATFORM="android"
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/dummy.apk"
    export IOS_KEYCHAIN_ACCESS_GROUP_REMAPPING_ENABLED="true"
    run bash "$ENTRYPOINT"
    assert_success
    refute_output --partial '"ios_keychain_access_group_remapping_enabled"'
}
