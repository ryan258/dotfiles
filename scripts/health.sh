#!/usr/bin/env bash
set -euo pipefail
# health.sh - Track health appointments, symptoms, and energy levels

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_lib "date_utils.sh"

DATA_DIR="${DATA_DIR:-$HOME/.config/dotfiles-data}"
HEALTH_FILE="${HEALTH_FILE:-$DATA_DIR/health.txt}"
CACHE_DIR="${CACHE_DIR:-$DATA_DIR/cache}"
mkdir -p "$CACHE_DIR"

COMMITS_CACHE_FILE="$CACHE_DIR/health_commits.cache"
COMMITS_CACHE_TTL="${HEALTH_COMMITS_CACHE_TTL:-3600}"
COMMITS_LOOKBACK_DAYS="${HEALTH_COMMITS_LOOKBACK_DAYS:-90}"

# Ensure health file exists
touch "$HEALTH_FILE"

# Cleanup
cleanup() {
    # Remove temp files if any (atomic ops handle their own, but good practice)
    :
}
trap cleanup EXIT

# --- Helper Functions ---
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

correlate_tasks() {
    local recent_data="$1"
    local todo_done_file="${DONE_FILE:-$DATA_DIR/todo_done.txt}"

    if [ ! -f "$todo_done_file" ]; then
        echo "  - Avg tasks on low energy days: N/A (no todo data)"
        echo "  - Avg tasks on high energy days: N/A (no todo data)"
        return
    fi

    # Use awk to map tasks to dates and correlate with energy
    awk -F'|' '
    FNR==NR {
        if (NF >= 2) {
             date = substr($1, 1, 10)
             tasks[date]++
        }
        next
    }
    {
        if ($1 == "ENERGY") {
            date = substr($2, 1, 10)
            energy = $3
            count = (date in tasks) ? tasks[date] : 0
            
            if (energy <= 4) {
                low_sum += count
                low_count++
            } else if (energy >= 7) {
                high_sum += count
                high_count++
            }
        }
    }
    END {
        low_avg = (low_count > 0) ? low_sum / low_count : 0
        high_avg = (high_count > 0) ? high_sum / high_count : 0
        printf "  - Avg tasks on low energy days (1-4): %.1f\n", low_avg
        printf "  - Avg tasks on high energy days (7-10): %.1f\n", high_avg
    }
    ' "$todo_done_file" - <<< "$recent_data"
}

generate_commit_cache() {
    local projects_dir="$HOME/Projects"
    local cache_file="$COMMITS_CACHE_FILE"
    
    # Check TTL
    if [ -f "$cache_file" ]; then
        local now=$(date +%s)
        local mtime=$(get_file_mtime "$cache_file")
        local age=$((now - mtime))
        if [ "$age" -lt "$COMMITS_CACHE_TTL" ]; then
            return 0 # Cache is valid
        fi
    fi

    # Regenerate cache
    echo "  (Regenerating git commit cache...)" >&2
    
    local content
    content=$(
        (find "$projects_dir" -maxdepth 3 -type d -name ".git" 2>/dev/null || true) | while read -r gitdir; do
            proj_dir=$(dirname "$gitdir")
            git -C "$proj_dir" log --all --since="${COMMITS_LOOKBACK_DAYS} days ago" --pretty=format:%cs 2>/dev/null || true
            echo ""
        done | (grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || true) | sort | uniq -c | awk '{print $2, $1}'
    )

    atomic_write "$content" "$cache_file"
}

