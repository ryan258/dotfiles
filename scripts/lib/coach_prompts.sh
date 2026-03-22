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

_coach_reason_label() {
    local reason="${1:-unavailable}"
    case "$reason" in
        ungrounded-actions)
            printf '%s\n' "AI briefing failed evidence check"
            ;;
        ungrounded-status)
            printf '%s\n' "AI status coach failed evidence check"
            ;;
        ungrounded-reflection)
            printf '%s\n' "AI reflection failed evidence check"
            ;;
        dispatcher-missing)
            printf '%s\n' "dispatcher missing"
            ;;
        *)
            printf '%s\n' "$reason"
            ;;
    esac
}

coach_build_startday_prompt() {
    local focus_context="$1"
    local coach_mode="$2"
    local yesterday_commits="$3"
    local recent_pushes="$4"
    local behavior_digest="$5"
    local custom_traps=""
    if [[ -n "${DATA_DIR:-}" ]] && [[ -f "$DATA_DIR/traps.txt" ]]; then
        custom_traps=$(cat "$DATA_DIR/traps.txt" 2>/dev/null || echo "(none defined)")
    fi

    cat <<EOF
Produce a high-signal morning execution guide for a user with brain fog.
Prioritize clarity, momentum, and health-aware pacing. Empathize with and validate their natural ADHD-driven exploration.
Use the provided behavior digest as ground truth for what is working. DO NOT shame "drift"—treat deviation as natural exploration of what they are drawn to.
Treat the declared focus and non-fork GitHub activity as the primary evidence of the spear, but firmly accept that working on other projects is valid.
Treat GitHub projects and recent commit activity as a map of their interests. Do NOT frame other repos as "neglected" or treat them as chores that "need attention."
Keep journals and todos out of coaching; they remain local notes, not planning input.

Today's focus:
${focus_context:-"(no focus set)"}

Coach mode for today:
${coach_mode:-LOCKED}

Yesterday's commits:
${yesterday_commits:-"(none)"}

Recent GitHub pushes (last 7 days):
${recent_pushes:-"(none)"}

Behavior digest:
${behavior_digest:-"(none)"}

Behavioral Interventions (use if triggered by digest):
- If stale_tasks > 4, suggest a "triage block" to clear old items.
- If dir_switches > 80, suggest a "single-project lock" for the first 2 hours.
- If afternoon_slump=true or "afternoon energy slump detected" is present, preemptively suggest shorter task blocks and an explicit break after 2pm.
- If suggestion_adherence is low, simplify your Do Next suggestions and ask if the tasks feel realistic.
- If suggestion_adherence_rate < 50% over multiple samples, ask for one reason yesterday's plan failed and reduce tomorrow to one locked must-do.
- If "late night commits detected" is present, note it as a possible hyperfocus signal and ask if it was intentional or something that pulled them in.

Personalized traps to avoid:
${custom_traps:-"(none defined)"}

Coach mode semantics:
- LOCKED: primary energy stays on declared focus; side-quest ideas get noted in a parking lot for later.
- FLOW: follow your energy, but check in before switching repos. If a new thread is compelling, name it and timebox it before diving in.
- OVERRIDE: allow one bounded exploration block, then return to locked plan.
- RECOVERY: aggressive simplicity. Enforce resting constraints, strip down tasks to 1-2 bare minimums, no high-cognitive-load planning.

Mode check:
- If digest metrics suggest a different mode than what was declared, recommend a switch. Signals: spoon budget <= 4 or fog >= 7 → suggest RECOVERY; late-night commits + low spoons → suggest RECOVERY; high dir_switches + scattered repos → suggest LOCKED; strong single-repo momentum → suggest FLOW. Only suggest if the evidence is clear; otherwise affirm the current mode.

Action-source rules:
- Use Today's focus as the PRIMARY source for Do Next actions.
- Use yesterday commits and recent pushes to infer likely repo continuity, blindspots, and adjacent enhancement opportunities, but do not invent new work from them.
- Do not use journals or todos for action selection, evidence checks, or momentum claims.
- Use recent repo names and commit-message patterns to surface 10 blindspots, side-quests, or enhancement opportunities. Frame these purely as optional explorations they might enjoy, NOT as overdue chores.

Output format (strict, no extra sections):
Briefing Summary:
- 4-5 bullet points covering: yesterday's momentum, today's focus alignment, current energy/health signal, and top risk. Synthesize across inputs; do not restate any single input section verbatim.
GitHub blindspots/opportunities (1-10):
1. First concise, GitHub-grounded blindspot or enhancement opportunity.
2. Second concise, GitHub-grounded blindspot or enhancement opportunity.
3. Third concise, GitHub-grounded blindspot or enhancement opportunity.
4. Fourth concise, GitHub-grounded blindspot or enhancement opportunity.
5. Fifth concise, GitHub-grounded blindspot or enhancement opportunity.
6. Sixth concise, GitHub-grounded blindspot or enhancement opportunity.
7. Seventh concise, GitHub-grounded blindspot or enhancement opportunity.
8. Eighth concise, GitHub-grounded blindspot or enhancement opportunity.
9. Ninth concise, GitHub-grounded blindspot or enhancement opportunity.
10. Tenth concise, GitHub-grounded blindspot or enhancement opportunity.
North Star:
- One sentence practical outcome for today.
Do Next (ordered 1-3):
1. First 10-15 minute action mapped directly to focus text and/or the provided GitHub activity.
2. Second action after step 1.
3. Done condition for today.
Operating insight (momentum + exploration):
- One line naming what is working and one observation on exploration patterns from digest metrics, framed positively.
Scope anchor:
- One explicit boundary rule for this mode.
Health lens:
- Always include energy/fog/spoon-aware pacing guidance with a specific timer command. Pick the right tool for the context:
  - LOCKED/FLOW mode focus blocks: suggest "Run: pomo" (25-min Pomodoro timer with break notification)
  - Longer focus sessions: suggest "Run: remind '+45m' 'Body check: stretch, hydrate, check numbness/vision/heat'"
  - RECOVERY mode gentle pacing: suggest "Run: tbreak 10" (short break timer)
  - If active_timer in the digest shows 2+ hours: urgently suggest "Run: tbreak 5" NOW for an immediate body check
- ADHD time blindness means internal clocks are unreliable — always include a concrete command, never just say "set a timer."
Signal confidence:
- HIGH, MEDIUM, or LOW based on how much evidence was available. If LOW, name which data sources (commits, health, digest) were absent.
Evidence check:
- One line naming exact commit/repo/metric cues used.
Mode suggestion:
- If digest signals suggest a different mode, say "Consider switching to [MODE] because [reason]." If the current mode fits, say "Current mode looks right" and briefly say why.

Constraints:
- Total 450-700 words.
- No markdown headers, bold text, separators, or concluding paragraph.
- Keep language operational and specific; avoid generic motivation.
- If signal is missing, say so briefly instead of inventing details.
- Do Next must be grounded in today's focus and listed GitHub activity.
- Do not use todo items, completed tasks, or journal notes as evidence or action anchors.
- If the focus is broad and does not name a concrete asset, page, file, or deliverable, do not invent one. Step 1 should capture or choose the next concrete move before execution begins.
- Do not invent new repositories, modules, endpoints, files, APIs, or projects unless those exact items appear in today's focus or provided GitHub activity.
- Do not invent page names, paragraphs, homepage sections, drafts, or publication status unless those exact items appear in today's focus or provided GitHub activity.
- Data-quality flags (e.g., dir_usage_malformed, malformed lines) are diagnostic metadata for system health, not actionable risks for the user. Do not surface them as top risks or action items.
- Evidence check must only cite cues that are explicitly present in the provided context.
- Do not mention journal evidence, journal momentum, todo completion, or journaling habits.
- Do Next must not reference commit hashes.
- If the behavior digest includes focus_git_status, primary_repo, or commit_coherence, use those as the primary grounding cues for working vs drift.
- Any blindspot, enhancement opportunity, or project idea must stay adjacent to actual repo names and commit patterns present in the provided GitHub activity.
- The GitHub blindspot/opportunity section must contain exactly 10 numbered lines.
- At least half of the 10 lines must mention a real repo name from the provided GitHub activity when repo names are available.
- RECOVERY mode override: If coach mode is RECOVERY, collapse the output to reduce decision fatigue. Use only 3 blindspots (not 10), only 1 Do Next action (not 3), drop the Scope anchor section entirely, and keep total output under 300 words. The goal is one clear thing to do, not a menu.
EOF
}

