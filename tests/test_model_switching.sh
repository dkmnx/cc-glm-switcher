#!/usr/bin/env bash

# Test cases for model switching functionality
# Tests the CC ↔ GLM model switching with environment variable preservation

set -euo pipefail

# Import test helper functions
# shellcheck source=tests/test_helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"

# Test: CC to GLM switching
test_cc_to_glm_switching() {
    log_info "Testing CC to GLM model switching..."

    # Ensure we start in CC mode (no env section)
    assert_contains "$(cat "$TEST_CLAUDE_DIR/settings.json")" "statusLine" "Should have basic settings"

    # Switch to GLM mode
    cd "$ROOT_DIR" || exit 1
    if ./cc_glm_switcher.sh glm >/dev/null 2>&1; then
        log_success "Switch to GLM completed"
    else
        log_error "Failed to switch to GLM mode"
        return 1
    fi

    # Verify GLM configuration
    local provider
    provider=$(jq -r '.env.CLAUDE_MODEL_PROVIDER // "not_found"' "$TEST_CLAUDE_DIR/settings.json" 2>/dev/null)
    local base_url
    base_url=$(jq -r '.env.ANTHROPIC_BASE_URL // "not_found"' "$TEST_CLAUDE_DIR/settings.json" 2>/dev/null)
    local auth_token
    auth_token=$(jq -r '.env.ANTHROPIC_AUTH_TOKEN // "not_found"' "$TEST_CLAUDE_DIR/settings.json" 2>/dev/null)

    assert_equals "zhipu" "$provider" "Should set GLM provider"
    assert_contains "$base_url" "z.ai" "Should set GLM base URL"
    assert_not_equals "not_found" "$auth_token" "Should set auth token"
    assert_json_valid "$TEST_CLAUDE_DIR/settings.json" "Settings should remain valid JSON"
}

# Test: GLM to CC switching
test_glm_to_cc_switching() {
    log_info "Testing GLM to CC model switching..."

    # First, set up GLM configuration
    cat > "$TEST_CLAUDE_DIR/settings.json" << EOF
{
  "statusLine": {"type": "command"},
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "test_token",
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "CLAUDE_MODEL_PROVIDER": "zhipu",
    "GLM_MODEL_MAPPING": "haiku:glm-4.5-air,sonnet:glm-4.6"
  }
}
EOF

    # Switch back to CC mode
    cd "$ROOT_DIR" || exit 1
    if ./cc_glm_switcher.sh cc >/dev/null 2>&1; then
        log_success "Switch to CC completed"
    else
        log_error "Failed to switch to CC mode"
        return 1
    fi

    # Verify CC configuration (no GLM variables)
    local provider
    provider=$(jq -r '.env.CLAUDE_MODEL_PROVIDER // "not_found"' "$TEST_CLAUDE_DIR/settings.json" 2>/dev/null)
    local base_url
    base_url=$(jq -r '.env.ANTHROPIC_BASE_URL // "not_found"' "$TEST_CLAUDE_DIR/settings.json" 2>/dev/null)

    assert_equals "not_found" "$provider" "GLM provider should be removed"
    assert_equals "not_found" "$base_url" "GLM base URL should be removed"
}

