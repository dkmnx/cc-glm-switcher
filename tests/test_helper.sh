#!/usr/bin/env bash

# Test helper functions for cc-glm-switcher
# Provides utilities for testing the script functionality

set -euo pipefail

# Test configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
ROOT_DIR="$(dirname "$TEST_DIR")"
readonly ROOT_DIR
readonly TEST_CONFIG_DIR="$TEST_DIR/test_configs"
readonly TEST_CLAUDE_DIR="$TEST_DIR/test_claude"
# shellcheck disable=SC2034  # Intentionally kept for potential future use
readonly FIXTURES_DIR="$TEST_DIR/fixtures"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-"Expected '$expected', got '$actual'"}"

    ((TESTS_TOTAL++))

    if [ "$expected" = "$actual" ]; then
        log_success "$message"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-"File should exist: $file"}"

    ((TESTS_TOTAL++))

    if [ -f "$file" ]; then
        log_success "$message"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-"File should not exist: $file"}"

    ((TESTS_TOTAL++))

    if [ ! -f "$file" ]; then
        log_success "$message"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-"String should contain: $needle"}"

    ((TESTS_TOTAL++))

    if [[ "$haystack" == *"$needle"* ]]; then
        log_success "$message"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_json_valid() {
    local file="$1"
    local message="${2:-"JSON should be valid: $file"}"

    ((TESTS_TOTAL++))

    if validate_json "$file"; then
        log_success "$message"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_not_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-"Expected not '$expected', but got '$actual'"}"

    ((TESTS_TOTAL++))

    if [ "$expected" != "$actual" ]; then
        log_success "$message"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_directory_exists() {
    local dir="$1"
    local message="${2:-"Directory should exist: $dir"}"

    ((TESTS_TOTAL++))

    if [ -d "$dir" ]; then
        log_success "$message"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test setup and teardown functions
setup_test_environment() {
    log_info "Setting up test environment..."

    # Create test directories
    mkdir -p "$TEST_CONFIG_DIR"
    mkdir -p "$TEST_CLAUDE_DIR"

    # Create test .env file
    cat > "$TEST_DIR/.env" << EOF
ZAI_AUTH_TOKEN=test_token_12345
MAX_BACKUPS=3
EOF

    # Create initial test settings.json
    cat > "$TEST_CLAUDE_DIR/settings.json" << EOF
{
  "statusLine": {
    "type": "command",
    "command": "bash /home/osiris/.claude/statusline-command.sh"
  },
  "enabledPlugins": {
    "arm-cortex-microcontrollers@claude-code-workflows": true
  },
  "alwaysThinkingEnabled": true
}
EOF

    # Set up environment variables for the script
    export ROOT_CC="$TEST_CLAUDE_DIR"
    export ROOT_SCRIPT="$ROOT_DIR"
    export CONFIG_DIR="$TEST_CONFIG_DIR"
    
    # Also export for subshells
    export TEST_DIR TEST_CONFIG_DIR TEST_CLAUDE_DIR ROOT_DIR

    log_info "Test environment setup complete"
}

cleanup_test_environment() {
    log_info "Cleaning up test environment..."

    # Remove test directories
    rm -rf "$TEST_CONFIG_DIR"
    rm -rf "$TEST_CLAUDE_DIR"
    rm -f "$TEST_DIR/.env"

    # Unset environment variables
    unset ROOT_CC ROOT_SCRIPT CONFIG_DIR

    log_info "Test environment cleanup complete"
}

# Backup and restore functions for tests
backup_current_settings() {
    if [ -f "$TEST_CLAUDE_DIR/settings.json" ]; then
        cp "$TEST_CLAUDE_DIR/settings.json" "$TEST_CONFIG_DIR/settings_backup_before_test.json"
    fi
}

restore_test_settings() {
    if [ -f "$TEST_CONFIG_DIR/settings_backup_before_test.json" ]; then
        cp "$TEST_CONFIG_DIR/settings_backup_before_test.json" "$TEST_CLAUDE_DIR/settings.json"
    fi
}

# Import validate_json function from main script
validate_json() {
    local file="$1"

    # Check if file exists and is not empty
    if [ ! -s "$file" ]; then
        return 1
    fi

    # Validate JSON syntax
    if ! jq empty "$file" >/dev/null 2>&1; then
        return 1
    fi

    return 0
}

# Utility functions
count_backup_files() {
    find "$TEST_CONFIG_DIR" -name "settings_backup_*.json" -type f | wc -l
}

get_latest_backup() {
    local latest
    latest=$(find "$TEST_CONFIG_DIR" -name "settings_backup_*.json" -type f -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)
    if [ -z "$latest" ]; then
        echo ""
    else
        echo "$latest"
    fi
}

create_test_backup() {
    local suffix="${1:-$(date +"%Y%m%d_%H%M%S")}"
    cp "$TEST_CLAUDE_DIR/settings.json" "$TEST_CONFIG_DIR/settings_backup_${suffix}.json"
}

# Test result reporting
print_test_results() {
    echo ""
    echo "=================================="
    echo "Test Results Summary"
    echo "=================================="
    echo -e "Total Assertions: ${BLUE}$TESTS_TOTAL${NC}"
    echo -e "Passed:           ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed:           ${RED}$TESTS_FAILED${NC}"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ All assertions passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some assertions failed!${NC}"
        return 1
    fi
}

# Run a test function with setup and teardown
run_test() {
    local test_name="$1"
    local test_function="$2"

    log_info "Running test: $test_name"

    # Setup test environment
    setup_test_environment

    # Run the test
    if "$test_function"; then
        log_success "Test passed: $test_name"
    else
        log_error "Test failed: $test_name"
    fi

    # Cleanup
    cleanup_test_environment

    echo ""
}