#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2329

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load shared helpers
# shellcheck source=tests/test_helper.sh
source "$SCRIPT_DIR/test_helper.sh"

ORIGINAL_PATH="$PATH"
RUN_OUTPUT=""
RUN_STATUS=0

write_env_file() {
    local token="$1"
    local max_backups="${2:-5}"

    cat > "$TEST_DIR/.env" <<EOF
ZAI_AUTH_TOKEN=$token
MAX_BACKUPS=$max_backups
EOF
}

setup_cli_test() {
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

finish_cli_test() {
    export PATH="$ORIGINAL_PATH"
    teardown_test_env
    unset ROOT_CC ROOT_SCRIPT CONFIG_DIR LOCK_FILE
}

run_switcher_capture() {
    set +e
    RUN_OUTPUT=$(
        cd "$TEST_DIR" && \
        ROOT_CC="$ROOT_CC" ROOT_SCRIPT="$ROOT_SCRIPT" CONFIG_DIR="$CONFIG_DIR" \
            LOCK_FILE="$LOCK_FILE" PATH="$PATH" \
            "$REPO_ROOT/cc_glm_switcher.sh" "$@" 2>&1
    )
    RUN_STATUS=$?
    set -e
    return "$RUN_STATUS"
}

########################################
# Command Parsing Tests
########################################

test_cli_cc_switch_outputs_success() {
    setup_cli_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "glm"
        run_switcher_capture cc
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
            echo "CLI cc: command failed"
        elif [[ "$RUN_OUTPUT" != *"Switched to Claude Code model"* ]]; then
            status=1
            echo "CLI cc: expected success message"
        fi
    } || status=$?
    finish_cli_test
    return "$status"
}

test_cli_glm_switch_outputs_success() {
    setup_cli_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "cc"
        write_env_file "test_token_123456"
        run_switcher_capture glm
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
            echo "CLI glm: command failed"
        elif [[ "$RUN_OUTPUT" != *"Switched to Z.AI GLM model"* ]]; then
            status=1
            echo "CLI glm: expected success message"
        fi
    } || status=$?
    finish_cli_test
    return "$status"
}

test_cli_list_command_lists_backups() {
    setup_cli_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "cc"
        write_env_file "test_token_123456"
        run_switcher_capture glm
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
            echo "CLI list: failed to create first backup"
        else
            sleep 1
            run_switcher_capture cc
            if [ "$RUN_STATUS" -ne 0 ]; then
                status=1
                echo "CLI list: failed to create second backup"
            else
                run_switcher_capture list
                if [ "$RUN_STATUS" -ne 0 ]; then
                    status=1
                    echo "CLI list: command failed"
                elif [[ "$RUN_OUTPUT" != *"Available backup files"* ]] || [[ "$RUN_OUTPUT" != *"Total backups:"* ]]; then
                    status=1
                    echo "CLI list: expected listing output"
                fi
            fi
        fi
    } || status=$?
    finish_cli_test
    return "$status"
}

test_cli_restore_command_restores_backup() {
    setup_cli_test
    local status=0
    {
        cat > "$ROOT_CC/settings.json" <<'EOF'
{
  "env": {
    "CUSTOM_VAR": "original"
  }
}
EOF
        write_env_file "test_token_123456"
        run_switcher_capture glm
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
            echo "CLI restore: failed to create backup"
        else
            run_switcher_capture restore 1
            if [ "$RUN_STATUS" -ne 0 ]; then
                status=1
                echo "CLI restore: command failed"
            elif [[ "$RUN_OUTPUT" != *"Settings restored from"* ]]; then
                status=1
                echo "CLI restore: expected restore message"
            elif ! jq -e '.env.CUSTOM_VAR == "original"' "$ROOT_CC/settings.json" >/dev/null; then
                status=1
                echo "CLI restore: custom variable missing after restore"
            fi
        fi
    } || status=$?
    finish_cli_test
    return "$status"
}

########################################
# Option Tests
########################################

test_cli_verbose_emits_info_messages() {
    setup_cli_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "glm"
        run_switcher_capture cc -v
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
            echo "CLI verbose: command failed"
        elif [[ "$RUN_OUTPUT" != *"[INFO]"* ]]; then
            status=1
            echo "CLI verbose: expected info messages"
        fi
    } || status=$?
    finish_cli_test
    return "$status"
}

test_cli_dry_run_makes_no_changes() {
    setup_cli_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "cc"
        cp "$ROOT_CC/settings.json" "$TEST_DIR/before.json"
        write_env_file "test_token_123456"
        run_switcher_capture glm --dry-run
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
            echo "CLI dry run: command failed"
        elif [[ "$RUN_OUTPUT" != *"DRY RUN: Would switch to Z.AI GLM model"* ]]; then
            status=1
            echo "CLI dry run: expected dry-run message"
        elif ! cmp -s "$ROOT_CC/settings.json" "$TEST_DIR/before.json"; then
            status=1
            echo "CLI dry run: settings were modified"
        fi
    } || status=$?
    finish_cli_test
    return "$status"
}

test_cli_help_shows_usage() {
    setup_cli_test
    local status=0
    {
        run_switcher_capture -h
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
            echo "CLI help: expected exit code 0"
        elif [[ "$RUN_OUTPUT" != *"Usage:"* ]]; then
            status=1
            echo "CLI help: usage not displayed"
        fi
    } || status=$?
    finish_cli_test
    return "$status"
}

test_cli_version_displays_version() {
    setup_cli_test
    local status=0
    {
        run_switcher_capture -V
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
            echo "CLI version: expected exit code 0"
        elif [[ "$RUN_OUTPUT" != *"cc-glm-switcher v"* ]]; then
            status=1
            echo "CLI version: version string missing"
        fi
    } || status=$?
    finish_cli_test
    return "$status"
}

########################################
# Test Runner
########################################

main() {
    set +e
    run_test test_cli_cc_switch_outputs_success || true
    run_test test_cli_glm_switch_outputs_success || true
    run_test test_cli_list_command_lists_backups || true
    run_test test_cli_restore_command_restores_backup || true
    run_test test_cli_verbose_emits_info_messages || true
    run_test test_cli_dry_run_makes_no_changes || true
    run_test test_cli_help_shows_usage || true
    run_test test_cli_version_displays_version || true
    set -e
}

main

set +e
print_test_summary
exit_code=$?
set -e
exit $exit_code
