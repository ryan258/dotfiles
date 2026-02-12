#!/usr/bin/env bash
# scripts/lib/health_ops.sh
# Shared Health tracking operations
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_HEALTH_OPS_LOADED:-}" ]]; then
    return 0
fi
readonly _HEALTH_OPS_LOADED=true

if [[ -z "${DATA_DIR:-}" ]]; then
    echo "Error: DATA_DIR is not set. Source scripts/lib/config.sh before health_ops.sh." >&2
    return 1
fi
if ! command -v timestamp_to_epoch >/dev/null 2>&1 || ! command -v date_today >/dev/null 2>&1; then
    echo "Error: date utilities are not loaded. Source scripts/lib/date_utils.sh before health_ops.sh." >&2
    return 1
fi

# Parse timestamp helper
_health_parse_timestamp() {
    local raw="$1"
    local epoch
    epoch=$(timestamp_to_epoch "$raw")
    echo "${epoch:-0}"
}

# Display health summary (Appointments, Energy, Symptoms)
# Usage: show_health_summary
show_health_summary() {
    local health_file="${HEALTH_FILE:-}"

    if [[ -z "$health_file" ]]; then
        echo "  (health file path is not configured; source config.sh)"
        return 0
    fi

    if [ ! -f "$health_file" ] || [ ! -s "$health_file" ]; then
        echo "  (no data tracked - try: health add, health energy, health symptom)"
        return 0
    fi

    # 1. Appointments
    local today_str
    today_str=$(date_today)
    local today_epoch
    today_epoch=$(_health_parse_timestamp "$today_str")
    
    local has_data=false

    if grep -q "^APPT|" "$health_file" 2>/dev/null; then
        grep "^APPT|" "$health_file" | sort -t'|' -k2 | while IFS='|' read -r type appt_date desc; do
            local appt_epoch
            appt_epoch=$(_health_parse_timestamp "$appt_date")
            
            if [ "$appt_epoch" -le 0 ]; then
                continue
            fi
            
            local diff_seconds=$(( appt_epoch - today_epoch ))
            local days_until=$(( diff_seconds / 86400 ))
            
            if [ "$days_until" -ge 0 ]; then
                has_data=true
                if [ "$days_until" -eq 1 ]; then
                     echo "  • $desc - $appt_date (Tomorrow)"
                elif [ "$days_until" -eq 0 ]; then
                     echo "  • $desc - $appt_date (Today)"
                else
                     echo "  • $desc - $appt_date (in $days_until days)"
                fi
            fi
        done
    fi

    # 2. Energy
    if grep -q "^ENERGY|$today_str" "$health_file" 2>/dev/null; then
        has_data=true
        local today_energy
        today_energy=$(grep "^ENERGY|$today_str" "$health_file" | tail -1 | cut -d'|' -f3)
        echo "  Energy level: $today_energy/10"
    fi

    # 3. Symptoms
    if grep -q "^SYMPTOM|$today_str" "$health_file" 2>/dev/null; then
        has_data=true
        local symptom_count
        symptom_count=$(grep -c "^SYMPTOM|$today_str" "$health_file")
        echo "  Symptoms logged today: $symptom_count (run 'health list' to see)"
    fi

    if [ "$has_data" = "false" ]; then
         echo "  (no data tracked - try: health add, health energy, health symptom)"
    fi
}
