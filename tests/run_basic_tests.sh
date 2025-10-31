#!/bin/bash
# Basic Test Runner for cc_glm_switcher.sh

# Get script directory (absolute path)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_SCRIPT="$SCRIPT_DIR/test_basic.sh"

echo "Running basic tests for cc_glm_switcher.sh..."
echo "=============================================="
echo "Project directory: $PROJECT_DIR"
echo "Test script: $TEST_SCRIPT"
echo ""

# Check if test script exists
if [[ ! -f "$TEST_SCRIPT" ]]; then
    echo "❌ Error: Test script not found at $TEST_SCRIPT"
    exit 1
fi

# Make test script executable
chmod +x "$TEST_SCRIPT"

# Change to project directory and run the basic test suite
cd "$PROJECT_DIR"
bash "$TEST_SCRIPT"
TEST_EXIT_CODE=$?

if [[ $TEST_EXIT_CODE -eq 0 ]]; then
    echo -e "\n🎉 All basic tests completed successfully!"
    exit 0
else
    echo -e "\n⚠️  Some tests failed - check output above"
    exit 1
fi