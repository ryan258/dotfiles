#!/usr/bin/env bash
# scripts/lib/coach_metrics.sh
# Data collection and metrics computation for behavioral coaching.
# NOTE: SOURCED file. Do NOT use set -euo pipefail.
#
# Dependencies:
# - DATA_DIR and coach-related config values from config.sh.
# - date helpers from date_utils.sh (date_shift_from, timestamp_to_epoch).
# - optional helpers from common.sh (sanitize_input).

if [[ -n "${_COACH_METRICS_LOADED:-}" ]]; then
    return 0
fi
readonly _COACH_METRICS_LOADED=true

# Drift thresholds (fixed deterministic defaults)
readonly COACH_DRIFT_STALE_THRESHOLD=4
readonly COACH_DRIFT_LOW_COMPLETION_THRESHOLD=2
readonly COACH_DRIFT_UNIQUE_DIRS_THRESHOLD=10
readonly COACH_DRIFT_SWITCHES_THRESHOLD=80
readonly COACH_LOW_ENERGY_THRESHOLD=4
readonly COACH_HIGH_FOG_THRESHOLD=6
readonly COACH_TREND_DELTA_THRESHOLD=0.2

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
    date_shift_from "$anchor_date" "$offset_days" "%Y-%m-%d"
}

_coach_date_to_epoch() {
    local date_value="$1"
    timestamp_to_epoch "$date_value"
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
    awk -v d="$delta" -v t="$COACH_TREND_DELTA_THRESHOLD" 'BEGIN {
        if (d > t) print "up";
        else if (d < -t) print "down";
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
