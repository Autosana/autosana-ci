#!/usr/bin/env bats

setup() {
    load 'test_helper/common-setup'
    _common_setup
}

# --- Missing required inputs ---

@test "missing AUTOSANA_KEY exits 1" {
    unset AUTOSANA_KEY
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Missing required inputs"
}

@test "missing PLATFORM exits 1" {
    unset PLATFORM
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Missing required inputs"
}

@test "both AUTOSANA_KEY and PLATFORM missing exits 1" {
    unset AUTOSANA_KEY
    unset PLATFORM
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Missing required inputs"
}

# --- Invalid platform ---

@test "invalid platform exits 1" {
    export PLATFORM="windows"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Invalid platform"
}

# --- Web platform validation ---

@test "web platform missing APP_ID exits 1" {
    export PLATFORM="web"
    export APP_ID=""
    export URL="https://example.com"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Missing required inputs for web"
}

@test "web platform missing URL exits 1" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL=""
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Missing required inputs for web"
}

@test "web platform invalid APP_ID with uppercase exits 1" {
    export PLATFORM="web"
    export APP_ID="My-App"
    export URL="https://example.com"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Invalid app-id format"
}

@test "web platform invalid APP_ID with underscores exits 1" {
    export PLATFORM="web"
    export APP_ID="my_app"
    export URL="https://example.com"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Invalid app-id format"
}

@test "web platform invalid APP_ID with spaces exits 1" {
    export PLATFORM="web"
    export APP_ID="my app"
    export URL="https://example.com"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Invalid app-id format"
}

@test "web platform invalid URL format exits 1" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="ftp://bad.example.com"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Invalid URL format"
}

# --- Mobile platform validation ---

@test "android platform missing BUNDLE_ID exits 1" {
    export PLATFORM="android"
    export BUNDLE_ID=""
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Missing required inputs for mobile"
}

@test "android platform missing BUILD_PATH exits 1" {
    export PLATFORM="android"
    export BUILD_PATH=""
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Missing required inputs for mobile"
}

@test "ios platform missing BUNDLE_ID exits 1" {
    export PLATFORM="ios"
    export BUNDLE_ID=""
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Missing required inputs for mobile"
}

@test "ios platform missing BUILD_PATH exits 1" {
    export PLATFORM="ios"
    export BUILD_PATH=""
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Missing required inputs for mobile"
}

# --- Valid inputs pass validation ---

@test "valid web inputs pass validation" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://example.com"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "All required environment variables are set"
}

@test "valid android inputs pass validation" {
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "All required environment variables are set"
}

@test "valid ios inputs pass validation" {
    export PLATFORM="ios"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "All required environment variables are set"
}

@test "APP_ID with numbers and hyphens is valid" {
    export PLATFORM="web"
    export APP_ID="preview-app-123"
    export URL="https://example.com"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "All required environment variables are set"
}

@test "single word APP_ID is valid" {
    export PLATFORM="web"
    export APP_ID="staging"
    export URL="https://example.com"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "All required environment variables are set"
}

@test "http URL is valid" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="http://localhost:3000"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "All required environment variables are set"
}
