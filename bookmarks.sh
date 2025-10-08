#!/bin/bash

# Universal Bookmarks
# A script to manage bookmarks using JSON format

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Non-interactive mode flag
NON_INTERACTIVE=false

# Check if BOOKMARKS_DIR is set
if [ -z "$BOOKMARKS_DIR" ]; then
    echo -e "${RED}Error: BOOKMARKS_DIR environment variable not set.${NC}"
    echo "Please set it to the directory where you want to store your bookmarks."
    echo "Example: export BOOKMARKS_DIR=\"\$HOME/.bookmarks\""
    exit 1
fi

# Create directory if it doesn't exist
if [ ! -d "$BOOKMARKS_DIR" ]; then
    mkdir -p "$BOOKMARKS_DIR"
    echo -e "${GREEN}Created directory: $BOOKMARKS_DIR${NC}"
fi

# Path to the bookmarks file
BOOKMARKS_FILE="$BOOKMARKS_DIR/bookmarks.json"

# Check if jq is installed (needed for JSON parsing)
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed. Please install it to use this script.${NC}"
    echo "jq is required for JSON processing."
    echo "Installation: sudo apt install jq (Debian/Ubuntu) or brew install jq (macOS)"
    exit 1
fi

# Check if fzf is installed
if ! command -v fzf &> /dev/null; then
    echo -e "${RED}Error: fzf is not installed. Please install it to use this script.${NC}"
    echo "Visit https://github.com/junegunn/fzf for installation instructions."
    exit 1
fi

# Create or initialize bookmarks file if it doesn't exist or is empty
if [ ! -f "$BOOKMARKS_FILE" ] || [ ! -s "$BOOKMARKS_FILE" ]; then
    echo '{"bookmarks":[]}' > "$BOOKMARKS_FILE"
    echo -e "${GREEN}Created bookmarks file: $BOOKMARKS_FILE${NC}"
fi

# Valid bookmark types
VALID_TYPES=("url" "pdf" "script" "ssh" "app" "cmd" "note" "folder" "file" "edit" "custom")

# Create a unique ID for the bookmark
generate_id() {
    echo "$(date +%s)_$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 6)"
}

# Check if bookmark type is valid
is_valid_type() {
    local type="$1"
    for valid_type in "${VALID_TYPES[@]}"; do
        if [[ "$valid_type" == "$type" ]]; then
            return 0
        fi
    done
    return 1
}

# Add a new bookmark
add_bookmark() {
    local description="$1"
    local type="$2"
    local command="$3"
    local tags="${4:-}"
    local notes="${5:-}"
    
    # Input validation
    if [ -z "$description" ]; then
        echo -e "${RED}Error: Description cannot be empty.${NC}"
        exit 1
    fi
    
    if [ -z "$type" ]; then
        echo -e "${RED}Error: Type cannot be empty.${NC}"
        exit 1
    fi
    
    # Check if the type is valid
    if ! is_valid_type "$type"; then
        echo -e "${RED}Error: Invalid bookmark type: $type${NC}"
        echo -e "Valid types: ${CYAN}${VALID_TYPES[*]}${NC}"
        
        local response="y"
        if [ "$NON_INTERACTIVE" = false ]; then
            read -p "Do you want to continue with a custom type? (y/n): " response
        fi
        
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    if [ -z "$command" ]; then
        echo -e "${RED}Error: Command cannot be empty.${NC}"
        exit 1
    fi
    
    # Check if bookmark with the same description already exists
    local exists=$(jq --arg desc "$description" '.bookmarks[] | select(.description == $desc)' "$BOOKMARKS_FILE")
    
    if [ -n "$exists" ]; then
        echo -e "${YELLOW}A bookmark with description '$description' already exists.${NC}"
        
        local update="y"
        if [ "$NON_INTERACTIVE" = false ]; then
            read -p "Do you want to update it? (y/n): " update
        fi
        
        if [[ "$update" =~ ^[Yy]$ ]]; then
            update_bookmark "$description" "$type" "$command" "$tags" "$notes"
            return
        else
            echo -e "${YELLOW}Operation cancelled.${NC}"
            exit 0
        fi
    fi
    
    # Generate a unique ID
    local id=$(generate_id)
    local created=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Prepare the bookmark entry
    local entry=$(jq -n \
        --arg id "$id" \
        --arg desc "$description" \
        --arg type "$type" \
        --arg cmd "$command" \
        --arg tags "$tags" \
        --arg notes "$notes" \
        --arg created "$created" \
        '{id: $id, description: $desc, type: $type, command: $cmd, tags: $tags, notes: $notes, created: $created, status: "active"}')
    
    # Add the bookmark to the file
    local updated_json=$(jq --argjson entry "$entry" '.bookmarks += [$entry]' "$BOOKMARKS_FILE")
    echo "$updated_json" > "$BOOKMARKS_FILE"
    
    echo -e "${GREEN}Bookmark added: ${CYAN}$description${NC}"
}