coach_build_goodevening_prompt() {
    local coach_mode="$1"
    local focus_context="$2"
    local today_commits="$3"
    local recent_pushes="$4"
    local behavior_digest="$5"
    local custom_traps=""
    if [[ -n "${DATA_DIR:-}" ]] && [[ -f "$DATA_DIR/traps.txt" ]]; then
        custom_traps=$(cat "$DATA_DIR/traps.txt" 2>/dev/null || echo "(none defined)")
    fi

    cat <<EOF
Produce a reflective daily coaching summary for a user managing brain fog and fatigue.
Use the behavior digest and today's evidence to identify what worked, where natural deviation (drift) happened, and how to lock tomorrow.
Validate ADHD-driven exploration. Never shame the user for deviating to work on what they were drawn to.
Always include health/energy context.
Judge the day primarily against the declared focus and non-fork GitHub evidence, but accept changing paths as valid.
If today's commits show a long unbroken stretch in one repo (4+ hours of commits without switching), flag it as a hyperfocus session and ask whether the user remembered to eat, hydrate, move, and check body signals (numbness, vision, heat). Hyperfocus with MS burns spoons invisibly.
Keep journals and todos out of the coaching verdict; they remain local notes for later querying.

Coach mode used today:
${coach_mode:-LOCKED}

Today's focus:
${focus_context:-"(no focus set)"}

Today's commits:
${today_commits:-"(none)"}

Recent GitHub pushes (last 7 days):
${recent_pushes:-"(none)"}

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
- LOCKED: primary energy stays on declared focus; side-quest ideas get noted in a parking lot for later.
- FLOW: follow your energy, but check in before switching repos. If a new thread is compelling, name it and timebox it before diving in.
- OVERRIDE: allow one bounded exploration block, then return to locked plan.
- RECOVERY: aggressive simplicity. Enforce resting constraints, strip down tasks to 1-2 bare minimums, no high-cognitive-load planning.

Tomorrow mode suggestion:
- Based on today's digest, energy trajectory, and patterns, recommend a mode for tomorrow in the output. Signals: low spoons or high fog at end of day → suggest RECOVERY; scattered repos all day → suggest LOCKED; strong single-lane energy → suggest FLOW. Frame it as a suggestion, not a command.

Output format (strict, no extra sections):
Reflection Summary:
- 3-5 bullet points covering: key accomplishment, focus-to-Git alignment, energy trajectory, main exploration detour, and tomorrow's setup. Synthesize across inputs; do not restate any single input section verbatim.
Blindspots to sleep on (1-10):
1. First concise, GitHub-grounded blindspot or enhancement opportunity to revisit tomorrow.
2. Second concise blindspot/opportunity.
3. Third concise blindspot/opportunity.
4. Fourth concise blindspot/opportunity.
5. Fifth concise blindspot/opportunity.
6. Sixth concise blindspot/opportunity.
7. Seventh concise blindspot/opportunity.
8. Eighth concise blindspot/opportunity.
9. Ninth concise blindspot/opportunity.
10. Tenth concise blindspot/opportunity.
What worked:
- 1-2 lines anchored to concrete evidence.
Off-script momentum:
- 1-2 lines observing unexpected exploration, side-quests, or off-script momentum. Frame this neutrally without calling it a "distraction".
What pulled you in:
- One probable reason this direction was compelling, based on evidence.
Pattern watch:
- One line noting any recurring pattern visible across recent days (e.g., "third consecutive day with context-switching drift after 2pm"). Only include if behavior digest supports it; otherwise say "not enough data for pattern detection."
Tomorrow lock:
- One locked first move, one done condition, and one scope anchor boundary.
Health lens:
- Include energy/fog/spoon-aware pacing guidance. When recommending tomorrow's setup, suggest a specific timer command:
  - For focus blocks: "Start tomorrow with: pomo" (25-min Pomodoro)
  - For gentle recovery days: "Pace with: tbreak 10" (10-min break timer)
  - If today showed hyperfocus sessions: "Set a body-check alarm: remind '+90m' 'Body check: stretch, hydrate, check numbness/vision/heat'"
- Always give a concrete command — ADHD time blindness means "set a timer" alone won't happen.
Signal confidence:
- HIGH, MEDIUM, or LOW based on how much evidence was available. If LOW, name which data sources (commits, health, digest) were absent.
Evidence used:
- One line naming exact commit/repo/metrics cues used.
Tomorrow mode suggestion:
- Recommend a coach mode for tomorrow based on today's energy trajectory and patterns (e.g., "Tomorrow try FLOW — your energy was strong and single-lane today"). Frame as a suggestion.

Constraints:
- Total 420-700 words.
- Reflective summary tone, operationally useful.
- No markdown headers, bold text, separators, or concluding paragraph.
- If data is sparse, say so briefly instead of inventing details.
- Make the main verdict about whether the spear moved, stalled, or diffused based on focus plus Git evidence.
- Do not use completed tasks or journal notes as evidence or explanation.
- Prefer commit/repo evidence over local notes when they conflict.
- The blindspot section must contain exactly 10 numbered lines.
- At least half of the 10 lines must mention a real repo name from today's commits or recent pushes when repo names are available.
- RECOVERY mode override: If coach mode is RECOVERY, collapse the output to reduce decision fatigue. Use only 3 blindspots (not 10), shorten Reflection Summary to 2-3 bullets, drop Pattern watch, and keep total output under 300 words. Focus on one win and one thing for tomorrow.
EOF
}

