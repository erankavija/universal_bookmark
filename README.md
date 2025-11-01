# Universal Bookmarks

Shell script to manage bookmarks in a JSON format. A bookmark can be anything from a URL to a script that you want to run frequently.

Note: The content is mostly AI generated.

## Features

- **Rich Bookmark Data**: Store descriptions, commands, types, tags, and notes
- **Intelligent Sorting**: Frecency-based sorting (frequency + recency) shows your most-used bookmarks first
- **Intuitive Management**: Add, edit, update, delete, and mark bookmarks as obsolete
- **Advanced Searching**: Fuzzy search through bookmarks with colored output
- **Tag Support**: Organize and search bookmarks by tags
- **Backup & Restore**: Built-in backup/restore functionality
- **Hooks**: Custom extensibility with hook scripts
- **Cross-Shell Compatible**: Works with Bash, Zsh, Fish, and others

A bookmark is stored in a JSON file with fields for ID, description, type, command, tags, notes, created date, status, and frecency-based usage tracking. This provides much more flexibility and robustness compared to simple text files.

For example, a bookmark entry in the JSON file looks like this:

```json
{
  "id": "1633042516_a3b2c1",
  "description": "Open ChatGPT",
  "type": "url",
  "command": "xdg-open \"https://chat.openai.com/\"",
  "tags": "ai chat assistant",
  "notes": "OpenAI's ChatGPT interface",
  "created": "2023-10-01 15:30:45",
  "status": "active",
  "access_count": 15,
  "last_accessed": "2025-10-26 23:30:45",
  "frecency_score": 142500
}
```

But you don't need to edit the JSON directly - the script provides a user-friendly interface for managing bookmarks.

## Installation

### Dependencies

Before installation, make sure you have these dependencies:

