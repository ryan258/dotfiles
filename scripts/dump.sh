#!/usr/bin/env bash
set -euo pipefail

# --- dump.sh: Brain dump - multi-paragraph capture via editor ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_lib "config.sh"

JOURNAL_FILE="$JOURNAL_FILE"
TEMP_FILE=$(mktemp)

encode_journal_content() {
    python3 - <<'PY'
import sys, codecs
data = sys.stdin.read()
encoded = codecs.encode(data, "unicode_escape").decode("ascii")
encoded = encoded.replace("|", r"\|")
sys.stdout.write(encoded)
PY
}

# Pre-populate with header
cat > "$TEMP_FILE" << HEADER
Brain Dump - $(date '+%A, %B %d, %Y at %H:%M')
================================================================

HEADER

# Open editor
${EDITOR:-nano} "$TEMP_FILE"

# Check if user wrote anything beyond the header
content_lines=$(tail -n +4 "$TEMP_FILE" | grep -vc '^$' | tr -d ' ')

if [ "$content_lines" -gt 0 ]; then
    # Append entire dump to journal with timestamp
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    {
        echo "BRAIN DUMP:"
        tail -n +4 "$TEMP_FILE"
        echo ""
    } | encode_journal_content | {
        read -r ENCODED
        echo "$TIMESTAMP|$ENCODED" >> "$JOURNAL_FILE"
    }
    echo "✅ Brain dump captured to journal ($content_lines lines)"
else
    echo "⚠️  No content written, nothing saved"
fi

rm -f "$TEMP_FILE"