correlate_commits() {
    local recent_data="$1"
    local projects_dir="$HOME/Projects"

    if [ ! -d "$projects_dir" ]; then
        echo "  - Avg commits on low energy days: N/A (no Projects dir)"
        echo "  - Avg commits on high energy days: N/A (no Projects dir)"
        return
    fi

    generate_commit_cache
    
    if [ ! -f "$COMMITS_CACHE_FILE" ]; then
         echo "  - Avg commits on low energy days: N/A (cache failed)"
         echo "  - Avg commits on high energy days: N/A (cache failed)"
         return
    fi

    awk '
    BEGIN { FS=" " } 
    FNR==NR {
        commits[$1] = $2
        next
    }
    {
        split($0, parts, "|")
        if (parts[1] == "ENERGY") {
            date = substr(parts[2], 1, 10)
            energy = parts[3]
            
            count = (date in commits) ? commits[date] : 0
            
            if (energy <= 4) {
                low_sum += count
                low_count++
            } else if (energy >= 7) {
                high_sum += count
                high_count++
            }
        }
    }
    END {
        low_avg = (low_count > 0) ? low_sum / low_count : 0
        high_avg = (high_count > 0) ? high_sum / high_count : 0
        printf "  - Avg commits on low energy days (1-4): %.1f\n", low_avg
        printf "  - Avg commits on high energy days (7-10): %.1f\n", high_avg
    }
    ' "$COMMITS_CACHE_FILE" - <<< "$recent_data"
}

