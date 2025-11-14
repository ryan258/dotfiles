#!/bin/bash
set -euo pipefail
# health.sh - Track health appointments, symptoms, and energy levels

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATE_UTILS="$SCRIPT_DIR/lib/date_utils.sh"
if [ -f "$DATE_UTILS" ]; then
    # shellcheck disable=SC1090
    source "$DATE_UTILS"
else
    echo "Error: date utilities not found at $DATE_UTILS" >&2
    exit 1
fi

HEALTH_FILE="$HOME/.config/dotfiles-data/health.txt"
CACHE_DIR="$HOME/.config/dotfiles-data/cache"
mkdir -p "$CACHE_DIR"
COMMITS_CACHE_FILE="$CACHE_DIR/health_commits.cache"
COMMITS_CACHE_TTL="${HEALTH_COMMITS_CACHE_TTL:-3600}"
COMMITS_LOOKBACK_DAYS="${HEALTH_COMMITS_LOOKBACK_DAYS:-90}"

# --- Helper Functions ---
correlate_tasks() {
    local recent_data="$1"
    local todo_done_file="$HOME/.config/dotfiles-data/todo_done.txt"

    if [ ! -f "$todo_done_file" ]; then
        echo "  - Avg tasks on low energy days: N/A (no todo data)"
        echo "  - Avg tasks on high energy days: N/A (no todo data)"
        return
    fi

    # Build associative array of tasks per day
    declare -A tasks_by_day
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
            day="${BASH_REMATCH[1]}"
            tasks_by_day[$day]=$(( ${tasks_by_day[$day]:-0} + 1 ))
        fi
    done < "$todo_done_file"

    local low_energy_tasks=0
    local low_energy_days=0
    local high_energy_tasks=0
    local high_energy_days=0

    # Correlate energy levels with task completion
    while IFS='|' read -r type timestamp energy; do
        if [ "$type" = "ENERGY" ]; then
            day="${timestamp:0:10}"
            tasks=${tasks_by_day[$day]:-0}

            if [ "$energy" -le 4 ]; then
                low_energy_tasks=$((low_energy_tasks + tasks))
                low_energy_days=$((low_energy_days + 1))
            elif [ "$energy" -ge 7 ]; then
                high_energy_tasks=$((high_energy_tasks + tasks))
                high_energy_days=$((high_energy_days + 1))
            fi
        fi
    done < <(echo "$recent_data")

    local avg_low_energy_tasks="0.0"
    local avg_high_energy_tasks="0.0"

    if [ "$low_energy_days" -gt 0 ]; then
        avg_low_energy_tasks=$(awk "BEGIN {printf \"%.1f\", $low_energy_tasks / $low_energy_days}")
    fi

    if [ "$high_energy_days" -gt 0 ]; then
        avg_high_energy_tasks=$(awk "BEGIN {printf \"%.1f\", $high_energy_tasks / $high_energy_days}")
    fi

    echo "  - Avg tasks on low energy days (1-4): $avg_low_energy_tasks"
    echo "  - Avg tasks on high energy days (7-10): $avg_high_energy_tasks"
}

correlate_commits() {
    local recent_data="$1"
    local projects_dir="$HOME/Projects"

    if [ ! -d "$projects_dir" ]; then
        echo "  - Avg commits on low energy days: N/A (no Projects dir)"
        echo "  - Avg commits on high energy days: N/A (no Projects dir)"
        return
    fi

    # Build associative array of commits per day
    declare -A commits_by_day
    if ! load_commit_cache commits_by_day; then
        while IFS= read -r gitdir; do
            proj_dir=$(dirname "$gitdir")
            (cd "$proj_dir" && git log --all --since="${COMMITS_LOOKBACK_DAYS} days ago" --pretty=format:%cs 2>/dev/null || true) | while read -r day; do
                commits_by_day[$day]=$(( ${commits_by_day[$day]:-0} + 1 ))
            done
        done < <(find "$projects_dir" -maxdepth 2 -type d -name ".git" 2>/dev/null || true)
        save_commit_cache commits_by_day
    fi

    local low_energy_commits=0
    local low_energy_days=0
    local high_energy_commits=0
    local high_energy_days=0

    # Correlate energy levels with git commits
    while IFS='|' read -r type timestamp energy; do
        if [ "$type" = "ENERGY" ]; then
            day="${timestamp:0:10}"
            commits=${commits_by_day[$day]:-0}

            if [ "$energy" -le 4 ]; then
                low_energy_commits=$((low_energy_commits + commits))
                low_energy_days=$((low_energy_days + 1))
            elif [ "$energy" -ge 7 ]; then
                high_energy_commits=$((high_energy_commits + commits))
                high_energy_days=$((high_energy_days + 1))
            fi
        fi
    done < <(echo "$recent_data")

    local avg_low_energy_commits="0.0"
    local avg_high_energy_commits="0.0"

    if [ "$low_energy_days" -gt 0 ]; then
        avg_low_energy_commits=$(awk "BEGIN {printf \"%.1f\", $low_energy_commits / $low_energy_days}")
    fi

    if [ "$high_energy_days" -gt 0 ]; then
        avg_high_energy_commits=$(awk "BEGIN {printf \"%.1f\", $high_energy_commits / $high_energy_days}")
    fi

    echo "  - Avg commits on low energy days (1-4): $avg_low_energy_commits"
    echo "  - Avg commits on high energy days (7-10): $avg_high_energy_commits"
}

