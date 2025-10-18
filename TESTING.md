# Testing Guide

This project includes a comprehensive test suite to ensure reliability and catch regressions. The tests are located in the `tests/` directory and cover all major functionality.

## Overview

The test suite provides:
- **136 individual assertions** across 4 test suites
- **Comprehensive coverage** of all script functionality
- **Isolated test environments** to avoid affecting your actual configuration
- **Detailed reporting** with color-coded output
- **Automated cleanup** of test artifacts

## Running Tests

### Run All Tests
```bash
# Run the complete test suite
./tests/run_all_tests.sh

# Run with verbose output
./tests/run_all_tests.sh --verbose
```

### Run Specific Test Suites
```bash
# Run only model switching tests
./tests/run_all_tests.sh model-switching

# Run multiple specific test suites
./tests/run_all_tests.sh backup-restore cli-options

# Run error handling tests only
./tests/run_all_tests.sh error-handling
```

### Test Utilities
```bash
# Check test dependencies
./tests/run_all_tests.sh --check-deps

# Clean up test environment
./tests/run_all_tests.sh --cleanup

# Show test runner help
./tests/run_all_tests.sh --help
```

## Test Coverage

The test suite includes the following test modules:

### `test_model_switching.sh` (23 assertions)
Tests the core model switching functionality:

- **CC → GLM switching**: Verifies proper injection of GLM environment variables
- **GLM → CC switching**: Ensures clean removal of GLM configuration
- **Environment variable preservation**: Tests that custom variables are maintained during switches
- **JSON validation**: Confirms settings.json remains valid after operations
- **Dry run functionality**: Verifies preview mode works without making changes
- **Model mapping configuration**: Tests correct GLM model mappings
- **GLM configuration detection**: Ensures proper detection of GLM setups

### `test_backup_restore.sh` (20 assertions)
Tests backup and restore functionality:

- **Backup creation**: Verifies timestamped backups are created before changes
- **Backup listing**: Tests the backup listing functionality and output format
- **Restore operations**: Validates restoration from specific backups
- **Backup retention**: Tests automatic cleanup of old backups based on `MAX_BACKUPS`
- **Interactive restore**: Tests menu-driven restore functionality
- **Pre-restore backup**: Ensures current settings are backed up before restore
- **Custom environment preservation**: Verifies custom variables survive backup/restore cycles
- **Error handling**: Tests restore from invalid or missing backups

### `test_cli_options.sh` (54 assertions)
Tests command-line interface and options:

- **Command-line parsing**: Tests all CLI flags and arguments
- **Help system**: Verifies help and version information display
- **Dry run mode**: Ensures dry-run shows changes without applying them
- **Verbose output**: Tests detailed logging functionality
- **Flag positioning**: Tests flags before and after commands
- **Combined flags**: Tests multiple flags used together
- **Exit codes**: Verifies proper exit codes for success and failure cases
- **Argument validation**: Tests invalid arguments and error handling

### `test_error_handling.sh` (39 assertions)
Tests error conditions and edge cases:

- **Invalid JSON**: Tests handling of corrupted settings files
- **Missing dependencies**: Verifies graceful failure when required tools are missing
- **Authentication errors**: Tests behavior with invalid API tokens
- **Lock file handling**: Ensures proper concurrent execution protection
- **File system errors**: Tests missing files, empty files, permission issues
- **Backup corruption**: Tests recovery from malformed backup files
- **Edge cases**: Various boundary conditions and error scenarios

## Test Framework

The tests use a custom bash testing framework with:

### Assertion Functions
- `assert_equals(expected, actual, message)` - Compare two values
- `assert_not_equals(expected, actual, message)` - Ensure values differ
- `assert_file_exists(file, message)` - Check file existence
- `assert_file_not_exists(file, message)` - Check file absence
- `assert_directory_exists(dir, message)` - Check directory existence
- `assert_contains(haystack, needle, message)` - Check string contains substring
- `assert_json_valid(file, message)` - Validate JSON syntax

### Test Environment
- **Test isolation**: Each test runs in a clean, isolated environment
- **Fixture data**: Pre-configured test scenarios in `tests/fixtures/`
- **Helper utilities**: Common test operations in `test_helper.sh`
- **Comprehensive reporting**: Detailed test results with color-coded output

