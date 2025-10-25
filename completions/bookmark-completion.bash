# Bash completion for Universal Bookmarks
# Place this file in /etc/bash_completion.d/ or source it from your .bashrc

_bookmark_completion() {
    local cur prev opts commands types
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Check if BOOKMARKS_DIR is set and bookmarks file exists
    if [[ -z "$BOOKMARKS_DIR" ]] || [[ ! -f "$BOOKMARKS_DIR/bookmarks.json" ]]; then
        return 0
    fi
    
    # Available commands
    commands="add edit modify-add update delete obsolete list details tag backup restore help"
    
    # Bookmark types
    types="url pdf script ssh app cmd note folder file edit custom"
    
    # Handle flags
    if [[ ${cur} == -* ]]; then
        opts="-y --yes"
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi
    
    # First argument: command completion
    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )
        return 0
    fi
    
    # Get the command (first argument)
    local cmd="${COMP_WORDS[1]}"
    
    case "${cmd}" in
        add)
            case ${COMP_CWORD} in
                2)
                    # Description - no completion, let user type
                    return 0
                    ;;
                3)
                    # Type completion
                    COMPREPLY=( $(compgen -W "${types}" -- ${cur}) )
                    return 0
                    ;;
                4)
                    # Command - no completion, let user type
                    return 0
                    ;;
                5)
                    # Tags completion
                    if command -v jq >/dev/null 2>&1; then
                        local tags=$(jq -r '.bookmarks[].tags' "$BOOKMARKS_DIR/bookmarks.json" 2>/dev/null | \
                                   tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ')
                        COMPREPLY=( $(compgen -W "${tags}" -- ${cur}) )
                    fi
                    return 0
                    ;;
                6)
                    # Notes - no completion, let user type
                    return 0
                    ;;
            esac
            ;;
        edit|delete|obsolete)
            if [[ ${COMP_CWORD} -eq 2 ]]; then
                # Complete with bookmark descriptions
                if command -v jq >/dev/null 2>&1; then
                    local descriptions=$(jq -r '.bookmarks[].description' "$BOOKMARKS_DIR/bookmarks.json" 2>/dev/null | tr '\n' '|')
                    # Handle spaces in descriptions by using a different approach
                    local IFS=$'\n'
                    local desc_array=($(jq -r '.bookmarks[].description' "$BOOKMARKS_DIR/bookmarks.json" 2>/dev/null))
                    COMPREPLY=( $(compgen -W "$(printf '%s\n' "${desc_array[@]}")" -- ${cur}) )
                fi
            fi
            return 0
            ;;
        update)
            case ${COMP_CWORD} in
                2)
                    # Complete with bookmark descriptions
                    if command -v jq >/dev/null 2>&1; then
                        local IFS=$'\n'
                        local desc_array=($(jq -r '.bookmarks[].description' "$BOOKMARKS_DIR/bookmarks.json" 2>/dev/null))
                        COMPREPLY=( $(compgen -W "$(printf '%s\n' "${desc_array[@]}")" -- ${cur}) )
                    fi
                    return 0
                    ;;
                3)
                    # Type completion
                    COMPREPLY=( $(compgen -W "${types}" -- ${cur}) )
                    return 0
                    ;;
                4)
                    # Command - no completion, let user type
                    return 0
                    ;;
                5)
                    # Tags completion
                    if command -v jq >/dev/null 2>&1; then
                        local tags=$(jq -r '.bookmarks[].tags' "$BOOKMARKS_DIR/bookmarks.json" 2>/dev/null | \
                                   tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ')
                        COMPREPLY=( $(compgen -W "${tags}" -- ${cur}) )
                    fi
                    return 0
                    ;;
                6)
                    # Notes - no completion, let user type
                    return 0
                    ;;
            esac
            ;;
        tag)
            if [[ ${COMP_CWORD} -eq 2 ]]; then
                # Complete with existing tags
                if command -v jq >/dev/null 2>&1; then
                    local tags=$(jq -r '.bookmarks[].tags' "$BOOKMARKS_DIR/bookmarks.json" 2>/dev/null | \
                               tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ')
                    COMPREPLY=( $(compgen -W "${tags}" -- ${cur}) )
                fi
            fi
            return 0
            ;;
        *)
            # For search terms or default behavior, complete with bookmark descriptions
            if command -v jq >/dev/null 2>&1; then
                local IFS=$'\n'
                local desc_array=($(jq -r '.bookmarks[].description' "$BOOKMARKS_DIR/bookmarks.json" 2>/dev/null))
                COMPREPLY=( $(compgen -W "$(printf '%s\n' "${desc_array[@]}")" -- ${cur}) )
            fi
            return 0
            ;;
    esac
    
    return 0
}

# Register completion for both 'bookmark' and 'bookmarks.sh'
complete -F _bookmark_completion bookmark
complete -F _bookmark_completion bookmarks.sh
