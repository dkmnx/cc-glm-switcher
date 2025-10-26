#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2329

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load shared helpers
# shellcheck source=tests/test_helper.sh
source "$SCRIPT_DIR/test_helper.sh"

ORIGINAL_PATH="$PATH"
REAL_JQ="$(command -v jq)"
RUN_OUTPUT=""
RUN_STATUS=0

write_env_file() {
    local token="$1"
    local max_backups="${2:-5}"

    cat > "$TEST_DIR/.env" <<EOF
ZAI_AUTH_TOKEN=$token
MAX_BACKUPS=$max_backups
EOF
    # Set secure permissions for test .env file
    chmod 600 "$TEST_DIR/.env"
}

setup_error_test() {
    setup_test_env

    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/claude" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$TEST_DIR/bin/claude"

    export PATH="$TEST_DIR/bin:$ORIGINAL_PATH"
    export ROOT_CC="$TEST_ROOT_CC"
    export ROOT_SCRIPT="$TEST_ROOT_SCRIPT"
    export CONFIG_DIR="$TEST_CONFIG_DIR"
    export LOCK_FILE="$TEST_LOCK_FILE"
}

finish_error_test() {
    export PATH="$ORIGINAL_PATH"
    teardown_test_env
    unset ROOT_CC ROOT_SCRIPT CONFIG_DIR LOCK_FILE
}

run_switcher_capture() {
    set +e
    RUN_OUTPUT=$(
        # Run from /tmp to avoid local .env file interference
        cd /tmp && \
        ROOT_CC="$ROOT_CC" ROOT_SCRIPT="$ROOT_SCRIPT" CONFIG_DIR="$CONFIG_DIR" \
            TEST_DIR="$TEST_DIR" LOCK_FILE="$LOCK_FILE" PATH="$PATH" \
            "$REPO_ROOT/cc_glm_switcher.sh" "$@" 2>&1
    )
    RUN_STATUS=$?
    set -e
    return "$RUN_STATUS"
}

########################################
# Dependency and File Error Tests
########################################

test_missing_jq_detected() {
    setup_error_test
    local status=0
    {
        ln -s "$(command -v bash)" "$TEST_DIR/bin/bash"
        export PATH="$TEST_DIR/bin"
        run_switcher_capture cc
        if [ "$RUN_STATUS" -eq 0 ]; then
            status=1
            echo "Missing jq: command succeeded unexpectedly"
        elif [[ "$RUN_OUTPUT" != *"jq command not found"* ]]; then
            status=1
            echo "Missing jq: expected error message, got: $RUN_OUTPUT"
        fi
    } || status=$?
    finish_error_test
    return "$status"
}

test_missing_env_file_for_glm() {
    setup_error_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "cc"
        run_switcher_capture glm
        if [ "$RUN_STATUS" -eq 0 ]; then
            status=1
            echo "Missing .env: command succeeded unexpectedly"
        elif [[ "$RUN_OUTPUT" != *".env file not found"* ]]; then
            status=1
            echo "Missing .env: expected error message, got: $RUN_OUTPUT"
        fi
    } || status=$?
    finish_error_test
    return "$status"
}

test_corrupted_settings_abort_operation() {
    setup_error_test
    local status=0
    {
        printf '{invalid json' > "$ROOT_CC/settings.json"
        run_switcher_capture cc
        if [ "$RUN_STATUS" -eq 0 ]; then
            status=1
            echo "Corrupted settings: command succeeded unexpectedly"
        elif [[ "$RUN_OUTPUT" != *"Current settings.json is invalid"* ]]; then
            status=1
            echo "Corrupted settings: missing validation message"
        fi
    } || status=$?
    finish_error_test
    return "$status"
}

