#!/usr/bin/env bash
# scripts/lib/coach_prebrief.sh
# Interactive pre-brief question flow for daily coaching.
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_COACH_PREBRIEF_LOADED:-}" ]]; then
    return 0
fi
readonly _COACH_PREBRIEF_LOADED=true

_coach_prebrief_attempt_limit() {
    local value="${AI_COACH_PREBRIEF_MAX_ATTEMPTS:-3}"

    if ! [[ "$value" =~ ^[1-9]$ ]]; then
        value=3
    fi
    printf '%s' "$value"
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

_coach_prebrief_real_risk_from_digest() {
    local digest="$1"
    local latest_energy=""
    local latest_fog=""

    latest_energy=$(_coach_prebrief_digest_line_value "$digest" "latest_energy")
    latest_fog=$(_coach_prebrief_digest_line_value "$digest" "latest_fog")

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

_coach_prebrief_digest_inline_value() {
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

_coach_prebrief_digest_line_value() {
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

_coach_prebrief_trim_ascii_whitespace() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
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
        focus_git_status=$(_coach_prebrief_digest_inline_value "$behavior_digest" "focus_git_status")
        active_repos=$(_coach_prebrief_digest_inline_value "$behavior_digest" "active_repos")
        primary_repo=$(_coach_prebrief_digest_inline_value "$behavior_digest" "primary_repo")
        latest_energy=$(_coach_prebrief_digest_line_value "$behavior_digest" "latest_energy")
        latest_fog=$(_coach_prebrief_digest_line_value "$behavior_digest" "latest_fog")
        real_risk=$(_coach_prebrief_real_risk_from_digest "$behavior_digest" 2>/dev/null || true)
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

        line=$(_coach_prebrief_trim_ascii_whitespace "$line")
        [[ -z "$line" ]] && continue
        if [[ "$line" =~ ^([0-9]+)([A-Ea-e])(.*)$ ]]; then
            question_index="${BASH_REMATCH[1]}"
            answer_letter=$(printf '%s' "${BASH_REMATCH[2]}" | tr '[:lower:]' '[:upper:]')
            answer_tail=$(_coach_prebrief_trim_ascii_whitespace "${BASH_REMATCH[3]}")
            answer_tail="${answer_tail#:}"
            answer_tail=$(_coach_prebrief_trim_ascii_whitespace "$answer_tail")
            if [[ "$answer_tail" == \(* && "$answer_tail" == *\) ]]; then
                answer_tail="${answer_tail#\(}"
                answer_tail="${answer_tail%\)}"
                answer_tail=$(_coach_prebrief_trim_ascii_whitespace "$answer_tail")
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
        raw_answers=$(_coach_prebrief_trim_ascii_whitespace "$raw_answers")
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