# Add a new bookmark interactively
interactive_add_bookmark() {
    echo -e "${BLUE}Adding a new bookmark interactively${NC}"
    echo ""
    
    # Prompt for description
    read -p "Description: " description
    while [ -z "$description" ]; do
        echo -e "${RED}Description cannot be empty.${NC}"
        read -p "Description: " description
    done
    
    # Prompt for type
    echo -e "${CYAN}Valid types: ${VALID_TYPES[*]}${NC}"
    read -p "Type: " type
    while [ -z "$type" ]; do
        echo -e "${RED}Type cannot be empty.${NC}"
        read -p "Type: " type
    done
    
    # Validate type or confirm custom type
    if ! is_valid_type "$type"; then
        echo -e "${YELLOW}Warning: '$type' is not in the list of standard types.${NC}"
        echo -e "Standard types: ${CYAN}${VALID_TYPES[*]}${NC}"
        
        local response
        read -p "Do you want to continue with this custom type? (y/n): " response
        
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Operation cancelled.${NC}"
            exit 0
        fi
    fi
    
    # Prompt for command
    read -p "Command: " command
    while [ -z "$command" ]; do
        echo -e "${RED}Command cannot be empty.${NC}"
        read -p "Command: " command
    done
    
    # Prompt for tags (optional)
    read -p "Tags (optional): " tags
    
    # Prompt for notes (optional)
    read -p "Notes (optional): " notes
    
    # Call the regular add_bookmark function with the collected inputs
    # Set NON_INTERACTIVE temporarily since we've already handled user interaction
    local saved_non_interactive="$NON_INTERACTIVE"
    NON_INTERACTIVE=true
    add_bookmark "$description" "$type" "$command" "$tags" "$notes"
    NON_INTERACTIVE="$saved_non_interactive"
}

# Select a bookmark using fzf
# Returns the description of the selected bookmark
select_bookmark_with_fzf() {
    local prompt="${1:-Select a bookmark}"
    
    # Prepare the bookmarks for display
    local formatted_bookmarks=$(jq -r '.bookmarks[] | "\(.id)|\(.description)|\(.type)|\(.command)|\(.status)"' "$BOOKMARKS_FILE" | \
        while IFS="|" read -r id description type command status; do
            status_str=""
            if [ "$status" = "obsolete" ]; then
                status_str="${RED}[OBSOLETE]${NC} "
            fi
            echo -e "${status_str}${CYAN}[$type]${NC} ${YELLOW}$description${NC}"
        done)
    
    if [ -z "$formatted_bookmarks" ]; then
        echo -e "${YELLOW}No bookmarks found.${NC}" >&2
        return 1
    fi
    
    # Use fzf for interactive selection
    local selected=$(echo -e "$formatted_bookmarks" | fzf --ansi --height 40% --border --prompt="$prompt: ")
    
    if [ -z "$selected" ]; then
        return 1
    fi
    
    # Extract the description (remove ANSI codes and format markers)
    local description=$(echo "$selected" | sed -E 's/\x1B\[[0-9;]*[mK]//g' | sed -E 's/^\[OBSOLETE\] \[(.*)\] (.*)/\2/' | sed -E 's/^\[(.*)\] (.*)/\2/')
    
    echo "$description"
    return 0
}

