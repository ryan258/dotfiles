#!/usr/bin/env bash
set -euo pipefail
MEMO_FILE="${MEMO_FILE:-$HOME/Documents/memos.txt}"
mkdir -p "$(dirname "$MEMO_FILE")"
cmd="${1:-add}"
case "$cmd" in
  add) shift; [ $# -gt 0 ] || { echo "Usage: memo add <text>"; exit 1; }
       printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$MEMO_FILE"
       echo "Saved to $MEMO_FILE";;
  list) [ -f "$MEMO_FILE" ] && cat "$MEMO_FILE" || echo "No memos yet.";;
  today) [ -f "$MEMO_FILE" ] && grep -E "^$(date '+%Y-%m-%d')" "$MEMO_FILE" || echo "No memos today.";;
  clear) : > "$MEMO_FILE"; echo "Cleared $MEMO_FILE";;
  *) printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$MEMO_FILE"; echo "Saved to $MEMO_FILE";;
esac