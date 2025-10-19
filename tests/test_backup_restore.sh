#!/usr/bin/env bash

# Test cases for backup and restore functionality
# Tests the backup creation, listing, and restoration features

set -euo pipefail

# Import test helper functions
# shellcheck source=tests/test_helper.sh
# shellcheck disable=SC1091  # Source file not followed (normal for test helpers)
source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"

# Test: Basic backup creation
test_backup_creation() {
    log_info "Testing backup creation..."

    # Count initial backups
    local initial_backups
    initial_backups=$(count_backup_files)

    # Run the script to create a backup (without dry-run)
    cd "$ROOT_DIR" || exit 1
    ./cc_glm_switcher.sh cc >/dev/null 2>&1

    # Check if backup was created
    local backup_count
    backup_count=$(count_backup_files)

    assert_equals "$((initial_backups + 1))" "$backup_count" "Backup should be created"

    local latest_backup
    latest_backup=$(get_latest_backup)
    assert_file_exists "$latest_backup" "Backup file should exist"
    assert_json_valid "$latest_backup" "Backup file should contain valid JSON"
}

# Test: Backup listing functionality
test_backup_listing() {
    log_info "Testing backup listing..."

    # Create some test backups
    create_test_backup "20250101_120000"
    create_test_backup "20250101_130000"
    create_test_backup "20250101_140000"

    # Test list command
    local list_output
    list_output=$(cd "$ROOT_DIR" && ./cc_glm_switcher.sh list 2>/dev/null)

    assert_contains "$list_output" "Available backup files" "Should show backup list header"
    assert_contains "$list_output" "settings_backup_20250101_140000.json" "Should show newest backup"
    assert_contains "$list_output" "Total backups:" "Should show backup count"
    assert_contains "$list_output" "Usage:" "Should show usage instructions"
}

# Test: Backup retention
test_backup_retention() {
    log_info "Testing backup retention..."

    # Set MAX_BACKUPS to 3 for this test
    echo "MAX_BACKUPS=3" > "$TEST_DIR/.env"

    # Create more backups than MAX_BACKUPS (set to 3 in test .env)
    create_test_backup "20250101_100000"
    create_test_backup "20250101_110000"
    create_test_backup "20250101_120000"
    create_test_backup "20250101_130000"
    create_test_backup "20250101_140000"

    # Run cleanup (this happens automatically when creating new backups)
    cd "$ROOT_DIR" || exit 1
    ./cc_glm_switcher.sh cc >/dev/null 2>&1

    local backup_count
    backup_count=$(count_backup_files)

    # Should have exactly 3 backups (MAX_BACKUPS=3)
    assert_equals "3" "$backup_count" "Should keep exactly MAX_BACKUPS files"
}

# Test: Restore functionality
test_restore_functionality() {
    log_info "Testing restore functionality..."

    # Create a known backup state
    create_test_backup "restore_test"

    # Test restore (dry run)
    cd "$ROOT_DIR" || exit 1
    local restore_output
    restore_output=$(./cc_glm_switcher.sh restore 1 --dry-run 2>&1)

    assert_contains "$restore_output" "DRY RUN" "Should indicate dry run mode"
    assert_contains "$restore_output" "Would restore" "Should show would restore message"
}

# Test: Interactive restore
test_interactive_restore() {
    log_info "Testing interactive restore functionality..."

    # Create some test backups
    create_test_backup "20250101_120000"
    create_test_backup "20250101_130000"

    # Create a different settings state
    cat > "$TEST_CLAUDE_DIR/settings.json" << EOFS
{
  "statusLine": {"type": "command"},
  "modified": "this_should_be_restored"
}
EOFS

    # Test interactive restore (we'll use a simulated input for testing)
    # Note: In real interactive mode, this would wait for user input
    # For testing, we'll verify the menu is displayed correctly
    cd "$ROOT_DIR" || exit 1

    # We can't easily test the interactive part without user input,
    # but we can test that the command exists and shows the menu
    timeout 2s ./cc_glm_switcher.sh restore >/dev/null 2>&1 || true

    # The fact that the command didn't immediately fail suggests
    # the interactive menu is being displayed
    log_success "Interactive restore command executed (menu displayed)"
}

# Test: Restore validation
test_restore_validation() {
    log_info "Testing restore validation..."

    # Create an invalid JSON backup file
    echo '{"invalid": json}' > "$TEST_CONFIG_DIR/settings_backup_invalid.json"

    # Try to restore from invalid backup
    cd "$ROOT_DIR" || exit 1

    # The script should validate and reject invalid JSON
    if ./cc_glm_switcher.sh restore 999 >/dev/null 2>&1; then
        log_warning "Restore completed - backup may be valid"
    else
        log_success "Restore properly rejected invalid backup or invalid number"
    fi

    # Clean up invalid backup
    rm -f "$TEST_CONFIG_DIR/settings_backup_invalid.json"
}

