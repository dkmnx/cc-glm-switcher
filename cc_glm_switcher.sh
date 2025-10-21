#!/usr/bin/env bash

# Claude Code ↔ Z.AI GLM Model Switcher
# Author: dkmnx
# Repository: https://github.com/dkmnx/cc-glm-switcher
# Description: This script switches between Claude Code and Z.AI GLM models
# Usage: ./cc_glm_switcher.sh [MODEL] [OPTIONS]

# Version information
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="cc-glm-switcher"

# Configuration variables
ROOT_CC="${ROOT_CC:-$HOME/.claude}"
ROOT_SCRIPT="${ROOT_SCRIPT:-${HOME}/Documents/scripts/cc-glm-switcher}"
LOCK_FILE="${LOCK_FILE:-$ROOT_SCRIPT/.switcher.lock}"
CONFIG_DIR="${CONFIG_DIR:-$ROOT_SCRIPT/configs}"
MAX_BACKUPS=5
VERBOSE=false
DRY_RUN=false

# Define all functions first
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

# Atomic file move function
atomic_move() {
    local src="$1"
    local dest="$2"
    log "Moving $src to $dest atomically"
    mv "$src" "$dest"
}

# Load configuration from .env file

# shellcheck disable=SC2329  # Function is invoked later
load_config() {
    # Check multiple possible locations for .env file
    local env_file=""
    if [ -f ".env" ]; then
        env_file=".env"
    elif [ -f "$ROOT_SCRIPT/.env" ]; then
        env_file="$ROOT_SCRIPT/.env"
    elif [ -n "$TEST_DIR" ] && [ -f "$TEST_DIR/.env" ]; then
        env_file="$TEST_DIR/.env"
    fi

    if [ -n "$env_file" ]; then
        set -a
        # shellcheck disable=SC1090
        source "$env_file"
        set +a
        if [ -n "$MAX_BACKUPS" ] && [[ "$MAX_BACKUPS" =~ ^[0-9]+$ ]]; then
            log "Using MAX_BACKUPS=$MAX_BACKUPS from .env file"
        else
            # Reset to default if invalid
            MAX_BACKUPS=5
            log "Using default MAX_BACKUPS=$MAX_BACKUPS"
        fi
    else
        log "No .env file found, using default MAX_BACKUPS=$MAX_BACKUPS"
    fi
}

# Cleanup old backups based on MAX_BACKUPS setting

# shellcheck disable=SC2329  # Function is invoked later
cleanup_old_backups() {
    local backup_files=()
    local count=0

    if [ ! -d "$CONFIG_DIR" ]; then
        return 0
    fi

    load_config

    while IFS= read -r -d '' file; do
        ((count++))
        backup_files+=("$file")
    done < <(find "$CONFIG_DIR" -name "settings_backup_*.json" -type f -printf '%T@ %p\0' | sort -z -nr | sed -z 's/^[^ ]* //')

    if [ "$count" -le "$MAX_BACKUPS" ]; then
        log "Keeping all $count backup files (MAX_BACKUPS=$MAX_BACKUPS)"
        return 0
    fi

    local files_to_remove=$((count - MAX_BACKUPS))
    log "Removing $files_to_remove old backup files (keeping $MAX_BACKUPS most recent)"

    for ((i=MAX_BACKUPS; i<count; i++)); do
        local file_to_remove="${backup_files[$i]}"
        log "Removing old backup: $(basename "$file_to_remove")"
        rm -f "$file_to_remove"
    done
}

# List available backup files
list_backups() {
    local backup_files=()
    local count=0

    echo "Available backup files:"
    echo "======================"

    if [ ! -d "$CONFIG_DIR" ]; then
        echo "No backup directory found."
        return 1
    fi

    # Get list of backup files sorted by date (newest first)
    while IFS= read -r -d '' file; do
        ((count++))
        backup_files+=("$file")
        local timestamp
        timestamp=$(basename "$file" | sed 's/settings_backup_//' | sed 's/.json//')
        local formatted_date
        formatted_date=$(date -d "${timestamp:0:8} ${timestamp:9:2}:${timestamp:11:2}:${timestamp:13:2}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$timestamp")

        printf "%2d. %s  (%s)\n" "$count" "$(basename "$file")" "$formatted_date"
    done < <(find "$CONFIG_DIR" -name "settings_backup_*.json" -type f -printf '%T@ %p\0' | sort -z -nr | sed -z 's/^[^ ]* //')

    if [ $count -eq 0 ]; then
        echo "No backup files found."
        return 1
    fi

    echo ""
    echo "Total backups: $count"
    echo "Usage: $0 restore [1-$count]"
}

