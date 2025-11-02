#!/bin/bash
set -euo pipefail
# meds.sh - Medication tracking and reminder system

SYSTEM_LOG_FILE="$HOME/.config/dotfiles-data/system.log"
MEDS_FILE="$HOME/.config/dotfiles-data/medications.txt"

case "$1" in
    add)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: meds add \"medication name\" \"dosage schedule\""
            echo "Example: meds add \"Medication X\" \"morning,evening\""
            echo "Example: meds add \"Medication Y\" \"8:00,20:00\""
            exit 1
        fi
        med_name="$2"
        schedule="$3"
        echo "MED|$med_name|$schedule" >> "$MEDS_FILE"
        echo "Added medication: $med_name ($schedule)"
        ;;

    log)
        if [ -z "$2" ]; then
            echo "Usage: meds log \"medication name\""
            echo "Logs that you took the medication right now"
            exit 1
        fi
        med_name="$2"
        timestamp=$(date '+%Y-%m-%d %H:%M')
        echo "DOSE|$timestamp|$med_name" >> "$MEDS_FILE"
        echo "✅ Logged: $med_name at $timestamp"
        ;;

    list)
        if [ ! -f "$MEDS_FILE" ] || [ ! -s "$MEDS_FILE" ]; then
            echo "No medications tracked."
            exit 0
        fi

        echo "💊 CURRENT MEDICATIONS:"
        grep "^MED|" "$MEDS_FILE" 2>/dev/null | while IFS='|' read -r type med_name schedule; do
            echo "  • $med_name - Schedule: $schedule"
        done

        echo ""
        echo "📅 RECENT DOSES (last 7 days):"
        cutoff=$(date -v-7d '+%Y-%m-%d')
        grep "^DOSE|" "$MEDS_FILE" 2>/dev/null | awk -F'|' -v cutoff="$cutoff" '
            $2 >= cutoff {
                printf "  • %s: %s\n", $2, $3
            }
        ' | tail -20 || echo "  (No doses logged)"
        ;;

    check)
        if [ ! -f "$MEDS_FILE" ] || [ ! -s "$MEDS_FILE" ]; then
            echo "No medications to check."
            exit 0
        fi

        echo "💊 MEDICATION CHECK:"
        today=$(date '+%Y-%m-%d')
        current_hour=$(date '+%H')

        all_taken=true

        # Check each medication
        grep "^MED|" "$MEDS_FILE" 2>/dev/null | while IFS='|' read -r type med_name schedule; do
            # Parse schedule (could be "morning,evening" or "8:00,20:00")
            IFS=',' read -ra times <<< "$schedule"

            for time_slot in "${times[@]}"; do
                # Determine if we should have taken this dose yet today
                should_take=false

                case "$time_slot" in
                    morning)
                        if [ "$current_hour" -ge 6 ]; then should_take=true; fi
                        ;;
                    afternoon)
                        if [ "$current_hour" -ge 12 ]; then should_take=true; fi
                        ;;
                    evening)
                        if [ "$current_hour" -ge 18 ]; then should_take=true; fi
                        ;;
                    night)
                        if [ "$current_hour" -ge 21 ]; then should_take=true; fi
                        ;;
                    *:*)
                        # Specific time like "8:00"
                        dose_hour=$(echo "$time_slot" | cut -d: -f1)
                        if [ "$current_hour" -ge "$dose_hour" ]; then should_take=true; fi
                        ;;
                esac

                if [ "$should_take" = true ]; then
                    # Check if taken today
                    taken=$(grep "^DOSE|$today.*|$med_name" "$MEDS_FILE" 2>/dev/null | grep -c "$time_slot" || echo "0")

                    if [ "$taken" -eq 0 ]; then
                        echo "  ⚠️  $med_name ($time_slot) - NOT TAKEN YET"
                        all_taken=false
                    else
                        echo "  ✅ $med_name ($time_slot) - taken"
                    fi
                fi
            done
        done

        if [ "$all_taken" = true ]; then
            echo "  ✅ All scheduled medications taken for now"
        fi
        ;;

    history)
        if [ ! -f "$MEDS_FILE" ] || [ ! -s "$MEDS_FILE" ]; then
            echo "No medication history."
            exit 0
        fi

        med_name="${2:-}"
        days="${3:-7}"

        echo "📊 MEDICATION HISTORY:"
        if [ -n "$med_name" ]; then
            echo "Medication: $med_name (last $days days)"
        else
            echo "All medications (last $days days)"
        fi
        echo ""

        cutoff=$(date -v-${days}d '+%Y-%m-%d')

        if [ -n "$med_name" ]; then
            grep "^DOSE|" "$MEDS_FILE" 2>/dev/null | grep "$med_name" | awk -F'|' -v cutoff="$cutoff" '
                $2 >= cutoff {
                    printf "%s: %s\n", $2, $3
                }
            ' | sort || echo "No doses logged for $med_name"
        else
            grep "^DOSE|" "$MEDS_FILE" 2>/dev/null | awk -F'|' -v cutoff="$cutoff" '
                $2 >= cutoff {
                    printf "%s: %s\n", $2, $3
                }
            ' | sort || echo "No doses logged"
        fi
        ;;

    dashboard)
        echo "💊 MEDICATION ADHERENCE DASHBOARD (Last 30 Days) 💊"
        echo ""

        # --- Configuration ---
        DAYS_AGO=30
        CUTOFF_DATE=$(date -v-${DAYS_AGO}d '+%Y-%m-%d')
        MEDS_FILE="$HOME/.config/dotfiles-data/medications.txt"

        if [ ! -f "$MEDS_FILE" ]; then
            echo "Medications file not found."
            exit 1
        fi

        if [ ! -s "$MEDS_FILE" ]; then
            echo "Medications file is empty."
            exit 0
        fi

        # --- Calculations ---
        # Get all medications
        MEDS=$(grep "^MED|" "$MEDS_FILE" | cut -d'|' -f2)

        if [ -z "$MEDS" ]; then
            echo "No medications configured."
            exit 0
        fi

        for med in $MEDS; do
            # Get schedule for the med
            SCHEDULE=$(grep "^MED|$med|" "$MEDS_FILE" | cut -d'|' -f3)
            DOSES_PER_DAY=$(echo "$SCHEDULE" | tr ',' '\n' | wc -l | tr -d ' ')

            # Calculate expected doses
            EXPECTED_DOSES=$((DAYS_AGO * DOSES_PER_DAY))

            # Calculate actual doses
            ACTUAL_DOSES=$(grep "^DOSE|" "$MEDS_FILE" | awk -F'|' -v cutoff="$CUTOFF_DATE" -v med="$med" '$2 >= cutoff && $3 == med' | wc -l | tr -d ' ')

            # Calculate adherence
            if [ "$EXPECTED_DOSES" -gt 0 ]; then
                ADHERENCE=$((ACTUAL_DOSES * 100 / EXPECTED_DOSES))
                echo "• $med: ${ADHERENCE}% adherence ($ACTUAL_DOSES/$EXPECTED_DOSES doses)"
            else
                echo "• $med: N/A (no schedule found)"
            fi
        done
        ;;

    remove)
        if [ -z "$2" ]; then
            echo "Usage: meds remove \"medication name\""
            grep "^MED|" "$MEDS_FILE" 2>/dev/null | cut -d'|' -f2 | sed 's/^/  • /' || echo "No medications to remove"
            exit 1
        fi
        med_name="$2"
        grep -v "^MED|$med_name|" "$MEDS_FILE" > "${MEDS_FILE}.tmp" && mv "${MEDS_FILE}.tmp" "$MEDS_FILE"
        echo "Removed medication: $med_name"
        ;;

    remind)
        # This can be called from a cron job or manually
        if [ ! -f "$MEDS_FILE" ] || [ ! -s "$MEDS_FILE" ]; then
            exit 0
        fi

        today=$(date '+%Y-%m-%d')
        current_hour=$(date '+%H')

        # Check for any overdue medications
        overdue_found=false

        grep "^MED|" "$MEDS_FILE" 2>/dev/null | while IFS='|' read -r type med_name schedule; do
            IFS=',' read -ra times <<< "$schedule"

            for time_slot in "${times[@]}"; do
                should_take=false

                case "$time_slot" in
                    morning) if [ "$current_hour" -ge 6 ] && [ "$current_hour" -lt 12 ]; then should_take=true; fi ;;
                    afternoon) if [ "$current_hour" -ge 12 ] && [ "$current_hour" -lt 18 ]; then should_take=true; fi ;;
                    evening) if [ "$current_hour" -ge 18 ] && [ "$current_hour" -lt 22 ]; then should_take=true; fi ;;
                    night) if [ "$current_hour" -ge 21 ] || [ "$current_hour" -lt 6 ]; then should_take=true; fi ;;
                    *:*)
                        dose_hour=$(echo "$time_slot" | cut -d: -f1)
                        if [ "$current_hour" -eq "$dose_hour" ]; then should_take=true; fi
                        ;;
                esac

                if [ "$should_take" = true ]; then
                    taken=$(grep -c "^DOSE|$today.*|$med_name" "$MEDS_FILE" 2>/dev/null || echo "0")

                    if [ "$taken" -eq 0 ]; then
                        # Send notification
                        echo "$(date): meds.sh - Sending reminder for $med_name ($time_slot)." >> "$SYSTEM_LOG_FILE"
                        osascript -e "display notification \"Time to take: $med_name ($time_slot)\" with title \"💊 Medication Reminder\""
                        overdue_found=true
                    fi
                fi
            done
        done
        ;;

    *)
        echo "Error: Unknown command '$1'" >&2
        echo "Usage: meds [add|log|list|check|history|dashboard|remove|remind]"
        echo ""
        echo "Setup:"
        echo "  meds add \"medication name\" \"schedule\""
        echo "    Schedule examples: \"morning,evening\" or \"8:00,20:00\""
        echo ""
        echo "Daily Use:"
        echo "  meds check              # Check what needs to be taken"
        echo "  meds log \"med name\"     # Log that you took it"
        echo "  meds list               # Show all medications & recent doses"
        echo ""
        echo "History & Maintenance:"
        echo "  meds history [med] [days]   # Show dose history"
        echo "  meds dashboard          # Show 30-day adherence dashboard"
        echo "  meds remove \"med name\"     # Remove a medication"
        echo ""
        echo "Automation:"
        echo "  meds remind             # Check & send notifications (for cron)"
        exit 1
        ;;
esac
