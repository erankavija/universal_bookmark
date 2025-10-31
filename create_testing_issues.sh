#!/bin/bash

#=============================================================================
# GitHub Issue Creator for Testing Improvements
# 
# This script helps create GitHub issues for the testing improvements
# outlined in TESTING_IMPROVEMENTS.md
#=============================================================================

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m'

REPO_OWNER="erankavija"
REPO_NAME="universal_bookmark"

echo -e "${BLUE}GitHub Issue Creator for Testing Improvements${NC}"
echo ""
echo "This script will help create GitHub issues for proposed testing improvements."
echo "You'll need the GitHub CLI (gh) installed and authenticated."
echo ""

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo -e "${YELLOW}Warning: GitHub CLI (gh) is not installed.${NC}"
    echo "Install it from: https://cli.github.com/"
    echo ""
    echo "Alternatively, you can manually create issues using the content below."
    echo ""
    read -p "Continue to show issue templates? [y/N] " response
    if [[ ! $response =~ ^[Yy]$ ]]; then
        exit 0
    fi
    MANUAL_MODE=true
else
    MANUAL_MODE=false
    echo -e "${GREEN}✓ GitHub CLI detected${NC}"
    echo ""
fi

# Issue templates
declare -a ISSUES

# Issue 1: Test Coverage Reporting
ISSUES[0]=$(cat <<'EOF'
{
  "title": "Add test coverage reporting",
  "body": "## Description\n\nImplement test coverage reporting to provide visibility into what code is covered by tests and what isn't.\n\n## Proposed Solution\n\n- Use `kcov` or similar tool for bash script coverage\n- Generate coverage reports for each test run\n- Add coverage percentage to test summary\n- Upload coverage reports to Codecov or similar service\n- Add coverage badge to README\n\n## Benefits\n\n- Identify untested code paths\n- Set coverage goals and track progress\n- Prevent coverage regression\n- Build confidence in test suite\n\n## Implementation Ideas\n\n```bash\n# Example using kcov\nkcov --exclude-pattern=/usr coverage/ ./run_tests.sh\n\n# Coverage badge in README\n![Coverage](https://codecov.io/gh/erankavija/universal_bookmark/branch/main/graph/badge.svg)\n```\n\n## References\n\n- kcov: https://github.com/SimonKagstrom/kcov\n- Codecov: https://codecov.io/\n\n## Related\n\nSee TESTING_IMPROVEMENTS.md for more details.",
  "labels": ["enhancement", "testing", "ci"],
  "priority": "medium"
}
EOF
)

# Issue 2: Parallel Test Execution
ISSUES[1]=$(cat <<'EOF'
{
  "title": "Implement parallel test execution",
  "body": "## Description\n\nCurrently, all test suites run sequentially. Implement parallel test execution for faster feedback, especially in CI.\n\n## Proposed Solution\n\n- Implement `--parallel` flag in `run_tests.sh`\n- Use GNU parallel or background jobs to run test suites simultaneously\n- Ensure test isolation (already using separate temp dirs)\n- Collect and aggregate results from parallel runs\n- Handle output synchronization to avoid garbled logs\n\n## Implementation Ideas\n\n```bash\n# Using GNU parallel\nparallel --jobs 4 --tag ::: ./test_bookmarks.sh ./test_frecency.sh ...\n\n# Or using background jobs\nfor test in test_*.sh; do\n    ./\"$test\" > \"$test.log\" 2>&1 &\ndone\nwait\n```\n\n## Considerations\n\n- Test suites must be completely isolated (already are)\n- May be harder to debug failures\n- Need to aggregate results from multiple runs\n- Some developers may not have GNU parallel installed\n\n## Expected Improvement\n\nReduce test execution time by 60-70% (from ~30s to ~10s)\n\n## Related\n\nSee TESTING_IMPROVEMENTS.md for more details.",
  "labels": ["enhancement", "testing", "performance"],
  "priority": "low"
}
EOF
)

# Issue 3: CI Caching and Optimization
ISSUES[2]=$(cat <<'EOF'
{
  "title": "Optimize CI with caching",
  "body": "## Description\n\nThe CI workflow installs dependencies every time. Implement caching to speed up CI runs.\n\n## Proposed Solution\n\n### 1. Cache fzf installation\n\n```yaml\n- name: Cache fzf\n  uses: actions/cache@v3\n  with:\n    path: ~/.fzf\n    key: ${{ runner.os }}-fzf-${{ hashFiles('**/*.sh') }}\n    restore-keys: |\n      ${{ runner.os }}-fzf-\n```\n\n### 2. Cache apt packages\n\n```yaml\n- name: Cache apt packages\n  uses: actions/cache@v3\n  with:\n    path: /var/cache/apt\n    key: ${{ runner.os }}-apt\n```\n\n### 3. Optimize checkout\n\nUse shallow clone:\n```yaml\n- uses: actions/checkout@v4\n  with:\n    fetch-depth: 1\n```\n\n## Expected Benefits\n\n- Reduce CI run time by 30-50%\n- Faster feedback on pull requests\n- Reduced GitHub Actions minutes usage\n\n## Related\n\nSee TESTING_IMPROVEMENTS.md for more details.",
  "labels": ["enhancement", "ci", "performance"],
  "priority": "high"
}
EOF
)

