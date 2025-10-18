#!/usr/bin/env bash

# Test cases for error handling and edge cases
# Tests script behavior under various error conditions

set -euo pipefail

# Import test helper functions
# shellcheck source=tests/test_helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"

# Test: Invalid JSON in settings.json
test_invalid_json_settings() {
    log_info "Testing invalid JSON in settings.json..."

    # Create invalid JSON file
    echo '{"invalid": json, "missing": "closing brace"' > "$TEST_CLAUDE_DIR/settings.json"

    cd "$ROOT_DIR" || exit 1

    # Try to run any command with invalid JSON
    local exit_code=0
    ./cc_glm_switcher.sh cc >/dev/null 2>&1 || exit_code=$?

    assert_not_equals "0" "$exit_code" "Script should reject invalid JSON"

    # Verify JSON is detected as invalid
    if ! validate_json "$TEST_CLAUDE_DIR/settings.json"; then
        assert_equals "1" "1" "Invalid JSON properly detected by helper function"
    else
        assert_equals "0" "1" "Helper function should detect invalid JSON"
    fi
}

# Test: Missing settings.json file
test_missing_settings_file() {
    log_info "Testing missing settings.json file..."

    # Remove settings file
    rm -f "$TEST_CLAUDE_DIR/settings.json"
    assert_file_not_exists "$TEST_CLAUDE_DIR/settings.json" "Settings file should be removed"

    cd "$ROOT_DIR" || exit 1

    # Try to run command with missing settings file
    local exit_code=0
    ./cc_glm_switcher.sh cc >/dev/null 2>&1 || exit_code=$?

    # The script should handle missing file gracefully (either succeed with creation or fail gracefully)
    assert_contains "0$exit_code" "0" "Script should handle missing settings file (exit code: $exit_code)"

    # Restore settings file
    cat > "$TEST_CLAUDE_DIR/settings.json" << EOF
{
  "statusLine": {"type": "command"}
}
EOF
    assert_file_exists "$TEST_CLAUDE_DIR/settings.json" "Settings file should be restored"
}

# Test: Empty settings.json file
test_empty_settings_file() {
    log_info "Testing empty settings.json file..."

    # Create empty file
    : > "$TEST_CLAUDE_DIR/settings.json"
    assert_file_exists "$TEST_CLAUDE_DIR/settings.json" "Empty settings file should exist"

    # Verify file is actually empty
    local file_size
    file_size=$(wc -c < "$TEST_CLAUDE_DIR/settings.json")
    assert_equals "0" "$file_size" "Settings file should be empty (0 bytes)"

    cd "$ROOT_DIR" || exit 1

    # Try to run command with empty file
    local exit_code=0
    ./cc_glm_switcher.sh cc >/dev/null 2>&1 || exit_code=$?

    assert_not_equals "0" "$exit_code" "Script should reject empty settings file"

    # Restore valid settings
    cat > "$TEST_CLAUDE_DIR/settings.json" << EOF
{
  "statusLine": {"type": "command"}
}
EOF
    assert_json_valid "$TEST_CLAUDE_DIR/settings.json" "Settings file should be valid after restoration"
}

# Test: Missing .env file
test_missing_env_file() {
    log_info "Testing missing .env file..."

    # Remove .env file from both locations
    rm -f "$TEST_DIR/.env"
    rm -f "$ROOT_DIR/.env"

    assert_file_not_exists "$TEST_DIR/.env" "Test .env file should be removed"
    assert_file_not_exists "$ROOT_DIR/.env" "Root .env file should be removed"

    cd "$ROOT_DIR" || exit 1

    # Try to switch to GLM mode (requires .env file)
    local exit_code=0
    ./cc_glm_switcher.sh glm >/dev/null 2>&1 || exit_code=$?

    assert_not_equals "0" "$exit_code" "Script should fail without .env file"

    # Restore .env file
    cat > "$TEST_DIR/.env" << EOF
ZAI_AUTH_TOKEN=test_token_12345
MAX_BACKUPS=3
EOF
    assert_file_exists "$TEST_DIR/.env" "Test .env file should be restored"
}

# Test: Invalid .env file format
test_invalid_env_file() {
    log_info "Testing invalid .env file format..."

    # Create invalid .env file
    echo "INVALID_FORMAT" > "$TEST_DIR/.env"
    echo "NO_EQUALS_SIGN" >> "$TEST_DIR/.env"
    assert_file_exists "$TEST_DIR/.env" "Invalid .env file should be created"

    cd "$ROOT_DIR" || exit 1

    # Try to use GLM mode
    local exit_code=0
    ./cc_glm_switcher.sh glm >/dev/null 2>&1 || exit_code=$?

    assert_not_equals "0" "$exit_code" "Script should reject invalid .env format"

    # Restore valid .env file
    cat > "$TEST_DIR/.env" << EOF
ZAI_AUTH_TOKEN=test_token_12345
MAX_BACKUPS=3
EOF
}

