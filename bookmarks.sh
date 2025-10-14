#!/bin/bash
set -euo pipefail

# Universal Bookmarks
# A script to manage bookmarks using JSON format
# Focus: Shell command bookmarks with improved readability and performance

#=============================================================================
# CONSTANTS AND CONFIGURATION
#=============================================================================

# Color definitions for output formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Valid bookmark types - focused on shell commands and common file types
readonly VALID_TYPES=("url" "pdf" "script" "ssh" "app" "cmd" "note" "folder" "file" "edit" "custom")

# Configuration defaults
readonly DEFAULT_BACKUP_RETENTION=5

# Global flags
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


#=============================================================================
# UTILITY FUNCTIONS
#=============================================================================

# Generate a unique ID for bookmarks
# Returns: timestamp_randomstring format
generate_id() {
    echo "$(date +%s)_$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 6)"
}

# Validate bookmark type against allowed types
# Args: $1 - type to validate
# Returns: 0 if valid, 1 if invalid
is_valid_type() {
    local type="$1"
    for valid_type in "${VALID_TYPES[@]}"; do
        if [[ "$valid_type" == "$type" ]]; then
            return 0
        fi
    done
    return 1
}

# Get bookmark data by ID or description (optimized single jq call)
# Args: $1 - ID or description to search for
# Returns: JSON object of the bookmark or empty if not found
get_bookmark_by_id_or_desc() {
    local id_or_desc="$1"
    
    if [[ "$id_or_desc" == *"_"* ]]; then
        # Looks like an ID
        jq -r --arg id "$id_or_desc" '.bookmarks[] | select(.id == $id)' "$BOOKMARKS_FILE"
    else
        # Treat as description
        jq -r --arg desc "$id_or_desc" '.bookmarks[] | select(.description == $desc)' "$BOOKMARKS_FILE"
    fi
}

# Check if bookmark exists by description
# Args: $1 - description to check
# Returns: 0 if exists, 1 if not
bookmark_exists() {
    local description="$1"
    local count
    count=$(jq --arg desc "$description" '.bookmarks | map(select(.description == $desc)) | length' "$BOOKMARKS_FILE")
    [[ "$count" -gt 0 ]]
}

# Validate JSON file integrity
# Returns: 0 if valid, 1 if invalid
validate_bookmarks_file() {
    if ! jq empty "$BOOKMARKS_FILE" 2>/dev/null; then
        echo -e "${RED}Error: Bookmarks file contains invalid JSON${NC}" >&2
        return 1
    fi
    return 0
}

# Get user confirmation (respects NON_INTERACTIVE flag)
# Args: $1 - prompt message, $2 - default response (optional)
# Returns: 0 for yes, 1 for no
get_user_confirmation() {
    local prompt="$1"
    local default="${2:-y}"
    
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        return 0
    fi
    
    local response
    read -p "$prompt" response
    response="${response:-$default}"
    [[ "$response" =~ ^[Yy]$ ]]
}

#=============================================================================
# BOOKMARK MANAGEMENT FUNCTIONS
#=============================================================================

# Validate bookmark input parameters
# Args: $1 - description, $2 - type, $3 - command
# Returns: 0 if valid, exits on invalid input
validate_bookmark_input() {
    local description="$1"
    local type="$2"
    local command="$3"
    
    # Validate required fields
    if [[ -z "$description" ]]; then
        echo -e "${RED}Error: Description cannot be empty.${NC}" >&2
        exit 1
    fi
    
    if [[ -z "$type" ]]; then
        echo -e "${RED}Error: Type cannot be empty.${NC}" >&2
        exit 1
    fi
    
    if [[ -z "$command" ]]; then
        echo -e "${RED}Error: Command cannot be empty.${NC}" >&2
        exit 1
    fi
    
    # Validate type or get user confirmation for custom types
    if ! is_valid_type "$type"; then
        echo -e "${RED}Error: Invalid bookmark type: $type${NC}" >&2
        echo -e "Valid types: ${CYAN}${VALID_TYPES[*]}${NC}" >&2
        
        if ! get_user_confirmation "Do you want to continue with a custom type? (y/n): "; then
            exit 1
        fi
    fi
}

# Create bookmark JSON entry
# Args: $1 - description, $2 - type, $3 - command, $4 - tags, $5 - notes
# Returns: JSON string for the bookmark
create_bookmark_entry() {
    local description="$1"
    local type="$2"
    local command="$3"
    local tags="${4:-}"
    local notes="${5:-}"
    
    local id
    id=$(generate_id)
    local created
    created=$(date +"%Y-%m-%d %H:%M:%S")
    
    jq -n \
        --arg id "$id" \
        --arg desc "$description" \
        --arg type "$type" \
        --arg cmd "$command" \
        --arg tags "$tags" \
        --arg notes "$notes" \
        --arg created "$created" \
        '{id: $id, description: $desc, type: $type, command: $cmd, tags: $tags, notes: $notes, created: $created, status: "active"}'
}

# Add a new bookmark with improved validation and modularity
# Args: $1 - description, $2 - type, $3 - command, $4 - tags (optional), $5 - notes (optional)
add_bookmark() {
    local description="$1"
    local type="$2"
    local command="$3"
    local tags="${4:-}"
    local notes="${5:-}"
    
    # Validate JSON file first
    validate_bookmarks_file || exit 1
    
    # Validate input parameters
    validate_bookmark_input "$description" "$type" "$command"
    
    # Check for existing bookmark and handle accordingly
    if bookmark_exists "$description"; then
        echo -e "${YELLOW}A bookmark with description '$description' already exists.${NC}"
        
        if get_user_confirmation "Do you want to update it? (y/n): "; then
            update_bookmark "$description" "$type" "$command" "$tags" "$notes"
            return
        else
            echo -e "${YELLOW}Operation cancelled.${NC}"
            exit 0
        fi
    fi
    
    # Create and add the bookmark
    local entry
    entry=$(create_bookmark_entry "$description" "$type" "$command" "$tags" "$notes")
    
    local updated_json
    updated_json=$(jq --argjson entry "$entry" '.bookmarks += [$entry]' "$BOOKMARKS_FILE")
    echo "$updated_json" > "$BOOKMARKS_FILE"
    
    echo -e "${GREEN}Bookmark added: ${CYAN}$description${NC}"
}

# Interactive bookmark creation with improved user experience
# Prompts user for all bookmark fields with validation
interactive_add_bookmark() {
    echo -e "${BLUE}Adding a new bookmark interactively${NC}"
    echo ""
    
    # Get description with validation
    local description
    while [[ -z "${description:-}" ]]; do
        read -p "Description: " description
        if [[ -z "$description" ]]; then
            echo -e "${RED}Description cannot be empty.${NC}"
        fi
    done
    
    # Get type with validation
    echo -e "${CYAN}Valid types: ${VALID_TYPES[*]}${NC}"
    local type
    while [[ -z "${type:-}" ]]; do
        read -p "Type: " type
        if [[ -z "$type" ]]; then
            echo -e "${RED}Type cannot be empty.${NC}"
            continue
        fi
        
        # Validate type or confirm custom type
        if ! is_valid_type "$type"; then
            echo -e "${YELLOW}Warning: '$type' is not in the list of standard types.${NC}"
            echo -e "Standard types: ${CYAN}${VALID_TYPES[*]}${NC}"
            
            if ! get_user_confirmation "Do you want to continue with this custom type? (y/n): "; then
                echo -e "${YELLOW}Operation cancelled.${NC}"
                exit 0
            fi
        fi
    done
    
    # Get command with validation
    local command
    while [[ -z "${command:-}" ]]; do
        read -p "Command: " command
        if [[ -z "$command" ]]; then
            echo -e "${RED}Command cannot be empty.${NC}"
        fi
    done
    
    # Get optional fields
    local tags notes
    read -p "Tags (optional): " tags
    read -p "Notes (optional): " notes
    
    # Add the bookmark using the main function
    # Temporarily set NON_INTERACTIVE since we've handled user interaction
    local saved_non_interactive="$NON_INTERACTIVE"
    NON_INTERACTIVE=true
    add_bookmark "$description" "$type" "$command" "$tags" "$notes"
    NON_INTERACTIVE="$saved_non_interactive"
}

#=============================================================================
# USER INTERFACE FUNCTIONS
#=============================================================================

# Format bookmark data for display (optimized single jq call)
# Returns: formatted bookmark list for fzf
format_bookmarks_for_display() {
    # Single jq call to get all necessary data and format it
    jq -r '.bookmarks[] | 
        (if .status == "obsolete" then "[OBSOLETE] " else "" end) + 
        "[" + .type + "] " + .description + 
        "|" + .id + 
        "|" + .command + 
        "|" + .status' "$BOOKMARKS_FILE" | \
    while IFS="|" read -r display_line id command status; do
        if [[ "$status" == "obsolete" ]]; then
            echo -e "${RED}$display_line${NC}"
        else
            # Color the type and description differently
            local colored_line
            colored_line=$(echo "$display_line" | sed -E "s/\[([^\]]*)\]/\${CYAN}[\1]\${NC}/" | sed -E "s/\] (.*)$/\] \${YELLOW}\1\${NC}/")
            echo -e "$colored_line"
        fi
    done
}

# Extract description from formatted fzf line
# Args: $1 - formatted line from fzf
# Returns: clean description
extract_description_from_fzf_line() {
    local selected="$1"
    # Remove ANSI codes and extract description
    echo "$selected" | sed -E 's/\x1B\[[0-9;]*[mK]//g' | sed -E 's/^\[OBSOLETE\] \[(.*)\] (.*)/\2/' | sed -E 's/^\[(.*)\] (.*)/\2/'
}

# Select a bookmark using fzf with improved formatting
# Args: $1 - prompt message (optional)
# Returns: description of selected bookmark
select_bookmark_with_fzf() {
    local prompt="${1:-Select a bookmark}"
    
    # Get formatted bookmarks
    local formatted_bookmarks
    formatted_bookmarks=$(format_bookmarks_for_display)
    
    if [[ -z "$formatted_bookmarks" ]]; then
        echo -e "${YELLOW}No bookmarks found.${NC}" >&2
        return 1
    fi
    
    # Use fzf for interactive selection
    local selected
    selected=$(echo "$formatted_bookmarks" | fzf --ansi --height 40% --border --prompt="$prompt: ")
    
    if [[ -z "$selected" ]]; then
        return 1
    fi
    
    # Extract and return the description
    extract_description_from_fzf_line "$selected"
    return 0
}

# Update an existing bookmark with improved validation
# Args: $1 - description, $2 - type, $3 - command, $4 - tags (optional), $5 - notes (optional)
update_bookmark() {
    local description="$1"
    local type="$2"
    local command="$3"
    local tags="${4:-}"
    local notes="${5:-}"
    
    # Validate JSON file first
    validate_bookmarks_file || exit 1
    
    # Validate input parameters
    validate_bookmark_input "$description" "$type" "$command"
    
    # Check bookmark existence and uniqueness
    local count
    count=$(jq --arg desc "$description" '.bookmarks | map(select(.description == $desc)) | length' "$BOOKMARKS_FILE")
    
    if [[ "$count" -eq 0 ]]; then
        echo -e "${RED}No bookmark found with description: $description${NC}" >&2
        exit 1
    elif [[ "$count" -gt 1 ]]; then
        echo -e "${RED}Multiple bookmarks found with description: $description${NC}" >&2
        echo -e "Please provide a more specific description or use edit_bookmark with ID.${NC}" >&2
        exit 1
    fi
    
    # Update the bookmark with timestamp
    local modified
    modified=$(date +"%Y-%m-%d %H:%M:%S")
    
    local updated_json
    updated_json=$(jq --arg desc "$description" \
        --arg type "$type" \
        --arg cmd "$command" \
        --arg tags "$tags" \
        --arg notes "$notes" \
        --arg modified "$modified" \
        '.bookmarks = [.bookmarks[] | if .description == $desc then .type = $type | .command = $cmd | .tags = $tags | .notes = $notes | .modified = $modified else . end]' "$BOOKMARKS_FILE")
    
    echo "$updated_json" > "$BOOKMARKS_FILE"
    echo -e "${GREEN}Bookmark updated: ${CYAN}$description${NC}"
}

