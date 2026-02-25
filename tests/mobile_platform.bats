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
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "Upload completed successfully"
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
