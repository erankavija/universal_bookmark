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
    # We need to track the main bookmarks.sh script
    # --exclude-pattern to ignore test files and system files
    # --include-pattern to only track bookmarks.sh
    kcov \
        --exclude-pattern=/usr/,/tmp/,test_ \
        --include-pattern="${SCRIPT_DIR}/bookmarks.sh" \
        --bash-dont-parse-binary-dir \
        "$output_dir" \
        "${SCRIPT_DIR}/${test_file}"
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ Coverage collected for $test_file${NC}"
    else
        echo -e "${YELLOW}⚠ Coverage collection completed with exit code $exit_code for $test_file${NC}"
        # Don't fail on coverage collection errors, just warn
    fi
    
    return 0
}

# Function to merge coverage reports
merge_coverage_reports() {
    echo ""
    echo -e "${BOLD}${BLUE}Merging coverage reports...${NC}"
    
    local merged_dir="${COVERAGE_DIR}/merged"
    mkdir -p "$merged_dir"
    
    # Find all coverage directories
    local coverage_dirs=()
    for dir in "${COVERAGE_DIR}"/test_*; do
        if [ -d "$dir" ] && [ -f "$dir/cobertura.xml" ]; then
            coverage_dirs+=("$dir")
        fi
    done
    
    if [ ${#coverage_dirs[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠ No coverage reports found to merge${NC}"
        return 1
    fi
    
    # Merge using kcov's merge functionality
    # Simply copy all coverage data to merged directory
    for dir in "${coverage_dirs[@]}"; do
        cp -r "$dir"/* "$merged_dir/" 2>/dev/null || true
    done
    
    # Run kcov --merge to combine them
    kcov --merge "$merged_dir" "${coverage_dirs[@]}" 2>/dev/null || {
        echo -e "${YELLOW}⚠ kcov merge had issues, but continuing...${NC}"
    }
    
    echo -e "${GREEN}✓ Coverage reports merged${NC}"
    return 0
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
        local line_rate=$(grep 'line-rate=' "$merged_dir/cobertura.xml" | head -1 | sed 's/.*line-rate="\([0-9.]*\)".*/\1/' || echo "0")
        local branch_rate=$(grep 'branch-rate=' "$merged_dir/cobertura.xml" | head -1 | sed 's/.*branch-rate="\([0-9.]*\)".*/\1/' || echo "0")
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
        echo -e "${RED}Failed to merge coverage reports${NC}" >&2
        exit 1
    fi
    
    # Display coverage summary
    if ! display_coverage_summary; then
        echo -e "${RED}Failed to generate coverage summary${NC}" >&2
        exit 1
    fi
    
    echo -e "${BOLD}${GREEN}✓ Coverage collection completed successfully${NC}"
    echo ""
    
    return 0
}

# Run main function with all arguments
main "$@"
