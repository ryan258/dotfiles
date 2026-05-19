#!/usr/bin/env bash
# scripts/lib/coach_prompts.sh
# Prompt construction and fallback output for behavioral coaching.
# NOTE: SOURCED file. Do NOT use set -euo pipefail.
#
# Dependencies:
# - coach_metrics.sh must be sourced first (provides _coach_extract_first_task helpers).

if [[ -n "${_COACH_PROMPTS_LOADED:-}" ]]; then
    return 0
fi
if [[ -z "${_COACH_METRICS_LOADED:-}" ]]; then
    echo "Error: coach_metrics.sh must be sourced before coach_prompts.sh." >&2
    return 1
fi
readonly _COACH_PROMPTS_LOADED=true
readonly COACH_BLINDSPOT_LIMIT=5

# Small helpers normalize labels, limits, and pre-brief question text.
_coach_reason_label() {
    local reason="${1:-unavailable}"
    # Turn internal machine labels into friendlier words for humans.
    case "$reason" in
        dispatcher-missing)
            printf '%s\n' "dispatcher missing"
            ;;
        *)
            printf '%s\n' "$reason"
            ;;
    esac
}

_coach_blindspot_limit() {
    printf '%s' "${COACH_BLINDSPOT_LIMIT:-5}"
}

_coach_blindspot_heading() {
    local section="${1:-github}"
    local limit

    limit=$(_coach_blindspot_limit)
    case "$section" in
        goodevening)
            printf 'Blindspots to sleep on (1-%s):' "$limit"
            ;;
        *)
            printf 'GitHub blindspots/opportunities (1-%s):' "$limit"
            ;;
    esac
}

_coach_prebrief_attempt_limit() {
    local value="${AI_COACH_PREBRIEF_MAX_ATTEMPTS:-3}"

    if ! [[ "$value" =~ ^[1-9]$ ]]; then
        value=3
    fi
    printf '%s' "$value"
}

_coach_repo_local_blindspot_scan() {
    local repo_name="$1"

    cat <<EOF
1. In ${repo_name}, name one visible polish pass before opening scope elsewhere.
2. In ${repo_name}, add one demo, screenshot, or walkthrough so the current lane is easier to re-enter.
3. In ${repo_name}, write one README or changelog note tied to the next concrete change.
4. In ${repo_name}, run one stability, test, or guardrail pass that would reduce future noise.
5. In ${repo_name}, define one clear finish line so you can tell when this sweep is actually done.
EOF
}

_coach_real_risk_from_digest() {
    local digest="$1"
    local latest_energy=""
    local latest_fog=""

    latest_energy=$(_coach_digest_line_value "$digest" "latest_energy")
    latest_fog=$(_coach_digest_line_value "$digest" "latest_fog")

    if [[ "$latest_energy" =~ ^[0-9]+$ ]] && [[ "$latest_energy" -le 1 ]]; then
        printf 'energy is at %s/10' "$latest_energy"
        return 0
    fi
    if [[ "$latest_fog" =~ ^[0-9]+$ ]] && [[ "$latest_fog" -ge 8 ]]; then
        printf 'brain fog is at %s/10' "$latest_fog"
        return 0
    fi

    return 1
}

_coach_strategy_signal_count() {
    local digest="$1"
    local key="$2"
    local value=""

    value=$(_coach_digest_line_value "$digest" "$key")
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        printf '%s' "$value"
    else
        printf '0'
    fi
}

