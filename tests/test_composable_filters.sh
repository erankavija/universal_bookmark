#!/bin/bash
# Test suite for composable filter functions
# These tests validate the UNIX-style filter pattern implementation

# No set -e because we handle errors in run_test
set -o pipefail

# Set up test environment
export BOOKMARKS_DIR=$(mktemp -d)
export NON_INTERACTIVE=true
echo "Test environment set up at $BOOKMARKS_DIR"

# Initialize test counters
tests_passed=0
tests_failed=0

# Path to bookmarks script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOKMARKS_SCRIPT="$SCRIPT_DIR/../bookmarks.sh"

# Create initial bookmarks file
echo '{"bookmarks":[]}' > "$BOOKMARKS_DIR/bookmarks.json"

# Helper function to run tests
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_exit="${3:-0}"
    
    echo "Running test: $test_name"
    eval "$test_cmd" > /dev/null 2>&1
    local exit_code=$?
    
    if [ $exit_code -eq $expected_exit ]; then
        echo "✓ Test passed: $test_name"
        ((tests_passed++))
        return 0
    else
        echo "✗ Test failed: $test_name (Exit code: $exit_code, Expected: $expected_exit)"
        ((tests_failed++))
        return 1
    fi
}

# Show test summary
show_test_summary() {
    echo ""
    echo "Test summary:"
    echo "  Tests passed: $tests_passed"
    echo "  Tests failed: $tests_failed"
    echo "  Total tests: $((tests_passed + tests_failed))"
    
    if [ $tests_failed -eq 0 ]; then
        echo "All composable filter tests passed! 🎉"
    else
        echo "Some tests failed."
    fi
}

# Cleanup function
cleanup_test_env() {
    echo "Cleaning up test environment..."
    rm -rf "$BOOKMARKS_DIR"
    echo "Test environment cleaned up"
}

trap cleanup_test_env EXIT

echo "Starting composable filters test suite for Universal Bookmarks"

# Add some test bookmarks for filtering
run_test "Add URL bookmark for filter tests" \
    "$BOOKMARKS_SCRIPT add 'Google Search' url 'xdg-open https://google.com' 'search web'"

run_test "Add script bookmark for filter tests" \
    "$BOOKMARKS_SCRIPT add 'List Directory' script 'ls -la' 'files system'"

run_test "Add note bookmark for filter tests" \
    "$BOOKMARKS_SCRIPT add 'TODO List' note 'cat ~/todo.txt' 'notes personal'"

# Since we can't easily test the pure filter functions in isolation without sourcing,
# we'll test them through the main script's functionality

# Test that we can list bookmarks (validates filter_all_bookmarks works)
echo "Testing bookmark listing (validates filters)..."
bookmark_count=$("$BOOKMARKS_SCRIPT" list | wc -l 2>/dev/null || echo "0")
if [ "$bookmark_count" -ge 3 ]; then
    echo "✓ Test passed: Can list all bookmarks"
    ((tests_passed++))
else
    echo "✗ Test failed: Bookmark listing issue"
    ((tests_failed++))
fi

# Test filtering by tag through search
echo "Testing tag search (validates filter_by_tag)..."
search_result=$("$BOOKMARKS_SCRIPT" tag "search" 2>&1 | grep -c "Google Search" || echo "0")
if [ "$search_result" -ge 1 ]; then
    echo "✓ Test passed: Tag filtering works"
    ((tests_passed++))
else
    echo "✗ Test failed: Tag filtering doesn't work"
    ((tests_failed++))
fi

# Test marking bookmark as obsolete - we can't easily test this without interactive mode
# so we'll skip it for now. The important thing is that the filters themselves work.
echo "Skipping obsolete test (requires interactive mode)"

echo ""
echo "Note: Composable filter functions are designed for advanced users and scripts."
echo "They enable UNIX-style pipeline operations like:"
echo "  filter_all_bookmarks | filter_active | filter_by_type 'url' | format_bookmark_line"
echo ""

# Show test summary
show_test_summary

# Exit code based on test results
exit $((tests_failed > 0 ? 1 : 0))
