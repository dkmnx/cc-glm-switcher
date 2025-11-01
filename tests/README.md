# Test Suite for cc_provider_switcher.sh

This directory contains the simplified test suite for the Claude Code / GLM model switcher utility.

## Overview

The test suite provides focused validation of core script functionality:

- **Essential test coverage** for script behavior and configuration management
- **Simple execution** with clear pass/fail output
- **Robust validation** of JSON handling, authentication, and error scenarios
- **Minimal complexity** - easy to understand and maintain

## Directory Structure

```bash
tests/
├── README.md              # This file
├── test_basic.sh          # Core test suite (11 tests)
└── run_basic_tests.sh     # Simple test runner
```

## Running Tests

### Full Test Suite

Run all tests with the test runner:

```bash
# Run all tests
./tests/run_basic_tests.sh
```

### Individual Test Execution

Run tests directly:

```bash
# Run from project root
./tests/test_basic.sh
```

## Test Coverage

The test suite includes 11 comprehensive tests:

### **Test 1: Script Existence**

- Validates the main script exists and is executable
- Ensures proper file permissions

### **Test 2: Help Command**

- Tests the `-h` and `--help` functionality
- Verifies usage information is displayed

### **Test 3: Invalid Argument Handling**

- Tests rejection of invalid commands
- Ensures proper error handling for bad input

### **Test 4: Show Command**

- Tests the `show` command functionality
- Validates configuration display capabilities

### **Test 5: GLM Mode Authentication**

- Tests that GLM mode requires `ZAI_AUTH_TOKEN`
- Validates authentication enforcement
- Temporarily isolates `.env` file for testing

### **Test 6: Dependencies**

- Validates required dependencies (`jq`, `claude`)
- Ensures environment is properly configured

### **Test 7: CC Mode Switching**

- Tests switching to Claude Code mode
- Validates configuration changes

### **Test 8: JSON Validation**

- **8a: Valid JSON Creation** - Tests GLM mode creates valid JSON
- **8b: Invalid JSON Handling** - Tests graceful handling of malformed JSON
- **8c: Empty JSON Handling** - Tests handling of empty JSON objects

## Test Output

Running the test suite produces clear output:

```bash
$ ./tests/run_basic_tests.sh

Running basic tests for cc_provider_switcher.sh...
==============================================
Project directory: /home/user/cc-provider-switcher
Test script: /home/user/cc-provider-switcher/tests/test_basic.sh

Basic Test Suite for cc_provider_switcher.sh
=======================================

1. Testing script existence...
✓ Script exists and is executable

2. Testing help command...
✓ Help command works

3. Testing invalid argument handling...
✓ Script properly rejects invalid commands

4. Testing show command...
✓ Show command works

5. Testing GLM mode authentication requirement...
✓ GLM mode properly requires authentication

6. Testing dependencies...
✓ jq dependency available

7. Testing CC mode switch...
✓ CC mode switch works

8. Testing JSON validation...
  Testing valid JSON creation...
✓ GLM mode creates valid JSON
  Testing invalid JSON handling...
✓ Show command handles invalid JSON gracefully
  Testing empty JSON handling...
✓ Show command handles empty JSON

=======================================
✅ All tests passed! (0 failures)

🎉 All basic tests completed successfully!
```

## Test Features

### **Authentication Testing**

The GLM authentication test temporarily isolates the `.env` file to test authentication requirements without affecting the actual configuration.

### **JSON Validation**

Comprehensive JSON testing ensures:

- Valid JSON generation in GLM mode
- Graceful handling of malformed JSON
- Proper processing of empty JSON objects

### **Environment Isolation**

Tests use proper backup/restore to prevent interference with actual Claude Code settings.

## Dependencies

- **bash**: Shell environment (version 4.0+)
- **jq**: JSON validation and manipulation
- **claude**: Claude Code CLI tool

## Writing New Tests

The test suite uses a simple, direct approach:

```bash
#!/bin/bash
# Example test structure

# Test setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SCRIPT="$PROJECT_DIR/cc_provider_switcher.sh"

# Test execution
if [condition]; then
    echo "✓ Test passed"
else
    echo "✗ Test failed"
    exit 1
fi
```

### Best Practices

1. **Use descriptive test names** that explain what is being validated
2. **Test both success and failure scenarios** where applicable
3. **Clean up test artifacts** to prevent interference
4. **Use clear pass/fail indicators** with colors for readability
5. **Test core functionality** - avoid testing implementation details

## Test Metrics

- **Total Tests**: 11 comprehensive tests
- **Lines of Code**: 176 lines (test_basic.sh) + 34 lines (runner)
- **Execution Time**: ~5 seconds
- **Coverage**: Core script functionality + edge cases

## Test Environment

Tests run in the actual user environment but use proper isolation:

- **Configuration**: Tests actual `$HOME/.claude/settings.json`
- **Environment**: Uses real `.env` file when available
- **Cleanup**: Proper backup/restore of configurations
- **Isolation**: Temporary files for authentication testing