# --- Main Command Handler ---
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
            current_epoch=$(date +%s)
            grep "^APPT|" "$HEALTH_FILE" | sort -t'|' -k2 | while IFS='|' read -r type appt_date desc; do
                appt_epoch=$(timestamp_to_epoch "$appt_date")
                if [ "$appt_epoch" -le 0 ]; then
                    continue
                fi
                days_until=$(( ( appt_epoch - current_epoch ) / 86400 ))
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
        cutoff=$(date_shift_days -7 "%Y-%m-%d")
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

    export)
        if [ ! -f "$HEALTH_FILE" ] || [ ! -s "$HEALTH_FILE" ]; then
            echo "No health data to export."
            exit 0
        fi

        # Determine timeframe (default: last 7 days, or specify number of days)
        days=${2:-7}
        cutoff=$(date_shift_days "-${days}" "%Y-%m-%d")

        output_file="${HEALTH_EXPORT_FILE:-$HOME/health_export_$(date '+%Y%m%d').md}"

        cat > "$output_file" << EOF
# Health Summary Report

**Generated:** $(date '+%Y-%m-%d %H:%M')
**Period:** Last $days days (since $cutoff)

EOF

        # Export energy levels
        echo "## Energy Levels" >> "$output_file"
        echo "" >> "$output_file"

        if grep -q "^ENERGY|" "$HEALTH_FILE" 2>/dev/null; then
            grep "^ENERGY|" "$HEALTH_FILE" | awk -F'|' -v cutoff="$cutoff" '
                $2 >= cutoff {
                    printf "- **%s** at %s: %s/10\n", substr($2, 1, 10), substr($2, 12), $3
                }
            ' >> "$output_file"

            # Calculate average energy
            avg_energy=$(grep "^ENERGY|" "$HEALTH_FILE" | awk -F'|' -v cutoff="$cutoff" '
                $2 >= cutoff { sum += $3; count++ }
                END { if (count > 0) printf "%.1f", sum/count; else print "N/A" }
            ')
            echo "" >> "$output_file"
            echo "**Average energy:** $avg_energy/10" >> "$output_file"
        else
            echo "No energy data logged for this period." >> "$output_file"
        fi

        { echo ""; } >> "$output_file"

        # Export symptoms
        echo "## Symptoms" >> "$output_file"
        { echo ""; } >> "$output_file"

        if grep -q "^SYMPTOM|" "$HEALTH_FILE" 2>/dev/null; then
            grep "^SYMPTOM|" "$HEALTH_FILE" | awk -F'|' -v cutoff="$cutoff" '
                $2 >= cutoff {
                    printf "- **%s** at %s: %s\n", substr($2, 1, 10), substr($2, 12), $3
                }
            ' >> "$output_file"
        else
            echo "No symptoms logged for this period." >> "$output_file"
        fi

        { echo ""; } >> "$output_file"

        # Export upcoming appointments
        echo "## Upcoming Appointments" >> "$output_file"
        { echo ""; } >> "$output_file"

        if grep -q "^APPT|" "$HEALTH_FILE" 2>/dev/null; then
            current_epoch=$(date +%s)
            while IFS='|' read -r _ appt_date desc; do
                appt_epoch=$(timestamp_to_epoch "$appt_date")
                if [ "$appt_epoch" -le 0 ]; then
                    continue
                fi
                days_until=$(( ( appt_epoch - current_epoch ) / 86400 ))
                if [ "$days_until" -ge 0 ]; then
                    printf "- **%s**: %s (in %d days)\n" "$appt_date" "$desc" "$days_until" >> "$output_file"
                fi
            done < <(grep "^APPT|" "$HEALTH_FILE" | sort -t'|' -k2)
        else
            echo "No upcoming appointments." >> "$output_file"
        fi

        # Export medication data
        echo "" >> "$output_file"
        echo "## Current Medications" >> "$output_file"
        echo "" >> "$output_file"

        MEDS_FILE="$HOME/.config/dotfiles-data/medications.txt"
        if [ -f "$MEDS_FILE" ] && [ -s "$MEDS_FILE" ]; then
            # List current medications
            if grep -q "^MED|" "$MEDS_FILE" 2>/dev/null; then
                echo "### Medication List" >> "$output_file"
                echo "" >> "$output_file"
                grep "^MED|" "$MEDS_FILE" | while IFS='|' read -r type med_name schedule; do
                    echo "- **$med_name** - Schedule: $schedule" >> "$output_file"
                done
                echo "" >> "$output_file"

                # Calculate adherence rates
                echo "### Adherence Rates (Last $days days)" >> "$output_file"
                echo "" >> "$output_file"

                grep "^MED|" "$MEDS_FILE" | while IFS='|' read -r type med_name schedule; do
                    DOSES_PER_DAY=$(echo "$schedule" | tr ',' '\n' | wc -l | tr -d ' ')
                    EXPECTED_DOSES=$((days * DOSES_PER_DAY))
                    ACTUAL_DOSES=$(grep "^DOSE|" "$MEDS_FILE" 2>/dev/null | awk -F'|' -v cutoff="$cutoff" -v med="$med_name" '$2 >= cutoff && $3 == med' | wc -l | tr -d ' ')

                    if [ "$EXPECTED_DOSES" -gt 0 ]; then
                        ADHERENCE=$((ACTUAL_DOSES * 100 / EXPECTED_DOSES))
                        echo "- **$med_name**: ${ADHERENCE}% adherence ($ACTUAL_DOSES/$EXPECTED_DOSES doses)" >> "$output_file"
                    else
                        echo "- **$med_name**: N/A (no schedule data)" >> "$output_file"
                    fi
                done
                echo "" >> "$output_file"

                # Recent dose history
                echo "### Recent Doses" >> "$output_file"
                echo "" >> "$output_file"
                if grep -q "^DOSE|" "$MEDS_FILE" 2>/dev/null; then
                    grep "^DOSE|" "$MEDS_FILE" | awk -F'|' -v cutoff="$cutoff" '
                        $2 >= cutoff {
                            printf "- **%s** at %s: %s\n", substr($2, 1, 10), substr($2, 12), $3
                        }
                    ' >> "$output_file"
                else
                    echo "No doses logged for this period." >> "$output_file"
                fi
            else
                echo "No medications currently configured." >> "$output_file"
            fi
        else
            echo "No medication data available." >> "$output_file"
        fi

        echo "" >> "$output_file"
        echo "---" >> "$output_file"
        echo "" >> "$output_file"
        echo "*Generated by dotfiles health.sh tracking system*" >> "$output_file"

        echo "✅ Health data exported to: $output_file"
        echo ""
        echo "You can now:"
        echo "  • Email this file to your doctor"
        echo "  • Print it for your appointment"
        echo "  • Copy to clipboard: pbcopy < $output_file"
        ;;

    dashboard)
        set +e
        echo "🏥 HEALTH DASHBOARD (Last 30 Days) 🏥"
        echo ""

        # --- Configuration ---
        DAYS_AGO=30
        CUTOFF_DATE=$(date_shift_days "-$DAYS_AGO" "%Y-%m-%d")
        HEALTH_FILE="$HOME/.config/dotfiles-data/health.txt"

        if [ ! -f "$HEALTH_FILE" ]; then
            echo "Health data file not found."
            exit 1
        fi

        if [ ! -s "$HEALTH_FILE" ]; then
            echo "Health data file is empty."
            exit 0
        fi

        # --- Calculations ---
        # Filter relevant data once
        RECENT_DATA=$(grep -E "^(ENERGY|SYMPTOM)" "$HEALTH_FILE" | awk -F'|' -v cutoff="$CUTOFF_DATE" '$2 >= cutoff' || true)

        # 1. Average Energy Level
        AVG_ENERGY=$(echo "$RECENT_DATA" | grep "^ENERGY" | awk -F'|' '{ sum += $3; count++ } END { if (count > 0) printf "%.1f", sum/count; else echo "N/A"; }')
        echo "• Average Energy (30d): $AVG_ENERGY/10"

        # 2. Symptom Frequency
        echo "• Symptom Frequency (30d):"
        FOG_COUNT=$(echo "$RECENT_DATA" | grep -ci "fog" | tr -d ' ')
        FATIGUE_COUNT=$(echo "$RECENT_DATA" | grep -ci "fatigue" | tr -d ' ')
        HEADACHE_COUNT=$(echo "$RECENT_DATA" | grep -ci "headache" | tr -d ' ')
        PAIN_COUNT=$(echo "$RECENT_DATA" | grep -ci "pain" | tr -d ' ')
        ANXIETY_COUNT=$(echo "$RECENT_DATA" | grep -ci "anxiety" | tr -d ' ')
        OTHER_COUNT=$(echo "$RECENT_DATA" | grep -v -i -e "fog" -e "fatigue" -e "headache" -e "pain" -e "anxiety" -c | tr -d ' ')

        if [ "$FOG_COUNT" -gt 0 ]; then
            printf "  - %-15s: %s times\n" "fog" "$FOG_COUNT"
        fi
        if [ "$FATIGUE_COUNT" -gt 0 ]; then
            printf "  - %-15s: %s times\n" "fatigue" "$FATIGUE_COUNT"
        fi
        if [ "$HEADACHE_COUNT" -gt 0 ]; then
            printf "  - %-15s: %s times\n" "headache" "$HEADACHE_COUNT"
        fi
        if [ "$PAIN_COUNT" -gt 0 ]; then
            printf "  - %-15s: %s times\n" "pain" "$PAIN_COUNT"
        fi
        if [ "$ANXIETY_COUNT" -gt 0 ]; then
            printf "  - %-15s: %s times\n" "anxiety" "$ANXIETY_COUNT"
        fi
        if [ "$OTHER_COUNT" -gt 0 ]; then
            printf "  - %-15s: %s times\n" "other" "$OTHER_COUNT"
        fi

        # 3. Average energy on days with 'fog'
        FOG_DAYS=$(echo "$RECENT_DATA" | grep "^SYMPTOM" | grep -i "fog" | awk -F'|' '{print substr($2, 1, 10)}' | sort -u)
        if [ -n "$FOG_DAYS" ]; then
            FOG_DAY_ENERGY_SUM=0
            FOG_DAY_ENERGY_COUNT=0
            for day in $FOG_DAYS; do
                # Get energy for that day. If multiple, take the first one.
                ENERGY_ON_FOG_DAY=$(echo "$RECENT_DATA" | grep "^ENERGY" | grep "^ENERGY|$day" | head -n 1 | awk -F'|' '{print $3}')
                if [ -n "$ENERGY_ON_FOG_DAY" ]; then
                    FOG_DAY_ENERGY_SUM=$((FOG_DAY_ENERGY_SUM + ENERGY_ON_FOG_DAY))
                    FOG_DAY_ENERGY_COUNT=$((FOG_DAY_ENERGY_COUNT + 1))
                fi
            done

            if [ "$FOG_DAY_ENERGY_COUNT" -gt 0 ]; then
                AVG_ENERGY_FOG=$(awk "BEGIN {printf \"%.1f\", $FOG_DAY_ENERGY_SUM / $FOG_DAY_ENERGY_COUNT}")
                echo "• Avg. Energy on 'Fog' Days: $AVG_ENERGY_FOG/10"
            else
                echo "• Avg. Energy on 'Fog' Days: N/A (no energy logged on fog days)"
            fi
        else
            echo "• Avg. Energy on 'Fog' Days: N/A (no 'fog' symptoms logged)"
        fi

        # 4. Energy vs. Productivity Correlation
        echo ""
        echo "• Energy vs. Productivity Correlation (30d):"
        correlate_tasks "$RECENT_DATA"
        correlate_commits "$RECENT_DATA"
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
        echo "Error: Unknown command '$1'" >&2
        echo "Usage: health [add|symptom|energy|list|summary|dashboard|export|remove]"
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
        echo ""
        echo "Reporting:"
        echo "  health dashboard        # Show 30-day trend analysis"
        echo "  health export [days]    # Export last N days (default: 7)"
        exit 1
        ;;
