#!/bin/bash

# Git Pull All Repositories
# This script recursively searches for Git repositories and executes 'git pull' on each one

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS] [DIRECTORY]"
    echo "Execute 'git pull' on all Git repositories found recursively"
    echo ""
    echo "Options:"
    echo "  -f, --force          Force pull even if there are local changes"
    echo "  -q, --quiet          Suppress output from git pull commands"
    echo "  -v, --verbose        Show detailed output for each repository"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Arguments:"
    echo "  DIRECTORY            Starting directory to search (default: current directory)"
    echo ""
    echo "Example:"
    echo "  $0 -v /path/to/search"
    echo "  $0 --force --quiet"
}

# Default values
SEARCH_DIR="."
FORCE_PULL=false
QUIET_MODE=false
VERBOSE_MODE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_PULL=true
            shift
            ;;
        -q|--quiet)
            QUIET_MODE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE_MODE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            SEARCH_DIR="$1"
            shift
            ;;
    esac
done

# Validate search directory
if [[ ! -d "$SEARCH_DIR" ]]; then
    echo "Error: Directory '$SEARCH_DIR' does not exist" >&2
    exit 1
fi

# Function to check if a directory is a Git repository
is_git_repo() {
    local dir="$1"
    [[ -d "$dir/.git" ]]
}

# Function to check if repository has uncommitted changes
has_uncommitted_changes() {
    local repo_dir="$1"
    cd "$repo_dir" || return 1
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        return 0  # Has uncommitted changes
    fi
    
    # Check for untracked files
    if [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
        return 0  # Has untracked files
    fi
    
    return 1  # No uncommitted changes
}

# Function to execute git pull on a repository
pull_repo() {
    local repo_path="$1"
    local repo_name
    repo_name=$(basename "$repo_path")
    
    cd "$repo_path" || return 1
    
    # Check if repository has a remote configured
    if ! git remote | grep -q .; then
        if [[ "$VERBOSE_MODE" == true ]]; then
            echo "  ⚠️  No remote configured for $repo_name"
        fi
        return 1
    fi
    
    # Check for uncommitted changes if not forcing
    if [[ "$FORCE_PULL" == false ]] && has_uncommitted_changes "$repo_path"; then
        if [[ "$VERBOSE_MODE" == true ]]; then
            echo "  ⚠️  Skipping $repo_name (has uncommitted changes)"
        fi
        return 1
    fi
    
    # Execute git pull
    if [[ "$VERBOSE_MODE" == true ]]; then
        echo "  🔄 Pulling $repo_name..."
    fi
    
    local pull_output
    if [[ "$QUIET_MODE" == true ]]; then
        pull_output=$(git pull 2>&1)
    else
        pull_output=$(git pull 2>&1)
        echo "$pull_output"
    fi
    
    local pull_exit_code=$?
    
    if [[ $pull_exit_code -eq 0 ]]; then
        if [[ "$VERBOSE_MODE" == true ]]; then
            echo "  ✅ Successfully pulled $repo_name"
        fi
        return 0
    else
        if [[ "$VERBOSE_MODE" == true ]]; then
            echo "  ❌ Failed to pull $repo_name"
            if [[ "$QUIET_MODE" == true ]]; then
                echo "    Error: $pull_output"
            fi
        fi
        return 1
    fi
}

# Function to find and pull all Git repositories
find_and_pull_repos() {
    local search_path="$1"
    local success_count=0
    local skip_count=0
    local error_count=0
    local total_count=0
    
    echo "Searching for Git repositories in: $search_path"
    echo "This may take a while for large directory trees..."
    echo ""
    
    # Find all .git directories and pull their parent repositories
    while IFS= read -r -d '' git_dir; do
        # Get the repository directory (parent of .git)
        local repo_dir
        repo_dir=$(dirname "$git_dir")
        local repo_name
        repo_name=$(basename "$repo_dir")
        
        ((total_count++))
        
        if [[ "$VERBOSE_MODE" == true ]]; then
            echo "[$total_count] Processing: $repo_dir"
        else
            echo "[$total_count] $repo_name"
        fi
        
        if pull_repo "$repo_dir"; then
            ((success_count++))
        else
            # Determine if it was skipped or failed
            cd "$repo_dir" 2>/dev/null || {
                ((error_count++))
                continue
            }
            
            if [[ "$FORCE_PULL" == false ]] && has_uncommitted_changes "$repo_dir"; then
                ((skip_count++))
            else
                ((error_count++))
            fi
        fi
        
    done < <(find "$search_path" -type d -name ".git" -print0 2>/dev/null)
    
    # Display summary
    echo ""
    echo "Summary:"
    echo "========="
    echo "Total repositories found: $total_count"
    echo "Successfully pulled: $success_count"
    echo "Skipped (uncommitted changes): $skip_count"
    echo "Errors: $error_count"
    
    if [[ $error_count -gt 0 ]]; then
        echo ""
        echo "Note: Use -f/--force to pull repositories with uncommitted changes"
        echo "Use -v/--verbose to see detailed information for each repository"
    fi
}

# Main execution
main() {
    echo "Git Pull All Repositories"
    echo "========================"
    echo "Search Directory: $SEARCH_DIR"
    echo "Force pull: $FORCE_PULL"
    echo "Quiet mode: $QUIET_MODE"
    echo "Verbose mode: $VERBOSE_MODE"
    echo ""
    
    # Convert to absolute path
    SEARCH_DIR=$(cd "$SEARCH_DIR" && pwd)
    
    # Generate the report
    find_and_pull_repos "$SEARCH_DIR"
}

# Run main function
main "$@"
