# scripts/ Overview

This is a quick guide for the `scripts/` folder.
The full rules live in `../CLAUDE.md`.

## Daily Commands

- `startday.sh`
- `status.sh`
- `goodevening.sh`
- `todo.sh`
- `idea.sh`
- `journal.sh`
- `health.sh`
- `focus.sh`

## Library Rules

- Libraries live in `scripts/lib/*.sh`. They are sourced (loaded), not run directly. They must not set strict mode.
- Scripts you run directly use `#!/usr/bin/env bash` and `set -euo pipefail`.
- Root `dotfiles` scripts should not use Bash 4-only features unless clearly needed.
- If a script needs Bash 4+, it should fail fast with a clear message. Right now, time tracking uses special arrays (called "associative arrays"). So `scripts/lib/time_tracking.sh` and `scripts/generate_report.sh` need Bash 4+.
- On macOS, `/bin/bash` is old (version 3.2). Make sure `/usr/bin/env bash` points to a newer Bash when running those paths.
- For scheduled jobs (launchd/cron), use `scripts/run_with_modern_bash.sh <script> ...` to pick a modern Bash before the target script starts.
- Any script that writes data must clean the input first and check the file path.

## Coaching System

- `scripts/lib/coach_ops.sh` checks that coaching tools are ready to run.
- `scripts/lib/coach_metrics.sh`, `scripts/lib/coach_prompts.sh`, and `scripts/lib/coach_scoring.sh` handle numbers, prompt building, timed AI calls, mode saving, and coaching logs.
- `scripts/lib/coach_chat.sh` gives you a chat after each briefing. You can talk to the coach, ask questions, and use short commands (`/j` journal, `/t` todo, `/f` focus, `/q` quit). It is on by default. Turn it off with `AI_COACH_CHAT_ENABLED=false`.
- Daily coaching calls `dhp-coach.sh` first. This is a single, fast call to OpenRouter. It skips the slower AI-Staff-HQ swarm path used by `dhp-strategy.sh`.
- The coaching model is set in root `dotfiles/.env` with `AI_COACH_MODEL`. Changing `ai-staff-hq/.env` does not change `startday` or `goodevening`.
- `status.sh --coach` uses the same fast `dhp-coach.sh` path for a mid-day reset. If you run it inside a git repo, the coach focuses on that repo. Outside a repo, it shows a wider view. Set `AI_STATUS_ENABLED=true` to show this on every `status` run. You can also tune `AI_STATUS_TEMPERATURE` on its own.
- `config.sh` now reloads the root `.env` each time a process runs. This means coach timeout and model changes take effect right away.
- Coach modes: LOCKED (stay focused), FLOW (follow energy with check-ins), OVERRIDE (explore with limits), RECOVERY (low output for low-energy days). The coach suggests mode switches based on your numbers.
- Drift and health limits (`COACH_*_THRESHOLD`) are set in `config.sh`. You can change them in `.env`.
- `startday.sh` and `goodevening.sh` use daily focus and non-fork GitHub activity as coaching context. Journal and todo data stay local but do not steer the coach.
- `startday.sh` now creates a 10-item GitHub scan of blind spots and chances. It looks at recent repos and commit messages. Even if the AI call fails, the fallback still comments on real project work.
- `goodevening.sh` now creates a 10-item "Blindspots to sleep on" scan using GitHub data. This carries real ideas into tomorrow.
- `goodevening.sh` now summarizes repo safety findings after a capped number of project details. Tune the scan and visible detail counts with `GOODEVENING_PROJECT_SCAN_LIMIT`, `GOODEVENING_PROJECT_SCAN_JOBS`, and `GOODEVENING_PROJECT_ISSUE_DETAIL_LIMIT`.
- Blog status now groups `drafts/ingest/<session>` markdown artifacts into review sessions instead of printing every generated artifact path. Tune the visible review list with `BLOG_STATUS_REVIEW_DETAIL_LIMIT`.
- If the AI returns output, the coaching flows now show it raw. Deterministic fallback text only appears when the dispatcher times out, errors, or is unavailable.
- `status.sh` shows the current coach mode, spoon budget and use, focus text, and a Git-backed alignment signal in a DAILY CONTEXT section.
- When the AI status coach is on, `status.sh` also shows a GitHub-first reset section. It uses today's commits, recent pushes, project context, and the same scan cleaner as the morning coach.

## Data Location

All saved data lives here:

- `~/.config/dotfiles-data/`

Key files:

- `todo.txt`, `todo_done.txt`
- `ideas.txt`
- `journal.txt`
- `health.txt`, `spoons.txt`
- `coach_mode.txt`, `coach_log.txt`, `coach_adherence.txt`