test_missing_settings_creates_minimal_file() {
    setup_error_test
    local status=0
    {
        rm -f "$ROOT_CC/settings.json"
        run_switcher_capture cc
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
            echo "Missing settings: command failed"
        elif [ ! -f "$ROOT_CC/settings.json" ]; then
            status=1
            echo "Missing settings: file not created"
        elif ! "$REAL_JQ" -e 'type == "object" and (keys | length == 0)' "$ROOT_CC/settings.json" >/dev/null; then
            status=1
            echo "Missing settings: expected empty object"
        fi
    } || status=$?
    finish_error_test
    return "$status"
}

test_lock_prevents_concurrent_execution() {
    setup_error_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "cc"
        echo "12345" > "$LOCK_FILE"
        run_switcher_capture cc
        if [ "$RUN_STATUS" -eq 0 ]; then
            status=1
            echo "Lock: command succeeded with existing lock"
        elif [[ "$RUN_OUTPUT" != *"Another instance is already running"* ]]; then
            status=1
            echo "Lock: expected lock error message"
        fi
    } || status=$?
    finish_error_test
    return "$status"
}

########################################
# Input Validation Tests
########################################

test_invalid_token_format_rejected() {
    setup_error_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "cc"
        write_env_file "invalid!token"
        run_switcher_capture glm
        if [ "$RUN_STATUS" -eq 0 ]; then
            status=1
            echo "Invalid token: command succeeded"
        elif [[ "$RUN_OUTPUT" != *"Invalid ZAI_AUTH_TOKEN format"* ]]; then
            status=1
            echo "Invalid token: expected format error message"
        fi
    } || status=$?
    finish_error_test
    return "$status"
}

test_empty_token_rejected() {
    setup_error_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "cc"
        cat > "$TEST_DIR/.env" <<'EOF'
ZAI_AUTH_TOKEN=
MAX_BACKUPS=5
EOF
        chmod 600 "$TEST_DIR/.env"
        run_switcher_capture glm
        if [ "$RUN_STATUS" -eq 0 ]; then
            status=1
            echo "Empty token: command succeeded"
        elif [[ "$RUN_OUTPUT" != *"ZAI_AUTH_TOKEN not found in .env file"* ]]; then
            status=1
            echo "Empty token: expected missing token error"
        fi
    } || status=$?
    finish_error_test
    return "$status"
}

test_invalid_backup_number_errors() {
    setup_error_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "cc"
        write_env_file "test_token_123456"
        run_switcher_capture glm
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
            echo "Invalid backup: setup glm failed"
        else
            run_switcher_capture restore 99
            if [ "$RUN_STATUS" -eq 0 ]; then
                status=1
                echo "Invalid backup: restore succeeded unexpectedly"
            elif [[ "$RUN_OUTPUT" != *"Invalid backup number"* ]]; then
                status=1
                echo "Invalid backup: expected error message"
            fi
        fi
    } || status=$?
    finish_error_test
    return "$status"
}

test_unknown_command_shows_usage() {
    setup_error_test
    local status=0
    {
        run_switcher_capture foobar
        if [ "$RUN_STATUS" -eq 0 ]; then
            status=1
            echo "Unknown command: succeeded unexpectedly"
        elif [[ "$RUN_OUTPUT" != *"Error: Unknown option foobar"* ]]; then
            status=1
            echo "Unknown command: unexpected output"
        fi
    } || status=$?
    finish_error_test
    return "$status"
}

########################################
# Test Runner
########################################

main() {
    set +e
    run_test test_missing_jq_detected || true
    run_test test_missing_env_file_for_glm || true
    run_test test_corrupted_settings_abort_operation || true
    run_test test_missing_settings_creates_minimal_file || true
    run_test test_lock_prevents_concurrent_execution || true
    run_test test_invalid_token_format_rejected || true
    run_test test_empty_token_rejected || true
    run_test test_invalid_backup_number_errors || true
    run_test test_unknown_command_shows_usage || true
    set -e
}

main

set +e
print_test_summary
exit_code=$?
set -e
exit $exit_code
