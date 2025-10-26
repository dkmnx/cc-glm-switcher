#!/usr/bin/env bash

# Security functions extracted from main script for testing

# Logging function
log() {
    if [ "${VERBOSE:-false}" = true ]; then
        echo "[INFO] $1"
    fi
}

# Error logging function
log_error() {
    echo "[ERROR] $1" >&2
}

# Ensure secure file permissions
ensure_secure_permissions() {
    local file="$1"
    local expected_perms="${2:-600}"

    if [ ! -f "$file" ]; then
        log "File does not exist: $file"
        return 0
    fi

    local current_perms
    current_perms=$(stat -c "%a" "$file" 2>/dev/null)

    if [ "$current_perms" != "$expected_perms" ]; then
        log "Setting secure permissions for $file: $expected_perms (was $current_perms)"
        if ! chmod "$expected_perms" "$file"; then
            log_error "Failed to set permissions for $file"
            return 1
        fi
    else
        log "File $file already has secure permissions: $current_perms"
    fi

    return 0
}

# Validate directory permissions
validate_directory_permissions() {
    local directory="$1"
    local expected_perms="${2:-700}"

    if [ ! -d "$directory" ]; then
        log "Directory does not exist: $directory"
        return 0
    fi

    local current_perms
    current_perms=$(stat -c "%a" "$directory" 2>/dev/null)

    if [ "$current_perms" != "$expected_perms" ]; then
        log "Setting secure permissions for directory $directory: $expected_perms (was $current_perms)"
        if ! chmod "$expected_perms" "$directory"; then
            log_error "Failed to set directory permissions for $directory"
            return 1
        fi
    fi

    return 0
}

# Check file ownership
validate_file_ownership() {
    local file="$1"
    local expected_owner="${2:-$(id -u)}"

    if [ ! -f "$file" ]; then
        return 0
    fi

    local current_owner
    current_owner=$(stat -c "%u" "$file" 2>/dev/null)

    if [ "$current_owner" != "$expected_owner" ]; then
        log_error "File $file is owned by different user (uid: $current_owner, expected: $expected_owner)"
        return 1
    fi

    return 0
}

# Validate directory ownership
validate_directory_ownership() {
    local directory="$1"
    local expected_owner="${2:-$(id -u)}"

    if [ ! -d "$directory" ]; then
        return 0
    fi

    local current_owner
    current_owner=$(stat -c "%u" "$directory" 2>/dev/null)

    if [ "$current_owner" != "$expected_owner" ]; then
        log_error "Directory $directory is owned by different user (uid: $current_owner, expected: $expected_owner)"
        return 1
    fi

    return 0
}

# Security validation for configuration files
validate_config_file_security() {
    local config_file="$1"

    if [ ! -f "$config_file" ]; then
        return 0
    fi

    log "Validating security of configuration file: $config_file"

    # Check file permissions
    if ! ensure_secure_permissions "$config_file" "600"; then
        log_error "Configuration file has insecure permissions: $config_file"
        return 1
    fi

    # Check file ownership
    if ! validate_file_ownership "$config_file"; then
        log_error "Configuration file has invalid ownership: $config_file"
        return 1
    fi

    log "Configuration file security validation passed: $config_file"
    return 0
}