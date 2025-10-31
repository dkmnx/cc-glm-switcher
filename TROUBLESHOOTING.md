# Troubleshooting

This guide covers common issues and solutions for the cc-glm-switcher script.

## Common Issues

### 1. "claude command not found"

**Problem**: The script cannot find the Claude Code CLI.

**Solution**:

- Install Claude Code CLI: <https://github.com/anthropics/claude-code>
- Ensure it's in your PATH and executable

### 2. "jq command not found"

**Problem**: The script cannot find the `jq` JSON processor.

**Solution**:

- Install jq using your package manager:

  ```bash
  # Ubuntu/Debian
  sudo apt-get install jq

  # macOS
  brew install jq

  # Fedora/CentOS
  sudo dnf install jq
  ```

### 3. "ZAI_AUTH_TOKEN not found"

**Problem**: The script cannot find your Z.AI API token.

**Solution**:

- Ensure `.env` file exists in the script directory
- Check that the token is correctly formatted:

  ```bash
  ZAI_AUTH_TOKEN=your_zai_api_token_here
  ```

- Verify the file permissions allow reading

### 4. "Another instance is already running"

**Problem**: The script detects a lock file, indicating another instance is running.

**Solution**:

- Check if another script instance is actually running:

  ```bash
  ps aux | grep cc_glm_switcher
  ```

- If no other instance is running, manually remove the lock file:

  ```bash
  rm ~/.claude/.switcher.lock
  ```

### 5. "Invalid JSON" errors

**Problem**: The script detects invalid JSON in your settings file.

**Solution**:

- Check your current `~/.claude/settings.json` for syntax errors
- Use a JSON validator to identify the issue
- Restore from a backup in the `configs/` directory:

  ```bash
  # List available backups
  ./cc_glm_switcher.sh list

  # Restore from a specific backup
  ./cc_glm_switcher.sh restore 1
  ```

### 6. Lost custom environment variables

**Problem**: Custom environment variables disappeared after switching modes.

**Solution**:

- The script now preserves custom environment variables automatically
- Check verbose output (`-v`) to see what variables are being preserved:

  ```bash
  ./cc_glm_switcher.sh glm -v
  ```

- If you lost custom variables before this fix, restore from an older backup

## Debug Mode

Use verbose output to troubleshoot issues and see detailed operation information:

```bash
# Switch to GLM mode with verbose output
./cc_glm_switcher.sh glm -v

# Switch to CC mode with verbose output
./cc_glm_switcher.sh cc -v

# Dry run with verbose output to preview changes
./cc_glm_switcher.sh glm --dry-run -v
```

Verbose output shows:

- Current configuration state
- Environment variables being preserved/removed
- File operations being performed
- Backup creation details
- Validation results

## Recovery

If something goes wrong, you can manually restore from a backup:

### Using the Script

```bash
# List available backups
./cc_glm_switcher.sh list

# Interactive restore (choose from menu)
./cc_glm_switcher.sh restore

# Restore from specific backup number
./cc_glm_switcher.sh restore 2

# Preview restore before applying
./cc_glm_switcher.sh restore 1 --dry-run
```

### Manual Recovery

```bash
# List available backups
ls -la configs/settings_backup_*.json

# Restore a specific backup (replace with actual timestamp)
cp configs/settings_backup_20231215_143022.json ~/.claude/settings.json

# Verify the restored file is valid JSON
jq empty ~/.claude/settings.json
```

## Advanced Troubleshooting

### Check Script Environment

```bash
# Check if required dependencies are available
which claude jq

# Check environment variables
env | grep -E "(ZAI|ROOT|CONFIG)"

# Check file permissions
ls -la ~/.claude/settings.json
ls -la .env
```

### Validate Configuration Files

```bash
# Check current settings.json syntax
jq empty ~/.claude/settings.json

# Check .env file format
cat .env

# View current configuration
cat ~/.claude/settings.json | jq .
```

### Test Script Components

```bash
# Test JSON validation function
echo '{"test": "valid"}' | jq empty

# Test file creation permissions
touch /tmp/test_write && rm /tmp/test_write

# Test backup directory access
ls -la configs/
```

## Common Error Messages and Solutions

| Error Message | Cause | Solution |
|---------------|-------|----------|
| `File is empty or does not exist` | Missing or empty settings.json | Restore from backup or recreate settings file |
| `Invalid JSON in settings.json` | Corrupted settings file | Use JSON linter to fix or restore from backup |
| `ZAI_AUTH_TOKEN not found or empty` | Missing/invalid API token | Check .env file and token format |
| `Another instance is already running` | Stale lock file | Remove lock file or wait for other instance |
| `Permission denied` | File permission issues | Check file permissions and directory access |
| `jq: command not found` | Missing jq dependency | Install jq using package manager |

## Getting Help

If you're still experiencing issues:

1. **Check the logs**: Use verbose mode (`-v`) to get detailed information
2. **Search existing issues**: Check the GitHub repository for similar problems
3. **Create an issue**: Include:
   - Script version (`./cc_glm_switcher.sh --version`)
   - Error messages (full output)
   - Operating system and shell version
   - Steps to reproduce the issue
   - Verbose output if applicable

## Prevention Tips

- **Always use dry-run first**: Preview changes before applying them
- **Keep backups**: Don't delete old backup files immediately
- **Use verbose mode**: Understand what the script is doing
- **Check dependencies**: Ensure all required tools are installed
- **Validate JSON**: Periodically check your settings.json syntax
- **Monitor disk space**: Ensure enough space for backups

## Environment Variables Reference

The script uses these environment variables:

| Variable | Purpose | Default |
|----------|---------|---------|
| `ZAI_AUTH_TOKEN` | Your Z.AI API token | Required |
| `MAX_BACKUPS` | Maximum backup files to keep | 5 |
| `ROOT_CC` | Claude Code config directory | `~/.claude` |
| `CONFIG_DIR` | Backup storage directory | `./configs` |

## File Locations

- **Settings file**: `~/.claude/settings.json`
- **Environment file**: `./.env` (in script directory)
- **Backup directory**: `./configs/`
- **Lock file**: `~/.claude/.switcher.lock`
- **Script location**: Where you installed `cc_glm_switcher.sh`
