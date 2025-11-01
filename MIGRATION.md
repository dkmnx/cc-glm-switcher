# Migration Guide: cc-glm-switcher → cc-provider-switcher

This guide provides step-by-step instructions for migrating from the old `cc-glm-switcher` script to the new `cc-provider-switcher` script.

## Overview

The project has been renamed from **cc-glm-switcher** to **cc-provider-switcher** to reflect the expanded scope beyond just GLM models to support multiple AI providers.

**Breaking Change**: The script file has been renamed from `cc_glm_switcher.sh` to `cc_provider_switcher.sh`.

## Migration Steps

### Step 1: Update Script References

If you have scripts, aliases, or automation that reference the old script name, update them:

**Old usage:**
```bash
./cc_glm_switcher.sh cc
./cc_glm_switcher.sh glm
./cc_glm_switcher.sh show
```

**New usage:**
```bash
./cc_provider_switcher.sh cc
./cc_provider_switcher.sh glm
./cc_provider_switcher.sh show
```

### Step 2: Install the Updated Script

1. **Download the new script:**
   ```bash
   # If you have a local copy, rename it:
   mv cc_glm_switcher.sh cc_provider_switcher.sh
   chmod +x cc_provider_switcher.sh
   ```

2. **Or reinstall from source:**
   ```bash
   # Download from the repository
   wget -O cc_provider_switcher.sh [repository-url]/cc_provider_switcher.sh
   chmod +x cc_provider_switcher.sh
   ```

### Step 3: Update Configuration Files

The script is backward compatible with your existing configuration:

- **`.env` file**: No changes required - same format and variables
- **`configs/` directory**: Existing backups are automatically recognized
- **`~/.claude/settings.json`**: No changes needed - script works with existing configs

### Step 4: Update Automations

If you use the script in:
- **Cron jobs**: Update the script path
- **Shell scripts**: Update script references
- **Aliases**: Update alias definitions
- **Desktop shortcuts**: Update target path

### Step 5: Verify Installation

Test the new script to ensure it works correctly:

```bash
# Show version (should be v3.0.0)
./cc_provider_switcher.sh --version

# Test basic functionality
./cc_provider_switcher.sh show

# Switch modes
./cc_provider_switcher.sh cc
./cc_provider_switcher.sh glm
```

## Version Information

- **Old version**: cc-glm-switcher v2.0.0
- **New version**: cc-provider-switcher v3.0.0

## Compatibility Notes

### What's the Same
- ✅ All configuration file formats
- ✅ Environment variables (`.env` format)
- ✅ Backup file format and location
- ✅ Command-line interface and options
- ✅ JSON configuration structure

### What's Changed
- ❌ Script filename: `cc_glm_switcher.sh` → `cc_provider_switcher.sh`
- ❌ Version number: v2.0.0 → v3.0.0
- ❌ Project name in documentation and branding

### Breaking Changes
- **Script references**: Any automation or scripts using the old filename will need updates
- **Command execution**: `cc_glm_switcher.sh` command will no longer work

## Rollback (If Needed)

If you encounter issues and need to rollback:

1. **Revert to previous version:**
   ```bash
   git checkout HEAD~1
   ```

2. **Restore previous script:**
   ```bash
   # If you backed up the old script
   mv cc_glm_switcher.sh.backup cc_glm_switcher.sh
   chmod +x cc_glm_switcher.sh
   ```

## Common Issues

### Issue: "Command not found" after migration

**Solution**: Update your PATH or script references to use the new filename.

### Issue: Existing backups not recognized

**Solution**: Backups should work automatically. If issues persist, check file permissions:
```bash
chmod 600 configs/backup_*.json
```

### Issue: Configuration not working

**Solution**: The `.env` format hasn't changed. Verify your environment variables are still set correctly.

## Support

If you encounter issues during migration:

1. Check the [Troubleshooting guide](TROUBLESHOOTING.md)
2. Verify all tests pass: `./tests/run_basic_tests.sh`
3. Run with verbose output for debugging: `./cc_provider_switcher.sh [command] -v`
4. Open an issue in the repository with details about the problem

## Summary

The migration is straightforward:
1. Update script references to new filename
2. Test basic functionality
3. Update any automation that references the old script

The configuration and backup systems remain fully compatible with no changes required.