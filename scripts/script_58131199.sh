#!/bin/bash
# macOS version using osascript for notifications

MINUTES=${1:-15}

echo "Starting a $MINUTES minute break..."
sleep $((MINUTES * 60))

# macOS notification
osascript -e "display notification \"Break time is over! Welcome back.\" with title \"Health Break\""
echo "Break complete!"

