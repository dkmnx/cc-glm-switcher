#!/bin/bash
# Test Helper Functions for cc_glm_switcher.sh
# Provides assertion functions, test environment setup, and result tracking

# Test result counters
PASSED=0
FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test directory (set by setup_test_env)
TEST_DIR=""

# Track all test directories for cleanup
TEST_DIRS=()

# Cleanup flag
CLEANUP_REGISTERED=false

# ============================================================================
# Assertion Functions
# ============================================================================

# assert_equals: Compare two values for equality
# Usage: assert_equals "expected" "actual" "test description"
assert_equals() {
    local expected="$1"
    local actual="$2"
    local description="${3:-assertion}"

    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} PASS: $description"
        return 0
    else
        echo -e "${RED}✗${NC} FAIL: $description"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        return 1
    fi
}

# assert_file_exists: Check if a file exists
# Usage: assert_file_exists "/path/to/file" "test description"
assert_file_exists() {
    local file_path="$1"
    local description="${2:-file exists}"

    if [[ -f "$file_path" ]]; then
        echo -e "${GREEN}✓${NC} PASS: $description"
        return 0
    else
        echo -e "${RED}✗${NC} FAIL: $description"
        echo "  File not found: $file_path"
        return 1
    fi
}

# assert_json_valid: Validate JSON syntax using jq
# Usage: assert_json_valid "/path/to/file.json" "test description"
assert_json_valid() {
    local file_path="$1"
    local description="${2:-JSON validation}"

    if ! [[ -f "$file_path" ]]; then
        echo -e "${RED}✗${NC} FAIL: $description"
        echo "  File not found: $file_path"
        return 1
    fi

    local error_output
    if error_output=$(jq empty "$file_path" 2>&1); then
        echo -e "${GREEN}✓${NC} PASS: $description"
        return 0
    else
        echo -e "${RED}✗${NC} FAIL: $description"
        echo "  JSON validation error: $error_output"
        return 1
    fi
}

# assert_contains: Check if a string or file contains expected substring
# Usage: assert_contains "expected substring" "actual string or file path" "test description"
assert_contains() {
    local expected="$1"
    local source="$2"
    local description="${3:-contains assertion}"
    local content=""

    # Check if source is a file
    if [[ -f "$source" ]]; then
        content=$(cat "$source")
    else
        content="$source"
    fi

    if [[ "$content" == *"$expected"* ]]; then
        echo -e "${GREEN}✓${NC} PASS: $description"
        return 0
    else
        echo -e "${RED}✗${NC} FAIL: $description"
        echo "  Expected substring: '$expected'"
        echo "  Not found in: '${content:0:100}...'"
        return 1
    fi
}

# ============================================================================
# Cleanup Functions
# ============================================================================

# cleanup_all: Clean up all test directories created during the session
# This is registered as a trap handler and can be called manually
cleanup_all() {
    local cleanup_count=0

    # Clean up tracked test directories
    for dir in "${TEST_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            rm -rf "$dir" 2>/dev/null
            ((cleanup_count++))
        fi
    done

    # Clean up current TEST_DIR if set
    if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR" 2>/dev/null
        ((cleanup_count++))
    fi

    # Clean up any orphaned test directories
    local orphaned=$(find /tmp -maxdepth 1 -type d -name "cc_glm_test_*" 2>/dev/null)
    if [[ -n "$orphaned" ]]; then
        while IFS= read -r dir; do
            rm -rf "$dir" 2>/dev/null
            ((cleanup_count++))
        done <<< "$orphaned"
    fi

    if [[ $cleanup_count -gt 0 ]]; then
        echo -e "${YELLOW}→${NC} Cleaned up $cleanup_count test directory/directories"
    fi
}

# register_cleanup: Register cleanup trap handlers
# Automatically called when test_helper.sh is sourced
register_cleanup() {
    if [[ "$CLEANUP_REGISTERED" == "false" ]]; then
        trap cleanup_all EXIT INT TERM
        CLEANUP_REGISTERED=true
    fi
}

