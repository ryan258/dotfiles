#!/usr/bin/env bash
# scripts/lib/coach_metrics.sh
# Data collection and metrics computation for behavioral coaching.
# NOTE: SOURCED file. Do NOT use set -euo pipefail.
#
# Dependencies:
# - config.sh: DATA_DIR, coach-related config values, and COACH_*_THRESHOLD vars.
# - date helpers from date_utils.sh (date_shift_from, timestamp_to_epoch).
# - optional helpers from common.sh (sanitize_input).

if [[ -n "${_COACH_METRICS_LOADED:-}" ]]; then
    return 0
fi
readonly _COACH_METRICS_LOADED=true

# Drift & health thresholds are provided by config.sh (COACH_*_THRESHOLD vars).
# Callers must source config.sh before this file.

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

_coach_focus_keywords() {
    local text="$1"
    # Use a stricter 4-character floor here than focus_coherence's 3-character floor.
    # Git commit text is noisier than task text, so this reduces false matches on short tokens.
    printf '%s' "$text" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '\n' | awk '
        length >= 4 {
            if ($0 ~ /^(about|after|align|around|before|build|built|core|declared|daily|done|focus|from|into|main|make|move|moving|only|primary|project|projects|repo|repos|ship|shipping|spear|task|tasks|that|this|through|today|tomorrow|work|working|yesterday)$/) {
                next
            }
            print
        }
    ' | sort -u
}

_coach_text_matches_keywords() {
    local text="$1"
    local keywords="$2"
    local keyword=""
    local lowered

    lowered=$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')
    while IFS= read -r keyword; do
        [[ -z "$keyword" ]] && continue
        if [[ "$lowered" == *"$keyword"* ]]; then
            return 0
        fi
    done <<< "$keywords"

    return 1
}

