#!/usr/bin/env bash
set -euo pipefail

# swipe.sh - Run a dispatcher and optionally log the output.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
SHARED_LIB="$DOTFILES_DIR/bin/dhp-shared.sh"
CONFIG_LIB="$DOTFILES_DIR/scripts/lib/config.sh"
if [ -f "$CONFIG_LIB" ]; then
  # shellcheck disable=SC1090
  source "$CONFIG_LIB"
else
  echo "Error: configuration library not found at $CONFIG_LIB" >&2
  exit 1
fi
if [ -f "$SHARED_LIB" ]; then
  # shellcheck disable=SC1090
  source "$SHARED_LIB"
else
  echo "Error: shared dispatcher library not found at $SHARED_LIB" >&2
  exit 1
fi

LOG_ENABLED="${SWIPE_LOG_ENABLED:-false}"
LOG_FILE="${SWIPE_LOG_FILE:-$HOME/Documents/swipe.md}"

if [ $# -eq 0 ]; then
  echo "Usage: swipe <command> [args...]" >&2
  exit 1
fi

CMD="${1:-}"
shift

RESOLVED_CMD="$(dhp_resolve_dispatcher_command "$CMD" "$DOTFILES_DIR" 2>/dev/null || true)"

if [ -z "$RESOLVED_CMD" ]; then
  echo "swipe: command not found: $CMD" >&2
  exit 127
fi

if [ "$LOG_ENABLED" != "true" ]; then
  exec "$RESOLVED_CMD" "$@"
fi

mkdir -p "$(dirname "$LOG_FILE")"

# Rotate log if it exceeds 1MB
MAX_LOG_BYTES="${SWIPE_MAX_LOG_BYTES:-1048576}"
if [ -f "$LOG_FILE" ]; then
  LOG_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
  if [ "$LOG_SIZE" -gt "$MAX_LOG_BYTES" ]; then
    mv "$LOG_FILE" "${LOG_FILE%.md}.$(date +%Y%m%d%H%M%S).md"
  fi
fi

DISPLAY_CMD="$CMD"
if [ $# -gt 0 ]; then
  DISPLAY_CMD="$DISPLAY_CMD $*"
fi

{
  echo ""
  echo "### $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
  echo "**Command:** $DISPLAY_CMD"
  echo ""
  echo '```'
} >> "$LOG_FILE"

# Capture output while preserving exit code.
# Disable pipefail locally so set -e does not abort before we read PIPESTATUS.
set +o pipefail
"$RESOLVED_CMD" "$@" 2>&1 | tee -a "$LOG_FILE"
CMD_STATUS=${PIPESTATUS[0]}
set -o pipefail
echo '```' >> "$LOG_FILE"

exit "$CMD_STATUS"
