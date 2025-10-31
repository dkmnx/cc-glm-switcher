#!/bin/bash

# test_lint.sh - Lint test for shell scripts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source test helper
source "$SCRIPT_DIR/test_helper.sh"

# Test function
test_shellcheck_linting() {
    local script_files=("$REPO_ROOT/cc_glm_switcher.sh" "$REPO_ROOT/install.sh")

    echo "Running shellcheck on main scripts..."

    for script in "${script_files[@]}"; do
        if [[ -f "$script" ]]; then
            if ! shellcheck --severity=error "$script"; then
                echo "shellcheck errors found in $script"
                return 1
            fi
        else
            echo "Script file $script not found"
            return 1
        fi
    done

    echo "Running shellcheck on test files..."

    # Use find to get all test_*.sh files
    while IFS= read -r -d '' test_file; do
        if ! shellcheck --severity=error "$test_file"; then
            echo "shellcheck errors found in $test_file"
            return 1
        fi
    done < <(find tests -name "test_*.sh" -type f -print0)

    echo "All shell scripts passed linting"
    return 0
}

########################################
# Test Runner
########################################

main() {
    set +e
    run_test test_shellcheck_linting || true
    set -e
}

main

set +e
print_test_summary
exit_code=$?
set -e
exit $exit_code