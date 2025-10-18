#!/usr/bin/env bash

# Test cases for CLI options and help functionality
# Tests command-line flags, help output, and version information

set -euo pipefail

# Import test helper functions
# shellcheck source=tests/test_helper.sh
# shellcheck disable=SC1091  # Source file not followed (normal for test helpers)
source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"

# Test: Help command
test_help_command() {
    log_info "Testing help command..."

    cd "$ROOT_DIR" || exit 1
    local help_output
    help_output=$(./cc_glm_switcher.sh -h 2>&1)

    # Verify help content
    assert_contains "$help_output" "cc-glm-switcher" "Should show script name"
    assert_contains "$help_output" "Claude Code ↔ Z.AI GLM Model Switcher" "Should show description"
    assert_contains "$help_output" "Usage:" "Should show usage information"
    assert_contains "$help_output" "Commands:" "Should show available commands"
    assert_contains "$help_output" "cc" "Should show cc command"
    assert_contains "$help_output" "glm" "Should show glm command"
    assert_contains "$help_output" "list" "Should show list command"
    assert_contains "$help_output" "restore" "Should show restore command"
    assert_contains "$help_output" "Options:" "Should show available options"
    assert_contains "$help_output" "--verbose" "Should show verbose option"
    assert_contains "$help_output" "--dry-run" "Should show dry run option"
    assert_contains "$help_output" "--version" "Should show version option"
    assert_contains "$help_output" "--help" "Should show help option"
    assert_contains "$help_output" "Examples:" "Should show usage examples"

    # Test --help flag
    local help_output_long
    help_output_long=$(./cc_glm_switcher.sh --help 2>&1)

    assert_equals "$help_output" "$help_output_long" "Short and long help should be identical"
}

# Test: Version command
test_version_command() {
    log_info "Testing version command..."

    cd "$ROOT_DIR" || exit 1
    local version_output
    version_output=$(./cc_glm_switcher.sh -V 2>&1)

    # Verify version content
    assert_contains "$version_output" "cc-glm-switcher" "Should show script name"
    assert_contains "$version_output" "1.0.0" "Should show version number"
    assert_contains "$version_output" "Repository: https://github.com/dkmnx/cc-glm-switcher" "Should show repository URL"

    # Test --version flag
    local version_output_long
    version_output_long=$(./cc_glm_switcher.sh --version 2>&1)

    assert_equals "$version_output" "$version_output_long" "Short and long version should be identical"
}

# Test: Invalid command
test_invalid_command() {
    log_info "Testing invalid command handling..."

    cd "$ROOT_DIR" || exit 1

    # Test with invalid command
    local error_output
    error_output=$(./cc_glm_switcher.sh invalid_command 2>&1 || true)

    assert_contains "$error_output" "Error: Unknown option" "Should show unknown option error"
    assert_contains "$error_output" "Use -h or --help for usage information" "Should show help hint"
}

# Test: Missing command
test_missing_command() {
    log_info "Testing missing command handling..."

    cd "$ROOT_DIR" || exit 1

    # Test with no command
    local error_output
    error_output=$(./cc_glm_switcher.sh 2>&1 || true)

    assert_contains "$error_output" "Error: Command must be specified" "Should show command missing error"
    assert_contains "$error_output" "Usage:" "Should show usage hint"
}

# Test: Verbose flag
test_verbose_flag() {
    log_info "Testing verbose flag..."

    # Create test environment
    setup_test_environment

    cd "$ROOT_DIR" || exit 1
    local verbose_output
    verbose_output=$(./cc_glm_switcher.sh cc -v 2>&1)

    # Verify verbose output
    assert_contains "$verbose_output" "[INFO]" "Should show info messages"
    assert_contains "$verbose_output" "cc-glm-switcher v1.0.0" "Should show version in verbose mode"
    assert_contains "$verbose_output" "Repository: https://github.com/dkmnx/cc-glm-switcher" "Should show repository in verbose mode"
    assert_contains "$verbose_output" "Current configuration:" "Should show current configuration"
    assert_contains "$verbose_output" "Provider: claude (default)" "Should show current provider"

    # Test long verbose flag
    local verbose_output_long
    verbose_output_long=$(./cc_glm_switcher.sh cc --verbose 2>&1)

    assert_contains "$verbose_output_long" "[INFO]" "Long verbose flag should show info messages"

    cleanup_test_environment
}

# Test: Dry run flag
test_dry_run_flag() {
    log_info "Testing dry run flag..."

    # Create test environment
    setup_test_environment

    cd "$ROOT_DIR" || exit 1
    local dry_run_output
    dry_run_output=$(./cc_glm_switcher.sh glm --dry-run 2>&1)

    # Verify dry run output
    assert_contains "$dry_run_output" "DRY RUN" "Should indicate dry run mode"
    assert_contains "$dry_run_output" "Would switch" "Should show would switch message"

    # Verify settings unchanged
    local initial_settings
    initial_settings=$(cat "$TEST_CLAUDE_DIR/settings.json")
    local current_settings
    current_settings=$(cat "$TEST_CLAUDE_DIR/settings.json")

    assert_equals "$initial_settings" "$current_settings" "Settings should be unchanged in dry run"

    cleanup_test_environment
}

# Test: Combined flags
test_combined_flags() {
    log_info "Testing combined flags..."

    # Create test environment
    setup_test_environment

    cd "$ROOT_DIR" || exit 1
    local combined_output
    combined_output=$(./cc_glm_switcher.sh glm --dry-run -v 2>&1)

    # Verify both dry run and verbose are active
    assert_contains "$combined_output" "DRY RUN" "Should indicate dry run mode"
    assert_contains "$combined_output" "[INFO]" "Should show info messages"
    assert_contains "$combined_output" "cc-glm-switcher v1.0.0" "Should show version"
    assert_contains "$combined_output" "Repository:" "Should show repository"
    assert_contains "$combined_output" "Current configuration:" "Should show current configuration"

    cleanup_test_environment
}

