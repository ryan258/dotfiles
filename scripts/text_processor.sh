#!/bin/bash
# text_processor.sh - Text file processing utilities
set -euo pipefail

case "$1" in
    count)
        if [ -z "$2" ]; then
            echo "Usage: $0 count <file>"
            exit 1
        fi
        
        FILE="$2"
        if [ ! -f "$FILE" ]; then
            echo "File not found: $FILE"
            exit 1
        fi
        
        echo "=== Text Statistics for $FILE ==="
        echo "Lines: $(wc -l < "$FILE")"
        echo "Words: $(wc -w < "$FILE")"
        echo "Characters: $(wc -c < "$FILE")"
        echo "Characters (no spaces): $(tr -d ' \t\n' < "$FILE" | wc -c)"
        ;;
    
    search)
        if [ $# -lt 3 ]; then
            echo "Usage: $0 search <pattern> <file>"
            exit 1
        fi
        
        PATTERN="$2"
        FILE="$3"

        if [ ! -f "$FILE" ]; then
            echo "File not found: $FILE"
            exit 1
        fi
        
        echo "=== Searching for '$PATTERN' in $FILE ==="
        grep -n -i -F -- "$PATTERN" "$FILE" || echo "Pattern not found"
        ;;
    
    replace)
        if [ $# -lt 4 ]; then
            echo "Usage: $0 replace <old_text> <new_text> <file>"
            echo "Note: This creates a backup with .bak extension"
            exit 1
        fi
        
        OLD_TEXT="$2"
        NEW_TEXT="$3"
        FILE="$4"
        
        if [ ! -f "$FILE" ]; then
            echo "File not found: $FILE"
            exit 1
        fi
        
        # Create backup
        cp "$FILE" "${FILE}.bak"
        
        # Perform replacement safely via Python to handle special characters
        python3 <<'PY' "$FILE" "$OLD_TEXT" "$NEW_TEXT"
import sys
from pathlib import Path

file_path = Path(sys.argv[1]).expanduser()
old = sys.argv[2]
new = sys.argv[3]

try:
    text = file_path.read_text(encoding="utf-8")
except UnicodeDecodeError:
    text = file_path.read_text(encoding="utf-8", errors="surrogateescape")

text = text.replace(old, new)

file_path.write_text(text, encoding="utf-8")
PY
        
        echo "Replaced '$OLD_TEXT' with '$NEW_TEXT' in $FILE"
        echo "Backup saved as ${FILE}.bak"
        ;;
    
    clean)
        if [ -z "$2" ]; then
            echo "Usage: $0 clean <file>"
            exit 1
        fi
        
        FILE="$2"
        if [ ! -f "$FILE" ]; then
            echo "File not found: $FILE"
            exit 1
        fi
        
        # Create backup
        cp "$FILE" "${FILE}.bak"
        
        # Remove extra whitespace and empty lines
        sed -e 's/[[:space:]]*$//' -e '/^$/d' "$FILE" > "${FILE}.tmp"
        mv "${FILE}.tmp" "$FILE"
        
        echo "Cleaned up $FILE (removed trailing spaces and empty lines)"
        echo "Backup saved as ${FILE}.bak"
        ;;
    
    *)
        echo "Usage: $0 {count|search|replace|clean}"
        echo "  count <file>                    : Count lines, words, characters"
        echo "  search <pattern> <file>         : Search for text pattern"
        echo "  replace <old> <new> <file>      : Replace text (creates backup)"
        echo "  clean <file>                    : Remove extra whitespace"
        ;;
esac

# ---
