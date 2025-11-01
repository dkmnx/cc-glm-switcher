# Claude Code ↔ Z.AI GLM Model Switcher

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-Passing-brightgreen)](https://www.shellcheck.net/)
[![CI](https://github.com/dkmnx/cc-provider-switcher/actions/workflows/ci.yml/badge.svg)](https://github.com/dkmnx/cc-provider-switcher/actions/workflows/ci.yml)

**Current version:** 3.0.0

A robust shell script utility that enables seamless switching between Claude Code and multiple AI providers by safely managing your Claude Code configuration.

> **⚠️ Platform Compatibility**: This script has been tested and confirmed to work on Linux only. While it may work on other Unix-like systems (macOS, WSL), compatibility is not guaranteed.

## Overview

This script allows you to easily toggle between:

- **Claude Code models** (default Anthropic models)
- **Multiple AI providers** (GLM models and others) via their respective APIs

It handles all configuration changes automatically while maintaining backups and ensuring data integrity.

> **📝 Environment Variable Preservation**: The script now intelligently preserves your custom environment variables. When switching back to Claude Code mode, only GLM-specific environment variables are removed, while your custom configurations (like `CUSTOM_API_KEY`, `OTHER_SETTING`, etc.) are retained in the backup.

## Prerequisites

- [Claude Code CLI](https://github.com/anthropics/claude-code) installed and configured
- Valid Z.AI API token (get from [z.ai](https://z.ai/))
- Bash shell environment
- **Note**: `jq` is automatically installed by the install script

### Installation of Dependencies

```bash
# Install jq (Ubuntu/Debian)
sudo apt-get install jq

# Install jq (macOS)
brew install jq

# Install jq (Fedora/CentOS)
sudo dnf install jq
```

## Quick Install

For a **one-command setup**, run:

```bash
./install.sh
```

This will automatically:

- Detect your operating system
- Install required dependencies (`jq`)
- Set up your environment file
- Make the script executable
- Validate the installation

## Manual Setup

If you prefer manual setup or the automated script doesn't work on your system:

1. **Clone or download this repository**
2. **Install dependencies**:

   **Ubuntu/Debian:**

   ```bash
   sudo apt-get install jq
   ```

   **macOS:**

   ```bash
   brew install jq
   ```

   **Fedora/CentOS:**

   ```bash
   sudo dnf install jq
   ```

3. **Create the environment file**:

   ```bash
   cp .env.example .env
   # Edit .env with your Z.AI API token
   ```

4. **Make the script executable**:

   ```bash
   chmod +x cc_provider_switcher.sh
   ```

5. **Configure your `.env` file** with your Z.AI credentials:

   ```bash
   ZAI_AUTH_TOKEN=your_zai_api_token_here

   # Optional: Configure backup retention (default: 5)
   MAX_BACKUPS=5
   ```

6. **Set secure permissions** for your configuration files:

   ```bash
   # Protect your API token
   chmod 600 .env

   # Create configs directory with secure permissions
   mkdir -p configs
   chmod 700 configs
   ```

## Usage

### Basic Model Switching

```bash
# Switch to Claude Code models
./cc_provider_switcher.sh cc

# Switch to provider models
./cc_provider_switcher.sh glm
```

### View Current Configuration

```bash
# Display current settings.json with configuration summary
./cc_provider_switcher.sh show
```

### Version Information

```bash
# Show version and repository information
./cc_provider_switcher.sh --version
```

This will display:

- The complete `settings.json` file content (with syntax highlighting if `bat` or `jq` is available)
- Configuration summary showing:
  - Current provider (Claude or zhipu)
  - Base URL
  - Current mode (Claude Code or Z.AI GLM)

### Quick Start Example

```bash
# 1. Set up your environment
cp .env.example .env
# Edit .env with your ZAI_AUTH_TOKEN

# 2. Make executable and switch to GLM
chmod +x cc_provider_switcher.sh
./cc_provider_switcher.sh glm

# 3. Verify the switch worked
./cc_provider_switcher.sh show

# 4. Switch back to Claude Code when needed
./cc_provider_switcher.sh cc
```

### Command Options

```bash
# Show help message
./cc_provider_switcher.sh -h

# Show version information
./cc_provider_switcher.sh --version
```

**Note**: The script ignores additional arguments after commands (e.g., `./cc_provider_switcher.sh glm -v` works but `-v` has no effect).

The version command displays:

```bash
cc-provider-switcher v3.0.0
```

## Backup Management

### List Backups

```bash
# List all available backup files
./cc_provider_switcher.sh list
```

### Restore From Backup

```bash
# Restore from latest backup
./cc_provider_switcher.sh restore
```

### Backup Retention

The script automatically:

- Creates timestamped backups before any changes
- Keeps the 3 most recent backups
- Removes older backups automatically
- Creates backup of current settings before restore

### Complete Command Reference

Run `./cc_provider_switcher.sh --help` to see all available commands:

```text
Usage: ./cc_provider_switcher.sh {cc|glm|list|restore|show}
Commands: cc=claude, glm=provider, list=backups, restore=latest, show=settings
```

**Available Commands:**

- `cc` - Switch to Claude Code models
- `glm` - Switch to Z.AI GLM models
- `list` - List available backup files
- `restore` - Restore from latest backup
- `show` - Display current settings.json file
- `-V, --version` - Show version information
- `-h, --help` - Show help message

## Features

### 🔒 Safety & Reliability

- **Automatic backups**: Timestamped backups before any changes
- **Backup retention**: Keeps the 3 most recent backups (automatic cleanup)
- **JSON validation**: Ensures configuration files remain valid using `jq`
- **Error handling**: Graceful failure with descriptive messages
- **Dependency checking**: Validates required tools are available

### 💾 Backup Management

- **List backups**: View all available backup files
- **Latest restore**: Restore from the most recent backup
- **Automatic cleanup**: Removes older backups (keeps 3 most recent)
- **Timestamped naming**: Easy identification of backup files

### 🔄 Model Configuration

#### Claude Code Mode

- Creates empty configuration (`{}`) for default Claude Code behavior
- Removes all custom environment variables for clean state

#### GLM Mode

- Configures Z.AI API endpoint and authentication
- Sets up GLM provider configuration with:
  - `ANTHROPIC_AUTH_TOKEN`: Your Z.AI API token
  - `ANTHROPIC_BASE_URL`: Z.AI API endpoint
  - `CLAUDE_MODEL_PROVIDER`: Set to `zhipu`

### 📁 File Management

- **Backups**: Stored in `configs/backup_[timestamp].json`
- **Configuration**: Modified in `~/.claude/settings.json`

## How It Works

The script safely modifies the `~/.claude/settings.json` file:

1. **Dependencies**: Validates required tools (`jq`, `claude`) are available
2. **Backup**: Creates a timestamped backup of current settings
3. **Switch**:
   - **CC mode**: Creates empty configuration (`{}`) for default behavior
   - **GLM mode**: Injects Z.AI API configuration from `.env` file
4. **Apply**: Writes new configuration to settings file
5. **Cleanup**: Removes old backups (keeps 3 most recent)

## Configuration Details

When switching to provider mode, the script creates this configuration:

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "your_zai_token",
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "CLAUDE_MODEL_PROVIDER": "zhipu"
  }
}
```

### 🔄 Configuration Switching

#### From GLM Mode → Claude Code Mode

- ✅ **Result**: Empty configuration (`{}`) for default Claude Code behavior
- ❌ **Removed**: All environment variables including GLM settings

#### From Claude Code Mode → Provider Mode

- ✅ **Result**: Provider configuration with API settings
- ➕ **Added**: Provider environment variables from `.env` file

#### Backup Strategy

- **Automatic Backups**: Created before any configuration changes
- **Timestamped Files**: Named with Unix timestamp for easy identification
- **Retention**: Keeps 3 most recent backups automatically

## Security

- **Token security**: Never commit your `.env` file to version control
- **File permissions**: `.env` file should be `600` (owner read/write only), `configs/` directory should be `700` (owner access only)
- **Input validation**: Tokens are validated for basic format requirements
- **Secure temporary files**: Script uses secure temporary file creation

## Testing

This project includes a focused automated test suite with 11 essential tests that validate core functionality. For detailed testing information, including test coverage and how to run tests, see [tests/README.md](tests/README.md).

### Quick Test Commands

```bash
# Run all tests
./tests/run_basic_tests.sh

# Run tests directly
./tests/test_basic.sh
```

### Test Coverage

The test suite validates:

- ✅ Script existence and execution permissions
- ✅ Help command functionality
- ✅ Invalid argument handling and error scenarios
- ✅ Configuration display (`show` command)
- ✅ GLM mode authentication requirements
- ✅ Required dependencies (`jq`, `claude`)
- ✅ CC mode switching functionality
- ✅ JSON validation (valid/invalid/empty JSON handling)

### Continuous Integration

GitHub Actions automatically runs the test suite on every push to `main` and on all pull requests. The workflow verifies dependencies and executes the complete test suite (`./tests/run_basic_tests.sh`). Check the latest status via the **CI** badge above or by visiting the [Actions dashboard](https://github.com/dkmnx/cc-provider-switcher/actions/workflows/ci.yml).

#### Reproducing the CI job locally

```bash
# Install dependencies (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y jq shellcheck

# Run the test suite
./tests/run_basic_tests.sh
```

The simplified test suite executes in ~5 seconds and provides comprehensive validation of core script functionality.

## Troubleshooting

For common issues, debugging steps, and recovery procedures, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Contributing

We welcome contributions! Please see our [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines on:

- Development workflow and branch naming
- Code quality standards and shellcheck requirements
- Conventional commit message format
- Testing requirements and best practices
- Pull request guidelines and review process

All contributions should follow our commit message standards and pass shellcheck validation.

## Project Documentation

- **[tests/README.md](tests/README.md)**: Comprehensive testing framework documentation

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

**⚠️ Important Notice**: This script modifies your Claude Code configuration files. Always ensure you have proper backups before making changes. Use at your own risk.

## Support

For issues related to:

- **Script functionality**: Create an issue in this repository
- **Claude Code**: Visit the [Claude Code documentation](https://docs.claude.com)
- **Z.AI API**: Contact [Z.AI support](https://z.ai/contact)
