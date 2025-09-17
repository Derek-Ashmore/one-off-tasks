#!/bin/bash

# Git Branch Report Generator
# This script recursively searches for Git repositories and generates a CSV report
# of unmerged remote branches with their status and last updater information

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS] [DIRECTORY]"
    echo "Generate a CSV report of unmerged remote branches across Git repositories"
    echo ""
    echo "Options:"
    echo "  -o, --output FILE    Output CSV file (default: git_branch_report.csv)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Arguments:"
    echo "  DIRECTORY           Starting directory to search (default: current directory)"
    echo ""
    echo "Example:"
    echo "  $0 -o report.csv /path/to/search"
}

# Default values
OUTPUT_FILE="git_branch_report.csv"
SEARCH_DIR="."

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
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

# Function to get the default branch name
get_default_branch() {
    local repo_dir="$1"
    cd "$repo_dir" || return 1
    
    # Try to get the default branch from origin
    local default_branch
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    
    if [[ -z "$default_branch" ]]; then
        # Fallback: try common default branch names
        for branch in main master develop; do
            if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
                default_branch="$branch"
                break
            fi
        done
    fi
    
    if [[ -z "$default_branch" ]]; then
        # Final fallback: use the first remote branch
        default_branch=$(git branch -r | head -1 | sed 's/.*origin\///' | tr -d ' ')
    fi
    
    echo "$default_branch"
}

# Function to analyze branches in a Git repository
analyze_repo() {
    local repo_path="$1"
    local repo_name
    repo_name=$(basename "$repo_path")
    
    cd "$repo_path" || return 1
    
    # Fetch latest remote information (skip if no remote configured or fetch fails)
    if git remote | grep -q .; then
        git fetch --all --quiet 2>/dev/null || {
            echo "Warning: Failed to fetch from remote in $repo_path (continuing with local data)" >&2
        }
    else
        echo "Warning: No remote configured for $repo_path (using local data only)" >&2
    fi
    
    # Get the default branch
    local default_branch
    default_branch=$(get_default_branch "$repo_path")
    
    if [[ -z "$default_branch" ]]; then
        echo "Warning: Could not determine default branch for $repo_path" >&2
        return 1
    fi
    
    # Get all remote branches except HEAD
    local remote_branches
    remote_branches=$(git branch -r | grep -v "origin/HEAD" | sed 's/.*origin\///' | tr -d ' ')
    
    for branch in $remote_branches; do
        # Skip the default branch as it's considered "merged" by definition
        if [[ "$branch" == "$default_branch" ]]; then
            continue
        fi
        
        # Check if branch exists on remote
        if ! git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
            continue
        fi
        
        # Get commits ahead and behind compared to default branch
        local ahead_behind
        ahead_behind=$(git rev-list --left-right --count "origin/$default_branch...origin/$branch" 2>/dev/null)
        
        if [[ -z "$ahead_behind" ]]; then
            continue
        fi
        
        local behind ahead
        behind=$(echo "$ahead_behind" | cut -f1)
        ahead=$(echo "$ahead_behind" | cut -f2)
        
        # Skip if branch is fully merged (0 commits ahead)
        if [[ "$ahead" -eq 0 ]]; then
            continue
        fi
        
        # Get the last committer information
        local last_commit_info
        last_commit_info=$(git log -1 --format="%an|%ae|%ad" --date=iso "origin/$branch" 2>/dev/null)
        
        if [[ -z "$last_commit_info" ]]; then
            continue
        fi
        
        local author_name author_email commit_date
        IFS='|' read -r author_name author_email commit_date <<< "$last_commit_info"
        
        # Output CSV row
        echo "\"$repo_name\",\"$repo_path\",\"$branch\",\"$ahead\",\"$behind\",\"$author_name\",\"$author_email\",\"$commit_date\""
    done
}

# Function to find and analyze all Git repositories
find_and_analyze_repos() {
    local search_path="$1"
    local temp_file
    temp_file=$(mktemp)
    
    echo "Searching for Git repositories in: $search_path"
    echo "This may take a while for large directory trees..."
    
    # Find all .git directories and analyze their parent repositories
    local repo_count=0
    while IFS= read -r -d '' git_dir; do
        # Get the repository directory (parent of .git)
        local repo_dir
        repo_dir=$(dirname "$git_dir")
        
        echo "Analyzing repository: $repo_dir"
        analyze_repo "$repo_dir" >> "$temp_file"
        ((repo_count++))
    done < <(find "$search_path" -type d -name ".git" -print0 2>/dev/null)
    
    echo "Found and analyzed $repo_count Git repositories"
    
    # Create final CSV with headers
    {
        echo "Repository,Path,Branch,Commits Ahead,Commits Behind,Last Author,Author Email,Last Commit Date"
        sort "$temp_file"
    } > "$OUTPUT_FILE"
    
    # Clean up
    rm -f "$temp_file"
}

# Main execution
main() {
    echo "Git Branch Report Generator"
    echo "=========================="
    echo "Search Directory: $SEARCH_DIR"
    echo "Output File: $OUTPUT_FILE"
    echo ""
    
    # Convert to absolute paths
    SEARCH_DIR=$(cd "$SEARCH_DIR" && pwd)
    
    # Convert output file to absolute path if it's not already
    if [[ "$OUTPUT_FILE" != /* ]]; then
        OUTPUT_FILE="$(pwd)/$OUTPUT_FILE"
    fi
    
    echo "Absolute output path: $OUTPUT_FILE"
    
    # Generate the report
    find_and_analyze_repos "$SEARCH_DIR"
    
    # Display results
    local line_count
    line_count=$(wc -l < "$OUTPUT_FILE")
    local branch_count=$((line_count - 1))  # Subtract header row
    
    echo ""
    if [[ -f "$OUTPUT_FILE" ]]; then
        echo "Report generated successfully!"
        echo "Output file: $OUTPUT_FILE"
        echo "File size: $(wc -c < "$OUTPUT_FILE") bytes"
        echo "Total unmerged branches found: $branch_count"
    else
        echo "Error: Output file was not created at $OUTPUT_FILE" >&2
        exit 1
    fi
    
    if [[ $branch_count -gt 0 ]]; then
        echo ""
        echo "Preview of results:"
        head -6 "$OUTPUT_FILE" | column -t -s','
        if [[ $branch_count -gt 5 ]]; then
            echo "... and $((branch_count - 5)) more branches"
        fi
    else
        echo ""
        echo "No unmerged remote branches found in the specified directory tree."
    fi
}

# Run main function
main "$@"
