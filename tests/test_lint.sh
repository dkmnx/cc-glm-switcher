#!/bin/bash

# test_lint.sh - Lint test for shell scripts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source test helper
# shellcheck source=tests/test_helper.sh
source "$SCRIPT_DIR/test_helper.sh"

# Test function
# shellcheck disable=SC2329  # Function is invoked indirectly via run_test
test_shellcheck_linting() {
    # shellcheck disable=SC2317  # Code is reachable
    echo "Running shellcheck on all scripts..."

    # shellcheck disable=SC2317  # Code is reachable
    if ! shellcheck cc_glm_switcher.sh install.sh tests/*.sh; then
        # shellcheck disable=SC2317  # Code is reachable
        echo "shellcheck found issues"
        # shellcheck disable=SC2317  # Code is reachable
        return 1
    fi

    # shellcheck disable=SC2317  # Code is reachable
    echo "All shell scripts passed linting with no warnings"
    # shellcheck disable=SC2317  # Code is reachable
    return 0
}

########################################
# Test Runner
########################################

main() {
    set +e
    run_test test_shellcheck_linting
    set -e
}

main

set +e
print_test_summary
exit_code=$?
set -e
exit $exit_code