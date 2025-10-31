# Test Infrastructure for cc_glm_switcher.sh

This directory contains the test infrastructure for the Claude Code / GLM model switcher utility.

## Overview

The test suite provides:

- **Assertion functions** for validating script behavior
- **Test environment isolation** to prevent interference with actual Claude Code settings
- **Fixtures** for testing various configuration scenarios
- **Result tracking** for comprehensive test reporting

## Directory Structure

```bash
tests/
├── README.md              # This file
├── run_all_tests.sh       # Master test runner (37 tests total)
├── test_helper.sh         # Core test utilities and assertion functions
├── security_functions.sh  # Security validation functions
├── test_core.sh           # Core functionality tests (20 tests)
├── test_errors.sh         # Error handling tests (9 tests)
├── test_cli.sh            # CLI options tests (8 tests)
└── test_security.sh       # Security function tests
```

## Running Tests

### Full Test Suite

The complete test suite includes 37 automated tests across three phases:

```bash
# Run all tests
./tests/run_all_tests.sh

# Run with verbose output
./tests/run_all_tests.sh --verbose

# Check dependencies only
./tests/run_all_tests.sh --check-deps
```

### Individual Test Suites

```bash
# Core functionality tests (20 tests)
./tests/test_core.sh

# Error handling tests (9 tests)
./tests/test_errors.sh

# CLI options tests (8 tests)
./tests/test_cli.sh
```

### Basic Usage (Manual Testing)

To run tests manually, source the test helper and use the provided functions:

```bash
# Source the test helper
source tests/test_helper.sh

# Run a simple test
assert_equals "expected" "actual" "test description"

# Set up isolated test environment
setup_test_env

# Your test code here...

# Clean up
teardown_test_env
```

### Example Test Suite

```bash
#!/bin/bash
source tests/test_helper.sh

# Define a test function
test_json_validation() {
    assert_json_valid "tests/fixtures/settings_cc.json" "Claude Code settings validation"
}

# Run tests and track results
run_test test_json_validation

# Display summary
print_test_summary
```

## Available Assertion Functions

### `assert_equals expected actual description`

Compares two values for equality.

```bash
assert_equals "foo" "foo" "string equality"
```

### `assert_file_exists file_path description`

Checks if a file exists at the given path.

```bash
assert_file_exists "$HOME/.claude/settings.json" "settings file exists"
```

### `assert_json_valid file_path description`

Validates JSON syntax using `jq`.

```bash
assert_json_valid "config.json" "configuration is valid JSON"
```

### `assert_contains expected source description`

Checks if a string or file contains the expected substring.

```bash
# Check string content
assert_contains "API_KEY" "$settings_content" "contains API key"

# Check file content
assert_contains "ANTHROPIC_BASE_URL" "settings.json" "contains base URL"
```

## Test Environment Functions

### `setup_test_env`

Creates an isolated test environment with:

- Temporary directory (`/tmp/cc_glm_test_$$_timestamp`)
- Mock `.claude` directory structure
- Test-specific environment variables

The test directory path is stored in `$TEST_DIR`.

```bash
setup_test_env
echo "Testing in: $TEST_DIR"
```

### `teardown_test_env`

Cleans up the test environment:

- Removes temporary directories
- Unsets test environment variables

```bash
teardown_test_env
```

### Environment Variables Set by `setup_test_env`

- `TEST_ROOT_CC`: Path to mock Claude settings directory
- `TEST_ROOT_SCRIPT`: Path to mock script directory
- `TEST_CONFIG_DIR`: Path to mock configs directory
- `TEST_LOCK_FILE`: Path to mock lock file
- `TEST_DIR`: Root test directory path

## Cleanup Functions

The test helper includes automatic cleanup functionality to prevent orphaned test directories.

### `cleanup_all`

Cleans up all test directories created during the current session. This is automatically registered as a trap handler for EXIT, INT, and TERM signals, but can also be called manually.

```bash
# Cleanup is automatic on script exit, but you can call it manually
cleanup_all
```

**What it cleans:**

- All tracked test directories from the current session
- The current `$TEST_DIR` if set
- Any orphaned `cc_glm_test_*` directories in `/tmp`

### `cleanup_old_tests [hours]`

Remove test directories older than the specified number of hours (default: 24).

```bash
# Clean up test directories older than 24 hours (default)
cleanup_old_tests

# Clean up test directories older than 1 hour
cleanup_old_tests 1

# Clean up test directories older than 7 days
cleanup_old_tests 168
```

### Automatic Cleanup

When you source `test_helper.sh`, cleanup trap handlers are automatically registered:

- **EXIT**: Cleanup on normal script exit
- **INT**: Cleanup on Ctrl+C (SIGINT)
- **TERM**: Cleanup on termination signal

This ensures test directories are cleaned up even if tests fail or are interrupted.

## Test Tracking Functions

### `run_test test_function_name`

Wrapper that executes a test function and tracks pass/fail results.

```bash
test_my_feature() {
    assert_equals "1" "1" "basic math"
}

run_test test_my_feature
```

### `print_test_summary`