# --- Main Command Handler ---
cmd_add() {
    local desc="$1"
    local time_str="$2"
    
    if [ -z "$desc" ] || [ -z "$time_str" ]; then
        echo "Usage: $(basename "$0") add \"description\" \"YYYY-MM-DD HH:MM\""
        exit 1
    fi
    desc=$(sanitize_input "$desc")
    desc=${desc//$'\n'/\\n}
    time_str=$(sanitize_input "$time_str")
    echo "APPT|$time_str|$desc" >> "$HEALTH_FILE"
    echo "Added: $desc on $time_str"
}

cmd_symptom() {
    local symptom_note="$*"
    if [ -z "$symptom_note" ]; then
        echo "Usage: $(basename "$0") symptom \"symptom description\""
        exit 1
    fi
    local timestamp=$(date '+%Y-%m-%d %H:%M')
    symptom_note=$(sanitize_input "$symptom_note")
    symptom_note=${symptom_note//$'\n'/\\n}
    echo "SYMPTOM|$timestamp|$symptom_note" >> "$HEALTH_FILE"
    echo "Logged symptom: $symptom_note"
}

cmd_energy() {
    local rating="$1"
    if [ -z "$rating" ]; then
        echo "Usage: $(basename "$0") energy <1-10>"
        exit 1
    fi
    validate_range "$rating" 1 10 "energy rating" || exit 1
    
    local timestamp=$(date '+%Y-%m-%d %H:%M')
    echo "ENERGY|$timestamp|$rating" >> "$HEALTH_FILE"
    echo "Logged energy level: $rating/10"
}

cmd_list() {
    if [ ! -s "$HEALTH_FILE" ]; then
        echo "No health data tracked."
        exit 0
    fi

    echo "🏥 UPCOMING HEALTH APPOINTMENTS:"
    local appt_found=false
    
    local TODAY_STR=$(date +%Y-%m-%d)
    local TODAY_EPOCH=$(timestamp_to_epoch "$TODAY_STR")

    if grep -q "^APPT|" "$HEALTH_FILE" 2>/dev/null; then
        grep "^APPT|" "$HEALTH_FILE" | sort -t'|' -k2 | while IFS='|' read -r type appt_date desc; do
            local appt_epoch=$(timestamp_to_epoch "$appt_date")
            [ "$appt_epoch" -le 0 ] && continue
            
            local diff_seconds=$(( appt_epoch - TODAY_EPOCH ))
            local days_until=$(( diff_seconds / 86400 ))
            
            if [ "$days_until" -ge 0 ]; then
                appt_found=true
                if [ "$days_until" -eq 0 ]; then
                    echo "  • $desc - $appt_date (Today)"
                elif [ "$days_until" -eq 1 ]; then
                    echo "  • $desc - $appt_date (Tomorrow)"
                else
                    echo "  • $desc - $appt_date (in $days_until days)"
                fi
            fi
        done
    fi
    if [ "$appt_found" = "false" ]; then
        echo "  (No appointments tracked)"
    fi

    echo ""
    echo "📊 RECENT ENERGY LEVELS (last 7 days):"
    local cutoff=$(date_shift_days -7 "%Y-%m-%d")
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
}

cmd_summary() {
    if [ ! -s "$HEALTH_FILE" ]; then
        echo "No health data tracked."
        exit 0
    fi
    local today=$(date '+%Y-%m-%d')
    local today_energy=$(grep "^ENERGY|$today" "$HEALTH_FILE" 2>/dev/null | tail -1 | cut -d'|' -f3)
    if [ -n "$today_energy" ]; then
        echo "Energy: $today_energy/10"
    fi
    local symptom_count=$(grep -c "^SYMPTOM|$today" "$HEALTH_FILE" 2>/dev/null || echo "0")
    if [ "$symptom_count" -gt 0 ]; then
        echo "Symptoms logged today: $symptom_count"
    fi
}

cmd_remove() {
    local line_num="$1"
    if [ -z "$line_num" ]; then
        echo "Usage: $(basename "$0") remove <line_number>"
        grep -n "^APPT|" "$HEALTH_FILE" 2>/dev/null | sed 's/^/  /' || echo "No appointments to remove"
        exit 1
    fi
    
    validate_numeric "$line_num" "line number" || exit 1
    
    # Use atomic delete
    atomic_delete_line "$line_num" "$HEALTH_FILE" || {
         echo "Error: Failed to remove line $line_num" >&2
         exit 1
    }
    echo "Removed line #$line_num"
}

cmd_dashboard() {
    set +e # Relax error checking for dashboard display
    echo "🏥 HEALTH DASHBOARD (Last 30 Days) 🏥"
    echo ""

    local DAYS_AGO=30
    local CUTOFF_DATE=$(date_shift_days "-$DAYS_AGO" "%Y-%m-%d")

    if [ ! -s "$HEALTH_FILE" ]; then
        echo "Health data file is empty."
        exit 0
    fi

    # Filter relevant data once
    local RECENT_DATA=$(grep -E "^(ENERGY|SYMPTOM)" "$HEALTH_FILE" | awk -F'|' -v cutoff="$CUTOFF_DATE" '$2 >= cutoff' || true)

    # 1. Average Energy Level
    local AVG_ENERGY=$(echo "$RECENT_DATA" | grep "^ENERGY" | awk -F'|' '{ sum += $3; count++ } END { if (count > 0) printf "%.1f", sum/count; else echo "N/A"; }')
    echo "• Average Energy (30d): $AVG_ENERGY/10"

    # 2. Symptom Frequency
    echo "• Symptom Frequency (30d):"
    echo "$RECENT_DATA" | grep "^SYMPTOM" | cut -d'|' -f3 | sort | uniq -c | sort -nr | head -5 | while read -r count name; do
         printf "  - %-15s: %s times\n" "$name" "$count"
    done

    # 3. Average energy on days with 'fog'
    local FOG_DAYS=$(echo "$RECENT_DATA" | grep "^SYMPTOM" | grep -i "fog" | awk -F'|' '{print substr($2, 1, 10)}' | sort -u)
    if [ -n "$FOG_DAYS" ]; then
        local FOG_DAY_ENERGY_SUM=0
        local FOG_DAY_ENERGY_COUNT=0
        while read -r day; do
            [ -z "$day" ] && continue
            local ENERGY_ON_FOG_DAY=$(echo "$RECENT_DATA" | grep "^ENERGY" | grep "^ENERGY|$day" | head -n 1 | awk -F'|' '{print $3}')
            if [ -n "$ENERGY_ON_FOG_DAY" ]; then
                FOG_DAY_ENERGY_SUM=$((FOG_DAY_ENERGY_SUM + ENERGY_ON_FOG_DAY))
                FOG_DAY_ENERGY_COUNT=$((FOG_DAY_ENERGY_COUNT + 1))
            fi
        done <<< "$FOG_DAYS"

        if [ "$FOG_DAY_ENERGY_COUNT" -gt 0 ]; then
            local AVG_ENERGY_FOG=$(awk "BEGIN {printf \"%.1f\", $FOG_DAY_ENERGY_SUM / $FOG_DAY_ENERGY_COUNT}")
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
}

cmd_export() {
    local format="${1:-csv}"
    local output_file="${2:-}"

    if [[ ! -s "$HEALTH_FILE" ]]; then
        echo "No health data to export." >&2
        exit 1
    fi

    case "$format" in
        csv)
            if [[ -n "$output_file" ]]; then
                {
                    echo "type,timestamp,value"
                    awk -F'|' '{print $1","$2","$3}' "$HEALTH_FILE"
                } > "$output_file"
                echo "Exported to: $output_file"
            else
                echo "type,timestamp,value"
                awk -F'|' '{print $1","$2","$3}' "$HEALTH_FILE"
            fi
            ;;
        json)
            local json_output
            json_output=$(awk -F'|' '
                BEGIN { print "[" }
                NR > 1 { print "," }
                {
                    gsub(/"/, "\\\"", $3)
                    printf "  {\"type\": \"%s\", \"timestamp\": \"%s\", \"value\": \"%s\"}", $1, $2, $3
                }
                END { print "\n]" }
            ' "$HEALTH_FILE")

            if [[ -n "$output_file" ]]; then
                echo "$json_output" > "$output_file"
                echo "Exported to: $output_file"
            else
                echo "$json_output"
            fi
            ;;
        *)
            echo "Usage: $(basename "$0") export {csv|json} [output_file]" >&2
            echo "Formats: csv (default), json" >&2
            exit 1
            ;;
    esac
}


