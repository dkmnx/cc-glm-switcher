# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains a shell script utility (`cc_glm_switcher.sh`) that enables switching between Claude Code and Z.AI GLM models by modifying the Claude Code configuration file (`~/.claude/settings.json`).

## Key Components

### Main Script
- `cc_glm_switcher.sh`: Bash script that performs model switching by:
  - Creating backups of current settings
  - Validating JSON configuration files using `jq`
  - Injecting environment variables for GLM model configuration
  - Providing atomic file operations and lock mechanisms for safety

### Configuration Files
- `configs/`: Directory containing timestamped backups of `settings.json`
- `.env`: Contains `ZAI_AUTH_TOKEN` for GLM API authentication (not tracked in git)

## Common Commands

### Model Switching
```bash
# Switch to Claude Code models
./cc_glm_switcher.sh cc

# Switch to Z.AI GLM models
./cc_glm_switcher.sh glm

# Verbose output
./cc_glm_switcher.sh glm -v

# Dry run (show what would be done)
./cc_glm_switcher.sh glm --dry-run

# Show help
./cc_glm_switcher.sh -h
```

### Dependencies
- `jq`: Required for JSON manipulation and validation
- `claude`: Claude Code CLI tool
- Standard Unix utilities (`mv`, `cp`, `rm`, `date`)

## Architecture

### Safety Mechanisms
- **Lock file**: Prevents concurrent script execution (`$HOME/.claude/.switcher.lock`)
- **Atomic operations**: Uses temporary files and atomic moves to prevent corruption
- **JSON validation**: Validates all JSON operations before and after modification
- **Backup strategy**: Creates timestamped backups before any changes
- **Cleanup traps**: Ensures temporary files are cleaned up on script exit

### Model Configuration Strategy
The script operates by modifying the `env` section in `~/.claude/settings.json`:
- **Claude Code mode**: Removes the `env` section entirely
- **GLM mode**: Injects environment variables pointing to Z.AI's API endpoint with GLM model mappings

### Error Handling
- Input validation for authentication tokens
- Pre-flight checks for required commands
- JSON validation before and after operations
- Graceful error handling with descriptive messages

## Environment Setup

Create a `.env` file in the repository root containing:
```
ZAI_AUTH_TOKEN=your_zai_api_token_here
```

The script will automatically create the `configs/` directory for backups if it doesn't exist.