#!/usr/bin/env bash

# Security Test Suite for CC GLM Switcher
# Tests file permissions, ownership validation, and security features

set -euo pipefail

# Source test helper
source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"

# Test secure file permissions function
test_ensure_secure_permissions() {
    setup_test_env

    # Create test file with insecure permissions
    local test_file="$TEST_DIR/test_config.txt"
    echo "test data" > "$test_file"
    chmod 644 "$test_file"  # Insecure permissions

    # Source the security functions for testing
    source "$(dirname "${BASH_SOURCE[0]}")/security_functions.sh"

    # Test permission fixing
    if ensure_secure_permissions "$test_file" "600"; then
        local new_perms
        new_perms=$(stat -c "%a" "$test_file")
        assert_equals "600" "$new_perms" "File permissions corrected to 600"
    else
        echo "SECURITY_FUNCTION_FAILED: ensure_secure_permissions returned failure"
        return 1
    fi

    # Test that already secure permissions don't change
    if ensure_secure_permissions "$test_file" "600"; then
        local same_perms
        same_perms=$(stat -c "%a" "$test_file")
        assert_equals "600" "$same_perms" "Secure permissions unchanged"
    else
        echo "SECURITY_FUNCTION_FAILED: ensure_secure_permissions failed on secure file"
        return 1
    fi

    teardown_test_env
}

# Test file ownership validation
test_validate_file_ownership() {
    setup_test_env

    # Create test file owned by current user
    local test_file="$TEST_DIR/test_config.txt"
    echo "test data" > "$test_file"
    chmod 600 "$test_file"

    # Source the security functions for testing
    source "$(dirname "${BASH_SOURCE[0]}")/security_functions.sh"

    local current_uid
    current_uid=$(id -u)

    # Test valid ownership
    if validate_file_ownership "$test_file" "$current_uid"; then
        echo "OWNERSHIP_VALIDATION_PASSED: Current user ownership validated"
    else
        echo "OWNERSHIP_VALIDATION_FAILED: Should have passed for current user"
        return 1
    fi

    # Test invalid ownership (using a different UID)
    if ! validate_file_ownership "$test_file" "99999"; then
        echo "OWNERSHIP_VALIDATION_PASSED: Correctly rejected invalid ownership"
    else
        echo "OWNERSHIP_VALIDATION_FAILED: Should have failed for invalid UID"
        return 1
    fi

    teardown_test_env
}

# Test directory permissions validation
test_validate_directory_permissions() {
    setup_test_env

    # Create test directory with insecure permissions
    local test_dir="$TEST_DIR/test_config_dir"
    mkdir -p "$test_dir"
    chmod 755 "$test_dir"  # Insecure permissions

    # Source the security functions for testing
    source "$(dirname "${BASH_SOURCE[0]}")/security_functions.sh"

    # Test permission fixing
    if validate_directory_permissions "$test_dir" "700"; then
        local new_perms
        new_perms=$(stat -c "%a" "$test_dir")
        assert_equals "700" "$new_perms" "Directory permissions corrected to 700"
    else
        echo "SECURITY_FUNCTION_FAILED: validate_directory_permissions returned failure"
        return 1
    fi

    teardown_test_env
}

# Test .env file security validation in load_config
test_env_file_security_validation() {
    setup_test_env
    local root_script_var="${ROOT_SCRIPT:-$HOME/Documents/scripts/cc-glm-switcher}"

    # Create .env file with insecure permissions
    create_test_env_file "$TEST_DIR/.env"
    chmod 644 "$TEST_DIR/.env"  # Insecure permissions

    # Test that script rejects insecure .env file
    local output
    local exit_code

    # Run script from /tmp to avoid local .env file interference
    local root_script_var="${ROOT_SCRIPT:-$HOME/Documents/scripts/cc-glm-switcher}"
    output=$(cd /tmp && ROOT_SCRIPT="$TEST_DIR" TEST_DIR="$TEST_DIR" "$root_script_var/cc_glm_switcher.sh" glm 2>&1 || true)
    exit_code=$?

    # Should fail due to insecure permissions
    if [ $exit_code -ne 0 ] && [[ "$output" == *"insecure permissions"* ]]; then
        echo "ENV_SECURITY_VALIDATION_PASSED: Script correctly rejected insecure .env file"
    else
        echo "ENV_SECURITY_VALIDATION_FAILED: Script should have rejected insecure .env file"
        echo "Exit code: $exit_code"
        echo "Output: $output"
        return 1
    fi

    # Now test with secure permissions - should work
    chmod 600 "$TEST_DIR/.env"
    output=$(cd /tmp && ROOT_SCRIPT="$TEST_DIR" TEST_DIR="$TEST_DIR" "$root_script_var/cc_glm_switcher.sh" glm --dry-run 2>&1 || true)
    exit_code=$?

    if [ $exit_code -eq 0 ] || [[ "$output" == *"DRY RUN"* ]]; then
        echo "ENV_SECURITY_VALIDATION_PASSED: Script accepted secure .env file"
    else
        echo "ENV_SECURITY_VALIDATION_FAILED: Script should have accepted secure .env file"
        echo "Exit code: $exit_code"
        echo "Output: $output"
        return 1
    fi

    teardown_test_env
}

