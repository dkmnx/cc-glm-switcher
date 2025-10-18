#!/usr/bin/env bash

# This script switches between Claude Code  and Z.AI GLM models
# Usage: ./cc_glm_switcher.sh [MODEL] [OPTIONS]

# Configuration variables
ROOT_CC="$HOME/.claude"
ROOT_SCRIPT="${HOME}/Documents/scripts/cc-glm-switcher"
LOCK_FILE="$ROOT_SCRIPT/.switcher.lock"
VERBOSE=false
DRY_RUN=false

# Parse command line arguments
MODEL=""
while [[ $# -gt 0 ]]; do
    case $1 in
        cc|glm)
            MODEL="$1"
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 {cc|glm} [OPTIONS]"
            echo "Options:"
            echo "  -v, --verbose    Enable verbose output"
            echo "  --dry-run        Show what would be done without making changes"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

if [ -z "$MODEL" ]; then
    echo "Error: MODEL must be specified"
    echo "Usage: $0 {cc|glm} [OPTIONS]"
    exit 1
fi

# Logging function
log() {
    if [ "$VERBOSE" = true ]; then
        echo "[INFO] $1"
    fi
}

# Error logging function
log_error() {
    echo "[ERROR] $1" >&2
}

# Lock file mechanism
acquire_lock() {
    log "Attempting to acquire lock..."
    if ! (set -C; echo $$ > "$LOCK_FILE") 2>/dev/null; then
        log_error "Another instance is already running. PID: $(cat "$LOCK_FILE")"
        exit 1
    fi
    log "Lock acquired successfully"
}

release_lock() {
    log "Releasing lock..."
    rm -f "$LOCK_FILE"
}

# Cleanup function
cleanup() {
    local exit_code=$?
    log "Performing cleanup..."
    release_lock
    exit $exit_code
}

# Set up trap for cleanup
trap cleanup EXIT INT TERM

# Validate JSON function
validate_json() {
    local file="$1"
    if ! jq empty "$file" >/dev/null 2>&1; then
        log_error "Invalid JSON in $file"
        return 1
    fi
    return 0
}

# Check if current configuration is GLM mode
is_glm_config() {
    local file="$1"
    local provider
    local base_url

    if [ ! -f "$file" ]; then
        return 1
    fi

    # Check for GLM indicators in order of reliability
    provider=$(jq -r '.env.CLAUDE_MODEL_PROVIDER // ""' "$file" 2>/dev/null)
    if [ "$provider" == "zhipu" ]; then
        log "GLM config detected: CLAUDE_MODEL_PROVIDER = zhipu"
        return 0
    fi

    base_url=$(jq -r '.env.ANTHROPIC_BASE_URL // ""' "$file" 2>/dev/null)
    if [[ "$base_url" == *"z.ai"* ]]; then
        log "GLM config detected: ANTHROPIC_BASE_URL contains z.ai"
        return 0
    fi

    # Check for GLM model mapping
    if jq -e '.env.GLM_MODEL_MAPPING' "$file" >/dev/null 2>&1; then
        log "GLM config detected: GLM_MODEL_MAPPING exists"
        return 0
    fi

    log "No GLM configuration detected"
    return 1
}

# Atomic file move function
atomic_move() {
    local src="$1"
    local dest="$2"
    log "Moving $src to $dest atomically"
    mv "$src" "$dest"
}

# check if claude command exists
if ! command -v claude &> /dev/null; then
    log_error "claude command not found. See https://github.com/anthropics/claude-code for installation instructions."
    exit 1
fi

# check jq command exists
if ! command -v jq &> /dev/null; then
    log_error "jq command not found. Please install jq."
    exit 1
fi

# Input validation function
validate_auth_token() {
    local token="$1"
    if [ -z "$token" ]; then
        log_error "Authentication token is empty"
        return 1
    fi
    # Basic token format validation (adjust as needed)
    if [[ ! "$token" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        log_error "Invalid token format"
        return 1
    fi
    return 0
}

# Show current configuration
show_current_config() {
    log "Current configuration:"
    if [ -f "$ROOT_CC/settings.json" ]; then
        local has_env
        has_env=$(jq '(.env | has("ANTHROPIC_AUTH_TOKEN"))' "$ROOT_CC/settings.json" 2>/dev/null)
        if [ "$has_env" == "true" ]; then
            local provider
            provider=$(jq -r '.env.CLAUDE_MODEL_PROVIDER // "unknown"' "$ROOT_CC/settings.json" 2>/dev/null)
            local base_url
            base_url=$(jq -r '.env.ANTHROPIC_BASE_URL // "unknown"' "$ROOT_CC/settings.json" 2>/dev/null)
            echo "  Provider: $provider"
            echo "  Base URL: $base_url"
        else
            echo "  Provider: claude (default)"
        fi
    else
        echo "  No configuration found"
    fi
}

# Acquire lock before proceeding
acquire_lock

# Show current configuration if verbose
if [ "$VERBOSE" = true ]; then
    show_current_config
fi

# check if configs backup directory exists, if not create it
if [ ! -d "$ROOT_SCRIPT/configs" ]; then
    mkdir -p "$ROOT_SCRIPT/configs"
fi

timestamp=$(date +"%Y%m%d_%H%M%S")

# Create secure temp files
temp_settings=$(mktemp)
temp_backup=$(mktemp)
final_backup="$ROOT_SCRIPT/configs/settings_backup_$timestamp.json"

log "Created temporary files: $temp_settings, $temp_backup"

# check if backup of settings_backup_*.json already exists, if yes remove it
if ls "$ROOT_SCRIPT/configs/settings_backup_"*.json 1> /dev/null 2>&1; then
    log "Removing existing backup files"
    rm "$ROOT_SCRIPT/configs/settings_backup_"*.json
fi

# Validate current settings.json before proceeding
if ! validate_json "$ROOT_CC/settings.json"; then
    log_error "Current settings.json is invalid. Cannot proceed."
    exit 1
fi

# backup current settings.json
if is_glm_config "$ROOT_CC/settings.json"; then
    log "Found GLM configuration, creating clean backup (removing only GLM variables)"
    # Remove only GLM-specific environment variables, preserve others
    if ! jq 'del(.env.ANTHROPIC_AUTH_TOKEN) | del(.env.ANTHROPIC_BASE_URL) | del(.env.API_TIMEOUT_MS) | del(.env.ANTHROPIC_DEFAULT_HAIKU_MODEL) | del(.env.ANTHROPIC_DEFAULT_SONNET_MODEL) | del(.env.ANTHROPIC_DEFAULT_OPUS_MODEL) | del(.env.CLAUDE_MODEL_PROVIDER) | del(.env.GLM_MODEL_MAPPING) | if .env == {} then del(.env) else . end' "$ROOT_CC/settings.json" > "$temp_backup"; then
        log_error "Failed to create clean backup"
        exit 1
    fi
else
    log "Found standard configuration, creating direct backup"
    if ! cp "$ROOT_CC/settings.json" "$temp_backup"; then
        log_error "Failed to copy settings.json to backup"
        exit 1
    fi
fi

# Validate backup
if ! validate_json "$temp_backup"; then
    log_error "Generated backup is invalid"
    exit 1
fi

# Move backup to final location atomically
atomic_move "$temp_backup" "$final_backup"
log "Backup created: $final_backup"

# Prepare settings based on model choice
if [ "$MODEL" == "glm" ]; then
    # For GLM mode, start with clean backup and add GLM variables
    if [ "$DRY_RUN" = false ]; then
        cp "$final_backup" "$temp_settings"
    else
        log "DRY RUN: Would copy backup to current settings"
    fi
else
    # For CC mode, merge current settings with backup, removing only GLM variables
    if [ "$DRY_RUN" = false ]; then
        log "Merging current settings with backup (removing only GLM variables)"
        if ! jq 'del(.env.ANTHROPIC_AUTH_TOKEN) | del(.env.ANTHROPIC_BASE_URL) | del(.env.API_TIMEOUT_MS) | del(.env.ANTHROPIC_DEFAULT_HAIKU_MODEL) | del(.env.ANTHROPIC_DEFAULT_SONNET_MODEL) | del(.env.ANTHROPIC_DEFAULT_OPUS_MODEL) | del(.env.CLAUDE_MODEL_PROVIDER) | del(.env.GLM_MODEL_MAPPING) | if .env == {} then del(.env) else . end' "$ROOT_CC/settings.json" > "$temp_settings"; then
            log_error "Failed to merge settings for CC mode"
            exit 1
        fi
    else
        log "DRY RUN: Would merge current settings removing only GLM variables"
    fi
fi

if [ "$MODEL" == "glm" ]; then
    log "Switching to GLM configuration"

    # Extract ZAI_AUTH_TOKEN from .env file
    if [ ! -f "$ROOT_SCRIPT/.env" ]; then
        log_error "$ROOT_SCRIPT/.env file not found"
        exit 1
    fi

    auth_token=$(grep "^ZAI_AUTH_TOKEN=" "$ROOT_SCRIPT/.env" | cut -d'=' -f2)
    if [ -z "$auth_token" ]; then
        log_error "ZAI_AUTH_TOKEN not found in .env file"
        exit 1
    fi

    # Validate auth token
    if ! validate_auth_token "$auth_token"; then
        log_error "Invalid ZAI_AUTH_TOKEN format"
        exit 1
    fi

    log "Authentication token validated successfully"

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

    if [ "$DRY_RUN" = false ]; then
        log "Creating GLM configuration"
        if ! jq '.env += '"$env_json"' | if has("env") and .env == {} then del(.env) else . end' "$temp_settings" > "$temp_settings.new"; then
            log_error "Failed to create GLM configuration"
            exit 1
        fi
        mv "$temp_settings.new" "$temp_settings"

        # Validate final configuration
        if ! validate_json "$temp_settings"; then
            log_error "Generated GLM configuration is invalid"
            exit 1
        fi

        # Apply configuration atomically
        atomic_move "$temp_settings" "$ROOT_CC/settings.json"
        log "GLM configuration applied successfully"
        echo "Switched to Z.AI GLM model"
    else
        log "DRY RUN: Would create GLM configuration with provided token"
        echo "DRY RUN: Would switch to Z.AI GLM model"
    fi
else
    log "Switching to Claude Code configuration"
    if [ "$DRY_RUN" = false ]; then
        # Apply clean configuration atomically
        atomic_move "$temp_settings" "$ROOT_CC/settings.json"
        log "Claude Code configuration applied successfully"
        echo "Switched to Claude Code model"
    else
        log "DRY RUN: Would switch to Claude Code model"
        echo "DRY RUN: Would apply clean configuration"
    fi
fi

# Cleanup temp files
rm -f "$temp_settings" "$temp_backup" "$temp_settings.new" 2>/dev/null
log "Temporary files cleaned up"
