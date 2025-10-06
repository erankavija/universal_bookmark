#!/bin/bash

# Test suite for Universal Bookmarks
# Run this script to test the functionality of the bookmarks.sh script

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Setup test environment
setup_test_env() {
    echo -e "${BLUE}Setting up test environment...${NC}"
    
    # Create temporary test directory
    TEST_DIR=$(mktemp -d)
    TEST_BOOKMARKS_FILE="$TEST_DIR/bookmarks.json"
    
    # Initialize bookmarks file
    echo '{"bookmarks":[]}' > "$TEST_BOOKMARKS_FILE"
    
    # Save original BOOKMARKS_DIR
    ORIG_BOOKMARKS_DIR="$BOOKMARKS_DIR"
    
    # Set BOOKMARKS_DIR to test directory
    export BOOKMARKS_DIR="$TEST_DIR"
    
    echo -e "${GREEN}Test environment set up at $TEST_DIR${NC}"
}

# Cleanup test environment
cleanup_test_env() {
    echo -e "${BLUE}Cleaning up test environment...${NC}"
    
    # Restore original BOOKMARKS_DIR
    export BOOKMARKS_DIR="$ORIG_BOOKMARKS_DIR"
    
    # Remove test directory
    rm -rf "$TEST_DIR"
    
    echo -e "${GREEN}Test environment cleaned up${NC}"
}

# Run a test and check if it passes
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_exit_code="${3:-0}"
    
    echo -e "${BLUE}Running test: ${YELLOW}$test_name${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Run the command
    eval "$test_cmd"
    local exit_code=$?
    
    if [ "$exit_code" -eq "$expected_exit_code" ]; then
        echo -e "${GREEN}✓ Test passed: $test_name${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ Test failed: $test_name (Exit code: $exit_code, Expected: $expected_exit_code)${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Run the test suite
run_test_suite() {
    echo -e "${BLUE}Starting test suite for Universal Bookmarks${NC}"
    
    # Test adding a bookmark
    run_test "Add URL bookmark" \
        "./bookmarks.sh add 'Test URL' url 'echo \"This is a URL test\"'"
    
    # Test adding another bookmark
    run_test "Add script bookmark" \
        "./bookmarks.sh add 'Test Script' script 'echo \"This is a script test\"' 'test automation' 'Test notes'"
    
    # Test listing bookmarks
    run_test "List all bookmarks" \
        "./bookmarks.sh list"
    
    # Test detailed listing
    run_test "List bookmark details" \
        "./bookmarks.sh details"
    
    # Test updating a bookmark
    run_test "Update a bookmark" \
        "./bookmarks.sh update 'Test URL' url 'echo \"This is an updated URL test\"' 'updated test'"
    
    # Test tag search
    run_test "Search by tag" \
        "./bookmarks.sh tag 'test'"
    
    # Test marking a bookmark as obsolete
    run_test "Mark bookmark as obsolete" \
        "./bookmarks.sh obsolete 'Test Script'"
    
    # Test backup creation
    run_test "Create backup" \
        "./bookmarks.sh backup"
    
    # Test exporting bookmarks
    run_test "Export bookmarks" \
        "./bookmarks.sh export"
    
    # Test deleting a bookmark
    run_test "Delete a bookmark" \
        "./bookmarks.sh delete 'Test URL'"
    
    # Summary
    echo -e "${BLUE}Test summary:${NC}"
    echo -e "  ${GREEN}Tests passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Tests failed: $TESTS_FAILED${NC}"
    echo -e "  ${BLUE}Total tests: $TOTAL_TESTS${NC}"
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}All tests passed! 🎉${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        return 1
    fi
}

# Main function
main() {
    # Setup test environment
    setup_test_env
    
    # Run test suite
    run_test_suite
    local test_result=$?
    
    # Cleanup test environment
    cleanup_test_env
    
    # Return test result
    return $test_result
}

# Run main function
main
exit $?
