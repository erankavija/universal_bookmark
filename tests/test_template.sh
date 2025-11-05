#!/bin/bash

# Test suite for [Feature Name]
# Run this script to test [description of what this test suite covers]

# Source the shared test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_framework.sh"

# Run the test suite
run_test_suite() {
    echo -e "${BLUE}Starting [feature name] test suite for Universal Bookmarks${NC}"
    
    # Test 1: Basic functionality test
    # Description: [What this test verifies]
    run_test "Basic functionality test name" \
        "../bookmarks.sh command 'args'"
    
    # Test 2: Success case with validation
    # Description: [What this test verifies]
    run_test "Test name describing what is verified" \
        "../bookmarks.sh add 'Test Bookmark' type 'command' && \
         jq -e '.bookmarks[] | select(.description == \"Test Bookmark\")' \$TEST_BOOKMARKS_FILE > /dev/null"
    
    # Test 3: Failure case (expecting non-zero exit code)
    # Description: [What failure condition this test verifies]
    run_test "Test name for expected failure" \
        "../bookmarks.sh command_that_should_fail 'invalid'" \
        1  # Expected exit code 1 (failure)
    
    # Test 4: JSON validation
    # Description: [What JSON structure or field this test verifies]
    run_test "JSON structure validation" \
        "jq -e '.bookmarks[0] | has(\"id\") and has(\"description\") and has(\"type\")' \
         \$TEST_BOOKMARKS_FILE > /dev/null"
    
    # Test 5: Output format validation
    # Description: [What output format this test verifies]
    run_test "Output format test" \
        "../bookmarks.sh list | grep -qE 'expected pattern'"
    
    # Test 6: Multiple commands in sequence
    # Description: [What workflow or sequence this test verifies]
    run_test "Multi-step workflow test" \
        "../bookmarks.sh add 'First' cmd 'echo 1' && \
         ../bookmarks.sh add 'Second' cmd 'echo 2' && \
         [ \$(jq -r '.bookmarks | length' \$TEST_BOOKMARKS_FILE) -eq 2 ]"
    
    # Test 7: Edge case
    # Description: [What edge case this test covers]
    run_test "Edge case test name" \
        "../bookmarks.sh command_with_edge_case"
    
    # Test 8: Cleanup or state verification
    # Description: [What state change this test verifies]
    run_test "State verification test" \
        "../bookmarks.sh -y delete 'Test Bookmark' && \
         ! jq -e '.bookmarks[] | select(.description == \"Test Bookmark\")' \
           \$TEST_BOOKMARKS_FILE > /dev/null"
    
    # Print test summary
    echo ""
    echo -e "${BLUE}Test summary:${NC}"
    echo -e "  ${GREEN}Tests passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Tests failed: $TESTS_FAILED${NC}"
    echo -e "  Total tests: $TOTAL_TESTS"
    
    # Return appropriate exit code
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All [feature name] tests passed! 🎉${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        return 1
    fi
}

# Main execution
# This pattern ensures cleanup happens even if tests fail
setup_test_env
run_test_suite
TEST_RESULT=$?
cleanup_test_env

exit $TEST_RESULT

# ==============================================================================
# TEMPLATE USAGE GUIDE
# ==============================================================================
#
# 1. Copy this template to create a new test file:
#    cp test_template.sh test_myfeature.sh
#
# 2. Replace placeholders:
#    - [Feature Name] - Name of the feature being tested
#    - [description] - Brief description of test coverage
#    - [feature name] - Lowercase feature name for messages
#
# 3. Write your tests:
#    - Use run_test() for each test case
#    - Include descriptive test names
#    - Test both success and failure cases
#    - Verify state changes, not just command execution
#
# 4. Make the file executable:
#    chmod +x test_myfeature.sh
#
# 5. Add to run_tests.sh TEST_FILES array
#
# 6. Update .github/workflows/test.yml to include the new test
#
# ==============================================================================
# COMMON TEST PATTERNS
# ==============================================================================
#
# Pattern 1: Simple command test
# --------------------------------
# run_test "Add bookmark" \
#     "../bookmarks.sh add 'Test' url 'https://example.com'"
#
# Pattern 2: Test with validation
# --------------------------------
# run_test "Bookmark was added" \
#     "../bookmarks.sh add 'Test' url 'https://example.com' && \
#      ../bookmarks.sh list | grep -q 'Test'"
#
# Pattern 3: Test expected failure
# --------------------------------
# run_test "Invalid type rejected" \
#     "../bookmarks.sh add 'Test' invalid_type 'cmd'" \
#     1  # Expected exit code 1
#
# Pattern 4: JSON field validation
# --------------------------------
# run_test "Bookmark has ID field" \
#     "jq -e '.bookmarks[0] | has(\"id\")' \$TEST_BOOKMARKS_FILE > /dev/null"
#
# Pattern 5: Count validation
# --------------------------------
# run_test "Correct number of bookmarks" \
#     "[ \$(jq -r '.bookmarks | length' \$TEST_BOOKMARKS_FILE) -eq 3 ]"
#
# Pattern 6: String comparison
# --------------------------------
# run_test "Bookmark description matches" \
#     "desc=\$(jq -r '.bookmarks[0].description' \$TEST_BOOKMARKS_FILE) && \
#      [ \"\$desc\" = 'Expected Description' ]"
#
# Pattern 7: Verify deletion
# --------------------------------
# run_test "Bookmark deleted successfully" \
#     "../bookmarks.sh -y delete 'Test' && \
#      ! jq -e '.bookmarks[] | select(.description == \"Test\")' \
#        \$TEST_BOOKMARKS_FILE > /dev/null"
#
# Pattern 8: Output format check
# --------------------------------
# run_test "Output has correct format" \
#     "../bookmarks.sh list | grep -qE '^\[[a-z]+\] .+ \| .+'"
#
# Pattern 9: Multiple operations
# --------------------------------
# run_test "Add, update, verify workflow" \
#     "../bookmarks.sh add 'Test' cmd 'echo 1' && \
#      ../bookmarks.sh update 'Test' cmd 'echo 2' && \
#      cmd=\$(jq -r '.bookmarks[0].command' \$TEST_BOOKMARKS_FILE) && \
#      [ \"\$cmd\" = 'echo 2' ]"
#
# Pattern 10: Silent command (clean output)
# --------------------------------
# run_test "Background operation" \
#     "../bookmarks.sh add 'Silent' cmd 'echo test' > /dev/null 2>&1 && \
#      ../bookmarks.sh list | grep -q 'Silent'"
#
# ==============================================================================
# BEST PRACTICES
# ==============================================================================
#
# 1. Test Isolation
#    - Each test should be independent
#    - Don't rely on state from previous tests
#    - Create necessary data within the test
#
# 2. Non-Interactive Mode
#    - Always use -y flag for confirmation prompts
#    - Use timeout for potentially blocking commands
#
# 3. Descriptive Names
#    - Use clear, descriptive test names
#    - Name should indicate what is being tested
#    - Be specific about the expected behavior
#
# 4. Test Both Success and Failure
#    - Include positive and negative test cases
#    - Verify error handling
#    - Test edge cases and boundary conditions
#
# 5. Verify State Changes
#    - Don't just run commands, verify their effects
#    - Check JSON file contents
#    - Validate output format and content
#
# 6. Clean Output
#    - Redirect output when not needed (> /dev/null 2>&1)
#    - Only show output that helps with debugging
#    - Keep test output focused and readable
#
# 7. Use Variables for Clarity
#    - Extract complex jq queries to variables
#    - Make test logic clear and readable
#    - Document complex test conditions
#
# 8. Handle Temporary Data
#    - Use $TEST_DIR for temporary files
#    - Clean up within the test if creating extra files
#    - Let cleanup_test_env handle the main cleanup
#
# ==============================================================================
