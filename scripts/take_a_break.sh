#!/usr/bin/env bash
# take_a_break.sh - Health-focused break timer with macOS notifications
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/common.sh"
else
    echo "Error: common library not found at $SCRIPT_DIR/lib/common.sh" >&2
    exit 1
fi
if [[ -f "$SCRIPT_DIR/lib/config.sh" ]]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/config.sh"
else
    echo "Error: configuration library not found at $SCRIPT_DIR/lib/config.sh" >&2
    exit 1
fi

BREAKS_LOG="${BREAKS_LOG:?BREAKS_LOG is not set by config.sh}"
BREAK_TIMER_LOCK_DIR="${BREAK_TIMER_LOCK_DIR:-${TMPDIR:-/tmp}/take_a_break_lock}"
BREAK_TIMER_PID_FILE="$BREAK_TIMER_LOCK_DIR/pid"
BREAK_TIMER_MINUTES_FILE="$BREAK_TIMER_LOCK_DIR/minutes"
mkdir -p "$DATA_DIR"

show_usage() {
    cat <<'EOF'
Usage: take_a_break.sh [minutes]
       take_a_break.sh --status
       take_a_break.sh --stop

Defaults to 15 minutes when no duration is provided.
EOF
}

lock_owner_pid() {
    if [[ -f "$BREAK_TIMER_PID_FILE" ]]; then
        tr -cd '0-9' < "$BREAK_TIMER_PID_FILE"
    fi
}

is_pid_running() {
    local pid="$1"
    if [[ -z "$pid" ]]; then
        return 1
    fi
    kill -0 "$pid" 2>/dev/null
}

is_break_timer_process() {
    local pid="$1"
    if ! is_pid_running "$pid"; then
        return 1
    fi

    # Best effort verification so --stop does not kill unrelated processes.
    local cmdline
    cmdline=$(ps -p "$pid" -o command= 2>/dev/null || true)
    if [[ -z "$cmdline" ]]; then
        return 0
    fi
    [[ "$cmdline" == *"take_a_break.sh"* ]]
}

release_lock_if_owner() {
    if [[ ! -d "$BREAK_TIMER_LOCK_DIR" ]]; then
        return 0
    fi

    local owner_pid
    owner_pid="$(lock_owner_pid)"
    if [[ "$owner_pid" == "$$" ]]; then
        rm -rf "$BREAK_TIMER_LOCK_DIR"
    fi
}

acquire_lock() {
    local minutes="$1"

    if mkdir "$BREAK_TIMER_LOCK_DIR" 2>/dev/null; then
        printf '%s\n' "$$" > "$BREAK_TIMER_PID_FILE"
        printf '%s\n' "$minutes" > "$BREAK_TIMER_MINUTES_FILE"
        trap release_lock_if_owner EXIT INT TERM
        return 0
    fi

    local owner_pid
    owner_pid="$(lock_owner_pid)"
    if is_break_timer_process "$owner_pid"; then
        echo "A break timer is already running (PID $owner_pid)."
        echo "Use 'take_a_break.sh --status' or 'take_a_break.sh --stop'."
        return "$EXIT_ERROR"
    fi

    rm -rf "$BREAK_TIMER_LOCK_DIR"
    if mkdir "$BREAK_TIMER_LOCK_DIR" 2>/dev/null; then
        printf '%s\n' "$$" > "$BREAK_TIMER_PID_FILE"
        printf '%s\n' "$minutes" > "$BREAK_TIMER_MINUTES_FILE"
        trap release_lock_if_owner EXIT INT TERM
        return 0
    fi

    echo "Unable to acquire break timer lock."
    return "$EXIT_SERVICE_ERROR"
}

show_status() {
    if [[ ! -d "$BREAK_TIMER_LOCK_DIR" ]]; then
        echo "No active break timer."
        return 0
    fi

    local owner_pid
    owner_pid="$(lock_owner_pid)"
    local minutes="unknown"
    if [[ -f "$BREAK_TIMER_MINUTES_FILE" ]]; then
        minutes=$(tr -cd '0-9' < "$BREAK_TIMER_MINUTES_FILE")
    fi

    if is_break_timer_process "$owner_pid"; then
        echo "Active break timer: ${minutes} minute(s) (PID $owner_pid)."
        return 0
    fi

    echo "Break timer lock is stale."
    return "$EXIT_ERROR"
}

stop_timer() {
    if [[ ! -d "$BREAK_TIMER_LOCK_DIR" ]]; then
        echo "No active break timer."
        return 0
    fi

    local owner_pid
    owner_pid="$(lock_owner_pid)"
    if is_break_timer_process "$owner_pid"; then
        if kill "$owner_pid" 2>/dev/null; then
            echo "Stopped active break timer (PID $owner_pid)."
        else
            echo "Unable to stop break timer process $owner_pid."
            return "$EXIT_SERVICE_ERROR"
        fi
    else
        echo "Removed stale break timer lock."
    fi

    rm -rf "$BREAK_TIMER_LOCK_DIR"
    return 0
}

ACTION_RAW="${1:-}"

# Check for subcommands first to avoid stripping hyphens during sanitization
case "$ACTION_RAW" in
    -h|--help|help)
        show_usage
        exit 0
        ;;
    --status|status)
        show_status
        exit $?
        ;;
    --stop|stop|--cancel|cancel)
        stop_timer
        exit $?
        ;;
esac

MINUTES_RAW="${1:-15}"
MINUTES=$(sanitize_input "$MINUTES_RAW")
MINUTES=${MINUTES//$'\n'/ }

if ! [[ "$MINUTES" =~ ^[0-9]+$ ]]; then
    echo "Please enter a whole number of minutes."
    exit "$EXIT_INVALID_ARGS"
fi

if [[ "$MINUTES" -lt 1 || "$MINUTES" -gt 120 ]]; then
    echo "Please specify a break time between 1 and 120 minutes."
    exit "$EXIT_INVALID_ARGS"
fi

acquire_lock "$MINUTES"

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
if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"Break time is over! Welcome back.\" with title \"Health Break Complete\""
fi

# Optional: Log break completion
echo "[$(date)] Completed $MINUTES minute break (PID $$)" >> "$BREAKS_LOG"