_coach_repo_from_activity_line() {
    local line="$1"
    printf '%s\n' "$line" | awk '
        function trim(value) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            return value
        }
        {
            raw = $0
            sub(/^[[:space:]]*•[[:space:]]*/, "", raw)
            repo = raw
            if (repo ~ /: /) {
                sub(/:.*/, "", repo)
            } else if (repo ~ / \(pushed /) {
                sub(/ \(pushed .*/, "", repo)
            }
            print trim(repo)
        }
    '
}

_coach_commit_message_from_activity_line() {
    local line="$1"
    printf '%s\n' "$line" | awk '
        function trim(value) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            return value
        }
        {
            raw = $0
            sub(/^[[:space:]]*•[[:space:]]*/, "", raw)
            if (raw ~ /: /) {
                sub(/^[^:]+:[[:space:]]*/, "", raw)
                sub(/[[:space:]]+\([0-9a-f]{7}\)$/, "", raw)
                print trim(raw)
            }
        }
    '
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
        # Ensure file is in new ID|DATE|text format before reading
        if type ensure_todo_migrated >/dev/null 2>&1; then
            ensure_todo_migrated
        fi
        open_tasks=$(awk -F'|' '$2 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ {count++} END {print count+0}' "$todo_file")
        stale_tasks=$(awk -F'|' -v cutoff="$stale_cutoff" '$2 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ && $2 < cutoff {count++} END {print count+0}' "$todo_file")
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
        read -r energy_sum energy_count afternoon_slumps <<< "$(awk -F'|' -v start="$window_start" -v end="$anchor_date" -v threshold="${COACH_LOW_ENERGY_THRESHOLD:-4}" '
            $1 == "ENERGY" && $2 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/ && $3 ~ /^[0-9]+$/ {
                day = substr($2, 1, 10)
                if (day >= start && day <= end) {
                    sum += $3; count++
                    if (length($2) >= 13) {
                        hour = substr($2, 12, 2) + 0
                        if (hour >= 14 && $3 <= threshold) slumps++
                    }
                }
            }
            END {print sum+0, count+0, slumps+0}
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
    local slump_bool="false"
    if [[ "${afternoon_slumps:-0}" -gt 0 ]]; then slump_bool="true"; fi
    echo "afternoon_slump=$slump_bool"
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
        read -r complete_first complete_second <<< "$(awk -F'|' -v start="$window_start" -v mid="$split_date" -v end="$anchor_date" '
            $1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}$/ {
                day = substr($1, 1, 10)
                if (day >= start && day <= mid) first++
                else if (day > mid && day <= end) second++
            }
            END {print first+0, second+0}
        ' "$done_file")"
    fi

    if [[ -f "$journal_file" ]]; then
        read -r journal_first journal_second <<< "$(awk -F'|' -v start="$window_start" -v mid="$split_date" -v end="$anchor_date" '
            $1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}$/ {
                day = substr($1, 1, 10)
                if (day >= start && day <= mid) first++
                else if (day > mid && day <= end) second++
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

# Compute focus-vs-Git evidence using commit messages and non-fork repo activity.
# Usage: coach_focus_git_signal <focus_text> <recent_pushes> <commit_context>
# Output: key=value lines describing primary repo, repo concentration, and coherence.
coach_focus_git_signal() {
    local focus_text="$1"
    local recent_pushes="${2:-}"
    local commit_context="${3:-}"
    local keywords=""
    local repo_weights=""
    local push_lines=""
    local commit_lines=""
    local line=""
    local repo=""
    local message=""
    local repo_count="0"
    local primary_repo="N/A"
    local primary_repo_weight="0"
    local primary_repo_share="N/A"
    local commit_total="0"
    local commit_matches="0"
    local commit_coherence="N/A"
    local repo_event_total="0"
    local status="no-git-evidence"
    local reason="no non-fork GitHub activity available"
    local high_threshold="${COACH_FOCUS_GIT_HIGH_THRESHOLD:-60}"
    local low_threshold="${COACH_FOCUS_GIT_LOW_THRESHOLD:-40}"
    local repo_drift_threshold="${COACH_FOCUS_ACTIVE_REPO_DRIFT_THRESHOLD:-2}"
    local repo_share_threshold="${COACH_FOCUS_PRIMARY_REPO_SHARE_THRESHOLD:-60}"

    if [[ -z "$focus_text" ]]; then
        echo "focus_git_primary_repo=N/A"
        echo "focus_git_primary_repo_share=N/A"
        echo "focus_git_repo_count=0"
        echo "focus_git_commit_total=0"
        echo "focus_git_commit_matches=0"
        echo "focus_git_commit_coherence=N/A"
        echo "focus_git_status=no-focus"
        echo "focus_git_reason=no daily focus set"
        return 0
    fi

    keywords=$(_coach_focus_keywords "$focus_text")

    commit_lines=$(printf '%s\n' "$commit_context" | awk '/^[[:space:]]*• /')
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        repo=$(_coach_repo_from_activity_line "$line")
        message=$(_coach_commit_message_from_activity_line "$line")
        if [[ -n "$repo" ]]; then
            # Commits count double here on purpose: commit-level evidence should outweigh push cadence
            # when determining the day's primary repo.
            repo_weights="${repo_weights}${repo_weights:+$'\n'}${repo}"
            repo_weights="${repo_weights}${repo_weights:+$'\n'}${repo}"
        fi
        if [[ -n "$message" ]]; then
            commit_total=$((commit_total + 1))
            if [[ -n "$keywords" ]] && _coach_text_matches_keywords "$message" "$keywords"; then
                commit_matches=$((commit_matches + 1))
            fi
        fi
    done <<< "$commit_lines"

    push_lines=$(printf '%s\n' "$recent_pushes" | awk '/^[[:space:]]*• /')
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        repo=$(_coach_repo_from_activity_line "$line")
        if [[ -n "$repo" ]]; then
            repo_weights="${repo_weights}${repo_weights:+$'\n'}${repo}"
        fi
    done <<< "$push_lines"

    if [[ -n "$repo_weights" ]]; then
        repo_event_total=$(printf '%s\n' "$repo_weights" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')
        repo_count=$(printf '%s\n' "$repo_weights" | sed '/^[[:space:]]*$/d' | sort -u | wc -l | tr -d ' ')
        primary_repo=$(printf '%s\n' "$repo_weights" | sed '/^[[:space:]]*$/d' | sort | uniq -c | sort -nr | head -n 1 | awk '{count=$1; $1=""; sub(/^[[:space:]]+/, "", $0); print $0}')
        primary_repo_weight=$(printf '%s\n' "$repo_weights" | sed '/^[[:space:]]*$/d' | sort | uniq -c | sort -nr | head -n 1 | awk '{print $1+0}')
        if [[ "${repo_event_total:-0}" -gt 0 ]]; then
            primary_repo_share=$(awk -v p="$primary_repo_weight" -v t="$repo_event_total" 'BEGIN { printf "%d", (p/t)*100 }')
        fi
    fi

    if [[ "${commit_total:-0}" -gt 0 ]]; then
        commit_coherence=$(awk -v m="$commit_matches" -v t="$commit_total" 'BEGIN { printf "%d", (m/t)*100 }')
    fi

    local git_signal_unavailable="false"
    if [[ "$recent_pushes" == *"GitHub signal unavailable"* ]] || [[ "$commit_context" == *"GitHub signal unavailable"* ]]; then
        git_signal_unavailable="true"
    fi

    if [[ "$git_signal_unavailable" == "true" ]]; then
        status="git-unavailable"
        reason="GitHub signal unavailable; unable to evaluate focus against non-fork activity"
    elif [[ "${repo_event_total:-0}" -eq 0 ]]; then
        status="no-git-evidence"
        reason="no non-fork GitHub activity available"
    elif [[ "$commit_coherence" == "N/A" ]]; then
        if [[ "${repo_count:-0}" -le 1 ]] && [[ "${primary_repo_share:-0}" =~ ^[0-9]+$ ]] && [[ "${primary_repo_share:-0}" -ge "$repo_share_threshold" ]]; then
            status="repo-locked"
            reason="recent GitHub activity is concentrated in ${primary_repo} (${primary_repo_share}% of observed repo activity)"
        else
            status="diffuse"
            reason="recent GitHub activity is spread across ${repo_count} repos without commit-level evidence"
        fi
    elif [[ "$commit_coherence" -ge "$high_threshold" ]] && [[ "${primary_repo_share:-0}" =~ ^[0-9]+$ ]] && [[ "${primary_repo_share:-0}" -ge "$repo_share_threshold" ]] && [[ "${repo_count:-0}" -le "$repo_drift_threshold" ]]; then
        status="aligned"
        reason="${commit_matches}/${commit_total} commit cues match focus; primary repo ${primary_repo} holds ${primary_repo_share}% of observed activity"
    elif [[ "$commit_coherence" -lt "$low_threshold" ]] || [[ "${repo_count:-0}" -gt "$repo_drift_threshold" ]]; then
        status="diffuse"
        reason="${commit_matches}/${commit_total} commit cues match focus; activity spans ${repo_count} repos"
    else
        status="mixed"
        reason="${commit_matches}/${commit_total} commit cues match focus; primary repo ${primary_repo} holds ${primary_repo_share}% of observed activity"
    fi

    echo "focus_git_primary_repo=${primary_repo:-N/A}"
    echo "focus_git_primary_repo_share=${primary_repo_share:-N/A}"
    echo "focus_git_repo_count=${repo_count:-0}"
    echo "focus_git_commit_total=${commit_total:-0}"
    echo "focus_git_commit_matches=${commit_matches:-0}"
    echo "focus_git_commit_coherence=${commit_coherence:-N/A}"
    echo "focus_git_status=${status}"
    echo "focus_git_reason=${reason}"
}

# Compute focus coherence: % of completed tasks aligned with today's focus
# Usage: coach_focus_coherence <focus_text> <anchor_date> [include_commits]
# Output: key=value lines (focus_coherence_pct, focus_coherence_detail)
coach_focus_coherence() {
    local focus_text="$1"
    local anchor_date="$2"
    local include_commits="${3:-true}"
    local done_file="$DONE_FILE"

    if [[ -z "$focus_text" ]]; then
        echo "focus_coherence_pct=N/A"
        echo "focus_coherence_detail=no focus set"
        return 0
    fi

    # Tokenize focus into keywords (lowercase, drop words < 3 chars)
    local keywords
    keywords=$(printf '%s' "$focus_text" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '\n' | awk 'length >= 3' | sort -u)

    if [[ -z "$keywords" ]]; then
        echo "focus_coherence_pct=N/A"
        echo "focus_coherence_detail=no usable keywords in focus"
        return 0
    fi

    # Gather completed tasks for anchor_date
    local tasks=""
    if [[ -f "$done_file" ]]; then
        tasks=$(awk -F'|' -v day="$anchor_date" '
            substr($1, 1, 10) == day { print tolower($2) }
        ' "$done_file")
    fi

    # Gather commit messages for anchor_date (best-effort from common repos)
    # Can be disabled for low-latency call sites (for example status.sh).
    local commits=""
    local projects_dir="${PROJECTS_DIR:-$HOME/Projects}"
    if [[ "$include_commits" == "true" ]] && command -v git >/dev/null 2>&1; then
        local repo_dir
        for repo_dir in "$HOME/dotfiles" "$projects_dir"/*; do
            if [[ -d "$repo_dir/.git" ]]; then
                local repo_commits
                repo_commits=$(git -C "$repo_dir" log --format='%s' \
                    --after="$anchor_date 00:00:00" --before="$anchor_date 23:59:59" 2>/dev/null || true)
                if [[ -n "$repo_commits" ]]; then
                    commits="${commits}${commits:+$'\n'}$(printf '%s' "$repo_commits" | tr '[:upper:]' '[:lower:]')"
                fi
            fi
        done
    fi

    local all_items="${tasks}${tasks:+$'\n'}${commits}"
    all_items=$(printf '%s\n' "$all_items" | sed '/^[[:space:]]*$/d')

    if [[ -z "$all_items" ]]; then
        echo "focus_coherence_pct=N/A"
        if [[ "$include_commits" == "true" ]]; then
            echo "focus_coherence_detail=no tasks or commits"
        else
            echo "focus_coherence_detail=no tasks"
        fi
        return 0
    fi

    local total=0
    local aligned=0
    while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        total=$((total + 1))
        local kw
        while IFS= read -r kw; do
            if printf '%s' "$item" | grep -qi "$kw" 2>/dev/null; then
                aligned=$((aligned + 1))
                break
            fi
        done <<< "$keywords"
    done <<< "$all_items"

    if [[ "$total" -eq 0 ]]; then
        echo "focus_coherence_pct=N/A"
        echo "focus_coherence_detail=no items"
        return 0
    fi

    local pct
    pct=$(awk -v a="$aligned" -v t="$total" 'BEGIN { printf "%d", (a/t)*100 }')
    echo "focus_coherence_pct=$pct"
    echo "focus_coherence_detail=${aligned}/${total} items aligned"
}

# Compute 3-day energy trajectory from HEALTH_FILE
# Usage: coach_energy_trajectory <anchor_date>
# Output: key=value lines (energy_3d_trajectory, energy_3d_direction)
coach_energy_trajectory() {
    local anchor_date="$1"
    local health_file="$HEALTH_FILE"

    if [[ ! -f "$health_file" ]]; then
        echo "energy_3d_trajectory=N/A"
        echo "energy_3d_direction=N/A"
        return 0
    fi

    local readings=()
    local i
    for i in 2 1 0; do
        local day
        day=$(_coach_shift_date "$anchor_date" "-$i") || continue
        # Get last ENERGY reading for that day
        local reading
        reading=$(awk -F'|' -v d="$day" '
            $1 == "ENERGY" && substr($2, 1, 10) == d && $3 ~ /^[0-9]+$/ { val = $3 }
            END { if (val != "") print val }
        ' "$health_file")
        readings+=("${reading:-}")
    done

    # Need at least 2 of 3 days with data
    local filled=0
    local vals=()
    for r in "${readings[@]}"; do
        if [[ -n "$r" ]]; then
            filled=$((filled + 1))
            vals+=("$r")
        fi
    done

    if [[ "$filled" -lt 2 ]]; then
        echo "energy_3d_trajectory=N/A"
        echo "energy_3d_direction=N/A"
        return 0
    fi

    # Build trajectory string (e.g., "6→5→4")
    local trajectory=""
    for r in "${readings[@]}"; do
        if [[ -n "$r" ]]; then
            trajectory="${trajectory}${trajectory:+→}${r}"
        else
            trajectory="${trajectory}${trajectory:+→}?"
        fi
    done

    # Direction: compare first available vs last available
    local first_val="${vals[0]}"
    local last_val="${vals[${#vals[@]}-1]}"
    local direction
    direction=$(_coach_calc_trend "$first_val" "$last_val")
    local label
    case "$direction" in
        up) label="improving" ;;
        down) label="declining" ;;
        *) label="stable" ;;
    esac

    echo "energy_3d_trajectory=${trajectory}"
    echo "energy_3d_direction=${label}"
}

# Compute AI suggestion adherence: did the user complete tasks recommended yesterday?
coach_suggestion_adherence() {
    local anchor_date="$1"
    local briefing_file="$BRIEFING_CACHE_FILE"
    local done_file="$DONE_FILE"

    if [[ ! -f "$briefing_file" ]] || [[ ! -f "$done_file" ]]; then
        echo "suggestion_adherence=N/A"
        return 0
    fi

    local yesterday
    yesterday=$(_coach_shift_date "$anchor_date" "-1") || return 0

    # Extract yesterday's briefing
    local yesterday_briefing
    yesterday_briefing=$(grep "^$yesterday|" "$briefing_file" 2>/dev/null | tail -n 1 | cut -d'|' -f2- || true)

    if [[ -z "$yesterday_briefing" ]]; then
        echo "suggestion_adherence=N/A"
        return 0
    fi
    # Unescape newlines
    yesterday_briefing="${yesterday_briefing//\\n/$'\n'}"

    # Extract "Do Next" section bullet points
    local do_next
    do_next=$(printf '%s\n' "$yesterday_briefing" | awk '/Do Next/,/Operating insight/' | grep -E '^[0-9]+\.' || true)
    if [[ -z "$do_next" ]]; then
        echo "suggestion_adherence=N/A"
        return 0
    fi

    local keywords
    keywords=$(printf '%s' "$do_next" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '\n' | awk 'length >= 4' | sort -u)
    if [[ -z "$keywords" ]]; then
        echo "suggestion_adherence=N/A"
        return 0
    fi

    # Gather completed tasks from yesterday
    local tasks
    tasks=$(awk -F'|' -v day="$yesterday" 'substr($1, 1, 10) == day { print tolower($2) }' "$done_file")
    if [[ -z "$tasks" ]]; then
        echo "suggestion_adherence=low"
        return 0
    fi

    local matched=0
    local kw
    while IFS= read -r kw; do
        if printf '%s\n' "$tasks" | grep -qi "$kw" 2>/dev/null; then
            matched=$((matched + 1))
        fi
    done <<< "$keywords"

    if [[ "$matched" -ge 1 ]]; then
        echo "suggestion_adherence=high"
    else
        echo "suggestion_adherence=low"
    fi
}

# Persist daily adherence as a simple feedback loop for future coaching.
# Usage: coach_record_suggestion_adherence <anchor_date> <high|low|N/A>
coach_record_suggestion_adherence() {
    local anchor_date="$1"
    local adherence="$2"
    local adherence_file="${COACH_ADHERENCE_FILE:-${DATA_DIR:-}/coach_adherence.txt}"

    if [[ "$adherence" != "high" && "$adherence" != "low" ]]; then
        return 0
    fi
    if [[ -z "$anchor_date" ]]; then
        anchor_date=$(date '+%Y-%m-%d')
    fi
    if [[ -z "$adherence_file" ]]; then
        return 0
    fi

    local adherence_dir
    adherence_dir=$(dirname "$adherence_file")
    mkdir -p "$adherence_dir" 2>/dev/null || return 0

    local tmp_file=""
    tmp_file=$(_coach_secure_tmpfile "coach_adherence") || return 0
    : > "$tmp_file"

    if [[ -f "$adherence_file" ]]; then
        awk -F'|' -v day="$anchor_date" '
            $1 != day && $1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ && ($2 == "high" || $2 == "low") {
                print $1 "|" $2
            }
        ' "$adherence_file" >> "$tmp_file" 2>/dev/null || true
    fi
    printf '%s|%s\n' "$anchor_date" "$adherence" >> "$tmp_file"

    sort -u "$tmp_file" > "${tmp_file}.sorted" 2>/dev/null || cp "$tmp_file" "${tmp_file}.sorted"
    mv "${tmp_file}.sorted" "$adherence_file" 2>/dev/null || true
    rm -f "$tmp_file" "${tmp_file}.sorted" 2>/dev/null || true
}

# Compute rolling adherence rate for the feedback loop.
# Usage: coach_suggestion_adherence_rate <anchor_date> [days]
coach_suggestion_adherence_rate() {
    local anchor_date="$1"
    local days="${2:-14}"
    local adherence_file="${COACH_ADHERENCE_FILE:-${DATA_DIR:-}/coach_adherence.txt}"

    if [[ -z "$anchor_date" ]]; then
        anchor_date=$(date '+%Y-%m-%d')
    fi
    if ! [[ "$days" =~ ^[0-9]+$ ]] || [[ "$days" -lt 1 ]]; then
        days=14
    fi
    if [[ ! -f "$adherence_file" ]]; then
        echo "suggestion_adherence_rate=N/A"
        echo "suggestion_adherence_samples=0"
        return 0
    fi

    local window_start
    window_start=$(_coach_shift_date "$anchor_date" "-$((days-1))") || {
        echo "suggestion_adherence_rate=N/A"
        echo "suggestion_adherence_samples=0"
        return 0
    }

    local high_count low_count sample_count
    read -r high_count low_count sample_count <<< "$(awk -F'|' -v start="$window_start" -v end="$anchor_date" '
        $1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ && $1 >= start && $1 <= end && ($2 == "high" || $2 == "low") {
            total++
            if ($2 == "high") high++
            else low++
        }
        END {print high+0, low+0, total+0}
    ' "$adherence_file")"

    if [[ "${sample_count:-0}" -eq 0 ]]; then
        echo "suggestion_adherence_rate=N/A"
        echo "suggestion_adherence_samples=0"
        return 0
    fi

    local pct
    pct=$(awk -v h="$high_count" -v t="$sample_count" 'BEGIN { printf "%d", (h/t)*100 }')
    echo "suggestion_adherence_rate=$pct"
    echo "suggestion_adherence_samples=$sample_count"
    echo "suggestion_adherence_high=$high_count"
    echo "suggestion_adherence_low=$low_count"
}

# Detect commits pushed after midnight (early morning of anchor date)
coach_late_night_commits() {
    local anchor_date="$1"
    local projects_dir="${PROJECTS_DIR:-$HOME/Projects}"
    local late_commits=""

    if command -v git >/dev/null 2>&1; then
        local repo_dir
        for repo_dir in "$HOME/dotfiles" "$projects_dir"/*; do
            if [[ -d "$repo_dir/.git" ]]; then
                local repo_commits
                repo_commits=$(git -C "$repo_dir" log --format='%cd' --date=format:'%H:%M' \
                    --after="$anchor_date 00:00:00" --before="$anchor_date 04:00:00" 2>/dev/null || true)
                if [[ -n "$repo_commits" ]]; then
                    late_commits="${late_commits}${late_commits:+$'\n'}${repo_commits}"
                fi
            fi
        done
    fi

    late_commits=$(printf '%s\n' "$late_commits" | sed '/^[[:space:]]*$/d' | sort -u | head -n 1)

    if [[ -n "$late_commits" ]]; then
        echo "late_night_commits=true"
        echo "late_night_time=$late_commits"
    else
        echo "late_night_commits=false"
        echo "late_night_time="
    fi
}

coach_build_behavior_digest() {
    local anchor_date="$1"
    local tactical_days="${2:-7}"
    local pattern_days="${3:-30}"
    local recent_pushes_context="${4:-}"
    local commit_context="${5:-}"

    local tactical
    local pattern
    local quality
    tactical=$(coach_collect_tactical_metrics "$anchor_date" "$tactical_days") || return 1
    pattern=$(coach_collect_pattern_metrics "$anchor_date" "$pattern_days") || return 1
    quality=$(coach_collect_data_quality_flags)

    # Energy trajectory (3-day)
    local energy_traj
    energy_traj=$(coach_energy_trajectory "$anchor_date" 2>/dev/null || true)
    local energy_3d_trajectory energy_3d_direction
    energy_3d_trajectory=$(_coach_extract_value "$energy_traj" "energy_3d_trajectory")
    energy_3d_direction=$(_coach_extract_value "$energy_traj" "energy_3d_direction")

    # Focus coherence
    local focus_text=""
    if [[ -f "${FOCUS_FILE:-}" ]] && [[ -s "${FOCUS_FILE:-}" ]]; then
        focus_text=$(cat "$FOCUS_FILE" 2>/dev/null || true)
    fi
    local coherence
    coherence=$(coach_focus_coherence "$focus_text" "$anchor_date" 2>/dev/null || true)
    local focus_coherence_pct focus_coherence_detail
    focus_coherence_pct=$(_coach_extract_value "$coherence" "focus_coherence_pct")
    focus_coherence_detail=$(_coach_extract_value "$coherence" "focus_coherence_detail")

    local focus_git
    focus_git=$(coach_focus_git_signal "$focus_text" "$recent_pushes_context" "$commit_context" 2>/dev/null || echo $'focus_git_primary_repo=N/A\nfocus_git_primary_repo_share=N/A\nfocus_git_repo_count=0\nfocus_git_commit_total=0\nfocus_git_commit_matches=0\nfocus_git_commit_coherence=N/A\nfocus_git_status=no-git-evidence\nfocus_git_reason=focus-vs-git signal unavailable')
    local focus_git_primary_repo focus_git_primary_repo_share focus_git_repo_count focus_git_commit_total
    local focus_git_commit_matches focus_git_commit_coherence focus_git_status focus_git_reason
    focus_git_primary_repo=$(_coach_extract_value "$focus_git" "focus_git_primary_repo")
    focus_git_primary_repo_share=$(_coach_extract_value "$focus_git" "focus_git_primary_repo_share")
    focus_git_repo_count=$(_coach_extract_value "$focus_git" "focus_git_repo_count")
    focus_git_commit_total=$(_coach_extract_value "$focus_git" "focus_git_commit_total")
    focus_git_commit_matches=$(_coach_extract_value "$focus_git" "focus_git_commit_matches")
    focus_git_commit_coherence=$(_coach_extract_value "$focus_git" "focus_git_commit_coherence")
    focus_git_status=$(_coach_extract_value "$focus_git" "focus_git_status")
    focus_git_reason=$(_coach_extract_value "$focus_git" "focus_git_reason")

    local adherence
    adherence=$(coach_suggestion_adherence "$anchor_date" 2>/dev/null || echo "suggestion_adherence=N/A")
    local suggestion_adherence
    suggestion_adherence=$(_coach_extract_value "$adherence" "suggestion_adherence")
    coach_record_suggestion_adherence "$anchor_date" "$suggestion_adherence" || true

    local adherence_rate_blob
    adherence_rate_blob=$(coach_suggestion_adherence_rate "$anchor_date" 14 2>/dev/null || echo $'suggestion_adherence_rate=N/A\nsuggestion_adherence_samples=0')
    local suggestion_adherence_rate suggestion_adherence_samples
    suggestion_adherence_rate=$(_coach_extract_value "$adherence_rate_blob" "suggestion_adherence_rate")
    suggestion_adherence_samples=$(_coach_extract_value "$adherence_rate_blob" "suggestion_adherence_samples")

    local late_night
    late_night=$(coach_late_night_commits "$anchor_date" 2>/dev/null || echo "late_night_commits=N/A")
    local late_night_commits late_night_time
    late_night_commits=$(_coach_extract_value "$late_night" "late_night_commits")
    late_night_time=$(_coach_extract_value "$late_night" "late_night_time")

    local stale_tasks completed_tasks unique_dirs dir_switches avg_energy avg_fog avg_spoon_budget avg_spoon_spend
    stale_tasks=$(_coach_extract_value "$tactical" "stale_tasks")
    completed_tasks=$(_coach_extract_value "$tactical" "completed_tasks")
    unique_dirs=$(_coach_extract_value "$tactical" "unique_dirs")
    dir_switches=$(_coach_extract_value "$tactical" "dir_switches")
    avg_energy=$(_coach_extract_value "$tactical" "avg_energy")
    avg_fog=$(_coach_extract_value "$tactical" "avg_fog")
    avg_spoon_budget=$(_coach_extract_value "$tactical" "avg_spoon_budget")
    avg_spoon_spend=$(_coach_extract_value "$tactical" "avg_spoon_spend")
    local afternoon_slump
    afternoon_slump=$(_coach_extract_value "$tactical" "afternoon_slump")

    local working_signals=()
    local drift_risks=()

    if [[ "$focus_git_status" == "aligned" ]]; then
        working_signals+=("Git activity supports the declared focus (${focus_git_reason})")
    elif [[ "$focus_git_status" == "repo-locked" ]]; then
        working_signals+=("recent GitHub activity is concentrated in ${focus_git_primary_repo}")
    elif [[ "$focus_git_status" == "mixed" ]]; then
        drift_risks+=("Git activity only partially supports the declared focus (${focus_git_reason})")
    elif [[ "$focus_git_status" == "diffuse" ]]; then
        drift_risks+=("Git activity is drifting from the declared focus (${focus_git_reason})")
    elif [[ "$focus_git_status" == "no-git-evidence" ]]; then
        drift_risks+=("recent non-fork GitHub evidence is thin; focus movement is unproven")
    elif [[ "$focus_git_status" == "git-unavailable" ]]; then
        working_signals+=("GitHub signal was unavailable, so spear movement could not be evaluated from remote activity")
    fi
    if [[ "$suggestion_adherence_rate" =~ ^[0-9]+$ ]] && [[ "${suggestion_adherence_samples:-0}" =~ ^[0-9]+$ ]]; then
        if [[ "$suggestion_adherence_rate" -ge 70 ]]; then
            working_signals+=("recent AI suggestion follow-through is strong (${suggestion_adherence_rate}% over ${suggestion_adherence_samples} days)")
        elif [[ "$suggestion_adherence_rate" -lt 50 ]] && [[ "$suggestion_adherence_samples" -ge 3 ]]; then
            drift_risks+=("AI suggestion follow-through is low (${suggestion_adherence_rate}% over ${suggestion_adherence_samples} days)")
        fi
    fi
    if [[ "$late_night_commits" == "true" ]]; then
        drift_risks+=("late night commits detected (e.g., at ${late_night_time}) - consider whether intentional or hyperfocus drift")
    fi
    if [[ "$afternoon_slump" == "true" ]]; then
        drift_risks+=("afternoon energy slump detected")
    fi

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
    if [[ "$energy_3d_direction" == "improving" ]]; then
        working_signals+=("energy trajectory is improving (${energy_3d_trajectory})")
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
    if [[ "$avg_spoon_budget" != "N/A" && "$avg_spoon_spend" != "N/A" ]]; then
        if awk -v s="$avg_spoon_spend" -v b="$avg_spoon_budget" 'BEGIN { exit !(s > b) }'; then
            drift_risks+=("consistent spoon overspend (${avg_spoon_spend} vs budget ${avg_spoon_budget}) - burnout risk")
        fi
    fi

    if [[ "$focus_git_status" == "aligned" ]] && [[ "$focus_coherence_pct" != "N/A" ]] && [[ "$focus_coherence_pct" -ge 70 ]] 2>/dev/null; then
        working_signals+=("tasks completed today also reinforce the focus (${focus_coherence_pct}% — ${focus_coherence_detail})")
    elif [[ "$focus_git_status" == "no-git-evidence" ]] && [[ "$focus_coherence_pct" != "N/A" ]] && [[ "$focus_coherence_pct" -lt 40 ]] 2>/dev/null; then
        drift_risks+=("task completion also looks weakly aligned to focus (${focus_coherence_pct}% — ${focus_coherence_detail})")
    fi
    if [[ "$energy_3d_direction" == "declining" ]]; then
        local _traj_risk="energy trajectory is declining (${energy_3d_trajectory})"
        # If latest reading is near threshold, suggest RECOVERY
        local _latest_reading
        _latest_reading=$(printf '%s' "$energy_3d_trajectory" | awk -F'→' '{print $NF}')
        local _recovery_boundary=$((COACH_LOW_ENERGY_THRESHOLD + 1))
        if [[ "$_latest_reading" =~ ^[0-9]+$ ]] && [[ "$_latest_reading" -le "$_recovery_boundary" ]]; then
            _traj_risk="${_traj_risk} — consider RECOVERY mode"
        fi
        drift_risks+=("$_traj_risk")
    fi

    if [[ "$quality" != "none" ]]; then
        drift_risks+=("data quality flags detected")
    fi

    # Active timer check — detect long-running hyperfocus sessions
    local active_timer_status="none"
    local active_timer_duration_min=0
    if command -v get_active_timer >/dev/null 2>&1 || type get_active_timer >/dev/null 2>&1; then
        local _active_task_id
        _active_task_id=$(get_active_timer 2>/dev/null || true)
        if [[ -n "$_active_task_id" ]] && [[ -f "${TIME_LOG:-}" ]]; then
            local _last_start
            _last_start=$(grep "^START|${_active_task_id}" "$TIME_LOG" 2>/dev/null | tail -n 1 | cut -d'|' -f4)
            if [[ -n "$_last_start" ]]; then
                local _start_epoch _now_epoch
                _start_epoch=$(timestamp_to_epoch "$_last_start" 2>/dev/null || echo 0)
                _now_epoch=$(date +%s)
                if [[ "$_start_epoch" -gt 0 ]]; then
                    active_timer_duration_min=$(( (_now_epoch - _start_epoch) / 60 ))
                    active_timer_status="running|${_active_task_id}|${active_timer_duration_min}min"
                    if [[ "$active_timer_duration_min" -ge 120 ]]; then
                        drift_risks+=("active timer running for ${active_timer_duration_min}min on task ${_active_task_id} — possible hyperfocus session, body check recommended")
                    fi
                fi
            fi
        fi
    fi

    echo "Behavior digest (structured):"
    echo "Tactical window: ${tactical_days}d ending $anchor_date"
    echo "  open_tasks=$(_coach_extract_value "$tactical" "open_tasks"), stale_tasks=$stale_tasks, completed_tasks=$completed_tasks, journal_entries=$(_coach_extract_value "$tactical" "journal_entries")"
    echo "  avg_energy=${avg_energy}, avg_fog=${avg_fog}, energy_3d=${energy_3d_trajectory:-N/A} (${energy_3d_direction:-N/A}), afternoon_slump=${afternoon_slump:-N/A}, avg_spoon_budget=$(_coach_extract_value "$tactical" "avg_spoon_budget"), avg_spoon_spend=$(_coach_extract_value "$tactical" "avg_spoon_spend")"
    echo "  unique_dirs=$unique_dirs, dir_switches=$dir_switches, suggestion_adherence=${suggestion_adherence:-N/A}, suggestion_adherence_rate=${suggestion_adherence_rate:-N/A} (${suggestion_adherence_samples:-0} samples), late_night_commits=${late_night_commits:-N/A}, recent_pushes=$(_coach_extract_value "$tactical" "recent_pushes_count"), commit_context=$(_coach_extract_value "$tactical" "commit_context_count")"
    echo "Pattern window: ${pattern_days}d ending $anchor_date"
    echo "  completion_trend=$(_coach_extract_value "$pattern" "completion_trend") (first=$(_coach_extract_value "$pattern" "completion_first_half"), second=$(_coach_extract_value "$pattern" "completion_second_half"))"
    echo "  journal_trend=$(_coach_extract_value "$pattern" "journal_trend") (first=$(_coach_extract_value "$pattern" "journal_first_half"), second=$(_coach_extract_value "$pattern" "journal_second_half"))"
    echo "  focus_changes=$(_coach_extract_value "$pattern" "focus_changes") (~$(_coach_extract_value "$pattern" "focus_changes_per_week")/week)"
    echo "  top_directories=$(_coach_extract_value "$pattern" "top_directories")"
    echo "  top_dispatchers=$(_coach_extract_value "$pattern" "top_dispatchers")"
    echo "  focus_git_status=${focus_git_status:-N/A}, primary_repo=${focus_git_primary_repo:-N/A}, primary_repo_share=${focus_git_primary_repo_share:-N/A}, commit_coherence=${focus_git_commit_coherence:-N/A}, active_repos=${focus_git_repo_count:-0}"
    echo "  active_timer=${active_timer_status}"
    echo "  focus_git_reason=${focus_git_reason:-N/A}"
    echo "  focus_coherence_secondary=${focus_coherence_pct:-N/A}% (${focus_coherence_detail:-N/A})"
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
