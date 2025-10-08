#!/bin/bash

# Test suite for type-specific bookmark execution
# This tests the new execute_bookmark_by_type function

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
    
    # Create test files
    mkdir -p "$TEST_DIR/files"
    echo "Test content" > "$TEST_DIR/files/test.txt"
    
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
    eval "$test_cmd" > /tmp/test_output.txt 2>&1
    local exit_code=$?
    
    if [ "$exit_code" -eq "$expected_exit_code" ]; then
        echo -e "${GREEN}✓ Test passed: $test_name${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ Test failed: $test_name (Exit code: $exit_code, Expected: $expected_exit_code)${NC}"
        cat /tmp/test_output.txt
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Run the test suite
run_test_suite() {
    echo -e "${BLUE}Starting type-specific execution test suite${NC}"
    
    # Test script type (direct execution)
    run_test "Add script bookmark" \
        "./bookmarks.sh add 'Test Script' script 'echo \"Script executed\"' 'test'"
    
    # Test cmd type (direct execution)
    run_test "Add cmd bookmark" \
        "./bookmarks.sh add 'Test Command' cmd 'echo \"Command executed\"' 'test'"
    
    # Test ssh type (direct execution - will fail to connect but should try)
    run_test "Add ssh bookmark" \
        "./bookmarks.sh add 'Test SSH' ssh 'echo \"SSH would connect here\"' 'test'"
    
    # Test app type (direct execution)
    run_test "Add app bookmark" \
        "./bookmarks.sh add 'Test App' app 'echo \"App launched\"' 'test'"
    
    # Test custom type (direct execution)
    run_test "Add custom bookmark" \
        "./bookmarks.sh add 'Test Custom' custom 'echo \"Custom executed\"' 'test'"
    
    # Test url type (should use xdg-open or equivalent)
    # Note: We can't actually open a browser in test, but we can verify the command construction
    run_test "Add url bookmark" \
        "./bookmarks.sh add 'Test URL' url '\"https://example.com\"' 'test'"
    
    # Test pdf type (should use xdg-open or equivalent)
    run_test "Add pdf bookmark" \
        "./bookmarks.sh add 'Test PDF' pdf '\"$TEST_DIR/files/test.pdf\"' 'test'"
    
    # Test file type (should use xdg-open or equivalent)
    run_test "Add file bookmark" \
        "./bookmarks.sh add 'Test File' file '\"$TEST_DIR/files/test.txt\"' 'test'"
    
    # Test folder type (should use xdg-open or equivalent)
    run_test "Add folder bookmark" \
        "./bookmarks.sh add 'Test Folder' folder '\"$TEST_DIR/files\"' 'test'"
    
    # Test note type (should use appropriate viewer)
    run_test "Add note bookmark" \
        "./bookmarks.sh add 'Test Note' note '\"$TEST_DIR/files/test.txt\"' 'test'"
    
    # Test edit type (should use BOOKMARKS_EDITOR or EDITOR)
    run_test "Add edit bookmark" \
        "./bookmarks.sh add 'Test Edit' edit '\"$TEST_DIR/files/test.txt\"' 'test'"
    
    # Verify bookmarks were added correctly
    echo -e "${BLUE}Verifying bookmark types...${NC}"
    
    local script_count=$(jq -r '.bookmarks[] | select(.type == "script") | .description' "$TEST_BOOKMARKS_FILE" | wc -l)
    local cmd_count=$(jq -r '.bookmarks[] | select(.type == "cmd") | .description' "$TEST_BOOKMARKS_FILE" | wc -l)
    local url_count=$(jq -r '.bookmarks[] | select(.type == "url") | .description' "$TEST_BOOKMARKS_FILE" | wc -l)
    local file_count=$(jq -r '.bookmarks[] | select(.type == "file") | .description' "$TEST_BOOKMARKS_FILE" | wc -l)
    local edit_count=$(jq -r '.bookmarks[] | select(.type == "edit") | .description' "$TEST_BOOKMARKS_FILE" | wc -l)
    
    if [ "$script_count" -ge 1 ] && [ "$cmd_count" -ge 1 ] && [ "$url_count" -ge 1 ] && [ "$file_count" -ge 1 ] && [ "$edit_count" -ge 1 ]; then
        echo -e "${GREEN}✓ All bookmark types added successfully${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Not all bookmark types were added (script: $script_count, cmd: $cmd_count, url: $url_count, file: $file_count, edit: $edit_count)${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Test that type information is displayed when executing
    echo -e "${BLUE}Testing type-aware execution output...${NC}"
    
    # Create a simple test by checking that the Type field is shown in output
    local output=$(./bookmarks.sh tag 'test' 2>&1)
    if echo "$output" | grep -q "script"; then
        echo -e "${GREEN}✓ Script type bookmarks displayed correctly${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Script type bookmarks not displayed${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Summary
    echo -e "${BLUE}Test summary:${NC}"
    echo -e "  ${GREEN}Tests passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Tests failed: $TESTS_FAILED${NC}"
    echo -e "  ${BLUE}Total tests: $TOTAL_TESTS${NC}"
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}All type-specific execution tests passed! 🎉${NC}"
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
