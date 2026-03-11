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
    local custom_traps=""
    if [[ -n "${DATA_DIR:-}" ]] && [[ -f "$DATA_DIR/traps.txt" ]]; then
        custom_traps=$(cat "$DATA_DIR/traps.txt" 2>/dev/null || echo "(none defined)")
    fi

    cat <<EOF
Produce a high-signal morning execution guide for a user with brain fog.
Prioritize clarity, momentum, anti-tinkering boundaries, and health-aware pacing.
Use the provided behavior digest as ground truth for what is working vs drift.
Treat the declared focus and non-fork GitHub activity as the primary evidence of the spear.
Treat top tasks and journal context as secondary scope-sharpeners only.

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

Behavioral Interventions (use if triggered by digest):
- If stale_tasks > 4, suggest a "triage block" to clear old items.
- If dir_switches > 80, suggest a "single-project lock" for the first 2 hours.
- If afternoon_slump=true or "afternoon energy slump detected" is present, preemptively suggest shorter task blocks and an explicit break after 2pm.
- If suggestion_adherence is low, simplify your Do Next suggestions and ask if the tasks feel realistic.
- If suggestion_adherence_rate < 50% over multiple samples, ask for one reason yesterday's plan failed and reduce tomorrow to one locked must-do.
- If "late night commits detected" is present, flag it as a drift risk and ask if it was intentional or hyperfocus.

Personalized traps to avoid:
${custom_traps:-"(none defined)"}

Coach mode semantics:
- LOCKED: no side quests until done condition is met.
- OVERRIDE: allow one bounded exploration block, then return to locked plan.
- RECOVERY: aggressive simplicity. Enforce resting constraints, strip down tasks to 1-2 bare minimums, no high-cognitive-load planning.

Action-source rules:
- Use Today's focus as the PRIMARY source for Do Next actions.
- Use Top tasks only when they sharpen or restate the focus; they are secondary and may be ignored if stale or off-spear.
- Use yesterday commits and recent pushes to infer likely repo continuity and momentum, but do not invent new work from them.
- Journal entries are drift context only (for Operating insight/Evidence check), not action selection.
- If focus and top tasks are misaligned, Do Next step 1 must be to reconcile task order/scope around the focus rather than expanding scope.

Output format (strict, no extra sections):
Briefing Summary:
- 3-5 bullet points covering: yesterday's momentum, today's focus alignment, current energy/health signal, top risk, and one quick win available. Synthesize across inputs; do not restate any single input section verbatim.
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
Signal confidence:
- HIGH, MEDIUM, or LOW based on how much evidence was available. If LOW, name which data sources (commits, journal, health, tasks, digest) were absent.
Evidence check:
- One line naming exact commits/tasks/journal/metrics cues used.

Constraints:
- Total 250-350 words.
- No markdown headers, bold text, separators, or concluding paragraph.
- Keep language operational and specific; avoid generic motivation.
- If signal is missing, say so briefly instead of inventing details.
- Do Next must be grounded in today's focus and listed top tasks.
- Do Next steps must quote or closely paraphrase actual task text from Top tasks. Do not rephrase tasks into implementation language the user did not use.
- When Top tasks are absent, stale, or misaligned, ground Do Next directly in the focus text and Git momentum instead of inventing task prose.
- Do not invent new repositories, modules, endpoints, files, APIs, or projects unless those exact items appear in today's focus or top tasks.
- If focus and top tasks conflict, step 1 must reconcile them (for example: update top task order or capture a scoped task), not invent a new implementation track.
- Data-quality flags (e.g., dir_usage_malformed, malformed lines) are diagnostic metadata for system health, not actionable risks for the user. Do not surface them as top risks or action items.
- Evidence check must only cite cues that are explicitly present in the provided context.
- Do Next must not reference commit hashes or journal-only details.
- If the behavior digest includes `focus_git_status`, `primary_repo`, or `commit_coherence`, use those as the primary grounding cues for working vs drift.
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
    local custom_traps=""
    if [[ -n "${DATA_DIR:-}" ]] && [[ -f "$DATA_DIR/traps.txt" ]]; then
        custom_traps=$(cat "$DATA_DIR/traps.txt" 2>/dev/null || echo "(none defined)")
    fi

    cat <<EOF