esac
get_file_mtime() {
    local file="$1"
    if command -v stat >/dev/null 2>&1; then
        if stat -f %m "$file" >/dev/null 2>&1; then
            stat -f %m "$file"
        else
            stat -c %Y "$file"
        fi
    else
        python3 - "$file" <<'PY'
import os, sys
print(int(os.path.getmtime(sys.argv[1])))
PY
    fi
}

load_commit_cache() {
    local target_array="$1"
    if [ ! -f "$COMMITS_CACHE_FILE" ]; then
        return 1
    fi

    local now mtime age
    now=$(date +%s)
    mtime=$(get_file_mtime "$COMMITS_CACHE_FILE")
    age=$((now - mtime))
    if [ "$age" -ge "$COMMITS_CACHE_TTL" ]; then
        return 1
    fi

    while read -r day count; do
        [ -z "$day" ] && continue
        eval "$target_array[\"\$day\"]=\$count"
    done < "$COMMITS_CACHE_FILE"
    return 0
}

save_commit_cache() {
    local src_array="$1"
    mkdir -p "$CACHE_DIR"
    local tmp_file="$COMMITS_CACHE_FILE.tmp"
    : > "$tmp_file"
    eval "local keys=(\"\${!$src_array[@]}\")"
    for day in "${keys[@]}"; do
        eval "local value=\"\${$src_array[\"$day\"]}\""
        printf "%s %s\n" "$day" "$value" >> "$tmp_file"
    done
    mv "$tmp_file" "$COMMITS_CACHE_FILE"
}
