#!/bin/bash
# done.sh - Run commands with completion notifications (macOS version)

if [ $# -eq 0 ]; then
    echo "Usage: $0 <your_command_here>"
    echo "Examples:"
    echo "  $0 sleep 10"
    echo "  $0 rsync -avh /source /dest"
    exit 1
fi

escape_applescript() {
    local input="$1"
    input=${input//\\/\\\\}
    input=${input//"/\\"}
    input=${input//$'\n'/\\n}
    printf '%s' "$input"
}

command_display="$*"
printf "Running command: '%s' ...\n" "$command_display"
echo "You will be notified upon completion."

if "$@"; then
    escaped=$(escape_applescript "$command_display")
    osascript -e "display notification \"Your command '$escaped' completed successfully.\" with title \"Task Finished\""
else
    status=$?
    escaped=$(escape_applescript "$command_display")
    osascript -e "display notification \"Your command '$escaped' finished with exit code $status.\" with title \"Task Failed\""
fi

# ---
