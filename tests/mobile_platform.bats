#!/usr/bin/env bats

setup() {
    load 'test_helper/common-setup'
    _common_setup
    # Defaults are already android with valid inputs
}

@test "successful android upload" {
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "Upload completed successfully"
}

@test "successful ios upload" {
    export PLATFORM="ios"
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/dummy.app.zip"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "Upload completed successfully"
}

@test "ios .ipa is reported as a real-device build" {
    export PLATFORM="ios"
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/dummy.ipa"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "iOS build type: real device (.ipa)"
    assert_output --partial "Upload completed successfully"
}

@test "ios zipped .app is reported as a simulator build" {
    export PLATFORM="ios"
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/dummy.app.zip"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "iOS build type: simulator"
    assert_output --partial "Upload a .ipa to test on physical devices"
}

@test "android upload does not print iOS build type" {
    run bash "$ENTRYPOINT"
    assert_success
    refute_output --partial "iOS build type"
}

@test "start-upload returns HTTP 500" {
    export MOCK_CURL_STATUS_START_UPLOAD=500
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "API request failed with HTTP status 500"
}

@test "start-upload returns invalid JSON" {
    export MOCK_CURL_BODY_START_UPLOAD="garbage"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "API returned invalid JSON"
}

@test "start-upload returns null upload_url" {
    export MOCK_CURL_BODY_START_UPLOAD='{"upload_url":null,"file_path":"x"}'
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Failed to retrieve upload URL"
}

@test "build file not found" {
    export BUILD_PATH="/nonexistent/path/app.apk"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Build file not found"
}

@test "S3 upload returns HTTP error" {
    export MOCK_CURL_STATUS_UPLOAD_FILE=403
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Upload failed with HTTP error"
}

@test "confirm-upload returns HTTP 500" {
    export MOCK_CURL_STATUS_CONFIRM_UPLOAD=500
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Confirm upload API request failed with HTTP status 500"
}

@test "confirm-upload returns invalid JSON" {
    export MOCK_CURL_BODY_CONFIRM_UPLOAD="garbage"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Confirm upload API returned invalid JSON"
}

@test "confirm-upload returns error detail" {
    export MOCK_CURL_BODY_CONFIRM_UPLOAD='{"detail":"Duplicate upload"}'
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Duplicate upload"
}

@test "success summary includes bundle ID and platform" {
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "Bundle ID: com.example.app"
    assert_output --partial "Platform: android"
}

@test "mobile platform does not enter web flow" {
    run bash "$ENTRYPOINT"
    assert_success
    refute_output --partial "Starting web URL registration"
}

@test "environment variable is passed in payload" {
    export ENVIRONMENT="staging"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial '"environment": "staging"'
}

# --- Build checks before upload ---

@test "an .aab names its own package" {
    export BUNDLE_ID=""
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/shopper.aab"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "Build's bundle ID: com.acme.shopper"
}

@test "an android file that isn't a build is refused before upload" {
    export BUILD_PATH="$BATS_TEST_TMPDIR/app-release.apk"
    echo "<Error>Service Unavailable</Error>" > "$BUILD_PATH"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "isn't an app build"
    refute_output --partial "Starting upload"
}

@test "an android zip without a manifest is refused" {
    export BUILD_PATH="$BATS_TEST_TMPDIR/app-release.apk"
    (cd "$BATS_TEST_TMPDIR" && echo dex > classes.dex && python3 -c "import zipfile; zipfile.ZipFile('app-release.apk', 'w').write('classes.dex')")
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "no AndroidManifest.xml"
}

@test "a build of another app is refused" {
    export BUNDLE_ID="com.example.other"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "The build's bundle ID is com.example.app, but bundle-id is com.example.other."
}

@test "an ios simulator build with only Intel code is refused" {
    export PLATFORM="ios"
    export BUNDLE_ID=""
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/intel-app.zip"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "only has Intel (x86_64) code"
}

@test "an ios device build in a zip is refused" {
    export PLATFORM="ios"
    export BUILD_PATH="$BATS_TEST_TMPDIR/device.app.zip"
    python3 - "$BUILD_PATH" <<'PY'
import plistlib, sys, zipfile
info = plistlib.dumps({"CFBundleIdentifier": "com.example.app", "DTPlatformName": "iphoneos"})
zipfile.ZipFile(sys.argv[1], "w").writestr("Dummy.app/Info.plist", info)
PY
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "This is a device build"
}

@test "an ios gzip tarball goes ahead unchecked" {
    export PLATFORM="ios"
    export BUILD_PATH="$BATS_TEST_TMPDIR/expo-build.zip"
    printf '\x1f\x8b\x08\x00gzip tarball' > "$BUILD_PATH"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "Upload completed successfully"
}