# Issue 4: Enhanced Test Output Formatting
ISSUES[3]=$(cat <<'EOF'
{
  "title": "Enhance test output formatting",
  "body": "## Description\n\nImprove test output to make it easier to scan results and identify failures quickly.\n\n## Proposed Improvements\n\n### 1. Add test timing information\n- Show duration for individual tests\n- Highlight slow tests (>1s)\n\n### 2. Improve failure output\n- Show context around failures\n- Diff expected vs actual for failed assertions\n- Add \"quick fix\" suggestions\n\n### 3. Add progress indicators\n- Show test progress (Test 5/25)\n- Add spinner for long-running tests\n\n### 4. Generate test report files\n- JUnit XML format for CI integration\n- HTML reports for human viewing\n- JSON format for tooling\n\n## Example Output\n\n```\nRunning test: Add URL bookmark [1/25]\n✓ Add URL bookmark (0.3s)\n\nRunning test: Complex query test [15/25]\n✓ Complex query test (1.2s) ⚠ SLOW\n\nRunning test: Invalid input handling [20/25]\n✗ Invalid input handling (0.1s)\n  Expected: exit code 1\n  Actual:   exit code 0\n  Hint: Check input validation in add_bookmark()\n```\n\n## Related\n\nSee TESTING_IMPROVEMENTS.md for more details.",
  "labels": ["enhancement", "testing", "dx"],
  "priority": "low"
}
EOF
)

# Issue 5: Pre-commit Hooks for Testing
ISSUES[4]=$(cat <<'EOF'
{
  "title": "Add pre-commit hooks for testing",
  "body": "## Description\n\nAdd git hooks to run relevant tests before commits to catch issues early.\n\n## Proposed Solution\n\n### 1. Create `.githooks/pre-commit`\n\n```bash\n#!/bin/bash\n# Run tests on changed files only\nCHANGED_FILES=$(git diff --cached --name-only | grep \"\\.sh$\")\nif [ -n \"$CHANGED_FILES\" ]; then\n    ./run_tests.sh -f  # Fail-fast mode\nfi\n```\n\n### 2. Setup script integration\n\n- Update `setup.sh` to install git hooks\n- Add option to skip hook installation\n\n### 3. Fast mode for hooks\n\n- Only run tests related to changed files\n- Skip slow integration tests\n- Add `--hook` mode to `run_tests.sh`\n\n## Configuration Example\n\n```bash\n# In setup.sh\nread -p \"Install git hooks for automatic testing? [y/N] \" response\nif [[ $response =~ ^[Yy]$ ]]; then\n    git config core.hooksPath .githooks\nfi\n```\n\n## Benefits\n\n- Catch test failures before pushing\n- Encourage test-driven development\n- Reduce CI failures\n- Faster development feedback\n\n## Related\n\nSee TESTING_IMPROVEMENTS.md for more details.",
  "labels": ["enhancement", "testing", "dx"],
  "priority": "medium"
}
EOF
)

# Issue 6: Test Documentation Improvements
ISSUES[5]=$(cat <<'EOF'
{
  "title": "Improve test documentation",
  "body": "## Description\n\nEnhance documentation around testing to help contributors write and run tests effectively.\n\n## Proposed Solution\n\n### 1. Create `TESTING.md`\n\n- How to run tests\n- How to write new tests\n- Testing best practices\n- Troubleshooting test failures\n\n### 2. Add inline documentation\n\n- Document test framework functions\n- Add examples to test files\n- Explain test patterns\n\n### 3. Update README\n\n- Add CI status badge\n- Add test coverage badge (when implemented)\n- Expand testing section\n- Link to detailed testing guide\n\n### 4. Create test templates\n\n- Template for new test files\n- Template for test cases\n- Examples of good tests\n\n## Example Structure\n\n```markdown\n# Testing Guide\n\n## Quick Start\n./run_tests.sh\n\n## Writing Tests\n1. Create new test file: test_myfeature.sh\n2. Source test framework\n3. Implement run_test_suite()\n4. Add tests using run_test()\n\n## Test Patterns\n- Test both success and failure cases\n- Use descriptive test names\n- Test edge cases (empty input, special chars)\n- Clean up test artifacts\n```\n\n## Related\n\nSee TESTING_IMPROVEMENTS.md for more details.",
  "labels": ["documentation", "testing"],
  "priority": "medium"
}
EOF
)

