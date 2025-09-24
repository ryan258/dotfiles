#!/bin/bash
# open_file.sh - Find and open files with fuzzy matching (macOS optimized)

if [ -z "$1" ]; then
    echo "Usage: $0 <partial_filename>"
    echo "Example: $0 budget    (might find 'Q3_budget_report.xlsx')"
    exit 1
fi

SEARCH_TERM="$1"

echo "Searching for files containing '$SEARCH_TERM'..."

# Find files in common macOS locations, excluding system directories
MATCHES=$(find ~ -maxdepth 3 -type f -iname "*$SEARCH_TERM*" 2>/dev/null | \
    grep -v "/Library/" | \
    grep -v "/.Trash/" | \
    grep -v "/.cache/" | \
    head -10)

if [ -z "$MATCHES" ]; then
    echo "No files found containing '$SEARCH_TERM'"
    exit 1
fi

echo "Found files:"
echo "$MATCHES" | nl

echo ""
IFS= read -r -p "Enter number to open (or Enter to cancel): " choice

if [[ "$choice" =~ ^[0-9]+$ ]]; then
    FILE=$(echo "$MATCHES" | sed -n "${choice}p")
    if [ -f "$FILE" ]; then
        open "$FILE"  # macOS open command
        echo "Opening: $FILE"
    fi
fi

# ---
