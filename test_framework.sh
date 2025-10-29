#!/bin/bash

# Shared test framework for Universal Bookmarks
# This file provides common test functions used across all test suites

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
# This function creates a temporary test directory and initializes the bookmarks file
setup_test_env() {
    echo -e "${BLUE}Setting up test environment...${NC}"
    
    # Create temporary test directory
    TEST_DIR=$(mktemp -d)
    TEST_BOOKMARKS_FILE="$TEST_DIR/bookmarks.json"
    
    # Initialize bookmarks file
    echo '{"bookmarks":[]}' > "$TEST_BOOKMARKS_FILE"
    
    # Save original BOOKMARKS_DIR (handle empty case)
    ORIG_BOOKMARKS_DIR="${BOOKMARKS_DIR:-}"
    
    # Set BOOKMARKS_DIR to test directory
    export BOOKMARKS_DIR="$TEST_DIR"
    
    # Save original EDITOR (handle empty case)
    ORIG_EDITOR="${EDITOR:-}"
    
    echo -e "${GREEN}Test environment set up at $TEST_DIR${NC}"
}

# Cleanup test environment
# This function restores the original environment and removes temporary files
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
# Args: $1 - test name, $2 - test command, $3 - expected exit code (default: 0)
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