coach_build_status_prompt() {
    local coach_mode="$1"
    local focus_context="$2"
    local today_commits="$3"
    local recent_pushes="$4"
    local behavior_digest="$5"
    local current_dir="$6"
    local project_context="$7"
    local context_scope="${8:-global}"

    cat <<EOF
Produce a concise mid-day recenter coaching brief for a user managing brain fog and fatigue. Validate their ADHD exploration style.
Use declared focus and non-fork GitHub activity as the primary evidence of whether the spear is moving, while accepting that natural deviation is valid.
Treat GitHub projects and recent commit/push activity as a map of their interests. Do not frame other repos as chores that "need attention."
Keep journals and todos out of coaching; they remain local notes for later querying.
Bias toward one immediate action that can be started right now.
If today's commits show sustained single-repo activity over many hours, add a body-check nudge: "You've been deep in [repo] — check in with your body (numbness, vision, heat, hunger, hydration)." Hyperfocus with MS can silently burn spoons.

Coach mode for today:
${coach_mode:-LOCKED}

Coach mode semantics:
- LOCKED: primary energy stays on declared focus; side-quest ideas get noted in a parking lot for later.
- FLOW: follow your energy, but check in before switching repos. If a new thread is compelling, name it and timebox it before diving in.
- OVERRIDE: allow one bounded exploration block, then return to locked plan.
- RECOVERY: aggressive simplicity. Enforce resting constraints, strip down tasks to 1-2 bare minimums, no high-cognitive-load planning.

Mode check:
- If digest metrics suggest a different mode than what was declared, recommend a switch in the Mode suggestion output section. Signals: spoon budget <= 4 or fog >= 7 → suggest RECOVERY; late-night commits + low spoons → suggest RECOVERY; high dir_switches + scattered repos → suggest LOCKED; strong single-repo momentum → suggest FLOW. Only suggest if the evidence is clear; otherwise affirm the current mode.

Today's focus:
${focus_context:-"(no focus set)"}

Today's commits:
${today_commits:-"(none)"}

Recent GitHub pushes (last 7 days):
${recent_pushes:-"(none)"}

Behavior digest:
${behavior_digest:-"(none)"}

Current directory:
${current_dir:-"(unknown)"}

Current project context:
${project_context:-"(none)"}

Context scope:
${context_scope:-global}

Output format (strict, no extra sections):
Briefing Summary:
- 3-4 bullets covering: current GitHub lane, exploration patterns, best immediate opening, and one project/blindspot insight. Synthesize across inputs; do not restate any single input section verbatim.
GitHub blindspots/opportunities (1-10):
1. First concise, GitHub-grounded blindspot or enhancement opportunity.
2. Second concise, GitHub-grounded blindspot or enhancement opportunity.
3. Third concise, GitHub-grounded blindspot or enhancement opportunity.
4. Fourth concise, GitHub-grounded blindspot or enhancement opportunity.
5. Fifth concise, GitHub-grounded blindspot or enhancement opportunity.
6. Sixth concise, GitHub-grounded blindspot or enhancement opportunity.
7. Seventh concise, GitHub-grounded blindspot or enhancement opportunity.
8. Eighth concise, GitHub-grounded blindspot or enhancement opportunity.
9. Ninth concise, GitHub-grounded blindspot or enhancement opportunity.
10. Tenth concise, GitHub-grounded blindspot or enhancement opportunity.
North Star:
- One sentence describing what matters for the next block of work.
Do Next (ordered 1-3):
1. First 10-15 minute action that can be started immediately.
2. Second action that stays inside the same repo/focus lane.
3. Done condition for this recenter block.
Operating insight (momentum + exploration):
- One line naming what is working and what could derail the next block, without calling natural exploration a "distraction."
Scope anchor:
- One explicit repo-switching or scope-switching boundary.
Health lens:
- One short pacing note that respects energy/fog/spoons if the digest supports it. Always include a specific timer command:
  - LOCKED/FLOW mode: "Run: pomo" (25-min focus block with notification)
  - RECOVERY mode: "Run: tbreak 10" (gentle 10-min break timer)
  - If active_timer shows 2+ hours: "Run: tbreak 5" NOW — body check is overdue
  - For body-check reminders: "Run: remind '+45m' 'Body check: stretch, hydrate, check numbness/vision/heat'"
  - Never just say "set a timer" — give the exact command. ADHD time blindness means it won't happen otherwise.
Signal confidence:
- HIGH, MEDIUM, or LOW based on how much GitHub and digest evidence was available.
Evidence check:
- One line naming exact repo/commit/metric cues used.
Mode suggestion:
- If digest signals suggest a different mode, say "Consider switching to [MODE] because [reason]." If the current mode fits, say "Current mode looks right" and briefly say why.

Constraints:
- Total 280-520 words.
- Keep language operational and immediate; avoid reflection-heavy tone.
- If signal is missing, say so briefly instead of inventing details.
- Do Next must be grounded in today's focus, today's commits, recent pushes, and current project context when present.
- Do not use journal notes, todo items, completed tasks, or vague productivity language as evidence.
- Do not invent new repositories, modules, pages, endpoints, or publish states unless those exact items appear in the provided GitHub activity or focus text.
- If Context scope is repo-local, keep repo commentary, blindspots, and actions inside Current project context; do not widen back out to other repos.
- If Context scope is global, synthesize across the visible repo set and name the most likely lane.
- The GitHub blindspot/opportunity section must contain exactly 10 numbered lines.
- At least half of the 10 lines must mention a real repo name from today's commits or recent pushes when repo names are available.
- RECOVERY mode override: If coach mode is RECOVERY, collapse the output to reduce decision fatigue. Use only 3 blindspots (not 10), only 1 Do Next action (not 3), drop the Scope anchor section entirely, and keep total output under 250 words. One clear action, nothing else.
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
    local limit=10
    local commit_coherence_value="N/A"

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
            candidates=$(_coach_append_unique_candidate "$candidates" "Recent work is feature-heavy across ${repo_summary}; turn one shipped change into a write-up, changelog, or demo angle instead of starting from a blank page.")
        else
            candidates=$(_coach_append_unique_candidate "$candidates" "Recent work is feature-heavy across ${repo_summary}; docs, demo, or polish work is likely lagging behind shipping.")
        fi
    fi

    if [[ "$focus_git_status" == "diffuse" ]] && [[ "${active_repos:-0}" =~ ^[0-9]+$ ]] && [[ "${active_repos:-0}" -ge 3 ]]; then
        candidates=$(_coach_append_unique_candidate "$candidates" "Breadth across ${active_repos} repos may be outrunning finish work; pick one repo to deepen instead of spreading more feature work.")
    fi

    if [[ -n "$primary_repo" && "$primary_repo" != "N/A" ]]; then
        candidates=$(_coach_append_unique_candidate "$candidates" "Use ${primary_repo} as the candidate for a small polish pass before opening a new lane.")
    fi

    if [[ "${commit_coherence:-}" =~ ^[0-9]+$ ]] && [[ "${commit_coherence:-0}" -lt 40 ]] && [[ "${total_commits:-0}" -gt 0 ]]; then
        candidates=$(_coach_append_unique_candidate "$candidates" "Commit language is only ${commit_coherence_value}% aligned with the declared focus; either tighten the work around the focus or rename the focus to match the real lane.")
    fi

    if [[ "${polish_commits:-0}" -eq 0 ]] && [[ "${total_commits:-0}" -gt 0 ]]; then
        candidates=$(_coach_append_unique_candidate "$candidates" "Recent commit language shows almost no docs, demo, or test cues; quality and legibility work may be hiding behind feature momentum.")
    fi

    if [[ -n "$focus_git_reason" ]]; then
        candidates=$(_coach_append_unique_candidate "$candidates" "Focus-vs-Git drift summary: ${focus_git_reason}; treat that as an input to prune one lane, not as background noise.")
    fi

    if _coach_focus_is_contentish "$focus" && [[ -n "$repo_summary" ]]; then
        candidates=$(_coach_append_unique_candidate "$candidates" "Your content focus can mine ${repo_summary} for a before/after story, a lessons-learned post, or a command-sheet artifact.")
    fi

    for repo in $repos_blob; do
        candidates=$(_coach_append_unique_candidate "$candidates" "Repo ${repo} likely wants a short demo, screenshot, or walkthrough so the newest capability is legible without code-reading.")
    done
    for repo in $repos_blob; do
        candidates=$(_coach_append_unique_candidate "$candidates" "Repo ${repo} is a candidate for a README or changelog pass tied directly to the newest change.")
    done
    for repo in $repos_blob; do
        candidates=$(_coach_append_unique_candidate "$candidates" "Repo ${repo} may have one onboarding or setup friction point worth removing before adding more features.")
    done
    for repo in $repos_blob; do
        candidates=$(_coach_append_unique_candidate "$candidates" "Repo ${repo} is worth scanning for one reusable script, pattern, or helper that could be extracted instead of staying one-off.")
    done
    for repo in $repos_blob; do
        candidates=$(_coach_append_unique_candidate "$candidates" "Repo ${repo} may need a stability or test pass before the next feature wave lands.")
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

_coach_clean_blindspot_section() {
    local existing_lines="$1"
    local grounded_scan="$2"
    local limit="${3:-10}"
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

coach_sanitize_startday_blindspots() {
    local response="$1"
    local focus="$2"
    local behavior_digest="${3:-}"
    local commit_context="${4:-}"
    local focus_git_status=""
    local primary_repo=""
    local primary_repo_share=""
    local commit_coherence=""
    local active_repos=""
    local focus_git_reason=""
    local repo_summary=""
    local grounded_scan=""
    local existing_lines=""
    local cleaned_lines=""

    if [[ -n "$behavior_digest" ]]; then
        focus_git_status=$(_coach_digest_inline_value "$behavior_digest" "focus_git_status")
        primary_repo=$(_coach_digest_inline_value "$behavior_digest" "primary_repo")
        primary_repo_share=$(_coach_digest_inline_value "$behavior_digest" "primary_repo_share")
        commit_coherence=$(_coach_digest_inline_value "$behavior_digest" "commit_coherence")
        active_repos=$(_coach_digest_inline_value "$behavior_digest" "active_repos")
        focus_git_reason=$(_coach_digest_line_value "$behavior_digest" "focus_git_reason")
    fi
    repo_summary=$(_coach_commit_repo_summary "$commit_context")
    grounded_scan=$(_coach_github_blindspot_scan "$focus" "$commit_context" "$focus_git_status" "$primary_repo" "$primary_repo_share" "$commit_coherence" "$active_repos" "$focus_git_reason" "$repo_summary")
    existing_lines=$(_coach_extract_numbered_section_lines "$response" "GitHub blindspots/opportunities")
    cleaned_lines=$(_coach_clean_blindspot_section "$existing_lines" "$grounded_scan" 10)
    _coach_replace_or_insert_numbered_section "$response" "GitHub blindspots/opportunities" "GitHub blindspots/opportunities (1-10):" "North Star:" "$cleaned_lines"
}

coach_sanitize_goodevening_blindspots() {
    local response="$1"
    local focus="$2"
    local behavior_digest="${3:-}"
    local commit_context="${4:-}"
    local focus_git_status=""
    local primary_repo=""
    local primary_repo_share=""
    local commit_coherence=""
    local active_repos=""
    local focus_git_reason=""
    local repo_summary=""
    local grounded_scan=""
    local existing_lines=""
    local cleaned_lines=""

    if [[ -n "$behavior_digest" ]]; then
        focus_git_status=$(_coach_digest_inline_value "$behavior_digest" "focus_git_status")
        primary_repo=$(_coach_digest_inline_value "$behavior_digest" "primary_repo")
        primary_repo_share=$(_coach_digest_inline_value "$behavior_digest" "primary_repo_share")
        commit_coherence=$(_coach_digest_inline_value "$behavior_digest" "commit_coherence")
        active_repos=$(_coach_digest_inline_value "$behavior_digest" "active_repos")
        focus_git_reason=$(_coach_digest_line_value "$behavior_digest" "focus_git_reason")
    fi
    repo_summary=$(_coach_commit_repo_summary "$commit_context")
    grounded_scan=$(_coach_github_blindspot_scan "$focus" "$commit_context" "$focus_git_status" "$primary_repo" "$primary_repo_share" "$commit_coherence" "$active_repos" "$focus_git_reason" "$repo_summary")
    existing_lines=$(_coach_extract_numbered_section_lines "$response" "Blindspots to sleep on")
    cleaned_lines=$(_coach_clean_blindspot_section "$existing_lines" "$grounded_scan" 10)
    _coach_replace_or_insert_numbered_section "$response" "Blindspots to sleep on" "Blindspots to sleep on (1-10):" "What worked:" "$cleaned_lines"
}

coach_sanitize_status_repo_scope() {
    local response="$1"
    local focus="$2"
    local project_context="$3"
    local context_scope="${4:-global}"
    local focus_label=""
    local do_next_lines=""
    local anti_tinker_line=""
    local scoped_response=""

    if [[ "$context_scope" != "repo-local" ]]; then
        printf '%s\n' "$response"
        return 0
    fi
    if [[ -z "$project_context" || "$project_context" == "(no project context)" ]]; then
        printf '%s\n' "$response"
        return 0
    fi

    focus_label="${focus:-current work}"
    do_next_lines=$(cat <<EOF
1. Pick one concrete next move inside ${project_context} that advances ${focus_label}, then start it now.
2. Keep the same ${project_context} repo open for one more short block before switching lanes.
3. Done when one focused block lands in ${project_context} and the next move is still obvious.
EOF
)
    anti_tinker_line="- Do not leave ${project_context} until Step 3 is complete or you explicitly decide to change the repo-local lane."

    scoped_response=$(_coach_replace_or_insert_text_section "$response" "Do Next" "Do Next (ordered 1-3):" "Operating insight:" "$do_next_lines")
    _coach_replace_or_insert_text_section "$scoped_response" "Scope anchor" "Scope anchor:" "Health lens:" "$anti_tinker_line"
}

coach_status_fallback_output() {
    local focus="$1"
    local mode="$2"
    local reason="${3:-unavailable}"
    local behavior_digest="${4:-}"
    local git_context="${5:-}"
    local current_dir="${6:-}"
    local project_context="${7:-}"
    local reason_detail="${8:-}"
    local context_scope="${9:-global}"
    local reason_label=""
    local focus_label=""
    local mode_upper=""
    local focus_git_status=""
    local primary_repo=""
    local primary_repo_share=""
    local commit_coherence=""
    local active_repos=""
    local focus_git_reason=""
    local repo_summary=""
    local github_opportunity_line=""
    local blindspot_scan=""
    local current_project_label=""
    local summary_project_line=""
    local repo_local_scope_line=""
    local step_one=""
    local step_two=""
    local step_three=""
    local working_signal="focus is declared but the next move still needs to be locked"
    local drift_risk="repo drift will keep compounding until one lane is chosen"
    local anti_tinker_rule="No repo switch until Step 3 is complete."
    local health_lens="Use one short block, then reassess energy and fog before broadening scope."
    local evidence_sources="focus"
    local signal_confidence="LOW"
    local reason_line=""
    local reason_detail_line=""
    local working_signal_cap=""

    focus_label="${focus:-"(no focus set)"}"
    mode_upper=$(printf '%s' "${mode:-LOCKED}" | tr '[:lower:]' '[:upper:]')
    reason_label=$(_coach_reason_label "$reason")
    repo_summary=$(_coach_commit_repo_summary "$git_context")
    current_project_label="${project_context:-"(no project context)"}"

    if [[ -n "$behavior_digest" ]]; then
        focus_git_status=$(_coach_digest_inline_value "$behavior_digest" "focus_git_status")
        primary_repo=$(_coach_digest_inline_value "$behavior_digest" "primary_repo")
        primary_repo_share=$(_coach_digest_inline_value "$behavior_digest" "primary_repo_share")
        commit_coherence=$(_coach_digest_inline_value "$behavior_digest" "commit_coherence")
        active_repos=$(_coach_digest_inline_value "$behavior_digest" "active_repos")
        focus_git_reason=$(_coach_digest_line_value "$behavior_digest" "focus_git_reason")
    fi

    if [[ -n "$repo_summary" ]]; then
        working_signal="today's visible GitHub lane is ${repo_summary}"
        evidence_sources="${evidence_sources}, repo_summary=${repo_summary}"
    fi
    if [[ "$context_scope" == "repo-local" ]] && [[ -n "$current_project_label" && "$current_project_label" != "(no project context)" ]]; then
        repo_local_scope_line="- Status coach is scoped to the current repo (${current_project_label}), so the next block stays inside that repo unless you deliberately choose to leave it."
        evidence_sources="${evidence_sources}, context_scope=repo-local"
        if [[ -z "$repo_summary" ]]; then
            working_signal="status coach is scoped to ${current_project_label}, even though same-repo GitHub evidence is thin right now"
        fi
        if [[ -z "$focus_git_reason" ]]; then
            drift_risk="switching out of ${current_project_label} before a concrete next move is locked will blur the repo-local context"
        fi
    fi
    if [[ -n "$focus_git_reason" ]]; then
        drift_risk="${focus_git_reason}"
    elif [[ "$focus_git_status" == "diffuse" ]]; then
        drift_risk="recent GitHub activity is spread across multiple repos relative to the declared focus"
    fi

    if [[ -n "$primary_repo" && "$primary_repo" != "N/A" ]]; then
        evidence_sources="${evidence_sources}, primary_repo=${primary_repo}"
        if [[ -n "$current_project_label" && "$current_project_label" != "(no project context)" && "$current_project_label" != "$primary_repo" ]]; then
            summary_project_line="- Current directory is ${current_project_label}, while the primary GitHub lane looks like ${primary_repo}; decide that mismatch explicitly before drifting further."
            drift_risk="${drift_risk}; current directory does not match the primary lane"
        fi
    elif [[ -n "$current_project_label" && "$current_project_label" != "(no project context)" ]]; then
        summary_project_line="- Current directory is ${current_project_label}; use that only if it directly advances the declared focus."
    fi

    github_opportunity_line=$(_coach_github_opportunity_line "$focus_label" "$git_context" "$focus_git_status" "$primary_repo" "$active_repos" "$repo_summary" || true)
    blindspot_scan=$(_coach_github_blindspot_scan "$focus_label" "$git_context" "$focus_git_status" "$primary_repo" "$primary_repo_share" "$commit_coherence" "$active_repos" "$focus_git_reason" "$repo_summary")
    if [[ "$context_scope" == "repo-local" ]] && [[ -n "$current_project_label" && "$current_project_label" != "(no project context)" ]] && [[ -z "$repo_summary" ]]; then
        github_opportunity_line="GitHub blindspot opportunity: ${current_project_label} likely has one visible polish, demo, or packaging gap worth naming before you widen back out to other repos."
        blindspot_scan=$(cat <<EOF
1. Repo ${current_project_label} likely wants one visible polish pass before more feature work is opened elsewhere.
2. Repo ${current_project_label} may have one demo, screenshot, or walkthrough gap that would make the current lane more legible.
3. Repo ${current_project_label} is a candidate for a README or changelog pass tied to the next concrete change.
4. Repo ${current_project_label} may hide one setup or onboarding friction point worth removing before adding scope.
5. Repo ${current_project_label} is worth scanning for one reusable helper or pattern that could be clarified or extracted.
6. Repo ${current_project_label} may benefit from one tight finish-line definition before another repo steals attention.
7. Repo ${current_project_label} is a good place to look for one test, stability, or guardrail pass before more feature work lands.
8. Repo ${current_project_label} may contain one small UX or legibility improvement that would compound quickly.
9. Repo ${current_project_label} is a candidate for one artifact, note, or demo angle that captures what changed.
10. Repo ${current_project_label} likely has one tiny cleanup that would make the current lane easier to resume later.
EOF
)
    fi

    if [[ -n "$github_opportunity_line" ]]; then
        evidence_sources="${evidence_sources}, github_opportunity_scan"
    fi
    if [[ "$context_scope" == "repo-local" ]] && [[ -n "$current_project_label" && "$current_project_label" != "(no project context)" ]] && [[ -z "$repo_summary" ]]; then
        step_one="Pick one concrete next move inside ${current_project_label} that advances ${focus_label}, then start it for 10-15 minutes."
        step_two="Keep the same ${current_project_label} repo open for one more short block before switching lanes."
    elif [[ -n "$repo_summary" ]]; then
        if _coach_focus_is_contentish "$focus_label"; then
            step_one="Turn one real change from ${repo_summary} into one explicit ${focus_label} angle or task, then start it for 10-15 minutes."
            step_two="Stay inside the same repo or content lane for one additional short block before opening anything else."
        else
            step_one="Pick one next visible move inside ${repo_summary} that advances ${focus_label}, then start it for 10-15 minutes."
            step_two="Keep the same repo lane open for one more short block before switching."
        fi
    else
        step_one="Write the next concrete move for ${focus_label}, then start it immediately for 10-15 minutes."
        step_two="If the move is still vague after that block, reduce it to one repo, file, or artifact before continuing."
    fi
    if [[ "$context_scope" == "repo-local" ]] && [[ -n "$current_project_label" && "$current_project_label" != "(no project context)" ]]; then
        anti_tinker_rule="Do not leave ${current_project_label} until Step 3 is complete or you explicitly decide to change the repo-local lane."
    elif [[ -n "$primary_repo" && "$primary_repo" != "N/A" ]]; then
        anti_tinker_rule="Do not switch away from ${primary_repo} until Step 3 is complete or you explicitly decide that today's focus has changed."
    fi
    step_three="Done condition: one focused block lands in the chosen lane and the next move is still obvious without opening a new repo."

    if [[ "$behavior_digest" != "(behavior digest unavailable)" && -n "$behavior_digest" ]]; then
        signal_confidence="MEDIUM"
        if [[ -n "$repo_summary" || -n "$focus_git_reason" ]]; then
            signal_confidence="HIGH"
        fi
    fi

    if [[ "$reason" != "unavailable" && "$reason" != "" ]]; then
        reason_line="- AI status coach was ${reason_label}; using deterministic fallback structure."
    fi
    if [[ -n "$reason_detail" ]]; then
        reason_detail_line="- Fallback detail: ${reason_detail}."
    fi
    working_signal_cap=$(printf '%s' "$working_signal" | awk '{ if (length($0) > 0) { printf "%s%s", toupper(substr($0, 1, 1)), substr($0, 2) } }')

    cat <<EOF | awk 'NF'
Briefing Summary:
- Coach mode: ${mode_upper}. Focus: ${focus_label}.
${reason_line}
- ${working_signal_cap:-$working_signal}.
${repo_local_scope_line}
${summary_project_line}
- ${github_opportunity_line:-GitHub blindspot opportunity: keep the next move anchored to a real repo lane instead of abstract planning.}
${reason_detail_line}
GitHub blindspots/opportunities (1-10):
${blindspot_scan}
North Star:
- Move one GitHub-visible step that matches ${focus_label} before switching lanes.
Do Next (ordered 1-3):
1. ${step_one}
2. ${step_two}
3. ${step_three}
Operating insight (momentum + exploration):
- Working: ${working_signal}. Exploration pattern: ${drift_risk}.
Scope anchor:
- ${anti_tinker_rule}
Health lens:
- ${health_lens}
Signal confidence:
- ${signal_confidence} (fallback uses focus, today's GitHub activity, current project context, and behavior digest when available).
Evidence check:
- Deterministic fallback (${reason_label}) using ${evidence_sources}, context_scope=${context_scope:-global}, current_dir=${current_dir:-"(unknown)"}, current_project=${current_project_label}.
EOF
}

coach_startday_fallback_output() {
    local focus="$1"
    local mode="$2"
    local reason="${3:-unavailable}"
    local behavior_digest="${4:-}"
    local commit_context="${5:-}"
    local reason_detail="${6:-}"
    local reason_label=""
    local reason_phrase=""
    local mode_upper=""
    local anti_tinker_rule=""
    local briefing_scope_line=""
    local briefing_reason_line=""
    local briefing_reason_detail_line=""
    local step_one=""
    local step_two=""
    local step_three=""
    local working_signal="focus is declared"
    local drift_risk="keep scope locked to the declared focus"
    local evidence_sources="focus"
    local focus_git_status=""
    local primary_repo=""
    local primary_repo_share=""
    local commit_coherence=""
    local active_repos=""
    local focus_git_reason=""
    local git_summary="Git focus signal unavailable in fallback context."
    local focus_label="$focus"
    local commit_repo_summary=""
    local commit_summary_line=""
    local github_opportunity_line=""
    local github_blindspot_scan=""
    local fallback_kind="Deterministic fallback"

    if [[ -z "$focus_label" ]]; then
        focus_label="(no focus set)"
    fi
    reason_label=$(_coach_reason_label "$reason")
    reason_phrase="AI ${reason_label}"
    commit_repo_summary=$(_coach_commit_repo_summary "$commit_context")
    mode_upper=$(printf '%s' "$mode" | tr '[:lower:]' '[:upper:]')
    if [[ "$mode_upper" == "OVERRIDE" ]]; then
        anti_tinker_rule="Allow one 15-minute exploration slot only after Step 1, then return to the locked plan."
    elif [[ "$mode_upper" == "RECOVERY" ]]; then
        anti_tinker_rule="Strictly limit to 1-2 bare minimum tasks. Do not start high-cognitive-load planning."
    else
        anti_tinker_rule="No side-quest work until Step 3 is complete and logged."
    fi

    briefing_scope_line="Fallback is grounded in today's focus and recent GitHub activity only."
    step_one="Capture the first concrete move for today's focus (${focus_label}), then spend 10-15 minutes starting it."
    step_two="If the next move is still vague after that block, write one explicit same-focus task before touching another repo or side quest."
    step_three="Done condition: one short focus block is completed and the next concrete move is captured."

    if [[ -n "$commit_repo_summary" ]]; then
        commit_summary_line="Yesterday's actual GitHub work landed in ${commit_repo_summary}."
        evidence_sources="${evidence_sources}, recent_commit_repos=${commit_repo_summary}"
        if _coach_focus_is_contentish "$focus_label"; then
            step_two="Before reopening ${commit_repo_summary}, turn one real change from that work into one explicit ${focus_label} angle or task and start it in the same block."
        else
            step_two="Before reopening ${commit_repo_summary}, write one explicit ${focus_label} task and start it in the same block."
        fi
        if [[ "$focus_git_status" == "diffuse" || "$focus_git_status" == "mixed" || -z "$focus_git_status" ]]; then
            working_signal="recent GitHub work shipped in ${commit_repo_summary}"
            drift_risk="that momentum is real, but it does not yet advance ${focus_label}"
        fi
    fi

    if [[ "$reason" == "ungrounded-actions" ]]; then
        reason_phrase="$reason_label"
        if [[ -n "$commit_repo_summary" ]]; then
            briefing_reason_line="${reason_label}; salvaging the plan from explicit focus and Git evidence."
            fallback_kind="Salvaged fallback"
        else
            briefing_reason_line="${reason_label}; using deterministic fallback structure."
        fi
        if [[ -n "$reason_detail" ]]; then
            briefing_reason_detail_line="Evidence-check detail: ${reason_detail}."
        else
            briefing_reason_detail_line="Evidence-check detail: no additional failure detail was captured."
        fi
    else
        briefing_reason_line="AI coaching was ${reason_label}; using deterministic fallback structure."
    fi

    if [[ -n "$behavior_digest" ]]; then
        focus_git_status=$(_coach_digest_inline_value "$behavior_digest" "focus_git_status")
        primary_repo=$(_coach_digest_inline_value "$behavior_digest" "primary_repo")
        primary_repo_share=$(_coach_digest_inline_value "$behavior_digest" "primary_repo_share")
        commit_coherence=$(_coach_digest_inline_value "$behavior_digest" "commit_coherence")
        active_repos=$(_coach_digest_inline_value "$behavior_digest" "active_repos")
        focus_git_reason=$(_coach_digest_line_value "$behavior_digest" "focus_git_reason")
    fi

    case "$focus_git_status" in
        aligned)
            working_signal="Git activity supports the declared focus via ${primary_repo:-the primary repo} (${commit_coherence:-N/A}% commit coherence)"
            drift_risk="activity is aligned now; stay inside ${primary_repo:-the current repo} and avoid extra repo switches"
            git_summary="Recent non-fork GitHub activity is aligned via ${primary_repo:-N/A} (${commit_coherence:-N/A}% commit coherence, ${primary_repo_share:-N/A}% primary-repo share)."
            evidence_sources="${evidence_sources}, focus_git_status=${focus_git_status}, primary_repo=${primary_repo:-N/A}, commit_coherence=${commit_coherence:-N/A}"
            ;;
        repo-locked)
            working_signal="recent GitHub activity is concentrated in ${primary_repo:-the primary repo}"
            drift_risk="commit-level alignment is still unproven, so verify that the next block advances today's focus"
            git_summary="Recent non-fork GitHub activity is concentrated in ${primary_repo:-N/A} (${primary_repo_share:-N/A}% primary-repo share) without commit-level focus proof."
            evidence_sources="${evidence_sources}, focus_git_status=${focus_git_status}, primary_repo=${primary_repo:-N/A}, primary_repo_share=${primary_repo_share:-N/A}"
            ;;
        mixed)
            working_signal="some Git activity supports the declared focus (${commit_coherence:-N/A}% commit coherence)"
            drift_risk="activity is only partially aligned across ${active_repos:-N/A} repos, so tighten scope before switching contexts"
            git_summary="Recent non-fork GitHub activity is mixed (${commit_coherence:-N/A}% commit coherence, ${active_repos:-N/A} repos active)."
            evidence_sources="${evidence_sources}, focus_git_status=${focus_git_status}, primary_repo=${primary_repo:-N/A}, commit_coherence=${commit_coherence:-N/A}, active_repos=${active_repos:-N/A}"
            ;;
        diffuse)
            if [[ -n "$commit_repo_summary" ]]; then
                working_signal="recent GitHub work shipped in ${commit_repo_summary}"
                drift_risk="${focus_git_reason:-recent GitHub activity is diffuse relative to the declared focus today}; that momentum is real, but it does not yet advance ${focus_label}"
            else
                working_signal="focus is declared, but it needs a fresh lock"
                drift_risk="${focus_git_reason:-recent GitHub activity is diffuse relative to the declared focus today}"
            fi
            git_summary="Recent non-fork GitHub activity is diffuse: ${focus_git_reason:-focus-vs-Git signal shows drift}."
            evidence_sources="${evidence_sources}, focus_git_status=${focus_git_status}, primary_repo=${primary_repo:-N/A}, commit_coherence=${commit_coherence:-N/A}, active_repos=${active_repos:-N/A}"
            ;;
        no-git-evidence)
            working_signal="focus is declared"
            drift_risk="recent non-fork GitHub evidence is thin, so spear movement is still unproven"
            git_summary="No recent non-fork GitHub evidence was available to confirm spear movement."
            evidence_sources="${evidence_sources}, focus_git_status=${focus_git_status}"
            ;;
        git-unavailable)
            working_signal="focus is declared"
            drift_risk="GitHub signal is unavailable, so use the focus text rather than repo momentum to choose the next move"
            git_summary="GitHub signal was unavailable, so focus-vs-Git alignment could not be scored."
            evidence_sources="${evidence_sources}, focus_git_status=${focus_git_status}"
            ;;
    esac

    github_opportunity_line=$(_coach_github_opportunity_line "$focus_label" "$commit_context" "$focus_git_status" "$primary_repo" "$active_repos" "$commit_repo_summary" || true)
    github_blindspot_scan=$(_coach_github_blindspot_scan "$focus_label" "$commit_context" "$focus_git_status" "$primary_repo" "$primary_repo_share" "$commit_coherence" "$active_repos" "$focus_git_reason" "$commit_repo_summary")
    if [[ -n "$github_opportunity_line" || -n "$github_blindspot_scan" ]]; then
        evidence_sources="${evidence_sources}, github_opportunity_scan"
    fi

    cat <<EOF
