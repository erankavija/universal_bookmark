#!/bin/bash

# Demo test suite to showcase enhanced test output features
# This demonstrates timing, progress indicators, slow test warnings, and failure hints

# Source the shared test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_framework.sh"

# Override the TOTAL_TESTS to show proper progress from the start
TOTAL_TESTS=10

# Run demo test suite
run_demo_suite() {
    echo -e "${BLUE}Demo Test Suite - Enhanced Output Features${NC}"
    echo ""
    
    # Fast passing test
    run_test "Fast passing test" \
        "sleep 0.1 && exit 0"
    
    # Another fast test
    run_test "Quick validation test" \
        "[ 1 -eq 1 ]"
    
    # Slow test (>1 second)
    run_test "Slow database query simulation" \
        "sleep 1.5 && exit 0"
    
    # Another slow test
    run_test "Long-running integration test" \
        "sleep 2 && exit 0"
    
    # Fast test
    run_test "Unit test for core functionality" \
        "sleep 0.2 && exit 0"
    
    # Failing test - wrong exit code
    run_test "Invalid input handling" \
        "echo 'Processing invalid input...' && exit 0" \
        1
    
    # Command not found test
    run_test "Missing command test" \
        "nonexistent_command_xyz123" \
        127
    
    # Another passing test
    run_test "Configuration validation" \
        "sleep 0.3 && exit 0"
    
    # Test with expected failure
    run_test "Error handling test" \
        "echo 'Error condition' && exit 1" \
        1
    
    # Final passing test
    run_test "Cleanup and finalization" \
        "sleep 0.1 && exit 0"
    
    # Summary
    echo ""
    echo -e "${BLUE}Demo Test Summary:${NC}"
    echo -e "  ${GREEN}Tests passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Tests failed: $TESTS_FAILED${NC}"
    echo -e "  ${BLUE}Total tests: $TOTAL_TESTS${NC}"
    
    # Generate reports
    if [ "${GENERATE_REPORTS:-false}" = "true" ]; then
        echo ""
        generate_all_reports "demo_enhanced"
    fi
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Main execution
setup_test_env
run_demo_suite
test_result=$?
cleanup_test_env

exit $test_result