# Update an existing bookmark
update_bookmark() {
    local description="$1"
    local type="$2"
    local command="$3"
    local tags="${4:-}"
    local notes="${5:-}"
    
    # Find the bookmark
    local count=$(jq --arg desc "$description" '.bookmarks | map(select(.description == $desc)) | length' "$BOOKMARKS_FILE")
    
    if [ "$count" -eq 0 ]; then
        echo -e "${RED}No bookmark found with description: $description${NC}"
        exit 1
    elif [ "$count" -gt 1 ]; then
        echo -e "${RED}Multiple bookmarks found with description: $description${NC}"
        echo -e "Please provide a more specific description or use edit_bookmark with ID.${NC}"
        exit 1
    fi
    
    # Prepare the updated data
    local modified=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Update the bookmark
    local updated_json=$(jq --arg desc "$description" \
        --arg type "$type" \
        --arg cmd "$command" \
        --arg tags "$tags" \
        --arg notes "$notes" \
        --arg modified "$modified" \
        '.bookmarks = [.bookmarks[] | if .description == $desc then .type = $type | .command = $cmd | .tags = $tags | .notes = $notes | .modified = $modified else . end]' "$BOOKMARKS_FILE")
    
    echo "$updated_json" > "$BOOKMARKS_FILE"
    echo -e "${GREEN}Bookmark updated: ${CYAN}$description${NC}"
}

# Edit a bookmark
edit_bookmark() {
    local id_or_desc="$1"
    
    # If no argument provided, use fzf to select
    if [ -z "$id_or_desc" ]; then
        id_or_desc=$(select_bookmark_with_fzf "Select bookmark to edit")
        if [ $? -ne 0 ] || [ -z "$id_or_desc" ]; then
            echo -e "${YELLOW}No bookmark selected.${NC}"
            exit 0
        fi
    fi
    
    # Find the bookmark
    local bookmark
    if [[ "$id_or_desc" == *"_"* ]]; then
        # Looks like an ID
        bookmark=$(jq --arg id "$id_or_desc" -r '.bookmarks[] | select(.id == $id)' "$BOOKMARKS_FILE")
    else
        # Treat as description
        bookmark=$(jq --arg desc "$id_or_desc" -r '.bookmarks[] | select(.description == $desc)' "$BOOKMARKS_FILE")
    fi
    
    if [ -z "$bookmark" ]; then
        echo -e "${RED}No bookmark found with ID or description: $id_or_desc${NC}"
        exit 1
    fi
    
    # Extract current values
    local id=$(echo "$bookmark" | jq -r '.id')
    local description=$(echo "$bookmark" | jq -r '.description')
    local type=$(echo "$bookmark" | jq -r '.type')
    local command=$(echo "$bookmark" | jq -r '.command')
    local tags=$(echo "$bookmark" | jq -r '.tags')
    local notes=$(echo "$bookmark" | jq -r '.notes')
    
    echo -e "${BLUE}Editing bookmark: ${CYAN}$description${NC}"
    echo -e "${BLUE}Current values:${NC}"
    echo -e "  ${BLUE}Description:${NC} $description"
    echo -e "  ${BLUE}Type:${NC} $type"
    echo -e "  ${BLUE}Command:${NC} $command"
    echo -e "  ${BLUE}Tags:${NC} $tags"
    echo -e "  ${BLUE}Notes:${NC} $notes"
    echo ""
    
    # Get new values
    read -p "New description (leave empty to keep current): " new_description
    read -p "New type (leave empty to keep current): " new_type
    read -p "New command (leave empty to keep current): " new_command
    read -p "New tags (leave empty to keep current): " new_tags
    read -p "New notes (leave empty to keep current): " new_notes
    
    # Use current values if new ones are not provided
    new_description=${new_description:-"$description"}
    new_type=${new_type:-"$type"}
    new_command=${new_command:-"$command"}
    new_tags=${new_tags:-"$tags"}
    new_notes=${new_notes:-"$notes"}
    
    # Check if the type is valid
    if ! is_valid_type "$new_type"; then
        echo -e "${YELLOW}Warning: '$new_type' is not in the list of standard types.${NC}"
        echo -e "Standard types: ${CYAN}${VALID_TYPES[*]}${NC}"
        
        local response="y"
        if [ "$NON_INTERACTIVE" = false ]; then
            read -p "Do you want to continue with this custom type? (y/n): " response
        fi
        
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Operation cancelled.${NC}"
            exit 0
        fi
    fi
    
    # Update the bookmark
    local modified=$(date +"%Y-%m-%d %H:%M:%S")
    
    local updated_json=$(jq --arg id "$id" \
        --arg desc "$new_description" \
        --arg type "$new_type" \
        --arg cmd "$new_command" \
        --arg tags "$new_tags" \
        --arg notes "$new_notes" \
        --arg modified "$modified" \
        '.bookmarks = [.bookmarks[] | if .id == $id then .description = $desc | .type = $type | .command = $cmd | .tags = $tags | .notes = $notes | .modified = $modified else . end]' "$BOOKMARKS_FILE")
    
    echo "$updated_json" > "$BOOKMARKS_FILE"
    echo -e "${GREEN}Bookmark updated: ${CYAN}$new_description${NC}"
}

