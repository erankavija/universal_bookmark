# Universal Bookmarks

Shell script to manage bookmarks in a JSON format. A bookmark can be anything from a URL to a script that you want to run frequently.

## Features

- **Rich Bookmark Data**: Store descriptions, commands, types, tags, and notes
- **Intuitive Management**: Add, edit, update, delete, and mark bookmarks as obsolete
- **Advanced Searching**: Fuzzy search through bookmarks with colored output
- **Tag Support**: Organize and search bookmarks by tags
- **Backup & Restore**: Built-in backup/restore functionality
- **Hooks**: Custom extensibility with hook scripts
- **Cross-Shell Compatible**: Works with Bash, Zsh, Fish, and others

A bookmark is stored in a JSON file with fields for ID, description, type, command, tags, notes, created date, and status. This provides much more flexibility and robustness compared to simple text files.

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
  "status": "active"
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

## Usage

After setup, you can use either the `bookmark` command (if you used the setup script) or the full path to `bookmarks.sh`.

### Basic Usage

- **Interactive Selection**: Simply run `bookmark` with no arguments to get a fuzzy search interface
- **Direct Search**: Use `bookmark "search term"` to filter and execute a bookmark
- **List All**: Run `bookmark list` to see all bookmarks without executing them
- **Get Help**: Use `bookmark help` for full documentation

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

Edit a bookmark interactively. If no description is provided, fzf will launch to select a bookmark:
```bash
bookmark edit                    # Uses fzf to select a bookmark
bookmark edit "Description"      # Edit a specific bookmark
```
Or update directly:
```bash
bookmark update "Description" new-type "new-command" "new-tags" "new-notes"
```

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

#### Detailed View

Show more details about your bookmarks:
```bash
bookmark details
```

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

Universal Bookmarks comes with a test suite to verify functionality. This is helpful for:
- Confirming all features work after making changes
- Verifying your installation is working correctly
- Understanding the capabilities of the system

Run the tests:

```bash
./test_bookmarks.sh
```

The test suite creates a temporary environment, tests all main functions, and cleans up after itself.

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
