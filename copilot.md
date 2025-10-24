# Copilot Development Guide for Universal Bookmarks

This document outlines the best practices, conventions, and guidelines followed in the Universal Bookmarks project to maintain code quality, consistency, and maintainability.

## Project Overview

Universal Bookmarks is a shell script-based bookmark management system that stores bookmarks in JSON format. It supports various bookmark types (URLs, scripts, SSH connections, files, etc.) and provides an intuitive interface using `fzf` for fuzzy searching.

**Key Technologies:**
- Shell scripting (Bash)
- JSON for data storage (`jq` for processing)
- `fzf` for interactive fuzzy finding
- GitHub Actions for CI/CD

## Code Style and Conventions

### Shell Script Structure

The project follows a well-organized structure with clear section headers:

```bash
#!/bin/bash
set -euo pipefail

#=============================================================================
# CONSTANTS AND CONFIGURATION
#=============================================================================

#=============================================================================
# UTILITY FUNCTIONS
#=============================================================================

#=============================================================================
# BOOKMARK MANAGEMENT FUNCTIONS
#=============================================================================

#=============================================================================
# USER INTERFACE FUNCTIONS
#=============================================================================

#=============================================================================
# BACKUP AND RESTORE FUNCTIONS
#=============================================================================

#=============================================================================
# HOOK SYSTEM
#=============================================================================
```

### Error Handling

Always use strict error handling:
```bash
set -euo pipefail  # Exit on error, unset variables, and pipe failures
```

### Color Coding

Use consistent color definitions for output:
```bash
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color
```

Color usage conventions:
- **RED**: Errors and destructive actions
- **GREEN**: Success messages
- **YELLOW**: Warnings and important notices
- **BLUE**: Informational messages and headers
- **CYAN**: Highlighted values (file paths, bookmark descriptions, etc.)

### Function Documentation

Document functions with clear comments:
```bash
# Function name and purpose
# Args: $1 - parameter description, $2 - parameter description
# Returns: description of return value or output
function_name() {
    local param1="$1"
    local param2="$2"
    # Implementation
}
```

### Variable Naming

- Use `readonly` for constants
- Use lowercase with underscores for variables: `bookmark_file`, `test_dir`
- Use descriptive names that explain the purpose
- Declare local variables with `local` keyword

### jq Performance Optimization

Optimize jq usage by combining operations into single calls:

**Bad:**
```bash
local description=$(echo "$bookmark" | jq -r '.description')
local type=$(echo "$bookmark" | jq -r '.type')
local command=$(echo "$bookmark" | jq -r '.command')
```

**Good:**
```bash
local values=$(echo "$bookmark" | jq -r '[.description, .type, .command] | @tsv')
IFS=$'\t' read -r description type command <<< "$values"
```

## Testing Requirements

### Test Structure

All new features must include tests. The test suite structure:

```bash
# Setup test environment with temporary directory
setup_test_env()

# Run individual test with expected exit code
run_test "Test name" "command" [expected_exit_code]

# Cleanup after tests
cleanup_test_env()
```

### Test Conventions

1. **Isolation**: Each test runs in a temporary directory
2. **Non-interactive**: Use `-y` flag for commands that require confirmation
3. **Verification**: Check both exit codes and actual results
4. **Coverage**: Test both success and failure scenarios

Example test:
```bash
run_test "Add URL bookmark" \
    "./bookmarks.sh add 'Test URL' url 'echo \"This is a URL test\"'"
```

### Running Tests

```bash
# Run full test suite
./test_bookmarks.sh

# Tests should pass on CI (GitHub Actions)
```

## Development Workflow

### Adding New Features

1. **Plan**: Consider the impact on existing functionality
2. **Implement**: Follow the modular function structure
3. **Test**: Add tests for new functionality
4. **Document**: Update README.md with new features/commands
5. **Hooks**: Consider if hook points are needed for extensibility

### Modifying Existing Code

When modifying code, follow these principles:

1. **Maintain backward compatibility**: Don't break existing command-line interfaces
2. **Preserve functionality**: All existing tests must pass
3. **Optimize carefully**: Performance improvements should maintain correctness
4. **Update documentation**: Reflect changes in README.md

### Code Review Checklist

- [ ] Follows project structure and conventions
- [ ] Includes appropriate error handling
- [ ] Uses consistent color coding for output
- [ ] Optimizes jq usage (single-pass operations)
- [ ] Includes tests for new functionality
- [ ] Updates documentation (README.md)
- [ ] Maintains backward compatibility
- [ ] Passes all existing tests

## Modularity and Reusability

### Utility Functions

Extract common operations into reusable utility functions:

```bash
# Good examples from the codebase:
- get_bookmark_by_id_or_desc()
- bookmark_exists()
- validate_bookmarks_file()
- get_user_confirmation()
- validate_bookmark_input()
```

### UI Functions

Separate display logic from business logic:

```bash
# Good examples:
- format_bookmarks_for_display()
- extract_description_from_fzf_line()
- display_bookmarks_by_type()
- display_detailed_bookmarks()
```

## Hook System

The project uses a hook system for extensibility. When adding new operations:

1. Consider if a hook point is appropriate
2. Document hook arguments in the README
3. Provide example hooks in `examples/` directory
4. Hook names follow the pattern: `after_<operation>.sh`

Hook execution:
```bash
run_hook "after_add"
run_hook "after_edit"
run_hook "after_delete"
```

## User Experience Best Practices

### Interactive vs Non-Interactive Modes

Support both modes:
- **Interactive**: Use `fzf` for selection, prompt for input
- **Non-interactive**: Accept command-line arguments, respect `-y` flag

Example:
```bash
# Interactive: No arguments, use fzf
./bookmarks.sh edit

# Non-interactive: Provide all arguments
./bookmarks.sh edit "Bookmark Description"
```