# Delete a bookmark
delete_bookmark() {
    local id_or_desc="$1"
    
    # If no argument provided, use fzf to select
    if [ -z "$id_or_desc" ]; then
        id_or_desc=$(select_bookmark_with_fzf "Select bookmark to delete")
        if [ $? -ne 0 ] || [ -z "$id_or_desc" ]; then
            echo -e "${YELLOW}No bookmark selected.${NC}"
            exit 0
        fi
    fi
    
    # Find the bookmark
    local bookmark
    if [[ "$id_or_desc" == *"_"* ]]; then
        # Looks like an ID
        bookmark=$(jq --arg id "$id_or_desc" -r '.bookmarks[] | select(.id == $id)' "$BOOKMARKS_FILE")
    else
        # Treat as description
        bookmark=$(jq --arg desc "$id_or_desc" -r '.bookmarks[] | select(.description == $desc)' "$BOOKMARKS_FILE")
    fi
    
    if [ -z "$bookmark" ]; then
        echo -e "${RED}No bookmark found with ID or description: $id_or_desc${NC}"
        exit 1
    fi
    
    # Extract description for confirmation
    local description=$(echo "$bookmark" | jq -r '.description')
    
    echo -e "${YELLOW}You are about to delete the bookmark: ${CYAN}$description${NC}"
    
    local confirmation="y"
    if [ "$NON_INTERACTIVE" = false ]; then
        read -p "Are you sure? (y/n): " confirmation
    fi
    
    if [[ "$confirmation" =~ ^[Yy]$ ]]; then
        if [[ "$id_or_desc" == *"_"* ]]; then
            # Delete by ID
            local updated_json=$(jq --arg id "$id_or_desc" '.bookmarks = [.bookmarks[] | select(.id != $id)]' "$BOOKMARKS_FILE")
        else
            # Delete by description
            local updated_json=$(jq --arg desc "$id_or_desc" '.bookmarks = [.bookmarks[] | select(.description != $desc)]' "$BOOKMARKS_FILE")
        fi
        
        echo "$updated_json" > "$BOOKMARKS_FILE"
        echo -e "${GREEN}Bookmark deleted: ${CYAN}$description${NC}"
    else
        echo -e "${YELLOW}Deletion cancelled.${NC}"
    fi
}