# Issue 7: Cross-Platform Testing
ISSUES[6]=$(cat <<'EOF'
{
  "title": "Add cross-platform testing (Linux, macOS, Windows/WSL)",
  "body": "## Description\n\nEnsure tests pass on multiple platforms (Linux, macOS, WSL) by adding matrix testing to CI.\n\n## Proposed Solution\n\n### 1. Update CI workflow\n\n```yaml\nstrategy:\n  matrix:\n    os: [ubuntu-latest, macos-latest, windows-latest]\nruns-on: ${{ matrix.os }}\n```\n\n### 2. Handle platform differences\n\n- Date command differences\n- Sed/awk variations\n- Path separators\n- Default shell differences\n\n### 3. Platform-specific tests\n\n- Test file type execution on each platform\n- Test URL opening on each platform\n- Test editor integration\n\n### 4. Document platform support\n\n- List supported platforms\n- Note any platform-specific limitations\n- Provide troubleshooting for each platform\n\n## Expected Challenges\n\n- Windows/WSL bash differences\n- macOS command variations (BSD vs GNU)\n- Different default shells\n- Path handling differences\n\n## Related\n\nSee TESTING_IMPROVEMENTS.md for more details.",
  "labels": ["enhancement", "testing", "ci", "cross-platform"],
  "priority": "medium"
}
EOF
)

# Issue 8: Performance Regression Testing
ISSUES[7]=$(cat <<'EOF'
{
  "title": "Add performance regression testing",
  "body": "## Description\n\nAdd tests to ensure performance doesn't regress as features are added.\n\n## Proposed Solution\n\n### 1. Benchmark key operations\n\n```bash\nbenchmark_add_operation() {\n    start=$(date +%s%N)\n    ./bookmarks.sh add \"Test\" url \"http://example.com\"\n    end=$(date +%s%N)\n    duration=$(( (end - start) / 1000000 ))\n    \n    if [ $duration -gt 100 ]; then\n        echo \"Warning: Add operation took ${duration}ms (threshold: 100ms)\"\n    fi\n}\n```\n\n### 2. Test with large datasets\n\n- Create bookmarks file with 1000+ entries\n- Measure search performance\n- Test list/display performance\n- Verify frecency calculation speed\n\n### 3. Track performance over time\n\n- Store benchmark results\n- Compare against baseline\n- Alert on significant regression (>20% slower)\n\n### 4. Add performance tests to CI\n\n- Run on every PR\n- Only fail on major regression\n- Track trends over time\n\n## Key Operations to Benchmark\n\n- Add bookmark (target: <100ms)\n- Search all bookmarks (target: <200ms)\n- List bookmarks (target: <50ms)\n- Frecency calculation (target: <10ms per bookmark)\n\n## Related\n\nSee TESTING_IMPROVEMENTS.md for more details.",
  "labels": ["enhancement", "testing", "performance"],
  "priority": "low"
}
EOF
)

# Function to create issues
create_issues() {
    local count=0
    
    for issue_json in "${ISSUES[@]}"; do
        count=$((count + 1))
        
        # Parse JSON
        title=$(echo "$issue_json" | jq -r '.title')
        body=$(echo "$issue_json" | jq -r '.body')
        labels=$(echo "$issue_json" | jq -r '.labels | join(",")')
        
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}Issue $count: $title${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        if [ "$MANUAL_MODE" = true ]; then
            echo ""
            echo "Title: $title"
            echo "Labels: $labels"
            echo ""
            echo "Body:"
            echo "$body" | sed 's/\\n/\n/g'
            echo ""
            echo "---"
            echo ""
        else
            # Create issue with gh
            if gh issue create \
                --repo "$REPO_OWNER/$REPO_NAME" \
                --title "$title" \
                --body "$(echo "$body" | sed 's/\\n/\n/g')" \
                --label "$labels"; then
                echo -e "${GREEN}✓ Issue created successfully${NC}"
            else
                echo -e "${YELLOW}⚠ Failed to create issue${NC}"
            fi
            echo ""
        fi
    done
    
    echo -e "${GREEN}Processed $count issues${NC}"
}

# Main execution
if [ "$MANUAL_MODE" = true ]; then
    echo "=== Manual Mode ==="
    echo "Copy and paste the following into GitHub to create issues manually:"
    echo ""
else
    echo "Creating issues automatically using GitHub CLI..."
    echo ""
    read -p "Create ${#ISSUES[@]} issues in $REPO_OWNER/$REPO_NAME? [y/N] " response
    if [[ ! $response =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
    echo ""
fi

create_issues

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Done!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
