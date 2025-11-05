#!/bin/bash

# Test suite for frecency-based bookmark sorting
# Run this script to test the frecency functionality

# Source the shared test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_framework.sh"

# Run the test suite
run_test_suite() {
    echo -e "${BLUE}Starting frecency test suite for Universal Bookmarks${NC}"
    
    # Test 1: New bookmarks have frecency fields
    run_test "New bookmarks have frecency fields" \
        "./bookmarks.sh add 'Frecency Test 1' cmd 'echo test1' && \
         jq -e '.bookmarks[0] | has(\"access_count\") and has(\"last_accessed\") and has(\"frecency_score\")' \$TEST_BOOKMARKS_FILE > /dev/null"
    
    # Test 2: New bookmarks start with zero frecency
    run_test "New bookmarks start with zero frecency" \
        "[ \$(jq -r '.bookmarks[0].frecency_score' \$TEST_BOOKMARKS_FILE) -eq 0 ]"
    
    # Test 3: Access count starts at zero
    run_test "Access count starts at zero" \
        "[ \$(jq -r '.bookmarks[0].access_count' \$TEST_BOOKMARKS_FILE) -eq 0 ]"
    
    # Test 4: Last accessed starts as null
    run_test "Last accessed starts as null" \
        "[ \$(jq -r '.bookmarks[0].last_accessed' \$TEST_BOOKMARKS_FILE) == 'null' ]"
    
    # Add more bookmarks for sorting tests
    run_test "Add multiple test bookmarks" \
        "./bookmarks.sh add 'Frecency Test 2' cmd 'echo test2' && \
         ./bookmarks.sh add 'Frecency Test 3' cmd 'echo test3'"
    
    # Test 5: Simulate bookmark access by manually updating statistics
    run_test "Manually update access statistics" \
        "jq '.bookmarks |= map(
           if .description == \"Frecency Test 2\" then 
             . + {access_count: 5, last_accessed: \"2025-10-26 23:30:00\", frecency_score: 100000}
           elif .description == \"Frecency Test 3\" then 
             . + {access_count: 2, last_accessed: \"2025-10-26 23:25:00\", frecency_score: 50000}
           else . end
         )' \$TEST_BOOKMARKS_FILE > \$TEST_BOOKMARKS_FILE.tmp && \
         mv \$TEST_BOOKMARKS_FILE.tmp \$TEST_BOOKMARKS_FILE"
    
    # Test 6: Verify sorting by frecency score
    run_test "Bookmarks sorted by frecency score" \
        "first_desc=\$(jq -r '.bookmarks | sort_by(-.frecency_score // 0) | .[0].description' \$TEST_BOOKMARKS_FILE) && \
         [ \"\$first_desc\" = 'Frecency Test 2' ]"
    
    # Test 7: Second highest frecency bookmark is correct
    run_test "Second bookmark by frecency is correct" \
        "second_desc=\$(jq -r '.bookmarks | sort_by(-.frecency_score // 0) | .[1].description' \$TEST_BOOKMARKS_FILE) && \
         [ \"\$second_desc\" = 'Frecency Test 3' ]"
    
    # Test 8: Test backward compatibility - old bookmarks get migrated
    cat > "$TEST_BOOKMARKS_FILE" <<'OLDFORMAT'
{
  "bookmarks": [
    {
      "id": "old_1",
      "description": "Old Bookmark",
      "type": "cmd",
      "command": "echo old",
      "tags": "",
      "notes": "",
      "created": "2023-01-01 00:00:00",
      "status": "active"
    }
  ]
}
OLDFORMAT
    
    run_test "Old bookmarks get migrated with frecency fields" \
        "timeout 2 bash -c './bookmarks.sh 2>&1' || true && \
         jq -e '.bookmarks[0] | has(\"access_count\") and has(\"last_accessed\") and has(\"frecency_score\")' \$TEST_BOOKMARKS_FILE > /dev/null"
    
    # Test 9: Migrated bookmarks have default values
    run_test "Migrated bookmarks have zero frecency" \
        "[ \$(jq -r '.bookmarks[0].frecency_score' \$TEST_BOOKMARKS_FILE) -eq 0 ]"
    
    # Test 10: Test frecency calculation function
    run_test "Frecency calculation produces non-zero scores" \
        "./bookmarks.sh add 'Calc Test' cmd 'echo calc' && \
         jq '.bookmarks[0] += {access_count: 3, last_accessed: \"2025-10-26 23:00:00\"}' \$TEST_BOOKMARKS_FILE > \$TEST_BOOKMARKS_FILE.tmp && \
         mv \$TEST_BOOKMARKS_FILE.tmp \$TEST_BOOKMARKS_FILE && \
         timeout 2 bash -c './bookmarks.sh 2>&1' || true && \
         score=\$(jq -r '.bookmarks[0].frecency_score' \$TEST_BOOKMARKS_FILE) && \
         [ \"\$score\" != 'null' ]"
    
    echo ""
    echo -e "${BLUE}Test summary:${NC}"
    echo -e "  ${GREEN}Tests passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Tests failed: $TESTS_FAILED${NC}"
    echo -e "  Total tests: $TOTAL_TESTS"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All frecency tests passed! 🎉${NC}"
    else
        echo -e "${RED}Some tests failed.${NC}"
    fi
    
    # Generate reports if requested
    if [ "${GENERATE_REPORTS:-false}" = "true" ]; then
        echo ""
        generate_all_reports "test_frecency"
    fi
    
    if [ $TESTS_FAILED -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Main execution
setup_test_env
run_test_suite
TEST_RESULT=$?
cleanup_test_env

exit $TEST_RESULT