# Make a bookmark obsolete
obsolete_bookmark() {
    local id_or_desc="$1"
    
    # If no argument provided, use fzf to select
    if [ -z "$id_or_desc" ]; then
        id_or_desc=$(select_bookmark_with_fzf "Select bookmark to mark obsolete")
        if [ $? -ne 0 ] || [ -z "$id_or_desc" ]; then
            echo -e "${YELLOW}No bookmark selected.${NC}"
            exit 0
        fi
    fi
    
    # Find the bookmark
    local bookmark
    if [[ "$id_or_desc" == *"_"* ]]; then
        # Looks like an ID
        bookmark=$(jq --arg id "$id_or_desc" -r '.bookmarks[] | select(.id == $id)' "$BOOKMARKS_FILE")
    else
        # Treat as description
        bookmark=$(jq --arg desc "$id_or_desc" -r '.bookmarks[] | select(.description == $desc)' "$BOOKMARKS_FILE")
    fi
    
    if [ -z "$bookmark" ]; then
        echo -e "${RED}No bookmark found with ID or description: $id_or_desc${NC}"
        exit 1
    fi
    
    # Extract description and current status for confirmation
    local description=$(echo "$bookmark" | jq -r '.description')
    local status=$(echo "$bookmark" | jq -r '.status')
    
    if [ "$status" = "obsolete" ]; then
        echo -e "${YELLOW}This bookmark is already marked as obsolete: ${CYAN}$description${NC}"
        
        local restore="y"
        if [ "$NON_INTERACTIVE" = false ]; then
            read -p "Do you want to restore it to active status? (y/n): " restore
        fi
        
        if [[ "$restore" =~ ^[Yy]$ ]]; then
            local new_status="active"
            local message="restored to active"
        else
            echo -e "${YELLOW}Operation cancelled.${NC}"
            exit 0
        fi
    else
        echo -e "${YELLOW}You are about to mark the bookmark as obsolete: ${CYAN}$description${NC}"
        
        local confirmation="y"
        if [ "$NON_INTERACTIVE" = false ]; then
            read -p "Continue? (y/n): " confirmation
        fi
        
        if [[ "$confirmation" =~ ^[Yy]$ ]]; then
            local new_status="obsolete"
            local message="marked as obsolete"
        else
            echo -e "${YELLOW}Operation cancelled.${NC}"
            exit 0
        fi
    fi
    
    # Update the bookmark status
    if [[ "$id_or_desc" == *"_"* ]]; then
        # Update by ID
        local updated_json=$(jq --arg id "$id_or_desc" --arg status "$new_status" \
            '.bookmarks = [.bookmarks[] | if .id == $id then .status = $status else . end]' "$BOOKMARKS_FILE")
    else
        # Update by description
        local updated_json=$(jq --arg desc "$id_or_desc" --arg status "$new_status" \
            '.bookmarks = [.bookmarks[] | if .description == $desc then .status = $status else . end]' "$BOOKMARKS_FILE")
    fi
    
    echo "$updated_json" > "$BOOKMARKS_FILE"
    echo -e "${GREEN}Bookmark $message: ${CYAN}$description${NC}"
}

# Execute a bookmark command based on its type
execute_bookmark_by_type() {
    local type="$1"
    local command="$2"
    local description="$3"
    
    # Detect the OS for cross-platform compatibility
    local open_cmd=""
    if command -v xdg-open &> /dev/null; then
        open_cmd="xdg-open"
    elif command -v open &> /dev/null; then
        open_cmd="open"  # macOS
    elif command -v start &> /dev/null; then
        open_cmd="start"  # Windows/WSL
    fi
    
    case "$type" in
        url|folder|file)
            # Use system's default opener for these types
            if [ -n "$open_cmd" ]; then
                echo -e "${GREEN}Opening with $open_cmd: ${CYAN}$description${NC}"
                eval "$open_cmd $command & disown"
            else
                echo -e "${YELLOW}Warning: No system opener found (xdg-open, open, or start)${NC}"
                echo -e "${BLUE}Falling back to direct execution${NC}"
                eval "$command"
            fi
            ;;
        pdf)
            # For PDFs, interpret as file and page number if specified (e.g., file.pdf#page=10)
            # Extract file and page number
            local file_part=$(echo "$command" | cut -d'#' -f1)
            local page_part=$(echo "$command" | grep -oP '(?<=#page=)[0-9]+' || echo "")
            # Open with zathura if available, otherwise fail with message
            if command -v zathura &> /dev/null; then
                if [ -n "$page_part" ]; then
                    echo -e "${GREEN}Opening PDF with zathura at page $page_part: ${CYAN}$file_part${NC}"
                    zathura "$file_part" --page "$page_part" --fork
                else
                    echo -e "${GREEN}Opening PDF with zathura: ${CYAN}$file_part${NC}"
                    zathura "$file_part" --fork
                fi
            else
                echo -e "${RED}Error: zathura is not installed. Please install it to open PDF files.${NC}"
                exit 1
            fi
            ;;
        note)
            # For notes, try to open with system default or fall back to less/cat
            if [ -n "$open_cmd" ]; then
                eval "$open_cmd $command"
            elif command -v less &> /dev/null; then
                eval "less $command"
            else
                eval "cat $command"
            fi
            ;;
        edit)
            # For edit type, use BOOKMARKS_EDITOR if defined, otherwise EDITOR
            local editor="${BOOKMARKS_EDITOR:-${EDITOR:-vi}}"
            echo -e "${GREEN}Opening with $editor: ${CYAN}$description${NC}"
            eval "$editor $command"
            ;;
        script|ssh|app|cmd|custom|*)
            # Direct execution for scripts, SSH connections, apps, commands, and custom types
            eval "$command"
            ;;
    esac
}