# Interactive restore menu
interactive_restore() {
    local backup_files=()
    local count=0

    echo "Interactive restore menu:"
    echo "========================"

    if [ ! -d "$CONFIG_DIR" ]; then
        log_error "No backup directory found."
        return 1
    fi

    # Get list of backup files
    while IFS= read -r -d '' file; do
        ((count++))
        backup_files+=("$file")
        local timestamp
        timestamp=$(basename "$file" | sed 's/settings_backup_//' | sed 's/.json//')
        local formatted_date
        formatted_date=$(date -d "${timestamp:0:8} ${timestamp:9:2}:${timestamp:11:2}:${timestamp:13:2}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$timestamp")

        printf "%2d. %s  (%s)\n" "$count" "$(basename "$file")" "$formatted_date"
    done < <(find "$CONFIG_DIR" -name "settings_backup_*.json" -type f -printf '%T@ %p\0' | sort -z -nr | sed -z 's/^[^ ]* //')

    if [ $count -eq 0 ]; then
        log_error "No backup files found."
        return 1
    fi

    echo ""
    echo "Enter backup number to restore (1-$count), or 'q' to quit:"
    read -r choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $count ]; then
        restore_backup "$choice"
    elif [[ "$choice" =~ ^[qQ]$ ]]; then
        echo "Restore cancelled."
        return 0
    else
        log_error "Invalid choice. Please enter a number between 1 and $count."
        return 1
    fi
}

# Trim whitespace from string
trim_whitespace() {
    local var="$1"
    # Remove leading and trailing whitespace
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

# Validate JSON function
validate_json() {
    local file="$1"

    # Check if file exists and is not empty
    if [ ! -s "$file" ]; then
        log_error "File is empty or does not exist: $file"
        return 1
    fi

    # Validate JSON syntax
    if ! jq empty "$file" >/dev/null 2>&1; then
        log_error "Invalid JSON in $file"
        return 1
    fi

    return 0
}

# Restore from backup
restore_backup() {
    local backup_num="$1"
    local backup_files=()
    local count=0

    if [ ! -d "$CONFIG_DIR" ]; then
        log_error "No backup directory found."
        return 1
    fi

    # Get list of backup files
    while IFS= read -r -d '' file; do
        ((count++))
        backup_files+=("$file")
    done < <(find "$CONFIG_DIR" -name "settings_backup_*.json" -type f -printf '%T@ %p\0' | sort -z -nr | sed -z 's/^[^ ]* //')

    if [ $count -eq 0 ]; then
        log_error "No backup files found."
        return 1
    fi

    if [[ "$backup_num" =~ ^[0-9]+$ ]] && [ "$backup_num" -ge 1 ] && [ "$backup_num" -le $count ]; then
        local selected_backup="${backup_files[$((backup_num-1))]}"

        echo "Selected backup: $(basename "$selected_backup")"

        # Validate backup file
        if ! validate_json "$selected_backup"; then
            log_error "Selected backup file is invalid."
            return 1
        fi

        # Create backup of current settings before restore
        local current_backup
        current_backup="$CONFIG_DIR/settings_backup_before_restore_$(date +"%Y%m%d_%H%M%S").json"
        if [ -f "$ROOT_CC/settings.json" ]; then
            cp "$ROOT_CC/settings.json" "$current_backup"
            log "Current settings backed up to: $(basename "$current_backup")"
        fi

        # Restore from backup
        if [ "$DRY_RUN" = false ]; then
            atomic_move "$selected_backup" "$ROOT_CC/settings.json"
            log "Successfully restored from backup"
            echo "Settings restored from: $(basename "$selected_backup")"
        else
            log "DRY RUN: Would restore from $(basename "$selected_backup")"
            echo "DRY RUN: Would restore from $(basename "$selected_backup")"
        fi
    else
        log_error "Invalid backup number. Please use 'list' to see available backups."
        return 1
    fi
}

# Parse command line arguments
MODEL=""
RESTORE_ARG=""

# First pass: parse all flags and store command arguments
while [[ $# -gt 0 ]]; do
    # Trim whitespace from current argument
    arg=$(trim_whitespace "$1")

    case $arg in
        cc|glm)
            MODEL="$arg"
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
        list)
            list_backups
            exit 0
            ;;
        restore)
            shift
            RESTORE_ARG=$(trim_whitespace "$1")
            shift
            ;;
        -V|--version)
            echo "$SCRIPT_NAME v$SCRIPT_VERSION"
            echo "Repository: https://github.com/dkmnx/cc-glm-switcher"
            exit 0
            ;;
        -h|--help)
            echo "$SCRIPT_NAME v$SCRIPT_VERSION - Claude Code ↔ Z.AI GLM Model Switcher"
            echo "Repository: https://github.com/dkmnx/cc-glm-switcher"
            echo ""
            echo "Usage: $0 {cc|glm|list|restore} [OPTIONS]"
            echo ""
            echo "Commands:"
            echo "  cc               Switch to Claude Code models"
            echo "  glm              Switch to Z.AI GLM models"
            echo "  list             List available backup files"
            echo "  restore [N]      Restore from backup (interactive or specify number)"
            echo ""
            echo "Options:"
            echo "  -v, --verbose    Enable verbose output"
            echo "  --dry-run        Show what would be done without making changes"
            echo "  -V, --version    Show version information"
            echo "  -h, --help       Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 glm           Switch to GLM models"
            echo "  $0 cc            Switch to Claude Code models"
            echo "  $0 list          List available backups"
            echo "  $0 restore       Interactive restore menu"
            echo "  $0 restore 3     Restore from backup #3"
            echo "  $0 glm -v        Switch with verbose output"
            echo "  $0 cc --dry-run  Preview CC mode switch"
            echo "  $0 restore 1 --dry-run  Preview restore from backup #1"
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Handle restore command after all flags are parsed
if [ -n "$RESTORE_ARG" ]; then
    if [ -z "$RESTORE_ARG" ]; then
        interactive_restore
        exit_code=$?
    else
        restore_backup "$RESTORE_ARG"
        exit_code=$?
    fi
    exit $exit_code
