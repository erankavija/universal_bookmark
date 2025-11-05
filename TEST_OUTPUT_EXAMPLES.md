# Enhanced Test Output Examples

This document showcases the enhanced test output features implemented for Universal Bookmarks.

## Command Line Output Examples

### Basic Test Execution

```bash
$ ./test_demo_enhanced.sh

Running test: Fast passing test [1/10]
✓ Fast passing test (0.10s)

Running test: Quick validation test [2/10]
✓ Quick validation test (0.00s)

Running test: Slow database query simulation [3/10]
✓ Slow database query simulation (1.50s) ⚠ SLOW

Running test: Long-running integration test [4/10]
✓ Long-running integration test (2.00s) ⚠ SLOW
```

### Test Failure with Context

```bash
Running test: Invalid input handling [6/10]
✗ Invalid input handling (0.00s)
  Expected: exit code 1
  Actual:   exit code 0
  Output:
    Processing invalid input...
  Hint:
    Command succeeded but was expected to fail - check input validation
```

### Test Suite Summary

```bash
Demo Test Summary:
  Tests passed: 9
  Tests failed: 1
  Total tests: 10
```

## Report Generation

### Enable Reports

```bash
# Generate reports for all test suites
$ ./run_tests.sh --reports

# Or set environment variable
$ GENERATE_REPORTS=true ./test_bookmarks.sh
```

### Generated Files

Reports are automatically created in the `test-reports/` directory:

```
test-reports/
├── junit-test_bookmarks.xml      # CI integration format
├── report-test_bookmarks.json    # Programmatic access
├── report-test_bookmarks.html    # Human-readable format
├── junit-test_frecency.xml
├── report-test_frecency.json
└── report-test_frecency.html
```

## Report Formats

### JUnit XML (for CI Integration)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="test_bookmarks" tests="25" failures="0" errors="0" time="0.20">
  <testcase name="Add URL bookmark" time="0.03">
  </testcase>
  <testcase name="Add script bookmark" time="0.02">
  </testcase>
  ...
</testsuite>
```

### JSON (for Tooling)

```json
{
  "suite": "test_bookmarks",
  "summary": {
    "total": 25,
    "passed": 25,
    "failed": 0,
    "totalTime": "0.20"
  },
  "tests": [
    {
      "name": "Add URL bookmark",
      "result": "PASS",
      "duration": 0.03,
      "exitCode": 0,
      "expectedCode": 0,
      "slow": false
    },
    ...
  ]
}
```

### HTML Report Features

The HTML report includes:
- **Visual Summary Cards**: Total tests, passed, failed, and total time
- **Detailed Test Table**: Test name, result, duration, and exit code
- **Slow Test Indicators**: Orange warning for tests exceeding 1 second
- **Color-Coded Results**: Green for passed, red for failed
- **Responsive Design**: Works on desktop and mobile devices

## Feature Highlights

### 1. Timing Information
- Every test shows execution duration in seconds
- Millisecond precision for accurate measurements
- Slow test warnings (⚠ SLOW) for tests > 1 second

### 2. Progress Indicators
- Clear [current/total] count for each test
- Helps track progress through long test suites
- No surprises about how many tests remain

### 3. Improved Failure Output
- Shows expected vs actual exit codes
- Displays test output context (first 10 lines)
- Provides helpful hints based on common failure patterns:
  - Exit code 0 but expected failure → Check input validation
  - Exit code 127 → Command not found
  - Exit code 126 → Permission denied
  - Exit code > 128 → Process terminated by signal

### 4. Report Generation
- **JUnit XML**: Standard format for CI/CD integration (Jenkins, GitHub Actions, etc.)
- **JSON**: Structured data for scripts and automation tools
- **HTML**: Beautiful, human-readable reports for developers
- All formats generated simultaneously
- Reports stored in `test-reports/` directory (gitignored)

## Usage Examples

### Run All Tests with Reports

```bash
$ ./run_tests.sh --reports

╔════════════════════════════════════════════════╗
║                                                ║
║     Universal Bookmarks Test Runner            ║
║                                                ║
╚════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Running test suite: test_bookmarks
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Running test: Add URL bookmark [1/25]
✓ Add URL bookmark (0.03s)
...

Generating test reports...
✓ JUnit XML: ./test-reports/junit-test_bookmarks.xml
✓ JSON:      ./test-reports/report-test_bookmarks.json
✓ HTML:      ./test-reports/report-test_bookmarks.html
```

### View HTML Report

```bash
# Open in browser (Linux)
$ xdg-open test-reports/report-test_bookmarks.html

# Open in browser (macOS)
$ open test-reports/report-test_bookmarks.html
```

### Query JSON Report

```bash
# Get summary statistics
$ jq '.summary' test-reports/report-test_bookmarks.json

# List slow tests
$ jq '.tests[] | select(.slow == true) | .name' test-reports/report-test_bookmarks.json

# List failed tests
$ jq '.tests[] | select(.result == "FAIL") | .name' test-reports/report-test_bookmarks.json
```

## Benefits

### For Developers
- **Immediate Feedback**: See test duration and progress in real-time
- **Quick Failure Diagnosis**: Hints point to common problems
- **Visual Reports**: Beautiful HTML reports for sharing with team

### For CI/CD
- **Standard Format**: JUnit XML works with all major CI systems
- **Automation Ready**: JSON format for scripting and metrics
- **Performance Tracking**: Identify slow tests that need optimization

### For Project Management
- **Clear Metrics**: Total tests, pass rate, execution time
- **Trend Analysis**: Track test performance over time
- **Quality Gates**: Fail builds on test failures or slow tests

## UNIX Philosophy

The implementation follows UNIX principles:
- **Composable Functions**: Small, focused functions that do one thing well
- **Pipeline-Friendly**: Reports can be piped to other tools
- **Text Streams**: All formats are text-based and readable
- **Separation of Concerns**: Data extraction, transformation, and presentation are separate
- **Tool Reusability**: jq for JSON, sed/awk for text processing

## Backward Compatibility

All enhancements are backward compatible:
- Tests run normally without `--reports` flag
- Existing test files work unchanged
- Report generation is opt-in via environment variable or flag
- No breaking changes to test framework API
