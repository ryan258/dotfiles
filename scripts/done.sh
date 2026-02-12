#!/usr/bin/env bash
# done.sh - Run commands with completion notifications
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: $0 <your_command_here>"
    echo "Examples:"
    echo "  $0 sleep 10"
    echo "  $0 rsync -avh /source /dest"
    exit 1
fi

notify_completion() {
    local title="$1"
    local body="$2"

    if [[ "$OSTYPE" == darwin* ]] && command -v osascript >/dev/null 2>&1; then
        local escaped_title
        local escaped_body
        escaped_title=$(escape_applescript "$title")
        escaped_body=$(escape_applescript "$body")
        osascript -e "display notification \"$escaped_body\" with title \"$escaped_title\""
        return 0
    fi

    # Cross-platform fallback: print a clear message and ring terminal bell.
    printf '\a'
    echo "[$title] $body"
}

escape_applescript() {
    local input="$1"
    input=${input//\\/\\\\}
    input=${input//\"/\\\"}
    input=${input//$'\n'/\\n}
    printf '%s' "$input"
}

command_display="$*"
printf "Running command: '%s' ...\n" "$command_display"
echo "You will be notified upon completion."

if "$@"; then
    notify_completion "Task Finished" "Your command '$command_display' completed successfully."
else
    status=$?
    notify_completion "Task Failed" "Your command '$command_display' finished with exit code $status."
fi

# ---
