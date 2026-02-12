#!/usr/bin/env bash
# duplicate_finder.sh - Find duplicate files on macOS
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/common.sh"
fi

SEARCH_DIR_RAW="${1:-.}"
SEARCH_DIR=$(validate_path "$SEARCH_DIR_RAW") || exit 1

echo "Searching for duplicate files in: $SEARCH_DIR"
echo "This may take a while for large directories..."

# Use md5 -r (hash filename) to find files with identical content
find "$SEARCH_DIR" -type f -print0 2>/dev/null | \
while IFS= read -r -d '' file; do
    md5 -r "$file"
done | \
sort | \
awk 'NR == 1 { prev_hash = "" }
{
    hash = $1
    sub(/^[^ ]+ /, "")
    file = $0
    if (hash == prev_hash) {
        if (!printed_group) {
            print "Duplicate group:"
            print "  " prev_file
            printed_group = 1
        }
        print "  " file
    } else {
        printed_group = 0
    }
    prev_hash = hash
    prev_file = file
}'

# ---