_coach_strategy_signal_summary() {
    local digest="$1"
    local horizon="${2:-week}"
    local drive_key="drive_focus_hits_week"
    local journal_hits=0
    local drive_hits=0
    local drive_titles=""
    local parts=()
    local joined=""

    if [[ "$horizon" == "today" ]]; then
        drive_key="drive_focus_hits_today"
    fi

    journal_hits=$(_coach_strategy_signal_count "$digest" "journal_focus_hits")
    drive_hits=$(_coach_strategy_signal_count "$digest" "$drive_key")
    drive_titles=$(_coach_digest_line_value "$digest" "drive_recent_titles")

    if [[ "$journal_hits" -gt 0 ]]; then
        parts+=("${journal_hits} focus-related journal hit(s)")
    fi
    if [[ "$drive_hits" -gt 0 ]]; then
        if [[ -n "$drive_titles" && "$drive_titles" != "none" ]]; then
            parts+=("${drive_hits} relevant Drive doc hit(s) (${drive_titles})")
        else
            parts+=("${drive_hits} relevant Drive doc hit(s)")
        fi
    fi

    if [[ ${#parts[@]} -eq 0 ]]; then
        return 1
    fi

    printf -v joined '%s; ' "${parts[@]}"
    printf '%s' "${joined%; }"
}

_coach_prebrief_enabled() {
    [[ "${AI_COACH_PREBRIEF_ENABLED:-true}" != "false" ]]
}

_coach_prebrief_max_questions() {
    local value="${AI_COACH_PREBRIEF_MAX_QUESTIONS:-3}"

    if ! [[ "$value" =~ ^[1-3]$ ]]; then
        value=3
    fi
    printf '%s\n' "$value"
}

_coach_append_prebrief_block() {
    local existing="$1"
    local block="$2"

    if [[ -z "$block" ]]; then
        printf '%s' "$existing"
        return 0
    fi
    if [[ -n "$existing" ]]; then
        printf '%s\n%s' "$existing" "$block"
    else
        printf '%s' "$block"
    fi
}

_coach_prebrief_echo() {
    local text="$1"

    printf '%s\n' "$text" >&2
}

_coach_prebrief_printf() {
    local format="$1"
    shift

    printf "$format" "$@" >&2
}

_coach_prebrief_question_lane() {
    local index="$1"

    cat <<EOF
Q|${index}|Lane|Which lane should this briefing optimize for?
O|${index}|A|Declared focus|Use your stated focus as the main lane.
O|${index}|B|Current repo lane|Let recent repo or GitHub momentum lead the advice.
O|${index}|C|Exploration is valid|Treat cross-repo wandering as part of the real work.
O|${index}|D|Help me choose|Compare the visible lanes and recommend one.
O|${index}|E|Custom|Add your own lane preference.
EOF
}

_coach_prebrief_question_priority() {
    local index="$1"

    cat <<EOF
Q|${index}|Priority|What kind of help do you want most from this briefing?
O|${index}|A|Concrete next move|Bias the briefing toward one clear first step.
O|${index}|B|Narrow scope|Trim the work down to one lane.
O|${index}|C|Energy-aware pacing|Keep the advice body-aware and lower-noise.
O|${index}|D|Reflection or reset|Bias toward recentering before new pressure.
O|${index}|E|Custom|Add your own priority.
EOF
}

_coach_prebrief_question_framing() {
    local index="$1"

    cat <<EOF
Q|${index}|Framing|How should the coach frame recent off-script work?
O|${index}|A|Valid exploration|Treat side work as part of the real pattern.
O|${index}|B|Main focus first|Judge it against the declared focus first.
O|${index}|C|Recovery or rest|Assume the body needed a lighter or different lane.
O|${index}|D|Ask carefully|Keep the interpretation tentative and gentle.
O|${index}|E|Custom|Add your own framing.
EOF
}

_coach_prebrief_question_pacing() {
    local index="$1"

    cat <<EOF
Q|${index}|Pacing|How hard should this briefing push right now?
O|${index}|A|Normal push|Give me a normal working-day briefing.
O|${index}|B|Keep it gentle|Use a softer, lower-noise tone.
O|${index}|C|Protect energy|Bias toward rest, pacing, and fewer asks.
O|${index}|D|Push harder|Be a little firmer and more tactical.
O|${index}|E|Custom|Add your own pacing note.
EOF
}

_coach_prebrief_question_exists() {
    local questions_blob="$1"
    local index="$2"

    printf '%s\n' "$questions_blob" | awk -F'|' -v q="$index" '$1 == "Q" && $2 == q { found=1 } END { exit(found ? 0 : 1) }'
}

_coach_prebrief_question_field() {
    local questions_blob="$1"
    local index="$2"
    local kind="$3"
    local answer_letter="${4:-}"

    if [[ "$kind" == "question" ]]; then
        printf '%s\n' "$questions_blob" | awk -F'|' -v q="$index" '$1 == "Q" && $2 == q { print $4; exit }'
        return 0
    fi
    if [[ "$kind" == "header" ]]; then
        printf '%s\n' "$questions_blob" | awk -F'|' -v q="$index" '$1 == "Q" && $2 == q { print $3; exit }'
        return 0
    fi

    printf '%s\n' "$questions_blob" | awk -F'|' -v q="$index" -v a="$answer_letter" -v field="$kind" '
        $1 == "O" && $2 == q && $3 == a {
            if (field == "label") {
                print $4
            } else if (field == "description") {
                print $5
            }
            exit
        }
    '
}

# coach_build_framing_template - Build the AI framing template (no facts).
#
# Returns short instructions that ask the AI to layer a calm framing sentence
# and one next-move recommendation on top of the deterministic brief that the
# caller will append. The template itself must never contain numbers, dates,
# bullets, or repo names. Those live in the deterministic brief.
#
# This function is the Phase 4 framing-prompt builder. It is intentionally
# decoupled from the broad startday/goodevening/status prompt builders so the
# framing-template-no-facts contract test in test_coach_framing.sh can lock in
# the deletion signal from DOT-ROADMAP.md section 10.1 step 5.
#
# Inputs (positional):
#   1: flow_type - "startday" | "status" | "goodevening" (default: "status")
coach_build_framing_template() {
    local flow_type="${1:-status}"
    local intent_line=""

    case "$flow_type" in
        startday)
            intent_line="Give one short sentence of framing for today, then one short recommended next move."
            ;;
        goodevening)
            intent_line="Give one short sentence of framing for what closed today, then one short recommended setup for tomorrow."
            ;;
        *)
            intent_line="Give one short sentence of framing for right now, then one short recommended next move."
            ;;
    esac

    cat <<EOF
You are a calm coach summarizing the day's deterministic facts. The brief below is ground truth.

$intent_line

Stay grounded in the brief and do not invent unobserved work. Stay brief; no long menus unless the brief explicitly shows ambiguity. If the brief flags low energy or high fog, lower the demand and pace the next move.
EOF
}

# coach_build_framing_prompt - Build the full framing prompt (template + brief).
#
# The caller passes in the deterministic brief produced by
# coach_brief_render_from_digest. This function emits the framing template
# followed by the brief, suitable for handing to the AI dispatcher.
#
# Inputs (positional):
#   1: flow_type
#   2: brief - deterministic brief text produced by coach_brief_render_from_digest
coach_build_framing_prompt() {
    local flow_type="${1:-status}"
    local brief="${2:-}"

    coach_build_framing_template "$flow_type"
    printf '\nDeterministic brief:\n%s\n' "$brief"
}

