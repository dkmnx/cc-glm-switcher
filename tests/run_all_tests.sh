#!/usr/bin/env bash

# Master test runner for cc-glm-switcher
# Runs all test suites and provides a summary report

set -euo pipefail

# Test directory configuration
readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(dirname "$TEST_DIR")"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Test counters
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

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

# Print header
print_header() {
    echo ""
    echo "=================================================="
    echo "cc-glm-switcher Test Suite Runner"
    echo "=================================================="
    echo "Testing: Claude Code ↔ Z.AI GLM Model Switcher"
    echo "Directory: $ROOT_DIR"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=================================================="
    echo ""
}

# Print footer
print_footer() {
    echo ""
    echo "=================================================="
    echo "Test Summary"
    echo "=================================================="
    echo -e "Test Suites: ${BLUE}$TOTAL_SUITES${NC} (Passed: ${GREEN}$PASSED_SUITES${NC}, Failed: ${RED}$FAILED_SUITES${NC})"
    echo -e "Total Tests: ${BLUE}$TOTAL_TESTS${NC} (Passed: ${GREEN}$PASSED_TESTS${NC}, Failed: ${RED}$FAILED_TESTS${NC})"
    echo ""

    if [ $FAILED_SUITES -eq 0 ]; then
        echo -e "${GREEN}✓ All test suites passed!${NC}"
        echo -e "${GREEN}✓ All $TOTAL_TESTS individual tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some test suites failed!${NC}"
        echo -e "${RED}✗ $FAILED_TESTS out of $TOTAL_TESTS tests failed!${NC}"
        return 1
    fi
}

# Run a single test suite
run_test_suite() {
    local test_file="$1"
    local suite_name
    suite_name=$(basename "$test_file" .sh)

    ((TOTAL_SUITES++))

    log_info "Running test suite: $suite_name"
    echo "----------------------------------------"

    # Make test file executable
    chmod +x "$test_file"

    # Run the test suite and capture output
    local test_output
    local test_exit_code=0
    test_output=$("$test_file" 2>&1) || test_exit_code=$?
    
    # Print the test output
    echo "$test_output"

    # Extract test results from the test output (common for both success and failure)
    local suite_passed=0
    local suite_total=0
    local suite_failed=0
    
    # Extract test results from the output (strip ANSI codes first)
    local clean_output
    clean_output=$(echo "$test_output" | sed 's/\x1b\[[0-9;]*m//g')
    
    local total_line
    local passed_line
    local failed_line
    
    total_line=$(echo "$clean_output" | grep "Total Assertions:" | tail -1)
    passed_line=$(echo "$clean_output" | grep "Passed:" | tail -1)
    failed_line=$(echo "$clean_output" | grep "Failed:" | tail -1)
    
    if [[ -n "$total_line" ]] && [[ -n "$passed_line" ]] && [[ -n "$failed_line" ]]; then
        local total_match
        local passed_match
        local failed_match
        
        total_match=$(echo "$total_line" | sed 's/.*Total Assertions: *\([0-9]*\).*/\1/' || echo "")
        passed_match=$(echo "$passed_line" | sed 's/.*Passed: *\([0-9]*\).*/\1/' || echo "")
        failed_match=$(echo "$failed_line" | sed 's/.*Failed: *\([0-9]*\).*/\1/' || echo "")
        
        # Validate that we got numeric values
        if [[ "$total_match" =~ ^[0-9]+$ ]] && [[ "$passed_match" =~ ^[0-9]+$ ]] && [[ "$failed_match" =~ ^[0-9]+$ ]]; then
            suite_total=$total_match
            suite_passed=$passed_match
            suite_failed=$failed_match
        fi
    fi

    if [ $test_exit_code -eq 0 ]; then
        ((PASSED_SUITES++))
        log_success "Test suite '$suite_name' passed"
    else
        ((FAILED_SUITES++))
        log_error "Test suite '$suite_name' failed"
    fi

    # Update totals
    ((TOTAL_TESTS += suite_total))
    ((PASSED_TESTS += suite_passed))
    ((FAILED_TESTS += suite_failed))

    echo "----------------------------------------"
    echo ""
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."

    local missing_deps=()

    # Check for required commands
    local required_commands=("jq" "bash")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        echo "Please install the missing dependencies and try again."
        return 1
    fi

    log_success "All dependencies are available"
}

# Setup test environment
setup_test_environment() {
    log_info "Setting up test environment..."

    # Ensure test directories exist
    mkdir -p "$TEST_DIR/test_configs"
    mkdir -p "$TEST_DIR/test_claude"

    # Ensure test scripts are executable
    find "$TEST_DIR" -name "test_*.sh" -exec chmod +x {} \;

    log_success "Test environment setup complete"
}