### Error Messages

- Clear and actionable error messages
- Use stderr for errors: `echo -e "${RED}Error${NC}" >&2`
- Suggest solutions when possible
- Exit with appropriate exit codes

### Validation

Validate input early:
- Check required parameters
- Validate JSON file integrity before operations
- Confirm destructive actions (unless `-y` flag is used)

## Dependencies Management

### Required Dependencies

- `jq`: JSON processing
- `fzf`: Fuzzy finding

### Dependency Checks

Check dependencies at script startup:
```bash
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed.${NC}"
    exit 1
fi
```

### Cross-Platform Compatibility

Detect platform differences:
```bash
# Detect OS for opener command
if command -v xdg-open &> /dev/null; then
    open_cmd="xdg-open"
elif command -v open &> /dev/null; then
    open_cmd="open"  # macOS
fi
```

## CI/CD Integration

### GitHub Actions

The project uses GitHub Actions for automated testing:
- Runs on push to `main` branch
- Runs on pull requests
- Installs dependencies (`jq`, `fzf`)
- Executes test suite

Configuration: `.github/workflows/test.yml`

### Test Requirements for PR

All pull requests must:
1. Pass the automated test suite
2. Maintain or improve test coverage
3. Include documentation updates

## Documentation Standards

### README.md Structure

Maintain the following sections:
1. Project description and features
2. Installation instructions (automatic and manual)
3. Usage examples (basic and advanced)
4. Bookmark types and execution methods
5. Hook system documentation
6. Testing instructions
7. Troubleshooting guide
8. Dependencies

### Code Comments

- Explain the "why" not the "what"
- Document complex logic or non-obvious solutions
- Keep comments up-to-date with code changes
- Use section headers for code organization

### Example Hooks

Provide well-documented example hooks:
- Include clear comments explaining arguments
- Show practical use cases
- Keep examples simple and understandable

## Performance Considerations

### jq Optimization

- Combine multiple jq operations into single calls
- Use `@tsv` format for multi-value extraction
- Avoid unnecessary JSON parsing

### File Operations

- Validate JSON file once per operation
- Use temporary files for complex transformations
- Clean up temporary files properly

### fzf Integration

- Format data once before passing to fzf
- Use `--ansi` flag for colored output
- Use `--filter` mode for non-interactive searching

## Security Best Practices

1. **Input Validation**: Validate all user input
2. **Command Execution**: Use `eval` carefully, understand the risks
3. **File Permissions**: Set appropriate permissions on hooks and scripts
4. **JSON Validation**: Check JSON integrity before operations
5. **Backup Safety**: Validate backup files before restoration

## Extensibility Patterns

### Adding New Bookmark Types

When adding new bookmark types:
1. Add to `VALID_TYPES` array
2. Implement execution logic in `execute_bookmark_by_type()`
3. Update documentation with type description
4. Add examples to README

### Adding New Commands

When adding new commands:
1. Implement the function following naming conventions
2. Add case handler in main command parsing
3. Update `show_help()` function
4. Add tests for the new command
5. Document in README

## Troubleshooting for Developers

### Common Issues

1. **JSON Parse Errors**: Use `validate_bookmarks_file()` to check integrity
2. **fzf Not Found**: Ensure PATH includes fzf binary location
3. **Hook Not Executing**: Check file permissions and existence
4. **Test Failures**: Ensure temporary directory cleanup works properly

### Debugging Tips

- Use `set -x` for verbose execution
- Check exit codes: `$?`
- Test jq queries independently: `jq '.' bookmarks.json`
- Test in isolated environment: `BOOKMARKS_DIR=/tmp/test`

## AI-Generated Content

This project includes AI-generated content. When working with or modifying AI-generated code:

1. **Review carefully**: Verify logic and correctness
2. **Test thoroughly**: AI-generated code needs validation
3. **Document clearly**: Explain any non-obvious solutions
4. **Maintain consistency**: Ensure new code matches project style

## Contributing Guidelines

### Before Starting

1. Read this document thoroughly
2. Review existing code to understand patterns
3. Check open issues for planned work
4. Run tests locally before submitting PR

### Pull Request Process

1. Create a feature branch: `feature/description`
2. Make focused, atomic commits
3. Write clear commit messages
4. Ensure all tests pass
5. Update documentation
6. Submit PR with clear description

### Commit Message Format

```
Short summary (50 chars or less)

More detailed explanation if needed. Explain what and why,
not how. Reference issues if applicable.

- List specific changes
- Use bullet points for multiple items
```

## Resources

- **jq Manual**: https://stedolan.github.io/jq/manual/
- **fzf GitHub**: https://github.com/junegunn/fzf
- **Bash Best Practices**: https://google.github.io/styleguide/shellguide.html
- **ShellCheck**: https://www.shellcheck.net/ (for linting)

## Project Maintenance

### Regular Tasks

- Review and update dependencies
- Monitor and respond to issues
- Update documentation for clarity
- Improve test coverage
- Optimize performance bottlenecks

### Version Updates

When updating versions:
1. Update README with new features
2. Update IMPROVEMENTS.md with technical details
3. Tag releases appropriately
4. Test on multiple platforms if possible

## Future Considerations

When planning new features, consider:

1. **Backward compatibility**: Can existing users upgrade seamlessly?
2. **Cross-platform support**: Does it work on Linux, macOS, and WSL?
3. **Performance impact**: Will it slow down existing operations?
4. **Maintenance burden**: Can the feature be maintained long-term?
5. **User benefit**: Does it solve a real problem?

---

This guide should be updated as the project evolves. When in doubt, follow the patterns established in the existing codebase and prioritize code clarity and maintainability over cleverness.
