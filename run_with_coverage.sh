#!/bin/bash

#=============================================================================
# Universal Bookmarks - Coverage Wrapper
# 
# Wrapper script to run tests with kcov for code coverage collection.
# This script is called by run_tests.sh when --coverage flag is used.
#=============================================================================

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Coverage output directory
COVERAGE_DIR="${SCRIPT_DIR}/coverage"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Function to check if kcov is available
check_kcov() {
    if ! command -v kcov &> /dev/null; then
        echo -e "${RED}Error: kcov is not installed.${NC}" >&2
        echo -e "${YELLOW}Install kcov to generate coverage reports:${NC}" >&2
        echo "  Ubuntu/Debian: sudo apt-get install kcov" >&2
        echo "  macOS: brew install kcov" >&2
        echo "  Build from source: https://github.com/SimonKagstrom/kcov" >&2
        return 1
    fi
    return 0
}

# Function to run a test file with coverage
run_test_with_coverage() {
    local test_file="$1"
    local test_name="${test_file%.sh}"
    local output_dir="${COVERAGE_DIR}/${test_name}"
    
    echo -e "${BLUE}Running $test_file with coverage...${NC}"
    
    # Create coverage directory if it doesn't exist
    mkdir -p "$output_dir"
    
    # Run kcov with the test script
    # kcov will track all bash scripts executed, including bookmarks.sh
    # --exclude-pattern to ignore system files and test framework
    # --bash-dont-parse-binary-dir to avoid parsing system binaries
    kcov \
        --exclude-pattern=/usr/,/tmp/,test_framework.sh,test_precommit_hooks.sh \
        --bash-dont-parse-binary-dir \
        "$output_dir" \
        "${SCRIPT_DIR}/${test_file}" 2>&1 || {
        local exit_code=$?
        echo -e "${YELLOW}⚠ kcov exited with code $exit_code for $test_file${NC}"
        # Check if coverage was still generated
        if [ -d "$output_dir" ] && [ -n "$(ls -A "$output_dir" 2>/dev/null)" ]; then
            echo -e "${GREEN}✓ Coverage data was generated despite non-zero exit${NC}"
        fi
    }
    
    return 0
}

