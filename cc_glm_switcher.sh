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

cp configs/settings_"$1".json "$ROOT_CC"/settings.json

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

    # Replace the token in settings.json using sed
    if [ ! -f "$ROOT_CC/settings.json" ]; then
        echo "Warning: $ROOT_CC/settings.json not found"
        exit 1
    fi

    sed -i "s/\(\"ANTHROPIC_AUTH_TOKEN\": \"\)[^\"]*/\1$auth_token/" "$ROOT_CC/settings.json"

    echo "Switched to Z.AI GLM model"
else
    echo "Switched to Claude Code model"
fi

