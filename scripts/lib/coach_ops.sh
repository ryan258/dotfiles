#!/usr/bin/env bash
# scripts/lib/coach_ops.sh
# Behavioral coaching metrics and persistence helpers.
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_COACH_OPS_LOADED:-}" ]]; then
    return 0
fi
readonly _COACH_OPS_LOADED=true

# Dependencies:
# - DATA_DIR and coach-related config values from config.sh.
# - optional helpers from common.sh/date_utils.sh (sanitize_input, validate_path, timestamp_to_epoch).
if [[ -z "${DATA_DIR:-}" ]]; then
    echo "Error: DATA_DIR is not set. Source scripts/lib/config.sh before coach_ops.sh." >&2
    return 1
fi
if [[ -z "${TODO_FILE:-}" || -z "${DONE_FILE:-}" || -z "${JOURNAL_FILE:-}" || -z "${HEALTH_FILE:-}" || -z "${SPOON_LOG:-}" || -z "${DIR_USAGE_LOG:-}" || -z "${FOCUS_HISTORY_FILE:-}" || -z "${DISPATCHER_USAGE_LOG:-}" || -z "${COACH_MODE_FILE:-}" || -z "${COACH_LOG_FILE:-}" ]]; then
    echo "Error: Coach paths are not fully configured. Source scripts/lib/config.sh before coach_ops.sh." >&2
    return 1
fi

# Drift thresholds (fixed deterministic defaults)
readonly COACH_DRIFT_STALE_THRESHOLD=4
readonly COACH_DRIFT_LOW_COMPLETION_THRESHOLD=2
readonly COACH_DRIFT_UNIQUE_DIRS_THRESHOLD=10
readonly COACH_DRIFT_SWITCHES_THRESHOLD=80
readonly COACH_LOW_ENERGY_THRESHOLD=4
readonly COACH_HIGH_FOG_THRESHOLD=6

_coach_escape_field() {
    local raw="$1"
    if command -v sanitize_input >/dev/null 2>&1; then
        raw=$(sanitize_input "$raw")
    fi
    raw="${raw//$'\r'/ }"
    raw="${raw//$'\n'/\\n}"
    raw="${raw//|/}"
    raw=$(printf '%s' "$raw" | tr -d '\000-\010\013\014\016-\037')
    printf '%s' "$raw"
}

_coach_shift_date() {
    local anchor_date="$1"
    local offset_days="$2"

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$anchor_date" "$offset_days" <<'PY'
import sys
from datetime import datetime, timedelta

anchor = datetime.strptime(sys.argv[1], "%Y-%m-%d")
offset = int(sys.argv[2])
print((anchor + timedelta(days=offset)).strftime("%Y-%m-%d"))
PY
        return
    fi

    if date -j -f "%Y-%m-%d" "$anchor_date" -v"${offset_days}"d "+%Y-%m-%d" >/dev/null 2>&1; then
        date -j -f "%Y-%m-%d" "$anchor_date" -v"${offset_days}"d "+%Y-%m-%d"
        return
    fi

    if command -v gdate >/dev/null 2>&1; then
        gdate -d "$anchor_date $offset_days day" "+%Y-%m-%d"
    else
        date -d "$anchor_date $offset_days day" "+%Y-%m-%d"
    fi
}

_coach_date_to_epoch() {
    local date_value="$1"

    if command -v timestamp_to_epoch >/dev/null 2>&1; then
        timestamp_to_epoch "$date_value"
        return
    fi

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$date_value" <<'PY'
import sys
from datetime import datetime

raw = sys.argv[1]
formats = ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d")
for fmt in formats:
    try:
        print(int(datetime.strptime(raw, fmt).timestamp()))
        break
    except ValueError:
        continue
else:
    print(0)
PY
        return
    fi

    echo "0"
}

_coach_average() {
    local sum="$1"
    local count="$2"
    if [[ -z "$count" || "$count" -eq 0 ]]; then
        echo "N/A"
        return
    fi
    awk -v s="$sum" -v c="$count" 'BEGIN { printf "%.1f", s/c }'
}

_coach_count_bullets() {
    local text="$1"
    if [[ -z "$text" ]]; then
        echo "0"
        return
    fi
    printf '%s\n' "$text" | awk '/^[[:space:]]*• / {count++} END {print count+0}'
}

_coach_extract_value() {
    local blob="$1"
    local key="$2"
    printf '%s\n' "$blob" | awk -F'=' -v k="$key" '$1 == k {print $2; exit}'
}

_coach_calc_trend() {
    local first="$1"
    local second="$2"

    if [[ "$first" -eq 0 && "$second" -eq 0 ]]; then
        echo "flat"
        return
    fi
    if [[ "$first" -eq 0 && "$second" -gt 0 ]]; then
        echo "up"
        return
    fi

    local delta
    delta=$(awk -v a="$first" -v b="$second" 'BEGIN { printf "%.3f", (b-a)/a }')
    awk -v d="$delta" 'BEGIN {
        if (d > 0.2) print "up";
        else if (d < -0.2) print "down";
        else print "flat";
    }'
}

