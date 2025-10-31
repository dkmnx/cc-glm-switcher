#!/bin/bash

# Claude Code ↔ Z.AI GLM Model Switcher - Installation Script
# Author: dkmnx
# Description: Automated installation and setup script

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_NAME="cc_glm_switcher.sh"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            echo "ubuntu"
        elif command -v dnf &> /dev/null; then
            echo "fedora"
        elif command -v pacman &> /dev/null; then
            echo "arch"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Install jq based on OS
install_jq() {
    local os="$1"

    log_info "Installing jq..."

    case "$os" in
        ubuntu)
            sudo apt-get update
            sudo apt-get install -y jq
            ;;
        fedora)
            sudo dnf install -y jq
            ;;
        arch)
            sudo pacman -S --noconfirm jq
            ;;
        macos)
            if command_exists brew; then
                brew install jq
            else
                log_error "Homebrew not found. Please install Homebrew first: https://brew.sh/"
                exit 1
            fi
            ;;
        *)
            log_error "Unsupported OS for automatic jq installation. Please install jq manually."
            log_info "Visit: https://stedolan.github.io/jq/download/"
            exit 1
            ;;
    esac

    if command_exists jq; then
        log_success "jq installed successfully"
    else
        log_error "Failed to install jq"
        exit 1
    fi
}

# Check if Claude Code is installed
check_claude() {
    if ! command_exists claude; then
        log_warning "Claude Code CLI not found"
        log_info "Please install Claude Code CLI first:"
        log_info "Visit: https://github.com/anthropics/claude-code"
        log_info ""
        log_info "After installation, run this script again."
        exit 1
    else
        log_success "Claude Code CLI found"
    fi
}

# Setup environment file
setup_env() {
    if [ ! -f ".env" ]; then
        log_info "Creating .env file from template..."
        cp .env.example .env
        log_success ".env file created"
        log_warning "Please edit .env file with your Z.AI API token:"
        log_info "  nano .env  # or your preferred editor"
        log_info ""
        log_info "Get your token from: https://z.ai/"
        echo ""
        read -r -p "Press Enter after you've added your Z.AI API token to continue..."
    else
        log_info ".env file already exists"
    fi
}

# Make script executable
setup_script() {
    if [ -f "$SCRIPT_NAME" ]; then
        log_info "Making $SCRIPT_NAME executable..."
        chmod +x "$SCRIPT_NAME"
        log_success "$SCRIPT_NAME is now executable"
    else
        log_error "$SCRIPT_NAME not found in current directory"
        exit 1
    fi
}

# Run basic validation
validate_setup() {
    log_info "Validating setup..."

    # Check if script is executable
    if [ ! -x "$SCRIPT_NAME" ]; then
        log_error "$SCRIPT_NAME is not executable"
        return 1
    fi

    # Check if .env exists
    if [ ! -f ".env" ]; then
        log_error ".env file not found"
        return 1
    fi

    # Check if ZAI_AUTH_TOKEN is set (basic check)
    if ! grep -q "^ZAI_AUTH_TOKEN=" .env 2>/dev/null; then
        log_warning "ZAI_AUTH_TOKEN not found in .env file"
        log_info "Please make sure to add your Z.AI API token to the .env file"
    fi

    log_success "Basic validation passed"
    return 0
}

# Show usage instructions
show_usage() {
    log_info "Installation completed successfully!"
    echo ""
    log_info "Usage:"
    echo "  ./$SCRIPT_NAME glm    # Switch to Z.AI GLM models"
    echo "  ./$SCRIPT_NAME cc     # Switch to Claude Code models"
    echo "  ./$SCRIPT_NAME show   # View current configuration"
    echo "  ./$SCRIPT_NAME --help # Show all options"
    echo ""
    log_info "For more information, see README.md"
}

# Main installation function
main() {
    echo ""
    log_info "Claude Code ↔ Z.AI GLM Model Switcher Installer"
    log_info "=============================================="
    echo ""

    # Detect OS
    local os
    os=$(detect_os)
    log_info "Detected OS: $os"

    # Check Claude Code
    check_claude

    # Install jq if needed
    if ! command_exists jq; then
        install_jq "$os"
    else
        log_success "jq already installed"
    fi

    # Setup environment
    setup_env

    # Setup script
    setup_script

    # Validate
    if validate_setup; then
        show_usage
        log_success "Installation completed!"
        echo ""
        log_info "Next steps:"
        log_info "1. Edit .env with your Z.AI API token (if not done already)"
        log_info "2. Run: ./$SCRIPT_NAME glm"
        log_info "3. Run: ./$SCRIPT_NAME show  # to verify"
    else
        log_error "Installation validation failed"
        exit 1
    fi
}

# Run main function
main "$@"