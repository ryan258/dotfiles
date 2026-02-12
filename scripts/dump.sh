#!/usr/bin/env bash
set -euo pipefail

# --- dump.sh: Brain dump - multi-paragraph capture via editor ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_lib "config.sh"
require_lib "date_utils.sh"

JOURNAL_FILE="${JOURNAL_FILE:?JOURNAL_FILE is not set by config.sh}"
TEMP_FILE=$(create_temp_file "brain-dump")
cleanup_dump_temp_file() {
    if [ -n "${TEMP_FILE:-}" ] && [ -f "$TEMP_FILE" ]; then
        rm -f "$TEMP_FILE"
    fi
}
trap cleanup_dump_temp_file EXIT

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
Brain Dump - $(date_now '%A, %B %d, %Y at %H:%M')
================================================================

HEADER

# Open editor
${EDITOR:-nano} "$TEMP_FILE"

# Check if user wrote anything beyond the header
content_lines=$(tail -n +4 "$TEMP_FILE" | grep -vc '^$' | tr -d ' ' || true)

if [ "$content_lines" -gt 0 ]; then
    # Append entire dump to journal with timestamp
    TIMESTAMP=$(date_now)
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
TEMP_FILE=""