### Test Structure
Each test follows this pattern:
```bash
test_feature_name() {
    log_info "Testing feature description..."
    
    # Setup test state
    setup_test_environment
    
    # Execute test operations
    # ... test code here ...
    
    # Verify results with assertions
    assert_equals "expected" "actual" "Feature should work correctly"
    assert_file_exists "$TEST_FILE" "Required file should be created"
    
    # Cleanup
    cleanup_test_environment
}
```

## Test Requirements

The tests require:
- **bash** (version 4.0+)
- **jq** (JSON processing)
- **Standard Unix utilities** (`find`, `grep`, `sed`, `awk`, etc.)

### Dependency Check
```bash
# Verify all dependencies are available
./tests/run_all_tests.sh --check-deps
```

## Test Environment

Tests run in isolated environments to avoid affecting your actual configuration:

### Directory Structure
```
tests/
├── test_helper.sh              # Test framework and utilities
├── run_all_tests.sh            # Test runner
├── test_model_switching.sh     # Model switching tests
├── test_backup_restore.sh      # Backup/restore tests
├── test_cli_options.sh         # CLI options tests
├── test_error_handling.sh      # Error handling tests
├── fixtures/                   # Test data and configurations
│   ├── invalid.json
│   ├── settings_cc.json
│   ├── settings_glm.json
│   └── settings_mixed.json
├── test_configs/               # Temporary backup directory (created during tests)
└── test_claude/                # Temporary Claude config directory (created during tests)
```

### Environment Isolation
- **Test directories**: Temporary directories created under `tests/test_*`
- **Mock configurations**: Sample settings files in `tests/fixtures/`
- **Environment variables**: Tests use separate environment variables
- **Automatic cleanup**: Test artifacts are removed after completion

## Writing New Tests

When adding new functionality, follow these testing guidelines:

### 1. Test Function Naming
Use the `test_*` naming convention:
```bash
test_new_feature_name() {
    # Test implementation
}
```

### 2. Use Assertion Functions
Always use assertion functions from `test_helper.sh`:
```bash
assert_equals "expected_value" "$actual_value" "Description of what should happen"
assert_file_exists "$expected_file" "File should be created"
assert_contains "$output" "expected_text" "Output should contain expected text"
```

### 3. Test Both Success and Failure
Test both positive and negative scenarios:
```bash
# Test success case
assert_equals "0" "$exit_code" "Command should succeed"

# Test failure case
assert_not_equals "0" "$error_exit_code" "Command should fail with invalid input"
```

### 4. Isolate Test Data
Use temporary directories and files:
```bash
# Create test file in temporary directory
echo "test data" > "$TEST_CLAUDE_DIR/test_file.json"

# Test with the file
assert_file_exists "$TEST_CLAUDE_DIR/test_file.json" "Test file should exist"
```

### 5. Clean Up Resources
Always clean up after tests:
```bash
# Use the framework cleanup
cleanup_test_environment

# Or clean up specific resources
rm -f "$temp_file"
```

### 6. Add Descriptive Messages
Provide clear assertion messages for debugging:
```bash
assert_equals "expected" "actual" "Variable should contain expected value after operation"
```

### Example Test Structure
```bash
test_backup_creation_with_custom_env() {
    log_info "Testing backup creation with custom environment variables..."
    
    # Setup test environment
    setup_test_environment
    
    # Create custom environment
    cat > "$TEST_CLAUDE_DIR/settings.json" << EOF
{
  "env": {
    "CUSTOM_VAR": "custom_value",
    "ANOTHER_VAR": "another_value"
  }
}
EOF
    
    # Run backup operation
    cd "$ROOT_DIR" || exit 1
    ./cc_glm_switcher.sh cc >/dev/null 2>&1
    
    # Verify backup was created and contains custom variables
    local latest_backup
    latest_backup=$(get_latest_backup)
    assert_file_exists "$latest_backup" "Backup file should be created"
    
    local backup_content
    backup_content=$(cat "$latest_backup")
    assert_contains "$backup_content" "CUSTOM_VAR" "Backup should contain custom variables"
    assert_contains "$backup_content" "custom_value" "Backup should preserve custom values"
    
    # Cleanup
    cleanup_test_environment
}
```

## Running Individual Tests

For debugging, you can run individual test files:

```bash
# Run a specific test suite
./tests/test_model_switching.sh

# Run with bash directly
bash ./tests/test_model_switching.sh

# Run with timeout to prevent hanging
timeout 60s ./tests/test_model_switching.sh
```

## Test Output

