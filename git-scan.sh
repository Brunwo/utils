#!/bin/bash

# Default values
BASE_DIR="."
REMOTE_ONLY=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --remote-only)
            REMOTE_ONLY=1
            shift
            ;;
        --base-dir)
            BASE_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

find "$BASE_DIR" -type d -name .git -not -path "*/.cache/*" 2>/dev/null | while read gitdir; do
    repo_dir=$(dirname "$gitdir")
    remote_url=$(git -C "$repo_dir" config --get remote.origin.url 2>/dev/null)

    # Filter out repos without remote if needed
    if [[ $REMOTE_ONLY -eq 1 && -z "$remote_url" ]]; then
        continue
    fi

    last_commit_date=$(git -C "$repo_dir" log -1 --format="%cd" --date=iso 2>/dev/null)
    last_commit_author=$(git -C "$repo_dir" log -1 --format="%an" 2>/dev/null)

    # Determine push status
    push_status="No remote"
    if [[ -n "$remote_url" ]]; then
        branch=$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
        upstream=$(git -C "$repo_dir" rev-parse --abbrev-ref "$branch@{upstream}" 2>/dev/null)
        if [[ -n "$upstream" ]]; then
            ahead=$(git -C "$repo_dir" rev-list --left-right --count "$upstream...$branch" 2>/dev/null | awk '{print $2}')
            if [[ "$ahead" == "0" ]]; then
                push_status="Pushed"
            else
                push_status="Not pushed"
            fi
        else
            push_status="No upstream"
        fi
    fi

    echo "Repository: $repo_dir"
    echo "Remote URL: ${remote_url:-Not configured}"
    echo "Last commit: ${last_commit_date:-No commits} by ${last_commit_author:-Unknown}"
    echo "Push status: $push_status"
    echo
done