# Pre-brief builders decide whether the coach should ask follow-up questions first.
coach_build_prebrief_questions() {
    local flow_type="$1"
    local focus_context="$2"
    local coach_mode="$3"
    local git_context="$4"
    local behavior_digest="$5"
    local current_dir="${6:-}"
    local project_context="${7:-}"
    local context_scope="${8:-global}"
    local questions=""
    local max_questions=""
    local always_ask="false"
    local focus_git_status=""
    local active_repos=""
    local primary_repo=""
    local latest_energy=""
    local latest_fog=""
    local real_risk=""
    local question_count=0
    local lane_ambiguous="false"
    local needs_priority="false"
    local needs_pacing="false"
    local needs_framing="false"

    max_questions=$(_coach_prebrief_max_questions)
    if [[ "${AI_COACH_PREBRIEF_ALWAYS_ASK:-false}" == "true" ]]; then
        always_ask="true"
    fi

    if [[ -n "$behavior_digest" ]]; then
        focus_git_status=$(_coach_digest_inline_value "$behavior_digest" "focus_git_status")
        active_repos=$(_coach_digest_inline_value "$behavior_digest" "active_repos")
        primary_repo=$(_coach_digest_inline_value "$behavior_digest" "primary_repo")
        latest_energy=$(_coach_digest_line_value "$behavior_digest" "latest_energy")
        latest_fog=$(_coach_digest_line_value "$behavior_digest" "latest_fog")
        real_risk=$(_coach_real_risk_from_digest "$behavior_digest" 2>/dev/null || true)
    fi

    if [[ -z "$focus_context" ]] || [[ "$focus_git_status" == "diffuse" || "$focus_git_status" == "mixed" || "$focus_git_status" == "repo-locked" || "$focus_git_status" == "no-git-evidence" || "$focus_git_status" == "git-unavailable" ]]; then
        lane_ambiguous="true"
    fi
    if [[ "${active_repos:-0}" =~ ^[0-9]+$ ]] && [[ "${active_repos:-0}" -ge 3 ]]; then
        lane_ambiguous="true"
        needs_priority="true"
    fi
    if [[ "$context_scope" == "repo-local" ]] && [[ -n "$project_context" && "$project_context" != "(no project context)" ]] && [[ -n "$primary_repo" && "$primary_repo" != "N/A" && "$primary_repo" != "$project_context" ]]; then
        lane_ambiguous="true"
    fi
    if [[ -z "$focus_context" ]] || [[ "$focus_git_status" == "no-git-evidence" || "$focus_git_status" == "git-unavailable" ]]; then
        needs_priority="true"
    fi
    if [[ -n "$real_risk" || "${coach_mode:-LOCKED}" == "RECOVERY" || -z "$latest_energy" || -z "$latest_fog" ]]; then
        needs_pacing="true"
    fi
    if [[ "$focus_git_status" == "diffuse" || "$focus_git_status" == "mixed" ]] || ([[ "${active_repos:-0}" =~ ^[0-9]+$ ]] && [[ "${active_repos:-0}" -ge 2 ]]); then
        needs_framing="true"
    fi

    if [[ "$flow_type" == "goodevening" ]]; then
        if [[ "$always_ask" == "true" || "$needs_framing" == "true" ]]; then
            question_count=$((question_count + 1))
            questions=$(_coach_append_prebrief_block "$questions" "$(_coach_prebrief_question_framing "$question_count")")
        fi
        if [[ "$question_count" -lt "$max_questions" ]] && [[ "$always_ask" == "true" || "$lane_ambiguous" == "true" ]]; then
            question_count=$((question_count + 1))
            questions=$(_coach_append_prebrief_block "$questions" "$(_coach_prebrief_question_lane "$question_count")")
        fi
        if [[ "$question_count" -lt "$max_questions" ]] && [[ "$always_ask" == "true" || "$needs_pacing" == "true" ]]; then
            question_count=$((question_count + 1))
            questions=$(_coach_append_prebrief_block "$questions" "$(_coach_prebrief_question_pacing "$question_count")")
        fi
    else
        if [[ "$always_ask" == "true" || "$lane_ambiguous" == "true" ]]; then
            question_count=$((question_count + 1))
            questions=$(_coach_append_prebrief_block "$questions" "$(_coach_prebrief_question_lane "$question_count")")
        fi
        if [[ "$question_count" -lt "$max_questions" ]] && [[ "$always_ask" == "true" || "$needs_priority" == "true" ]]; then
            question_count=$((question_count + 1))
            questions=$(_coach_append_prebrief_block "$questions" "$(_coach_prebrief_question_priority "$question_count")")
        fi
        if [[ "$question_count" -lt "$max_questions" ]] && [[ "$always_ask" == "true" || "$needs_pacing" == "true" ]]; then
            question_count=$((question_count + 1))
            questions=$(_coach_append_prebrief_block "$questions" "$(_coach_prebrief_question_pacing "$question_count")")
        fi
    fi

    printf '%s' "$questions"
}

_coach_render_prebrief_questions() {
    local questions_blob="$1"
    local line=""

    _coach_prebrief_echo "🤔 PRE-BRIEF CHECK:"
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        IFS='|' read -r record_type question_index question_header question_text question_detail <<< "$line"
        case "$record_type" in
            Q)
                _coach_prebrief_printf '  %s. %s\n' "$question_index" "$question_text"
                ;;
            O)
                _coach_prebrief_printf '     %s. %s\n' "$question_header" "$question_text"
                _coach_prebrief_printf '        %s\n' "$question_detail"
                ;;
        esac
    done <<< "$questions_blob"
    _coach_prebrief_echo "  Answer in one line like: 1B 2A 3E (custom detail)"
}

