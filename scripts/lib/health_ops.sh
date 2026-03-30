#!/usr/bin/env bash
# scripts/lib/health_ops.sh
# Shared Health tracking operations
# NOTE: SOURCED file. Do NOT use set -euo pipefail.
#
# Dependencies:
# - common.sh: validate_range
# - config.sh: DATA_DIR, DOTFILES_DIR, HEALTH_FILE
# - date_utils.sh: timestamp_to_epoch, date_today

if [[ -n "${_HEALTH_OPS_LOADED:-}" ]]; then
    return 0
fi
readonly _HEALTH_OPS_LOADED=true
readonly HEALTH_SECONDS_PER_DAY=86400
# This folder is where the watch data lives after we sync or import it.
# Think of it like a small filing cabinet just for Fitbit numbers.
readonly HEALTH_FITBIT_DIR="$DATA_DIR/fitbit"

if [[ -z "${DATA_DIR:-}" ]]; then
    echo "Error: DATA_DIR is not set. Source scripts/lib/config.sh before health_ops.sh." >&2
    return 1
fi
if ! command -v timestamp_to_epoch >/dev/null 2>&1 || ! command -v date_today >/dev/null 2>&1; then
    echo "Error: date utilities are not loaded. Source scripts/lib/date_utils.sh before health_ops.sh." >&2
    return 1
fi

# Turn a human-readable date like "2026-03-26 08:00" into a machine-friendly number.
# Computers compare big numbers more easily than date words.
_health_parse_timestamp() {
    local raw="$1"
    local epoch
    epoch=$(timestamp_to_epoch "$raw")
    echo "${epoch:-0}"
}

_health_fitbit_metric_path() {
    local metric="$1"

    # Each kind of Fitbit number gets its own file.
    # This helper answers the question: "Which drawer should I open?"
    case "$metric" in
        steps) echo "$HEALTH_FITBIT_DIR/steps.txt" ;;
        sleep_minutes) echo "$HEALTH_FITBIT_DIR/sleep_minutes.txt" ;;
        resting_heart_rate) echo "$HEALTH_FITBIT_DIR/resting_heart_rate.txt" ;;
        hrv) echo "$HEALTH_FITBIT_DIR/hrv.txt" ;;
        *)
            echo "Error: Unsupported Fitbit metric '$metric'" >&2
            return 1
            ;;
    esac
}

_health_fitbit_metric_label() {
    local metric="$1"

    # These are the shorter labels we show to humans.
    case "$metric" in
        steps) echo "steps" ;;
        sleep_minutes) echo "sleep" ;;
        resting_heart_rate) echo "resting HR" ;;
        hrv) echo "HRV" ;;
        *)
            echo "$metric"
            ;;
    esac
}

_health_format_minutes_human() {
    local raw_minutes="$1"

    if [[ ! "$raw_minutes" =~ ^-?[0-9]+$ ]]; then
        printf '%sm' "$raw_minutes"
        return 0
    fi

    local minutes="$raw_minutes"
    local sign=""
    if [ "$minutes" -lt 0 ]; then
        sign="-"
        minutes=$(( -minutes ))
    fi

    if [ "$minutes" -lt 60 ]; then
        printf '%s%sm' "$sign" "$minutes"
        return 0
    fi

    local hours=$(( minutes / 60 ))
    local remaining_minutes=$(( minutes % 60 ))
    if [ "$remaining_minutes" -eq 0 ]; then
        printf '%s%sh' "$sign" "$hours"
    else
        printf '%s%sh %sm' "$sign" "$hours" "$remaining_minutes"
    fi
}

_health_fitbit_metric_display() {
    local metric="$1"
    local value="$2"

    # Some numbers need tiny formatting help.
    # Example: sleep is easier to read as "4h 17m" than plain "257".
    case "$metric" in
        sleep_minutes) _health_format_minutes_human "$value" ;;
        *)
            printf '%s' "$value"
            ;;
    esac
}