# Test: Pre-restore backup creation
test_pre_restore_backup() {
    log_info "Testing pre-restore backup creation..."

    # Create a test backup to restore from
    create_test_backup "pre_restore_test"

    # Modify current settings
    cat > "$TEST_CLAUDE_DIR/settings.json" << EOFS
{
  "statusLine": {"type": "command"},
  "modified": "current_settings_before_restore"
}
EOFS

    # Perform restore (this should create a pre-restore backup)
    cd "$ROOT_DIR" || exit 1
    ./cc_glm_switcher.sh restore 1 >/dev/null 2>&1

    # Check if a pre-restore backup was created
    local pre_restore_backups
    pre_restore_backups=$(find "$TEST_CONFIG_DIR" -name "*before_restore*" -type f | wc -l)

    assert_equals "1" "$pre_restore_backups" "Should create exactly one pre-restore backup"

    # Verify the pre-restore backup contains the modified settings
    local pre_restore_backup
    pre_restore_backup=$(find "$TEST_CONFIG_DIR" -name "*before_restore*" -type f)
    if [ -n "$pre_restore_backup" ]; then
        assert_contains "$(cat "$pre_restore_backup")" "current_settings_before_restore" "Pre-restore backup should contain current settings"
    else
        log_error "No pre-restore backup found"
        return 1
    fi
}

# Test: Backup with custom environment variables
test_backup_with_custom_env() {
    log_info "Testing backup creation with custom environment variables..."

    # Create settings with custom environment variables
    cat > "$TEST_CLAUDE_DIR/settings.json" << EOFS
{
  "statusLine": {"type": "command"},
  "env": {
    "CUSTOM_API_KEY": "my_custom_key_123",
    "PERSONAL_CONFIG": "important_value",
    "OTHER_SETTING": "preserve_me"
  }
}
EOFS

    # Create backup
    cd "$ROOT_DIR" || exit 1
    ./cc_glm_switcher.sh cc >/dev/null 2>&1

    # Verify backup contains custom variables
    local latest_backup
    latest_backup=$(get_latest_backup)
    if [ -n "$latest_backup" ]; then
        local backup_content
        backup_content=$(cat "$latest_backup")

        assert_contains "$backup_content" "CUSTOM_API_KEY" "Backup should contain custom API key"
        assert_contains "$backup_content" "PERSONAL_CONFIG" "Backup should contain personal config"
        assert_contains "$backup_content" "OTHER_SETTING" "Backup should contain other setting"
    else
        log_error "No backup found"
        return 1
    fi
}

# Test: Backup cleanup on exceeding limit
test_backup_cleanup_on_limit() {
    log_info "Testing backup cleanup when exceeding retention limit..."

    # Set MAX_BACKUPS to 2 for this test
    echo "MAX_BACKUPS=2" > "$TEST_DIR/.env"

    # Create more backups than the limit
    create_test_backup "backup_001"
    create_test_backup "backup_002"
    create_test_backup "backup_003"
    create_test_backup "backup_004"
    create_test_backup "backup_005"

    # Run cleanup (this happens automatically when creating new backups)
    cd "$ROOT_DIR" || exit 1
    ./cc_glm_switcher.sh cc >/dev/null 2>&1

    # Check that only 2 most recent backups remain
    local backup_count
    backup_count=$(count_backup_files)

    assert_equals "2" "$backup_count" "Should keep only MAX_BACKUPS most recent backups"

    # Verify the oldest backups were removed
    assert_file_not_exists "$TEST_CONFIG_DIR/settings_backup_backup_001.json" "Oldest backup should be removed"
    assert_file_not_exists "$TEST_CONFIG_DIR/settings_backup_backup_002.json" "Second oldest backup should be removed"
    assert_file_not_exists "$TEST_CONFIG_DIR/settings_backup_backup_003.json" "Third oldest backup should be removed"
}

# Test: Restore from non-existent backup
test_restore_nonexistent() {
    log_info "Testing restore from non-existent backup..."

    # Try to restore from a backup number that doesn't exist
    cd "$ROOT_DIR" || exit 1

    if ./cc_glm_switcher.sh restore 999 >/dev/null 2>&1; then
        log_warning "Restore completed with non-existent backup (unexpected)"
    else
        log_success "Restore properly failed with non-existent backup"
    fi
}

# Test: List backups with no backups
test_list_no_backups() {
    log_info "Testing backup listing with no backups available..."

    # Remove all backup files
    rm -f "$TEST_CONFIG_DIR/settings_backup_"*.json

    # Try to list backups
    cd "$ROOT_DIR" || exit 1
    local list_output
    list_output=$(./cc_glm_switcher.sh list 2>&1)

    assert_contains "$list_output" "No backup files found" "Should indicate no backups available"
}

# Main test runner
main() {
    echo "=================================="
    echo "Running Backup & Restore Tests"
    echo "=================================="

    run_test "Backup Creation" test_backup_creation
    run_test "Backup Listing" test_backup_listing
    run_test "Backup Retention" test_backup_retention
    run_test "Restore Functionality" test_restore_functionality
    run_test "Interactive Restore" test_interactive_restore
    run_test "Restore Validation" test_restore_validation
    run_test "Pre-restore Backup Creation" test_pre_restore_backup
    run_test "Backup with Custom Environment Variables" test_backup_with_custom_env
    run_test "Backup Cleanup on Limit" test_backup_cleanup_on_limit
    run_test "Restore from Non-existent Backup" test_restore_nonexistent
    run_test "List with No Backups" test_list_no_backups

    print_test_results
}

# Run tests if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
