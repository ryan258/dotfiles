#!/bin/bash
set -euo pipefail
# health.sh - Track health appointments, symptoms, and energy levels

HEALTH_FILE="$HOME/.config/dotfiles-data/health.txt"

case "$1" in
    add)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: health add \"description\" \"YYYY-MM-DD HH:MM\""
            echo "Example: health add \"Neurologist follow-up\" \"2025-11-15 14:00\""
            exit 1
        fi
        echo "APPT|$3|$2" >> "$HEALTH_FILE"
        echo "Added: $2 on $3"
        ;;

    symptom)
        shift
        symptom_note="$*"
        if [ -z "$symptom_note" ]; then
            echo "Usage: health symptom \"symptom description\""
            echo "Example: health symptom \"Heavy brain fog, fatigue\""
            exit 1
        fi
        timestamp=$(date '+%Y-%m-%d %H:%M')
        echo "SYMPTOM|$timestamp|$symptom_note" >> "$HEALTH_FILE"
        echo "Logged symptom: $symptom_note"
        ;;

    energy)
        if [ -z "$2" ]; then
            echo "Usage: health energy <1-10>"
            echo "Example: health energy 6"
            echo "  1-3: Low energy, struggling"
            echo "  4-6: Medium energy, functional"
            echo "  7-10: Good energy, productive"
            exit 1
        fi
        rating="$2"
        if ! [[ "$rating" =~ ^[1-9]$|^10$ ]]; then
            echo "Error: Energy rating must be 1-10"
            exit 1
        fi
        timestamp=$(date '+%Y-%m-%d %H:%M')
        echo "ENERGY|$timestamp|$rating" >> "$HEALTH_FILE"
        echo "Logged energy level: $rating/10"
        ;;

    list)
        if [ ! -f "$HEALTH_FILE" ] || [ ! -s "$HEALTH_FILE" ]; then
            echo "No health data tracked."
            exit 0
        fi

        echo "🏥 UPCOMING HEALTH APPOINTMENTS:"
        appt_found=false
        if grep -q "^APPT|" "$HEALTH_FILE" 2>/dev/null; then
            grep "^APPT|" "$HEALTH_FILE" | sort -t'|' -k2 | while IFS='|' read -r type appt_date desc; do
                days_until=$(( ( $(date -j -f "%Y-%m-%d %H:%M" "$appt_date" +%s 2>/dev/null || echo 0) - $(date +%s) ) / 86400 ))
                if [ "$days_until" -ge 0 ]; then
                    echo "  • $desc - $appt_date (in $days_until days)"
                    appt_found=true
                fi
            done
        fi
        if [ "$appt_found" = "false" ]; then
            echo "  (No appointments tracked)"
        fi

        echo ""
        echo "📊 RECENT ENERGY LEVELS (last 7 days):"
        cutoff=$(date -v-7d '+%Y-%m-%d')
        if grep -q "^ENERGY|" "$HEALTH_FILE" 2>/dev/null; then
            grep "^ENERGY|" "$HEALTH_FILE" | awk -F'|' -v cutoff="$cutoff" '
                $2 >= cutoff {
                    date_part = substr($2, 1, 10)
                    time_part = substr($2, 12)
                    printf "  • %s at %s: %s/10\n", date_part, time_part, $3
                }
            ' | tail -5
        else
            echo "  (No energy data logged)"
        fi

        echo ""
        echo "💊 RECENT SYMPTOMS (last 7 days):"
        if grep -q "^SYMPTOM|" "$HEALTH_FILE" 2>/dev/null; then
            grep "^SYMPTOM|" "$HEALTH_FILE" | awk -F'|' -v cutoff="$cutoff" '
                $2 >= cutoff {
                    date_part = substr($2, 1, 10)
                    time_part = substr($2, 12)
                    printf "  • [%s %s] %s\n", date_part, time_part, $3
                }
            ' | tail -5
        else
            echo "  (No symptoms logged)"
        fi
        ;;

    summary)
        if [ ! -f "$HEALTH_FILE" ] || [ ! -s "$HEALTH_FILE" ]; then
            echo "No health data tracked."
            exit 0
        fi

        # Quick summary for dashboard use
        today=$(date '+%Y-%m-%d')

        # Today's energy
        today_energy=$(grep "^ENERGY|$today" "$HEALTH_FILE" 2>/dev/null | tail -1 | cut -d'|' -f3)
        if [ -n "$today_energy" ]; then
            echo "Energy: $today_energy/10"
        fi

        # Today's symptoms
        symptom_count=$(grep -c "^SYMPTOM|$today" "$HEALTH_FILE" 2>/dev/null || echo "0")
        if [ "$symptom_count" -gt 0 ]; then
            echo "Symptoms logged today: $symptom_count"
        fi
        ;;

    remove)
        if [ -z "$2" ]; then
            echo "Usage: health remove <line_number>"
            grep -n "^APPT|" "$HEALTH_FILE" 2>/dev/null | sed 's/^/  /' || echo "No appointments to remove"
            exit 1
        fi
        # Only allow removing appointments, not symptoms/energy (they're historical data)
        sed -i.bak "${2}d" "$HEALTH_FILE"
        echo "Removed line #$2"
        ;;

    *)
        echo "Usage: health [add|symptom|energy|list|summary|remove]"
        echo ""
        echo "Appointments:"
        echo "  health add \"description\" \"YYYY-MM-DD HH:MM\""
        echo "  health list"
        echo "  health remove <number>"
        echo ""
        echo "Daily Tracking:"
        echo "  health symptom \"symptom description\""
        echo "  health energy <1-10>"
        echo "  health summary"
        ;;
esac