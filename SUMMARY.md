# cc_glm_switcher.sh Summary

## Overview
- Bash utility that flips `~/.claude/settings.json` between Claude Code defaults and Z.AI GLM overrides.
- Ships with runtime safety nets: lock file enforcement, JSON validation, and atomic writes.
- Records timestamped backups under `configs/` and trims history against a configurable retention cap.
- Supports inspection and restoration tooling so operators can audit or roll back configuration state.

## Command Interface
- `./cc_glm_switcher.sh glm` – apply GLM provider settings sourced from `.env`.
- `./cc_glm_switcher.sh cc` – strip GLM-specific keys, reverting to Claude Code defaults.
- `./cc_glm_switcher.sh list` – print ordered backups with human-friendly timestamps.
- `./cc_glm_switcher.sh restore [N]` – restore interactively or by index; always re-validates JSON.
- `./cc_glm_switcher.sh show` – pretty-print current settings and highlight active mode.
- Global flags: `--dry-run` (no writes, auto-enables verbose logging) and `--verbose`.

## Execution Flow
1. Parse command argument and flags, deferring `restore` until all options are read.
2. For `list`, `show`, `restore` commands the script exits after handling the request.
3. `cc`/`glm` branches:
   - Acquire `.switcher.lock` (configurable via `LOCK_FILE`) to prevent concurrent writes.
   - Ensure `claude` CLI and `jq` are available.
   - Create `configs/` if missing and set up temp files plus a timestamped backup path.
   - Validate the live `settings.json`, creating `{}` when absent.
   - Copy a "clean" snapshot into a temp backup, removing GLM-only keys if necessary.
   - Atomically rotate that snapshot into `configs/settings_backup_<timestamp>.json`.
   - Enforce retention with `MAX_BACKUPS` (default 5, overridable through `.env`).
   - Prepare new settings in `temp_settings` and atomically move them into place (skipped in dry-run).
4. Registered EXIT/INT/TERM trap releases the lock and propagates the exit status.

## Mode-Specific Behavior
- **GLM:**
  - Loads `.env` (search order: current dir, repository root, test sandbox) and extracts `ZAI_AUTH_TOKEN`.
  - Validates token format, then injects GLM-specific env keys (provider `zhipu`, Z.AI API URL, model mapping, extended timeout).
  - Retains existing non-GLM configuration from the backup baseline.
- **Claude Code:**
  - Starts from current `settings.json`, removes GLM environment keys via `jq`, and writes the sanitized result.
  - Leaves any other `env` entries intact and drops the block entirely when empty.

## Backup and Restore Strategy
- Backups created on every run before modifications; GLM-mode backups omit sensitive GLM env keys.
- `cleanup_old_backups` keeps newest `MAX_BACKUPS` files and deletes older ones.
- `list_backups` and `interactive_restore` read from `CONFIG_DIR` (default `configs/`) and show formatted timestamps.
- `restore_backup` validates the chosen file, creates a "before restore" backup, then reuses `atomic_move` to replace the live settings.

## Safety and Validation
- Lock file (`.switcher.lock` by default) ensures single-writer semantics; failures emit PID diagnostics.
- `validate_json` guards both backups and the target settings using `jq empty`.
- `atomic_move` keeps writes atomic (`mv` onto the destination) to avoid partial updates.
- Temporary files from `mktemp` reduce race conditions; cleaned at script exit.
- `DRY_RUN` messages make it clear when no file operations occur.

## Configuration and Environment Inputs
- Defaults derive from environment variables with fallbacks: `ROOT_CC`, `ROOT_SCRIPT`, `LOCK_FILE`, `CONFIG_DIR`, `MAX_BACKUPS`.
- `load_config` sources `.env` (if present) with `set -a`, feeding values like `MAX_BACKUPS` into retention logic.
- Token validation enforces a conservative character whitelist and non-empty values.

## Dependencies and Ecosystem Hooks
- Requires `claude` CLI to exist in PATH; aborts early with installation guidance if missing.
- Requires `jq`; optionally leverages `bat` for `show` output.
- Designed to integrate with regression scripts under `tests/` that simulate the CLI using fixtures and dry-run operations.

## Operational Notes
- Script follows a verbose logging pattern gated by `--verbose`; info messages include file moves and cleanup steps.
- `trim_whitespace` ensures robust CLI argument parsing, especially when restore IDs are passed through wrappers.
- `is_glm_config` inspects multiple heuristics (provider, base URL, env mapping) to classify the active mode for backups and status messages.
- The implementation omits `set -euo pipefail`, so callers rely on explicit exit handling provided throughout the script.