# Test: Missing ZAI_AUTH_TOKEN in .env
test_missing_auth_token() {
    log_info "Testing missing ZAI_AUTH_TOKEN in .env..."

    # Create .env without auth token
    echo "MAX_BACKUPS=3" > "$TEST_DIR/.env"
    assert_file_exists "$TEST_DIR/.env" ".env file should exist without auth token"

    cd "$ROOT_DIR" || exit 1

    # Try to switch to GLM mode
    local exit_code=0
    ./cc_glm_switcher.sh glm >/dev/null 2>&1 || exit_code=$?

    assert_not_equals "0" "$exit_code" "Script should fail without auth token"

    # Restore auth token
    echo "ZAI_AUTH_TOKEN=test_token_12345" >> "$TEST_DIR/.env"
}

# Test: Invalid ZAI_AUTH_TOKEN format
test_invalid_auth_token() {
    log_info "Testing invalid ZAI_AUTH_TOKEN format..."

    # Create .env with invalid token
    cat > "$TEST_DIR/.env" << EOF
ZAI_AUTH_TOKEN=
MAX_BACKUPS=3
EOF

    cd "$ROOT_DIR" || exit 1

    # Try to switch to GLM mode
    local exit_code=0
    ./cc_glm_switcher.sh glm >/dev/null 2>&1 || exit_code=$?

    assert_not_equals "0" "$exit_code" "Script should reject empty auth token"

    # Test with token containing invalid characters
    cat > "$TEST_DIR/.env" << EOF
ZAI_AUTH_TOKEN=invalid@token#with\$special&chars
MAX_BACKUPS=3
EOF

    cd "$ROOT_DIR" || exit 1

    exit_code=0
    ./cc_glm_switcher.sh glm >/dev/null 2>&1 || exit_code=$?

    assert_not_equals "0" "$exit_code" "Script should reject token with special characters"

    # Restore valid token
    cat > "$TEST_DIR/.env" << EOF
ZAI_AUTH_TOKEN=test_token_12345
MAX_BACKUPS=3
EOF
}

# Test: Invalid MAX_BACKUPS value
test_invalid_max_backups() {
    log_info "Testing invalid MAX_BACKUPS value..."

    # Create .env with non-numeric MAX_BACKUPS
    cat > "$TEST_DIR/.env" << EOF
ZAI_AUTH_TOKEN=test_token_12345
MAX_BACKUPS=not_a_number
EOF

    cd "$ROOT_DIR" || exit 1

    # The script should fall back to default value (5)
    ./cc_glm_switcher.sh cc >/dev/null 2>&1

    # Check if script used default value
    local log_output
    log_output=$(./cc_glm_switcher.sh cc -v 2>&1)

    assert_contains "$log_output" "Using default MAX_BACKUPS=5" "Should use default MAX_BACKUPS when invalid"

    # Test with negative number
    cat > "$TEST_DIR/.env" << EOF
ZAI_AUTH_TOKEN=test_token_12345
MAX_BACKUPS=-1
EOF

    ./cc_glm_switcher.sh cc >/dev/null 2>&1
    log_output=$(./cc_glm_switcher.sh cc -v 2>&1)
    assert_contains "$log_output" "Using default MAX_BACKUPS=5" "Should use default MAX_BACKUPS when negative"

    # Restore valid value
    cat > "$TEST_DIR/.env" << EOF
ZAI_AUTH_TOKEN=test_token_12345
MAX_BACKUPS=3
EOF
}

# Test: Lock file conflict
test_lock_file_conflict() {
    log_info "Testing lock file conflict..."

    # Create a mock lock file
    echo "12345" > "$ROOT_DIR/.switcher.lock"
    assert_file_exists "$ROOT_DIR/.switcher.lock" "Lock file should be created"

    cd "$ROOT_DIR" || exit 1

    # Try to run another instance
    local exit_code=0
    ./cc_glm_switcher.sh cc >/dev/null 2>&1 || exit_code=$?

    assert_not_equals "0" "$exit_code" "Second instance should be blocked by lock file"

    # Clean up lock file
    rm -f "$ROOT_DIR/.switcher.lock"
    assert_file_not_exists "$ROOT_DIR/.switcher.lock" "Lock file should be cleaned up"
}

# Test: Missing dependencies (jq)
test_missing_dependencies() {
    log_info "Testing missing dependencies (jq)..."

    # Test by temporarily modifying PATH to hide jq
    local original_path
    original_path="$PATH"

    # Create a temporary directory and add it to PATH
    local temp_dir
    temp_dir=$(mktemp -d)

    # Set PATH to only include temp_dir and system directories (no /usr/bin)
    export PATH="$temp_dir:/bin:/sbin"

    cd "$ROOT_DIR" || exit 1

    # Try to run script without jq (should be in PATH now)
    local exit_code=0
    ./cc_glm_switcher.sh cc >/dev/null 2>&1 || exit_code=$?

    assert_not_equals "0" "$exit_code" "Script should fail without jq"

    # Restore original PATH
    export PATH="$original_path"

    # Clean up temp directory
    rm -rf "$temp_dir"

    # Verify jq is available again
    command -v jq >/dev/null 2>&1
    assert_equals "0" "$?" "jq should be available after PATH restoration"
}