# List all bookmarks with fuzzy search
list_bookmarks() {
    local search_term="$1"
    
    # Prepare the bookmarks for display
    local formatted_bookmarks=$(jq -r '.bookmarks[] | "\(.id)|\(.description)|\(.type)|\(.command)|\(.status)"' "$BOOKMARKS_FILE" | \
        while IFS="|" read -r id description type command status; do
            status_str=""
            if [ "$status" = "obsolete" ]; then
                status_str="${RED}[OBSOLETE]${NC} "
            fi
            echo -e "${status_str}${CYAN}[$type]${NC} ${YELLOW}$description${NC}"
        done)
    
    if [ -z "$formatted_bookmarks" ]; then
        echo -e "${YELLOW}No bookmarks found.${NC}"
        return
    fi
    
    local selected
    if [ -z "$search_term" ]; then
        # No search term provided, use fzf for interactive selection
        selected=$(echo -e "$formatted_bookmarks" | fzf --ansi --height 40% --border)
    else
        # Use the search term with fzf
        selected=$(echo -e "$formatted_bookmarks" | fzf --ansi --filter="$search_term" | head -1)
    fi
    
    if [ -n "$selected" ]; then
        # Extract the description
        local description=$(echo "$selected" | sed -E 's/\x1B\[[0-9;]*[mK]//g' | sed -E 's/^\[OBSOLETE\] \[(.*)\] (.*)/\2/' | sed -E 's/^\[(.*)\] (.*)/\2/')
        
        # Find the command and type in the JSON
        local bookmark=$(jq -r --arg desc "$description" '.bookmarks[] | select(.description == $desc)' "$BOOKMARKS_FILE")
        local command=$(echo "$bookmark" | jq -r '.command')
        local type=$(echo "$bookmark" | jq -r '.type')
        local status=$(echo "$bookmark" | jq -r '.status')
        
        if [ "$status" = "obsolete" ]; then
            echo -e "${YELLOW}Warning: This bookmark is marked as obsolete.${NC}"
            
            local confirm="y"
            if [ "$NON_INTERACTIVE" = false ]; then
                read -p "Do you still want to execute it? (y/n): " confirm
            fi
            
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                return
            fi
        fi
        
        echo -e "${GREEN}Executing: ${CYAN}$description${NC}"
        echo -e "${BLUE}Type: ${NC}$type"
        echo -e "${BLUE}Command: ${NC}$command"
        
        # Execute the command based on bookmark type
        execute_bookmark_by_type "$type" "$command" "$description"
    fi
}