_coach_secure_tmpfile() {
    local prefix="$1"
    local tmp_root="${TMPDIR:-/tmp}"
    local tmp_path=""
    local suffix=""

    if tmp_path=$(mktemp "${tmp_root%/}/${prefix}.XXXXXX" 2>/dev/null); then
        printf '%s' "$tmp_path"
        return 0
    fi

    if command -v python3 >/dev/null 2>&1; then
        suffix=$(python3 - <<'PY'
import uuid
print(uuid.uuid4().hex)
PY
)
    else
        suffix="$(date +%s 2>/dev/null)-$$-${RANDOM}${RANDOM}"
    fi

    tmp_path="${tmp_root%/}/${prefix}.${suffix}"
    (umask 077 && : > "$tmp_path") || return 1
    printf '%s' "$tmp_path"
}

coach_collect_tactical_metrics() {
    local anchor_date="$1"
    local days="${2:-7}"
    local pushes_context="${3:-}"
    local commits_context="${4:-}"
    local todo_file="$TODO_FILE"
    local done_file="$DONE_FILE"
    local journal_file="$JOURNAL_FILE"
    local health_file="$HEALTH_FILE"
    local spoon_file="$SPOON_LOG"
    local dir_usage_file="$DIR_USAGE_LOG"

    if [[ -z "$anchor_date" ]]; then
        anchor_date=$(date '+%Y-%m-%d')
    fi
    if ! [[ "$days" =~ ^[0-9]+$ ]] || [[ "$days" -lt 1 ]]; then
        days=7
    fi

    local window_start
    window_start=$(_coach_shift_date "$anchor_date" "-$((days-1))") || return 1

    local stale_days="${AI_COACH_DRIFT_STALE_TASK_DAYS:-${STALE_TASK_DAYS:-7}}"
    local stale_cutoff
    stale_cutoff=$(_coach_shift_date "$anchor_date" "-$stale_days") || return 1
    local window_start_epoch
    local window_end_epoch
    window_start_epoch=$(_coach_date_to_epoch "$window_start 00:00:00")
    window_end_epoch=$(_coach_date_to_epoch "$anchor_date 23:59:59")

    local open_tasks=0
    local stale_tasks=0
    local completed_tasks=0
    local journal_entries=0
    local energy_sum=0
    local energy_count=0
    local fog_sum=0
    local fog_count=0
    local spoon_budget_sum=0
    local spoon_budget_count=0
    local spoon_spend_sum=0
    local spoon_spend_count=0
    local unique_dirs=0
    local dir_switches=0

    if [[ -f "$todo_file" ]]; then
        open_tasks=$(awk -F'|' '$1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ {count++} END {print count+0}' "$todo_file")
        stale_tasks=$(awk -F'|' -v cutoff="$stale_cutoff" '$1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ && $1 < cutoff {count++} END {print count+0}' "$todo_file")
    fi

    if [[ -f "$done_file" ]]; then
        completed_tasks=$(awk -F'|' -v start="$window_start" -v end="$anchor_date" '
            $1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}$/ {
                day = substr($1, 1, 10)
                if (day >= start && day <= end) count++
            }
            END {print count+0}
        ' "$done_file")
    fi

    if [[ -f "$journal_file" ]]; then
        journal_entries=$(awk -F'|' -v start="$window_start" -v end="$anchor_date" '
            $1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}$/ {
                day = substr($1, 1, 10)
                if (day >= start && day <= end) count++
            }
            END {print count+0}
        ' "$journal_file")
    fi

    if [[ -f "$health_file" ]]; then
        read -r energy_sum energy_count <<< "$(awk -F'|' -v start="$window_start" -v end="$anchor_date" '
            $1 == "ENERGY" && $2 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/ && $3 ~ /^[0-9]+$/ {
                day = substr($2, 1, 10)
                if (day >= start && day <= end) {sum += $3; count++}
            }
            END {print sum+0, count+0}
        ' "$health_file")"

        read -r fog_sum fog_count <<< "$(awk -F'|' -v start="$window_start" -v end="$anchor_date" '
            $1 == "FOG" && $2 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/ && $3 ~ /^[0-9]+$/ {
                day = substr($2, 1, 10)
                if (day >= start && day <= end) {sum += $3; count++}
            }
            END {print sum+0, count+0}
        ' "$health_file")"
    fi

    if [[ -f "$spoon_file" ]]; then
        read -r spoon_budget_sum spoon_budget_count <<< "$(awk -F'|' -v start="$window_start" -v end="$anchor_date" '
            $1 == "BUDGET" && $2 >= start && $2 <= end && $3 ~ /^[0-9]+$/ {sum += $3; count++}
            END {print sum+0, count+0}
        ' "$spoon_file")"

        # SPEND layout: SPEND|YYYY-MM-DD|HH:MM|count|activity|remaining
        read -r spoon_spend_sum spoon_spend_count <<< "$(awk -F'|' -v start="$window_start" -v end="$anchor_date" '
            $1 == "SPEND" && $2 >= start && $2 <= end && $4 ~ /^[0-9]+$/ {sum += $4; count++}
            END {print sum+0, count+0}
        ' "$spoon_file")"
    fi

    if [[ -f "$dir_usage_file" ]]; then
        read -r unique_dirs dir_switches <<< "$(awk -F'|' -v start="$window_start_epoch" -v end="$window_end_epoch" '
            $1 ~ /^[0-9]{9,}$/ && $2 != "" && $1 >= start && $1 <= end {
                dirs[$2] = 1
                if (prev != "" && prev != $2) switches++
                prev = $2
            }
            END {
                for (d in dirs) unique++
                print unique+0, switches+0
            }
        ' "$dir_usage_file")"
    fi

    local recent_pushes_count
    local commit_context_count
    recent_pushes_count=$(_coach_count_bullets "$pushes_context")
    commit_context_count=$(_coach_count_bullets "$commits_context")

    echo "tactical_window_days=$days"
    echo "tactical_window_start=$window_start"
    echo "tactical_window_end=$anchor_date"
    echo "open_tasks=$open_tasks"
    echo "stale_tasks=$stale_tasks"
    echo "completed_tasks=$completed_tasks"
    echo "journal_entries=$journal_entries"
    echo "avg_energy=$(_coach_average "$energy_sum" "$energy_count")"
    echo "avg_fog=$(_coach_average "$fog_sum" "$fog_count")"
    echo "avg_spoon_budget=$(_coach_average "$spoon_budget_sum" "$spoon_budget_count")"
    echo "avg_spoon_spend=$(_coach_average "$spoon_spend_sum" "$spoon_spend_count")"
    echo "unique_dirs=$unique_dirs"
    echo "dir_switches=$dir_switches"
    echo "recent_pushes_count=$recent_pushes_count"
    echo "commit_context_count=$commit_context_count"
}