Produce a reflective daily coaching summary for a user managing brain fog and fatigue.
Use the behavior digest and today's evidence to identify what worked, where drift happened, and how to lock tomorrow.
Always include health/energy context.
Judge the day primarily against the declared focus and non-fork GitHub evidence.
Treat completed tasks and journal entries as secondary explanation layers, not the main verdict source.

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

Behavioral Interventions (use if triggered by digest):
- If dir_switches > 80, diagnose lack of flow state and suggest a "single-project lock" setup for tomorrow.
- If stale_tasks > 4, point out task accumulation and suggest a "triage block" tomorrow morning.
- If afternoon_slump=true or "afternoon energy slump detected" is present, note it as an exhaustion pattern and suggest better pacing tomorrow.
- If suggestion_adherence_rate < 50% over multiple samples, call out that plans may be too ambitious and tighten tomorrow's scope.
- If "late night commits detected" is present, gently point out that hyperfocus is cutting into sleep and recovery.

Personalized traps to avoid:
${custom_traps:-"(none defined)"}

Coach mode semantics:
- LOCKED: no side quests until done condition is met.
- OVERRIDE: allow one bounded exploration block, then return to locked plan.
- RECOVERY: aggressive simplicity. Enforce resting constraints, strip down tasks to 1-2 bare minimums, no high-cognitive-load planning.

Output format (strict, no extra sections):
Reflection Summary:
- 3-5 bullet points covering: key accomplishment, focus-to-Git alignment, energy trajectory, main drift event, and tomorrow's setup. Synthesize across inputs; do not restate any single input section verbatim.
What worked:
- 1-2 lines anchored to concrete evidence.
Where drift happened:
- 1-2 lines on off-rails patterns or distraction loops.
Likely trigger:
- One probable trigger for drift based on evidence.
Pattern watch:
- One line noting any recurring pattern visible across recent days (e.g., "third consecutive day with context-switching drift after 2pm"). Only include if behavior digest supports it; otherwise say "not enough data for pattern detection."
Tomorrow lock:
- One locked first move, one done condition, and one anti-tinker boundary.
Health lens:
- Always include energy/fog/spoon-aware pacing guidance.
Signal confidence:
- HIGH, MEDIUM, or LOW based on how much evidence was available. If LOW, name which data sources (commits, journal, health, tasks, digest) were absent.
Evidence used:
- One line naming exact commits/tasks/journal/metrics cues used.

Constraints:
- Total 280-400 words.
- Reflective summary tone, operationally useful.
- No markdown headers, bold text, separators, or concluding paragraph.
- If data is sparse, say so briefly instead of inventing details.
- Make the main verdict about whether the spear moved, stalled, or diffused based on focus plus Git evidence.
- Prefer commit/repo evidence over task/journal evidence when they conflict.
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
    elif [[ "$mode_upper" == "RECOVERY" ]]; then
        anti_tinker_rule="Strictly limit to 1-2 bare minimum tasks. Do not start high-cognitive-load planning."
    else
        anti_tinker_rule="No side-quest work until Step 3 is complete and logged."
    fi

    cat <<EOF
Briefing Summary:
- Coach mode: ${mode_upper}. Focus: ${focus:-"(no focus set)"}.
- AI coaching was ${reason}; using deterministic fallback structure.
- First task from your list: ${first_task}.
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
- Use short blocks with a break; pause if energy drops under ${COACH_LOW_ENERGY_THRESHOLD} or fog rises above ${COACH_HIGH_FOG_THRESHOLD}.
Signal confidence:
- LOW (AI ${reason}; fallback uses only focus, top tasks, and mode).
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
    elif [[ "$mode_upper" == "RECOVERY" ]]; then
        tomorrow_boundary="Aggressive simplicity. Restrict to bare minimum tasks, delay anything complex."
    else
        tomorrow_boundary="No side quests before the first locked task block is completed and logged."
    fi

    cat <<EOF
Reflection Summary:
- Coach mode: ${mode_upper}. Focus: ${focus:-"(no focus set)"}.
- AI reflection was ${reason}; using deterministic fallback structure.
- End-of-day context was captured, preserving continuity for tomorrow.
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
Pattern watch:
- Not enough data for pattern detection (fallback mode).
Signal confidence:
- LOW (AI ${reason}; fallback uses only focus, mode, and completed tasks).
Evidence used:
- Deterministic fallback (${reason}) using today's focus, completed tasks, journal entries, and behavioral digest metrics.
EOF
}
