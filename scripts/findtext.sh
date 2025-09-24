#!/bin/bash
# findtext.sh - A user-friendly wrapper for grep to find text in files

IFS= read -r -p "What text are you searching for? " search_term

if [ -z "$search_term" ]; then
    echo "No search term provided. Exiting."
    exit 1
fi

echo "Searching for '$search_term' in all files in the current directory..."

# The flags mean:
# -r = recursive (search in all sub-folders)
# -l = list only the names of files that contain the text
# -i = case-insensitive (matches 'hello', 'Hello', 'HELLO', etc.)
grep -rli "$search_term" .

# ---
