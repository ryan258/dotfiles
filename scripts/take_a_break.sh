#!/usr/bin/env bash
# take_a_break.sh - Health-focused break timer with macOS notifications
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/common.sh"
fi

if [ -f "$SCRIPT_DIR/lib/config.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/config.sh"
else
    echo "Error: configuration library not found at $SCRIPT_DIR/lib/config.sh" >&2
    exit 1
fi

BREAKS_LOG="${BREAKS_LOG:?BREAKS_LOG is not set by config.sh}"
mkdir -p "$DATA_DIR"

MINUTES_RAW=${1:-15}
MINUTES=$(sanitize_input "$MINUTES_RAW")
MINUTES=${MINUTES//$'\n'/ }

if ! [[ "$MINUTES" =~ ^[0-9]+$ ]]; then
    echo "Please enter a whole number of minutes."
    exit 1
fi

if [ "$MINUTES" -lt 1 ] || [ "$MINUTES" -gt 120 ]; then
    echo "Please specify a break time between 1 and 120 minutes."
    exit 1
fi

echo "Starting a $MINUTES minute break..."
echo "Break suggestions:"
echo "- Step away from the screen"
echo "- Do gentle neck rolls"
echo "- Stretch your hands and wrists"
echo "- Take deep breaths"
echo "- Walk around if possible"
echo ""
echo "Timer starting now..."

sleep $((MINUTES * 60))

echo ""
echo "========================================="
echo "  Break time is over! Welcome back."
echo "========================================="

# macOS notification
osascript -e "display notification \"Break time is over! Welcome back.\" with title \"Health Break Complete\""

# Optional: Log break completion
echo "[$(date)] Completed $MINUTES minute break" >> "$BREAKS_LOG"

# ---
