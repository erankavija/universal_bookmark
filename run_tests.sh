#!/bin/bash

#=============================================================================
# Universal Bookmarks - Test Runner
# 
# Convenience script to run all test suites with aggregated reporting.
# This script runs all test files and provides a summary of results.
#=============================================================================

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Test files to run (in order)
TEST_FILES=(
    "test_framework.sh"
    "test_bookmarks.sh"
    "test_frecency.sh"
    "test_editor_features.sh"
    "test_special_chars.sh"
    "test_type_execution.sh"
    "test_composable_filters.sh"
    "test_precommit_hooks.sh"
)

# Global counters
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
SKIPPED_SUITES=0

# Results storage
declare -a SUITE_RESULTS
declare -a SUITE_NAMES
declare -a SUITE_TIMES

# Function to print usage
print_usage() {
    cat << EOF
${BOLD}Universal Bookmarks Test Runner${NC}

${BOLD}USAGE:${NC}
    $0 [OPTIONS] [TEST_PATTERN]

${BOLD}OPTIONS:${NC}
    -h, --help          Show this help message
    -v, --verbose       Show detailed test output
    -q, --quiet         Show only summary
    -f, --fail-fast     Stop on first test failure
    -l, --list          List available test suites
    -c, --coverage      Run tests with code coverage collection (requires kcov)
    --hook              Run in git hook mode (quiet + fail-fast, minimal output)
    --parallel          Run tests in parallel (not yet implemented)
    
${BOLD}TEST_PATTERN:${NC}
    Optional pattern to filter test files (e.g., 'frecency' or 'bookmarks')
    
${BOLD}EXAMPLES:${NC}
    $0                  # Run all tests
    $0 -v               # Run all tests with verbose output
    $0 frecency         # Run only frecency tests
    $0 -f bookmarks     # Run bookmark tests, stop on first failure
    $0 --coverage       # Run all tests with coverage collection

${BOLD}ENVIRONMENT:${NC}
    Set FZF_PATH if fzf is not in your PATH:
        export FZF_PATH=/path/to/fzf/bin
        $0

EOF
}

# Function to list test suites
list_test_suites() {
    echo -e "${BOLD}Available test suites:${NC}"
    echo ""
    for test_file in "${TEST_FILES[@]}"; do
        if [ -f "$SCRIPT_DIR/$test_file" ]; then
            local description=$(head -5 "$SCRIPT_DIR/$test_file" | grep -m1 "^# " | sed 's/^# //')
            echo -e "  ${CYAN}$test_file${NC}"
            if [ -n "$description" ]; then
                echo -e "    $description"
            fi
        fi
    done
    echo ""
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for fzf (with custom path support)
    if [ -n "${FZF_PATH:-}" ]; then
        export PATH="$FZF_PATH:$PATH"
    fi
    
    if ! command -v fzf &> /dev/null; then
        missing_deps+=("fzf")
    fi
    
    # Check for jq (used by the test scripts themselves)
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required dependencies:${NC}" >&2
        for dep in "${missing_deps[@]}"; do
            echo -e "  - $dep" >&2
        done
        echo ""
        echo -e "${YELLOW}Install instructions:${NC}"
        echo "  jq:  https://stedolan.github.io/jq/download/"
        echo "  fzf: https://github.com/junegunn/fzf#installation"
        return 1
    fi
    
    return 0
}

# Function to run a single test suite
run_test_suite() {
    local test_file="$1"
    local verbose="${2:-false}"
    local test_path="$SCRIPT_DIR/$test_file"
    
    if [ ! -f "$test_path" ]; then
        echo -e "${YELLOW}⚠ Test file not found: $test_file${NC}"
        return 2
    fi
    
    if [ ! -x "$test_path" ]; then
        chmod +x "$test_path"
    fi
    
    TOTAL_SUITES=$((TOTAL_SUITES + 1))
    
    local suite_name="${test_file%.sh}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Running test suite: ${CYAN}$suite_name${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    local start_time=$(date +%s)
    local output
    local exit_code
    
    if [ "$verbose" = "true" ]; then
        "$test_path"
        exit_code=$?
    else
        output=$("$test_path" 2>&1)
        exit_code=$?
        # Show summary line from output
        echo "$output" | grep -E "(Test summary:|Tests passed:|Tests failed:|All tests passed)" || true
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Store results
    SUITE_NAMES+=("$suite_name")
    SUITE_TIMES+=("$duration")
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ Test suite passed${NC} (${duration}s)"
        PASSED_SUITES=$((PASSED_SUITES + 1))
        SUITE_RESULTS+=("PASS")
    else
        echo -e "${RED}✗ Test suite failed${NC} (${duration}s)"
        FAILED_SUITES=$((FAILED_SUITES + 1))
        SUITE_RESULTS+=("FAIL")
        
        if [ "$verbose" = "false" ]; then
            echo ""
            echo -e "${YELLOW}Failed test output:${NC}"
            echo "$output"
        fi
    fi
    
    echo ""
    return $exit_code
}

