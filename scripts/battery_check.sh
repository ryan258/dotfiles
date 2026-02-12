#!/usr/bin/env bash
# battery_check.sh - macOS battery monitoring with suggestions
set -euo pipefail

# Check if this is a laptop with a battery
if ! system_profiler SPPowerDataType >/dev/null 2>&1; then
    echo "No battery information available (desktop Mac?)"
    exit 1
fi

echo "=== Battery Status ==="

# Get battery info using pmset
BATTERY_INFO=$(pmset -g batt)
echo "$BATTERY_INFO"

# Extract percentage if possible
PERCENTAGE=$(echo "$BATTERY_INFO" | grep -o '[0-9]*%' | head -1 | tr -d '%')

if [ -n "$PERCENTAGE" ]; then
    echo ""
    if [ "$PERCENTAGE" -lt 20 ]; then
        echo "⚠️  Low battery! Consider:"
        echo "- Reducing screen brightness (F1)"
        echo "- Closing unnecessary applications"
        echo "- Enabling Low Power Mode in Battery preferences"
        echo "- Plugging in your charger"
    elif [ "$PERCENTAGE" -lt 50 ]; then
        echo "💡 Moderate battery. You might want to:"
        echo "- Save your work periodically (Cmd+S)"
        echo "- Consider plugging in soon"
        echo "- Close background apps you're not using"
    else
        echo "✅ Battery level looks good!"
    fi
fi

# ---