cmd_fog() {
    local rating="$1"
    if [ -z "$rating" ]; then
        echo "Usage: $(basename "$0") fog <1-10>"
        exit 1
    fi
    validate_range "$rating" 1 10 "fog rating" || exit 1
    
    local timestamp=$(date '+%Y-%m-%d %H:%M')
    echo "FOG|$timestamp|$rating" >> "$HEALTH_FILE"
    echo "Logged brain fog level: $rating/10"
    
    # Trigger check immediately
    cmd_check
}

cmd_check() {
    # Circuit Breaker Logic
    # Returns 0 if OPERATIONAL, 1 if RECOVERY RECOMMENDED

    if [ ! -s "$HEALTH_FILE" ]; then
        echo "No health data. System: OPERATIONAL (Default)"
        return 0
    fi

    local today=$(date '+%Y-%m-%d')
    local last_energy=$(grep "^ENERGY|" "$HEALTH_FILE" 2>/dev/null | tail -1 | cut -d'|' -f3)
    local last_fog=$(grep "^FOG|" "$HEALTH_FILE" 2>/dev/null | tail -1 | cut -d'|' -f3)
    
    # Check Energy (Low Energy Rule)
    if [ -n "$last_energy" ]; then
        if [ "$last_energy" -le 3 ]; then
            echo "🛑 CIRCUIT BREAKER TRIPPED: Low Energy ($last_energy/10)"
            echo "   Action: STOP high-cognitive tasks."
            echo "   Recommendation: Rest, active recovery, or Low Energy Menu items."
            return 1
        fi
    fi

    # Check Fog (High Fog Rule)
    if [ -n "$last_fog" ]; then
        if [ "$last_fog" -ge 6 ]; then
             echo "🛑 CIRCUIT BREAKER TRIPPED: High Brain Fog ($last_fog/10)"
             echo "   Action: EXTEND deadlines by 24h."
             echo "   Recommendation: No strategic decisions. Admin/Rote work only."
             return 1
        fi
    fi

    echo "✅ SYSTEM OPERATIONAL"
    echo "   Energy: ${last_energy:-N/A}/10 | Fog: ${last_fog:-N/A}/10"
    return 0
}

# --- Main Dispatcher ---
main() {
    local cmd="${1:-}"
    shift || true

    case "$cmd" in
        add)        cmd_add "$@" ;;
        symptom)    cmd_symptom "$@" ;;
        energy)     cmd_energy "$@" ;;
        fog)        cmd_fog "$@" ;;
        check)      cmd_check "$@" ;;
        list)       cmd_list "$@" ;;
        summary)    cmd_summary "$@" ;;
        remove)     cmd_remove "$@" ;;
        dashboard)  cmd_dashboard "$@" ;;
        export)
            cmd_export "$@"
            ;;
             
        *)
            echo "Usage: $(basename "$0") {add|symptom|energy|fog|check|list|summary|dashboard|remove|export}"
            exit 1
            ;;
    esac
}

main "$@"