# Function to print summary
print_summary() {
    local total_time=0
    for time in "${SUITE_TIMES[@]}"; do
        total_time=$((total_time + time))
    done
    
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}TEST SUITE SUMMARY${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Print individual suite results
    for i in "${!SUITE_NAMES[@]}"; do
        local name="${SUITE_NAMES[$i]}"
        local result="${SUITE_RESULTS[$i]}"
        local time="${SUITE_TIMES[$i]}"
        
        if [ "$result" = "PASS" ]; then
            echo -e "  ${GREEN}✓${NC} ${name} ${CYAN}(${time}s)${NC}"
        elif [ "$result" = "FAIL" ]; then
            echo -e "  ${RED}✗${NC} ${name} ${CYAN}(${time}s)${NC}"
        else
            echo -e "  ${YELLOW}⚠${NC} ${name} ${CYAN}(${time}s)${NC}"
        fi
    done
    
    echo ""
    echo -e "${BOLD}Results:${NC}"
    echo -e "  Total suites: ${CYAN}$TOTAL_SUITES${NC}"
    echo -e "  Passed:       ${GREEN}$PASSED_SUITES${NC}"
    echo -e "  Failed:       ${RED}$FAILED_SUITES${NC}"
    
    if [ $SKIPPED_SUITES -gt 0 ]; then
        echo -e "  Skipped:      ${YELLOW}$SKIPPED_SUITES${NC}"
    fi
    
    echo -e "  Total time:   ${CYAN}${total_time}s${NC}"
    
    # Display coverage summary if available
    local coverage_summary="$SCRIPT_DIR/coverage/summary.txt"
    if [ -f "$coverage_summary" ]; then
        echo ""
        echo -e "${BOLD}Coverage:${NC}"
        local line_coverage=$(grep "COVERAGE_LINE_RATE=" "$coverage_summary" | cut -d'=' -f2)
        local branch_coverage=$(grep "COVERAGE_BRANCH_RATE=" "$coverage_summary" | cut -d'=' -f2)
        echo -e "  Line coverage:   ${CYAN}${line_coverage}%${NC}"
        echo -e "  Branch coverage: ${CYAN}${branch_coverage}%${NC}"
    fi
    
    echo ""
    
    if [ $FAILED_SUITES -eq 0 ]; then
        echo -e "${BOLD}${GREEN}🎉 All test suites passed!${NC}"
    else
        echo -e "${BOLD}${RED}❌ Some test suites failed.${NC}"
    fi
    echo ""
}

# Main function
main() {
    local verbose=false
    local quiet=false
    local fail_fast=false
    local coverage=false
    local test_pattern=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -q|--quiet)
                quiet=true
                shift
                ;;
            -f|--fail-fast)
                fail_fast=true
                shift
                ;;
            -c|--coverage)
                coverage=true
                shift
                ;;
            -l|--list)
                list_test_suites
                exit 0
                ;;
            --hook)
                quiet=true
                fail_fast=true
                shift
                ;;
            -p|--parallel)
                echo -e "${YELLOW}Note: Parallel execution is not yet implemented. See Issue #2 in ISSUES_TO_CREATE.md${NC}"
                echo ""
                shift
                ;;
            -*)
                echo -e "${RED}Error: Unknown option: $1${NC}" >&2
                print_usage
                exit 1
                ;;
            *)
                test_pattern="$1"
                shift
                ;;
        esac
    done
    
    # Print header
    if [ "$quiet" = "false" ]; then
        echo ""
        echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${BLUE}║                                                ║${NC}"
        echo -e "${BOLD}${BLUE}║     Universal Bookmarks Test Runner            ║${NC}"
        echo -e "${BOLD}${BLUE}║                                                ║${NC}"
        echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════╝${NC}"
        echo ""
    fi
    
    # Check dependencies
    if ! check_dependencies; then
        exit 1
    fi
    
    # Filter test files if pattern provided
    local tests_to_run=()
    if [ -n "$test_pattern" ]; then
        for test_file in "${TEST_FILES[@]}"; do
            if [[ "$test_file" == *"$test_pattern"* ]]; then
                tests_to_run+=("$test_file")
            fi
        done
        
        if [ ${#tests_to_run[@]} -eq 0 ]; then
            echo -e "${RED}Error: No test files match pattern '$test_pattern'${NC}" >&2
            echo ""
            list_test_suites
            exit 1
        fi
        
        if [ "$quiet" = "false" ]; then
            echo -e "${YELLOW}Running tests matching pattern: $test_pattern${NC}"
            echo ""
        fi
    else
        tests_to_run=("${TEST_FILES[@]}")
    fi
    
    # If coverage mode is enabled, delegate to coverage wrapper
    if [ "$coverage" = "true" ]; then
        if [ ! -x "$SCRIPT_DIR/run_with_coverage.sh" ]; then
            chmod +x "$SCRIPT_DIR/run_with_coverage.sh"
        fi
        
        # Run coverage wrapper with test files
        "$SCRIPT_DIR/run_with_coverage.sh" "${tests_to_run[@]}"
        local coverage_exit_code=$?
        
        # Warn if coverage collection failed, but continue with tests
        if [ $coverage_exit_code -ne 0 ]; then
            echo -e "${YELLOW}Warning: Coverage collection encountered issues but tests will continue.${NC}"
        fi
        
        # Still run normal tests to get pass/fail summary
        echo ""
        echo -e "${BOLD}${BLUE}Running tests to collect results...${NC}"
        echo ""
    fi
    
    # Run tests
    local overall_result=0
    for test_file in "${tests_to_run[@]}"; do
        if ! run_test_suite "$test_file" "$verbose"; then
            overall_result=1
            if [ "$fail_fast" = "true" ]; then
                echo -e "${RED}Stopping on first failure (--fail-fast mode)${NC}"
                break
            fi
        fi
    done
    
    # Print summary
    if [ "$quiet" = "false" ]; then
        print_summary
    fi
    
    exit $overall_result
}

# Run main function
main "$@"