- **jq**: For JSON processing ([download](https://stedolan.github.io/jq/download/))
- **fzf**: For fuzzy searching ([download](https://github.com/junegunn/fzf#installation))

### Automatic Setup

1. Clone the repository or download the script files.
2. Navigate to the directory containing the scripts.
3. Make the scripts executable:
   ```bash
   chmod +x bookmarks.sh setup.sh
   ```
4. Run the setup script:
   ```bash
   ./setup.sh
   ```
   
The setup script will:
- Check for required dependencies
- Create the necessary directory and file structure (including backups and hooks directories)
- Add the `BOOKMARKS_DIR` environment variable to your shell configuration file
- Add an alias `bookmark` for the bookmarks.sh script
- Install shell completion scripts for Bash and Zsh (with user consent)
- Create example hook scripts
- Provide instructions for using the system

After running the setup script, restart your shell or run `source ~/.zshrc` (or the appropriate configuration file for your shell).

### Manual Setup

If you prefer a manual setup:

1. Clone the repository or download the `bookmarks.sh` script.
2. Make the script executable: `chmod +x bookmarks.sh`.
3. Create directories for your bookmarks:
   ```bash
   mkdir -p "$HOME/.bookmarks/hooks"
   mkdir -p "$HOME/.bookmarks/backups"
   ```
4. Create an initial JSON bookmarks file:
   ```bash
   echo '{"bookmarks":[]}' > "$HOME/.bookmarks/bookmarks.json"
   ```
5. Set the `BOOKMARKS_DIR` environment variable:
   ```bash
   export BOOKMARKS_DIR="$HOME/.bookmarks"
   ```
6. For permanent setup, add the environment variable and alias to your shell configuration file:
   ```bash
   echo 'export BOOKMARKS_DIR="$HOME/.bookmarks"' >> ~/.zshrc
   echo 'alias bookmark="/path/to/bookmarks.sh"' >> ~/.zshrc
   ```
   (Replace `~/.zshrc` with your shell's configuration file if different)

### Shell Completions

Universal Bookmarks provides intelligent tab completion for both Bash and Zsh shells. The completion scripts enable:

- **Command completion**: Tab-complete available commands (add, edit, delete, etc.)
- **Type completion**: Tab-complete bookmark types when adding or updating bookmarks
- **Bookmark description completion**: Tab-complete existing bookmark descriptions
- **Flag completion**: Tab-complete available flags like `-y` or `--yes`

#### Automatic Installation

The `setup.sh` script automatically installs the appropriate completion script for your shell:

- **Bash**: Installs `bookmark-completion.bash` to a bash completion directory
- **Zsh**: Installs `_bookmark` to a zsh completion directory

The setup script will ask for your consent before modifying configuration files and will guide you through the installation process.

#### Manual Installation

If you need to install completions manually:

**For Bash:**
```bash
# Copy the completion script to a bash completion directory
cp completions/bookmark-completion.bash ~/.local/share/bash-completion/completions/bookmark

# Or source it directly in your .bashrc
echo 'source /path/to/universal_bookmark/completions/bookmark-completion.bash' >> ~/.bashrc
```

**For Zsh:**
```bash
# Copy the completion script to a zsh completion directory
mkdir -p ~/.zsh/completions
cp completions/_bookmark ~/.zsh/completions/

# Add the completion directory to fpath in your .zshrc
echo 'fpath=(~/.zsh/completions $fpath)' >> ~/.zshrc
echo 'autoload -Uz compinit && compinit' >> ~/.zshrc
```

After installation, restart your shell or run `source ~/.bashrc` (or `~/.zshrc` for Zsh) to activate completions.

## Usage

After setup, you can use either the `bookmark` command (if you used the setup script) or the full path to `bookmarks.sh`.

### Basic Usage

- **Interactive Selection**: Simply run `bookmark` with no arguments to get a fuzzy search interface
- **Direct Search**: Use `bookmark "search term"` to filter and execute a bookmark
- **List All**: Run `bookmark list` to see all bookmarks in a machine-readable format (one per line with pipe-separated fields)
- **Get Help**: Use `bookmark help` for full documentation

### Non-Interactive Mode

For automation and scripting purposes, Universal Bookmarks supports a non-interactive mode using the `-y` or `--yes` flag. This skips all confirmation prompts and uses default values:

```bash
# Delete a bookmark without confirmation
bookmark -y delete "Description"

# Add a bookmark in a script
bookmark --yes add "Auto Bookmark" cmd "echo 'Automated task'" "automation"

# Works with any command that requires confirmation
bookmark -y obsolete "Old Bookmark"
```

This is particularly useful for:
- **Scripting**: Automate bookmark management in shell scripts
- **CI/CD Pipelines**: Manage bookmarks programmatically
- **Batch Operations**: Process multiple bookmarks without user interaction

The flag can be placed before the command name.

### Managing Bookmarks

#### Adding Bookmarks

You can add bookmarks in two ways:

**Interactive Mode** (no arguments):
```bash
bookmark add
```
This will prompt you for each field (description, type, command, tags, notes).

**Direct Mode** (with arguments):
```bash
bookmark add "Description" type "command" [tags] [notes]
```

Example:
```bash
bookmark add "Open ChatGPT" url 'xdg-open "https://chat.openai.com/"' "ai tools chat" "OpenAI's conversational AI"
```

#### Editing Bookmarks

The default editing mode uses your configured editor (set via `BOOKMARKS_EDITOR` or `EDITOR` environment variables, defaults to `vi`). The editor opens with the bookmark data in a structured format with comments indicating allowed values:

```bash
bookmark edit                    # Uses fzf to select a bookmark
bookmark edit "Description"      # Edit a specific bookmark
```

When the editor opens, you'll see:
```
# description
Your bookmark description
# type (allowed: url pdf script ssh app cmd note folder file edit custom)
url
# command
https://example.com
# tags
your tags here
# notes
Your notes here
```

Edit any field, save, and exit. The bookmark will be updated with your changes. Multiline commands are supported.

Or update directly without using an editor:
```bash
bookmark update "Description" new-type "new-command" "new-tags" "new-notes"
```

#### Creating from Existing Bookmarks

Create a new bookmark based on an existing one using `modify-add`. This opens fzf to select a bookmark as a template, then opens your editor with that bookmark's data. Edit as needed and save to create a new bookmark:

```bash
bookmark modify-add              # Select template, edit, and save as new
```

This is useful when creating similar bookmarks with slight variations.

#### Deleting or Marking Obsolete

Delete a bookmark completely. If no description is provided, fzf will launch to select a bookmark:
```bash
bookmark delete                  # Uses fzf to select a bookmark
bookmark delete "Description"    # Delete a specific bookmark
```

Mark a bookmark as obsolete (without deleting). If no description is provided, fzf will launch to select a bookmark:
```bash
bookmark obsolete                # Uses fzf to select a bookmark
bookmark obsolete "Description"  # Mark a specific bookmark as obsolete
```

### Advanced Features

#### Frecency-Based Sorting

Bookmarks are automatically sorted by "frecency" (frequency + recency), similar to how [z.sh](https://github.com/rupa/z) ranks directories. The system tracks:

- **Access Count**: How many times you've executed each bookmark
- **Last Accessed**: When you last used the bookmark  
- **Frecency Score**: A computed score that prioritizes both frequently-used and recently-used bookmarks

This means your most relevant bookmarks automatically appear at the top when using the fuzzy search interface, making it faster to access your commonly-used commands, URLs, and scripts.

The frecency score is calculated using the formula:
```
frecency = 10000 × access_count × (3.75 / ((0.0001 × age_in_seconds + 1) + 0.25))
```

**Note**: Existing bookmarks are automatically migrated to support frecency tracking with zero initial scores.

#### Detailed View

Show more details about your bookmarks:
```bash
bookmark details
```

#### Listing Bookmarks

List all bookmarks in a machine-readable format that can be piped to other shell utilities:
```bash
bookmark list
```

The output format is:
```
[type] description | command | status | id | tags
```

Each bookmark is output on a single line with fields separated by ` | ` (space-pipe-space). This format makes it easy to:

**Filter by type:**
```bash
bookmark list | grep '\[ssh\]'
```

**Extract commands:**
```bash
bookmark list | awk -F' [|] ' '{print $2}'
```

**Filter by tags:**
```bash
bookmark list | grep 'production'
```

**Filter by status:**
```bash
bookmark list | grep ' active '
```

**Count bookmarks by type:**
```bash
bookmark list | cut -d']' -f1 | cut -d'[' -f2 | sort | uniq -c
```

When output is directed to a terminal, the type field is color-coded for readability. When piped to another command or redirected to a file, colors are automatically removed for clean parsing.

#### Tag Filtering

Filter bookmarks by tag:
```bash
bookmark tag "ai"
```

#### Backup and Restore

Create a backup:
```bash
bookmark backup
```

Restore from a previous backup:
```bash
bookmark restore
```

### Using IDs

You can refer to bookmarks by their unique ID instead of description:
```bash
bookmark edit "1633042516_a3b2c1"
bookmark delete "1633042516_a3b2c1"
bookmark obsolete "1633042516_a3b2c1"
```

This is useful when you have multiple bookmarks with similar descriptions.

## Bookmark Types

The system supports these standard bookmark types, but you can define custom types as needed:

| Type | Description | Example Command | Execution Method |
|------|-------------|----------------|------------------|
| `url` | Web URLs | `"https://chat.openai.com/"` | System default opener (`xdg-open`/`open`) |
| `pdf` | PDF documents | `"$BOOKMARKS_DIR/documents/paper.pdf"` | System default opener (`xdg-open`/`open`) |
| `script` | Executable scripts | `"$BOOKMARKS_DIR/scripts/backup.sh"` | Direct shell execution |
| `ssh` | SSH connections | `ssh user@homeserver.local` | Direct shell execution |
| `app` | Application launchers | `code /path/to/project` | Direct shell execution |
| `cmd` | Custom commands | `curl wttr.in` | Direct shell execution |
| `note` | Notes or text files | `"$BOOKMARKS_DIR/notes/research.txt"` | System default opener or `less` |
| `edit` | Edit files in editor | `"$HOME/todo.txt"` | `$BOOKMARKS_EDITOR` or `$EDITOR` (fallback: `vi`) |
| `folder` | Directory shortcuts | `"$HOME/Projects"` | System default opener (`xdg-open`/`open`) |
| `file` | File shortcuts | `"$HOME/Documents/report.docx"` | System default opener (`xdg-open`/`open`) |
| `custom` | Any other type | *(your custom command)* | Direct shell execution |

### Type-Specific Execution

The bookmark system uses intelligent, type-aware execution:

- **File-based types** (`url`, `pdf`, `folder`, `file`): Opened with your system's default application using `xdg-open` (Linux), `open` (macOS), or `start` (Windows/WSL). Just store the path or URL without wrapping it in `xdg-open`.

  Example:
  ```bash
  bookmark add "ChatGPT" url '"https://chat.openai.com/"'
  bookmark add "Project Folder" folder '"$HOME/Projects"'
  ```

- **Executable types** (`script`, `ssh`, `app`, `cmd`, `custom`): Executed directly in the shell, allowing for complex commands, pipes, and shell features.

  Example:
  ```bash
  bookmark add "Weather" cmd 'curl wttr.in'
  bookmark add "Server" ssh 'ssh user@server.com'
  ```

- **Edit type**: Opens the specified file in your preferred editor. Uses `$BOOKMARKS_EDITOR` if defined, otherwise `$EDITOR`, with `vi` as the final fallback.

  Example:
  ```bash
  bookmark add "Todo List" edit '"$HOME/todo.txt"'
  bookmark add "Config" edit '"$HOME/.bashrc"'
  ```

- **Note type**: Attempts to use the system default opener first, falls back to `less` or `cat` for terminal viewing.

This approach provides a more systematic and cross-platform compatible way to handle different bookmark types compared to requiring manual `xdg-open` commands.

## Hook Scripts

Universal Bookmarks supports extension through hook scripts. These are shell scripts that run at specific points in the bookmark lifecycle:

1. Create a script in `$BOOKMARKS_DIR/hooks/` with one of these names:
   - `after_add.sh` - Runs after adding a bookmark
   - `after_edit.sh` - Runs after editing a bookmark
   - `after_update.sh` - Runs after updating a bookmark
   - `after_delete.sh` - Runs after deleting a bookmark
   - `after_obsolete.sh` - Runs after marking a bookmark as obsolete

2. Make the script executable:
   ```bash
   chmod +x "$BOOKMARKS_DIR/hooks/after_add.sh"
   ```

3. The script will receive these arguments:
   - `$1` - Path to the bookmarks directory
   - `$2` - Path to the bookmarks file

### Example Hook Use Cases

- **Automatic Backups**: Create backups after each modification
- **Cloud Sync**: Sync your bookmarks to cloud storage
- **Notifications**: Display notifications when bookmarks are added/changed
- **Logging**: Keep a log of all bookmark activities
- **Export**: Automatically export to other formats
- **Version Control**: Commit changes to a git repository

### Provided Examples

The project includes example hooks in the `examples/` directory:

- `after_add.sh.example`: Actions to perform after adding a bookmark
  - Logs additions to an activity log
  - Displays a notification
  - Optional cloud sync
  
- `after_delete.sh.example`: Actions to perform after deleting a bookmark
  - Logs deletions to an activity log
  - Creates an automatic backup

To use these examples, copy them to your hooks directory:

```bash
cp /path/to/universal_bookmark/examples/*.example "$BOOKMARKS_DIR/hooks/"
cd "$BOOKMARKS_DIR/hooks/"
cp after_add.sh.example after_add.sh
cp after_delete.sh.example after_delete.sh
chmod +x after_add.sh after_delete.sh
```

## Backup & Restore

Universal Bookmarks includes built-in backup functionality:

- **Create a backup**: `bookmark backup`
  - Creates timestamped backups in `$BOOKMARKS_DIR/backups/`
  - Automatically removes old backups (keeps last 5)

- **Restore from backup**: `bookmark restore`
  - Shows a list of available backups
  - Lets you select which one to restore

## Testing

Universal Bookmarks comes with comprehensive test suites to verify functionality. This is helpful for:
- Confirming all features work after making changes
- Verifying your installation is working correctly
- Understanding the capabilities of the system

### Quick Start

Run all tests with the convenience test runner:
```bash
./run_tests.sh
```

The test runner provides:
- Aggregated test results and summary
- Colored, formatted output
- Options for verbose, quiet, and fail-fast modes
- Ability to run specific test suites
- Dependency checking

### Test Runner Options

```bash
./run_tests.sh              # Run all tests
./run_tests.sh -v           # Verbose mode (show detailed output)
./run_tests.sh -q           # Quiet mode (summary only)
./run_tests.sh -f           # Fail-fast mode (stop on first failure)
./run_tests.sh --list       # List available test suites
./run_tests.sh frecency     # Run only tests matching 'frecency'
./run_tests.sh --help       # Show help message
```

### Individual Test Suites

The project includes multiple specialized test suites that can also be run individually:

**Main Test Suite (`test_bookmarks.sh`):**
Tests core functionality including adding, editing, updating, deleting bookmarks, and basic operations.

**Frecency Tests (`test_frecency.sh`):**
Tests the frecency (frequency + recency) scoring system that automatically prioritizes your most-used bookmarks.

**Editor Features Tests (`test_editor_features.sh`):**
Tests the editor-based bookmark editing functionality, including the `edit` and `modify-add` commands.

**Special Characters Tests (`test_special_chars.sh`):**
Tests handling of special characters in bookmark descriptions, commands, tags, and notes to ensure robustness.

**Type Execution Tests (`test_type_execution.sh`):**
Tests type-specific execution logic for different bookmark types (url, pdf, script, ssh, etc.).

**Run individual test:**
```bash
./test_bookmarks.sh         # Run a specific test suite
```

All test suites create a temporary environment, test their respective functions, and clean up after themselves. The test framework is modular and can be extended with new test suites as needed.

## Development

### GitHub Copilot Custom Agents

This project includes custom GitHub Copilot agents that provide specialized expertise for different aspects of development. These agents are configured in `.github/agents.yml` and located in `.github/agents/`:

- **CI/Testing Specialist** (`ci-testing-specialist.md`)
  - Expert in test automation, CI/CD pipelines, and quality assurance
  - Best for: Writing tests, debugging test failures, optimizing CI workflows
  
- **UNIX Philosopher** (`unix-philosopher.md`)
  - Expert in UNIX philosophy, functional programming, and elegant code design
  - Best for: Code refactoring, architectural decisions, composability improvements

When working with GitHub Copilot in this repository, these agents can be invoked to help with domain-specific tasks, ensuring code quality and adherence to project conventions.

For more information about the project's development guidelines, see [`.github/copilot-instructions.md`](.github/copilot-instructions.md).

## Troubleshooting

### Common Issues

1. **Missing Dependencies**
   - Error: `jq is not installed` or `fzf is not installed`
   - Solution: Install the missing dependency and run the setup again

2. **Environment Variable Not Set**
   - Error: `BOOKMARKS_DIR environment variable not set`
   - Solution: Run `export BOOKMARKS_DIR="$HOME/.bookmarks"` or restart your shell after setup

3. **Permission Denied**
   - Error when running scripts
   - Solution: Make sure scripts are executable with `chmod +x bookmarks.sh setup.sh`

4. **JSON Parse Error**
   - May happen if the bookmarks file was manually edited incorrectly
   - Solution: Restore from a backup or fix the JSON formatting

### Data Recovery

If your bookmarks file gets corrupted:

1. Check for backups in `$BOOKMARKS_DIR/backups/`
2. Restore using `bookmark restore`
3. If no backups are available, you can create a new empty file:
   ```bash
   echo '{"bookmarks":[]}' > "$BOOKMARKS_DIR/bookmarks.json"
   ```

## Dependencies

- **Required**:
  - `jq` - JSON processor for parsing and manipulating bookmark data
    - Installation: [https://stedolan.github.io/jq/download/](https://stedolan.github.io/jq/download/)
  - `fzf` - Command-line fuzzy finder for searching bookmarks
    - Installation: [https://github.com/junegunn/fzf#installation](https://github.com/junegunn/fzf#installation)

- **Optional/Commonly Used**:
  - `xdg-open` - For opening URLs and files (included in most Linux distributions)
  - Standard Unix utilities: `sed`, `awk`, `bash` (included in most systems)

The setup script will check for required dependencies and guide you through installation if any are missing.
