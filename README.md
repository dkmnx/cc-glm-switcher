# Claude Code ↔ Z.AI GLM Model Switcher

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
- `jq` command-line JSON processor
- Valid Z.AI API token
- Bash shell environment

### Installation of Dependencies

```bash
# Install jq (Ubuntu/Debian)
sudo apt-get install jq

# Install jq (macOS)
brew install jq

# Install jq (Fedora/CentOS)
sudo dnf install jq
```

## Setup

1. **Clone or download this repository**
2. **Create the environment file**:
   ```bash
   cp .env.example .env
   # Edit .env with your Z.AI API token
   ```

3. **Make the script executable**:
   ```bash
   chmod +x cc_glm_switcher.sh
   ```

4. **Create your `.env` file** with your Z.AI credentials:
   ```bash
   ZAI_AUTH_TOKEN=your_zai_api_token_here
   ```

## Usage

### Basic Model Switching

```bash
# Switch to Claude Code models
./cc_glm_switcher.sh cc

# Switch to Z.AI GLM models
./cc_glm_switcher.sh glm
```

### Advanced Options

```bash
# Verbose output (shows current configuration and detailed operations)
./cc_glm_switcher.sh glm -v

# Dry run (preview changes without applying them)
./cc_glm_switcher.sh glm --dry-run

# Show help message
./cc_glm_switcher.sh -h
```

## Features

### 🔒 Safety & Reliability
- **Atomic operations**: Prevents configuration corruption
- **Automatic backups**: Timestamped backups before any changes
- **Lock mechanism**: Prevents concurrent script execution
- **JSON validation**: Ensures configuration files remain valid
- **Error handling**: Graceful failure with descriptive messages
- **Intelligent environment preservation**: Safeguards your custom environment variables

### 🔄 Model Configuration

#### Claude Code Mode
- Removes custom environment variables
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

The script modifies the `~/.claude/settings.json` file by manipulating the `env` section:

1. **Backup**: Creates a timestamped backup of current settings
2. **Switch**:
   - **CC mode**: Removes the `env` section entirely
   - **GLM mode**: Injects Z.AI API configuration
3. **Validate**: Ensures JSON validity before and after changes
4. **Apply**: Uses atomic file operations to prevent corruption

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

### 🔄 What Gets Backed Up

#### From GLM Mode → Claude Code Mode:
- ✅ **Preserved**: All your custom environment variables (`CUSTOM_API_KEY`, `PERSONAL_CONFIG`, etc.)
- ❌ **Removed**: Only GLM-specific variables listed above

#### From Claude Code Mode → GLM Mode:
- ✅ **Preserved**: Any existing custom environment variables
- ➕ **Added**: GLM-specific variables (overwrites if they exist)

## Troubleshooting

### Common Issues

1. **"claude command not found"**
   - Install Claude Code CLI: https://github.com/anthropics/claude-code

2. **"jq command not found"**
   - Install jq using your package manager (see Prerequisites)

3. **"ZAI_AUTH_TOKEN not found"**
   - Ensure `.env` file exists in the script directory
   - Check that the token is correctly formatted

4. **"Another instance is already running"**
   - Check if another script instance is running
   - Manually remove lock file: `rm ~/.claude/.switcher.lock`

5. **"Invalid JSON" errors**
   - Check your current `~/.claude/settings.json` for syntax errors
   - Restore from a backup in the `configs/` directory

6. **Lost custom environment variables**
   - The script now preserves custom environment variables automatically
   - Check verbose output (`-v`) to see what variables are being preserved
   - If you lost custom variables before this fix, restore from an older backup

### Debug Mode

Use verbose output to troubleshoot issues:

```bash
./cc_glm_switcher.sh glm -v
```

### Recovery

If something goes wrong, you can restore from a backup:

```bash
# List available backups
ls -la configs/settings_backup_*.json

# Restore a specific backup
cp configs/settings_backup_YYYYMMDD_HHMMSS.json ~/.claude/settings.json
```

## Security

- **Token security**: Never commit your `.env` file to version control
- **File permissions**: Script uses secure temporary file creation
- **Input validation**: Tokens are validated for basic format requirements

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test thoroughly with both `--dry-run` and actual execution
4. Submit a pull request

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

**⚠️ Important Notice**: This script modifies your Claude Code configuration files. Always ensure you have proper backups before making changes. Use at your own risk.

## Support

For issues related to:
- **Script functionality**: Create an issue in this repository
- **Claude Code**: Visit the [Claude Code documentation](https://docs.claude.com)
- **Z.AI API**: Contact Z.AI support