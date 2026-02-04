#!/usr/bin/env bash
# remind_me.sh - Simple reminder system using macOS notifications
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/common.sh"
fi

if [ $# -lt 2 ]; then
    echo "Usage: $0 <time> <reminder_message>"
    echo "Examples:"
    echo "  $0 '2:30 PM' 'Call the dentist'"
    echo "  $0 '+30m' 'Take a break'"
    echo "  $0 'tomorrow 9am' 'Review project proposal'"
    exit 1
fi

TIME=$(sanitize_input "$1")
TIME=${TIME//$'\n'/ }
shift
MESSAGE=$(sanitize_input "$*")
MESSAGE=${MESSAGE//$'\n'/ }

# Escape notification strings for AppleScript
escape_applescript() {
    local input="$1"
    input=${input//\\/\\\\}
    input=${input//"/\\"}
    input=${input//$'\n'/\\n}
    printf '%s' "$input"
}

notify_after_delay() {
    local delay="$1"
    local message="$2"
    local escaped_message
    escaped_message=$(escape_applescript "$message")
    (sleep "$delay" && osascript -e "display notification \"$escaped_message\" with title \"Reminder\"") &
}

# Parse simple time formats
case "$TIME" in
    +*m)
        MINUTES=${TIME#+}
        MINUTES=${MINUTES%m}
        if ! [[ "$MINUTES" =~ ^[0-9]+$ ]]; then
            echo "Unable to parse minutes from '$TIME'"
            exit 1
        fi
        DELAY=$((MINUTES * 60))
        echo "Reminder set for $MINUTES minutes from now: '$MESSAGE'"
        notify_after_delay "$DELAY" "$MESSAGE"
        ;;

    +*h)
        HOURS=${TIME#+}
        HOURS=${HOURS%h}
        if ! [[ "$HOURS" =~ ^[0-9]+$ ]]; then
            echo "Unable to parse hours from '$TIME'"
            exit 1
        fi
        DELAY=$((HOURS * 3600))
        echo "Reminder set for $HOURS hours from now: '$MESSAGE'"
        notify_after_delay "$DELAY" "$MESSAGE"
        ;;

    *)
        echo "Simple time format not recognized."
        echo "Supported formats: +30m (30 minutes), +2h (2 hours)"
        echo "For complex times, use Calendar app or other scheduling tools."
        exit 1
        ;;
esac

# ---