Displays final test results with pass/fail counts.

```bash
print_test_summary
# Outputs:
# =========================================
# Test Summary
# =========================================
# Passed: 5
# Failed: 0
# Total:  5
```

## Test Data Generation

The test suite generates test data dynamically rather than using pre-defined fixture files. Test configurations are created inline within each test to ensure:

- **Isolation**: Each test has its own clean test environment
- **Flexibility**: Tests can create custom configurations as needed
- **Accuracy**: Test data matches the exact format expected by the script

For testing different scenarios, the tests create appropriate JSON configurations using helper functions like `create_test_settings`.

## Helper Functions

### `create_test_env_file path`

Creates a test `.env` file with sample configuration.

```bash
create_test_env_file "$TEST_DIR/.env"
```

### `create_test_settings path mode`

Creates a minimal settings.json file. Mode can be "cc" or "glm".

```bash
create_test_settings "$TEST_DIR/settings.json" "glm"
```

## Security Testing

The `security_functions.sh` file provides additional security validation functions for testing:

- File permission validation
- Ownership verification
- Directory security checks

These functions are used by the main script and tested in the security test suite.

## Writing New Tests

To add new tests:

1. **Create a test script** in the `tests/` directory
2. **Source the test helper** at the beginning
3. **Define test functions** that use assertion functions
4. **Run tests** with `run_test` wrapper
5. **Display results** with `print_test_summary`

### Template

```bash
#!/bin/bash
# tests/test_my_feature.sh

# Load test infrastructure
source "$(dirname "$0")/test_helper.sh"

# Test function
test_feature_works() {
    setup_test_env

    # Your test logic here
    assert_equals "expected" "actual" "feature works correctly"

    teardown_test_env
}

# Run tests
run_test test_feature_works

# Display results
print_test_summary
```

## Best Practices

1. **Always use `setup_test_env`** to create isolated test environments
2. **Always call `teardown_test_env`** to clean up after tests
3. **Use descriptive test names** that explain what is being tested
4. **Keep tests focused** - one test function per feature/behavior
5. **Validate fixtures** using `jq` before using them in tests
6. **Use test environment variables** (`TEST_ROOT_CC`, etc.) instead of real paths

## Quick Reference

### Common Cleanup Commands

```bash
# Manual cleanup of all test directories from current session
cleanup_all

# Clean up test directories older than 24 hours
cleanup_old_tests

# Clean up test directories older than 1 hour
cleanup_old_tests 1
```

### Cleanup Behavior Summary

| Function | What it cleans | When to use |
|----------|----------------|-------------|
| `cleanup_all` | All tracked test dirs + current TEST_DIR + orphaned dirs | Manual cleanup or automatic via trap |
| `cleanup_old_tests [hours]` | Test dirs older than N hours | Periodic maintenance |
| `teardown_test_env` | Current TEST_DIR only | Normal test cleanup |
| Automatic (trap) | All test directories on script exit | Always active when test_helper.sh is sourced |

### Test Results Summary

When running `./tests/run_all_tests.sh`, you'll see output like:

```
=========================================
Test Suite Results
=========================================
test_core.sh: PASSED (20/20 tests)
test_errors.sh: PASSED (9/9 tests)
test_cli.sh: PASSED (8/8 tests)
=========================================
Total Suites: 3
Total Tests: 37
All tests passed! ✓
```

## Verification

To manually verify the test infrastructure:

```bash
# Test environment setup/teardown
source tests/test_helper.sh
setup_test_env
echo "Test env created: $TEST_DIR"
teardown_test_env
echo "Cleanup complete"

# Test assertions (run from tests/ directory)
cd tests
bash -c 'source test_helper.sh && \
  assert_equals "foo" "foo" "equality test"'

# Create and validate test settings
create_test_settings "/tmp/test_settings.json" "glm"
assert_json_valid "/tmp/test_settings.json" "test GLM settings creation"
rm -f "/tmp/test_settings.json"

# Run full test suite
./run_all_tests.sh
```

## Dependencies

- **bash**: Shell environment
- **jq**: JSON validation and manipulation
- **shellcheck**: Shell script linting (for CI)
- Standard Unix utilities (mkdir, rm, cat, etc.)

## Test Coverage

The test suite covers:

### Phase 1: Infrastructure ✅ COMPLETED
- Test framework setup
- Assertion functions
- Environment isolation
- Cleanup mechanisms

### Phase 2: Core Functionality ✅ COMPLETED (20 tests)
- Model switching (CC ↔ GLM)
- Backup creation and validation
- JSON validation
- Environment variable handling

### Phase 3: Error Handling & CLI ✅ COMPLETED (17 tests)
- Dependency validation
- Input validation
- CLI option parsing
- Error scenarios

### Total Coverage: 37 automated tests

## CI/CD Integration

Tests are automatically run via GitHub Actions on:
- Every push to `main` branch
- All pull requests

The CI workflow mirrors the local test execution:
```bash
./tests/run_all_tests.sh --check-deps && ./tests/run_all_tests.sh
```

---

**Status:** ✓ All Phases Complete - Full Test Suite Ready