coach_collect_pattern_metrics() {
    local anchor_date="$1"
    local days="${2:-30}"
    local done_file="$DONE_FILE"
    local journal_file="$JOURNAL_FILE"
    local focus_history_file="$FOCUS_HISTORY_FILE"
    local dir_usage_file="$DIR_USAGE_LOG"
    local dispatcher_log_file="$DISPATCHER_USAGE_LOG"

    if [[ -z "$anchor_date" ]]; then
        anchor_date=$(date '+%Y-%m-%d')
    fi
    if ! [[ "$days" =~ ^[0-9]+$ ]] || [[ "$days" -lt 1 ]]; then
        days=30
    fi

    local window_start
    window_start=$(_coach_shift_date "$anchor_date" "-$((days-1))") || return 1
    local window_start_epoch
    local window_end_epoch
    window_start_epoch=$(_coach_date_to_epoch "$window_start 00:00:00")
    window_end_epoch=$(_coach_date_to_epoch "$anchor_date 23:59:59")

    local midpoint_offset="-$((days/2))"
    local split_date
    split_date=$(_coach_shift_date "$anchor_date" "$midpoint_offset") || return 1

    local complete_first=0
    local complete_second=0
    local journal_first=0
    local journal_second=0
    local focus_changes=0

    if [[ -f "$done_file" ]]; then
        read -r complete_first complete_second <<< "$(awk -F'|' -v start="$window_start" -v split="$split_date" -v end="$anchor_date" '
            $1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}$/ {
                day = substr($1, 1, 10)
                if (day >= start && day <= split) first++
                else if (day > split && day <= end) second++
            }
            END {print first+0, second+0}
        ' "$done_file")"
    fi

    if [[ -f "$journal_file" ]]; then
        read -r journal_first journal_second <<< "$(awk -F'|' -v start="$window_start" -v split="$split_date" -v end="$anchor_date" '
            $1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}$/ {
                day = substr($1, 1, 10)
                if (day >= start && day <= split) first++
                else if (day > split && day <= end) second++
            }
            END {print first+0, second+0}
        ' "$journal_file")"
    fi

    if [[ -f "$focus_history_file" ]]; then
        focus_changes=$(awk -F'|' -v start="$window_start" -v end="$anchor_date" '
            $1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ && $1 >= start && $1 <= end {count++}
            END {print count+0}
        ' "$focus_history_file")
    fi

    local top_dirs="(none)"
    if [[ -f "$dir_usage_file" ]]; then
        top_dirs=$(awk -F'|' -v start="$window_start_epoch" -v end="$window_end_epoch" '
            $1 ~ /^[0-9]{9,}$/ && $2 != "" && $1 >= start && $1 <= end {
                counts[$2]++
            }
            END {
                for (d in counts) printf "%s|%d\n", d, counts[d]
            }
        ' "$dir_usage_file" | sort -t'|' -k2,2nr | head -n 3 | awk -F'|' '{print $1 " (" $2 ")"}' | paste -sd ", " -)
        [[ -z "$top_dirs" ]] && top_dirs="(none)"
    fi

    local top_dispatchers="(none)"
    if [[ -f "$dispatcher_log_file" ]]; then
        top_dispatchers=$(awk -v start="$window_start" -v end="$anchor_date" '
            $0 ~ /^\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]/ {
                day = substr($0, 2, 10)
                name = ""
                if (match($0, /DISPATCHER: [^,]+/)) {
                    name = substr($0, RSTART, RLENGTH)
                    sub(/^DISPATCHER: /, "", name)
                }
                if (name != "" && day >= start && day <= end) counts[name]++
            }
            END {
                for (k in counts) printf "%s|%d\n", k, counts[k]
            }
        ' "$dispatcher_log_file" | sort -t'|' -k2,2nr | head -n 3 | awk -F'|' '{print $1 " (" $2 ")"}' | paste -sd ", " -)
        [[ -z "$top_dispatchers" ]] && top_dispatchers="(none)"
    fi

    local completion_trend
    local journal_trend
    completion_trend=$(_coach_calc_trend "$complete_first" "$complete_second")
    journal_trend=$(_coach_calc_trend "$journal_first" "$journal_second")

    local focus_changes_per_week
    focus_changes_per_week=$(awk -v c="$focus_changes" -v d="$days" 'BEGIN { printf "%.1f", c / (d / 7.0) }')

    echo "pattern_window_days=$days"
    echo "pattern_window_start=$window_start"
    echo "pattern_window_end=$anchor_date"
    echo "completion_first_half=$complete_first"
    echo "completion_second_half=$complete_second"
    echo "completion_trend=$completion_trend"
    echo "journal_first_half=$journal_first"
    echo "journal_second_half=$journal_second"
    echo "journal_trend=$journal_trend"
    echo "focus_changes=$focus_changes"
    echo "focus_changes_per_week=$focus_changes_per_week"
    echo "top_directories=$top_dirs"
    echo "top_dispatchers=$top_dispatchers"
}

coach_collect_data_quality_flags() {
    local done_file="$DONE_FILE"
    local dir_usage_file="$DIR_USAGE_LOG"
    local flags=()

    local done_malformed=0
    if [[ -f "$done_file" ]]; then
        done_malformed=$(awk -F'|' '
            NF && $0 !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}\|.+$/ {count++}
            END {print count+0}
        ' "$done_file")
        if [[ "$done_malformed" -gt 0 ]]; then
            flags+=("todo_done_malformed=$done_malformed")
        fi
    fi

    local dir_malformed=0
    if [[ -f "$dir_usage_file" ]]; then
        dir_malformed=$(awk -F'|' '
            NF && $0 !~ /^[0-9]{9,}\|.+$/ {count++}
            END {print count+0}
        ' "$dir_usage_file")
        if [[ "$dir_malformed" -gt 0 ]]; then
            flags+=("dir_usage_malformed=$dir_malformed")
        fi
    fi

    if [[ ${#flags[@]} -eq 0 ]]; then
        echo "none"
        return 0
    fi

    printf '%s\n' "${flags[@]}"
}

coach_build_behavior_digest() {
    local anchor_date="$1"
    local tactical_days="${2:-7}"
    local pattern_days="${3:-30}"

    local tactical
    local pattern
    local quality
    tactical=$(coach_collect_tactical_metrics "$anchor_date" "$tactical_days") || return 1
    pattern=$(coach_collect_pattern_metrics "$anchor_date" "$pattern_days") || return 1
    quality=$(coach_collect_data_quality_flags)

    local stale_tasks completed_tasks unique_dirs dir_switches avg_energy avg_fog
    stale_tasks=$(_coach_extract_value "$tactical" "stale_tasks")
    completed_tasks=$(_coach_extract_value "$tactical" "completed_tasks")
    unique_dirs=$(_coach_extract_value "$tactical" "unique_dirs")
    dir_switches=$(_coach_extract_value "$tactical" "dir_switches")
    avg_energy=$(_coach_extract_value "$tactical" "avg_energy")
    avg_fog=$(_coach_extract_value "$tactical" "avg_fog")

    local working_signals=()
    local drift_risks=()

    if [[ "${completed_tasks:-0}" -ge 1 ]]; then
        working_signals+=("recent task completions are present")
    fi
    if [[ "$(_coach_extract_value "$tactical" "journal_entries")" -ge 1 ]]; then
        working_signals+=("journal capture is active")
    fi
    if [[ "$(_coach_extract_value "$pattern" "completion_trend")" == "up" ]]; then
        working_signals+=("completion trend is improving")
    fi
    if [[ "$(_coach_extract_value "$pattern" "journal_trend")" == "up" ]]; then
        working_signals+=("journaling trend is improving")
    fi

    if [[ "${stale_tasks:-0}" -ge "$COACH_DRIFT_STALE_THRESHOLD" ]]; then
        drift_risks+=("stale task load is high (${stale_tasks})")
    fi
    if [[ "${completed_tasks:-0}" -lt "$COACH_DRIFT_LOW_COMPLETION_THRESHOLD" ]]; then
        drift_risks+=("recent completion volume is low (${completed_tasks})")
    fi
    if [[ "${unique_dirs:-0}" -gt "$COACH_DRIFT_UNIQUE_DIRS_THRESHOLD" ]]; then
        drift_risks+=("context switching across directories is high (${unique_dirs})")
    fi
    if [[ "${dir_switches:-0}" -gt "$COACH_DRIFT_SWITCHES_THRESHOLD" ]]; then
        drift_risks+=("directory switching frequency is very high (${dir_switches})")
    fi

    # awk exits 0 when the threshold condition is true.
    if [[ "$avg_energy" != "N/A" ]] && awk -v e="$avg_energy" -v threshold="$COACH_LOW_ENERGY_THRESHOLD" 'BEGIN { exit !(e < threshold) }'; then
        drift_risks+=("average energy is low (${avg_energy}/10)")
    fi
    if [[ "$avg_fog" != "N/A" ]] && awk -v f="$avg_fog" -v threshold="$COACH_HIGH_FOG_THRESHOLD" 'BEGIN { exit !(f >= threshold) }'; then
        drift_risks+=("average brain fog is high (${avg_fog}/10)")
    fi

    if [[ "$quality" != "none" ]]; then
        drift_risks+=("data quality flags detected")
    fi

    echo "Behavior digest (structured):"
    echo "Tactical window: ${tactical_days}d ending $anchor_date"
    echo "  open_tasks=$(_coach_extract_value "$tactical" "open_tasks"), stale_tasks=$stale_tasks, completed_tasks=$completed_tasks, journal_entries=$(_coach_extract_value "$tactical" "journal_entries")"
    echo "  avg_energy=${avg_energy}, avg_fog=${avg_fog}, avg_spoon_budget=$(_coach_extract_value "$tactical" "avg_spoon_budget"), avg_spoon_spend=$(_coach_extract_value "$tactical" "avg_spoon_spend")"
    echo "  unique_dirs=$unique_dirs, dir_switches=$dir_switches, recent_pushes=$(_coach_extract_value "$tactical" "recent_pushes_count"), commit_context=$(_coach_extract_value "$tactical" "commit_context_count")"
    echo "Pattern window: ${pattern_days}d ending $anchor_date"
    echo "  completion_trend=$(_coach_extract_value "$pattern" "completion_trend") (first=$(_coach_extract_value "$pattern" "completion_first_half"), second=$(_coach_extract_value "$pattern" "completion_second_half"))"
    echo "  journal_trend=$(_coach_extract_value "$pattern" "journal_trend") (first=$(_coach_extract_value "$pattern" "journal_first_half"), second=$(_coach_extract_value "$pattern" "journal_second_half"))"
    echo "  focus_changes=$(_coach_extract_value "$pattern" "focus_changes") (~$(_coach_extract_value "$pattern" "focus_changes_per_week")/week)"
    echo "  top_directories=$(_coach_extract_value "$pattern" "top_directories")"
    echo "  top_dispatchers=$(_coach_extract_value "$pattern" "top_dispatchers")"
    echo "Working signals:"
    if [[ ${#working_signals[@]} -eq 0 ]]; then
        echo "  - none detected"
    else
        printf '  - %s\n' "${working_signals[@]}"
    fi
    echo "Drift risks:"
    if [[ ${#drift_risks[@]} -eq 0 ]]; then
        echo "  - none detected"
    else
        printf '  - %s\n' "${drift_risks[@]}"
    fi
    echo "Data quality flags:"
    if [[ "$quality" == "none" ]]; then
        echo "  - none"
    else
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            echo "  - $line"
        done <<< "$quality"
    fi
}

coach_call_with_timeout() {
    local prompt="$1"
    local timeout_seconds="${2:-${AI_COACH_REQUEST_TIMEOUT_SECONDS:-35}}"
    shift 2

    if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || [[ "$timeout_seconds" -lt 1 ]]; then
        timeout_seconds=35
    fi
    if [[ "$#" -eq 0 ]]; then
        return 2
    fi

    if command -v python3 >/dev/null 2>&1; then
        local python_output=""
        local python_status=0
        python_output=$(python3 - "$prompt" "$timeout_seconds" "$@" <<'PY'
import subprocess
import sys

prompt = sys.argv[1]
timeout_seconds = int(sys.argv[2])
command = sys.argv[3:]

try:
    result = subprocess.run(
        command,
        input=prompt,
        text=True,
        capture_output=True,
        timeout=timeout_seconds,
    )
except subprocess.TimeoutExpired as exc:
    if exc.stdout:
        sys.stdout.write(exc.stdout)
    sys.stderr.write(
        f"coach_call_with_timeout: timed out after {timeout_seconds} seconds\n"
    )
    sys.exit(124)

if result.stdout:
    sys.stdout.write(result.stdout)

if result.returncode != 0:
    if result.stderr:
        sys.stderr.write(result.stderr)
    sys.exit(result.returncode)
PY
)
        python_status=$?
        printf '%s' "$python_output"
        return "$python_status"
    fi

    local prompt_file=""
    local output_file=""
    local error_file=""
    local child_pid=0
    local elapsed=0
    local child_status=0

    prompt_file=$(_coach_secure_tmpfile "coach_prompt") || return 1
    output_file=$(_coach_secure_tmpfile "coach_out") || {
        rm -f "$prompt_file"
        return 1
    }
    error_file=$(_coach_secure_tmpfile "coach_err") || {
        rm -f "$prompt_file" "$output_file"
        return 1
    }

    printf '%s' "$prompt" > "$prompt_file"
    "$@" < "$prompt_file" > "$output_file" 2> "$error_file" &
    child_pid=$!

    while kill -0 "$child_pid" 2>/dev/null; do
        if [[ "$elapsed" -ge "$timeout_seconds" ]]; then
            kill "$child_pid" 2>/dev/null || true
            sleep 1
            kill -9 "$child_pid" 2>/dev/null || true
            wait "$child_pid" 2>/dev/null || true
            cat "$output_file"
            rm -f "$prompt_file" "$output_file" "$error_file"
            return 124
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    wait "$child_pid" || child_status=$?
    cat "$output_file"
    if [[ "$child_status" -ne 0 && -s "$error_file" ]]; then
        cat "$error_file" >&2
    fi

    rm -f "$prompt_file" "$output_file" "$error_file"
    return "$child_status"
}

coach_strategy_with_timeout() {
    local prompt="$1"
    local temperature="${2:-0.25}"
    local timeout_seconds="${3:-${AI_COACH_REQUEST_TIMEOUT_SECONDS:-35}}"

    coach_call_with_timeout "$prompt" "$timeout_seconds" dhp-strategy.sh --temperature "$temperature"
}

coach_strategy_with_retry() {
    local prompt="$1"
    local temperature="${2:-0.25}"
    local timeout_seconds="${3:-${AI_COACH_REQUEST_TIMEOUT_SECONDS:-35}}"
    local retry_timeout_seconds="${4:-${AI_COACH_RETRY_TIMEOUT_SECONDS:-90}}"
    local retry_enabled="${AI_COACH_RETRY_ON_TIMEOUT:-true}"

    local first_status=0
    local second_status=0
    local first_output=""
    local second_output=""

    if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || [[ "$timeout_seconds" -lt 1 ]]; then
        timeout_seconds=35
    fi
    if ! [[ "$retry_timeout_seconds" =~ ^[0-9]+$ ]] || [[ "$retry_timeout_seconds" -lt 1 ]]; then
        retry_timeout_seconds=90
    fi

    first_output=$(coach_strategy_with_timeout "$prompt" "$temperature" "$timeout_seconds")
    first_status=$?
    if [[ "$first_status" -eq 0 ]]; then
        printf '%s' "$first_output"
        return 0
    fi

    if [[ "$first_status" -ne 124 ]]; then
        return "$first_status"
    fi
    if [[ "$retry_enabled" != "true" ]]; then
        return "$first_status"
    fi
    if [[ "$retry_timeout_seconds" -le "$timeout_seconds" ]]; then
        return "$first_status"
    fi

    second_output=$(coach_strategy_with_timeout "$prompt" "$temperature" "$retry_timeout_seconds")
    second_status=$?
    if [[ "$second_status" -eq 0 ]]; then
        printf '%s' "$second_output"
        return 0
    fi
    return "$second_status"
}

coach_build_startday_prompt() {
    local focus_context="$1"
    local coach_mode="$2"
    local yesterday_commits="$3"
    local recent_pushes="$4"
    local recent_journal="$5"
    local yesterday_journal_context="$6"
    local today_tasks="$7"
    local behavior_digest="$8"

    cat <<EOF
Produce a high-signal morning execution guide for a user with brain fog.
Prioritize clarity, momentum, anti-tinkering boundaries, and health-aware pacing.
Use the provided behavior digest as ground truth for what is working vs drift.

Today's focus:
${focus_context:-"(no focus set)"}

Coach mode for today:
${coach_mode:-LOCKED}

Yesterday's commits:
${yesterday_commits:-"(none)"}

Recent GitHub pushes (last 7 days):
${recent_pushes:-"(none)"}

Recent journal entries:
${recent_journal:-"(none)"}

Yesterday's journal entries:
${yesterday_journal_context:-"(none)"}

Top tasks:
${today_tasks:-"(none)"}

Behavior digest:
${behavior_digest:-"(none)"}

Coach mode semantics:
- LOCKED: no side quests until done condition is met.
- OVERRIDE: allow one bounded exploration block, then return to locked plan.

Action-source rules:
- Use Today's focus and Top tasks as the ONLY source for Do Next actions.
- Yesterday commits, pushes, and journal are momentum context only (for Operating insight/Evidence check), not action selection.
- If focus and top tasks are misaligned, Do Next step 1 must be to reconcile task order/scope in the todo list.

Output format (strict, no extra sections):
North Star:
- One sentence practical outcome for today.
Do Next (ordered 1-3):
1. First 10-15 minute action mapped directly to focus/top task text.
2. Second action after step 1.
3. Done condition for today.
Operating insight (working + drift risk):
- One line naming what is working and one drift risk from digest metrics.
Anti-tinker rule:
- One explicit boundary rule for this mode.
Health lens:
- Always include energy/fog/spoon-aware pacing guidance.
Evidence check:
- One line naming exact commits/tasks/journal/metrics cues used.

Constraints:
- Total 120-190 words.
- No markdown headers, bold text, separators, or concluding paragraph.
- Keep language operational and specific; avoid generic motivation.
- If signal is missing, say so briefly instead of inventing details.
- Do Next must be grounded in today's focus and listed top tasks.
- Do not invent new repositories, modules, endpoints, files, APIs, or projects unless those exact items appear in today's focus or top tasks.
- If focus and top tasks conflict, step 1 must reconcile them (for example: update top task order or capture a scoped task), not invent a new implementation track.
- Evidence check must only cite cues that are explicitly present in the provided context.
- Do Next must not reference commit hashes, repo names from push history, or journal-only details.
EOF
}

coach_build_goodevening_prompt() {
    local coach_mode="$1"
    local focus_context="$2"
    local today_commits="$3"
    local recent_pushes="$4"
    local today_tasks="$5"
    local today_journal="$6"
    local behavior_digest="$7"

    cat <<EOF
Produce a reflective daily coaching summary for a user managing brain fog and fatigue.
Use the behavior digest and today's evidence to identify what worked, where drift happened, and how to lock tomorrow.
Always include health/energy context.

Coach mode used today:
${coach_mode:-LOCKED}

Today's focus:
${focus_context:-"(no focus set)"}

Today's commits:
${today_commits:-"(none)"}

Recent GitHub pushes (last 7 days):
${recent_pushes:-"(none)"}

Completed tasks today:
${today_tasks:-"(none)"}

Today's journal entries:
${today_journal:-"(none)"}

Behavior digest:
${behavior_digest:-"(none)"}

Output format (strict, no extra sections):
What worked:
- 1-2 lines anchored to concrete evidence.
Where drift happened:
- 1-2 lines on off-rails patterns or distraction loops.
Likely trigger:
- One probable trigger for drift based on evidence.
Tomorrow lock:
- One locked first move, one done condition, and one anti-tinker boundary.
Health lens:
- Always include energy/fog/spoon-aware pacing guidance.
Evidence used:
- One line naming exact commits/tasks/journal/metrics cues used.

Constraints:
- Total 140-240 words.
- Reflective summary tone, operationally useful.
- No markdown headers, bold text, separators, or concluding paragraph.
- If data is sparse, say so briefly instead of inventing details.
EOF
}

_coach_extract_first_task() {
    local task_blob="$1"
    local cleaned=""

    cleaned=$(printf '%s\n' "$task_blob" | awk '
        function trim(value) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            return value
        }
        NF {
            line = trim($0)
            if (line == "") {
                next
            }
            if (line ~ /^-+[[:space:]]*Top[[:space:]]+[0-9]+[[:space:]]+Tasks[[:space:]]*-+$/) {
                next
            }
            if (line ~ /^Top[[:space:]]+[0-9]+[[:space:]]+Tasks$/) {
                next
            }
            if (line ~ /^\(No tasks/) {
                next
            }
            if (line ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}\|/) {
                sub(/^[0-9]{4}-[0-9]{2}-[0-9]{2}\|/, "", line)
            }
            if (line ~ /^[0-9]+[[:space:]]+[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]+/) {
                sub(/^[[:space:]]*[0-9]+[[:space:]]+[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]+/, "", line)
            } else {
                sub(/^[[:space:]]*[0-9]+[.)][[:space:]]+/, "", line)
                sub(/^[[:space:]]*[0-9]+[[:space:]]+/, "", line)
                sub(/^[[:space:]]*[•-][[:space:]]*/, "", line)
            }
            line = trim(line)
            if (line != "") {
                print line
                exit
            }
        }
    ')
    if [[ -z "$cleaned" ]]; then
        cleaned="the first listed top task"
    fi
    printf '%s' "$cleaned"
}

_coach_line_has_context_overlap() {
    local line="$1"
    local context="$2"
    local token=""

    while IFS= read -r token; do
        [[ -z "$token" ]] && continue
        case "$token" in
            a|an|the|and|or|to|of|in|on|at|with|from|for|that|this|it|is|are|be|as|by|if|then|after|before|into|your|you|today|tomorrow|first|second|third|one|two|three|task|tasks|step|steps|done|condition|minute|minutes|block)
                continue
                ;;
        esac
        [[ "${#token}" -lt 4 ]] && continue
        if [[ "$context" == *"$token"* ]]; then
            return 0
        fi
    done < <(printf '%s' "$line" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '\n')

    return 1
}

_coach_line_has_ungrounded_scope_expansion() {
    local line="$1"
    local context="$2"
    local risky=""

    for risky in folder endpoint repository repo clone api manifest module database server scaffold microservice; do
        if [[ "$line" == *"$risky"* ]] && [[ "$context" != *"$risky"* ]]; then
            return 0
        fi
    done
    return 1
}

coach_startday_response_is_grounded() {
    local response="$1"
    local focus="$2"
    local tasks="$3"
    local context=""
    local do_next_lines=""
    local first_line=""
    local line=""
    local count=0

    context=$(printf '%s\n%s\n' "$focus" "$tasks" | tr '[:upper:]' '[:lower:]')
    do_next_lines=$(printf '%s\n' "$response" | awk '
        BEGIN { in_do_next = 0 }
        /^Do Next \(ordered 1-3\):[[:space:]]*$/ { in_do_next = 1; next }
        in_do_next && /^[[:space:]]*[1-3]\.[[:space:]]+/ { print; next }
        in_do_next && /^[[:space:]]*[A-Za-z][^:]*:[[:space:]]*$/ { in_do_next = 0 }
    ')

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        count=$((count + 1))
        line=$(printf '%s' "$line" | sed -E 's/^[[:space:]]*[1-3]\.[[:space:]]+//')
        line=$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]')
        if _coach_line_has_ungrounded_scope_expansion "$line" "$context"; then
            return 1
        fi
        if [[ "$count" -eq 1 ]]; then
            first_line="$line"
        fi
    done <<< "$do_next_lines"

    if [[ "$count" -lt 3 ]]; then
        return 1
    fi
    if ! _coach_line_has_context_overlap "$first_line" "$context"; then
        return 1
    fi
    return 0
}

coach_startday_fallback_output() {
    local focus="$1"
    local mode="$2"
    local top_tasks="$3"
    local reason="${4:-unavailable}"
    local first_task=""
    local mode_upper=""
    local anti_tinker_rule=""

    first_task=$(_coach_extract_first_task "$top_tasks")
    mode_upper=$(printf '%s' "$mode" | tr '[:lower:]' '[:upper:]')
    if [[ "$mode_upper" == "OVERRIDE" ]]; then
        anti_tinker_rule="Allow one 15-minute exploration slot only after Step 1, then return to the locked plan."
    else
        anti_tinker_rule="No side-quest work until Step 3 is complete and logged."
    fi

    cat <<EOF
North Star:
- Ship one concrete action aligned to today's focus: ${focus:-"(no focus set)"}.
Do Next (ordered 1-3):
1. Spend 10-15 minutes starting: $first_task.
2. Complete one additional short block on the same task before switching contexts.
3. Done condition: log completion/progress in todo or journal for today.
Operating insight (working + drift risk):
- Working: focus and top tasks are available. Drift risk: AI response ${reason}, so keep scope locked to listed work.
Anti-tinker rule:
- ${anti_tinker_rule}
Health lens:
- Use short blocks with a break; pause if energy drops under 4 or fog rises above 6.
Evidence check:
- Deterministic fallback (${reason}) using focus, top tasks, and behavioral digest metrics.
EOF
}

coach_goodevening_fallback_output() {
    local focus="$1"
    local mode="$2"
    local reason="${3:-unavailable}"
    local mode_upper=""
    local tomorrow_boundary=""

    mode_upper=$(printf '%s' "$mode" | tr '[:lower:]' '[:upper:]')
    if [[ "$mode_upper" == "OVERRIDE" ]]; then
        tomorrow_boundary="One bounded exploration block is allowed only after the first locked task block completes."
    else
        tomorrow_boundary="No side quests before the first locked task block is completed and logged."
    fi

    cat <<EOF
What worked:
- You captured end-of-day context (focus/tasks/journal), which preserves continuity for tomorrow.
Where drift happened:
- AI reflection was ${reason}, so drift diagnosis is partial and must stay conservative.
Likely trigger:
- Context switching without a hard stop condition late in the day.
Tomorrow lock:
- First move: start with the top task aligned to focus (${focus:-"(no focus set)"}).
- Done condition: complete one focused 10-15 minute block and log progress.
- Anti-tinker boundary: ${tomorrow_boundary}
Health lens:
- Keep work in short blocks with recovery breaks and stop if energy/fog thresholds are crossed.
Evidence used:
- Deterministic fallback (${reason}) using today's focus, completed tasks, journal entries, and behavioral digest metrics.
EOF
}

coach_get_mode_for_date() {
    local target_date="$1"
    local interactive="${2:-false}"
    local mode_file="$COACH_MODE_FILE"
    local mode=""
    local source_tag=""
    local mode_dir=""

    if command -v validate_path >/dev/null 2>&1; then
        local validated_mode_file=""
        validated_mode_file=$(validate_path "$mode_file" 2>/dev/null) || return 1
        mode_file="$validated_mode_file"
    fi

    mode_dir=$(dirname "$mode_file")
    mkdir -p "$mode_dir"
    touch "$mode_file" 2>/dev/null || return 1

    mode=$(awk -F'|' -v day="$target_date" '$1 == day && ($2 == "LOCKED" || $2 == "OVERRIDE") {m=$2} END {print m}' "$mode_file")
    if [[ -n "$mode" ]]; then
        echo "$mode"
        return 0
    fi

    local default_mode="${AI_COACH_MODE_DEFAULT:-LOCKED}"
    default_mode=$(printf '%s' "$default_mode" | tr '[:lower:]' '[:upper:]')
    if [[ "$default_mode" != "LOCKED" && "$default_mode" != "OVERRIDE" ]]; then
        default_mode="LOCKED"
    fi

    mode="$default_mode"
    source_tag="default"

    if [[ "$interactive" == "true" && -r /dev/tty ]]; then
        local allow_override=""
        printf "🧭 Focus lock: allow one exploration slot today? [y/N]: " > /dev/tty
        if read -r -t 20 allow_override < /dev/tty; then
            if [[ "$allow_override" =~ ^[yY]$ ]]; then
                mode="OVERRIDE"
            else
                mode="LOCKED"
            fi
            source_tag="prompt"
        else
            mode="LOCKED"
            source_tag="prompt-timeout"
        fi
        printf "\n" > /dev/tty
    elif [[ "$interactive" == "true" ]]; then
        source_tag="non-tty-default"
    fi

    printf '%s|%s|%s\n' "$target_date" "$mode" "$source_tag" >> "$mode_file"
    echo "$mode"
}

coach_append_log() {
    local log_type="$1"
    local date_value="$2"
    local mode="$3"
    local focus="$4"
    local metrics="$5"
    local output="$6"

    if [[ "${AI_COACH_LOG_ENABLED:-true}" != "true" ]]; then
        return 0
    fi

    local log_file="$COACH_LOG_FILE"
    local ts
    local log_dir
    ts=$(date '+%Y-%m-%d %H:%M:%S')

    if command -v validate_path >/dev/null 2>&1; then
        local validated_log_file=""
        validated_log_file=$(validate_path "$log_file" 2>/dev/null) || return 1
        log_file="$validated_log_file"
    fi

    log_dir=$(dirname "$log_file")
    mkdir -p "$log_dir"
    touch "$log_file" 2>/dev/null || return 1
    chmod 600 "$log_file" 2>/dev/null || true

    printf '%s|%s|%s|%s|%s|%s|%s\n' \
        "$(_coach_escape_field "$log_type")" \
        "$(_coach_escape_field "$ts")" \
        "$(_coach_escape_field "$date_value")" \
        "$(_coach_escape_field "$mode")" \
        "$(_coach_escape_field "$focus")" \
        "$(_coach_escape_field "$metrics")" \
        "$(_coach_escape_field "$output")" >> "$log_file"
}
