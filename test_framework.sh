#!/bin/bash

# Shared test framework for Universal Bookmarks
# This file provides common test functions used across all test suites

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Test timing and results tracking
declare -a TEST_NAMES=()
declare -a TEST_RESULTS=()
declare -a TEST_DURATIONS=()
declare -a TEST_EXIT_CODES=()
declare -a TEST_EXPECTED_CODES=()

# Slow test threshold in seconds
SLOW_TEST_THRESHOLD=1

# Report output directory
REPORT_DIR="${REPORT_DIR:-./test-reports}"

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

#=============================================================================
# REPORT GENERATION FUNCTIONS
#=============================================================================

# Generate JUnit XML report
# This function creates a JUnit-compatible XML report for CI integration
generate_junit_report() {
    local suite_name="${1:-test-suite}"
    local output_file="${REPORT_DIR}/junit-${suite_name}.xml"
    
    # Create report directory if needed
    mkdir -p "$REPORT_DIR"
    
    # Calculate total time
    local total_time=0
    for duration in "${TEST_DURATIONS[@]}"; do
        total_time=$(awk -v t="$total_time" -v d="$duration" 'BEGIN { printf "%.2f", t+d }')
    done
    
    # Generate XML
    {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo "<testsuite name=\"$suite_name\" tests=\"$TOTAL_TESTS\" failures=\"$TESTS_FAILED\" errors=\"0\" time=\"$total_time\">"
        
        for i in "${!TEST_NAMES[@]}"; do
            local name="${TEST_NAMES[$i]}"
            local result="${TEST_RESULTS[$i]}"
            local duration="${TEST_DURATIONS[$i]}"
            local exit_code="${TEST_EXIT_CODES[$i]}"
            local expected_code="${TEST_EXPECTED_CODES[$i]}"
            
            echo "  <testcase name=\"$(xml_escape "$name")\" time=\"$duration\">"
            
            if [ "$result" = "FAIL" ]; then
                echo "    <failure message=\"Exit code mismatch\">"
                echo "      Expected: $expected_code, Actual: $exit_code"
                echo "    </failure>"
            fi
            
            echo "  </testcase>"
        done
        
        echo "</testsuite>"
    } > "$output_file"
    
    echo "$output_file"
}

# Generate JSON report
# This function creates a JSON report for tooling and programmatic access
generate_json_report() {
    local suite_name="${1:-test-suite}"
    local output_file="${REPORT_DIR}/report-${suite_name}.json"
    
    # Create report directory if needed
    mkdir -p "$REPORT_DIR"
    
    # Calculate total time
    local total_time=0
    for duration in "${TEST_DURATIONS[@]}"; do
        total_time=$(awk -v t="$total_time" -v d="$duration" 'BEGIN { printf "%.2f", t+d }')
    done
    
    # Build tests array using jq for proper JSON encoding
    local tests_json="["
    local first=true
    
    for i in "${!TEST_NAMES[@]}"; do
        [ "$first" = false ] && tests_json+=","
        first=false
        
        local name="${TEST_NAMES[$i]}"
        local result="${TEST_RESULTS[$i]}"
        local duration="${TEST_DURATIONS[$i]}"
        local exit_code="${TEST_EXIT_CODES[$i]}"
        local expected_code="${TEST_EXPECTED_CODES[$i]}"
        local is_slow=$(is_slow_test "$duration" && echo "true" || echo "false")
        
        # Use jq to properly escape the test name
        local escaped_name=$(echo -n "$name" | jq -Rs .)
        
        tests_json+="{\"name\":$escaped_name,\"result\":\"$result\",\"duration\":$duration,\"exitCode\":$exit_code,\"expectedCode\":$expected_code,\"slow\":$is_slow}"
    done
    tests_json+="]"
    
    # Generate JSON report
    jq -n \
        --arg suite "$suite_name" \
        --argjson total "$TOTAL_TESTS" \
        --argjson passed "$TESTS_PASSED" \
        --argjson failed "$TESTS_FAILED" \
        --arg time "$total_time" \
        --argjson tests "$tests_json" \
        '{
            suite: $suite,
            summary: {
                total: $total,
                passed: $passed,
                failed: $failed,
                totalTime: $time
            },
            tests: $tests
        }' > "$output_file"
    
    echo "$output_file"
}

