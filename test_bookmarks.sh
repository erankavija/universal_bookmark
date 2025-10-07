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
        "./bookmarks.sh -y obsolete 'Test Script'"
    
    # Test backup creation
    run_test "Create backup" \
        "./bookmarks.sh -y backup"
    
    # Test deleting a bookmark
    run_test "Delete a bookmark" \
        "./bookmarks.sh -y delete 'Test URL'"
    
    # Test jq command extraction with fzf filter
    echo -e "${BLUE}Testing jq command extraction with fzf filter...${NC}"
    run_test "Add test bookmarks for jq extraction" \
        "./bookmarks.sh add 'List Files' script 'ls -la' 'test,files' 'List all files' && \
         ./bookmarks.sh add 'Echo Test' script 'echo \"Hello World\"' 'test,echo' 'Echo test message'"
    
    # Test formatting bookmarks for fzf
    run_test "Format bookmarks for fzf display" \
        "jq -r '.bookmarks[] | if .status == \"obsolete\" then \"[OBSOLETE] \" else \"\" end + \"[\" + .type + \"] \" + .description' \"$TEST_BOOKMARKS_FILE\" | grep -q '\[script\] List Files'"
    
    # Test extracting command using jq from a formatted line
    echo -e "${BLUE}Testing command extraction from fzf-like output...${NC}"
    
    # Simulate what happens when fzf filters a line
    # 1. Format the line like fzf displays it
    local formatted_line="[script] List Files"
    
    # 2. Extract description (removing ANSI codes and format markers)
    local extracted_desc=$(echo "$formatted_line" | sed -E 's/^\[OBSOLETE\] \[(.*)\] (.*)/\2/' | sed -E 's/^\[(.*)\] (.*)/\2/')
    
    # 3. Use jq to get the command from the description
    local extracted_cmd=$(jq -r --arg desc "$extracted_desc" '.bookmarks[] | select(.description == $desc) | .command' "$TEST_BOOKMARKS_FILE")
    
    # 4. Verify the command is correct
    if [ "$extracted_cmd" = "ls -la" ]; then
        echo -e "${GREEN}✓ Test passed: Extract command from formatted line${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    else
        echo -e "${RED}✗ Test failed: Expected 'ls -la', got '$extracted_cmd'${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    fi
    
    # Test with OBSOLETE marker
    run_test "Mark bookmark as obsolete for jq test" \
        "./bookmarks.sh -y obsolete 'List Files'"
    
    # Test extraction with obsolete bookmark
    local obsolete_formatted_line="[OBSOLETE] [script] List Files"
    local obsolete_extracted_desc=$(echo "$obsolete_formatted_line" | sed -E 's/\x1B\[[0-9;]*[mK]//g' | sed -E 's/^\[OBSOLETE\] \[(.*)\] (.*)/\2/')
    local obsolete_extracted_cmd=$(jq -r --arg desc "$obsolete_extracted_desc" '.bookmarks[] | select(.description == $desc) | .command' "$TEST_BOOKMARKS_FILE")
    
    if [ "$obsolete_extracted_cmd" = "ls -la" ]; then
        echo -e "${GREEN}✓ Test passed: Extract command from obsolete formatted line${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    else
        echo -e "${RED}✗ Test failed: Expected 'ls -la', got '$obsolete_extracted_cmd'${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    fi
    
    # Test fzf filter mode (non-interactive)
    echo -e "${BLUE}Testing fzf filter mode for bookmark search...${NC}"
    local fzf_result=$(jq -r '.bookmarks[] | if .status == "obsolete" then "[OBSOLETE] " else "" end + "[" + .type + "] " + .description' "$TEST_BOOKMARKS_FILE" | fzf --ansi --filter="Echo Test" | head -1)
    
    if echo "$fzf_result" | grep -q "Echo Test"; then
        echo -e "${GREEN}✓ Test passed: fzf filter search${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    else
        echo -e "${RED}✗ Test failed: fzf filter did not find 'Echo Test'${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    fi
    
    # Test interactive add mode
    echo -e "${BLUE}Testing interactive add mode...${NC}"
    # Simulate interactive input using a here-doc
    {
        echo "Interactive Test Bookmark"
        echo "url"
        echo "echo 'Interactive test'"
        echo "interactive test"
        echo "This is an interactive test"
    } | ./bookmarks.sh add > /dev/null 2>&1
    
    # Verify the bookmark was added
    local interactive_bookmark=$(jq -r '.bookmarks[] | select(.description == "Interactive Test Bookmark") | .command' "$TEST_BOOKMARKS_FILE")
    
    if [ "$interactive_bookmark" = "echo 'Interactive test'" ]; then
        echo -e "${GREEN}✓ Test passed: Interactive add mode${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    else
        echo -e "${RED}✗ Test failed: Interactive add mode did not add bookmark correctly${NC}"
        echo -e "  Expected: echo 'Interactive test'"
        echo -e "  Got: $interactive_bookmark"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    fi
    
    # Test interactive add with custom type confirmation
    echo -e "${BLUE}Testing interactive add mode with custom type (auto-confirmed)...${NC}"
    {
        echo "Custom Type Test"
        echo "customtype"
        echo "y"
        echo "echo 'Custom type test'"
        echo ""
        echo ""
    } | ./bookmarks.sh add > /dev/null 2>&1
    
    # Verify the bookmark was added with custom type
    local custom_type_bookmark=$(jq -r '.bookmarks[] | select(.description == "Custom Type Test") | .type' "$TEST_BOOKMARKS_FILE")
    
    if [ "$custom_type_bookmark" = "customtype" ]; then
        echo -e "${GREEN}✓ Test passed: Interactive add with custom type${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    else
        echo -e "${RED}✗ Test failed: Interactive add with custom type did not work correctly${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    fi
    
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