# Cleanup test environment
cleanup_test_environment() {
    log_info "Cleaning up test environment..."

    # Remove any leftover test files
    rm -rf "$TEST_DIR/test_configs"
    rm -rf "$TEST_DIR/test_claude"
    rm -f "$TEST_DIR/.env"
    rm -f "$TEST_DIR/test_results.txt"

    log_success "Test environment cleanup complete"
}

# Run all test suites
run_all_tests() {
    local test_files=(
        "test_model_switching.sh"
        "test_backup_restore.sh"
        "test_cli_options.sh"
        "test_error_handling.sh"
    )

    local failed_suites=()

    for test_file in "${test_files[@]}"; do
        if [ -f "$TEST_DIR/$test_file" ]; then
            if ! run_test_suite "$TEST_DIR/$test_file"; then
                failed_suites+=("$test_file")
            fi
        else
            log_error "Test file not found: $test_file"
            ((FAILED_SUITES++))
            failed_suites+=("$test_file")
        fi
    done

    # Report any failed suites
    if [ ${#failed_suites[@]} -gt 0 ]; then
        echo ""
        log_error "Failed test suites:"
        for suite in "${failed_suits[@]}"; do
            echo "  - $suite"
        done
        return 1
    fi

    return 0
}

# Run specific test suites
run_specific_tests() {
    local suites_to_run=("$@")
    local failed_suites=()

    for suite in "${suites_to_run[@]}"; do
        local test_file="$TEST_DIR/test_${suite}.sh"
        if [ -f "$test_file" ]; then
            if ! run_test_suite "$test_file"; then
                failed_suites+=("$suite")
            fi
        else
            log_error "Test suite not found: $suite"
            ((FAILED_SUITES++))
            failed_suites+=("$suite")
        fi
    done

    # Report any failed suites
    if [ ${#failed_suites[@]} -gt 0 ]; then
        echo ""
        log_error "Failed test suites:"
        for suite in "${failed_suites[@]}"; do
            echo "  - $suite"
        done
        return 1
    fi

    return 0
}

# Display usage information
show_usage() {
    echo "Usage: $0 [OPTIONS] [TEST_SUITES...]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -v, --verbose       Enable verbose output"
    echo "  -c, --cleanup       Cleanup test environment and exit"
    echo "  --check-deps       Check dependencies only"
    echo ""
    echo "Test Suites:"
    echo "  model-switching    Model switching functionality tests"
    echo "  backup-restore     Backup and restore functionality tests"
    echo "  cli-options        Command-line options and flags tests"
    echo "  error-handling    Error conditions and edge cases tests"
    echo ""
    echo "Examples:"
    echo "  $0                    Run all test suites"
    echo "  $0 model-switching    Run only model switching tests"
    echo "  $0 backup-restore cli-options  Run specific test suites"
    echo "  $0 --verbose          Run with verbose output"
    echo "  $0 --cleanup           Cleanup test environment"
    echo ""
    echo "Environment Variables:"
    echo "  TEST_VERBOSE       Enable verbose test output"
    echo "  TEST_KEEP_FILES     Keep test files after cleanup"
    echo ""
}

# Main execution
main() {
    local verbose=false
    local cleanup_only=false
    local check_deps_only=false
    local specific_suites=()

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -c|--cleanup)
                cleanup_only=true
                shift
                ;;
            --check-deps)
                check_deps_only=true
                shift
                ;;
            model-switching|backup-restore|cli-options|error-handling)
                specific_suites+=("$1")
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                log_error "Unknown argument: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Set verbose mode if requested
    if [ "$verbose" = true ]; then
        set -x
    fi

    # Handle cleanup only mode
    if [ "$cleanup_only" = true ]; then
        cleanup_test_environment
        exit 0
    fi

    # Handle dependency check only mode
    if [ "$check_deps_only" = true ]; then
        check_dependencies
        exit 0
    fi

    # Print header
    print_header

    # Check dependencies
    if ! check_dependencies; then
        log_error "Dependency check failed"
        exit 1
    fi

    # Setup test environment
    setup_test_environment

    # Run tests
    local exit_code=0
    if [ ${#specific_suites[@]} -gt 0 ]; then
        log_info "Running specific test suites: ${specific_suites[*]}"
        if ! run_specific_tests "${specific_suites[@]}"; then
            exit_code=1
        fi
    else
        log_info "Running all test suites"
        if ! run_all_tests; then
            exit_code=1
        fi
    fi

    # Cleanup
    cleanup_test_environment

    # Print summary
    print_footer

    exit $exit_code
}

# Run script if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi