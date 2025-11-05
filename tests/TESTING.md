# Testing Guide for Universal Bookmarks

This guide provides comprehensive information about testing the Universal Bookmarks project, including how to run tests, write new tests, and troubleshoot issues.

## Table of Contents

- [Quick Start](#quick-start)
- [Test Organization](#test-organization)
- [Running Tests](#running-tests)
- [Test Framework](#test-framework)
- [Writing New Tests](#writing-new-tests)
- [Testing Best Practices](#testing-best-practices)
- [Code Coverage](#code-coverage)
- [Troubleshooting](#troubleshooting)

## Quick Start

Run all tests with the test runner:

```bash
cd tests
./run_tests.sh
```

The test runner automatically:
- Checks for required dependencies (`jq`, `fzf`)
- Runs all test suites in order
- Provides aggregated results and summary
- Returns non-zero exit code if any tests fail

## Test Organization

The test suite is organized into multiple specialized test files:

```
tests/
├── run_tests.sh              # Main test runner with aggregated reporting
├── run_with_coverage.sh      # Coverage collection wrapper (requires kcov)
├── test_framework.sh         # Shared test framework functions
├── test_bookmarks.sh         # Core functionality tests
├── test_frecency.sh          # Frecency scoring and sorting tests
├── test_editor_features.sh   # Editor-based bookmark editing tests
├── test_special_chars.sh     # Special character handling tests
├── test_type_execution.sh    # Type-specific execution logic tests
├── test_composable_filters.sh # Composable filter pipeline tests
└── TESTING.md               # This file
```

### Test Suite Descriptions

**test_framework.sh** - Shared test framework
- Provides common test functions used across all test suites
- Includes setup/cleanup functions and test result tracking
- Not executed directly; sourced by other test files

**test_bookmarks.sh** - Core functionality
- Tests adding, editing, updating, deleting bookmarks
- Tests list output format and parsing
- Tests tag search and backup/restore
- Tests non-interactive mode (`-y` flag)

**test_frecency.sh** - Frecency-based sorting
- Tests the frecency (frequency + recency) scoring system
- Tests automatic bookmark sorting
- Tests migration of old bookmarks without frecency fields

**test_editor_features.sh** - Editor integration
- Tests editor-based bookmark editing
- Tests `modify-add` command for creating from templates
- Tests `BOOKMARKS_EDITOR` and `EDITOR` environment variables

**test_special_chars.sh** - Special character handling
- Tests bookmarks with underscores, emojis, accents
- Tests Unicode characters (Chinese, Japanese, Korean, Arabic)
- Tests special characters in descriptions, commands, tags, and notes

**test_type_execution.sh** - Type-aware execution
- Tests execution logic for different bookmark types
- Tests `url`, `pdf`, `script`, `ssh`, `app`, `cmd`, `note`, `edit`, `folder`, `file`, `custom` types

**test_composable_filters.sh** - Filter pipelines
- Tests composable filter functions
- Tests UNIX-style pipeline operations
- Tests filter chaining and composition

## Running Tests

### Run All Tests

```bash
cd tests
./run_tests.sh
```

### Run Specific Test Suites

Filter by test name pattern:

```bash
./run_tests.sh frecency        # Run only frecency tests
./run_tests.sh special         # Run only special character tests
./run_tests.sh bookmarks       # Run only bookmark tests
```

### Test Runner Options

```bash
./run_tests.sh [OPTIONS] [TEST_PATTERN]

OPTIONS:
  -h, --help          Show help message
  -v, --verbose       Show detailed test output
  -q, --quiet         Show only summary
  -f, --fail-fast     Stop on first test failure
  -l, --list          List available test suites
  -c, --coverage      Run tests with code coverage (requires kcov)

EXAMPLES:
  ./run_tests.sh                  # Run all tests
  ./run_tests.sh -v               # Run all tests with verbose output
  ./run_tests.sh frecency         # Run only frecency tests
  ./run_tests.sh -f bookmarks     # Run bookmark tests, stop on first failure
  ./run_tests.sh --coverage       # Run all tests with coverage collection
```

### Run Individual Test File

Each test file can be run independently:

```bash
./test_bookmarks.sh         # Run a specific test suite
./test_frecency.sh          # Run another specific test suite
```

## Test Framework

The test framework (`test_framework.sh`) provides common functions for all test suites.

### Core Functions

#### setup_test_env()

Creates a temporary test environment with isolated bookmark file.

```bash
setup_test_env()
```

**What it does:**
- Creates temporary directory for test bookmarks
- Initializes empty bookmarks JSON file
- Sets `BOOKMARKS_DIR` environment variable
- Saves original environment variables for restoration

**Variables set:**
- `TEST_DIR` - Path to temporary test directory
- `TEST_BOOKMARKS_FILE` - Path to test bookmarks.json
- `ORIG_BOOKMARKS_DIR` - Original `BOOKMARKS_DIR` value
- `ORIG_EDITOR` - Original `EDITOR` value

#### cleanup_test_env()

Restores original environment and removes temporary test files.

```bash
cleanup_test_env()
```

**What it does:**
- Restores original `BOOKMARKS_DIR`
- Restores original `EDITOR`
- Removes temporary test directory

#### run_test(name, command, [expected_exit_code])

Runs a test command and checks if it passes.

```bash
run_test "Test name" "command to run" [expected_exit_code]
```

**Parameters:**
- `name` - Human-readable test description
- `command` - Shell command to execute
- `expected_exit_code` - Expected exit code (default: 0)

**Returns:**
- 0 if test passes
- 1 if test fails

**Updates:**
- `TESTS_PASSED` counter
- `TESTS_FAILED` counter
- `TOTAL_TESTS` counter

### Test Counters

The framework maintains global counters:

```bash
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0
```

These are automatically updated by `run_test()` and should be reported in test summaries.

### Color Output

The framework defines standard colors for consistent output:

```bash
RED='\033[0;31m'      # Errors and failures
GREEN='\033[0;32m'    # Success and passed tests
YELLOW='\033[0;33m'   # Warnings
BLUE='\033[0;34m'     # Informational messages
NC='\033[0m'          # No Color (reset)
```

## Writing New Tests

### Test File Template

Use this template for creating new test files:

```bash
#!/bin/bash

# Test suite for [Feature Name]
# Run this script to test [description]

# Source the shared test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_framework.sh"

# Run the test suite
run_test_suite() {
    echo -e "${BLUE}Starting [feature name] test suite${NC}"
    
    # Test 1: Basic functionality
    run_test "Test description" \
        "../bookmarks.sh command 'args'"
    
    # Test 2: Edge case
    run_test "Edge case description" \
        "command with expected failure" \
        1  # Expected exit code
    
    # Test 3: Validation
    run_test "Validation check" \
        "[ \$(jq -r '.bookmarks | length' \$TEST_BOOKMARKS_FILE) -eq 2 ]"
    
    # Print summary
    echo ""
    echo -e "${BLUE}Test summary:${NC}"
    echo -e "  ${GREEN}Tests passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Tests failed: $TESTS_FAILED${NC}"
    echo -e "  Total tests: $TOTAL_TESTS"
    
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
TEST_RESULT=$?
cleanup_test_env

exit $TEST_RESULT
```

### Test Case Examples

#### Example 1: Simple Command Test

```bash
run_test "Add URL bookmark" \
    "../bookmarks.sh add 'Test URL' url 'https://example.com'"
```

#### Example 2: Test with Expected Failure

```bash
run_test "Delete non-existent bookmark fails" \
    "../bookmarks.sh -y delete 'NonExistent'" \
    1  # Expected exit code 1 (failure)
```

#### Example 3: Validation Test

```bash
run_test "Bookmark count is correct" \
    "[ \$(jq -r '.bookmarks | length' \$TEST_BOOKMARKS_FILE) -eq 3 ]"
```

#### Example 4: Output Format Test

```bash
run_test "List output format is correct" \
    "../bookmarks.sh list | grep -qE '^\[[a-z]+\] .+ \| .+ \| (active|obsolete)'"
```

#### Example 5: Multiple Commands

```bash
run_test "Add and verify bookmark" \
    "../bookmarks.sh add 'Multi Test' cmd 'echo test' && \
     ../bookmarks.sh list | grep -q 'Multi Test'"
```

#### Example 6: JSON Validation

```bash
run_test "Bookmark has required fields" \
    "jq -e '.bookmarks[0] | has(\"id\") and has(\"description\") and has(\"type\")' \
     \$TEST_BOOKMARKS_FILE > /dev/null"
```

### Adding Tests to Test Runner

After creating a new test file:

1. Make it executable:
   ```bash
   chmod +x test_myfeature.sh
   ```

2. Add it to `run_tests.sh`:
   ```bash
   TEST_FILES=(
       "test_framework.sh"
       "test_bookmarks.sh"
       # ... other tests ...
       "test_myfeature.sh"  # Add your test here
   )
   ```

3. Update GitHub Actions workflow (`.github/workflows/test.yml`):
   ```yaml
   - name: Make scripts executable
     run: |
       chmod +x tests/test_myfeature.sh  # Add your test here
   ```

## Testing Best Practices

### 1. Test Isolation

Each test should be independent and not rely on other tests:

```bash
# Good: Self-contained test
run_test "Delete bookmark" \
    "../bookmarks.sh add 'ToDelete' cmd 'echo test' && \
     ../bookmarks.sh -y delete 'ToDelete'"

# Bad: Relies on previous test
run_test "Delete bookmark" \
    "../bookmarks.sh -y delete 'ToDelete'"  # Assumes bookmark exists
```

### 2. Use Non-Interactive Mode

Always use `-y` flag for commands that require confirmation:

```bash
# Good: Non-interactive
../bookmarks.sh -y delete "Bookmark Name"

# Bad: Would hang waiting for user input
../bookmarks.sh delete "Bookmark Name"
```

### 3. Test Both Success and Failure Cases

```bash
# Test success case
run_test "Valid bookmark type accepted" \
    "../bookmarks.sh add 'Test' url 'https://example.com'"

# Test failure case
run_test "Invalid bookmark type rejected" \
    "../bookmarks.sh add 'Test' invalidtype 'command'" \
    1  # Expect failure
```

### 4. Use Descriptive Test Names

```bash
# Good: Clear and descriptive
run_test "Frecency score increases with access count"

# Bad: Vague or unclear
run_test "Test 42"
```

### 5. Verify State Changes

Don't just test commands; verify they had the expected effect:

```bash
run_test "Delete removes bookmark from file" \
    "../bookmarks.sh add 'ToDelete' cmd 'echo test' && \
     ../bookmarks.sh -y delete 'ToDelete' && \
     ! jq -e '.bookmarks[] | select(.description == \"ToDelete\")' \
       \$TEST_BOOKMARKS_FILE > /dev/null"
```

### 6. Clean Test Output

Redirect output when not needed for verification:

```bash
# Good: Clean output
../bookmarks.sh add "Test" cmd "echo test" > /dev/null 2>&1

# Use when you need to verify output
local output=$(../bookmarks.sh list)
echo "$output" | grep -q "Test"
```

### 7. Test Edge Cases

Include tests for:
- Empty inputs
- Special characters
- Very long inputs
- Boundary conditions
- Error conditions

### 8. Use Variables for Readability

```bash
# Good: Clear and maintainable
local expected_count=5
local actual_count=$(jq -r '.bookmarks | length' $TEST_BOOKMARKS_FILE)
run_test "Bookmark count matches" \
    "[ $actual_count -eq $expected_count ]"

# Acceptable but less clear
run_test "Bookmark count matches" \
    "[ \$(jq -r '.bookmarks | length' \$TEST_BOOKMARKS_FILE) -eq 5 ]"
```

## Code Coverage

The project supports code coverage reporting using `kcov`.

### Prerequisites

Install kcov:

**Ubuntu/Debian:**
```bash
# Build from source (kcov not in default repos)
sudo apt-get install -y cmake g++ pkg-config libcurl4-openssl-dev \
    libelf-dev libdw-dev binutils-dev libiberty-dev
git clone --depth 1 --branch v43 https://github.com/SimonKagstrom/kcov.git
cd kcov
mkdir build && cd build
cmake ..
make
sudo make install
```

**macOS:**
```bash
brew install kcov
```

### Generating Coverage Reports

Run tests with coverage:

```bash
./run_tests.sh --coverage
```

Or use the short form:

```bash
./run_tests.sh -c
```

### Coverage Output

Coverage reports are generated in `./coverage/`:

```
coverage/
├── test_bookmarks/          # Coverage from test_bookmarks.sh
│   ├── cobertura.xml
│   └── index.html
├── test_frecency/           # Coverage from test_frecency.sh
│   ├── cobertura.xml
│   └── index.html
├── merged/                  # Combined coverage from all tests
│   ├── cobertura.xml        # XML format for CI tools
│   └── index.html           # Interactive HTML report
└── summary.txt              # Plain text summary
```

### Viewing Coverage Reports

Open the HTML report in your browser:

```bash
# Linux
xdg-open ./coverage/merged/index.html

# macOS
open ./coverage/merged/index.html
```

The HTML report shows:
- Line-by-line coverage (green for covered, red for uncovered)
- Function coverage
- Branch coverage
- File-level statistics

### Coverage Thresholds

The project uses these coverage quality indicators:

- **≥ 80%**: Excellent coverage ✓ (green)
- **≥ 60%**: Good coverage ⚠ (yellow)
- **< 60%**: Needs improvement ⚠ (red)

### CI/CD Integration

Coverage is automatically collected and uploaded to [Codecov](https://codecov.io/gh/erankavija/universal_bookmark) when:
- Code is pushed to the `main` branch
- Pull requests are opened or updated

The GitHub Actions workflow:
1. Installs kcov
2. Runs all tests with coverage
3. Uploads coverage data to Codecov
4. Displays coverage in PR comments

### Improving Coverage

To improve coverage:

1. **Identify uncovered code:**
   - Open the HTML coverage report
   - Look for red-highlighted lines
   - Check which functions/branches are uncovered

2. **Write targeted tests:**
   - Focus on untested error paths
   - Test edge cases and boundary conditions
   - Cover platform-specific code branches

3. **Example - Testing error handling:**
   ```bash
   # Test invalid JSON handling
   echo "invalid json" > $TEST_BOOKMARKS_FILE
   run_test "Invalid JSON handled gracefully" \
       "../bookmarks.sh list 2>&1 | grep -q 'Error'" \
       1  # Expect error exit code
   ```

## Troubleshooting

### Common Issues

#### 1. Missing Dependencies

**Error:** `fzf is not installed` or `jq is not installed`

**Solution:**
```bash
# Install jq
# Ubuntu/Debian: sudo apt-get install jq
# macOS: brew install jq

# Install fzf
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install --bin
export PATH="$HOME/.fzf/bin:$PATH"
```

#### 2. Tests Fail with "Command not found"

**Error:** `../bookmarks.sh: command not found`

**Cause:** Test files are not in the correct directory

**Solution:**
```bash
# Make sure you're in the tests directory
cd tests
./run_tests.sh
```

#### 3. Permission Denied

**Error:** `permission denied: ./test_bookmarks.sh`

**Solution:**
```bash
chmod +x test_*.sh run_tests.sh run_with_coverage.sh
```

#### 4. Test Hangs or Times Out

**Cause:** Test is waiting for user input or running interactive command

**Solution:**
- Use `-y` flag for confirmation prompts
- Use `timeout` command for potentially long-running operations
- Mock interactive tools (fzf) when testing

Example:
```bash
# Good: Non-interactive with timeout
timeout 2 bash -c '../bookmarks.sh list' || true

# Bad: Could hang
../bookmarks.sh edit  # Launches fzf interactively
```

#### 5. Tests Pass Locally but Fail in CI

**Possible causes:**
- Missing dependencies in CI environment
- Platform-specific behavior differences
- File path issues
- Timing-dependent tests

**Solution:**
- Check GitHub Actions logs for specific errors
- Test on same platform as CI (Ubuntu for GitHub Actions)
- Ensure tests are not timing-dependent
- Use absolute paths or relative paths consistently

#### 6. Coverage Reports Not Generated

**Cause:** kcov not installed or not in PATH

**Solution:**
```bash
# Check if kcov is available
which kcov

# If not found, install it (see Coverage Prerequisites)
```

#### 7. JSON Parse Errors in Tests

**Error:** `parse error: Invalid numeric literal`

**Cause:** Corrupted or invalid JSON in test bookmarks file

**Solution:**
- Check `$TEST_BOOKMARKS_FILE` contents
- Ensure proper escaping in test commands
- Validate JSON with `jq .` before using it

#### 8. Test Directory Not Cleaned Up

**Cause:** Test failed before cleanup_test_env was called

**Solution:**
```bash
# Manually clean up test directories
rm -rf /tmp/tmp.*

# The test framework uses mktemp which creates dirs like /tmp/tmp.XXXXXXXX
```

### Debugging Tests

#### Enable Verbose Output

```bash
./run_tests.sh -v              # Verbose mode
```

#### Run Tests with Bash Tracing

```bash
bash -x ./test_bookmarks.sh     # Shows each command as it executes
```

#### Check Test Environment

```bash
# Inside a test file, add debugging output:
echo "TEST_DIR: $TEST_DIR"
echo "TEST_BOOKMARKS_FILE: $TEST_BOOKMARKS_FILE"
echo "BOOKMARKS_DIR: $BOOKMARKS_DIR"
cat "$TEST_BOOKMARKS_FILE"  # Show current JSON state
```

#### Run Individual Test Commands

Extract and run commands directly:

```bash
# Set up test environment manually
TEST_DIR=$(mktemp -d)
TEST_BOOKMARKS_FILE="$TEST_DIR/bookmarks.json"
echo '{"bookmarks":[]}' > "$TEST_BOOKMARKS_FILE"
export BOOKMARKS_DIR="$TEST_DIR"

# Run command
../bookmarks.sh add "Test" cmd "echo test"

# Check result
cat "$TEST_BOOKMARKS_FILE"

# Cleanup
rm -rf "$TEST_DIR"
```

### Getting Help

If you encounter issues not covered here:

1. Check existing test files for examples
2. Review the test framework source (`test_framework.sh`)
3. Open an issue on GitHub with:
   - Test command that's failing
   - Error output
   - Platform and shell version
   - Steps to reproduce

## Additional Resources

- [README.md](../README.md) - General project documentation
- [.github/copilot-instructions.md](../.github/copilot-instructions.md) - Development guidelines
- [GitHub Actions Workflow](../.github/workflows/test.yml) - CI configuration
- [jq Manual](https://jqlang.github.io/jq/manual/) - JSON processing
- [fzf Documentation](https://github.com/junegunn/fzf) - Fuzzy finder
- [kcov Documentation](https://github.com/SimonKagstrom/kcov) - Coverage tool

## Contributing Tests

When contributing new tests:

1. Follow the test template and naming conventions
2. Ensure tests are isolated and repeatable
3. Test both success and failure cases
4. Include descriptive test names
5. Update this documentation if adding new patterns or techniques
6. Ensure all tests pass before submitting PR

**Test Requirements for Pull Requests:**
- All existing tests must pass
- New features must include tests
- Coverage should not decrease significantly
- Tests should be documented if they use novel approaches