### Successful Test Run
```
==================================================
cc-glm-switcher Test Suite Runner
==================================================
Testing: Claude Code ↔ Z.AI GLM Model Switcher
Directory: /path/to/cc-glm-switcher
Timestamp: 2025-01-15 10:30:45
==================================================

[INFO] Running test suite: test_model_switching
----------------------------------------
==================================
Running Model Switching Tests
==================================
[INFO] Running test: CC to GLM Switching
[PASS] Should have basic settings
[PASS] Switch to GLM completed
[PASS] Should set GLM provider
[PASS] Should set GLM base URL
[PASS] Should set auth token
[PASS] Settings should remain valid JSON
[PASS] Test passed: CC to GLM Switching

==================================
Test Results Summary
==================================
Total Assertions: 23
Passed:           23
Failed:           0
✓ All assertions passed!
[PASS] Test suite 'test_model_switching' passed
----------------------------------------

==================================================
Test Summary
==================================================
Test Suites: 4 (Passed: 4, Failed: 0)
Total Tests: 136 (Passed: 136, Failed: 0)

✓ All test suites passed!
✓ All 136 individual tests passed!
```

### Failed Test Example
```
[FAIL] Variable should contain expected value after operation
[FAIL] Test failed: Example Test

==================================
Test Results Summary
==================================
Total Assertions: 23
Passed:           22
Failed:           1
✗ Some assertions failed!
```

## Continuous Integration

The test suite is designed to run in CI/CD environments:

### CI Features
- **No interactive prompts**: All tests run automatically
- **Proper exit codes**: Returns non-zero for test failures
- **Environment variables**: Configurable via environment variables
- **Parallel execution**: Tests can be run in parallel if needed
- **Verbose logging**: Detailed output for debugging CI failures

### CI Configuration Example
```yaml
# GitHub Actions example
- name: Run tests
  run: |
    chmod +x tests/*.sh
    ./tests/run_all_tests.sh --verbose
```

### Environment Variables for CI
```bash
# Enable verbose output in CI
export TEST_VERBOSE=true

# Keep test files for debugging
export TEST_KEEP_FILES=true

# Custom test directory
export TEST_DIR=/tmp/tests
```

## Test Data and Fixtures

### Available Fixtures
- `invalid.json` - Malformed JSON for error testing
- `settings_cc.json` - Claude Code configuration example
- `settings_glm.json` - GLM configuration example
- `settings_mixed.json` - Mixed configuration with custom variables

### Using Fixtures in Tests
```bash
# Copy fixture to test environment
cp "$FIXTURES_DIR/settings_cc.json" "$TEST_CLAUDE_DIR/settings.json"

# Test with fixture data
assert_file_exists "$TEST_CLAUDE_DIR/settings.json" "Settings should be copied from fixture"
```

## Debugging Tests

### Common Issues
1. **Permission denied**: Ensure test scripts are executable
2. **Missing dependencies**: Run `./tests/run_all_tests.sh --check-deps`
3. **Hanging tests**: Use timeout or check for infinite loops
4. **Environment conflicts**: Ensure proper cleanup between tests

### Debugging Techniques
```bash
# Run with bash debugging
bash -x ./tests/test_model_switching.sh

# Run specific test with debugging
bash -x -c 'source tests/test_helper.sh; source tests/test_model_switching.sh; setup_test_environment; test_specific_function; cleanup_test_environment'

# Keep test files for inspection
export TEST_KEEP_FILES=true
./tests/run_all_tests.sh

# Check test environment
ls -la tests/test_*/
```

## Performance Considerations

- **Test isolation**: Each test creates and cleans up temporary directories
- **File operations**: Minimize unnecessary file I/O in tests
- **Parallel execution**: Tests are designed to be independent
- **Resource cleanup**: Always clean up temporary files and processes

## Best Practices

1. **Write descriptive test names** that clearly indicate what's being tested
2. **Use meaningful assertion messages** for easy debugging
3. **Test edge cases** and error conditions, not just happy paths
4. **Keep tests focused** on a single piece of functionality
5. **Use setup/teardown** properly to ensure test isolation
6. **Mock external dependencies** when possible
7. **Validate both state and behavior** in your tests
8. **Document complex test scenarios** with comments

## Contributing Tests

When contributing new features:

1. **Add corresponding tests** for all new functionality
2. **Update existing tests** if behavior changes
3. **Ensure all tests pass** before submitting PR
4. **Follow the established patterns** and naming conventions
5. **Add test documentation** for complex scenarios
6. **Consider edge cases** and error conditions

Remember: Good tests are as important as good code! They ensure reliability, prevent regressions, and serve as documentation for expected behavior.