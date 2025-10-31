# Claude Code ↔ Z.AI GLM Model Switcher

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-Passing-brightgreen)](https://www.shellcheck.net/)
[![CI](https://github.com/dkmnx/cc-glm-switcher/actions/workflows/ci.yml/badge.svg)](https://github.com/dkmnx/cc-glm-switcher/actions/workflows/ci.yml)

**Current version:** 1.0.0

A robust shell script utility that enables seamless switching between Claude Code and Z.AI GLM models by safely managing your Claude Code configuration.

> **⚠️ Platform Compatibility**: This script has been tested and confirmed to work on Linux only. While it may work on other Unix-like systems (macOS, WSL), compatibility is not guaranteed.

## Overview

This script allows you to easily toggle between:

- **Claude Code models** (default Anthropic models)
- **Z.AI GLM models** (GLM-4.5-air, GLM-4.6) via Z.AI's API

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
   chmod +x cc_glm_switcher.sh
   ```

5. **Configure your `.env` file** with your Z.AI credentials:

   ```bash
   ZAI_AUTH_TOKEN=your_zai_api_token_here

   # Optional: Configure backup retention (default: 5)
   MAX_BACKUPS=5
   ```

## Usage

### Basic Model Switching

```bash
# Switch to Claude Code models
./cc_glm_switcher.sh cc

# Switch to Z.AI GLM models
./cc_glm_switcher.sh glm
```

### View Current Configuration

```bash
# Display current settings.json with configuration summary
./cc_glm_switcher.sh show
```

### Version Information

```bash
# Show version and repository information
./cc_glm_switcher.sh --version
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
chmod +x cc_glm_switcher.sh
./cc_glm_switcher.sh glm

# 3. Verify the switch worked
./cc_glm_switcher.sh show

# 4. Switch back to Claude Code when needed
./cc_glm_switcher.sh cc
```

### Advanced Options

```bash
# Verbose output (shows current configuration and detailed operations)
./cc_glm_switcher.sh glm -v

# Dry run (preview changes without applying them)
./cc_glm_switcher.sh glm --dry-run

# Show help message
./cc_glm_switcher.sh -h

# Show version information
./cc_glm_switcher.sh --version
```

The version command displays:

```bash
cc_glm-switcher v1.0.0
Repository: https://github.com/dkmnx/cc-glm-switcher

A robust shell script utility for switching between Claude Code and Z.AI GLM models.
Licensed under MIT. Use at your own risk.
```

## Backup Management

### List Backups

```bash
# List all available backup files
./cc_glm_switcher.sh list
```

### Restore From Backup

```bash
# Interactive restore (choose from menu)
./cc_glm_switcher.sh restore

# Restore from specific backup number
./cc_glm_switcher.sh restore 2

# Restore with dry run to preview
./cc_glm_switcher.sh restore 1 --dry-run
```

### Backup Retention

Configure backup retention in your `.env` file:

```bash
# Keep maximum 5 backup files (default)
MAX_BACKUPS=5

# Keep maximum 10 backup files
MAX_BACKUPS=10

# Keep maximum 3 backup files
MAX_BACKUPS=3
```

The script automatically:

- Creates timestamped backups before any changes
- Removes oldest backups when limit is exceeded
- Preserves the most recent backups
- Creates backup of current settings before restore

### Complete Command Reference

Run `./cc_glm_switcher.sh --help` to see all available commands:

```text
Commands:
  cc               Switch to Claude Code models
  glm              Switch to Z.AI GLM models
  list             List available backup files
  restore [N]      Restore from backup (interactive or specify number)
  show             Display current settings.json file

Options:
  -v, --verbose    Enable verbose output
  --dry-run        Show what would be done without making changes
  -V, --version    Show version information
  -h, --help       Show this help message
```

## Features

### 🔒 Safety & Reliability

- **Atomic operations**: Prevents configuration corruption
- **Automatic backups**: Timestamped backups before any changes
- **Backup retention**: Configurable number of backups to keep (default: 5)
- **Lock mechanism**: Prevents concurrent script execution
- **JSON validation**: Ensures configuration files remain valid
- **Error handling**: Graceful failure with descriptive messages
- **Intelligent environment preservation**: Safeguards your custom environment variables

### 💾 Backup Management

- **List backups**: View all available backup files with timestamps
- **Interactive restore**: Choose from available backups via menu
- **Direct restore**: Restore from specific backup number
- **Pre-restore backup**: Automatically backs up current settings before restore
- **Configurable retention**: Set `MAX_BACKUPS` in `.env` file (default: 5)

### 🔄 Model Configuration

#### Claude Code Mode

- Removes only GLM-specific environment variables
- Preserves all custom environment variables
- Restores default Anthropic model configuration

#### GLM Mode

- Configures Z.AI API endpoint
- Maps Claude model names to GLM equivalents:
  - `haiku` → `glm-4.5-air`
  - `sonnet` → `glm-4.6`
  - `opus` → `glm-4.6`

### 📁 File Management

- **Backups**: Stored in `configs/settings_backup_YYYYMMDD_HHMMSS.json`
- **Lock file**: `$HOME/.claude/.switcher.lock`
- **Temp files**: Securely created and cleaned up automatically

## How It Works

The script safely modifies the `~/.claude/settings.json` file by manipulating the `env` section:

1. **Lock & Validate**: Acquires exclusive lock and validates current configuration
2. **Backup**: Creates a timestamped backup of current settings (GLM-specific variables removed for clean backups)
3. **Switch**:
   - **CC mode**: Removes only GLM-specific environment variables while preserving custom ones
   - **GLM mode**: Injects Z.AI API configuration while preserving existing custom variables
4. **Validate**: Ensures JSON validity before and after changes
5. **Apply**: Uses atomic file operations to prevent corruption
6. **Cleanup**: Releases lock and removes temporary files

## Configuration Details

When switching to GLM mode, the script adds these environment variables (preserving any existing custom ones):

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "your_zai_token",
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "API_TIMEOUT_MS": "3000000",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.6",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-4.6",
    "CLAUDE_MODEL_PROVIDER": "zhipu",
    "GLM_MODEL_MAPPING": "haiku:glm-4.5-air,sonnet:glm-4.6,opus:glm-4.6"
  }
}
```

### 🔄 Environment Variable Handling

#### From GLM Mode → Claude Code Mode

- ✅ **Preserved**: All your custom environment variables (`CUSTOM_API_KEY`, `PERSONAL_CONFIG`, etc.)
- ❌ **Removed**: Only GLM-specific variables listed above

#### From Claude Code Mode → GLM Mode

- ✅ **Preserved**: Any existing custom environment variables
- ➕ **Added**: GLM-specific variables (overwrites if they exist)

#### Backup Strategy

- **Clean Backups**: When backing up GLM configurations, GLM-specific variables are removed to create "clean" snapshots
- **Full Preservation**: Custom environment variables are always preserved in backups
- **Timestamped**: All backups include full timestamp for easy identification

## Security

- **Token security**: Never commit your `.env` file to version control
- **File permissions**: Script uses secure temporary file creation
- **Input validation**: Tokens are validated for basic format requirements

## Testing

This project includes a comprehensive automated test suite with 37 targeted checks across three scripts plus a master runner. For detailed testing information, including how to write additional cases and understand the test framework, see [tests/README.md](tests/README.md).

### Quick Test Commands

```bash
# Run all tests
./tests/run_all_tests.sh

# Run with verbose output
./tests/run_all_tests.sh --verbose

# Check dependencies
./tests/run_all_tests.sh --check-deps

# Mirror the GitHub Actions job locally (requires sudo for apt-get)
./tests/run_all_tests.sh --check-deps && ./tests/run_all_tests.sh
```

### Continuous Integration

GitHub Actions automatically runs the test suite on every push to `main` and on all pull requests. The workflow installs `jq`, `shellcheck`, and `bat`, verifies their availability, and then executes the full suite (`./tests/run_all_tests.sh`). Check the latest status via the **CI** badge above or by visiting the [Actions dashboard](https://github.com/dkmnx/cc-glm-switcher/actions/workflows/ci.yml).

#### Reproducing the CI job locally

- **Using `act`** (recommended):

  ```bash
  act push --job test
  ```

  `act` will run the workflow in a container that matches GitHub’s `ubuntu-latest` runner.

- **Manual dry run** without extra tooling:

  ```bash
  sudo apt-get update
  sudo apt-get install -y jq shellcheck bat
  ./tests/run_all_tests.sh --check-deps
  ./tests/run_all_tests.sh
  ```

  Running the commands inside an Ubuntu container (`docker run -it --rm ubuntu:22.04 bash`) gives you a clean environment similar to CI.

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

- **[CLAUDE.md](CLAUDE.md)**: Guidance for Claude Code when working with this repository
- **[SUMMARY.md](SUMMARY.md)**: Detailed script summary and architecture overview
- **[PLAN.md](PLAN.md)**: Test implementation plan and progress tracking
- **[tests/README.md](tests/README.md)**: Comprehensive testing framework documentation

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

**⚠️ Important Notice**: This script modifies your Claude Code configuration files. Always ensure you have proper backups before making changes. Use at your own risk.

## Support

For issues related to:

- **Script functionality**: Create an issue in this repository
- **Claude Code**: Visit the [Claude Code documentation](https://docs.claude.com)
- **Z.AI API**: Contact [Z.AI support](https://z.ai/contact)