_coach_parse_prebrief_answers() {
    local raw_answers="$1"
    local normalized_answers=""
    local line=""
    local question_index=""
    local answer_letter=""
    local answer_tail=""

    normalized_answers=$(printf '%s\n' "$raw_answers" | sed -E 's/(^|[[:space:]])([0-9]+[A-Ea-e])/\n\2/g')
    while IFS= read -r line; do
        question_index=""
        answer_letter=""
        answer_tail=""

        line=$(_coach_trim_ascii_whitespace "$line")
        [[ -z "$line" ]] && continue
        if [[ "$line" =~ ^([0-9]+)([A-Ea-e])(.*)$ ]]; then
            question_index="${BASH_REMATCH[1]}"
            answer_letter=$(printf '%s' "${BASH_REMATCH[2]}" | tr '[:lower:]' '[:upper:]')
            answer_tail=$(_coach_trim_ascii_whitespace "${BASH_REMATCH[3]}")
            answer_tail="${answer_tail#:}"
            answer_tail=$(_coach_trim_ascii_whitespace "$answer_tail")
            if [[ "$answer_tail" == \(* && "$answer_tail" == *\) ]]; then
                answer_tail="${answer_tail#\(}"
                answer_tail="${answer_tail%\)}"
                answer_tail=$(_coach_trim_ascii_whitespace "$answer_tail")
            fi
            printf '%s|%s|%s\n' "$question_index" "$answer_letter" "$answer_tail"
        fi
    done <<< "$normalized_answers"
}

coach_prebrief_answers_to_context() {
    local questions_blob="$1"
    local raw_answers="$2"
    local parsed_answers=""
    local summary=""
    local line=""

    parsed_answers=$(_coach_parse_prebrief_answers "$raw_answers")
    while IFS= read -r line; do
        local question_index=""
        local answer_letter=""
        local custom_text=""
        local question_header=""
        local option_label=""
        local option_description=""
        local summary_line=""

        [[ -z "$line" ]] && continue
        IFS='|' read -r question_index answer_letter custom_text <<< "$line"
        if ! _coach_prebrief_question_exists "$questions_blob" "$question_index"; then
            continue
        fi
        question_header=$(_coach_prebrief_question_field "$questions_blob" "$question_index" "header")
        option_label=$(_coach_prebrief_question_field "$questions_blob" "$question_index" "label" "$answer_letter")
        option_description=$(_coach_prebrief_question_field "$questions_blob" "$question_index" "description" "$answer_letter")
        if [[ -z "$option_label" ]]; then
            continue
        fi
        if [[ "$answer_letter" == "E" && -n "$custom_text" ]]; then
            summary_line="- ${question_header}: custom - ${custom_text}"
        elif [[ "$answer_letter" == "E" ]]; then
            summary_line="- ${question_header}: custom"
        elif [[ -n "$custom_text" ]]; then
            summary_line="- ${question_header}: ${option_label}. ${option_description} Note: ${custom_text}"
        else
            summary_line="- ${question_header}: ${option_label}. ${option_description}"
        fi
        summary=$(_coach_append_prebrief_block "$summary" "$summary_line")
    done <<< "$parsed_answers"

    printf '%s' "$summary"
}

coach_collect_prebrief_context() {
    local flow_type="$1"
    local focus_context="$2"
    local coach_mode="$3"
    local git_context="$4"
    local behavior_digest="$5"
    local current_dir="${6:-}"
    local project_context="${7:-}"
    local context_scope="${8:-global}"
    local questions_blob=""
    local raw_answers=""
    local prebrief_context=""
    local attempts=0
    local max_attempts=0

    if ! _coach_prebrief_enabled; then
        return 0
    fi
    if [[ ! -t 0 ]] && [[ ! -t 2 ]]; then
        return 0
    fi

    questions_blob=$(coach_build_prebrief_questions "$flow_type" "$focus_context" "$coach_mode" "$git_context" "$behavior_digest" "$current_dir" "$project_context" "$context_scope")
    [[ -z "$questions_blob" ]] && return 0
    max_attempts=$(_coach_prebrief_attempt_limit)

    while true; do
        _coach_render_prebrief_questions "$questions_blob"
        _coach_prebrief_printf '  Pre-brief answers [Enter to skip]: '
        if ! IFS= read -r raw_answers </dev/tty 2>/dev/null; then
            _coach_prebrief_echo ""
            return 0
        fi
        raw_answers=$(_coach_trim_ascii_whitespace "$raw_answers")
        if [[ -z "$raw_answers" ]]; then
            return 0
        fi
        prebrief_context=$(coach_prebrief_answers_to_context "$questions_blob" "$raw_answers")
        if [[ -n "$prebrief_context" ]]; then
            printf '%s' "$prebrief_context"
            return 0
        fi
        attempts=$((attempts + 1))
        if [[ "$attempts" -ge "$max_attempts" ]]; then
            _coach_prebrief_echo "  Couldn't parse that. Skipping pre-brief after ${max_attempts} tries."
            return 0
        fi
        _coach_prebrief_echo "  Couldn't parse that. Use format: 1B 2A 3E (custom detail)"
    done
}

