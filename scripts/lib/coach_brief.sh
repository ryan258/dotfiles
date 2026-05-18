#!/usr/bin/env bash
# scripts/lib/coach_brief.sh
# Deterministic, user-facing coach brief rendering.
# NOTE: SOURCED file. Do NOT use set -euo pipefail.
#
# Dependencies:
# - coach_metrics.sh must already be sourced by the caller.

if [[ -n "${_COACH_BRIEF_LOADED:-}" ]]; then
    return 0
fi
readonly _COACH_BRIEF_LOADED=true

_coach_brief_single_line() {
    local value="${1:-}"
    value="${value//$'\r'/ }"
    value="${value//$'\n'/ }"
    value=$(printf '%s' "$value" | awk '{$1=$1; print}')
    printf '%s' "$value"
}

_coach_brief_inline_value() {
    local digest="$1"
    local key="$2"
    local value=""

    value=$(printf '%s\n' "$digest" | awk -v k="$key" '
        function trim(v) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
            return v
        }
        {
            line = $0
            gsub(/^[[:space:]]+/, "", line)
            while (match(line, /(^|, )[A-Za-z0-9_]+=/)) {
                start = RSTART
                if (substr(line, start, 2) == ", ") {
                    start += 2
                }
                rest = substr(line, start)
                eq = index(rest, "=")
                if (eq == 0) {
                    break
                }
                name = substr(rest, 1, eq - 1)
                after = substr(rest, eq + 1)
                next_match = match(after, /, [A-Za-z0-9_]+=/)
                if (next_match) {
                    candidate = substr(after, 1, next_match - 1)
                    line = substr(after, next_match + 2)
                } else {
                    candidate = after
                    line = ""
                }
                if (name == k) {
                    print trim(candidate)
                    exit
                }
            }
        }
    ')

    if [[ -z "$value" ]]; then
        value="N/A"
    fi
    printf '%s' "$value"
}

_coach_brief_line_value() {
    local digest="$1"
    local key="$2"
    local value=""

    value=$(printf '%s\n' "$digest" | awk -v k="$key" '
        function trim(v) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
            return v
        }
        {
            line = $0
            gsub(/^[[:space:]]+/, "", line)
            prefix = k "="
            if (index(line, prefix) == 1) {
                print trim(substr(line, length(prefix) + 1))
                exit
            }
        }
    ')

    if [[ -z "$value" ]]; then
        value="N/A"
    fi
    printf '%s' "$value"
}

_coach_brief_window_value() {
    local digest="$1"
    local heading="$2"
    local value=""

    value=$(printf '%s\n' "$digest" | awk -v h="$heading" '
        index($0, h) == 1 {
            print substr($0, length(h) + 1)
            exit
        }
    ')
    value="$(_coach_brief_single_line "$value")"
    [[ -n "$value" ]] || value="N/A"
    printf '%s' "$value"
}

_coach_brief_reading_value() {
    local reading="${1:-N/A}"
    case "$reading" in
        *" ("*")")
            printf '%s' "${reading%% (*}"
            ;;
        *)
            printf '%s' "$reading"
            ;;
    esac
}

_coach_brief_reading_at() {
    local reading="${1:-N/A}"
    local at="N/A"
    case "$reading" in
        *" ("*")")
            at="${reading#* (}"
            at="${at%)}"
            ;;
    esac
    printf '%s' "$at"
}

