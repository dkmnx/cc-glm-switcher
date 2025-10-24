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

setup_core_test() {
    setup_test_env

    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/claude" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$TEST_DIR/bin/claude"

    export PATH="$TEST_DIR/bin:$ORIGINAL_PATH"
    write_env_file "test_token_123456" "5"

    export ROOT_CC="$TEST_ROOT_CC"
    export ROOT_SCRIPT="$TEST_ROOT_SCRIPT"
    export CONFIG_DIR="$TEST_CONFIG_DIR"
    export LOCK_FILE="$TEST_LOCK_FILE"
}

finish_core_test() {
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

latest_backup_file() {
    find "$CONFIG_DIR" -maxdepth 1 -type f -name 'settings_backup_*.json' \
        -printf '%T@ %p\n' | sort -nr | head -n1 | cut -d' ' -f2-
}

backup_count() {
    find "$CONFIG_DIR" -maxdepth 1 -type f -name 'settings_backup_*.json' | wc -l | tr -d ' '
}

########################################
# Model Switching Tests
########################################

test_switch_to_glm_adds_required_env_vars() {
    setup_core_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "cc"
        run_switcher_capture glm
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
        else
            if ! jq -e '.env.ANTHROPIC_AUTH_TOKEN == "test_token_123456"' "$ROOT_CC/settings.json" >/dev/null; then
                status=1
                echo "GLM switch: missing auth token"
            fi
            if ! jq -e '.env.API_TIMEOUT_MS == "3000000"' "$ROOT_CC/settings.json" >/dev/null; then
                status=1
                echo "GLM switch: incorrect timeout"
            fi
            if ! jq -e '.env.GLM_MODEL_MAPPING == "haiku:glm-4.5-air,sonnet:glm-4.6,opus:glm-4.6"' "$ROOT_CC/settings.json" >/dev/null; then
                status=1
                echo "GLM switch: incorrect model mapping"
            fi
        fi
    } || status=$?
    finish_core_test
    return "$status"
}

test_switch_to_glm_sets_correct_endpoint() {
    setup_core_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "cc"
        run_switcher_capture glm
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
        elif ! jq -e '.env.ANTHROPIC_BASE_URL == "https://api.z.ai/api/anthropic"' "$ROOT_CC/settings.json" >/dev/null; then
            status=1
            echo "GLM switch: incorrect API endpoint"
        fi
    } || status=$?
    finish_core_test
    return "$status"
}

test_switch_to_glm_sets_provider_zhipu() {
    setup_core_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "cc"
        run_switcher_capture glm
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
        elif ! jq -e '.env.CLAUDE_MODEL_PROVIDER == "zhipu"' "$ROOT_CC/settings.json" >/dev/null; then
            status=1
            echo "GLM switch: provider not set to zhipu"
        fi
    } || status=$?
    finish_core_test
    return "$status"
}

test_switch_to_glm_reads_token_from_env() {
    setup_core_test
    local status=0
    {
        write_env_file "custom_token_987" "5"
        create_test_settings "$ROOT_CC/settings.json" "cc"
        run_switcher_capture glm
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
        elif ! jq -e '.env.ANTHROPIC_AUTH_TOKEN == "custom_token_987"' "$ROOT_CC/settings.json" >/dev/null; then
            status=1
            echo "GLM switch: token not loaded from .env"
        fi
    } || status=$?
    finish_core_test
    return "$status"
}

test_switch_to_glm_creates_backup() {
    setup_core_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "cc"
        run_switcher_capture glm
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
        else
            local latest
            latest=$(latest_backup_file || true)
            if [ -z "$latest" ]; then
                status=1
                echo "GLM switch: backup not created"
            elif [ ! -f "$latest" ]; then
                status=1
                echo "GLM switch: backup path invalid"
            fi
        fi
    } || status=$?
    finish_core_test
    return "$status"
}

test_switch_to_cc_removes_glm_specific_variables() {
    setup_core_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "glm"
        run_switcher_capture cc
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
        else
            if jq -e '(.env // {}) | has("CLAUDE_MODEL_PROVIDER")' "$ROOT_CC/settings.json" >/dev/null; then
                status=1
                echo "CC switch: provider should be removed"
            fi
            if jq -e '(.env // {}) | has("ANTHROPIC_BASE_URL")' "$ROOT_CC/settings.json" >/dev/null; then
                status=1
                echo "CC switch: API endpoint should be removed"
            fi
        fi
    } || status=$?
    finish_core_test
    return "$status"
}

