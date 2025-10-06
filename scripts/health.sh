#!/bin/bash
# health.sh - Track health appointments and events

HEALTH_FILE="$HOME/.health_appointments.txt"

case "$1" in
    add)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: health add \"description\" \"YYYY-MM-DD HH:MM\""
            echo "Example: health add \"Neurologist follow-up\" \"2025-11-15 14:00\""
            exit 1
        fi
        echo "$3|$2" >> "$HEALTH_FILE"
        echo "Added: $2 on $3"
        ;;
    
    list)
        if [ ! -f "$HEALTH_FILE" ] || [ ! -s "$HEALTH_FILE" ]; then
            echo "No appointments tracked."
            exit 0
        fi
        
        echo "🏥 UPCOMING HEALTH APPOINTMENTS:"
        sort "$HEALTH_FILE" | while IFS='|' read -r appt_date desc; do
            days_until=$(( ( $(date -j -f "%Y-%m-%d %H:%M" "$appt_date" +%s 2>/dev/null || echo 0) - $(date +%s) ) / 86400 ))
            if [ "$days_until" -ge 0 ]; then
                echo "  • $desc - $appt_date (in $days_until days)"
            fi
        done
        ;;
    
    remove)
        if [ -z "$2" ]; then
            echo "Usage: health remove <line_number>"
            health list
            exit 1
        fi
        sed -i.bak "${2}d" "$HEALTH_FILE"
        echo "Removed appointment #$2"
        ;;
    
    *)
        echo "Usage: health [add|list|remove]"
        echo ""
        echo "  health add \"description\" \"YYYY-MM-DD HH:MM\""
        echo "  health list"
        echo "  health remove <number>"
        ;;
esac