# Test Implementation Plan for cc_glm_switcher.sh

A minimized, essential test suite with **3 phases** covering critical functionality (~35-40 tests total).

---

## **Phase 1: Test Infrastructure**
**Goal:** Set up minimal test framework

### Files to Create:
1. **`tests/test_helper.sh`** - Core test utilities
   - `assert_equals()`, `assert_file_exists()`
   - `assert_json_valid()`, `assert_contains()`
   - `setup_test_env()` - Creates isolated test directories
   - `teardown_test_env()` - Cleanup
   - Test result tracking (PASSED/FAILED count)

2. **`tests/fixtures/`** - Sample files
   - `settings_cc.json` - Valid Claude Code config
   - `settings_glm.json` - Valid GLM config
   - `invalid.json` - Malformed JSON

### Phase 1 Testing:
```bash
# Manually verify test_helper.sh functions work
source tests/test_helper.sh && setup_test_env && teardown_test_env
```

---

## **Phase 2: Core Functionality**
**Goal:** Test essential model switching and backup operations

### Test Suite:
**`tests/test_core.sh`** - ~20 tests

**Model Switching** (10 tests):
- Switch to GLM: adds all required env vars
- Switch to GLM: uses correct API endpoint (https://api.z.ai/api/anthropic)
- Switch to GLM: sets CLAUDE_MODEL_PROVIDER=zhipu
- Switch to GLM: reads ZAI_AUTH_TOKEN from .env
- Switch to GLM: creates backup before switching
- Switch to CC: removes all GLM-specific vars
- Switch to CC: preserves custom env variables
- Switch to CC: creates backup before switching
- Round-trip: CC → GLM → CC preserves original
- Dry-run: makes no actual changes

**Backup System** (8 tests):
- Backup created with timestamp format YYYYMMDD_HHMMSS
- Backup contains valid JSON
- Backup from GLM mode strips GLM vars only
- List command shows all backups
- Restore by number works
- Restore validates backup before applying
- Restore creates pre-restore backup
- MAX_BACKUPS cleanup removes oldest files

**JSON Validation** (2 tests):
- Valid JSON passes validation
- Invalid JSON fails validation

### Phase 2 Testing:
```bash
./tests/test_core.sh
```
**Expected:** ~20 tests pass

---

## **Phase 3: Error Handling & CLI**
**Goal:** Test critical error cases and CLI options

### Test Suites:

**`tests/test_errors.sh`** - ~10 tests

**Dependency & File Errors** (5 tests):
- Missing jq command detected
- Missing .env file shows error (GLM switch)
- Corrupted settings.json aborts operation
- Missing settings.json creates minimal valid one
- Lock prevents concurrent execution

**Input Validation** (5 tests):
- Invalid token format rejected
- Empty ZAI_AUTH_TOKEN rejected
- Invalid backup number shows error
- Unknown command shows usage
- Invalid restore selection rejected

**`tests/test_cli.sh`** - ~8 tests

**Command Parsing** (4 tests):
- `cc` command switches to Claude Code
- `glm` command switches to GLM
- `list` command shows backups
- `restore N` restores backup number N

**Options** (4 tests):
- `-v/--verbose` enables verbose output
- `--dry-run` makes no changes
- `-h/--help` shows help
- `-V/--version` shows version

**`tests/run_all_tests.sh`** - Master runner
- Runs all test suites in order
- Aggregates results (TOTAL:PASSED:FAILED)
- Supports `--verbose` flag
- Exit code 0 if all pass, 1 if any fail

### Phase 3 Testing:
```bash
./tests/run_all_tests.sh
./tests/run_all_tests.sh --verbose
```
**Expected:** ~18 tests pass

---

## **Test Execution Strategy**

After each phase:
1. **Run phase tests** to verify functionality
2. **Fix any failures** before proceeding
3. **Commit changes** with message: `test(phase-N): add [description]`
4. **Proceed to next phase** only when tests pass

## **Total Test Coverage**
- **Phase 1:** Infrastructure setup (no tests yet)
- **Phase 2:** ~20 tests (core switching + backups)
- **Phase 3:** ~18 tests (errors + CLI)
- **Grand Total:** ~38 essential tests

Focused on critical functionality with minimal overhead.
