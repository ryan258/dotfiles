#!/bin/bash
# macOS version with osascript notifications

if [ $# -eq 0 ]; then
    echo "Usage: $0 <your_command_here>"
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

if "$@"; then
    escaped=$(escape_applescript "$command_display")
    osascript -e "display notification \"Your command '$escaped' completed successfully.\" with title \"✅ Task Finished\""
else
    status=$?
    escaped=$(escape_applescript "$command_display")
    osascript -e "display notification \"Your command '$escaped' finished with exit code $status.\" with title \"❌ Task Failed\""
fi
