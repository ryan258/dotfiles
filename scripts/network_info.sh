#!/bin/bash
# network_info.sh - Network diagnostics for macOS

case "$1" in
    status)
        echo "=== Network Status ==="
        echo ""
        echo "--- Wi-Fi Information ---"
        networksetup -getairportnetwork en0
        
        echo ""
        echo "--- IP Addresses ---"
        echo "External IP: $(curl -s ifconfig.me)"
        echo "Local IP: $(ifconfig en0 | grep "inet " | awk '{print $2}')"
        
        echo ""
        echo "--- DNS Servers ---"
        scutil --dns | grep "nameserver" | head -3
        ;;
    
    scan)
        echo "=== Available Wi-Fi Networks ==="
        networksetup -listpreferredwirelessnetworks en0
        echo ""
        echo "--- Scanning for all networks ---"
        /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -s
        ;;
    
    speed)
        echo "=== Testing Network Speed ==="
        echo "Download speed test (using curl):"
        echo "Testing connection to fast.com..."
        
        # Simple speed test using curl
        START_TIME=$(date +%s)
        curl -o /dev/null -s "http://speedtest.tele2.net/10MB.zip"
        END_TIME=$(date +%s)
        
        DURATION=$((END_TIME - START_TIME))
        if [ $DURATION -gt 0 ]; then
            SPEED=$((10 / DURATION))
            echo "Approximate download speed: ${SPEED} MB/s"
        else
            echo "Test completed too quickly to measure accurately"
        fi
        ;;
    
    fix)
        echo "=== Network Troubleshooting ==="
        echo "Flushing DNS cache..."
        sudo dscacheutil -flushcache
        
        echo "Restarting Wi-Fi..."
        networksetup -setairportpower en0 off
        sleep 2
        networksetup -setairportpower en0 on
        
        echo "Network reset complete. Try your connection now."
        ;;
    
    *)
        echo "Usage: $0 {status|scan|speed|fix}"
        echo "  status : Show current network information"
        echo "  scan   : Scan for available Wi-Fi networks"
        echo "  speed  : Test network speed"
        echo "  fix    : Reset network settings"
        ;;
esac