# Generate HTML report
# This function creates a human-readable HTML report
generate_html_report() {
    local suite_name="${1:-test-suite}"
    local output_file="${REPORT_DIR}/report-${suite_name}.html"
    
    # Create report directory if needed
    mkdir -p "$REPORT_DIR"
    
    # Calculate total time
    local total_time=0
    for duration in "${TEST_DURATIONS[@]}"; do
        total_time=$(awk -v t="$total_time" -v d="$duration" 'BEGIN { printf "%.2f", t+d }')
    done
    
    # Generate HTML
    cat > "$output_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Test Report</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #4CAF50; padding-bottom: 10px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .stat { padding: 20px; border-radius: 6px; text-align: center; }
        .stat.total { background: #2196F3; color: white; }
        .stat.passed { background: #4CAF50; color: white; }
        .stat.failed { background: #f44336; color: white; }
        .stat.time { background: #FF9800; color: white; }
        .stat-value { font-size: 2em; font-weight: bold; }
        .stat-label { font-size: 0.9em; opacity: 0.9; margin-top: 5px; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th { background: #333; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background: #f9f9f9; }
        .pass { color: #4CAF50; font-weight: bold; }
        .fail { color: #f44336; font-weight: bold; }
        .slow { color: #FF9800; font-size: 0.9em; }
        .duration { color: #666; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Test Report: SUITE_NAME_PLACEHOLDER</h1>
        <div class="summary">
            <div class="stat total">
                <div class="stat-value">TOTAL_TESTS_PLACEHOLDER</div>
                <div class="stat-label">Total Tests</div>
            </div>
            <div class="stat passed">
                <div class="stat-value">PASSED_TESTS_PLACEHOLDER</div>
                <div class="stat-label">Passed</div>
            </div>
            <div class="stat failed">
                <div class="stat-value">FAILED_TESTS_PLACEHOLDER</div>
                <div class="stat-label">Failed</div>
            </div>
            <div class="stat time">
                <div class="stat-value">TOTAL_TIME_PLACEHOLDER</div>
                <div class="stat-label">Total Time (s)</div>
            </div>
        </div>
        <table>
            <thead>
                <tr>
                    <th>#</th>
                    <th>Test Name</th>
                    <th>Result</th>
                    <th>Duration</th>
                    <th>Exit Code</th>
                </tr>
            </thead>
            <tbody>
TEST_ROWS_PLACEHOLDER
            </tbody>
        </table>
    </div>
</body>
</html>
EOF
    
    # Replace placeholders
    sed -i "s/SUITE_NAME_PLACEHOLDER/$suite_name/g" "$output_file"
    sed -i "s/TOTAL_TESTS_PLACEHOLDER/$TOTAL_TESTS/g" "$output_file"
    sed -i "s/PASSED_TESTS_PLACEHOLDER/$TESTS_PASSED/g" "$output_file"
    sed -i "s/FAILED_TESTS_PLACEHOLDER/$TESTS_FAILED/g" "$output_file"
    sed -i "s/TOTAL_TIME_PLACEHOLDER/$total_time/g" "$output_file"
    
    # Generate test rows
    local rows=""
    for i in "${!TEST_NAMES[@]}"; do
        local num=$((i + 1))
        local name=$(html_escape "${TEST_NAMES[$i]}")
        local result="${TEST_RESULTS[$i]}"
        local duration="${TEST_DURATIONS[$i]}"
        local exit_code="${TEST_EXIT_CODES[$i]}"
        local expected_code="${TEST_EXPECTED_CODES[$i]}"
        
        local result_class="pass"
        local result_text="✓ PASS"
        if [ "$result" = "FAIL" ]; then
            result_class="fail"
            result_text="✗ FAIL"
        fi
        
        local slow_marker=""
        if is_slow_test "$duration"; then
            slow_marker=" <span class=\"slow\">⚠ SLOW</span>"
        fi
        
        rows+="                <tr>"
        rows+="<td>$num</td>"
        rows+="<td>$name</td>"
        rows+="<td class=\"$result_class\">$result_text</td>"
        rows+="<td class=\"duration\">${duration}s$slow_marker</td>"
        rows+="<td>$exit_code</td>"
        rows+="</tr>\n"
    done
    
    # Insert test rows
    sed -i "s|TEST_ROWS_PLACEHOLDER|$rows|g" "$output_file"
    
    echo "$output_file"
}

# Helper function to escape XML special characters
xml_escape() {
    local text="$1"
    echo "$text" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'\''/\&apos;/g'
}

# Helper function to escape HTML special characters
html_escape() {
    local text="$1"
    echo "$text" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'
}

# Generate all reports
# Args: $1 - suite name
generate_all_reports() {
    local suite_name="${1:-test-suite}"
    
    echo -e "${BLUE}Generating test reports...${NC}"
    
    local junit_file=$(generate_junit_report "$suite_name")
    echo -e "${GREEN}✓${NC} JUnit XML: $junit_file"
    
    local json_file=$(generate_json_report "$suite_name")
    echo -e "${GREEN}✓${NC} JSON:      $json_file"
    
    local html_file=$(generate_html_report "$suite_name")
    echo -e "${GREEN}✓${NC} HTML:      $html_file"
    
    echo ""
}

#=============================================================================
# TIMING FUNCTIONS
#=============================================================================

# Get current time in milliseconds (UNIX epoch)
# Returns: milliseconds since epoch
get_time_ms() {
    date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000))
}

# Calculate duration between two timestamps
# Args: $1 - start time (ms), $2 - end time (ms)
# Returns: duration in seconds with millisecond precision
calculate_duration() {
    local start_ms="$1"
    local end_ms="$2"
    local duration_ms=$((end_ms - start_ms))
    
    # Convert to seconds with 2 decimal places
    awk -v ms="$duration_ms" 'BEGIN { printf "%.2f", ms/1000.0 }'
}

# Check if a test is slow based on duration
# Args: $1 - duration in seconds
# Returns: 0 if slow, 1 if not
is_slow_test() {
    local duration="$1"
    awk -v dur="$duration" -v thresh="$SLOW_TEST_THRESHOLD" 'BEGIN { exit (dur > thresh) ? 0 : 1 }'
}

#=============================================================================
# PROGRESS DISPLAY FUNCTIONS
#=============================================================================

# Format test progress indicator
# Args: $1 - current test number, $2 - total tests
# Returns: formatted progress string
format_progress() {
    local current="$1"
    local total="$2"
    echo "[$current/$total]"
}

# Format duration with slow test warning
# Args: $1 - duration in seconds
# Returns: formatted duration string with optional warning
format_duration() {
    local duration="$1"
    local output="${CYAN}(${duration}s)${NC}"
    
    if is_slow_test "$duration"; then
        output="${output} ${YELLOW}⚠ SLOW${NC}"
    fi
    
    echo -e "$output"
}

#=============================================================================
# TEST EXECUTION FUNCTIONS
#=============================================================================

# Run a test and check if it passes
# Args: $1 - test name, $2 - test command, $3 - expected exit code (default: 0)
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_exit_code="${3:-0}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local current_test=$TOTAL_TESTS
    
    # Display progress and test name
    local progress=$(format_progress "$current_test" "$TOTAL_TESTS")
    echo -e "${BLUE}Running test: ${YELLOW}$test_name${NC} ${CYAN}$progress${NC}"
    
    # Capture start time
    local start_time=$(get_time_ms)
    
    # Run the command and capture output
    local test_output
    local exit_code
    test_output=$(eval "$test_cmd" 2>&1)
    exit_code=$?
    
    # Capture end time and calculate duration
    local end_time=$(get_time_ms)
    local duration=$(calculate_duration "$start_time" "$end_time")
    
    # Store test results for reporting
    TEST_NAMES+=("$test_name")
    TEST_DURATIONS+=("$duration")
    TEST_EXIT_CODES+=("$exit_code")
    TEST_EXPECTED_CODES+=("$expected_exit_code")
    
    # Check if test passed
    if [ "$exit_code" -eq "$expected_exit_code" ]; then
        echo -e "${GREEN}✓${NC} $test_name $(format_duration "$duration")"
        TEST_RESULTS+=("PASS")
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name $(format_duration "$duration")"
        echo -e "${RED}  Expected: exit code $expected_exit_code${NC}"
        echo -e "${RED}  Actual:   exit code $exit_code${NC}"
        
        # Show output context for failures
        if [ -n "$test_output" ]; then
            echo -e "${YELLOW}  Output:${NC}"
            echo "$test_output" | head -10 | sed 's/^/    /'
        fi
        
        # Provide hint based on exit code
        provide_failure_hint "$exit_code" "$expected_exit_code" "$test_name"
        
        TEST_RESULTS+=("FAIL")
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Provide helpful hints for test failures
# Args: $1 - actual exit code, $2 - expected exit code, $3 - test name
provide_failure_hint() {
    local actual="$1"
    local expected="$2"
    local test_name="$3"
    
    echo -e "${PURPLE}  Hint:${NC}" >&2
    
    # Generic hints based on exit code patterns
    if [ "$actual" -eq 1 ] && [ "$expected" -eq 0 ]; then
        echo "    Check for error conditions or failed validations" >&2
    elif [ "$actual" -eq 0 ] && [ "$expected" -ne 0 ]; then
        echo "    Command succeeded but was expected to fail - check input validation" >&2
    elif [ "$actual" -eq 127 ]; then
        echo "    Command not found - check PATH or command spelling" >&2
    elif [ "$actual" -eq 126 ]; then
        echo "    Permission denied - check file permissions" >&2
    elif [ "$actual" -gt 128 ]; then
        local signal=$((actual - 128))
        echo "    Process terminated by signal $signal" >&2
    else
        echo "    Review test command and expected behavior" >&2
    fi
}
