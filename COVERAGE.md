# Code Coverage Documentation

## Overview

The Universal Bookmarks project uses `kcov` for code coverage reporting. This document explains how to generate and interpret coverage reports.

## Prerequisites

### Installing kcov

**Ubuntu/Debian:**

kcov is not available in default Ubuntu repositories. You need to build from source:

```bash
# Install build dependencies
sudo apt-get update
sudo apt-get install -y cmake g++ pkg-config libcurl4-openssl-dev libelf-dev libdw-dev binutils-dev libiberty-dev

# Clone and build kcov
git clone --depth 1 --branch v43 https://github.com/SimonKagstrom/kcov.git
cd kcov
mkdir build
cd build
cmake ..
make
sudo make install
```

**macOS:**
```bash
brew install kcov
```

**Alternative - Build from Source (any platform):**
```bash
git clone https://github.com/SimonKagstrom/kcov.git
cd kcov
mkdir build
cd build
cmake ..
make
sudo make install
```

## Generating Coverage Reports

### Local Coverage Collection

Run all tests with coverage:
```bash
./run_tests.sh --coverage
```

Or use the short form:
```bash
./run_tests.sh -c
```

### Run Specific Tests with Coverage

You can combine coverage with test filtering:
```bash
./run_tests.sh --coverage frecency
```

This will run only tests matching "frecency" and collect coverage.

## Understanding Coverage Reports

### Console Output

When running tests with coverage, you'll see:

1. **Coverage Collection Progress**: Shows which test suite is being instrumented
2. **Coverage Summary**: Displays line and branch coverage percentages
3. **Coverage Report Location**: Path to HTML report and XML file

Example output:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
COVERAGE SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Line Coverage:   85.3%
  Branch Coverage: 72.1%

  Coverage Report: ./coverage/merged/index.html
  Cobertura XML:   ./coverage/merged/cobertura.xml

✓ Excellent coverage! (>= 80%)
```

### HTML Reports

Open the HTML report in your browser:
```bash
# Linux
xdg-open ./coverage/merged/index.html

# macOS
open ./coverage/merged/index.html
```

The HTML report shows:
- **Line-by-line coverage**: Green for covered lines, red for uncovered
- **Function coverage**: Which functions are tested
- **Branch coverage**: Which conditional branches are executed
- **File-level statistics**: Coverage percentage per file

### Coverage Thresholds

The project uses the following coverage quality indicators:

- **>= 80%**: Excellent coverage ✓ (green)
- **>= 60%**: Good coverage ⚠ (yellow)
- **< 60%**: Needs improvement ⚠ (red)

## CI/CD Integration

### GitHub Actions

Coverage is automatically collected and uploaded to Codecov when:
- Code is pushed to the `main` branch
- Pull requests are opened or updated

The workflow:
1. Installs kcov
2. Runs all tests with coverage
3. Uploads coverage data to Codecov
4. Displays coverage in PR comments

### Codecov Dashboard

View detailed coverage reports at:
https://codecov.io/gh/ahvth/universal_bookmark

Features:
- Coverage trends over time
- Coverage by file and function
- Pull request coverage impact
- Coverage sunburst and icicle charts

## Coverage Files

### Directory Structure

```
coverage/
├── test_framework/          # Coverage from test_framework.sh
│   ├── cobertura.xml
│   └── index.html
├── test_bookmarks/          # Coverage from test_bookmarks.sh
│   ├── cobertura.xml
│   └── index.html
├── test_frecency/           # Coverage from test_frecency.sh
│   ├── cobertura.xml
│   └── index.html
├── ...                      # Other test suites
├── merged/                  # Combined coverage from all tests
│   ├── cobertura.xml        # XML format for CI tools
│   └── index.html           # Interactive HTML report
└── summary.txt              # Plain text summary
```

### Cobertura XML

The `cobertura.xml` file is used for:
- CI/CD integration
- Coverage badges
- Automated coverage analysis
- Third-party coverage tools

### Coverage Summary

The `summary.txt` file contains:
```
COVERAGE_LINE_RATE=85.3
COVERAGE_BRANCH_RATE=72.1
```

This is used by `run_tests.sh` to display coverage in the test summary.

## Improving Coverage

### Identifying Uncovered Code

1. Open the HTML report
2. Look for red-highlighted lines
3. Check which functions/branches are uncovered
4. Write tests to exercise those code paths

### Common Uncovered Areas

- Error handling paths
- Edge cases and boundary conditions
- Rarely-used commands or options
- Platform-specific code

### Writing Tests for Coverage

Example: If `bookmarks.sh` has an uncovered error path:

```bash
# In test_bookmarks.sh
run_test "Test error handling for invalid JSON" \
    "./bookmarks.sh list 2>&1 | grep -q 'Error'" \
    1  # Expect exit code 1