_coach_brief_section_bullets() {
    local digest="$1"
    local heading="$2"
    local rendered=""

    rendered=$(printf '%s\n' "$digest" | awk -v h="$heading" '
        $0 == h {
            capture = 1
            next
        }
        capture && $0 ~ /^[^[:space:]].*:$/ {
            exit
        }
        capture {
            line = $0
            sub(/^[[:space:]]*- /, "- ", line)
            if (line ~ /^- /) {
                print line
            }
        }
    ')

    if [[ -n "$rendered" ]]; then
        printf '%s\n' "$rendered"
    else
        printf '%s\n' "- none detected"
    fi
}

coach_brief_render_from_digest() {
    local flow_type="${1:-status}"
    local anchor_date="${2:-}"
    local focus_context="${3:-}"
    local mode="${4:-LOCKED}"
    local digest="${5:-}"

    flow_type="$(_coach_brief_single_line "$flow_type")"
    anchor_date="$(_coach_brief_single_line "$anchor_date")"
    focus_context="$(_coach_brief_single_line "${focus_context:-"(no focus set)"}")"
    mode="$(_coach_brief_single_line "$mode")"

    local tactical_window pattern_window
    tactical_window=$(_coach_brief_window_value "$digest" "Tactical window:")
    pattern_window=$(_coach_brief_window_value "$digest" "Pattern window:")

    local open_tasks stale_tasks completed_tasks
    local journal_entries journal_focus_hits drive_focus_hits_week drive_activity_hits_week
    open_tasks=$(_coach_brief_inline_value "$digest" "open_tasks")
    stale_tasks=$(_coach_brief_inline_value "$digest" "stale_tasks")
    completed_tasks=$(_coach_brief_inline_value "$digest" "completed_tasks")
    journal_entries=$(_coach_brief_inline_value "$digest" "journal_entries")
    journal_focus_hits=$(_coach_brief_inline_value "$digest" "journal_focus_hits")
    drive_focus_hits_week=$(_coach_brief_inline_value "$digest" "drive_focus_hits_week")
    drive_activity_hits_week=$(_coach_brief_inline_value "$digest" "drive_activity_hits_week")

    local latest_energy latest_energy_value latest_energy_at avg_energy
    local latest_fog latest_fog_value latest_fog_at avg_fog energy_3d afternoon_slump
    local avg_spoon_budget avg_spoon_spend
    latest_energy=$(_coach_brief_inline_value "$digest" "latest_energy")
    latest_energy_value=$(_coach_brief_reading_value "$latest_energy")
    latest_energy_at=$(_coach_brief_reading_at "$latest_energy")
    avg_energy=$(_coach_brief_inline_value "$digest" "avg_energy")
    latest_fog=$(_coach_brief_inline_value "$digest" "latest_fog")
    latest_fog_value=$(_coach_brief_reading_value "$latest_fog")
    latest_fog_at=$(_coach_brief_reading_at "$latest_fog")
    avg_fog=$(_coach_brief_inline_value "$digest" "avg_fog")
    energy_3d=$(_coach_brief_inline_value "$digest" "energy_3d")
    afternoon_slump=$(_coach_brief_inline_value "$digest" "afternoon_slump")
    avg_spoon_budget=$(_coach_brief_inline_value "$digest" "avg_spoon_budget")
    avg_spoon_spend=$(_coach_brief_inline_value "$digest" "avg_spoon_spend")

    local unique_dirs dir_switches suggestion_adherence_rate late_night_commits
    local recent_pushes commit_context strategy_evidence_sources
    unique_dirs=$(_coach_brief_inline_value "$digest" "unique_dirs")
    dir_switches=$(_coach_brief_inline_value "$digest" "dir_switches")
    suggestion_adherence_rate=$(_coach_brief_inline_value "$digest" "suggestion_adherence_rate")
    late_night_commits=$(_coach_brief_inline_value "$digest" "late_night_commits")
    recent_pushes=$(_coach_brief_inline_value "$digest" "recent_pushes")
    commit_context=$(_coach_brief_inline_value "$digest" "commit_context")
    strategy_evidence_sources=$(_coach_brief_line_value "$digest" "strategy_evidence_sources")

    local completion_trend journal_trend focus_changes top_directories top_dispatchers
    completion_trend=$(_coach_brief_line_value "$digest" "completion_trend")
    journal_trend=$(_coach_brief_line_value "$digest" "journal_trend")
    focus_changes=$(_coach_brief_line_value "$digest" "focus_changes")
    top_directories=$(_coach_brief_line_value "$digest" "top_directories")
    top_dispatchers=$(_coach_brief_line_value "$digest" "top_dispatchers")

    local focus_git_status primary_repo commit_coherence active_repos focus_git_reason focus_coherence_secondary active_timer
    focus_git_status=$(_coach_brief_inline_value "$digest" "focus_git_status")
    primary_repo=$(_coach_brief_inline_value "$digest" "primary_repo")
    commit_coherence=$(_coach_brief_inline_value "$digest" "commit_coherence")
    active_repos=$(_coach_brief_inline_value "$digest" "active_repos")
    focus_git_reason=$(_coach_brief_line_value "$digest" "focus_git_reason")
    focus_coherence_secondary=$(_coach_brief_line_value "$digest" "focus_coherence_secondary")
    active_timer=$(_coach_brief_line_value "$digest" "active_timer")

    cat <<EOF
Coach Brief
Flow: $flow_type
Date: ${anchor_date:-N/A}
Mode: $mode
Focus: $focus_context

Current Facts
- Window: $tactical_window.
- Tasks: $open_tasks open, $stale_tasks stale, $completed_tasks completed in the tactical window.
- Journal/Drive: $journal_entries journal entries, $journal_focus_hits focus journal hits, $drive_focus_hits_week Drive focus hits, $drive_activity_hits_week Drive activity hits.
- Energy/Fog: latest energy $latest_energy_value at $latest_energy_at; average energy $avg_energy. Latest fog $latest_fog_value at $latest_fog_at; average fog $avg_fog.
- Spoons: average budget $avg_spoon_budget, average spend $avg_spoon_spend.
- Context switching: $unique_dirs directories, $dir_switches switches.
- Strategy evidence: ${strategy_evidence_sources:-N/A}; recent pushes $recent_pushes; commit context $commit_context.
- Health flags: energy trend $energy_3d; afternoon slump $afternoon_slump; late-night commits $late_night_commits; suggestion follow-through $suggestion_adherence_rate.

Patterns
- Window: $pattern_window.
- Completion trend: $completion_trend.
- Journal trend: $journal_trend.
- Focus changes: $focus_changes.
- Top directories: $top_directories.
- Top dispatchers: $top_dispatchers.
- Focus/Git: $focus_git_status; primary repo $primary_repo; commit coherence $commit_coherence; active repos $active_repos.
- Focus reason: $focus_git_reason.
- Focus coherence: $focus_coherence_secondary.
- Active timer: $active_timer.

Working Signals
EOF
    _coach_brief_section_bullets "$digest" "Working signals:"

    cat <<'EOF'

Watch
EOF
    _coach_brief_section_bullets "$digest" "Drift risks:"

    cat <<'EOF'

Data Quality
EOF
    _coach_brief_section_bullets "$digest" "Data quality flags:"
}

coach_brief_render() {
    local flow_type="${1:-status}"
    local anchor_date="${2:-}"
    local focus_context="${3:-}"
    local mode="${4:-LOCKED}"
    local recent_pushes_context="${5:-}"
    local commit_context="${6:-}"
    local tactical_days="${7:-7}"
    local pattern_days="${8:-30}"
    local digest=""

    if [[ -z "$anchor_date" ]]; then
        anchor_date=$(date '+%Y-%m-%d')
    fi

    if ! command -v coach_build_behavior_digest >/dev/null 2>&1; then
        echo "coach_brief_render requires coach_metrics.sh to be sourced first" >&2
        return 1
    fi

    digest=$(coach_build_behavior_digest "$anchor_date" "$tactical_days" "$pattern_days" "$recent_pushes_context" "$commit_context") || return 1
    coach_brief_render_from_digest "$flow_type" "$anchor_date" "$focus_context" "$mode" "$digest"
}
