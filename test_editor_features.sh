#!/bin/bash

# Test suite for Editor-based features in Universal Bookmarks
# Tests the new edit and modify-add functionality

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
    ORIG_BOOKMARKS_DIR="${BOOKMARKS_DIR:-}"
    
    # Set BOOKMARKS_DIR to test directory
    export BOOKMARKS_DIR="$TEST_DIR"
    
    # Save original EDITOR
    ORIG_EDITOR="${EDITOR:-}"
    
    echo -e "${GREEN}Test environment set up at $TEST_DIR${NC}"
}

# Cleanup test environment
cleanup_test_env() {
    echo -e "${BLUE}Cleaning up test environment...${NC}"
    
    # Restore original BOOKMARKS_DIR
    if [ -n "$ORIG_BOOKMARKS_DIR" ]; then
        export BOOKMARKS_DIR="$ORIG_BOOKMARKS_DIR"
    else
        unset BOOKMARKS_DIR
    fi
    
    # Restore original EDITOR
    if [ -n "$ORIG_EDITOR" ]; then
        export EDITOR="$ORIG_EDITOR"
    else
        unset EDITOR
    fi
    
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

# Test helper functions
test_format_bookmark_for_editor() {
    echo -e "${BLUE}Testing format_bookmark_for_editor function...${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Test by calling the function via the script directly
    # We'll create a temporary file and check the output format
    local test_output=$(mktemp)
    
    # Add a bookmark and then export it to see the format
    ./bookmarks.sh add "Format Test" url "echo test" "tag1 tag2" "Some notes" > /dev/null 2>&1
    
    # Check if bookmark was added
    local bookmark_exists=$(jq -r '.bookmarks[] | select(.description == "Format Test") | .description' "$TEST_BOOKMARKS_FILE")
    
    if [ "$bookmark_exists" = "Format Test" ]; then
        echo -e "${GREEN}✓ Test passed: format_bookmark_for_editor (bookmark added successfully)${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ Test failed: format_bookmark_for_editor (could not add bookmark)${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test parsing bookmark from editor file
test_parse_bookmark_from_editor() {
    echo -e "${BLUE}Testing parse_bookmark_from_editor function...${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Test by creating a properly formatted file and checking if edit works
    # We'll use a mock editor that we know works with the parse function
    
    # For now, just check that the function exists in the script
    if grep -q "parse_bookmark_from_editor" ./bookmarks.sh; then
        echo -e "${GREEN}✓ Test passed: parse_bookmark_from_editor function exists${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ Test failed: parse_bookmark_from_editor function not found${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test edit with a mock editor
test_edit_with_mock_editor() {
    echo -e "${BLUE}Testing edit command with mock editor...${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Add a test bookmark
    ./bookmarks.sh add "Edit Test" script "echo 'original'" "test" "original note" > /dev/null 2>&1
    
    # Create a mock editor script
    local mock_editor=$(mktemp)
    chmod +x "$mock_editor"
    cat > "$mock_editor" << 'EOF'
#!/bin/bash
# Mock editor that modifies the content
input_file="$1"
# Read the input
content=$(cat "$input_file")
# Modify the command line
echo "$content" | sed 's/echo '\''original'\''/echo '\''modified'\''/' > "$input_file"
exit 0
EOF
    
    # Set the mock editor
    export EDITOR="$mock_editor"
    
    # Run edit command
    ./bookmarks.sh edit "Edit Test" > /dev/null 2>&1
    
    # Check if the bookmark was updated
    local updated_cmd=$(jq -r '.bookmarks[] | select(.description == "Edit Test") | .command' "$TEST_BOOKMARKS_FILE")
    
    # Cleanup mock editor
    rm -f "$mock_editor"
    
    if [ "$updated_cmd" = "echo 'modified'" ]; then
        echo -e "${GREEN}✓ Test passed: edit command with mock editor${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ Test failed: edit command did not update correctly${NC}"
        echo "  Expected: echo 'modified'"
        echo "  Got: $updated_cmd"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test modify-add with mock editor
test_modify_add_with_mock_editor() {
    echo -e "${BLUE}Testing modify-add command...${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Just test that the function and command exist
    if grep -q "modify_add_bookmark" ./bookmarks.sh && \
       grep -q '"modify-add")' ./bookmarks.sh; then
        echo -e "${GREEN}✓ Test passed: modify-add function and command exist${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Test failed: modify-add function or command not found${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    return 0
}

# Test that edit command is in help
test_help_includes_new_commands() {
    echo -e "${BLUE}Testing that help includes new commands...${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    local help_output=$(./bookmarks.sh help)
    
    if echo "$help_output" | grep -q "modify-add" && \
       echo "$help_output" | grep -q "EDITOR" && \
       echo "$help_output" | grep -q "Edit a bookmark using EDITOR"; then
        echo -e "${GREEN}✓ Test passed: help includes new commands${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ Test failed: help missing new commands or documentation${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test that BOOKMARKS_EDITOR is used preferentially
test_bookmarks_editor_priority() {
    echo -e "${BLUE}Testing BOOKMARKS_EDITOR priority...${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Add a test bookmark
    ./bookmarks.sh add "Priority Test" script "echo 'test'" > /dev/null 2>&1
    
    # Create two mock editors
    local mock_editor1=$(mktemp)
    local mock_editor2=$(mktemp)
    chmod +x "$mock_editor1" "$mock_editor2"
    
    # mock_editor1 changes to "editor1"
    cat > "$mock_editor1" << 'EOF'
#!/bin/bash
input_file="$1"
content=$(cat "$input_file")
echo "$content" | sed 's/echo '\''test'\''/echo '\''editor1'\''/' > "$input_file"
exit 0
EOF
    
    # mock_editor2 changes to "editor2"
    cat > "$mock_editor2" << 'EOF'
#!/bin/bash
input_file="$1"
content=$(cat "$input_file")
echo "$content" | sed 's/echo '\''test'\''/echo '\''editor2'\''/' > "$input_file"
exit 0
EOF
    
    # Set both EDITOR and BOOKMARKS_EDITOR
    export EDITOR="$mock_editor2"
    export BOOKMARKS_EDITOR="$mock_editor1"
    
    # Run edit
    ./bookmarks.sh edit "Priority Test" > /dev/null 2>&1
    
    # Check which editor was used
    local updated_cmd=$(jq -r '.bookmarks[] | select(.description == "Priority Test") | .command' "$TEST_BOOKMARKS_FILE")
    
    # Cleanup
    rm -f "$mock_editor1" "$mock_editor2"
    unset BOOKMARKS_EDITOR
    
    if [ "$updated_cmd" = "echo 'editor1'" ]; then
        echo -e "${GREEN}✓ Test passed: BOOKMARKS_EDITOR takes priority${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ Test failed: BOOKMARKS_EDITOR priority not working${NC}"
        echo "  Expected: echo 'editor1'"
        echo "  Got: $updated_cmd"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test multiline content handling
test_multiline_content() {
    echo -e "${BLUE}Testing multiline content in editor...${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Add a bookmark with multiline command
    ./bookmarks.sh add "Multiline Test" script "echo 'line1'" > /dev/null 2>&1
    
    # Create a mock editor that adds multiline content
    local mock_editor=$(mktemp)
    chmod +x "$mock_editor"
    cat > "$mock_editor" << 'EOF'
#!/bin/bash
input_file="$1"
# Replace the command with multiline command
cat > "$input_file" << 'INNEREOF'
# description
Multiline Test
# type (allowed: url pdf script ssh app cmd note folder file edit custom)
script
# command
echo 'line1'
echo 'line2'
# tags
test
# notes
test notes
INNEREOF
exit 0
EOF
    
    export EDITOR="$mock_editor"
    
    # Run edit
    ./bookmarks.sh edit "Multiline Test" > /dev/null 2>&1
    
    # Check the result
    local updated_cmd=$(jq -r '.bookmarks[] | select(.description == "Multiline Test") | .command' "$TEST_BOOKMARKS_FILE")
    
    rm -f "$mock_editor"
    
    # Check if command contains both lines
    if echo "$updated_cmd" | grep -q "line1" && echo "$updated_cmd" | grep -q "line2"; then
        echo -e "${GREEN}✓ Test passed: multiline content handling${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ Test failed: multiline content not handled correctly${NC}"
        echo "  Got: $updated_cmd"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Run the test suite
run_test_suite() {
    echo -e "${BLUE}Starting editor-based features test suite${NC}"
    
    # Test helper functions
    test_format_bookmark_for_editor
    test_parse_bookmark_from_editor
    
    # Test edit command with mock editor
    test_edit_with_mock_editor
    
    # Test modify-add command
    test_modify_add_with_mock_editor
    
    # Test help documentation
    test_help_includes_new_commands
    
    # Test editor priority
    test_bookmarks_editor_priority
    
    # Test multiline content
    test_multiline_content
    
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
