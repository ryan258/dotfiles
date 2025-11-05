#!/bin/bash
set -euo pipefail

# --- dump.sh: Brain dump - multi-paragraph capture via editor ---

JOURNAL_FILE="$HOME/.config/dotfiles-data/journal.txt"
TEMP_FILE=$(mktemp)

# Pre-populate with header
cat > "$TEMP_FILE" << HEADER
Brain Dump - $(date '+%A, %B %d, %Y at %H:%M')
================================================================

HEADER

# Open editor
${EDITOR:-nano} "$TEMP_FILE"

# Check if user wrote anything beyond the header
content_lines=$(tail -n +4 "$TEMP_FILE" | grep -v '^$' | wc -l | tr -d ' ')

if [ "$content_lines" -gt 0 ]; then
    # Append entire dump to journal with timestamp
    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] BRAIN DUMP:"
        tail -n +4 "$TEMP_FILE"
        echo ""
    } >> "$JOURNAL_FILE"
    echo "✅ Brain dump captured to journal ($content_lines lines)"
else
    echo "⚠️  No content written, nothing saved"
fi

rm -f "$TEMP_FILE"