# Prompt builders turn the current context into a full dispatcher prompt.



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
    printf '%s' "$cleaned"
}

_coach_digest_inline_value() {
    local digest="$1"
    local key="$2"

    printf '%s\n' "$digest" | awk -v k="$key" '
        /focus_git_status=/ {
            n = split($0, fields, /,[[:space:]]*/)
            for (i = 1; i <= n; i++) {
                split(fields[i], pair, "=")
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", pair[1])
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", pair[2])
                if (pair[1] == k) {
                    print pair[2]
                    exit
                }
            }
        }
    '
}

_coach_digest_line_value() {
    local digest="$1"
    local key="$2"

    printf '%s\n' "$digest" | awk -v k="$key" '
        {
            line = $0
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            prefix = k "="
            if (index(line, prefix) == 1) {
                sub("^" prefix, "", line)
                print line
                exit
            }
        }
    '
}

_coach_base64_decode() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        base64 -D
        return
    fi
    if base64 --help 2>/dev/null | grep -q -- '--decode'; then
        base64 --decode
    else
        base64 -d
    fi
}

_coach_render_behavior_digest() {
    local digest="$1"

    printf '%s\n' "$digest" | awk '
        {
            trimmed = $0
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", trimmed)
            if (trimmed ~ /^drive_top_file_(id|name|snippet_b64)=/) {
                next
            }
            print $0
        }
    '
}

_coach_commit_repo_summary() {
    local commit_context="$1"

    printf '%s\n' "$commit_context" | awk '
        function trim(value) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            return value
        }
        /^[[:space:]]*[•-][[:space:]]+/ {
            line = $0
            sub(/^[[:space:]]*[•-][[:space:]]+/, "", line)
            line = trim(line)
            if (line == "" || line ~ /^\(none\)/ || line ~ /^\(GitHub signal unavailable\)/) {
                next
            }
            repo = line
            if (index(repo, ":") > 0) {
                sub(/:.*/, "", repo)
            } else if (repo ~ /[[:space:]]+\(/) {
                sub(/[[:space:]]+\(.*/, "", repo)
            }
            repo = trim(repo)
            if (repo == "" || seen[repo]) {
                next
            }
            seen[repo] = 1
            repos[++n] = repo
        }
        END {
            if (n == 1) {
                print repos[1]
            } else if (n == 2) {
                print repos[1] " and " repos[2]
            } else if (n >= 3) {
                print repos[1] ", " repos[2] ", and " (n - 2) " more"
            }
        }
    '
}

_coach_commit_repo_list() {
    local commit_context="$1"

    printf '%s\n' "$commit_context" | awk '
        function trim(value) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            return value
        }
        /^[[:space:]]*[•-][[:space:]]+/ {
            line = $0
            sub(/^[[:space:]]*[•-][[:space:]]+/, "", line)
            line = trim(line)
            if (line == "" || line ~ /^\(none\)/ || line ~ /^\(GitHub signal unavailable\)/) {
                next
            }
            repo = line
            if (index(repo, ":") > 0) {
                sub(/:.*/, "", repo)
            } else if (repo ~ /[[:space:]]+\(/) {
                sub(/[[:space:]]+\(.*/, "", repo)
            }
            repo = trim(repo)
            if (repo == "" || seen[repo]) {
                next
            }
            seen[repo] = 1
            print repo
        }
    '
}

_coach_focus_is_contentish() {
    local focus_text
    focus_text=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')

    case "$focus_text" in
        *content*|*blog*|*post*|*article*|*site*|*website*|*homepage*|*publish*|*writing*|*copy*|*ryanleej.com*)
            return 0
            ;;
    esac

    return 1
}

_coach_commit_pattern_metrics() {
    local commit_context="$1"

    printf '%s\n' "$commit_context" | awk '
        function trim(value) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            return value
        }
        /^[[:space:]]*[•-][[:space:]]+/ {
            line = $0
            sub(/^[[:space:]]*[•-][[:space:]]+/, "", line)
            line = trim(line)
            if (line == "" || line ~ /^\(none\)/ || line ~ /^\(GitHub signal unavailable\)/) {
                next
            }
            if (index(line, ":") == 0) {
                next
            }

            message = line
            sub(/^[^:]+:[[:space:]]*/, "", message)
            gsub(/[[:space:]]+\([0-9a-f]{7,}\)$/, "", message)
            message = tolower(trim(message))
            total++

            if (message ~ /(^|[^[:alpha:]])(feat|feature|implement|implemented|implementing|add|added|rewrite|rewrote|refactor|refactored|build|built|create|created|introduce|introduced|optimize|optimized|counterfactual|fingerprinting|retry)([^[:alpha:]]|$)/) {
                feature++
            }
            if (message ~ /(^|[^[:alpha:]])(docs|doc|readme|guide|demo|example|examples|test|tests|fix|fixed|polish|polished|cleanup|review|release|ship|content|copy|article)([^[:alpha:]]|$)/) {
                polish++
            }
        }
        END {
            print "feature_commits=" (feature + 0)
            print "polish_commits=" (polish + 0)
            print "total_commits=" (total + 0)
        }
    '
}

_coach_commit_pattern_value() {
    local metrics="$1"
    local key="$2"

    printf '%s\n' "$metrics" | awk -F'=' -v key="$key" '$1 == key { print $2; exit }'
}

_coach_github_opportunity_line() {
    local focus="$1"
    local commit_context="$2"
    local focus_git_status="$3"
    local primary_repo="$4"
    local active_repos="$5"
    local repo_summary="$6"
    local commit_metrics=""
    local feature_commits=0
    local polish_commits=0
    local total_commits=0

    commit_metrics=$(_coach_commit_pattern_metrics "$commit_context")
    feature_commits=$(_coach_commit_pattern_value "$commit_metrics" "feature_commits")
    polish_commits=$(_coach_commit_pattern_value "$commit_metrics" "polish_commits")
    total_commits=$(_coach_commit_pattern_value "$commit_metrics" "total_commits")

    if [[ -n "$repo_summary" ]] && [[ "${total_commits:-0}" -gt 0 ]] && [[ "${feature_commits:-0}" -gt "${polish_commits:-0}" ]]; then
        if _coach_focus_is_contentish "$focus"; then
            printf '%s\n' "GitHub blindspot opportunity: recent work is feature-heavy across ${repo_summary}; turn one real change from that work into a write-up, changelog, or demo angle instead of starting from a blank page."
        else
            printf '%s\n' "GitHub blindspot opportunity: recent work is feature-heavy across ${repo_summary}; docs, demo, or polish work is likely lagging behind shipping."
        fi
        return 0
    fi

    if [[ "$focus_git_status" == "diffuse" ]] && [[ "${active_repos:-0}" =~ ^[0-9]+$ ]] && [[ "${active_repos:-0}" -ge 3 ]]; then
        printf '%s\n' "GitHub blindspot opportunity: breadth across ${active_repos} repos may be outrunning finish work; pick one repo to deepen instead of spreading more feature work."
        return 0
    fi

    if [[ -n "$primary_repo" && "$primary_repo" != "N/A" ]]; then
        printf '%s\n' "Enhancement opportunity: use ${primary_repo} as the candidate for a small polish pass before opening a new lane."
        return 0
    fi

    return 1
}

_coach_append_unique_candidate() {
    local existing="$1"
    local candidate="$2"

    if [[ -z "$candidate" ]]; then
        printf '%s' "$existing"
        return 0
    fi

    if printf '%s\n' "$existing" | grep -Fqx "$candidate"; then
        printf '%s' "$existing"
        return 0
    fi

    if [[ -n "$existing" ]]; then
        printf '%s\n%s' "$existing" "$candidate"
    else
        printf '%s' "$candidate"
    fi
}

_coach_github_blindspot_scan() {
    local focus="$1"
    local commit_context="$2"
    local focus_git_status="$3"
    local primary_repo="$4"
    local primary_repo_share="$5"
    local commit_coherence="$6"
    local active_repos="$7"
    local focus_git_reason="$8"
    local repo_summary="$9"
    local commit_metrics=""
    local feature_commits=0
    local polish_commits=0
    local total_commits=0
    local repos_blob=""
    local repo=""
    local candidates=""
    local count=0
    local line=""
    local limit
    local commit_coherence_value="N/A"

    limit=$(_coach_blindspot_limit)

    commit_metrics=$(_coach_commit_pattern_metrics "$commit_context")
    feature_commits=$(_coach_commit_pattern_value "$commit_metrics" "feature_commits")
    polish_commits=$(_coach_commit_pattern_value "$commit_metrics" "polish_commits")
    total_commits=$(_coach_commit_pattern_value "$commit_metrics" "total_commits")
    repos_blob=$(_coach_commit_repo_list "$commit_context")
    if [[ "${commit_coherence:-}" =~ ^[0-9]+$ ]]; then
        commit_coherence_value="$commit_coherence"
    fi

    if [[ -n "$repo_summary" ]] && [[ "${total_commits:-0}" -gt 0 ]] && [[ "${feature_commits:-0}" -gt "${polish_commits:-0}" ]]; then
        if _coach_focus_is_contentish "$focus"; then
            candidates=$(_coach_append_unique_candidate "$candidates" "Turn one shipped change from ${repo_summary} into a write-up, changelog, or demo angle instead of starting from a blank page.")
        else
            candidates=$(_coach_append_unique_candidate "$candidates" "In ${repo_summary}, do one docs, demo, or polish pass before stacking more feature work.")
        fi
    fi

    if [[ "$focus_git_status" == "diffuse" ]] && [[ "${active_repos:-0}" =~ ^[0-9]+$ ]] && [[ "${active_repos:-0}" -ge 3 ]]; then
        candidates=$(_coach_append_unique_candidate "$candidates" "Pick one repo out of the ${active_repos} active lanes and deepen it instead of spreading more feature work.")
    fi

    if [[ -n "$primary_repo" && "$primary_repo" != "N/A" ]]; then
        candidates=$(_coach_append_unique_candidate "$candidates" "In ${primary_repo}, do one small polish pass before opening a new lane.")
    fi

    if [[ "${commit_coherence:-}" =~ ^[0-9]+$ ]] && [[ "${commit_coherence:-0}" -lt 40 ]] && [[ "${total_commits:-0}" -gt 0 ]]; then
        candidates=$(_coach_append_unique_candidate "$candidates" "Commit language is only ${commit_coherence_value}% aligned with the declared focus; either tighten the work around the focus or rename the focus to match the real lane.")
    fi

    if [[ "${polish_commits:-0}" -eq 0 ]] && [[ "${total_commits:-0}" -gt 0 ]]; then
        candidates=$(_coach_append_unique_candidate "$candidates" "Add one docs, demo, or test pass to the current lane so quality and legibility stop hiding behind feature momentum.")
    fi

    if [[ -n "$focus_git_reason" ]]; then
        candidates=$(_coach_append_unique_candidate "$candidates" "Use this focus-vs-Git signal to prune one lane: ${focus_git_reason}.")
    fi

    if _coach_focus_is_contentish "$focus" && [[ -n "$repo_summary" ]]; then
        candidates=$(_coach_append_unique_candidate "$candidates" "Mine ${repo_summary} for one before/after story, lessons-learned post, or command-sheet artifact that turns real work into publishable material.")
    fi

    for repo in $repos_blob; do
        candidates=$(_coach_append_unique_candidate "$candidates" "In ${repo}, add one short demo, screenshot, or walkthrough so the newest capability is legible without code-reading.")
    done
    for repo in $repos_blob; do
        candidates=$(_coach_append_unique_candidate "$candidates" "In ${repo}, add one README or changelog note tied directly to the newest change.")
    done
    for repo in $repos_blob; do
        candidates=$(_coach_append_unique_candidate "$candidates" "In ${repo}, remove one onboarding or setup friction point before adding more features.")
    done
    for repo in $repos_blob; do
        candidates=$(_coach_append_unique_candidate "$candidates" "In ${repo}, extract or document one reusable script, pattern, or helper instead of leaving it one-off.")
    done
    for repo in $repos_blob; do
        candidates=$(_coach_append_unique_candidate "$candidates" "In ${repo}, run one stability or test pass before the next feature wave lands.")
    done

    if [[ -z "$candidates" ]]; then
        candidates="Non-fork GitHub evidence is sparse, so the first opportunity is to produce one visible commit early and let the next scan work from that."
    fi

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        count=$((count + 1))
        printf '%s. %s\n' "$count" "$line"
        if [[ "$count" -ge "$limit" ]]; then
            break
        fi
    done <<< "$candidates"
}