Briefing Summary:
- Coach mode: ${mode_upper}. Focus: ${focus:-"(no focus set)"}.
- ${briefing_reason_line}
${briefing_reason_detail_line:+- ${briefing_reason_detail_line}}
- ${briefing_scope_line}
- ${commit_summary_line:-No commit-level repo summary was available for fallback grounding.}
- ${git_summary}
GitHub blindspots/opportunities (1-10):
${github_blindspot_scan:-1. GitHub opportunity scan did not find grounded opportunities beyond the current focus-vs-activity drift.}
North Star:
- Ship one concrete action aligned to today's focus: ${focus:-"(no focus set)"}.
Do Next (ordered 1-3):
1. ${step_one}
2. ${step_two}
3. ${step_three}
Operating insight (momentum + exploration):
- Working: ${working_signal}. Exploration pattern: ${drift_risk}; ${reason_phrase}, so keep the next move explicit and evidence-backed.
Scope anchor:
- ${anti_tinker_rule}
Health lens:
- Use short blocks with a break; pause if energy drops under ${COACH_LOW_ENERGY_THRESHOLD} or fog rises above ${COACH_HIGH_FOG_THRESHOLD}.
Signal confidence:
- LOW (${reason_phrase}; fallback uses ${evidence_sources}, mode, and behavioral digest metrics as available).
Evidence check:
- ${fallback_kind} (${reason_label}) using ${evidence_sources}, mode, and behavioral digest metrics.
EOF
}

