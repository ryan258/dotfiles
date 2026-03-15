# scripts/ Overview

Derived operational guide for `scripts/`.
Canonical architecture and policy live in `../CLAUDE.md`.

## Daily Commands

- `startday.sh`
- `status.sh`
- `goodevening.sh`
- `todo.sh`
- `idea.sh`
- `journal.sh`
- `health.sh`
- `focus.sh`

## Library Contracts

- Libraries in `scripts/lib/*.sh` are sourced and must not set strict mode.
- Executed scripts use `#!/usr/bin/env bash` + `set -euo pipefail`.
- Root `dotfiles` scripts should avoid Bash 4-only features unless the runtime requirement is explicit.
- If a script or library must use Bash 4+ features, it should fail fast with a clear message. Current known requirement: time tracking/reporting paths use associative arrays, so `scripts/lib/time_tracking.sh` and `scripts/generate_report.sh` require Bash 4+.
- On macOS, make sure `/usr/bin/env bash` resolves to a newer Bash when using those paths; `/bin/bash` is still 3.2.
- For launchd/cron/non-interactive entrypoints, use `scripts/run_with_modern_bash.sh <script> ...` to force a modern Bash before the target script starts.
- Data writes require sanitized input and validated paths.

## Coaching Runtime

- `scripts/lib/coach_ops.sh` validates coaching runtime dependencies.
- `scripts/lib/coach_metrics.sh`, `scripts/lib/coach_prompts.sh`, and `scripts/lib/coach_scoring.sh` provide metrics, prompt construction, timeout-guarded AI calls, mode persistence, and append-only coaching logs.
- Daily coaching now resolves `dhp-coach.sh` first, a single-call OpenRouter dispatcher that avoids the slower AI-Staff-HQ swarm path used by `dhp-strategy.sh`.
- Coaching model selection comes from root `dotfiles/.env` via `AI_COACH_MODEL`; changing `ai-staff-hq/.env` does not change `startday` or `goodevening`.
- `AI_COACH_EVIDENCE_CHECK_ENABLED=true` keeps the morning coach on strict focus+Git evidence; set it to `false` if you want to see raw AI output even when the model invents unsupported specifics.
- The same `AI_COACH_EVIDENCE_CHECK_ENABLED` flag now controls the evening validator too; when disabled, `goodevening` accepts raw AI reflection without warning noise.
- `status.sh --coach` now uses the same direct `dhp-coach.sh` path for an on-demand mid-day recenter brief. When you run it from inside a git repo, the coach narrows its prompt/fallback to that repo's context; outside a repo it keeps the global multi-repo view. Set `AI_STATUS_ENABLED=true` if you want that section on every `status` run, or tune `AI_STATUS_TEMPERATURE` separately from the morning briefing.
- `config.sh` now reloads the current root `.env` per process/path instead of trusting inherited `_DOTFILES_ENV_LOADED` markers from older shell state, so coach timeout/model changes take effect reliably.
- Drift and health thresholds (`COACH_*_THRESHOLD`) are defined in `config.sh` and overridable via `.env`.
- `startday.sh` and `goodevening.sh` now treat daily focus plus non-fork GitHub activity as the only coaching evidence; journal and todo data stay local for later querying but do not steer the coach.
- `startday.sh` now asks for, and fallback now generates, a 10-item GitHub blindspot/opportunity scan grounded in recent repos and commit-message patterns, so even failed AI briefings still comment on actual project momentum instead of only generic focus-lock advice.
- `goodevening.sh` now asks for, and fallback now generates, a 10-item `Blindspots to sleep on` scan grounded in recent GitHub evidence so the evening handoff carries real repo-specific opportunities into tomorrow.
- Even with evidence checking disabled, both flows now scrub obviously bad blindspot items such as raw metric flags or data-quality/debug tokens and replace them with grounded GitHub opportunity lines.
- `status.sh` shows current coach mode, spoon budget/depletion, focus text, and a Git-backed spear alignment signal in a DAILY CONTEXT section.
- When the AI status coach is enabled, `status.sh` also renders a GitHub-first recenter section using today's commits, recent pushes, current project context, and the same blindspot scrubber used by the morning coach.

## Data Location

All runtime data is under:

- `~/.config/dotfiles-data/`

Key files include:

- `todo.txt`, `todo_done.txt`
- `ideas.txt`
- `journal.txt`
- `health.txt`, `spoons.txt`
- `coach_mode.txt`, `coach_log.txt`, `coach_adherence.txt`