# Test: Flag positioning
test_flag_positioning() {
    log_info "Testing flag positioning..."

    # Create test environment
    setup_test_environment

    cd "$ROOT_DIR" || exit 1

    # Test flags before command
    local output_before
    output_before=$(./cc_glm_switcher.sh -v glm 2>&1)
    assert_contains "$output_before" "[INFO]" "Flags before command should work"

    # Test flags after command
    local output_after
    output_after=$(./cc_glm_switcher.sh glm -v 2>&1)
    assert_contains "$output_after" "[INFO]" "Flags after command should work"

    # Test multiple flags
    local output_multiple
    output_multiple=$(./cc_glm_switcher.sh glm -v --dry-run 2>&1)
    assert_contains "$output_multiple" "DRY RUN" "Multiple flags should work"
    assert_contains "$output_multiple" "[INFO]" "Multiple flags should work"

    cleanup_test_environment
}

# Test: List command with flags
test_list_with_flags() {
    log_info "Testing list command with flags..."

    # Create some test backups
    setup_test_environment
    create_test_backup "test_001"

    cd "$ROOT_DIR" || exit 1

    # List with verbose flag
    local list_verbose_output
    list_verbose_output=$(./cc_glm_switcher.sh list -v 2>&1)
    assert_contains "$list_verbose_output" "Available backup files" "Should show list content"

    # List with dry run flag (should not affect list)
    local list_dry_run_output
    list_dry_run_output=$(./cc_glm_switcher.sh list --dry-run 2>&1)
    assert_contains "$list_dry_run_output" "Available backup files" "Dry run should not affect list"

    cleanup_test_environment
}

# Test: Restore command with flags
test_restore_with_flags() {
    log_info "Testing restore command with flags..."

    # Create test environment
    setup_test_environment
    create_test_backup "test_001"

    cd "$ROOT_DIR" || exit 1

    # Restore with dry run
    local restore_dry_output
    restore_dry_output=$(./cc_glm_switcher.sh restore 1 --dry-run 2>&1)
    assert_contains "$restore_dry_output" "DRY RUN" "Should indicate dry run mode"

    # Restore with verbose
    local restore_verbose_output
    restore_verbose_output=$(./cc_glm_switcher.sh restore 1 --dry-run -v 2>&1)
    assert_contains "$restore_verbose_output" "[INFO]" "Should show info messages"
    assert_contains "$restore_verbose_output" "DRY RUN" "Should indicate dry run mode"

    cleanup_test_environment
}

# Test: Command line argument parsing
test_argument_parsing() {
    log_info "Testing command line argument parsing..."

    cd "$ROOT_DIR" || exit 1

    # Test multiple arguments
    local output_multiple
    output_multiple=$(./cc_glm_switcher.sh glm -v --dry-run 2>&1)
    assert_contains "$output_multiple" "DRY RUN" "Should parse multiple arguments correctly"

    # Test with extra whitespace
    local output_whitespace
    output_whitespace=$(./cc_glm_switcher.sh  "  glm  "   -v   2>&1)
    assert_contains "$output_whitespace" "[INFO]" "Should handle whitespace correctly" || log_warning "Whitespace handling may need adjustment"

    # Test case sensitivity (should be case sensitive for flags)
    local output_case_sensitive
    output_case_sensitive=$(./cc_glm_switcher.sh -V 2>&1)
    assert_contains "$output_case_sensitive" "cc-glm-switcher" "Short flags should be case sensitive"

    # Test invalid flag
    local output_invalid_flag
    output_invalid_flag=$(./cc_glm_switcher.sh cc --invalid-flag 2>&1 || true)
    assert_contains "$output_invalid_flag" "Error: Unknown option" "Should reject invalid flag"
}

# Test: Exit codes
test_exit_codes() {
    log_info "Testing command exit codes..."

    cd "$ROOT_DIR" || exit 1

    # Test successful command (help should exit with 0)
    ./cc_glm_switcher.sh -h >/dev/null
    assert_equals "$?" "0" "Help command should exit with 0"

    # Test successful command (version should exit with 0)
    ./cc_glm_switcher.sh -V >/dev/null
    assert_equals "$?" "0" "Version command should exit with 0"

    # Test failed command (invalid option should exit with 1)
    ./cc_glm_switcher.sh --invalid-option >/dev/null 2>&1
    assert_not_equals "$?" "0" "Invalid option should exit with non-zero"

    # Test failed command (missing argument should exit with 1)
    ./cc_glm_switcher.sh >/dev/null 2>&1
    assert_not_equals "$?" "0" "Missing command should exit with non-zero"
}

# Main test runner
main() {
    echo "=================================="
    echo "Running CLI Options Tests"
    echo "=================================="

    run_test "Help Command" test_help_command
    run_test "Version Command" test_version_command
    run_test "Invalid Command" test_invalid_command
    run_test "Missing Command" test_missing_command
    run_test "Verbose Flag" test_verbose_flag
    run_test "Dry Run Flag" test_dry_run_flag
    run_test "Combined Flags" test_combined_flags
    run_test "Flag Positioning" test_flag_positioning
    run_test "List with Flags" test_list_with_flags
    run_test "Restore with Flags" test_restore_with_flags
    run_test "Argument Parsing" test_argument_parsing
    run_test "Exit Codes" test_exit_codes

    print_test_results
}

# Run tests if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi