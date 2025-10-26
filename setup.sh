#!/bin/bash

# Setup script for Universal Bookmarks

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Determine the shell being used
SHELL_NAME=$(basename "$SHELL")
RC_FILE=""

# Get the absolute path of the script directory without realpath
get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    local dir=""
    
    # Resolve $source until the file is no longer a symlink
    while [ -L "$source" ]; do
        dir="$( cd -P "$( dirname "$source" )" && pwd )"
        source="$(readlink "$source")"
        # If $source was a relative symlink, we need to resolve it relative to the path where 
        # the symlink file was located
        [[ $source != /* ]] && source="$dir/$source"
    done
    dir="$( cd -P "$( dirname "$source" )" && pwd )"
    echo "$dir"
}

# Check for dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for fzf
    if ! command -v fzf &> /dev/null; then
        missing_deps+=("fzf")
    fi
    
    # Check for jq
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}Missing dependencies: ${CYAN}${missing_deps[*]}${NC}"
        echo -e "${YELLOW}Please install the missing dependencies before continuing.${NC}"
        
        if [[ " ${missing_deps[*]} " =~ " jq " ]]; then
            echo -e "Install jq: ${CYAN}sudo apt install jq${NC} (Debian/Ubuntu) or ${CYAN}brew install jq${NC} (macOS)"
        fi
        
        if [[ " ${missing_deps[*]} " =~ " fzf " ]]; then
            echo -e "Install fzf: ${CYAN}https://github.com/junegunn/fzf#installation${NC}"
        fi
        
        read -p "Do you want to continue anyway? (y/n): " continue_anyway
        if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
            echo -e "${RED}Setup aborted.${NC}"
            exit 1
        fi
    fi
}

# Shell detection and configuration
case "$SHELL_NAME" in
    bash)
        RC_FILE="$HOME/.bashrc"
        ;;
    zsh)
        RC_FILE="$HOME/.zshrc"
        ;;
    fish)
        RC_FILE="$HOME/.config/fish/config.fish"
        ;;
    dash)
        RC_FILE="$HOME/.profile"
        ;;
    ksh)
        RC_FILE="$HOME/.kshrc"
        ;;
    *)
        echo -e "${YELLOW}Shell not automatically recognized: $SHELL_NAME${NC}"
        echo -e "Select your shell configuration file:"
        echo -e "  ${CYAN}1)${NC} .bashrc (Bash)"
        echo -e "  ${CYAN}2)${NC} .zshrc (Zsh)"
        echo -e "  ${CYAN}3)${NC} .config/fish/config.fish (Fish)"
        echo -e "  ${CYAN}4)${NC} .profile (Generic)"
        echo -e "  ${CYAN}5)${NC} Custom path"
        
        read -p "Enter your choice (1-5): " shell_choice
        
        case $shell_choice in
            1) RC_FILE="$HOME/.bashrc" ;;
            2) RC_FILE="$HOME/.zshrc" ;;
            3) RC_FILE="$HOME/.config/fish/config.fish" ;;
            4) RC_FILE="$HOME/.profile" ;;
            5) 
                read -p "Enter the full path to your shell configuration file: " RC_FILE
                ;;
            *)
                echo -e "${RED}Invalid choice.${NC}"
                echo -e "${YELLOW}Please manually add the following to your shell configuration file:${NC}"
                echo 'export BOOKMARKS_DIR="$HOME/.bookmarks"'
                echo 'alias bookmark="/path/to/bookmarks.sh"'
                exit 1
                ;;
        esac
        ;;
esac

# Check for dependencies
check_dependencies

# Create bookmarks directory if it doesn't exist
mkdir -p "$HOME/.bookmarks"
echo -e "${GREEN}Created directory: $HOME/.bookmarks${NC}"

# Create bookmarks file if it doesn't exist
if [ ! -f "$HOME/.bookmarks/bookmarks.json" ]; then
    echo '{"bookmarks":[]}' > "$HOME/.bookmarks/bookmarks.json"
    echo -e "${GREEN}Created bookmarks file: $HOME/.bookmarks/bookmarks.json${NC}"
fi

# Create hooks directory if it doesn't exist
mkdir -p "$HOME/.bookmarks/hooks"
echo -e "${GREEN}Created hooks directory: $HOME/.bookmarks/hooks${NC}"

# Create backups directory if it doesn't exist
mkdir -p "$HOME/.bookmarks/backups"
echo -e "${GREEN}Created backups directory: $HOME/.bookmarks/backups${NC}"

# Get the script directory
SCRIPT_DIR=$(get_script_dir)

# Function to display proposed shell configuration changes
show_proposed_changes() {
    local rc_file="$1"
    local script_dir="$2"
    
    echo -e "${CYAN}=== Proposed Changes to $rc_file ===${NC}"
    echo ""
    
    if [[ "$rc_file" == *"fish"* ]]; then
        echo -e "${YELLOW}The following lines will be added:${NC}"
        echo ""
        echo "# Universal Bookmarks configuration"
        echo "set -x BOOKMARKS_DIR \"\$HOME/.bookmarks\""
        echo "alias bookmark=\"$script_dir/bookmarks.sh\""
    else
        echo -e "${YELLOW}The following lines will be added:${NC}"
        echo ""
        echo "# Universal Bookmarks configuration"
        echo "export BOOKMARKS_DIR=\"\$HOME/.bookmarks\""
        echo "alias bookmark=\"$script_dir/bookmarks.sh\""
    fi
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

# Function to show and ask permission for completion configuration changes
ask_completion_permission() {
    local rc_file="$1"
    local lines_to_add="$2"
    
    echo -e "${CYAN}=== Proposed Completion Changes to $rc_file ===${NC}"
    echo ""
    echo -e "${YELLOW}The following lines will be added:${NC}"
    echo ""
    echo "$lines_to_add"
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    read -p "Do you want to add these completion lines to $rc_file? (y/n): " user_consent
    if [[ "$user_consent" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Handle fish shell differently
if [[ "$RC_FILE" == *"fish"* ]]; then
    if ! grep -q "BOOKMARKS_DIR" "$RC_FILE" 2>/dev/null; then
        # Show proposed changes
        show_proposed_changes "$RC_FILE" "$SCRIPT_DIR"
        
        # Ask for permission
        read -p "Do you want to add these lines to $RC_FILE? (y/n): " user_consent
        if [[ "$user_consent" =~ ^[Yy]$ ]]; then
            echo '' >> "$RC_FILE"
            echo '# Universal Bookmarks configuration' >> "$RC_FILE"
            echo 'set -x BOOKMARKS_DIR "$HOME/.bookmarks"' >> "$RC_FILE"
            echo "alias bookmark=\"$SCRIPT_DIR/bookmarks.sh\"" >> "$RC_FILE"
            
            echo -e "${GREEN}Configuration added to $RC_FILE${NC}"
            echo -e "${YELLOW}Please restart your shell or run 'source $RC_FILE'${NC}"
        else
            echo -e "${YELLOW}Configuration not added. You can manually add the following to $RC_FILE:${NC}"
            echo 'set -x BOOKMARKS_DIR "$HOME/.bookmarks"'
            echo "alias bookmark=\"$SCRIPT_DIR/bookmarks.sh\""
        fi
    else
        echo -e "${YELLOW}Configuration already exists in $RC_FILE${NC}"
    fi
else
    # Add environment variable and alias to shell configuration for bash/zsh and others
    if ! grep -q "BOOKMARKS_DIR" "$RC_FILE" 2>/dev/null; then
        # Get the absolute path of the bookmarks.sh script without using realpath
        SCRIPT_PATH="$SCRIPT_DIR/bookmarks.sh"
        
        # Show proposed changes
        show_proposed_changes "$RC_FILE" "$SCRIPT_DIR"
        
        # Ask for permission
        read -p "Do you want to add these lines to $RC_FILE? (y/n): " user_consent
        if [[ "$user_consent" =~ ^[Yy]$ ]]; then
            echo '' >> "$RC_FILE"
            echo '# Universal Bookmarks configuration' >> "$RC_FILE"
            echo 'export BOOKMARKS_DIR="$HOME/.bookmarks"' >> "$RC_FILE"
            echo "alias bookmark=\"$SCRIPT_PATH\"" >> "$RC_FILE"
            
            echo -e "${GREEN}Configuration added to $RC_FILE${NC}"
            echo -e "${YELLOW}Please restart your shell or run 'source $RC_FILE'${NC}"
        else
            echo -e "${YELLOW}Configuration not added. You can manually add the following to $RC_FILE:${NC}"
            echo 'export BOOKMARKS_DIR="$HOME/.bookmarks"'
            echo "alias bookmark=\"$SCRIPT_PATH\""
        fi
    else
        echo -e "${YELLOW}Configuration already exists in $RC_FILE${NC}"
    fi
fi

# Install autocompletion files
install_autocompletion() {
    local autocomp_installed=false
    
    if [[ "$SHELL_NAME" == "zsh" ]]; then
        # Try to find zsh completion directory
        local zsh_comp_dirs=(
            "$HOME/.local/share/zsh/site-functions"
            "$HOME/.zsh/completions"
            "$HOME/.config/zsh/completions"
            "/usr/local/share/zsh/site-functions"
            "/usr/share/zsh/site-functions"
        )
        
        for comp_dir in "${zsh_comp_dirs[@]}"; do
            if [[ -d "$comp_dir" ]] || [[ "$comp_dir" == "$HOME"* ]]; then
                # Create directory if it's in user home and doesn't exist
                if [[ "$comp_dir" == "$HOME"* ]] && [[ ! -d "$comp_dir" ]]; then
                    mkdir -p "$comp_dir"
                fi
                
                # Try to install completion file
                if [[ -w "$comp_dir" ]] || [[ "$comp_dir" == "$HOME"* ]]; then
                    cp "$SCRIPT_DIR/completions/_bookmark" "$comp_dir/_bookmark" 2>/dev/null && {
                        echo -e "${GREEN}Installed zsh completion to: $comp_dir/_bookmark${NC}"
                        autocomp_installed=true
                        
                        # Add fpath to .zshrc if it's a custom directory
                        if [[ "$comp_dir" == "$HOME"* ]] && ! grep -q "fpath.*$comp_dir" "$HOME/.zshrc" 2>/dev/null; then
                            local completion_lines="# Add custom completion directory to fpath
fpath=(\"$comp_dir\" \$fpath)
autoload -Uz compinit && compinit"
                            
                            if ask_completion_permission "$HOME/.zshrc" "$completion_lines"; then
                                echo '' >> "$HOME/.zshrc"
                                echo "# Add custom completion directory to fpath" >> "$HOME/.zshrc"
                                echo "fpath=(\"$comp_dir\" \$fpath)" >> "$HOME/.zshrc"
                                echo "autoload -Uz compinit && compinit" >> "$HOME/.zshrc"
                                echo -e "${GREEN}Added completion directory to .zshrc${NC}"
                            else
                                echo -e "${YELLOW}Completion configuration not added. You can manually add the following to $HOME/.zshrc:${NC}"
                                echo "$completion_lines"
                            fi
                        fi
                        break
                    }
                fi
            fi
        done
        
        if [[ "$autocomp_installed" == false ]]; then
            # Fallback: create user completion directory
            mkdir -p "$HOME/.zsh/completions"
            cp "$SCRIPT_DIR/completions/_bookmark" "$HOME/.zsh/completions/_bookmark"
            echo -e "${GREEN}Installed zsh completion to: $HOME/.zsh/completions/_bookmark${NC}"
            
            if ! grep -q "fpath.*/.zsh/completions" "$HOME/.zshrc" 2>/dev/null; then
                local completion_lines="# Add custom completion directory to fpath
fpath=(\"\$HOME/.zsh/completions\" \$fpath)
autoload -Uz compinit && compinit"
                
                if ask_completion_permission "$HOME/.zshrc" "$completion_lines"; then
                    echo '' >> "$HOME/.zshrc"
                    echo "# Add custom completion directory to fpath" >> "$HOME/.zshrc"
                    echo "fpath=(\"\$HOME/.zsh/completions\" \$fpath)" >> "$HOME/.zshrc"
                    echo "autoload -Uz compinit && compinit" >> "$HOME/.zshrc"
                    echo -e "${GREEN}Added completion directory to .zshrc${NC}"
                else
                    echo -e "${YELLOW}Completion configuration not added. You can manually add the following to $HOME/.zshrc:${NC}"
                    echo "$completion_lines"
                fi
            fi
            autocomp_installed=true
        fi
        
    elif [[ "$SHELL_NAME" == "bash" ]]; then
        # Try to find bash completion directory
        local bash_comp_dirs=(
            "$HOME/.local/share/bash-completion/completions"
            "$HOME/.bash_completion.d"
            "/usr/local/etc/bash_completion.d"
            "/etc/bash_completion.d"
            "/usr/share/bash-completion/completions"
        )
        
        for comp_dir in "${bash_comp_dirs[@]}"; do
            if [[ -d "$comp_dir" ]] || [[ "$comp_dir" == "$HOME"* ]]; then
                # Create directory if it's in user home and doesn't exist
                if [[ "$comp_dir" == "$HOME"* ]] && [[ ! -d "$comp_dir" ]]; then
                    mkdir -p "$comp_dir"
                fi
                
                # Try to install completion file
                if [[ -w "$comp_dir" ]] || [[ "$comp_dir" == "$HOME"* ]]; then
                    cp "$SCRIPT_DIR/completions/bookmark-completion.bash" "$comp_dir/bookmark" 2>/dev/null && {
                        echo -e "${GREEN}Installed bash completion to: $comp_dir/bookmark${NC}"
                        autocomp_installed=true
                        break
                    }
                fi
            fi
        done
        
        if [[ "$autocomp_installed" == false ]]; then
            # Fallback: source completion directly in .bashrc
            if ! grep -q "bookmark-completion.bash" "$HOME/.bashrc" 2>/dev/null; then
                local completion_lines="# Universal Bookmarks completion
source \"$SCRIPT_DIR/completions/bookmark-completion.bash\""
                
                if ask_completion_permission "$HOME/.bashrc" "$completion_lines"; then
                    echo '' >> "$HOME/.bashrc"
                    echo "# Universal Bookmarks completion" >> "$HOME/.bashrc"
                    echo "source \"$SCRIPT_DIR/completions/bookmark-completion.bash\"" >> "$HOME/.bashrc"
                    echo -e "${GREEN}Added completion source to .bashrc${NC}"
                    autocomp_installed=true
                else
                    echo -e "${YELLOW}Completion configuration not added. You can manually add the following to $HOME/.bashrc:${NC}"
                    echo "$completion_lines"
                fi
            fi
        fi
    fi
    
    if [[ "$autocomp_installed" == true ]]; then
        echo -e "${CYAN}Shell autocompletion installed successfully!${NC}"
        echo -e "${YELLOW}You may need to restart your shell or run 'exec \$SHELL' to activate completion${NC}"
    else
        echo -e "${YELLOW}Could not install autocompletion automatically.${NC}"
        echo -e "You can manually install completion files from: $SCRIPT_DIR/completions/"
    fi
}

# Create example hook file
if [ ! -f "$HOME/.bookmarks/hooks/after_add.sh.example" ]; then
    cat > "$HOME/.bookmarks/hooks/after_add.sh.example" << 'EOF'
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
    chmod +x "$HOME/.bookmarks/hooks/after_add.sh.example"
    echo -e "${GREEN}Created example hook: $HOME/.bookmarks/hooks/after_add.sh.example${NC}"
fi

# Install autocompletion
install_autocompletion

echo -e "${GREEN}Universal Bookmarks setup completed!${NC}"
echo -e "${BLUE}Directory:${NC} $HOME/.bookmarks"
echo -e "${BLUE}Bookmarks file:${NC} $HOME/.bookmarks/bookmarks.json"
echo ""
echo -e "${CYAN}You can now use the 'bookmark' command to manage your bookmarks:${NC}"
echo "  bookmark add \"Description\" type \"command\" [tags] [notes]   # Add a new bookmark"
echo "  bookmark add                                       # Add a bookmark interactively"
echo "  bookmark edit [\"Description or ID\"]                   # Edit a bookmark interactively (uses fzf if no argument)"
echo "  bookmark delete [\"Description or ID\"]                 # Delete a bookmark (uses fzf if no argument)"
echo "  bookmark obsolete [\"Description or ID\"]               # Mark a bookmark as obsolete (uses fzf if no argument)"
echo "  bookmark list                                      # List all bookmarks without executing"
echo "  bookmark details                                   # List all bookmarks with details"
echo "  bookmark [search term]                             # Search and execute a bookmark"
echo ""
echo -e "${BLUE}For complete documentation, run:${NC} bookmark help"
