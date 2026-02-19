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
readonly _COACH_PROMPTS_LOADED=true

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
