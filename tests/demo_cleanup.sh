#!/bin/bash
# Demonstration of cleanup functionality in test_helper.sh

# Load test helper (cleanup handlers are registered automatically)
source "$(dirname "$0")/test_helper.sh"

echo ""
echo "========================================="
echo "Cleanup Functionality Demo"
echo "========================================="
echo ""

# Demo 1: Automatic cleanup on exit
echo "Demo 1: Creating test environments..."
setup_test_env
DIR1="$TEST_DIR"
echo "  Created: $DIR1"

setup_test_env
DIR2="$TEST_DIR"
echo "  Created: $DIR2"

setup_test_env
DIR3="$TEST_DIR"
echo "  Created: $DIR3"

echo ""
echo "Listing test directories:"
ls -ld /tmp/cc_glm_test_* 2>/dev/null || echo "No test directories found"

echo ""
echo "Demo 2: Manual cleanup with cleanup_all..."
cleanup_all

echo ""
echo "After cleanup:"
ls -ld /tmp/cc_glm_test_* 2>/dev/null || echo "✓ All test directories cleaned up"

echo ""
echo "Demo 3: Creating orphaned directories to demonstrate cleanup_old_tests..."
# Create some test directories
mkdir -p /tmp/cc_glm_test_orphan_1
mkdir -p /tmp/cc_glm_test_orphan_2
echo "  Created orphaned directories"

echo ""
echo "Orphaned test directories:"
ls -ld /tmp/cc_glm_test_* 2>/dev/null

echo ""
echo "Running cleanup_old_tests 0 (clean all)..."
cleanup_old_tests 0

echo ""
echo "After cleanup_old_tests:"
ls -ld /tmp/cc_glm_test_* 2>/dev/null || echo "✓ All orphaned directories cleaned up"

echo ""
echo "========================================="
echo "Demo Complete"
echo "========================================="
echo ""
echo "Key takeaways:"
echo "- cleanup_all is registered as trap handler (EXIT, INT, TERM)"
echo "- Test directories are automatically tracked and cleaned up"
echo "- cleanup_old_tests removes old orphaned directories"
echo "- Manual cleanup is available with cleanup_all"
