#!/usr/bin/env bash

# This script switches between Claude Code  and Z.AI GLM models
# Usage: ./cc_glm_switcher.sh [MODEL]

ROOT_CC="$HOME/.claude"
ROOT_SCRIPT="${HOME}/Documents/scripts/cc-glm-switcher"

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 {cc|glm}"
    exit 1
fi

if [ "$1" != "cc" ] && [ "$1" != "glm" ]; then
    echo "Error: MODEL must be either 'cc' or 'glm'"
    exit 1
fi

# check if claude command exists
if ! command -v claude &> /dev/null; then
    echo "Error: claude command not found. See https://github.com/anthropics/claude-code for installation instructions."
    exit 1
fi

# check jq command exists
if ! command -v jq &> /dev/null; then
    echo "Error: jq command not found. Please install jq."
    exit 1
fi

# backup current settings.json
timestamp=$(date +"%Y%m%d_%H%M%S")

# check first if glm config exists
check_glm_config=$(jq '(.env | has("ANTHROPIC_AUTH_TOKEN"))' "$ROOT_CC/settings.json")
if [ "$check_glm_config" == "true" ]; then
    # remove env section from settings.json
    jq 'del(.env)' "$ROOT_CC/settings.json" > "$ROOT_SCRIPT/configs/settings_backup_$timestamp.json"
else
    cp "$ROOT_CC/settings.json" "$ROOT_SCRIPT/configs/settings_backup_$timestamp.json"
fi

cp "$ROOT_SCRIPT/configs/settings_backup_$timestamp.json" "$ROOT_CC/settings.json"

if [ "$1" == "glm" ]; then
    # Extract ZAI_AUTH_TOKEN from .env file
    if [ ! -f "$ROOT_SCRIPT/.env" ]; then
        echo "Warning: $ROOT_SCRIPT/.env file not found"
        exit 1
    fi

    auth_token=$(grep "^ZAI_AUTH_TOKEN=" "$ROOT_SCRIPT/.env" | cut -d'=' -f2)
    if [ -z "$auth_token" ]; then
        echo "Warning: ZAI_AUTH_TOKEN not found in .env file"
        exit 1
    fi

    env_json='{
        "ANTHROPIC_AUTH_TOKEN": "'"$auth_token"'",
        "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
        "API_TIMEOUT_MS": "3000000",
        "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air",
        "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.6",
        "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-4.6",
        "CLAUDE_MODEL_PROVIDER": "zhipu",
        "GLM_MODEL_MAPPING": "haiku:glm-4.5-air,sonnet:glm-4.6,opus:glm-4.6"
    }'

    jq '. + {env: '"$env_json"'}' "$ROOT_CC/settings.json" > "$ROOT_CC/temp_settings.json" && mv "$ROOT_CC/temp_settings.json" "$ROOT_CC/settings.json"

    if ! jq empty "$ROOT_CC/settings.json" >/dev/null 2>&1; then
        echo "Error: Invalid JSON"
        exit 1
    fi

    echo "Switched to Z.AI GLM model"
else
    echo "Switched to Claude Code model"
fi