# Display current bookmark values for editing
# Args: $1 - bookmark JSON object
display_bookmark_for_editing() {
    local bookmark="$1"
    
    # Extract values using a single jq call for efficiency
    local values
    values=$(echo "$bookmark" | jq -r '[.description, .type, .command, .tags, .notes] | @tsv')
    
    # Parse the tab-separated values
    IFS=$'\t' read -r description type command tags notes <<< "$values"
    
    echo -e "${BLUE}Current values:${NC}"
    echo -e "  ${BLUE}Description:${NC} $description"
    echo -e "  ${BLUE}Type:${NC} $type"
    echo -e "  ${BLUE}Command:${NC} $command"
    echo -e "  ${BLUE}Tags:${NC} $tags"
    echo -e "  ${BLUE}Notes:${NC} $notes"
    echo ""
}

# Get new values from user for editing
# Args: $1 - current description, $2 - current type, $3 - current command, $4 - current tags, $5 - current notes
# Returns: tab-separated new values
get_new_values_for_editing() {
    local current_desc="$1" current_type="$2" current_cmd="$3" current_tags="$4" current_notes="$5"
    
    local new_description new_type new_command new_tags new_notes
    
    read -p "New description (leave empty to keep current): " new_description
    read -p "New type (leave empty to keep current): " new_type
    read -p "New command (leave empty to keep current): " new_command
    read -p "New tags (leave empty to keep current): " new_tags
    read -p "New notes (leave empty to keep current): " new_notes
    
    # Use current values if new ones are not provided
    new_description="${new_description:-$current_desc}"
    new_type="${new_type:-$current_type}"
    new_command="${new_command:-$current_cmd}"
    new_tags="${new_tags:-$current_tags}"
    new_notes="${new_notes:-$current_notes}"
    
    # Validate the new type
    if ! is_valid_type "$new_type"; then
        echo -e "${YELLOW}Warning: '$new_type' is not in the list of standard types.${NC}"
        echo -e "Standard types: ${CYAN}${VALID_TYPES[*]}${NC}"
        
        if ! get_user_confirmation "Do you want to continue with this custom type? (y/n): "; then
            echo -e "${YELLOW}Operation cancelled.${NC}"
            exit 0
        fi
    fi
    
    # Return tab-separated values
    printf "%s\t%s\t%s\t%s\t%s" "$new_description" "$new_type" "$new_command" "$new_tags" "$new_notes"
}