_coach_blindspot_line_is_noise() {
    local line="$1"
    local lowered=""

    lowered=$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]')
    if [[ "$lowered" == *"journal"* || "$lowered" == *"todo"* || "$lowered" == *"completed task"* || "$lowered" == *"task completion"* ]]; then
        return 0
    fi
    if [[ "$lowered" == *"data quality"* || "$lowered" == *"malformed"* || "$lowered" == *"dir_usage_malformed"* || "$lowered" == *"todo_done_malformed"* || "$lowered" == *"commit_context"* || "$lowered" == *"commit context"* ]]; then
        return 0
    fi
    if [[ "$lowered" == *"focus_git_status"* || "$lowered" == *"primary_repo_share"* || "$lowered" == *"avg_fog"* || "$lowered" == *"afternoon_slump"* ]]; then
        return 0
    fi
    if [[ "$lowered" == *"brain fog"* || "$lowered" == *"fog score"* || "$lowered" == *"cognitive load"* || "$lowered" == *"health constraint"* || "$lowered" == *"task scheduling"* || "$lowered" == *"afternoon slump"* || "$lowered" == *"energy slump"* || "$lowered" == *"suggestion adherence"* || "$lowered" == *"adherence rate"* || "$lowered" == *"completion trend"* || "$lowered" == *"focus aid"* || "$lowered" == *"planned intervention"* ]]; then
        return 0
    fi
    if [[ "$lowered" == *"impossible to judge"* || "$lowered" == *"makes it impossible"* || "$lowered" == *"cannot verify"* || "$lowered" == *"can't verify"* || "$lowered" == *"no recent commit evidence"* || "$lowered" == *"local-only stage"* ]]; then
        return 0
    fi
    if [[ "$lowered" =~ [a-z0-9_]+=[^[:space:]]+ ]]; then
        return 0
    fi
    return 1
}

_coach_trim_ascii_whitespace() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

_coach_strip_numbered_prefix() {
    local line="$1"

    line=$(_coach_trim_ascii_whitespace "$line")
    if [[ "$line" =~ ^[0-9]+\.[[:space:]]+ ]]; then
        line="${line#*.}"
        line=$(_coach_trim_ascii_whitespace "$line")
    fi
    printf '%s' "$line"
}

_coach_extract_numbered_section_lines() {
    local response="$1"
    local section_prefix="$2"
    local line=""
    local in_section=0

    while IFS= read -r line; do
        if [[ "$in_section" -eq 0 ]]; then
            if _coach_line_has_prefix "$line" "$section_prefix"; then
                in_section=1
            fi
            continue
        fi

        if [[ "$line" =~ ^[[:space:]]*[0-9]+\.[[:space:]]+ ]]; then
            printf '%s\n' "$line"
            continue
        fi
        if _coach_line_is_heading "$line"; then
            break
        fi
    done <<< "$response"
}

_coach_extract_text_section_body() {
    local response="$1"
    local section_prefix="$2"
    local line=""
    local in_section=0

    while IFS= read -r line; do
        if [[ "$in_section" -eq 0 ]]; then
            if _coach_line_has_prefix "$line" "$section_prefix"; then
                in_section=1
            fi
            continue
        fi

        if _coach_line_is_heading "$line"; then
            break
        fi

        printf '%s\n' "$line"
    done <<< "$response"
}

