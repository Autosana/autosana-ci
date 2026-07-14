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

# --- Chrome extension validation ---

@test "chrome-extension missing BUNDLE_ID exits 1" {
    export PLATFORM="chrome-extension"
    export BUNDLE_ID=""
    export BUILD_PATH="$BATS_TEST_TMPDIR/extension.zip"
    touch "$BUILD_PATH"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Missing required inputs for chrome-extension"
}

@test "chrome-extension rejects non-zip build" {
    export PLATFORM="chrome-extension"
    export BUNDLE_ID="my-extension"
    export BUILD_PATH="$PROJECT_ROOT/tests/fixtures/dummy.apk"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "must be a .zip"
}

@test "valid chrome-extension inputs pass validation" {
    export PLATFORM="chrome-extension"
    export BUNDLE_ID="my-extension"
    export BUILD_PATH="$BATS_TEST_TMPDIR/extension.zip"
    touch "$BUILD_PATH"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "Chrome extension platform detected"
}

@test "chrome-extension accepts uppercase ZIP extension" {
    export PLATFORM="chrome-extension"
    export BUNDLE_ID="my-extension"
    export BUILD_PATH="$BATS_TEST_TMPDIR/extension.ZIP"
    touch "$BUILD_PATH"
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "Chrome extension platform detected"
}

@test "chrome-extension rejects direct test selectors before upload" {
    export PLATFORM="chrome-extension"
    export BUNDLE_ID="my-extension"
    export BUILD_PATH="$BATS_TEST_TMPDIR/extension.zip"
    touch "$BUILD_PATH"

    local selectors=("FLOW_IDS=flow-1" "SUITE_IDS=suite-1" "LABELS=smoke")
    for selector in "${selectors[@]}"; do
        export FLOW_IDS=""
        export SUITE_IDS=""
        export LABELS=""
        export "${selector?}"

        run bash "$ENTRYPOINT"
        assert_failure
        assert_output --partial "Chrome extension uploads cannot trigger tests directly"
        assert_output --partial "Upload and attach the extension, then run tests in a separate 'platform: web' Action step"
        refute_output --partial "Ensuring jq"
        refute_output --partial "Starting upload process"
    done
}

# --- Secret-safe diagnostics ---

@test "missing platform validation never logs API key material" {
    export AUTOSANA_KEY="autosana-super-secret-value"
    unset PLATFORM
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "AUTOSANA_KEY: SET"
    refute_output --partial "$AUTOSANA_KEY"
    refute_output --partial "autosana-su"
    refute_output --partial "chars"
}

@test "platform diagnostics never log API key material" {
    export AUTOSANA_KEY="autosana-super-secret-value"
    export PLATFORM="web"
    export APP_ID=""
    export URL="https://example.com"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "AUTOSANA_KEY: SET"
    refute_output --partial "$AUTOSANA_KEY"
    refute_output --partial "autosana-su"
    refute_output --partial "chars"
}

# --- Dependencies validation ---

@test "dependencies must be valid JSON before web registration" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://example.com"
    export FLOW_IDS="uuid-1"
    export DEPENDENCIES='["extension-app"'
    export MOCK_CURL_STATUS_UPLOAD_WEB=503
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "'dependencies' must be a valid JSON array"
    refute_output --partial "Ensuring jq"
    refute_output --partial "Registering web build"
}

@test "dependencies must be a JSON array before web registration" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://example.com"
    export FLOW_IDS="uuid-1"
    export DEPENDENCIES='{"app_id":"extension-app"}'
    export MOCK_CURL_STATUS_UPLOAD_WEB=503
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "'dependencies' must be a valid JSON array"
    refute_output --partial "Ensuring jq"
    refute_output --partial "Registering web build"
}

@test "whitespace-only dependencies is invalid when provided" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://example.com"
    export FLOW_IDS="uuid-1"
    export DEPENDENCIES="   "
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "'dependencies' must be a valid JSON array"
    refute_output --partial "Ensuring jq"
    refute_output --partial "Registering web build"
}

@test "dependencies reject invalid entry structures before jq setup" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://example.com"
    export FLOW_IDS="uuid-1"

    local invalid_dependencies=(
        '[123]'
        '[""]'
        '["not-a-uuid"]'
        '[{}]'
        '[{"app_id":""}]'
        '[{"app_id":"not-a-uuid"}]'
        '[{"app_id":"11111111-1111-1111-1111-111111111111","app_build_id":""}]'
        '[{"app_id":"11111111-1111-1111-1111-111111111111","app_build_id":"not-a-uuid"}]'
    )

    for dependencies in "${invalid_dependencies[@]}"; do
        export DEPENDENCIES="$dependencies"
        run bash "$ENTRYPOINT"
        assert_failure
        assert_output --partial "'dependencies' must be a valid JSON array"
        refute_output --partial "Ensuring jq"
        refute_output --partial "Registering web build"
    done
}

@test "missing dependency validator runtime has a distinct preflight error" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://example.com"
    export FLOW_IDS="uuid-1"
    export DEPENDENCIES='[]'
    export PYTHON3_BIN="definitely-missing-python3"

    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "Dependency validation requires Python 3"
    assert_output --partial "Set PYTHON3_BIN to an available Python 3 executable"
    refute_output --partial "'dependencies' must be a valid JSON array"
    refute_output --partial "Ensuring jq"
    refute_output --partial "Registering web build"
}

@test "mobile rejects provided dependencies before upload" {
    export DEPENDENCIES='[]'
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "'dependencies' is supported only for web flow, suite, or label runs"
    refute_output --partial "Starting upload process"
}

@test "chrome-extension rejects provided dependencies before upload" {
    export PLATFORM="chrome-extension"
    export BUNDLE_ID="my-extension"
    export BUILD_PATH="$BATS_TEST_TMPDIR/extension.zip"
    export DEPENDENCIES='["extension-app"]'
    touch "$BUILD_PATH"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "'dependencies' is supported only for web flow, suite, or label runs"
    refute_output --partial "Starting upload process"
}

@test "web registration without a direct run rejects dependencies" {
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://example.com"
    export DEPENDENCIES='[]'
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "'dependencies' requires suite-ids, flow-ids, or labels"
    refute_output --partial "Ensuring jq"
    refute_output --partial "Registering web build"
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

@test "android-arm64-gplay platform passes validation" {
    export PLATFORM="android-arm64-gplay"
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
