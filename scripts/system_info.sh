#!/bin/bash
# system_info.sh - Quick system overview for macOS
set -euo pipefail

echo "=== macOS System Information ==="
echo ""

echo "--- Hardware ---"
echo "Model: $(system_profiler SPHardwareDataType | grep "Model Name" | cut -d: -f2 | xargs)"
echo "Chip: $(system_profiler SPHardwareDataType | grep "Chip" | cut -d: -f2 | xargs)"
echo "Memory: $(system_profiler SPHardwareDataType | grep "Memory" | cut -d: -f2 | xargs)"

echo ""
echo "--- CPU Usage ---"
top -l 1 | head -n 10 | tail -n 5

echo ""
echo "--- Memory Usage ---"
vm_stat | head -n 5

echo ""
echo "--- Disk Usage ---"
df -h / | tail -n 1

echo ""
echo "--- Network ---"
echo "External IP: $(curl -s ifconfig.me)"
echo "Wi-Fi Status: $(ifconfig en0 | grep "status" | cut -d: -f2 | xargs)"

# ---