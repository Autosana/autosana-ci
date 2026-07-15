#!/usr/bin/env bats

# iOS keychain support flag on confirm-upload for .ipa builds.

setup() {
    load 'test_helper/common-setup'
    _common_setup
    export PLATFORM="ios"
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/dummy.ipa"
}

@test "ios ipa: ios_keychain_support included by default" {
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial '"ios_keychain_support": true'
    assert_output --partial "iOS keychain support: enabled"
}

@test "ios ipa: ios_keychain_support omitted when disabled" {
    export IOS_KEYCHAIN_SUPPORT="false"
    run bash "$ENTRYPOINT"
    assert_success
    refute_output --partial '"ios_keychain_support"'
}

@test "ios zip: ios_keychain_support not sent for simulator builds" {
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/dummy.app.zip"
    run bash "$ENTRYPOINT"
    assert_success
    refute_output --partial '"ios_keychain_support"'
}

@test "android: ios_keychain_support not sent" {
    export PLATFORM="android"
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/dummy.apk"
    run bash "$ENTRYPOINT"
    assert_success
    refute_output --partial '"ios_keychain_support"'
}
