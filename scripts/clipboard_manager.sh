#!/usr/bin/env bash
# clipboard_manager.sh - Enhanced clipboard management for macOS
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_lib "config.sh"
require_cmd "python3" "Install with: brew install python"

CLIP_FILE="$CLIPBOARD_FILE"
mkdir -p "$(dirname "$CLIP_FILE")"
touch "$CLIP_FILE"
chmod 600 "$CLIP_FILE"

encode_clipboard() {
    python3 - <<'PY'
import sys, codecs
data = sys.stdin.read()
encoded = codecs.encode(data, "unicode_escape").decode("ascii")
encoded = encoded.replace("|", r"\|")
sys.stdout.write(encoded)
PY
}

decode_clipboard() {
    python3 - <<'PY'
import sys, codecs
data = sys.stdin.read()
data = data.replace(r"\|", "|")
sys.stdout.write(codecs.decode(data, "unicode_escape"))
PY
}

MODE="${1:-}"

if [ -z "$MODE" ]; then
    echo "Usage:"
    echo "  clip save [name]  : Save current clipboard"
    echo "  clip load <name>  : Load clip to clipboard"
    echo "  clip list         : Show all saved clips"
    echo "  clip peek         : Show current clipboard content"
    exit 1
fi

case "$MODE" in
    save)
        NAME="${2:-clip_$(date +%H%M%S)}"
        if [[ "$NAME" == *"|"* ]]; then
            echo "Error: Clip name cannot contain '|'" >&2
            exit 1
        fi
        NAME=$(sanitize_input "$NAME")
        TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
        CONTENT_ENCODED=$(pbpaste | encode_clipboard)
        echo "$TIMESTAMP|$NAME|$CONTENT_ENCODED" >> "$CLIP_FILE"
        echo "Saved clipboard as '$NAME'"
        ;;
    
    load)
        if [ -z "${2:-}" ]; then
            echo "Available clips:"
            awk -F'|' 'NF>=2 {print $2}' "$CLIP_FILE" | sort -u || echo "No clips saved yet"
            exit 1
        fi
        NAME="$2"
        if [[ "$NAME" == *"|"* ]]; then
            echo "Error: Clip name cannot contain '|'" >&2
            exit 1
        fi
        python3 - "$NAME" "$CLIP_FILE" <<'PY' | pbcopy
import sys, codecs
name = sys.argv[1]
path = sys.argv[2]
chosen = None
with open(path, "r", encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        # Parse line into fields split on unescaped |
        parts = []
        buf = []
        escaped = False
        for ch in line:
            if escaped:
                buf.append(ch)
                escaped = False
                continue
            if ch == "\\":
                escaped = True
                buf.append(ch)
                continue
            if ch == "|":
                parts.append("".join(buf))
                buf = []
            else:
                buf.append(ch)
        parts.append("".join(buf))
        if len(parts) < 3:
            continue
        if parts[1] == name:
            chosen = parts[2]
if chosen is None:
    sys.exit(1)
chosen = chosen.replace(r"\|", "|")
sys.stdout.write(codecs.decode(chosen, "unicode_escape"))
PY
        if [ "${PIPESTATUS[0]}" -eq 0 ]; then
            echo "Loaded '$NAME' to clipboard"
        else
            echo "Clip '$NAME' not found"
        fi
        ;;
    
    list)
        echo "=== Saved Clips ==="
        if [ ! -s "$CLIP_FILE" ]; then
            echo "No clips saved yet"
            exit 0
        fi
        python3 - "$CLIP_FILE" <<'PY'
import sys, codecs
path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        parts = []
        buf = []
        escaped = False
        for ch in line:
            if escaped:
                buf.append(ch)
                escaped = False
                continue
            if ch == "\\":
                escaped = True
                buf.append(ch)
                continue
            if ch == "|":
                parts.append("".join(buf))
                buf = []
            else:
                buf.append(ch)
        parts.append("".join(buf))
        if len(parts) < 3:
            continue
        ts, name, content = parts[0], parts[1], parts[2]
        content = content.replace(r"\|", "|")
        content = codecs.decode(content, "unicode_escape")
        preview = content.replace("\n", " ")[:50]
        print(f"{ts} | {name}: {preview}...")
PY
        ;;
    
    peek)
        echo "=== Current Clipboard ==="
        pbpaste | head -c 200
        echo ""
        ;;
    
    *)
        echo "Usage:"
        echo "  clip save [n]  : Save current clipboard"
        echo "  clip load <n>  : Load clip to clipboard"
        echo "  clip list         : Show all saved clips"
        echo "  clip peek         : Show current clipboard content"
        ;;
esac

# ---
