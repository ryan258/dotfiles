#!/bin/bash
# my_progress.sh - Shows your recent Git commits

# First, check if this is a git repository
if [ ! -d .git ]; then
  echo "This is not a Git repository. No progress to show."
  exit 1
fi

# Get your name from the Git config to filter by author
MY_NAME=$(git config user.name)

echo "--- Your Git Commits Since Yesterday ---"
git log --oneline --author="$MY_NAME" --since="yesterday"

echo ""
echo "--- All Recent Commits (Last 7) ---"
git log --oneline -n 7

# ---