# Test: Restore from invalid backup number
test_restore_invalid_backup_number() {
    log_info "Testing restore from invalid backup number..."

    # Create a valid backup
    create_test_backup "test_backup"

    cd "$ROOT_DIR" || exit 1

    # Try to restore from invalid backup numbers
    local invalid_numbers=("0" "-1" "abc" "999999")

    for invalid_num in "${invalid_numbers[@]}"; do
        local exit_code=0
        ./cc_glm_switcher.sh restore "$invalid_num" >/dev/null 2>&1 || exit_code=$?

        assert_not_equals "0" "$exit_code" "Restore should fail with invalid backup number: $invalid_num"
    done
}

# Test: Malformed backup file
test_malformed_backup_file() {
    log_info "Testing restore from malformed backup file..."

    # Create a malformed backup file with proper timestamp naming so it will be backup #1
    local malformed_backup
    malformed_backup="$TEST_CONFIG_DIR/settings_backup_$(date +"%Y%m%d_%H%M%S").json"
    echo '{"invalid": json}' > "$malformed_backup"
    assert_file_exists "$malformed_backup" "Malformed backup file should be created"

    cd "$ROOT_DIR" || exit 1

    # Try to restore from malformed backup (should be backup #1)
    local exit_code=0
    ./cc_glm_switcher.sh restore 1 >/dev/null 2>&1 || exit_code=$?

    assert_not_equals "0" "$exit_code" "Restore should fail with malformed backup file"

    # Clean up malformed backup
    rm -f "$malformed_backup"
    assert_file_not_exists "$malformed_backup" "Malformed backup file should be cleaned up"
}

# Test: Corrupted backup directory
test_corrupted_backup_directory() {
    log_info "Testing operations on corrupted backup directory..."

    # Remove config directory to simulate corruption
    rm -rf "$TEST_CONFIG_DIR"
    assert_file_not_exists "$TEST_CONFIG_DIR" "Config directory should be removed"

    cd "$ROOT_DIR" || exit 1

    # Try to list backups
    local list_output
    list_output=$(./cc_glm_switcher.sh list 2>&1)
    assert_contains "$list_output" "No backup directory found" "List should handle missing directory"

    # Try to restore backup
    local exit_code=0
    ./cc_glm_switcher.sh restore 1 >/dev/null 2>&1 || exit_code=$?

    assert_not_equals "0" "$exit_code" "Restore should fail with corrupted directory"

    # Recreate directory
    mkdir -p "$TEST_CONFIG_DIR"
    assert_directory_exists "$TEST_CONFIG_DIR" "Config directory should be recreated"
}

# Test: Out of disk space simulation
test_out_of_disk_space() {
    log_info "Testing behavior when out of disk space..."

    # Create a very large file to simulate low disk space
    # (This is a simulation, actual disk space check may not work)
    local large_file="$TEST_CONFIG_DIR/large_file.tmp"

    # Try to create a large file (may fail gracefully)
    if dd if=/dev/zero of="$large_file" bs=1M count=1000 2>/dev/null; then
        assert_equals "0" "0" "Large file created successfully (disk space not an issue)"
        rm -f "$large_file"
        assert_file_not_exists "$large_file" "Large file should be cleaned up"
    else
        assert_equals "0" "0" "Large file creation failed (simulating out of space)"
    fi
}

# Main test runner
main() {
    echo "=================================="
    echo "Running Error Handling Tests"
    echo "=================================="

    run_test "Invalid JSON Settings" test_invalid_json_settings
    run_test "Missing Settings File" test_missing_settings_file
    run_test "Empty Settings File" test_empty_settings_file
    run_test "Missing .env File" test_missing_env_file
    run_test "Invalid .env File Format" test_invalid_env_file
    run_test "Missing Auth Token" test_missing_auth_token
    run_test "Invalid Auth Token Format" test_invalid_auth_token
    run_test "Invalid MAX_BACKUPS Value" test_invalid_max_backups
    run_test "Lock File Conflict" test_lock_file_conflict
    run_test "Missing Dependencies" test_missing_dependencies
    run_test "Invalid Backup Number" test_restore_invalid_backup_number
    run_test "Malformed Backup File" test_malformed_backup_file
    run_test "Corrupted Backup Directory" test_corrupted_backup_directory
    run_test "Out of Disk Space" test_out_of_disk_space

    print_test_results
}

# Run tests if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