fi

if [ -z "$MODEL" ]; then
    echo "Error: Command must be specified"
    echo "Usage: $0 {cc|glm|list|restore} [OPTIONS]"
    echo "Use -h or --help for usage information"
    exit 1
fi

# Lock file mechanism
acquire_lock() {
    log "Attempting to acquire lock..."

    # Ensure the directory for the lock file exists
    local lock_dir
    lock_dir=$(dirname "$LOCK_FILE")
    if [ ! -d "$lock_dir" ]; then
        mkdir -p "$lock_dir" || {
            log_error "Failed to create lock directory: $lock_dir"
            exit 1
        }
    fi

    if ! (set -C; echo $$ > "$LOCK_FILE") 2>/dev/null; then
        if [ -f "$LOCK_FILE" ]; then
            local pid
            pid=$(cat "$LOCK_FILE" 2>/dev/null)
            log_error "Another instance is already running. PID: $pid"
        else
            log_error "Failed to acquire lock (unable to create lock file)"
        fi
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

# Check if current configuration is GLM mode
is_glm_config() {
    local file="$1"
    local provider
    local base_url

    if [ ! -f "$file" ]; then
        return 1
    fi

    # Check if file is empty
    if [ ! -s "$file" ]; then
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
    if [ -f "$ROOT_CC/settings.json" ] && [ -s "$ROOT_CC/settings.json" ]; then
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

# Show startup information if verbose
if [ "$VERBOSE" = true ]; then
    log "$SCRIPT_NAME v$SCRIPT_VERSION - Claude Code ↔ Z.AI GLM Model Switcher"
    log "Repository: https://github.com/dkmnx/cc-glm-switcher"
    show_current_config
fi

# check if configs backup directory exists, if not create it
if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
fi

timestamp=$(date +"%Y%m%d_%H%M%S")

# Create secure temp files
temp_settings=$(mktemp)
temp_backup=$(mktemp)
final_backup="$CONFIG_DIR/settings_backup_$timestamp.json"

log "Created temporary files: $temp_settings, $temp_backup"

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

# Cleanup old backups after creating new one
cleanup_old_backups

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
    # Check multiple possible locations for .env file
    env_file=""
    if [ -f ".env" ]; then
        env_file=".env"
    elif [ -f "$ROOT_SCRIPT/.env" ]; then
        env_file="$ROOT_SCRIPT/.env"
    elif [ -n "$TEST_DIR" ] && [ -f "$TEST_DIR/.env" ]; then
        env_file="$TEST_DIR/.env"
    else
        log_error ".env file not found in current directory, $ROOT_SCRIPT/.env, or TEST_DIR/.env"
        exit 1
    fi

    auth_token=$(grep "^ZAI_AUTH_TOKEN=" "$env_file" | cut -d'=' -f2)
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