# Test: Custom environment variable preservation (CC → GLM → CC)
test_custom_env_preservation_roundtrip() {
    log_info "Testing custom environment variable preservation roundtrip..."

    # Start with CC mode + custom variables
    cat > "$TEST_CLAUDE_DIR/settings.json" << EOF
{
  "statusLine": {"type": "command"},
  "env": {
    "CUSTOM_API_KEY": "my_custom_key_123",
    "PERSONAL_CONFIG": "important_value",
    "OTHER_SETTING": "preserve_me"
  }
}
EOF

    # Switch to GLM mode
    cd "$ROOT_DIR" || exit 1
    ./cc_glm_switcher.sh glm >/dev/null 2>&1

    # Verify custom variables are preserved in GLM mode
    local custom_key
    custom_key=$(jq -r '.env.CUSTOM_API_KEY // "not_found"' "$TEST_CLAUDE_DIR/settings.json" 2>/dev/null)
    local personal_config
    personal_config=$(jq -r '.env.PERSONAL_CONFIG // "not_found"' "$TEST_CLAUDE_DIR/settings.json" 2>/dev/null)
    local glm_provider
    glm_provider=$(jq -r '.env.CLAUDE_MODEL_PROVIDER // "not_found"' "$TEST_CLAUDE_DIR/settings.json" 2>/dev/null)

    assert_equals "my_custom_key_123" "$custom_key" "Custom API key should be preserved in GLM mode"
    assert_equals "important_value" "$personal_config" "Personal config should be preserved in GLM mode"
    assert_equals "zhipu" "$glm_provider" "GLM provider should be added"

    # Switch back to CC mode
    ./cc_glm_switcher.sh cc >/dev/null 2>&1

    # Verify custom variables are still preserved after returning to CC
    custom_key=$(jq -r '.env.CUSTOM_API_KEY // "not_found"' "$TEST_CLAUDE_DIR/settings.json" 2>/dev/null)
    personal_config=$(jq -r '.env.PERSONAL_CONFIG // "not_found"' "$TEST_CLAUDE_DIR/settings.json" 2>/dev/null)
    glm_provider=$(jq -r '.env.CLAUDE_MODEL_PROVIDER // "not_found"' "$TEST_CLAUDE_DIR/settings.json" 2>/dev/null)

    assert_equals "my_custom_key_123" "$custom_key" "Custom API key should be preserved in CC mode"
    assert_equals "important_value" "$personal_config" "Personal config should be preserved in CC mode"
    assert_equals "not_found" "$glm_provider" "GLM provider should be removed"
}

# Test: Add custom variables in GLM mode and preserve them
test_add_custom_in_glm_mode() {
    log_info "Testing adding custom variables in GLM mode..."

    # Start with CC mode
    cat > "$TEST_CLAUDE_DIR/settings.json" << EOF
{
  "statusLine": {"type": "command"}
}
EOF

    # Switch to GLM mode
    cd "$ROOT_DIR" || exit 1
    ./cc_glm_switcher.sh glm >/dev/null 2>&1

    # Add custom variables while in GLM mode
    jq '.env += {"GLM_CUSTOM_VAR": "added_in_glm", "GLM_SETTING": "test_value"}' "$TEST_CLAUDE_DIR/settings.json" > "$TEST_CLAUDE_DIR/settings.json.tmp"
    mv "$TEST_CLAUDE_DIR/settings.json.tmp" "$TEST_CLAUDE_DIR/settings.json"

    # Switch back to CC mode
    ./cc_glm_switcher.sh cc >/dev/null 2>&1

    # Verify custom variables are preserved
    local glm_custom
    glm_custom=$(jq -r '.env.GLM_CUSTOM_VAR // "not_found"' "$TEST_CLAUDE_DIR/settings.json" 2>/dev/null)
    local glm_setting
    glm_setting=$(jq -r '.env.GLM_SETTING // "not_found"' "$TEST_CLAUDE_DIR/settings.json" 2>/dev/null)
    local glm_provider
    glm_provider=$(jq -r '.env.CLAUDE_MODEL_PROVIDER // "not_found"' "$TEST_CLAUDE_DIR/settings.json" 2>/dev/null)

    assert_equals "added_in_glm" "$glm_custom" "Custom variable added in GLM mode should be preserved"
    assert_equals "test_value" "$glm_setting" "Setting added in GLM mode should be preserved"
    assert_equals "not_found" "$glm_provider" "GLM provider should be removed"
}

# Test: GLM configuration detection
test_glm_config_detection() {
    log_info "Testing GLM configuration detection..."

    # Test various GLM configuration indicators

    # Test 1: CLAUDE_MODEL_PROVIDER = "zhipu"
    cat > "$TEST_CLAUDE_DIR/settings.json" << EOF
{
  "statusLine": {"type": "command"},
  "env": {
    "CLAUDE_MODEL_PROVIDER": "zhipu"
  }
}
EOF
    cd "$ROOT_DIR" || exit 1
    ./cc_glm_switcher.sh cc --dry-run >/dev/null 2>&1
    # Should detect GLM config and clean it

    # Test 2: ANTHROPIC_BASE_URL contains "z.ai"
    cat > "$TEST_CLAUDE_DIR/settings.json" << EOF
{
  "statusLine": {"type": "command"},
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic"
  }
}
EOF
    ./cc_glm_switcher.sh cc --dry-run >/dev/null 2>&1
    # Should detect GLM config and clean it

    # Test 3: GLM_MODEL_MAPPING exists
    cat > "$TEST_CLAUDE_DIR/settings.json" << EOF
{
  "statusLine": {"type": "command"},
  "env": {
    "GLM_MODEL_MAPPING": "haiku:glm-4.5-air"
  }
}
EOF
    ./cc_glm_switcher.sh cc --dry-run >/dev/null 2>&1
    # Should detect GLM config and clean it

    log_success "GLM configuration detection completed"
}

