#!/usr/bin/env bats

setup() {
    load 'test_helper/common-setup'
    _common_setup
    # Default to web platform for these tests
    export PLATFORM="web"
    export APP_ID="my-app"
    export URL="https://preview.example.com"
}

@test "successful web registration" {
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "Web URL registered successfully"
}

@test "web API returns HTTP 500" {
    export MOCK_CURL_STATUS_UPLOAD_WEB=500
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "API request failed with HTTP status 500"
}

@test "web API returns invalid JSON" {
    export MOCK_CURL_BODY_UPLOAD_WEB="not-valid-json"
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "API returned invalid JSON"
}

@test "web API returns error detail" {
    export MOCK_CURL_BODY_UPLOAD_WEB='{"detail":"API key invalid"}'
    run bash "$ENTRYPOINT"
    assert_failure
    assert_output --partial "API key invalid"
}

@test "web registration payload includes correct fields" {
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial '"app_id"'
    assert_output --partial '"url"'
    assert_output --partial '"commit_sha"'
    assert_output --partial '"branch_name"'
    assert_output --partial '"repo_full_name"'
}

@test "web success summary includes app ID and URL" {
    run bash "$ENTRYPOINT"
    assert_success
    assert_output --partial "App ID: my-app"
    assert_output --partial "URL: https://preview.example.com"
}

@test "web platform does not enter mobile flow" {
    run bash "$ENTRYPOINT"
    assert_success
    refute_output --partial "Starting upload process"
}
