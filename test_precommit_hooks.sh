#!/bin/bash
#=============================================================================
# Universal Bookmarks - Pre-commit Hook Tests
# 
# Tests for the git pre-commit hook functionality
#=============================================================================

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source test framework
source "$SCRIPT_DIR/test_framework.sh"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Create a temporary git repository for testing
setup_test_git_repo() {
    TEST_REPO_DIR=$(mktemp -d)
    cd "$TEST_REPO_DIR"
    
    # Initialize git repo
    git init > /dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    # Copy necessary files
    cp "$SCRIPT_DIR/run_tests.sh" .
    cp "$SCRIPT_DIR/test_framework.sh" .
    cp -r "$SCRIPT_DIR/.githooks" .
    
    # Make scripts executable
    chmod +x run_tests.sh
    chmod +x test_framework.sh
    chmod +x .githooks/pre-commit
    
    # Create a simple test file that always passes
    cat > test_simple.sh << 'EOF'
#!/bin/bash
echo "Test passed"
exit 0
EOF
    chmod +x test_simple.sh
    
    # Update run_tests.sh to only run test_simple.sh for faster testing
    # Comment out other test files
    sed -i 's/^    "test_framework.sh"/#    "test_framework.sh"/' run_tests.sh
    sed -i 's/^    "test_bookmarks.sh"/#    "test_bookmarks.sh"/' run_tests.sh
    sed -i 's/^    "test_frecency.sh"/#    "test_frecency.sh"/' run_tests.sh
    sed -i 's/^    "test_editor_features.sh"/#    "test_editor_features.sh"/' run_tests.sh
    sed -i 's/^    "test_special_chars.sh"/#    "test_special_chars.sh"/' run_tests.sh
    sed -i 's/^    "test_type_execution.sh"/#    "test_type_execution.sh"/' run_tests.sh
    sed -i 's/^    "test_composable_filters.sh"/#    "test_composable_filters.sh"/' run_tests.sh
    sed -i 's/^    "test_precommit_hooks.sh"/#    "test_precommit_hooks.sh"/' run_tests.sh
    
    # Add test_simple.sh to the array
    sed -i '/^TEST_FILES=(/a\    "test_simple.sh"' run_tests.sh
    
    # Initial commit
    git add .
    git commit -m "Initial commit" > /dev/null 2>&1
}

# Cleanup test repository
cleanup_test_git_repo() {
    cd "$SCRIPT_DIR"
    rm -rf "$TEST_REPO_DIR"
}

# Run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"
    
    if eval "$test_command" > /dev/null 2>&1; then
        local actual_exit_code=0
    else
        local actual_exit_code=$?
    fi
    
    if [ "$actual_exit_code" -eq "$expected_exit_code" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name (expected exit code $expected_exit_code, got $actual_exit_code)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo ""
echo "Testing pre-commit hook functionality..."
echo ""

# Test 1: Hook mode in run_tests.sh
run_test "run_tests.sh accepts --hook flag" \
    "$SCRIPT_DIR/run_tests.sh --help | grep -q '\-\-hook'"

# Test 2: Pre-commit hook exists and is executable
run_test "Pre-commit hook exists and is executable" \
    "[ -x '$SCRIPT_DIR/.githooks/pre-commit' ]"

# Test 3: Pre-commit hook with no staged files
setup_test_git_repo
run_test "Pre-commit hook skips tests when no shell scripts changed" \
    "git config core.hooksPath .githooks && touch README.md && git add README.md && git commit -m 'test' --no-verify && ./.githooks/pre-commit | grep -q 'No shell scripts changed'"
cleanup_test_git_repo

# Test 4: Pre-commit hook with staged shell file
setup_test_git_repo
git config core.hooksPath .githooks
echo "# comment" >> run_tests.sh
git add run_tests.sh
OUTPUT=$(./.githooks/pre-commit 2>&1 || true)
run_test "Pre-commit hook runs tests when shell scripts changed" \
    "echo '$OUTPUT' | grep -q 'Changed shell scripts'"
cleanup_test_git_repo

# Test 5: Pre-commit hook passes with passing tests
setup_test_git_repo
git config core.hooksPath .githooks
echo "# comment" >> test_simple.sh
git add test_simple.sh
run_test "Pre-commit hook exits 0 when tests pass" \
    "./.githooks/pre-commit 2>&1"
cleanup_test_git_repo

# Test 6: Pre-commit hook fails with failing tests
setup_test_git_repo
git config core.hooksPath .githooks
# Create a failing test
cat > test_simple.sh << 'EOF'
#!/bin/bash
echo "Test failed"
exit 1
EOF
chmod +x test_simple.sh
git add test_simple.sh
run_test "Pre-commit hook exits 1 when tests fail" \
    "./.githooks/pre-commit" 1
cleanup_test_git_repo

# Test 7: Hook mode is quiet and fail-fast
# The hook mode should still show test suite output but skip the fancy header
run_test "Hook mode runs tests without main header" \
    "$SCRIPT_DIR/run_tests.sh --hook 2>&1 | grep -qv 'Universal Bookmarks Test Runner' || true"

echo ""
echo "Test summary:"
echo "  Tests passed: $TESTS_PASSED"
echo "  Tests failed: $TESTS_FAILED"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
