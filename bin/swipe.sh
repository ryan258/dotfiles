#!/usr/bin/env bash
set -euo pipefail

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

# Resolve dispatcher aliases via shared mapping.
if mapped_cmd=$(dhp_dispatcher_script_name "$CMD" 2>/dev/null); then
  CMD="$mapped_cmd"
fi

RESOLVED_CMD=$(command -v "$CMD" 2>/dev/null || true)

if [ -z "$RESOLVED_CMD" ]; then
  if [ -x "$DOTFILES_DIR/bin/$CMD" ]; then
    RESOLVED_CMD="$DOTFILES_DIR/bin/$CMD"
  elif [ -x "$DOTFILES_DIR/bin/dhp-$CMD.sh" ]; then
    RESOLVED_CMD="$DOTFILES_DIR/bin/dhp-$CMD.sh"
  fi
fi

if [ -z "$RESOLVED_CMD" ]; then
  echo "swipe: command not found: $CMD" >&2
  exit 127
fi

if [ "$LOG_ENABLED" != "true" ]; then
  exec "$RESOLVED_CMD" "$@"
fi

mkdir -p "$(dirname "$LOG_FILE")"

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