_coach_clean_blindspot_section() {
    local existing_lines="$1"
    local grounded_scan="$2"
    local limit="${3:-$(_coach_blindspot_limit)}"
    local cleaned=""
    local line=""
    local bare=""
    local count=0

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        bare=$(_coach_strip_numbered_prefix "$line")
        if _coach_blindspot_line_is_noise "$bare"; then
            continue
        fi
        cleaned=$(_coach_append_unique_candidate "$cleaned" "$bare")
    done <<< "$existing_lines"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        bare=$(_coach_strip_numbered_prefix "$line")
        if _coach_blindspot_line_is_noise "$bare"; then
            continue
        fi
        cleaned=$(_coach_append_unique_candidate "$cleaned" "$bare")
    done <<< "$grounded_scan"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        count=$((count + 1))
        printf '%s. %s\n' "$count" "$line"
        if [[ "$count" -ge "$limit" ]]; then
            break
        fi
    done <<< "$cleaned"
}

# Refinement helpers patch missing sections and keep headings stable.

_coach_normalize_heading_line() {
    local line="$1"

    line=$(_coach_trim_ascii_whitespace "$line")
    while [[ "$line" == \** ]]; do
        line="${line#\*}"
    done
    while [[ "$line" == *\* ]]; do
        line="${line%\*}"
    done
    line=$(_coach_trim_ascii_whitespace "$line")
    printf '%s' "$line"
}

_coach_line_is_heading() {
    local normalized=""

    normalized=$(_coach_normalize_heading_line "$1")
    [[ "$normalized" =~ ^[[:space:]]*[A-Za-z][^:]*:[[:space:]]*$ ]]
}

_coach_line_has_prefix() {
    local line="$1"
    local prefix="$2"
    local normalized=""

    normalized=$(_coach_normalize_heading_line "$line")
    [[ "$normalized" == "$prefix"* ]]
}

_coach_line_equals_heading() {
    local line="$1"
    local heading="$2"
    local normalized=""

    normalized=$(_coach_normalize_heading_line "$line")
    [[ "$normalized" == "$heading" ]]
}

_coach_replace_or_insert_numbered_section() {
    local response="$1"
    local section_prefix="$2"
    local section_heading="$3"
    local insert_before_heading="$4"
    local section_lines="$5"
    local line=""
    local in_section=0
    local inserted=0

    _coach_print_replacement() {
        if [[ "$inserted" -eq 1 ]]; then
            return 0
        fi
        printf '%s\n' "$section_heading"
        if [[ -n "$section_lines" ]]; then
            printf '%s\n' "$section_lines"
        fi
        inserted=1
        return 0
    }

    while IFS= read -r line; do
        if [[ "$in_section" -eq 1 ]]; then
            if _coach_line_is_heading "$line"; then
                in_section=0
            else
                continue
            fi
        fi

        if _coach_line_has_prefix "$line" "$section_prefix"; then
            _coach_print_replacement
            in_section=1
            continue
        fi

        if [[ "$inserted" -eq 0 ]] && _coach_line_equals_heading "$line" "$insert_before_heading"; then
            _coach_print_replacement
        fi

        printf '%s\n' "$line"
    done <<< "$response"

    if [[ "$inserted" -eq 0 ]]; then
        _coach_print_replacement
    fi

    unset -f _coach_print_replacement
}

_coach_replace_or_insert_text_section() {
    local response="$1"
    local section_prefix="$2"
    local section_heading="$3"
    local insert_before_heading="$4"
    local section_body="$5"
    local line=""
    local in_section=0
    local inserted=0

    _coach_print_text_replacement() {
        if [[ "$inserted" -eq 1 ]]; then
            return 0
        fi
        printf '%s\n' "$section_heading"
        if [[ -n "$section_body" ]]; then
            printf '%s\n' "$section_body"
        fi
        inserted=1
        return 0
    }

    while IFS= read -r line; do
        if [[ "$in_section" -eq 1 ]]; then
            if _coach_line_is_heading "$line"; then
                in_section=0
            else
                continue
            fi
        fi

        if _coach_line_has_prefix "$line" "$section_prefix"; then
            _coach_print_text_replacement
            in_section=1
            continue
        fi

        if [[ "$inserted" -eq 0 ]] && _coach_line_equals_heading "$line" "$insert_before_heading"; then
            _coach_print_text_replacement
        fi

        printf '%s\n' "$line"
    done <<< "$response"

    if [[ "$inserted" -eq 0 ]]; then
        _coach_print_text_replacement
    fi

    unset -f _coach_print_text_replacement
}

# Fallback builders keep each flow useful even when AI is off or unavailable.



_coach_drive_snippet_block() {
    local digest="$1"
    if [[ -z "$digest" ]]; then
        return 0
    fi
    local drive_top_file_name
    local drive_top_file_snippet_b64
    local snippet

    drive_top_file_name=$(_coach_digest_line_value "$digest" "drive_top_file_name")
    drive_top_file_snippet_b64=$(_coach_digest_line_value "$digest" "drive_top_file_snippet_b64")

    if [[ -n "$drive_top_file_snippet_b64" && "$drive_top_file_snippet_b64" != "none" ]]; then
        snippet=$(printf '%s' "$drive_top_file_snippet_b64" | _coach_base64_decode 2>/dev/null || true)
        snippet=${snippet%$'\n'}
        if [[ -n "$snippet" ]]; then
            [[ -n "$drive_top_file_name" && "$drive_top_file_name" != "none" ]] || drive_top_file_name="Recent Google Drive document"
            printf '\n### Recent Google Drive Document Excerpt: %s\n````text\n%s\n````\n' "$drive_top_file_name" "$snippet"
        fi
    fi
}