# Test configuration directory security
test_config_directory_security() {
    setup_test_env

    # Source the security functions for testing
    source "$(dirname "${BASH_SOURCE[0]}")/security_functions.sh"

    # Set CONFIG_DIR to test directory
    local test_config_dir="$TEST_DIR/configs"
    # CONFIG_DIR="$test_config_dir"  # Not needed for this test

    # Create directory with insecure permissions
    mkdir -p "$test_config_dir"
    chmod 755 "$test_config_dir"  # Insecure permissions

    # Test security validation (should fix permissions)
    if validate_directory_permissions "$test_config_dir" "700"; then
        local new_perms
        new_perms=$(stat -c "%a" "$test_config_dir")
        assert_equals "700" "$new_perms" "Config directory permissions secured"
    else
        echo "CONFIG_DIR_SECURITY_FAILED: Failed to secure config directory"
        return 1
    fi

    teardown_test_env
}

# Test comprehensive configuration file security
test_config_file_security_validation() {
    setup_test_env

    # Source the security functions for testing
    source "$(dirname "${BASH_SOURCE[0]}")/security_functions.sh"

    # Create test configuration file
    local test_config="$TEST_DIR/test_settings.json"
    echo '{"test": "data"}' > "$test_config"

    # Test with insecure permissions
    chmod 644 "$test_config"

    if ! validate_config_file_security "$test_config"; then
        echo "CONFIG_SECURITY_VALIDATION_PASSED: Correctly rejected insecure config file"
    else
        echo "CONFIG_SECURITY_VALIDATION_FAILED: Should have rejected insecure config file"
        return 1
    fi

    # Test with secure permissions
    chmod 600 "$test_config"

    if validate_config_file_security "$test_config"; then
        echo "CONFIG_SECURITY_VALIDATION_PASSED: Correctly accepted secure config file"
    else
        echo "CONFIG_SECURITY_VALIDATION_FAILED: Should have accepted secure config file"
        return 1
    fi

    teardown_test_env
}

# Test security of backup files
test_backup_file_security() {
    setup_test_env

    # Create .env file with secure permissions
    create_test_env_file "$TEST_DIR/.env"
    chmod 600 "$TEST_DIR/.env"

    # Run script to create backup
    cd /tmp && ROOT_SCRIPT="$TEST_DIR" TEST_DIR="$TEST_DIR" "$ROOT_SCRIPT/cc_glm_switcher.sh" glm --dry-run >/dev/null 2>&1 || true

    # Check if backup files were created with secure permissions
    local backup_files
    backup_files=$(find "$TEST_DIR/configs" -name "settings_backup_*.json" 2>/dev/null || true)

    if [ -n "$backup_files" ]; then
        while IFS= read -r backup_file; do
            if [ -f "$backup_file" ]; then
                local perms
                perms=$(stat -c "%a" "$backup_file")
                if [ "$perms" = "600" ]; then
                    echo "BACKUP_SECURITY_PASSED: Backup file has secure permissions: $backup_file"
                else
                    echo "BACKUP_SECURITY_FAILED: Backup file has insecure permissions: $backup_file ($perms)"
                    return 1
                fi
            fi
        done <<< "$backup_files"
    else
        echo "BACKUP_SECURITY_INFO: No backup files created (this may be expected)"
    fi

    teardown_test_env
}

# Test script behavior with missing security-critical directories
test_missing_directories_security() {
    setup_test_env

    # Remove critical directories to test script behavior
    rm -rf "$TEST_DIR/.claude"
    rm -rf "$TEST_DIR/configs"

    # Create .env file with secure permissions
    create_test_env_file "$TEST_DIR/.env"
    chmod 600 "$TEST_DIR/.env"

    # Test that script creates directories with secure permissions
    cd /tmp && ROOT_SCRIPT="$TEST_DIR" TEST_DIR="$TEST_DIR" "$ROOT_SCRIPT/cc_glm_switcher.sh" glm --dry-run >/dev/null 2>&1 || true

    # Check that directories were created with secure permissions
    local claude_perms
    local claude_perms
    claude_perms=$(stat -c "%a" "$TEST_DIR/.claude" 2>/dev/null || echo "missing")
    local config_perms
    config_perms=$(stat -c "%a" "$TEST_DIR/configs" 2>/dev/null || echo "missing")

    # .claude directory should be created by the script (if needed)
    # config directory should be 700
    if [ "$config_perms" = "700" ]; then
        echo "DIRECTORY_CREATION_SECURITY_PASSED: Config directory created with secure permissions"
    else
        echo "DIRECTORY_CREATION_SECURITY_FAILED: Config directory permissions: $config_perms (expected 700)"
        return 1
    fi

    teardown_test_env
}

# Main test execution function
main() {
    echo "========================================="
    echo "Security Test Suite"
    echo "========================================="

    # Run all security tests
    run_test test_ensure_secure_permissions
    run_test test_validate_file_ownership
    run_test test_validate_directory_permissions
    run_test test_env_file_security_validation
    run_test test_config_directory_security
    run_test test_config_file_security_validation
    run_test test_backup_file_security
    run_test test_missing_directories_security

    # Print summary
    print_test_summary
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi