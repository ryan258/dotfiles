#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
ENV_FILE="$DOTFILES_DIR/.env"
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

LOG_ENABLED="${SWIPE_LOG_ENABLED:-false}"
LOG_FILE="${SWIPE_LOG_FILE:-$HOME/Documents/swipe.md}"

if [ $# -eq 0 ]; then
  echo "Usage: swipe <command> [args...]" >&2
  exit 1
fi

CMD="$1"
shift

# Map dispatcher aliases to full script names
# This allows: swipe tech "..." instead of swipe dhp-tech.sh "..."
case "$CMD" in
  tech)      CMD="dhp-tech.sh" ;;
  creative)  CMD="dhp-creative.sh" ;;
  content)   CMD="dhp-content.sh" ;;
  strategy)  CMD="dhp-strategy.sh" ;;
  brand)     CMD="dhp-brand.sh" ;;
  market)    CMD="dhp-market.sh" ;;
  stoic)     CMD="dhp-stoic.sh" ;;
  research)  CMD="dhp-research.sh" ;;
  narrative) CMD="dhp-narrative.sh" ;;
  copy)      CMD="dhp-copy.sh" ;;
esac

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

# Capture output while preserving exit code
if "$RESOLVED_CMD" "$@" 2>&1 | tee -a "$LOG_FILE"; then
  CMD_STATUS=0
else
  CMD_STATUS=${PIPESTATUS[0]}
fi
echo '```' >> "$LOG_FILE"

exit "$CMD_STATUS"
