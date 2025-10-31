#!/bin/bash
# Basic Test Suite for cc_glm_switcher.sh
# Validates core functionality with minimal complexity

# Get absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SCRIPT="$PROJECT_DIR/cc_glm_switcher.sh"
FAILURES=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Basic Test Suite for cc_glm_switcher.sh"
echo "======================================="

# Test 1: Script exists
echo -e "\n${YELLOW}1. Testing script existence...${NC}"
if [[ -f "$SCRIPT" && -x "$SCRIPT" ]]; then
    echo -e "${GREEN}✓ Script exists and is executable${NC}"
else
    echo -e "${RED}✗ Script missing or not executable${NC}"
    ((FAILURES++))
fi

# Test 2: Help command
echo -e "\n${YELLOW}2. Testing help command...${NC}"
if $SCRIPT -h > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Help command works${NC}"
else
    echo -e "${RED}✗ Help command failed${NC}"
    ((FAILURES++))
fi

# Test 3: Invalid argument handling
echo -e "\n${YELLOW}3. Testing invalid argument handling...${NC}"
if ! $SCRIPT invalid_command > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Script properly rejects invalid commands${NC}"
else
    echo -e "${RED}✗ Script should reject invalid commands${NC}"
    ((FAILURES++))
fi

# Test 4: Show command
echo -e "\n${YELLOW}4. Testing show command...${NC}"
if $SCRIPT show > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Show command works${NC}"
else
    echo -e "${RED}✗ Show command failed${NC}"
    ((FAILURES++))
fi

# Test 5: GLM mode requires auth token
echo -e "\n${YELLOW}5. Testing GLM mode authentication requirement...${NC}"
# Temporarily move .env file to test authentication requirement
ENV_FILE="$PROJECT_DIR/.env"
ENV_BACKUP="$PROJECT_DIR/.env.backup_test"
if [[ -f "$ENV_FILE" ]]; then
    mv "$ENV_FILE" "$ENV_BACKUP"
    ENV_MOVED=true
else
    ENV_MOVED=false
fi

# Test without auth token (should fail)
if ! ZAI_AUTH_TOKEN="" $SCRIPT glm > /dev/null 2>&1; then
    echo -e "${GREEN}✓ GLM mode properly requires authentication${NC}"
else
    echo -e "${RED}✗ GLM mode should require authentication${NC}"
    ((FAILURES++))
fi

# Restore .env file if it was moved
if [[ "$ENV_MOVED" == "true" ]]; then
    mv "$ENV_BACKUP" "$ENV_FILE"
fi

# Test 6: Dependencies check
echo -e "\n${YELLOW}6. Testing dependencies...${NC}"
if command -v jq > /dev/null 2>&1; then
    echo -e "${GREEN}✓ jq dependency available${NC}"
else
    echo -e "${RED}✗ jq dependency missing${NC}"
    ((FAILURES++))
fi

# Test 7: Basic CC mode
echo -e "\n${YELLOW}7. Testing CC mode switch...${NC}"
if $SCRIPT cc > /dev/null 2>&1; then
    echo -e "${GREEN}✓ CC mode switch works${NC}"
else
    echo -e "${RED}✗ CC mode switch failed${NC}"
    ((FAILURES++))
fi

# Test 8: JSON validation
echo -e "\n${YELLOW}8. Testing JSON validation...${NC}"

# Test 8a: Valid JSON creation (GLM mode creates valid JSON)
echo "  Testing valid JSON creation..."
# Setup valid token for GLM test
echo 'ZAI_AUTH_TOKEN=test_valid_token_12345' > .env.test_env

# Backup current settings
if [[ -f "$HOME/.claude/settings.json" ]]; then
    cp "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.backup_test" 2>/dev/null || true
fi

# Create GLM configuration
ENV_FILE="$PROJECT_DIR/.env.test_env"
if ZAI_AUTH_TOKEN="test_valid_token_12345" $SCRIPT glm > /dev/null 2>&1; then
    # Validate the created JSON is valid
    if [[ -f "$HOME/.claude/settings.json" ]] && jq empty "$HOME/.claude/settings.json" 2>/dev/null; then
        echo -e "${GREEN}✓ GLM mode creates valid JSON${NC}"
    else
        echo -e "${RED}✗ GLM mode created invalid JSON${NC}"
        ((FAILURES++))
    fi
else
    echo -e "${RED}✗ GLM mode failed during JSON test${NC}"
    ((FAILURES++))
fi

# Test 8b: Invalid JSON handling
echo "  Testing invalid JSON handling..."
# Create invalid JSON file
echo '{"invalid": json, "missing": quotes}' > "$HOME/.claude/settings.json"

# Test if show command handles invalid JSON gracefully
if $SCRIPT show > /dev/null 2>&1; then
    # Show command should handle invalid JSON (fallback to cat)
    echo -e "${GREEN}✓ Show command handles invalid JSON gracefully${NC}"
else
    echo -e "${RED}✗ Show command failed on invalid JSON${NC}"
    ((FAILURES++))
fi

# Test 8c: Empty JSON handling
echo "  Testing empty JSON handling..."
echo '{}' > "$HOME/.claude/settings.json"
if $SCRIPT show > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Show command handles empty JSON${NC}"
else
    echo -e "${RED}✗ Show command failed on empty JSON${NC}"
    ((FAILURES++))
fi

# Cleanup test environment
rm -f .env.test_env
if [[ -f "$HOME/.claude/settings.json.backup_test" ]]; then
    mv "$HOME/.claude/settings.json.backup_test" "$HOME/.claude/settings.json"
else
    # If no backup existed, create empty settings
    echo '{}' > "$HOME/.claude/settings.json"
fi

# Summary
echo -e "\n======================================="
if [[ $FAILURES -eq 0 ]]; then
    echo -e "${GREEN}✅ All tests passed! ($FAILURES failures)${NC}"
    exit 0
else
    echo -e "${RED}❌ $FAILURES test(s) failed${NC}"
    exit 1
fi