# cleanup_old_tests: Remove test directories older than specified hours
# Usage: cleanup_old_tests [hours] (default: 24)
cleanup_old_tests() {
    local hours="${1:-24}"
    local count=0

    echo -e "${YELLOW}→${NC} Cleaning up test directories older than $hours hours..."

    # Find and remove old test directories
    while IFS= read -r dir; do
        if [[ -d "$dir" ]]; then
            rm -rf "$dir" 2>/dev/null && ((count++))
        fi
    done < <(find /tmp -maxdepth 1 -type d -name "cc_glm_test_*" -mmin +$((hours * 60)) 2>/dev/null)

    echo -e "${GREEN}✓${NC} Removed $count old test directory/directories"
}

# ============================================================================
# Test Environment Setup/Teardown
# ============================================================================

# setup_test_env: Create isolated test environment
# Returns: Path to test directory in TEST_DIR variable
setup_test_env() {
    # Create unique test directory
    TEST_DIR="/tmp/cc_glm_test_$$_$(date +%s)"
    mkdir -p "$TEST_DIR"

    # Track this directory for cleanup
    TEST_DIRS+=("$TEST_DIR")

    # Create mock .claude directory structure
    mkdir -p "$TEST_DIR/.claude"
    mkdir -p "$TEST_DIR/configs"

    # Set test-specific environment variables
    export TEST_ROOT_CC="$TEST_DIR/.claude"
    export TEST_ROOT_SCRIPT="$TEST_DIR"
    export TEST_CONFIG_DIR="$TEST_DIR/configs"
    export TEST_LOCK_FILE="$TEST_DIR/.switcher.lock"

    echo -e "${YELLOW}→${NC} Test environment created: $TEST_DIR"
    return 0
}

# teardown_test_env: Clean up test environment
teardown_test_env() {
    if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
        echo -e "${YELLOW}→${NC} Test environment cleaned up: $TEST_DIR"
    fi

    # Unset test environment variables
    unset TEST_ROOT_CC
    unset TEST_ROOT_SCRIPT
    unset TEST_CONFIG_DIR
    unset TEST_LOCK_FILE
    TEST_DIR=""

    return 0
}

# ============================================================================
# Test Execution and Tracking
# ============================================================================

# run_test: Wrapper function to run a test and track results
# Usage: run_test test_function_name
run_test() {
    local test_name="$1"

    echo ""
    echo "========================================="
    echo "Running: $test_name"
    echo "========================================="

    # Run the test function
    if $test_name; then
        ((PASSED++))
    else
        ((FAILED++))
    fi
}

# print_test_summary: Display final test results
print_test_summary() {
    local total=$((PASSED + FAILED))

    echo ""
    echo "========================================="
    echo "Test Summary"
    echo "========================================="
    echo -e "${GREEN}Passed:${NC} $PASSED"
    echo -e "${RED}Failed:${NC} $FAILED"
    echo "Total:  $total"

    if [[ $FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}Some tests failed.${NC}"
        return 1
    fi
}

# ============================================================================
# Helper Functions
# ============================================================================

# create_test_env_file: Create a test .env file
# Usage: create_test_env_file "/path/to/.env"
create_test_env_file() {
    local env_file="$1"
    cat > "$env_file" << 'EOF'
ZAI_AUTH_TOKEN=test_token_123456
MAX_BACKUPS=5
EOF
}

# create_test_settings: Create a minimal settings.json for testing
# Usage: create_test_settings "/path/to/settings.json" "cc|glm"
create_test_settings() {
    local settings_file="$1"
    local mode="${2:-cc}"

    if [[ "$mode" == "glm" ]]; then
        cat > "$settings_file" << 'EOF'
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "test_token",
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "API_TIMEOUT_MS": "300000",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4-flash",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4-plus",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-4-plus",
    "CLAUDE_MODEL_PROVIDER": "zhipu",
    "GLM_MODEL_MAPPING": "haiku:glm-4-flash,sonnet:glm-4-plus,opus:glm-4-plus"
  }
}
EOF
    else
        cat > "$settings_file" << 'EOF'
{
  "env": {}
}
EOF
    fi
}

# ============================================================================
# Automatic Cleanup Registration
# ============================================================================

# Register cleanup handlers on script load
register_cleanup

echo -e "${GREEN}Test helper loaded successfully${NC}"
echo -e "${YELLOW}→${NC} Automatic cleanup registered (EXIT, INT, TERM)"