coach_goodevening_fallback_output() {
    local focus="$1"
    local mode="$2"
    local reason="${3:-unavailable}"
    local behavior_digest="${4:-}"
    local commit_context="${5:-}"
    local reason_detail="${6:-}"
    local mode_upper=""
    local tomorrow_boundary=""
    local focus_label="$focus"
    local focus_git_status=""
    local primary_repo=""
    local primary_repo_share=""
    local commit_coherence=""
    local active_repos=""
    local focus_git_reason=""
    local git_summary="Git focus signal unavailable in fallback context."
    local what_worked="You captured end-of-day context, which preserves continuity for tomorrow."
    local where_drift="drift diagnosis is partial and must stay conservative"
    local likely_trigger="context switching without a hard stop condition late in the day."
    local tomorrow_first_move=""
    local tomorrow_done_condition="complete one focused 10-15 minute block and log whether it moved the spear."
    local pattern_watch="not enough data for pattern detection (fallback mode)."
    local evidence_sources="focus"
    local reason_label=""
    local reason_detail_line=""
    local commit_repo_summary=""
    local blindspots_to_sleep_on=""

    if [[ -z "$focus_label" ]]; then
        focus_label="(no focus set)"
    fi
    reason_label=$(_coach_reason_label "$reason")
    commit_repo_summary=$(_coach_commit_repo_summary "$commit_context")

    mode_upper=$(printf '%s' "$mode" | tr '[:lower:]' '[:upper:]')
    if [[ "$mode_upper" == "OVERRIDE" ]]; then
        tomorrow_boundary="One bounded exploration block is allowed only after the first locked task block completes."
    elif [[ "$mode_upper" == "RECOVERY" ]]; then
        tomorrow_boundary="Aggressive simplicity. Restrict to bare minimum tasks, delay anything complex."
    else
        tomorrow_boundary="No side quests before the first locked task block is completed and logged."
    fi

    if [[ -n "$behavior_digest" ]]; then
        focus_git_status=$(_coach_digest_inline_value "$behavior_digest" "focus_git_status")
        primary_repo=$(_coach_digest_inline_value "$behavior_digest" "primary_repo")
        primary_repo_share=$(_coach_digest_inline_value "$behavior_digest" "primary_repo_share")
        commit_coherence=$(_coach_digest_inline_value "$behavior_digest" "commit_coherence")
        active_repos=$(_coach_digest_inline_value "$behavior_digest" "active_repos")
        focus_git_reason=$(_coach_digest_line_value "$behavior_digest" "focus_git_reason")
    fi

    tomorrow_first_move="capture the first concrete move for ${focus_label} before opening any unrelated repo or side quest."

    case "$focus_git_status" in
        aligned)
            git_summary="Recent non-fork GitHub activity stayed aligned via ${primary_repo:-N/A} (${commit_coherence:-N/A}% commit coherence, ${primary_repo_share:-N/A}% primary-repo share)."
            what_worked="Git activity stayed concentrated in ${primary_repo:-the primary repo} and supported the declared focus."
            where_drift="the main risk is losing this lock tomorrow by reopening extra repos before the spear moves"
            likely_trigger="finishing the day without a clearly named next move inside the aligned lane."
            tomorrow_first_move="resume the spear by naming the next concrete move for ${focus_label}, then start it before opening any second repo."
            pattern_watch="focus-vs-Git alignment was visible today; if tomorrow starts the same way, protect that single-lane momentum."
            evidence_sources="${evidence_sources}, focus_git_status=${focus_git_status}, primary_repo=${primary_repo:-N/A}, commit_coherence=${commit_coherence:-N/A}"
            ;;
        repo-locked)
            git_summary="Recent non-fork GitHub activity stayed concentrated in ${primary_repo:-N/A} (${primary_repo_share:-N/A}% primary-repo share) without commit-level focus proof."
            what_worked="Git activity stayed concentrated in ${primary_repo:-the primary repo}, which gives tomorrow a clean re-entry point."
            where_drift="commit-level alignment to the declared focus is still unproven"
            likely_trigger="working from repo momentum without an explicit done condition tied to the declared focus."
            tomorrow_first_move="turn ${focus_label} into one explicit next move, then start it before widening scope beyond ${primary_repo:-the current repo}."
            pattern_watch="single-repo momentum was visible today; if tomorrow begins the same way, verify it is actually advancing the declared focus."
            evidence_sources="${evidence_sources}, focus_git_status=${focus_git_status}, primary_repo=${primary_repo:-N/A}, primary_repo_share=${primary_repo_share:-N/A}"
            ;;
        mixed)
            git_summary="Recent non-fork GitHub activity was mixed (${commit_coherence:-N/A}% commit coherence, ${active_repos:-N/A} repos active)."
            what_worked="part of today's Git activity matched the declared focus, so the spear was visible at times."
            where_drift="activity only partially matched focus across ${active_repos:-N/A} repos"
            likely_trigger="scope drift after the first aligned block."
            tomorrow_first_move="pick one concrete move for ${focus_label}, then refuse any second repo until that move is started."
            pattern_watch="focus-vs-Git alignment was mixed today; if tomorrow also splits across repos, treat that as a real drift pattern."
            evidence_sources="${evidence_sources}, focus_git_status=${focus_git_status}, primary_repo=${primary_repo:-N/A}, commit_coherence=${commit_coherence:-N/A}, active_repos=${active_repos:-N/A}"
            ;;
        diffuse)
            git_summary="Recent non-fork GitHub activity was diffuse: ${focus_git_reason:-focus-vs-Git signal shows drift}."
            what_worked="you still closed the day with a declared focus and enough evidence to see the drift clearly."
            where_drift="${focus_git_reason:-recent GitHub activity diffused away from the declared focus}"
            likely_trigger="multiple active repos without a hard spear lock."
            tomorrow_first_move="write the first concrete move for ${focus_label} before opening any repo or task that does not directly serve it."
            pattern_watch="focus-vs-Git drift was visible today; if tomorrow also diffuses, treat it as a real pattern instead of a one-off."
            evidence_sources="${evidence_sources}, focus_git_status=${focus_git_status}, primary_repo=${primary_repo:-N/A}, commit_coherence=${commit_coherence:-N/A}, active_repos=${active_repos:-N/A}"
            ;;
        no-git-evidence)
            git_summary="No recent non-fork GitHub evidence was available to confirm spear movement."
            what_worked="the day still ended with a declared focus and captured context for tomorrow."
            where_drift="recent non-fork GitHub evidence was too thin to prove whether the spear moved"
            likely_trigger="work stayed too implicit to evaluate cleanly."
            tomorrow_first_move="define one explicit move for ${focus_label} and start it early enough to produce evidence."
            evidence_sources="${evidence_sources}, focus_git_status=${focus_git_status}"
            ;;
        git-unavailable)
            git_summary="GitHub signal was unavailable, so focus-vs-Git alignment could not be scored."
            what_worked="the day still ended with a declared focus and a saved shutdown note."
            where_drift="the evidence gap is about unavailable GitHub signal, not a confirmed lack of movement"
            likely_trigger="signal quality, not necessarily behavior."
            tomorrow_first_move="use the declared focus itself to choose one concrete first move before relying on repo memory."
            evidence_sources="${evidence_sources}, focus_git_status=${focus_git_status}"
            ;;
    esac

    if [[ -n "$commit_repo_summary" ]]; then
        evidence_sources="${evidence_sources}, recent_commit_repos=${commit_repo_summary}"
    fi
    if [[ "$reason" == "ungrounded-reflection" ]]; then
        if [[ -n "$reason_detail" ]]; then
            reason_detail_line="Evidence-check detail: ${reason_detail}."
        else
            reason_detail_line="Evidence-check detail: no additional failure detail was captured."
        fi
    fi
    blindspots_to_sleep_on=$(_coach_github_blindspot_scan "$focus_label" "$commit_context" "$focus_git_status" "$primary_repo" "$primary_repo_share" "$commit_coherence" "$active_repos" "$focus_git_reason" "$commit_repo_summary")
    if [[ -n "$blindspots_to_sleep_on" ]]; then
        evidence_sources="${evidence_sources}, github_opportunity_scan"
    fi

    cat <<EOF
Reflection Summary:
- Coach mode: ${mode_upper}. Focus: ${focus_label}.
- AI reflection was ${reason_label}; using deterministic fallback structure.
${reason_detail_line:+- ${reason_detail_line}}
- ${git_summary}
Blindspots to sleep on (1-10):
${blindspots_to_sleep_on:-1. Non-fork GitHub evidence is sparse, so the first blindspot to sleep on is how to create one visible commit early tomorrow.}
What worked:
- ${what_worked}
Off-script momentum:
- ${where_drift}; AI reflection was ${reason_label}, so keep the diagnosis conservative.
What pulled you in:
- ${likely_trigger}
Pattern watch:
- ${pattern_watch}
Tomorrow lock:
- First move: ${tomorrow_first_move}
- Done condition: ${tomorrow_done_condition}
- Scope anchor boundary: ${tomorrow_boundary}
Health lens:
- Keep work in short blocks with recovery breaks and stop if energy/fog thresholds are crossed.
Signal confidence:
- LOW (AI ${reason_label}; fallback uses ${evidence_sources}, mode, and behavioral digest metrics as available).
Evidence used:
- Deterministic fallback (${reason_label}) using ${evidence_sources}, mode, and behavioral digest metrics.
EOF
}