# Edit a bookmark interactively with improved modularity
# Args: $1 - ID or description (optional, uses fzf if not provided)
edit_bookmark() {
    local id_or_desc="${1:-}"
    
    # If no argument provided, use fzf to select
    if [[ -z "$id_or_desc" ]]; then
        id_or_desc=$(select_bookmark_with_fzf "Select bookmark to edit")
        if [[ $? -ne 0 ]] || [[ -z "$id_or_desc" ]]; then
            echo -e "${YELLOW}No bookmark selected.${NC}"
            exit 0
        fi
    fi
    
    # Validate JSON file first
    validate_bookmarks_file || exit 1
    
    # Find the bookmark using the optimized function
    local bookmark
    bookmark=$(get_bookmark_by_id_or_desc "$id_or_desc")
    
    if [[ -z "$bookmark" ]]; then
        echo -e "${RED}No bookmark found with ID or description: $id_or_desc${NC}" >&2
        exit 1
    fi
    
    # Extract current values efficiently
    local current_values
    current_values=$(echo "$bookmark" | jq -r '[.id, .description, .type, .command, .tags, .notes] | @tsv')
    IFS=$'\t' read -r id description type command tags notes <<< "$current_values"
    
    echo -e "${BLUE}Editing bookmark: ${CYAN}$description${NC}"
    display_bookmark_for_editing "$bookmark"
    
    # Get new values from user
    local new_values
    new_values=$(get_new_values_for_editing "$description" "$type" "$command" "$tags" "$notes")
    IFS=$'\t' read -r new_description new_type new_command new_tags new_notes <<< "$new_values"
    
    # Update the bookmark with timestamp
    local modified
    modified=$(date +"%Y-%m-%d %H:%M:%S")
    
    local updated_json
    updated_json=$(jq --arg id "$id" \
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

# Delete a bookmark with improved confirmation and error handling
# Args: $1 - ID or description (optional, uses fzf if not provided)
delete_bookmark() {
    local id_or_desc="${1:-}"
    
    # If no argument provided, use fzf to select
    if [[ -z "$id_or_desc" ]]; then
        id_or_desc=$(select_bookmark_with_fzf "Select bookmark to delete")
        if [[ $? -ne 0 ]] || [[ -z "$id_or_desc" ]]; then
            echo -e "${YELLOW}No bookmark selected.${NC}"
            exit 0
        fi
    fi
    
    # Validate JSON file first
    validate_bookmarks_file || exit 1
    
    # Find the bookmark using the optimized function
    local bookmark
    bookmark=$(get_bookmark_by_id_or_desc "$id_or_desc")
    
    if [[ -z "$bookmark" ]]; then
        echo -e "${RED}No bookmark found with ID or description: $id_or_desc${NC}" >&2
        exit 1
    fi
    
    # Extract description for confirmation
    local description
    description=$(echo "$bookmark" | jq -r '.description')
    
    echo -e "${YELLOW}You are about to delete the bookmark: ${CYAN}$description${NC}"
    
    if get_user_confirmation "Are you sure? (y/n): "; then
        # Delete the bookmark (determine method based on ID format)
        local updated_json
        if [[ "$id_or_desc" == *"_"* ]]; then
            # Delete by ID
            updated_json=$(jq --arg id "$id_or_desc" '.bookmarks = [.bookmarks[] | select(.id != $id)]' "$BOOKMARKS_FILE")
        else
            # Delete by description
            updated_json=$(jq --arg desc "$id_or_desc" '.bookmarks = [.bookmarks[] | select(.description != $desc)]' "$BOOKMARKS_FILE")
        fi
        
        echo "$updated_json" > "$BOOKMARKS_FILE"
        echo -e "${GREEN}Bookmark deleted: ${CYAN}$description${NC}"
    else
        echo -e "${YELLOW}Deletion cancelled.${NC}"
    fi
}

# Toggle bookmark obsolete status with improved logic
# Args: $1 - ID or description (optional, uses fzf if not provided)
obsolete_bookmark() {
    local id_or_desc="${1:-}"
    
    # If no argument provided, use fzf to select
    if [[ -z "$id_or_desc" ]]; then
        id_or_desc=$(select_bookmark_with_fzf "Select bookmark to mark obsolete")
        if [[ $? -ne 0 ]] || [[ -z "$id_or_desc" ]]; then
            echo -e "${YELLOW}No bookmark selected.${NC}"
            exit 0
        fi
    fi
    
    # Validate JSON file first
    validate_bookmarks_file || exit 1
    
    # Find the bookmark using the optimized function
    local bookmark
    bookmark=$(get_bookmark_by_id_or_desc "$id_or_desc")
    
    if [[ -z "$bookmark" ]]; then
        echo -e "${RED}No bookmark found with ID or description: $id_or_desc${NC}" >&2
        exit 1
    fi
    
    # Extract description and current status efficiently
    local bookmark_info
    bookmark_info=$(echo "$bookmark" | jq -r '[.description, .status] | @tsv')
    IFS=$'\t' read -r description status <<< "$bookmark_info"
    
    # Determine action based on current status
    local new_status message
    if [[ "$status" == "obsolete" ]]; then
        echo -e "${YELLOW}This bookmark is already marked as obsolete: ${CYAN}$description${NC}"
        
        if get_user_confirmation "Do you want to restore it to active status? (y/n): "; then
            new_status="active"
            message="restored to active"
        else
            echo -e "${YELLOW}Operation cancelled.${NC}"
            exit 0
        fi
    else
        echo -e "${YELLOW}You are about to mark the bookmark as obsolete: ${CYAN}$description${NC}"
        
        if get_user_confirmation "Continue? (y/n): "; then
            new_status="obsolete"
            message="marked as obsolete"
        else
            echo -e "${YELLOW}Operation cancelled.${NC}"
            exit 0
        fi
    fi
    
    # Update the bookmark status
    local updated_json
    if [[ "$id_or_desc" == *"_"* ]]; then
        # Update by ID
        updated_json=$(jq --arg id "$id_or_desc" --arg status "$new_status" \
            '.bookmarks = [.bookmarks[] | if .id == $id then .status = $status else . end]' "$BOOKMARKS_FILE")
    else
        # Update by description
        updated_json=$(jq --arg desc "$id_or_desc" --arg status "$new_status" \
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

#=============================================================================
# BOOKMARK LISTING AND EXECUTION FUNCTIONS
#=============================================================================

# Execute a bookmark after validating its status
# Args: $1 - bookmark JSON object, $2 - description
execute_selected_bookmark() {
    local bookmark="$1"
    local description="$2"
    
    # Extract command, type, and status efficiently
    local bookmark_data
    bookmark_data=$(echo "$bookmark" | jq -r '[.command, .type, .status] | @tsv')
    IFS=$'\t' read -r command type status <<< "$bookmark_data"
    
    # Check if bookmark is obsolete
    if [[ "$status" == "obsolete" ]]; then
        echo -e "${YELLOW}Warning: This bookmark is marked as obsolete.${NC}"
        
        if ! get_user_confirmation "Do you still want to execute it? (y/n): "; then
            return
        fi
    fi
    
    echo -e "${GREEN}Executing: ${CYAN}$description${NC}"
    echo -e "${BLUE}Type: ${NC}$type"
    echo -e "${BLUE}Command: ${NC}$command"
    
    # Execute the command based on bookmark type
    execute_bookmark_by_type "$type" "$command" "$description"
}

# List and optionally execute bookmarks with fuzzy search
# Args: $1 - search term (optional)
list_bookmarks() {
    local search_term="${1:-}"
    
    # Validate JSON file first
    validate_bookmarks_file || return 1
    
    # Get formatted bookmarks for display
    local formatted_bookmarks
    formatted_bookmarks=$(format_bookmarks_for_display)
    
    if [[ -z "$formatted_bookmarks" ]]; then
        echo -e "${YELLOW}No bookmarks found.${NC}"
        return
    fi
    
    # Select bookmark based on search term or interactively
    local selected
    if [[ -z "$search_term" ]]; then
        # No search term provided, use fzf for interactive selection
        selected=$(echo "$formatted_bookmarks" | fzf --ansi --height 40% --border)
    else
        # Use the search term with fzf filter
        selected=$(echo "$formatted_bookmarks" | fzf --ansi --filter="$search_term" | head -1)
    fi
    
    if [[ -n "$selected" ]]; then
        # Extract the description from the formatted line
        local description
        description=$(extract_description_from_fzf_line "$selected")
        
        # Get the bookmark data using optimized function
        local bookmark
        bookmark=$(get_bookmark_by_id_or_desc "$description")
        
        # Execute the selected bookmark
        execute_selected_bookmark "$bookmark" "$description"
    fi
}

# Display bookmarks grouped by type with color coding
display_bookmarks_by_type() {
    # Single optimized jq call to group and format bookmarks
    jq -r '
        .bookmarks | 
        sort_by(.type) | 
        group_by(.type) | 
        .[] | 
        "Type: " + .[0].type + "\n" + 
        (map("  " + (if .status == "obsolete" then "🚫 " else "✅ " end) + .description) | join("\n")) + "\n"
    ' "$BOOKMARKS_FILE" | \
    while IFS= read -r line; do
        if [[ "$line" == Type:* ]]; then
            echo -e "${CYAN}$line${NC}"
        elif [[ "$line" == *"🚫"* ]]; then
            echo -e "${RED}$line${NC}"
        elif [[ -n "$line" ]]; then
            echo -e "$line"
        fi
    done
}

# Display detailed bookmark information with color coding
display_detailed_bookmarks() {
    echo -e "\n${BLUE}Bookmark Details:${NC}"
    echo -e "${BLUE}----------------${NC}"
    
    # Optimized jq call to format all bookmark details
    jq -r '.bookmarks[] | 
        "ID: " + .id + "\n" +
        "Description: " + .description + "\n" +
        "Type: " + .type + "\n" +
        "Command: " + .command + "\n" +
        "Tags: " + (.tags // "") + "\n" +
        "Notes: " + (.notes // "") + "\n" +
        "Created: " + (.created // "") + "\n" +
        "Status: " + .status + "\n"
    ' "$BOOKMARKS_FILE" | \
    while IFS= read -r line; do
        case "$line" in
            Description:*) echo -e "${YELLOW}$line${NC}" ;;
            ID:*|Type:*|Command:*|Tags:*|Notes:*|Created:*) echo -e "${BLUE}$line${NC}" ;;
            Status:*) 
                if [[ "$line" == *"obsolete"* ]]; then
                    echo -e "${RED}$line${NC}"
                else
                    echo -e "${GREEN}$line${NC}"
                fi
                ;;
            "") echo ;; # Empty line
            *) echo "$line" ;;
        esac
    done
}

# List all bookmarks without executing them
# Args: $1 - show_details flag ("true" to show details, default "false")
list_all_bookmarks() {
    local show_details="${1:-false}"
    
    # Validate JSON file first
    validate_bookmarks_file || return 1
    
    echo -e "${BLUE}All Bookmarks:${NC}"
    echo -e "${BLUE}-------------${NC}"
    
    # Display bookmarks grouped by type
    display_bookmarks_by_type
    
    # Show detailed information if requested
    if [[ "$show_details" == "true" ]]; then
        display_detailed_bookmarks
    fi
}

# Search bookmarks by tags with optimized display
# Args: $1 - tag to search for
search_by_tag() {
    local tag="$1"
    
    # Validate JSON file first
    validate_bookmarks_file || return 1
    
    echo -e "${BLUE}Bookmarks with tag: ${CYAN}$tag${NC}"
    echo -e "${BLUE}---------------------${NC}"
    
    # Optimized jq call to filter and format in one operation
    local results
    results=$(jq -r --arg tag "$tag" '
        .bookmarks[] | 
        select(.tags | contains($tag)) | 
        (if .status == "obsolete" then "[OBSOLETE] " else "" end) + 
        "[" + .type + "] " + .description
    ' "$BOOKMARKS_FILE")
    
    if [[ -z "$results" ]]; then
        echo -e "${YELLOW}No bookmarks found with tag: $tag${NC}"
        return
    fi
    
    # Display results with appropriate coloring
    echo "$results" | while IFS= read -r line; do
        if [[ "$line" == *"[OBSOLETE]"* ]]; then
            echo -e "${RED}$line${NC}"
        else
            # Color the type and description differently
            local colored_line
            colored_line=$(echo "$line" | sed -E "s/\[([^\]]*)\]/\${CYAN}[\1]\${NC}/" | sed -E "s/\] (.*)$/\] \${YELLOW}\1\${NC}/")
            echo -e "$colored_line"
        fi
    done
}



#=============================================================================
# BACKUP AND RESTORE FUNCTIONS
#=============================================================================

# Create a timestamped backup of the bookmarks file
backup_bookmarks() {
    local backup_dir="$BOOKMARKS_DIR/backups"
    mkdir -p "$backup_dir"
    
    # Validate JSON file before backup
    validate_bookmarks_file || {
        echo -e "${RED}Cannot backup invalid JSON file${NC}" >&2
        return 1
    }
    
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$backup_dir/bookmarks_$timestamp.json"
    
    if cp "$BOOKMARKS_FILE" "$backup_file"; then
        echo -e "${GREEN}Backup created: ${CYAN}$backup_file${NC}"
        
        # Clean up old backups - keep last N backups (configurable)
        local retention_count="${BACKUP_RETENTION:-$DEFAULT_BACKUP_RETENTION}"
        local old_backups
        old_backups=$(ls -t "$backup_dir"/bookmarks_*.json 2>/dev/null | tail -n +$((retention_count + 1)))
        
        if [[ -n "$old_backups" ]]; then
            echo "$old_backups" | xargs rm -f
            echo -e "${BLUE}Kept last $retention_count backups in ${CYAN}$backup_dir${NC}"
        fi
    else
        echo -e "${RED}Failed to create backup${NC}" >&2
        return 1
    fi
}

# Format backup filename for display
# Args: $1 - backup filename
# Returns: formatted date string
format_backup_date() {
    local backup_file="$1"
    local basename_file
    basename_file=$(basename "$backup_file")
    
    # Extract date components from filename
    if [[ "$basename_file" =~ bookmarks_([0-9]{8})_([0-9]{6})\.json ]]; then
        local date_part="${BASH_REMATCH[1]}"
        local time_part="${BASH_REMATCH[2]}"
        
        # Format as YYYY-MM-DD HH:MM:SS
        echo "${date_part:0:4}-${date_part:4:2}-${date_part:6:2} ${time_part:0:2}:${time_part:2:2}:${time_part:4:2}"
    else
        echo "$basename_file"
    fi
}

# Restore bookmarks from a backup with improved validation
restore_from_backup() {
    local backup_dir="$BOOKMARKS_DIR/backups"
    
    if [[ ! -d "$backup_dir" ]]; then
        echo -e "${RED}No backups directory found.${NC}" >&2
        exit 1
    fi
    
    # Get available backups sorted by modification time (newest first)
    local backups
    readarray -t backups < <(ls -t "$backup_dir"/bookmarks_*.json 2>/dev/null)
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        echo -e "${RED}No backup files found.${NC}" >&2
        exit 1
    fi
    
    echo -e "${BLUE}Available backups:${NC}"
    for i in "${!backups[@]}"; do
        local formatted_date
        formatted_date=$(format_backup_date "${backups[i]}")
        echo -e "  ${BLUE}$((i+1)))${NC} $formatted_date"
    done
    
    local selection="1"
    if [[ "$NON_INTERACTIVE" == "false" ]]; then
        read -p "Enter backup number to restore (0 to cancel): " selection
    fi
    
    # Validate selection
    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le ${#backups[@]} ]]; then
        local selected_backup="${backups[$((selection-1))]}"
        
        # Validate the backup file before restoring
        if ! jq empty "$selected_backup" 2>/dev/null; then
            echo -e "${RED}Selected backup file is corrupted or invalid${NC}" >&2
            exit 1
        fi
        
        echo -e "${YELLOW}You are about to restore from: ${CYAN}$(basename "$selected_backup")${NC}"
        echo -e "${RED}This will overwrite your current bookmarks!${NC}"
        
        if get_user_confirmation "Continue? (y/n): "; then
            if cp "$selected_backup" "$BOOKMARKS_FILE"; then
                echo -e "${GREEN}Bookmarks restored from: ${CYAN}$(basename "$selected_backup")${NC}"
            else
                echo -e "${RED}Failed to restore backup${NC}" >&2
                exit 1
            fi
        else
            echo -e "${YELLOW}Restore cancelled.${NC}"
        fi
    else
        echo -e "${YELLOW}Restore cancelled.${NC}"
    fi
}

#=============================================================================
# HOOK SYSTEM
#=============================================================================

# Execute a hook script if it exists
# Args: $1 - hook name (without .sh extension)
run_hook() {
    local hook_name="$1"
    local hook_script="$BOOKMARKS_DIR/hooks/$hook_name.sh"
    
    if [[ -f "$hook_script" ]] && [[ -x "$hook_script" ]]; then
        echo -e "${BLUE}Running hook: ${CYAN}$hook_name${NC}"
        if ! bash "$hook_script" "$BOOKMARKS_DIR" "$BOOKMARKS_FILE"; then
            echo -e "${YELLOW}Warning: Hook $hook_name failed${NC}" >&2
        fi
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
