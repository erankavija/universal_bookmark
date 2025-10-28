#!/bin/bash

# Test suite for special character handling in Universal Bookmarks
# This test verifies that descriptions and notes can contain any Unicode characters

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

# Test that a bookmark with a specific description exists
test_bookmark_exists() {
    local description="$1"
    local count
    count=$(jq --arg desc "$description" '.bookmarks | map(select(.description == $desc)) | length' "$TEST_BOOKMARKS_FILE")
    [ "$count" -gt 0 ]
}

# Test that a bookmark with a specific property value exists
test_bookmark_property() {
    local description="$1"
    local property="$2"
    local expected_value="$3"
    local actual_value
    actual_value=$(jq -r --arg desc "$description" --arg prop "$property" '.bookmarks[] | select(.description == $desc) | .[$prop]' "$TEST_BOOKMARKS_FILE")
    [ "$actual_value" = "$expected_value" ]
}

# Run the test suite
run_test_suite() {
    echo -e "${BLUE}Starting special character test suite for Universal Bookmarks${NC}"
    echo ""
    
    # Test 1: Add bookmark with underscore in description
    echo -e "${BLUE}=== Test 1: Underscore in description ===${NC}"
    run_test "Add bookmark with underscore" \
        "./bookmarks.sh add 'Test_with_underscore' url 'https://example.com'"
    
    if test_bookmark_exists "Test_with_underscore"; then
        echo -e "${GREEN}✓ Bookmark with underscore was added successfully${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Bookmark with underscore was not added${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Test 2: Delete bookmark with underscore
    run_test "Delete bookmark with underscore" \
        "./bookmarks.sh -y delete 'Test_with_underscore'"
    
    if ! test_bookmark_exists "Test_with_underscore"; then
        echo -e "${GREEN}✓ Bookmark with underscore was deleted successfully${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Bookmark with underscore was not deleted${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
    
    # Test 3: Add bookmark with emoji in description
    echo -e "${BLUE}=== Test 2: Emoji in description ===${NC}"
    run_test "Add bookmark with emoji" \
        "./bookmarks.sh add 'Test with emoji 😀 🎉' cmd 'echo hello'"
    
    if test_bookmark_exists "Test with emoji 😀 🎉"; then
        echo -e "${GREEN}✓ Bookmark with emoji was added successfully${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Bookmark with emoji was not added${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Test 4: Mark obsolete bookmark with emoji
    run_test "Mark obsolete bookmark with emoji" \
        "./bookmarks.sh -y obsolete 'Test with emoji 😀 🎉'"
    
    if test_bookmark_property "Test with emoji 😀 🎉" "status" "obsolete"; then
        echo -e "${GREEN}✓ Bookmark with emoji was marked obsolete${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Bookmark with emoji was not marked obsolete${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
    
    # Test 5: Add bookmark with accented characters
    echo -e "${BLUE}=== Test 3: Accented characters ===${NC}"
    run_test "Add bookmark with accented chars" \
        "./bookmarks.sh add 'Café résumé naïve' cmd 'echo test' 'tag' 'Notes: José María'"
    
    if test_bookmark_exists "Café résumé naïve"; then
        echo -e "${GREEN}✓ Bookmark with accented characters was added${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Bookmark with accented characters was not added${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Test 6: Update bookmark with accented characters
    run_test "Update bookmark with accented chars" \
        "./bookmarks.sh update 'Café résumé naïve' cmd 'echo updated' 'newtag' 'New notes: ñoño'"
    
    if test_bookmark_property "Café résumé naïve" "notes" "New notes: ñoño"; then
        echo -e "${GREEN}✓ Bookmark with accented characters was updated${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Bookmark with accented characters was not updated correctly${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
    
    # Test 7: Add bookmark with CJK characters
    echo -e "${BLUE}=== Test 4: CJK characters ===${NC}"
    run_test "Add bookmark with CJK chars" \
        "./bookmarks.sh add '日本語 中文 한글' cmd 'echo hello' 'tag' '你好世界'"
    
    if test_bookmark_exists "日本語 中文 한글"; then
        echo -e "${GREEN}✓ Bookmark with CJK characters was added${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Bookmark with CJK characters was not added${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
    
    # Test 8: Add bookmark with Arabic characters
    echo -e "${BLUE}=== Test 5: Arabic characters ===${NC}"
    run_test "Add bookmark with Arabic chars" \
        "./bookmarks.sh add 'مرحبا بكم' cmd 'echo test' 'tag' 'Arabic: مرحبا'"
    
    if test_bookmark_exists "مرحبا بكم"; then
        echo -e "${GREEN}✓ Bookmark with Arabic characters was added${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Bookmark with Arabic characters was not added${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
    
    # Test 9: Add bookmark with multiple underscores
    echo -e "${BLUE}=== Test 6: Multiple underscores ===${NC}"
    run_test "Add bookmark with multiple underscores" \
        "./bookmarks.sh add 'test_multiple_underscores_here' cmd 'echo test'"
    
    if test_bookmark_exists "test_multiple_underscores_here"; then
        echo -e "${GREEN}✓ Bookmark with multiple underscores was added${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Bookmark with multiple underscores was not added${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Test 10: Delete bookmark with multiple underscores
    run_test "Delete bookmark with multiple underscores" \
        "./bookmarks.sh -y delete 'test_multiple_underscores_here'"
    
    if ! test_bookmark_exists "test_multiple_underscores_here"; then
        echo -e "${GREEN}✓ Bookmark with multiple underscores was deleted${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Bookmark with multiple underscores was not deleted${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
    
    # Test 11: Combined special characters
    echo -e "${BLUE}=== Test 7: Combined special characters ===${NC}"
    run_test "Add bookmark with combined special chars" \
        "./bookmarks.sh add 'Mix_of_everything: 😀 café 你好 مرحبا' cmd 'echo test' 'tag1 tag2' 'Notes: all_types_here é 🎉'"
    
    if test_bookmark_exists "Mix_of_everything: 😀 café 你好 مرحبا"; then
        echo -e "${GREEN}✓ Bookmark with combined special characters was added${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Bookmark with combined special characters was not added${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Test 12: Update with combined special characters
    run_test "Update bookmark with combined special chars" \
        "./bookmarks.sh update 'Mix_of_everything: 😀 café 你好 مرحبا' cmd 'echo updated' 'new_tag' 'Updated: special_chars 🌟'"
    
    if test_bookmark_property "Mix_of_everything: 😀 café 你好 مرحبا" "notes" "Updated: special_chars 🌟"; then
        echo -e "${GREEN}✓ Bookmark with combined special characters was updated${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Bookmark with combined special characters was not updated correctly${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
    
    # Test 13: Verify ID-based operations still work
    echo -e "${BLUE}=== Test 8: ID-based operations ===${NC}"
    local test_id
    test_id=$(jq -r '.bookmarks[0].id' "$TEST_BOOKMARKS_FILE")
    
    if [[ -n "$test_id" ]] && [[ "$test_id" != "null" ]]; then
        run_test "Delete bookmark by ID" \
            "./bookmarks.sh -y delete '$test_id'"
        
        # Check if bookmark was deleted
        local count
        count=$(jq --arg id "$test_id" '.bookmarks | map(select(.id == $id)) | length' "$TEST_BOOKMARKS_FILE")
        if [ "$count" -eq 0 ]; then
            echo -e "${GREEN}✓ Bookmark was deleted by ID successfully${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗ Bookmark was not deleted by ID${NC}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    else
        echo -e "${YELLOW}⚠ Skipping ID-based test (no bookmarks available)${NC}"
    fi
    echo ""
    
    # Test 14: Verify that actual IDs are still recognized
    echo -e "${BLUE}=== Test 9: Real ID detection ===${NC}"
    run_test "Add bookmark to get real ID" \
        "./bookmarks.sh add 'Test for ID' cmd 'echo test'"
    
    local real_id
    real_id=$(jq -r '.bookmarks[] | select(.description == "Test for ID") | .id' "$TEST_BOOKMARKS_FILE")
    
    if [[ "$real_id" =~ ^[0-9]{10}_[a-zA-Z0-9]{6}$ ]]; then
        echo -e "${GREEN}✓ Real ID format is correct: $real_id${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        
        # Try to delete by ID
        run_test "Delete by real ID" \
            "./bookmarks.sh -y delete '$real_id'"
        
        if ! test_bookmark_exists "Test for ID"; then
            echo -e "${GREEN}✓ Bookmark was deleted using real ID${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗ Bookmark was not deleted using real ID${NC}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    else
        echo -e "${RED}✗ ID format is incorrect: $real_id${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
    
    # Print summary
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Test Summary:${NC}"
    echo -e "  ${GREEN}Tests passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Tests failed: $TESTS_FAILED${NC}"
    echo -e "  Total tests: $TOTAL_TESTS"
    echo -e "${BLUE}========================================${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        return 1
    fi
}

# Main execution
setup_test_env
run_test_suite
test_result=$?
cleanup_test_env
exit $test_result