# List all bookmarks without executing them
list_all_bookmarks() {
    local show_details="${1:-false}"
    
    echo -e "${BLUE}All Bookmarks:${NC}"
    echo -e "${BLUE}-------------${NC}"
    
    jq -r '.bookmarks | sort_by(.type) | .[]' "$BOOKMARKS_FILE" | jq -s '.' | \
    jq -r 'group_by(.type) | .[] | "Type: \(.[0].type)\n\(reduce .[] as $item (""; . + "  " + if $item.status == "obsolete" then "🚫 " else "✅ " end + $item.description + "\n"))"' | \
    while IFS= read -r line; do
        if [[ "$line" == Type:* ]]; then
            type=${line#Type: }
            echo -e "${CYAN}$line${NC}"
        else
            if [[ "$line" == *"🚫"* ]]; then
                echo -e "${RED}$line${NC}"
            else
                echo -e "$line"
            fi
        fi
    done
    
    if [ "$show_details" = "true" ]; then
        echo -e "\n${BLUE}Bookmark Details:${NC}"
        echo -e "${BLUE}----------------${NC}"
        
        jq -r '.bookmarks[] | "ID: \(.id)\nDescription: \(.description)\nType: \(.type)\nCommand: \(.command)\nTags: \(.tags)\nNotes: \(.notes)\nCreated: \(.created)\nStatus: \(.status)\n"' "$BOOKMARKS_FILE" | \
        while IFS= read -r line; do
            if [[ "$line" == Description:* ]]; then
                echo -e "${YELLOW}$line${NC}"
            elif [[ "$line" == ID:* || "$line" == Type:* || "$line" == Command:* || "$line" == Tags:* || "$line" == Notes:* || "$line" == Created:* ]]; then
                echo -e "${BLUE}$line${NC}"
            elif [[ "$line" == Status:* ]]; then
                if [[ "$line" == *"obsolete"* ]]; then
                    echo -e "${RED}$line${NC}"
                else
                    echo -e "${GREEN}$line${NC}"
                fi
            else
                echo "$line"
            fi
        done
    fi
}

# Search bookmarks by tags
search_by_tag() {
    local tag="$1"
    
    echo -e "${BLUE}Bookmarks with tag: ${CYAN}$tag${NC}"
    echo -e "${BLUE}---------------------${NC}"
    
    jq -r --arg tag "$tag" '.bookmarks[] | select(.tags | contains($tag)) | "\(.id)|\(.description)|\(.type)|\(.command)|\(.status)"' "$BOOKMARKS_FILE" | \
    while IFS="|" read -r id description type command status; do
        status_str=""
        if [ "$status" = "obsolete" ]; then
            status_str="${RED}[OBSOLETE]${NC} "
        fi
        echo -e "${status_str}${CYAN}[$type]${NC} ${YELLOW}$description${NC}"
    done
}



# Backup the bookmarks file
backup_bookmarks() {
    local backup_dir="$BOOKMARKS_DIR/backups"
    mkdir -p "$backup_dir"
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$backup_dir/bookmarks_$timestamp.json"
    
    cp "$BOOKMARKS_FILE" "$backup_file"
    echo -e "${GREEN}Backup created: ${CYAN}$backup_file${NC}"
    
    # Clean up old backups - keep last 5
    ls -t "$backup_dir"/bookmarks_*.json | tail -n +6 | xargs rm -f 2>/dev/null
    echo -e "${BLUE}Kept last 5 backups in ${CYAN}$backup_dir${NC}"
}

# Restore from a backup
restore_from_backup() {
    local backup_dir="$BOOKMARKS_DIR/backups"
    
    if [ ! -d "$backup_dir" ]; then
        echo -e "${RED}No backups directory found.${NC}"
        exit 1
    fi
    
    local backups=($(ls -t "$backup_dir"/bookmarks_*.json 2>/dev/null))
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${RED}No backup files found.${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Available backups:${NC}"
    local i=1
    for backup in "${backups[@]}"; do
        local date=$(basename "$backup" | sed -E 's/bookmarks_([0-9]{8})_([0-9]{6})\.json/\1 \2/')
        local formatted_date=$(echo "$date" | sed -E 's/([0-9]{4})([0-9]{2})([0-9]{2}) ([0-9]{2})([0-9]{2})([0-9]{2})/\1-\2-\3 \4:\5:\6/')
        echo -e "  ${BLUE}$i)${NC} $formatted_date"
        i=$((i+1))
    done
    
    local selection="1"
    if [ "$NON_INTERACTIVE" = false ]; then
        read -p "Enter backup number to restore (0 to cancel): " selection
    fi
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#backups[@]} ]; then
        local selected_backup="${backups[$((selection-1))]}"
        
        echo -e "${YELLOW}You are about to restore from: ${CYAN}$(basename "$selected_backup")${NC}"
        echo -e "${RED}This will overwrite your current bookmarks!${NC}"
        
        local confirm="y"
        if [ "$NON_INTERACTIVE" = false ]; then
            read -p "Continue? (y/n): " confirm
        fi
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            cp "$selected_backup" "$BOOKMARKS_FILE"
            echo -e "${GREEN}Bookmarks restored from: ${CYAN}$(basename "$selected_backup")${NC}"
        else
            echo -e "${YELLOW}Restore cancelled.${NC}"
        fi
    else
        echo -e "${YELLOW}Restore cancelled.${NC}"
    fi
}

# Run custom hook
run_hook() {
    local hook_name="$1"
    local hook_script="$BOOKMARKS_DIR/hooks/$hook_name.sh"
    
    if [ -f "$hook_script" ]; then
        echo -e "${BLUE}Running hook: ${CYAN}$hook_name${NC}"
        bash "$hook_script" "$BOOKMARKS_DIR" "$BOOKMARKS_FILE"
    fi
}

# Show help information
show_help() {
    script_name=$(basename "$0")
    echo -e "${BLUE}Universal Bookmarks - Manage and use bookmarks from the command line${NC}"
    echo ""
    echo -e "${GREEN}Usage: $script_name [command], where command can be one of${NC}"
    echo "  add \"Description\" type \"command\" [tags] [notes]   # Add a new bookmark"
    echo "  add                                       # Add a bookmark interactively"
    echo "  edit [\"Description or ID\"]                   # Edit a bookmark interactively (uses fzf if no argument)"
    echo "  update \"Description\" type \"command\" [tags] [notes] # Update a bookmark"
    echo "  delete [\"Description or ID\"]                 # Delete a bookmark (uses fzf if no argument)"
    echo "  obsolete [\"Description or ID\"]               # Mark a bookmark as obsolete (uses fzf if no argument)"
    echo "  list                                      # List all bookmarks without executing"
    echo "  details                                   # List all bookmarks with details"
    echo "  tag \"tag\"                                # Search bookmarks by tag"
    echo "  backup                                    # Create a backup of bookmarks"
    echo "  restore                                   # Restore from a backup"
    echo "  help                                      # Show this help information"
    echo "  [search term]                             # Search and execute a bookmark"
    echo "  [no arguments]                            # Search bookmarks interactively"
    echo ""
    echo -e "${CYAN}Bookmark Types:${NC}"
    for type in "${VALID_TYPES[@]}"; do
        echo "  $type"
    done
}

# Check if hooks directory exists, create it if not
if [ ! -d "$BOOKMARKS_DIR/hooks" ]; then
    mkdir -p "$BOOKMARKS_DIR/hooks"
fi

# Example hook for after bookmark added
if [ ! -f "$BOOKMARKS_DIR/hooks/after_add.sh.example" ]; then
    cat > "$BOOKMARKS_DIR/hooks/after_add.sh.example" << 'EOF'
#!/bin/bash
# Example hook that runs after adding a bookmark
# Rename to after_add.sh to activate
#
# Arguments:
# $1 - Bookmarks directory
# $2 - Bookmarks file

BOOKMARKS_DIR="$1"
BOOKMARKS_FILE="$2"

echo "Bookmark was added!"
echo "You can add custom actions here, like syncing bookmarks to another location."
EOF
    chmod +x "$BOOKMARKS_DIR/hooks/after_add.sh.example"
fi

# Main command handling
# Parse flags
while [[ "$1" == -* ]]; do
    case "$1" in
        -y|--yes)
            NON_INTERACTIVE=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

case "$1" in
    "add")
        if [ $# -eq 1 ]; then
            # No arguments provided, run interactively
            interactive_add_bookmark
        elif [ $# -lt 4 ]; then
            echo -e "${RED}Usage: $0 add \"Description\" type \"command\" [tags] [notes]${NC}"
            echo -e "${BLUE}Or run '$0 add' with no arguments for interactive mode${NC}"
            exit 1
        else
            # Arguments provided, use non-interactive mode
            add_bookmark "$2" "$3" "$4" "${5:-}" "${6:-}"
        fi
        run_hook "after_add"
        ;;
    "edit")
        edit_bookmark "${2:-}"
        run_hook "after_edit"
        ;;
    "update")
        if [ $# -lt 4 ]; then
            echo -e "${RED}Usage: $0 update \"Description\" type \"command\" [tags] [notes]${NC}"
            exit 1
        fi
        update_bookmark "$2" "$3" "$4" "${5:-}" "${6:-}"
        run_hook "after_update"
        ;;
    "delete")
        delete_bookmark "${2:-}"
        run_hook "after_delete"
        ;;
    "obsolete")
        obsolete_bookmark "${2:-}"
        run_hook "after_obsolete"
        ;;
    "list")
        list_all_bookmarks "false"
        ;;
    "details")
        list_all_bookmarks "true"
        ;;
    "tag")
        if [ $# -lt 2 ]; then
            echo -e "${RED}Usage: $0 tag \"tag\"${NC}"
            exit 1
        fi
        search_by_tag "$2"
        ;;
    "backup")
        backup_bookmarks
        ;;
    "restore")
        restore_from_backup
        ;;
    "help")
        show_help
        ;;
    *)
        # Default: list bookmarks
        list_bookmarks "$1"
        ;;
esac

exit 0