test_switch_to_cc_preserves_custom_variables() {
    setup_core_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "glm"
        jq '.env.CUSTOM_VAR = "keep-me"' "$ROOT_CC/settings.json" > "$ROOT_CC/settings_tmp.json"
        mv "$ROOT_CC/settings_tmp.json" "$ROOT_CC/settings.json"

        run_switcher_capture cc
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
        elif ! jq -e '.env.CUSTOM_VAR == "keep-me"' "$ROOT_CC/settings.json" >/dev/null; then
            status=1
            echo "CC switch: custom variable removed"
        fi
    } || status=$?
    finish_core_test
    return "$status"
}

test_switch_to_cc_creates_backup() {
    setup_core_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "glm"
        run_switcher_capture cc
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
        else
            local latest
            latest=$(latest_backup_file || true)
            if [ -z "$latest" ]; then
                status=1
                echo "CC switch: backup not created"
            elif [ ! -f "$latest" ]; then
                status=1
                echo "CC switch: backup path invalid"
            fi
        fi
    } || status=$?
    finish_core_test
    return "$status"
}

test_round_trip_preserves_original_settings() {
    setup_core_test
    local status=0
    {
        cat > "$ROOT_CC/settings.json" <<'EOF'
{
  "env": {
    "CUSTOM_VAR": "original",
    "ANOTHER_SETTING": "true"
  }
}
EOF
        cp "$ROOT_CC/settings.json" "$TEST_DIR/original_settings.json"

        run_switcher_capture glm
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
        else
            run_switcher_capture cc
            if [ "$RUN_STATUS" -ne 0 ]; then
                status=1
            elif ! cmp -s "$ROOT_CC/settings.json" "$TEST_DIR/original_settings.json"; then
                status=1
                echo "Round trip: original settings not preserved"
            fi
        fi
    } || status=$?
    finish_core_test
    return "$status"
}

test_dry_run_does_not_modify_settings() {
    setup_core_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "cc"
        cp "$ROOT_CC/settings.json" "$TEST_DIR/before.json"

        run_switcher_capture glm --dry-run
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
        elif ! cmp -s "$ROOT_CC/settings.json" "$TEST_DIR/before.json"; then
            status=1
            echo "Dry run: settings were modified"
        fi
    } || status=$?
    finish_core_test
    return "$status"
}

########################################
# Backup System Tests
########################################

test_backup_filename_uses_timestamp_format() {
    setup_core_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "cc"
        run_switcher_capture glm
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
        else
            local latest
            latest=$(latest_backup_file || true)
            if [ -z "$latest" ]; then
                status=1
                echo "Backup timestamp: missing backup"
            else
                local name
                name=$(basename "$latest")
                if [[ ! "$name" =~ ^settings_backup_[0-9]{8}_[0-9]{6}\.json$ ]]; then
                    status=1
                    echo "Backup timestamp: unexpected filename $name"
                fi
            fi
        fi
    } || status=$?
    finish_core_test
    return "$status"
}

test_backup_contains_valid_json() {
    setup_core_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "cc"
        run_switcher_capture glm
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
        else
            local latest
            latest=$(latest_backup_file || true)
            if [ -z "$latest" ]; then
                status=1
                echo "Backup validation: missing backup"
            elif ! assert_json_valid "$latest" "Backup JSON should be valid"; then
                status=1
            fi
        fi
    } || status=$?
    finish_core_test
    return "$status"
}

test_glm_backup_strips_only_glm_variables() {
    setup_core_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "glm"
        jq '.env.CUSTOM_VAR = "persist"' "$ROOT_CC/settings.json" > "$ROOT_CC/settings_tmp.json"
        mv "$ROOT_CC/settings_tmp.json" "$ROOT_CC/settings.json"

        run_switcher_capture cc
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
        else
            local latest
            latest=$(latest_backup_file || true)
            if [ -z "$latest" ]; then
                status=1
                echo "GLM backup: missing backup"
            else
                if jq -e '(.env // {}) | has("GLM_MODEL_MAPPING")' "$latest" >/dev/null; then
                    status=1
                    echo "GLM backup: GLM mapping should be removed"
                fi
                if ! jq -e '.env.CUSTOM_VAR == "persist"' "$latest" >/dev/null; then
                    status=1
                    echo "GLM backup: custom variable lost"
                fi
            fi
        fi
    } || status=$?
    finish_core_test
    return "$status"
}

test_list_command_displays_backups() {
    setup_core_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "cc"
        run_switcher_capture glm
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
        else
            sleep 1
            run_switcher_capture cc
            if [ "$RUN_STATUS" -ne 0 ]; then
                status=1
            else
                run_switcher_capture list
                if [ "$RUN_STATUS" -ne 0 ]; then
                    status=1
                elif ! [[ "$RUN_OUTPUT" == *"1."* && "$RUN_OUTPUT" == *"2."* ]]; then
                    status=1
                    echo "List command: expected enumerated backups"
                fi
            fi
        fi
    } || status=$?
    finish_core_test
    return "$status"
}