```

## Troubleshooting

### kcov Not Found

If you see "kcov is not installed":
```bash
# Check if kcov is in PATH
which kcov

# If not, install it (see Prerequisites section)
```

### Coverage Reports Not Generated

Check that:
1. Tests are passing (coverage requires test execution)
2. `bookmarks.sh` path is correct in `run_with_coverage.sh`
3. Write permissions exist for `./coverage` directory

### Low Coverage Numbers

Possible causes:
1. Tests are skipping functionality
2. Non-interactive mode not properly tested
3. Error paths not covered
4. New code added without tests

To improve:
- Review uncovered lines in HTML report
- Add tests for missing scenarios
- Test both success and failure paths

## Best Practices

### Before Committing

Always run tests with coverage before submitting PRs:
```bash
./run_tests.sh --coverage
```

Check that:
- Coverage percentage doesn't decrease
- New code is adequately covered (>70%)
- No new uncovered error paths

### During Development

Use coverage to guide test writing:
1. Write initial tests
2. Check coverage
3. Identify gaps
4. Add targeted tests
5. Repeat until satisfied

### Coverage Goals

- **Overall project**: Aim for 70-80% line coverage
- **Core functions**: Aim for 90%+ coverage
- **Error handling**: Ensure all error paths are tested
- **New features**: Require 70%+ coverage

## Integration with Development Workflow

### Local Development

```bash
# Make changes to bookmarks.sh
vim bookmarks.sh

# Run tests to verify
./run_tests.sh

# Check coverage impact
./run_tests.sh --coverage

# Review HTML report
open ./coverage/merged/index.html
```

### Pull Request Workflow

1. Make changes and add tests
2. Run coverage locally
3. Push to GitHub
4. CI runs tests with coverage
5. Codecov comments on PR with coverage delta
6. Review coverage changes
7. Add tests if coverage decreased

## Advanced Usage

### Coverage for Single Test Suite

To analyze coverage from a specific test suite:
```bash
# Run coverage wrapper directly
./run_with_coverage.sh test_bookmarks.sh

# View results
open ./coverage/test_bookmarks/index.html
```

### Combining Coverage Runs

Coverage from multiple runs is automatically merged by `run_with_coverage.sh`. The merged report shows:
- Lines covered by any test suite
- Maximum coverage across all runs
- Cumulative branch coverage

### Filtering Coverage

The `.codecov.yml` file configures which files to include/exclude:
```yaml
ignore:
  - "test_*.sh"      # Exclude test files
  - "examples/**"    # Exclude examples
  - "setup.sh"       # Exclude setup script
```

## FAQ

**Q: Why does coverage show less than 100%?**
A: Some code paths may be:
- Error conditions that are hard to trigger
- Platform-specific code not tested on Linux
- Defensive programming checks
- Deprecated code paths

**Q: Should I aim for 100% coverage?**
A: No. 70-80% is excellent for shell scripts. Focus on testing important functionality rather than chasing 100%.

**Q: Does coverage slow down tests?**
A: Yes, tests with coverage take 2-3x longer due to instrumentation. Use coverage selectively during development.

**Q: Can I exclude specific lines from coverage?**
A: kcov doesn't support line-level exclusions like some other tools. Focus on testing important code paths.

**Q: How often is coverage data collected?**
A: Coverage is collected:
- On every push to main
- On every PR
- When you run `./run_tests.sh --coverage` locally

## Resources

- [kcov Documentation](https://github.com/SimonKagstrom/kcov)
- [Codecov Documentation](https://docs.codecov.io/)
- [Cobertura Format](http://cobertura.github.io/cobertura/)
- [Shell Script Testing Best Practices](https://github.com/ahvth/universal_bookmark#testing)

## See Also

- [README.md](../README.md) - General project documentation
- [run_tests.sh](../run_tests.sh) - Test runner
- [run_with_coverage.sh](../run_with_coverage.sh) - Coverage collection script
- [.github/workflows/test.yml](../.github/workflows/test.yml) - CI configuration