# Function to merge coverage reports
merge_coverage_reports() {
    echo ""
    echo -e "${BOLD}${BLUE}Merging coverage reports...${NC}"
    
    local merged_dir="${COVERAGE_DIR}/merged"
    mkdir -p "$merged_dir"
    
    # Find all coverage directories (more permissive check)
    local coverage_dirs=()
    for dir in "${COVERAGE_DIR}"/test_*; do
        if [ -d "$dir" ]; then
            # Check if there's any coverage data (not just cobertura.xml)
            if [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
                coverage_dirs+=("$dir")
            fi
        fi
    done
    
    if [ ${#coverage_dirs[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠ No coverage data directories found${NC}"
        echo -e "${YELLOW}This might be the first run or coverage collection failed${NC}"
        # Create an empty merged directory to avoid downstream errors
        touch "$merged_dir/.placeholder"
        return 1
    fi
    
    echo -e "${BLUE}Found ${#coverage_dirs[@]} coverage report(s) to merge${NC}"
    
    # Merge using kcov's merge functionality
    # kcov --merge handles the merging internally
    if kcov --merge "$merged_dir" "${coverage_dirs[@]}" 2>&1; then
        echo -e "${GREEN}✓ Coverage reports merged successfully${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ kcov merge had issues${NC}"
        # Check if any output was generated
        if [ -f "$merged_dir/cobertura.xml" ]; then
            echo -e "${GREEN}✓ Merged coverage data exists${NC}"
            return 0
        fi
        return 1
    fi
}

# Function to calculate and display coverage summary
display_coverage_summary() {
    local merged_dir="${COVERAGE_DIR}/merged"
    
    if [ ! -f "$merged_dir/cobertura.xml" ]; then
        echo -e "${YELLOW}⚠ No merged coverage report found${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}COVERAGE SUMMARY${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Parse coverage from cobertura.xml using grep and sed
    if command -v xmllint &> /dev/null; then
        # Use xmllint if available (more reliable)
        local line_rate=$(xmllint --xpath "string(/coverage/@line-rate)" "$merged_dir/cobertura.xml" 2>/dev/null || echo "0")
        local branch_rate=$(xmllint --xpath "string(/coverage/@branch-rate)" "$merged_dir/cobertura.xml" 2>/dev/null || echo "0")
    else
        # Fallback to grep/sed (portable across systems)
        # Pattern: [0-9]*\.?[0-9]* matches valid decimal numbers (e.g., 0.85, 1, 0.5)
        local line_rate=$(grep 'line-rate=' "$merged_dir/cobertura.xml" | head -1 | sed 's/.*line-rate="\([0-9]*\.*[0-9]*\)".*/\1/' || echo "0")
        local branch_rate=$(grep 'branch-rate=' "$merged_dir/cobertura.xml" | head -1 | sed 's/.*branch-rate="\([0-9]*\.*[0-9]*\)".*/\1/' || echo "0")
    fi
    
    # Convert to percentage
    local line_coverage=$(awk "BEGIN {printf \"%.1f\", $line_rate * 100}")
    local branch_coverage=$(awk "BEGIN {printf \"%.1f\", $branch_rate * 100}")
    
    echo -e "  ${BOLD}Line Coverage:${NC}   ${CYAN}${line_coverage}%${NC}"
    echo -e "  ${BOLD}Branch Coverage:${NC} ${CYAN}${branch_coverage}%${NC}"
    echo ""
    echo -e "  ${BOLD}Coverage Report:${NC} ${CYAN}${merged_dir}/index.html${NC}"
    echo -e "  ${BOLD}Cobertura XML:${NC}   ${CYAN}${merged_dir}/cobertura.xml${NC}"
    echo ""
    
    # Display coverage status with color (using awk for portable floating point comparison)
    if [ "$(awk "BEGIN {print ($line_coverage >= 80)}")" = "1" ]; then
        echo -e "${BOLD}${GREEN}✓ Excellent coverage! (>= 80%)${NC}"
    elif [ "$(awk "BEGIN {print ($line_coverage >= 60)}")" = "1" ]; then
        echo -e "${BOLD}${YELLOW}⚠ Good coverage, but could be improved (>= 60%)${NC}"
    else
        echo -e "${BOLD}${RED}⚠ Coverage could be significantly improved (< 60%)${NC}"
    fi
    echo ""
    
    # Export coverage for use in CI
    echo "COVERAGE_LINE_RATE=${line_coverage}" >> "${COVERAGE_DIR}/summary.txt"
    echo "COVERAGE_BRANCH_RATE=${branch_coverage}" >> "${COVERAGE_DIR}/summary.txt"
    
    return 0
}

# Main function
main() {
    local test_files=("$@")
    
    # Check if kcov is available
    if ! check_kcov; then
        exit 1
    fi
    
    # Clean previous coverage data
    if [ -d "$COVERAGE_DIR" ]; then
        echo -e "${BLUE}Cleaning previous coverage data...${NC}"
        rm -rf "$COVERAGE_DIR"
    fi
    mkdir -p "$COVERAGE_DIR"
    
    echo ""
    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║                                                ║${NC}"
    echo -e "${BOLD}${BLUE}║     Coverage Collection Started                ║${NC}"
    echo -e "${BOLD}${BLUE}║                                                ║${NC}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Run each test file with coverage
    local failed_tests=0
    for test_file in "${test_files[@]}"; do
        if ! run_test_with_coverage "$test_file"; then
            failed_tests=$((failed_tests + 1))
        fi
    done
    
    # Merge coverage reports
    if ! merge_coverage_reports; then
        echo -e "${YELLOW}Warning: Could not merge coverage reports${NC}"
        echo -e "${YELLOW}Coverage collection may not have captured any data${NC}"
        # Don't exit with error - let CI continue
        return 0
    fi
    
    # Display coverage summary
    if ! display_coverage_summary; then
        echo -e "${YELLOW}Warning: Could not generate coverage summary${NC}"
        # Don't exit with error - let CI continue
        return 0
    fi
    
    echo -e "${BOLD}${GREEN}✓ Coverage collection completed${NC}"
    echo ""
    
    return 0
}

# Run main function with all arguments
main "$@"