test_restore_by_number_restores_backup() {
    setup_core_test
    local status=0
    {
        cat > "$ROOT_CC/settings.json" <<'EOF'
{
  "env": {
    "CUSTOM_VAR": "original"
  }
}
EOF
        run_switcher_capture glm
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
        else
            run_switcher_capture restore 1
            if [ "$RUN_STATUS" -ne 0 ]; then
                status=1
            elif ! jq -e '.env.CUSTOM_VAR == "original"' "$ROOT_CC/settings.json" >/dev/null; then
                status=1
                echo "Restore: original custom variable missing"
            fi
        fi
    } || status=$?
    finish_core_test
    return "$status"
}

test_restore_rejects_invalid_backup() {
    setup_core_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "cc"
        run_switcher_capture glm
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
        else
            local invalid_backup="$CONFIG_DIR/settings_backup_20990101_000000.json"
            echo '{"env": invalid json}' > "$invalid_backup"
            sleep 1
            run_switcher_capture restore 1
            if [ "$RUN_STATUS" -eq 0 ]; then
                status=1
                echo "Restore: invalid backup should fail"
            fi
        fi
    } || status=$?
    finish_core_test
    return "$status"
}

test_restore_creates_pre_restore_backup() {
    setup_core_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "cc"
        run_switcher_capture glm
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
        else
            run_switcher_capture restore 1
            if [ "$RUN_STATUS" -ne 0 ]; then
                status=1
            else
                local before_restore
                before_restore=$(find "$CONFIG_DIR" -maxdepth 1 -type f -name 'settings_backup_before_restore_*.json' | head -n1)
                if [ -z "$before_restore" ]; then
                    status=1
                    echo "Restore: missing pre-restore backup"
                fi
            fi
        fi
    } || status=$?
    finish_core_test
    return "$status"
}

test_max_backups_cleanup_removes_oldest() {
    setup_core_test
    local status=0
    {
        write_env_file "test_token_123456" "2"
        create_test_settings "$ROOT_CC/settings.json" "cc"
        run_switcher_capture glm
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
        else
            sleep 1
            run_switcher_capture glm
            if [ "$RUN_STATUS" -ne 0 ]; then
                status=1
            else
                sleep 1
                run_switcher_capture glm
                if [ "$RUN_STATUS" -ne 0 ]; then
                    status=1
                else
                    local count
                    count=$(backup_count)
                    if [ "$count" -ne 2 ]; then
                        status=1
                        echo "MAX_BACKUPS: expected 2 backups, found $count"
                    fi
                fi
            fi
        fi
    } || status=$?
    finish_core_test
    return "$status"
}

########################################
# JSON Validation Tests
########################################

test_valid_json_allows_switch() {
    setup_core_test
    local status=0
    {
        create_test_settings "$ROOT_CC/settings.json" "cc"
        run_switcher_capture glm
        if [ "$RUN_STATUS" -ne 0 ]; then
            status=1
            echo "Valid JSON: switch failed unexpectedly"
        fi
    } || status=$?
    finish_core_test
    return "$status"
}

test_invalid_json_aborts_switch() {
    setup_core_test
    local status=0
    {
        echo '{"env": {"bad": ]}' > "$ROOT_CC/settings.json"
        run_switcher_capture glm
        if [ "$RUN_STATUS" -eq 0 ]; then
            status=1
            echo "Invalid JSON: switch should fail"
        fi
    } || status=$?
    finish_core_test
    return "$status"
}

########################################
# Test Runner
########################################

main() {
    set +e
    run_test test_switch_to_glm_adds_required_env_vars || true
    run_test test_switch_to_glm_sets_correct_endpoint || true
    run_test test_switch_to_glm_sets_provider_zhipu || true
    run_test test_switch_to_glm_reads_token_from_env || true
    run_test test_switch_to_glm_creates_backup || true
    run_test test_switch_to_cc_removes_glm_specific_variables || true
    run_test test_switch_to_cc_preserves_custom_variables || true
    run_test test_switch_to_cc_creates_backup || true
    run_test test_round_trip_preserves_original_settings || true
    run_test test_dry_run_does_not_modify_settings || true

    run_test test_backup_filename_uses_timestamp_format || true
    run_test test_backup_contains_valid_json || true
    run_test test_glm_backup_strips_only_glm_variables || true
    run_test test_list_command_displays_backups || true
    run_test test_restore_by_number_restores_backup || true
    run_test test_restore_rejects_invalid_backup || true
    run_test test_restore_creates_pre_restore_backup || true
    run_test test_max_backups_cleanup_removes_oldest || true

    run_test test_valid_json_allows_switch || true
    run_test test_invalid_json_aborts_switch || true
    set -e
}

main

set +e
print_test_summary
exit_code=$?
set -e
exit $exit_code
