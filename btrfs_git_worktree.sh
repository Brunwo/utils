#!/bin/bash

# Script to create or remove a Git worktree using a Btrfs snapshot for CoW efficiency
# Usage: ./btrfs_git_worktree.sh create <repo_path> <worktree_name> <branch> [sparse_paths]
#        ./btrfs_git_worktree.sh remove <repo_path> <worktree_name>

#sample usage: 
# sudo btrfs subvolume create /btrfs/docker/git-worktrees
# ./btrfs_git_worktree.sh create /btrfs/docker/git-worktrees/my-repo my-worktree-feature feature

set -e

# Function to display usage
usage() {
    echo "Usage:"
    echo "  $0 create <repo_path> <worktree_name> <branch> [sparse_paths...]"
    echo "  $0 remove <repo_path> <worktree_name>"
    echo "Example:"
    echo "  $0 create /btrfs/repo/my-repo my-worktree-feature feature path/to/files"
    echo "  $0 remove /btrfs/repo/my-repo my-worktree-feature"
    exit 1
}

# Function to check if running on Btrfs
check_btrfs() {
    local path="$1"
    if ! df -T "$path" | grep -q "btrfs"; then
        echo "Error: $path is not on a Btrfs filesystem"
        exit 1
    fi
}

# Function to create a worktree with a Btrfs snapshot
create_worktree() {
    local repo_path="$1"
    local worktree_name="$2"
    local branch="$3"
    shift 3
    local sparse_paths=("$@")

    # Validate inputs
    if [ -z "$repo_path" ] || [ -z "$worktree_name" ] || [ -z "$branch" ]; then
        usage
    fi

    # Ensure repo_path exists and is a Git repository
    if [ ! -d "$repo_path/.git" ]; then
        echo "Error: $repo_path is not a Git repository"
        exit 1
    fi

    # Check if running on Btrfs
    check_btrfs "$repo_path"

    # Ensure the branch exists
    if ! git -C "$repo_path" rev-parse --verify "$branch" >/dev/null 2>&1; then
        echo "Error: Branch $branch does not exist in $repo_path"
        exit 1
    fi

    # Create Btrfs snapshot
    local worktree_path="$(dirname "$repo_path")/$worktree_name"
    if [ -d "$worktree_path" ]; then
        echo "Error: Worktree path $worktree_path already exists"
        exit 1
    fi
    btrfs subvolume snapshot "$repo_path" "$worktree_path"

    # Configure Git worktree metadata
    local worktree_git_dir="$repo_path/.git/worktrees/$worktree_name"
    mkdir -p "$worktree_git_dir"

    # Set up .git file in the worktree
    echo "gitdir: $worktree_git_dir" > "$worktree_path/.git"

    # Set up worktree metadata files
    git -C "$repo_path" rev-parse "$branch" > "$worktree_git_dir/HEAD"
    echo "$worktree_path/.git" > "$worktree_git_dir/gitdir"
    echo "../.." > "$worktree_git_dir/commondir"

    # Optionally set up sparse checkout
    if [ ${#sparse_paths[@]} -gt 0 ]; then
        cd "$worktree_path"
        git sparse-checkout init --cone
        git sparse-checkout set "${sparse_paths[@]}"
    fi

    echo "Worktree created at $worktree_path for branch $branch"
    echo "Disk usage:"
    btrfs filesystem du "$(dirname "$repo_path")" | grep -E "$repo_path|$worktree_name"
}

# Function to remove a worktree and its snapshot
remove_worktree() {
    local repo_path="$1"
    local worktree_name="$2"

    # Validate inputs
    if [ -z "$repo_path" ] || [ -z "$worktree_name" ]; then
        usage
    fi

    # Ensure repo_path exists and is a Git repository
    if [ ! -d "$repo_path/.git" ]; then
        echo "Error: $repo_path is not a Git repository"
        exit 1
    fi

    # Check if running on Btrfs
    check_btrfs "$repo_path"

    # Ensure worktree exists
    local worktree_path="$(dirname "$repo_path")/$worktree_name"
    if [ ! -d "$worktree_path" ]; then
        echo "Error: Worktree $worktree_path does not exist"
        exit 1
    fi

    # Remove the Btrfs snapshot
    btrfs subvolume delete "$worktree_path"

    # Remove worktree metadata
    rm -rf "$repo_path/.git/worktrees/$worktree_name"

    echo "Worktree $worktree_name removed"
}

# Main script logic
if [ $# -lt 2 ]; then
    usage
fi

action="$1"
shift

case "$action" in
    create)
        create_worktree "$@"
        ;;
    remove)
        remove_worktree "$@"
        ;;
    *)
        usage
        ;;
esac