health_ops_auto_sync_fitbit() {
    local dotfiles_root="${DOTFILES_DIR:-}"
    local auth_file="${GOOGLE_HEALTH_AUTH_FILE:-$DATA_DIR/google_health_oauth.json}"
    local sync_days="${GOOGLE_HEALTH_DEFAULT_DAYS:-7}"
    local sync_script=""

    # First, find the main dotfiles folder so we know where fitbit_sync.sh lives.
    if [[ -z "$dotfiles_root" ]]; then
        dotfiles_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    fi
    sync_script="$dotfiles_root/scripts/fitbit_sync.sh"

    # Quietly give up if the sync tool is missing or if the user has not logged in yet.
    # We do not want morning/evening status screens to crash just because wearable sync
    # is not ready today.
    [[ -x "$sync_script" ]] || return 1
    [[ -s "$auth_file" ]] || return 1

    # Ask the sync script to refresh recent days of wearable data.
    # The number of days comes from the normal Google Health default setting.
    "$sync_script" sync "$sync_days"
}

health_ops_has_fitbit_data() {
    local metric file_path

    # Look through the metric files and answer a simple yes/no question:
    # "Do we already have any wearable data at all?"
    for metric in steps sleep_minutes resting_heart_rate hrv; do
        file_path=$(_health_fitbit_metric_path "$metric") || continue
        if [[ -s "$file_path" ]]; then
            return 0
        fi
    done

    return 1
}

