#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<'EOF'
Usage: ./tests/run_all_tests.sh [OPTIONS]

Options:
  --verbose       Show commands as they run
  --check-deps    Verify required tools (jq, shellcheck, bat) are installed
  -h, --help      Show this help message
EOF
}

VERBOSE=false
CHECK_DEPS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose)
            VERBOSE=true
            shift
            ;;
        --check-deps)
            CHECK_DEPS=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ "$CHECK_DEPS" == true ]]; then
    missing=()
    for dep in jq shellcheck bat; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        echo "All dependencies available: jq, shellcheck, bat"
        exit 0
    else
        echo "Missing dependencies: ${missing[*]}" >&2
        exit 1
    fi
fi

tests=(
    "test_core.sh"
    "test_errors.sh"
    "test_cli.sh"
)

declare -A SUITE_LABELS=(
    ["test_core.sh"]="Core Switching & Backups"
    ["test_errors.sh"]="Error Handling"
    ["test_cli.sh"]="CLI Commands"
)

declare -A SUITE_COUNTS=(
    ["test_core.sh"]=20
    ["test_errors.sh"]=9
    ["test_cli.sh"]=8
)

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

TOTAL=0
PASSED=0
FAILED=0
TOTAL_TESTS=0
PASS_TESTS=0
FAIL_TESTS=0
declare -a SUITE_LABEL_LIST=()
declare -a SUITE_STATUS_LIST=()

for test_script in "${tests[@]}"; do
    ((TOTAL+=1))
    suite_tests=${SUITE_COUNTS[$test_script]:-0}
    ((TOTAL_TESTS+=suite_tests))
    if [[ "$VERBOSE" == true ]]; then
        echo "→ Running $test_script..."
    fi

    if bash "$SCRIPT_DIR/$test_script"; then
        ((PASSED+=1))
        PASS_TESTS=$((PASS_TESTS + suite_tests))
        SUITE_LABEL_LIST+=("${SUITE_LABELS[$test_script]:-$test_script}")
        SUITE_STATUS_LIST+=("PASS")
    else
        ((FAILED+=1))
        FAIL_TESTS=$((FAIL_TESTS + suite_tests))
        SUITE_LABEL_LIST+=("${SUITE_LABELS[$test_script]:-$test_script}")
        SUITE_STATUS_LIST+=("FAIL")
    fi
done

printf '\n'
printf "=========================================\n"
printf "Combined Test Summary\n"
printf "=========================================\n"
for idx in "${!SUITE_LABEL_LIST[@]}"; do
    label=${SUITE_LABEL_LIST[$idx]}
    status=${SUITE_STATUS_LIST[$idx]}
    if [[ "$status" == "PASS" ]]; then
        printf "%-24s : %bPASS%b\n" "$label" "$GREEN" "$NC"
    else
        printf "%-24s : %bFAIL%b\n" "$label" "$RED" "$NC"
    fi
done
printf '%s\n' "-----------------------------------------"
printf "Total Suites (Tests) Run : %d (%d)\n" "$TOTAL" "$TOTAL_TESTS"
printf '%s\n' "-----------------------------------------"
printf "%bPassed : %b%d (%d)%b\n" "$GREEN" "$NC" "$PASSED" "$PASS_TESTS" "$NC"
printf "%bFailed : %b%d (%d)%b\n" "$RED" "$NC" "$FAILED" "$FAIL_TESTS" "$NC"
printf '%s\n' "-----------------------------------------"
if [[ "$FAILED" -eq 0 ]]; then
    printf "Result: %bPASS%b ✅ All test suites passed.\n" "$GREEN" "$NC"
    printf "=========================================\n"
    exit 0
else
    printf "Result: %bFAIL%b ❌ Some test suites failed.\n" "$RED" "$NC"
    printf "=========================================\n"
    exit 1
fi
