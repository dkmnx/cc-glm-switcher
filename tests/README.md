# Test Infrastructure for cc_glm_switcher.sh

This directory contains the test infrastructure for the Claude Code / GLM model switcher utility.

## Overview

The test suite provides:
- **Assertion functions** for validating script behavior
- **Test environment isolation** to prevent interference with actual Claude Code settings
- **Fixtures** for testing various configuration scenarios
- **Result tracking** for comprehensive test reporting

## Directory Structure

```
tests/
├── README.md           # This file
├── test_helper.sh      # Core test utilities and assertion functions
└── fixtures/           # Sample configuration files
    ├── settings_cc.json      # Valid Claude Code configuration
    ├── settings_glm.json     # Valid GLM configuration
    └── invalid.json          # Malformed JSON for error testing
```

## Running Tests

### Basic Usage

To run tests, source the test helper and use the provided functions:

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

## Test Fixtures

### `settings_cc.json`
Minimal valid Claude Code configuration with no GLM-specific environment variables.

**Structure:**
```json
{
  "env": {}
}
```

### `settings_glm.json`
Valid GLM configuration with all required environment variables:

**Required Variables:**
- `ANTHROPIC_AUTH_TOKEN`: Authentication token
- `ANTHROPIC_BASE_URL`: https://api.z.ai/api/anthropic
- `API_TIMEOUT_MS`: Request timeout
- `ANTHROPIC_DEFAULT_HAIKU_MODEL`: Haiku model mapping
- `ANTHROPIC_DEFAULT_SONNET_MODEL`: Sonnet model mapping
- `ANTHROPIC_DEFAULT_OPUS_MODEL`: Opus model mapping
- `CLAUDE_MODEL_PROVIDER`: zhipu
- `GLM_MODEL_MAPPING`: Model mapping configuration

### `invalid.json`
Malformed JSON file for testing error handling (contains trailing comma).

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

# See cleanup in action
./tests/demo_cleanup.sh
```

### Cleanup Behavior Summary

| Function | What it cleans | When to use |
|----------|----------------|-------------|
| `cleanup_all` | All tracked test dirs + current TEST_DIR + orphaned dirs | Manual cleanup or automatic via trap |
| `cleanup_old_tests [hours]` | Test dirs older than N hours | Periodic maintenance |
| `teardown_test_env` | Current TEST_DIR only | Normal test cleanup |
| Automatic (trap) | All test directories on script exit | Always active when test_helper.sh is sourced |

## Verification

To manually verify the test infrastructure:

```bash
# Test environment setup/teardown
source tests/test_helper.sh
setup_test_env
echo "Test env created: $TEST_DIR"
teardown_test_env
echo "Cleanup complete"

# Validate fixtures
jq empty tests/fixtures/settings_cc.json
jq empty tests/fixtures/settings_glm.json

# Test assertions
cd tests
bash -c 'source test_helper.sh && \
  assert_equals "foo" "foo" "equality test" && \
  assert_file_exists "fixtures/settings_cc.json" "file test" && \
  assert_json_valid "fixtures/settings_cc.json" "json test" && \
  assert_contains "ANTHROPIC_BASE_URL" "fixtures/settings_glm.json" "contains test"'
```

## Dependencies

- **bash**: Shell environment
- **jq**: JSON validation and manipulation
- Standard Unix utilities (mkdir, rm, cat, etc.)

## Future Phases

This is **Phase 1** of the test implementation. Future phases will include:
- **Phase 2**: Basic functionality tests (switching, validation)
- **Phase 3**: Advanced tests (backup, restore, edge cases)
- **Phase 4**: Integration tests and CI/CD setup

---

**Status:** ✓ Phase 1 Complete - Infrastructure Ready