health_ops_get_latest_fitbit_metric() {
    local metric="$1"
    local file_path
    file_path=$(_health_fitbit_metric_path "$metric") || return 1
    [[ -s "$file_path" ]] || return 1

    # A tiny Python helper reads the whole file and keeps the last valid line.
    # The last line is the newest day we know about because new syncs append newer days.
    python3 - "$file_path" <<'PY'
import os
import sys

path = sys.argv[1]
latest = None

if os.path.exists(path):
    with open(path, "r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line or "|" not in line:
                continue
            latest = line

if latest:
    print(latest)
PY
}

health_ops_print_fitbit_snapshot() {
    local metric latest_line date value label display_value
    local printed=false

    # Print the newest reading for each important wearable signal.
    # This becomes the quick "what does the watch say right now?" summary.
    for metric in sleep_minutes resting_heart_rate hrv steps; do
        latest_line="$(health_ops_get_latest_fitbit_metric "$metric" || true)"
        [[ -n "$latest_line" ]] || continue

        date="${latest_line%%|*}"
        value="${latest_line#*|}"
        label=$(_health_fitbit_metric_label "$metric")
        display_value=$(_health_fitbit_metric_display "$metric" "$value")

        printed=true
        echo "  Fitbit ${label}: ${display_value} (${date})"
    done

    [[ "$printed" == "true" ]]
}

health_ops_print_fitbit_dashboard() {
    local days="${1:-30}"
    local health_file="${HEALTH_FILE:-}"

    # This bigger Python block does the math for the dashboard:
    # it looks at recent Fitbit files, computes averages, and compares sleep
    # with low-energy and high-energy days from the health log.
    python3 - "$HEALTH_FITBIT_DIR" "$health_file" "$days" "$(date_today)" <<'PY'
import os
import sys
from datetime import datetime, timedelta

fitbit_dir, health_file, days_raw, today_raw = sys.argv[1:5]
days = int(days_raw)
today = datetime.strptime(today_raw, "%Y-%m-%d").date()
cutoff = today - timedelta(days=days)

metric_defs = [
    ("sleep_minutes", "sleep", "m"),
    ("steps", "steps", ""),
    ("resting_heart_rate", "resting HR", ""),
    ("hrv", "HRV", ""),
]


def parse_float(value):
    # Turn text like "257" into the number 257.0.
    # If the value is junk, return None so we can skip it safely.
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def format_value(value, suffix=""):
    # Show friendly numbers to humans:
    # 257.0 becomes "257", but 257.5 stays "257.5".
    rounded = round(value)
    if abs(value - rounded) < 1e-9:
        body = str(int(rounded))
    else:
        body = f"{value:.1f}".rstrip("0").rstrip(".")
    return f"{body}{suffix}"


def load_metric(metric):
    # Read one Fitbit metric file and build a list of (day, value) pairs.
    # Example: [("2026-03-26", 822), ("2026-03-27", 5000)]
    path = os.path.join(fitbit_dir, f"{metric}.txt")
    rows = []
    if not os.path.exists(path):
        return rows
    with open(path, "r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line or "|" not in line:
                continue
            day_str, value_raw = line.split("|", 1)
            try:
                day = datetime.strptime(day_str, "%Y-%m-%d").date()
            except ValueError:
                continue
            value = parse_float(value_raw)
            if value is None:
                continue
            rows.append((day, value))
    return rows


def load_energy_by_day():
    # Read only ENERGY lines from the health log so we can compare
    # sleep with good-energy and low-energy days later.
    energy = {}
    if not health_file or not os.path.exists(health_file):
        return energy
    with open(health_file, "r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line.startswith("ENERGY|"):
                continue
            parts = line.split("|")
            if len(parts) < 3:
                continue
            day_str = parts[1][:10]
            try:
                day = datetime.strptime(day_str, "%Y-%m-%d").date()
                energy[day] = float(parts[2])
            except ValueError:
                continue
    return energy


energy_by_day = load_energy_by_day()
had_output = False
lines = []

for metric, label, suffix in metric_defs:
    # Keep only the recent rows inside the dashboard window,
    # then compute both an average and the newest value.
    rows = [(day, value) for day, value in load_metric(metric) if day >= cutoff]
    if not rows:
        continue
    rows.sort(key=lambda item: item[0])
    latest_day, latest_value = rows[-1]
    avg_value = sum(value for _, value in rows) / len(rows)
    lines.append(
        f"  - {label}: avg {format_value(avg_value, suffix)} over {len(rows)} day(s); latest {format_value(latest_value, suffix)} ({latest_day.isoformat()})"
    )
    had_output = True

sleep_rows = [(day, value) for day, value in load_metric("sleep_minutes") if day >= cutoff]
if sleep_rows:
    # Split sleep into two buckets:
    # low-energy days and high-energy days.
    # This helps answer "Do I usually feel better after more sleep?"
    low = [value for day, value in sleep_rows if energy_by_day.get(day, 0) <= 4]
    high = [value for day, value in sleep_rows if energy_by_day.get(day, 0) >= 7]
    if low:
        lines.append(f"  - sleep on low-energy days (1-4): {format_value(sum(low) / len(low), 'm')} (n={len(low)})")
        had_output = True
    if high:
        lines.append(f"  - sleep on high-energy days (7-10): {format_value(sum(high) / len(high), 'm')} (n={len(high)})")
        had_output = True

if had_output:
    # Print the whole wearable mini-report only if we found at least one useful fact.
    print("• Wearable Signals (30d):")
    print("\n".join(lines))
PY
}

# Get daily health metrics as structured pipe-delimited data.
# Usage: health_ops_get_daily_summary [date]
# Output format (one line per field, key=value):
#   energy=<1-10 or empty>
#   fog=<1-10 or empty>
#   symptom_count=<N>
#   symptoms=<comma-separated list or empty>
# Returns 0 even if no data (fields will be empty).
health_ops_get_daily_summary() {
    local target_date="${1:-$(date_today)}"
    local health_file="${HEALTH_FILE:-}"

    # These start empty on purpose.
    # If the log file is missing, we still return a predictable shape.
    local energy="" fog="" symptom_count=0 symptoms=""

    if [[ -n "$health_file" && -f "$health_file" && -s "$health_file" ]]; then
        energy=$(grep "^ENERGY|$target_date" "$health_file" 2>/dev/null | tail -1 | cut -d'|' -f3)
        fog=$(grep "^FOG|$target_date" "$health_file" 2>/dev/null | tail -1 | cut -d'|' -f3)
        symptom_count=$(grep -c "^SYMPTOM|$target_date" "$health_file" 2>/dev/null || echo "0")
        symptoms=$(grep "^SYMPTOM|$target_date" "$health_file" 2>/dev/null | cut -d'|' -f3 | paste -sd',' - || true)
    fi

    printf 'energy=%s\n' "$energy"
    printf 'fog=%s\n' "$fog"
    printf 'symptom_count=%s\n' "$symptom_count"
    printf 'symptoms=%s\n' "$symptoms"
}

# Prompt for optional same-run manual energy/fog logging.
# Usage: health_ops_prompt_for_manual_checkin [health_script]
health_ops_prompt_for_manual_checkin() {
    local health_script="${1:-${HEALTH_SCRIPT:-${DOTFILES_DIR:-$HOME/dotfiles}/scripts/health.sh}}"
    local log_health=""
    local energy=""
    local fog=""

    if ! [ -t 0 ] || ! [ -x "$health_script" ]; then
        return 1
    fi

    echo -n "🏥 Log Energy/Fog levels? [y/N]: "
    read -r log_health
    if [[ "$log_health" =~ ^[yY] ]]; then
        echo -n "   Energy Level (1-10): "
        read -r energy
        if validate_range "$energy" 1 10 "energy level" >/dev/null 2>&1; then
            "$health_script" energy "$energy" | sed 's/^/   /'
        elif [ -n "$energy" ]; then
            echo "   (Skipped: must be 1-10)"
        fi

        echo -n "   Brain Fog Level (1-10): "
        read -r fog
        if validate_range "$fog" 1 10 "brain fog level" >/dev/null 2>&1; then
            "$health_script" fog "$fog" | sed 's/^/   /'
        elif [ -n "$fog" ]; then
            echo "   (Skipped: must be 1-10)"
        fi
    fi

    return 0
}

# Display health summary (Appointments, Energy, Symptoms)
# Usage: show_health_summary
show_health_summary() {
    local health_file="${HEALTH_FILE:-}"
    local has_fitbit_data=false

    # If config did not tell us where the health log lives, we cannot read anything.
    if [[ -z "$health_file" ]]; then
        echo "  (health file path is not configured; source config.sh)"
        return 0
    fi

    # We allow wearable-only summaries now.
    # That means the summary can still show Fitbit data even when no manual
    # health notes were written today.
    if health_ops_has_fitbit_data; then
        has_fitbit_data=true
    fi

    if { [ ! -f "$health_file" ] || [ ! -s "$health_file" ]; } && [[ "$has_fitbit_data" != "true" ]]; then
        echo "  (no data tracked - try: health add, health energy, health symptom)"
        return 0
    fi

    # Part 1: upcoming appointments.
    # We compare each appointment day to "today" and print only today/future items.
    local today_str
    today_str=$(date_today)
    local today_epoch
    today_epoch=$(_health_parse_timestamp "$today_str")
    
    local has_data=false

    if [[ -f "$health_file" ]] && grep -q "^APPT|" "$health_file" 2>/dev/null; then
        grep "^APPT|" "$health_file" | sort -t'|' -k2 | while IFS='|' read -r type appt_date desc; do
            local appt_epoch
            appt_epoch=$(_health_parse_timestamp "$appt_date")
            
            if [ "$appt_epoch" -le 0 ]; then
                continue
            fi
            
            local diff_seconds=$(( appt_epoch - today_epoch ))
            local days_until=$(( diff_seconds / HEALTH_SECONDS_PER_DAY ))
            
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

    # Part 2: today's manual health notes like energy and symptoms.
    # We read them through a helper so the summary code stays simpler.
    local _summary _energy _symptom_count
    if [[ -f "$health_file" ]] && [[ -s "$health_file" ]]; then
        _summary=$(health_ops_get_daily_summary "$today_str")
        _energy=$(echo "$_summary" | grep '^energy=' | cut -d'=' -f2)
        _symptom_count=$(echo "$_summary" | grep '^symptom_count=' | cut -d'=' -f2)
    else
        _summary=""
        _energy=""
        _symptom_count=0
    fi

    if [[ -n "$_energy" ]]; then
        has_data=true
        echo "  Energy level: $_energy/10"
    fi

    if [[ "$_symptom_count" -gt 0 ]] 2>/dev/null; then
        has_data=true
        echo "  Symptoms logged today: $_symptom_count (run 'health list' to see)"
    fi

    # Part 3: newest wearable readings from Fitbit / Google Health.
    # These lines are printed after manual health notes so the whole summary reads
    # like "appointments, how you felt, what the watch saw."
    if health_ops_print_fitbit_snapshot; then
        has_data=true
    fi

    # If every section stayed empty, show one gentle hint instead of a blank block.
    if [ "$has_data" = "false" ]; then
         echo "  (no data tracked - try: health add, health energy, health symptom)"
    fi
}