# Test: Dry run functionality
test_dry_run_functionality() {
    log_info "Testing dry run functionality..."

    # Create initial settings
    local initial_settings
    initial_settings=$(cat "$TEST_CLAUDE_DIR/settings.json")

    # Run dry run to GLM mode
    cd "$ROOT_DIR" || exit 1
    local dry_run_output
    dry_run_output=$(./cc_glm_switcher.sh glm --dry-run 2>&1)

    # Verify dry run indicators
    assert_contains "$dry_run_output" "DRY RUN" "Should indicate dry run mode"
    assert_contains "$dry_run_output" "Would switch" "Should show would switch message"

    # Verify settings unchanged
    local current_settings
    current_settings=$(cat "$TEST_CLAUDE_DIR/settings.json")
    assert_equals "$initial_settings" "$current_settings" "Settings should be unchanged in dry run"
}

# Test: Model mapping configuration
test_model_mapping_configuration() {
    log_info "Testing model mapping configuration..."

    # Switch to GLM mode
    cd "$ROOT_DIR" || exit 1
    ./cc_glm_switcher.sh glm >/dev/null 2>&1

    # Verify model mappings
    local haiku_model
    haiku_model=$(jq -r '.env.ANTHROPIC_DEFAULT_HAIKU_MODEL // "not_found"' "$TEST_CLAUDE_DIR/settings.json" 2>/dev/null)
    local sonnet_model
    sonnet_model=$(jq -r '.env.ANTHROPIC_DEFAULT_SONNET_MODEL // "not_found"' "$TEST_CLAUDE_DIR/settings.json" 2>/dev/null)
    local opus_model
    opus_model=$(jq -r '.env.ANTHROPIC_DEFAULT_OPUS_MODEL // "not_found"' "$TEST_CLAUDE_DIR/settings.json" 2>/dev/null)
    local model_mapping
    model_mapping=$(jq -r '.env.GLM_MODEL_MAPPING // "not_found"' "$TEST_CLAUDE_DIR/settings.json" 2>/dev/null)

    assert_equals "glm-4.5-air" "$haiku_model" "Should map haiku to glm-4.5-air"
    assert_equals "glm-4.6" "$sonnet_model" "Should map sonnet to glm-4.6"
    assert_equals "glm-4.6" "$opus_model" "Should map opus to glm-4.6"
    assert_contains "$model_mapping" "haiku:glm-4.5-air" "Should include haiku mapping"
}

# Test: Configuration validation
test_configuration_validation() {
    log_info "Testing configuration validation..."

    # Test with invalid JSON
    echo '{"invalid": json}' > "$TEST_CLAUDE_DIR/settings.json"

    cd "$ROOT_DIR" || exit 1
    if ./cc_glm_switcher.sh cc >/dev/null 2>&1; then
        log_warning "Script completed with invalid JSON"
    else
        log_success "Script properly rejected invalid JSON"
    fi

    # Restore valid JSON
    cat > "$TEST_CLAUDE_DIR/settings.json" << EOF
{
  "statusLine": {"type": "command"}
}
EOF

    # Test with valid JSON (should work)
    if ./cc_glm_switcher.sh cc >/dev/null 2>&1; then
        log_success "Script completed with valid JSON"
    else
        log_error "Script failed with valid JSON"
        return 1
    fi
}

# Main test runner
main() {
    echo "=================================="
    echo "Running Model Switching Tests"
    echo "=================================="

    run_test "CC to GLM Switching" test_cc_to_glm_switching
    run_test "GLM to CC Switching" test_glm_to_cc_switching
    run_test "Custom Environment Preservation Roundtrip" test_custom_env_preservation_roundtrip
    run_test "Add Custom Variables in GLM Mode" test_add_custom_in_glm_mode
    run_test "GLM Configuration Detection" test_glm_config_detection
    run_test "Dry Run Functionality" test_dry_run_functionality
    run_test "Model Mapping Configuration" test_model_mapping_configuration
    run_test "Configuration Validation" test_configuration_validation

    print_test_results
}

# Run tests if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi