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
- `repo_tracker.sh`

## Document Utilities

- `pdf_to_markdown.sh` extracts embedded text from a PDF and writes Markdown beside the source file by default, which is useful when you want a cheaper AI-ingestion format than the original PDF.
- It uses macOS `PDFKit` via `swift`, so it works without extra Homebrew PDF tooling.
- Use `pdf_to_markdown.sh report.pdf`, `pdf_to_markdown.sh report.pdf notes/report.md`, or `pdf_to_markdown.sh report.pdf --stdout`.
- Scanned or image-only PDFs still need OCR. This tool only converts text that already exists in the PDF.

## Wearable Imports

- `fitbit_import.sh` imports Fitbit CSV exports into normalized daily metric files under `~/.config/dotfiles-data/fitbit/`.
- `fitbit_sync.sh` performs a one-time Google OAuth setup and then syncs recent Google Health API data into the same normalized metric files.
- If `fitbit_sync.sh status` says the auth file is empty or invalid JSON, rerun `fitbit_sync.sh auth` to repair the local Google Health token state.
- `fitbit_sync.sh status` now also shows the last stored sync error, and the daily health summary surfaces that refresh failure when stale Fitbit data is still on screen.
- `startday.sh`, `status.sh`, and `goodevening.sh` now run a best-effort `fitbit_sync.sh sync "$GOOGLE_HEALTH_DEFAULT_DAYS"` first when Google Health auth is already present, so the daily views and coach prompts see fresh wearable data.
- Keep `health.sh` for subjective signals like energy, fog, and symptoms. Use `fitbit_import.sh` for objective Fitbit metrics like sleep, steps, resting heart rate, and HRV.
- `fitbit_import.sh auto <dir>` scans a Fitbit export directory, while `fitbit_import.sh latest` shows the newest imported values.
- `fitbit_sync.sh sync 7` uses the Google Health API once auth is in place. It currently syncs `steps`, `sleep_minutes`, and best-effort `resting_heart_rate` / `hrv` into the same local files.

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
- `scripts/lib/coach_chat.sh` gives you a chat after each briefing. You can talk to the coach, ask questions, and use short commands (`/j` journal, `/t` todo, `/f` focus, `/q` quit). When it needs clarification, it should prefer short `A/B/C/D/E` questions with `E` as a custom answer. It is on by default. Turn it off with `AI_COACH_CHAT_ENABLED=false`.
- Daily coaching calls `dhp-coach.sh` first. This is a single, fast call to OpenRouter. It skips the slower AI-Staff-HQ swarm path used by `dhp-strategy.sh`.
- The coaching model is set in root `dotfiles/.env` with `AI_COACH_MODEL`. Changing `ai-staff-hq/.env` does not change `startday` or `goodevening`.
- `status.sh --coach` uses the same fast `dhp-coach.sh` path for a mid-day reset. If you run it inside a git repo, the coach focuses on that repo. Outside a repo, it shows a wider view. Set `AI_STATUS_ENABLED=true` to show this on every `status` run. You can also tune `AI_STATUS_TEMPERATURE` on its own.
- `startday.sh` and `goodevening.sh` now open with the manual energy/fog check and health summary, so you can log current state before the rest of the morning or evening flow.
- `repo_tracker.sh` lets you deactivate a repo when it is in a good place and reactivate it later. Use `repo_tracker.sh deactivate <repo> [note...]`, `repo_tracker.sh reactivate <repo>`, `repo_tracker.sh list`, and `repo_tracker.sh names`.
- When the AI status coach is on and `status.sh` is interactive, it asks for energy and fog before building the briefing so the same run can use your fresh manual readings.
- In interactive runs, `startday.sh`, `status.sh --coach`, and `goodevening.sh` can ask up to 3 pre-brief clarification questions before the AI call. Answer them in one line with numbered choices like `1B 2A 3E (custom note)`. Set `AI_COACH_PREBRIEF_ENABLED=false` to skip them, `AI_COACH_PREBRIEF_ALWAYS_ASK=true` to force them, and `AI_COACH_PREBRIEF_MAX_QUESTIONS=1..3` to cap how many appear.
- The three daily coach flows now append an Additional local context bundle to the AI prompt by default. It includes bounded last-7-day raw local context such as journal lines, open todos/top tasks, schedule output, suggested directories, blog status/content snapshots, launchpad text, the latest weekly review text, and raw `health.txt`, `spoons.txt`, and `dir_usage.log` slices. Tune it with `AI_COACH_LOCAL_CONTEXT_ENABLED`, `AI_COACH_LOCAL_CONTEXT_DAYS`, and `AI_COACH_LOCAL_CONTEXT_DIR_LOG_MAX_LINES`.
- `g.sh suggest` now tolerates legacy colon-delimited directory logs and preserves full paths with spaces, so `startday.sh` no longer truncates entries like `Projects/the merge/...`.
- `config.sh` now reloads the root `.env` each time a process runs. This means coach timeout and model changes take effect right away.
- Most scripts should source `common.sh` and then only the libraries they need. `loader.sh` is reserved for the coaching-heavy daily flows (`startday.sh`, `status.sh`, and `goodevening.sh`) that intentionally preload the full stack.
- Coach modes: LOCKED (stay focused), FLOW (follow energy with check-ins), OVERRIDE (explore with limits), RECOVERY (low output for low-energy days). The coach suggests mode switches based on your numbers.
- Drift and health limits (`COACH_*_THRESHOLD`) are set in `config.sh`. You can change them in `.env`.
- `startday.sh` and `goodevening.sh` use daily focus and non-fork GitHub activity as coaching context. Journal and todo data stay local but do not steer the coach.
- The shared behavior digest now includes the latest Fitbit wearable snapshot when it exists, and the coach prompts are told to treat those metrics as live health context instead of suggesting Fitbit setup work.
- The shared behavior digest now includes both the latest manual energy/fog reading and the trailing averages, so the coach can distinguish "right now" from "recent trend."
- `startday.sh` now creates a capped 3-5 item GitHub blindspot/opportunity scan. It looks at recent repos and commit messages, and each item should point to an obvious next action instead of vague repo trivia.
- `goodevening.sh` now creates a capped 3-5 item "Blindspots to sleep on" scan using GitHub data, so tomorrow inherits a few grounded follow-ups instead of a wall of options.
- `goodevening.sh` now summarizes repo safety findings after a capped number of project details. Tune the scan and visible detail counts with `GOODEVENING_PROJECT_SCAN_LIMIT`, `GOODEVENING_PROJECT_SCAN_JOBS`, and `GOODEVENING_PROJECT_ISSUE_DETAIL_LIMIT`.
- Blog status now groups `drafts/ingest/<session>` markdown artifacts into review sessions instead of printing every generated artifact path. Tune the visible review list with `BLOG_STATUS_REVIEW_DETAIL_LIMIT`.
- If the AI returns output, the coaching flows keep that output but still clean and cap the blindspot sections so raw metric/debug noise does not leak into the user-facing briefing. Deterministic fallback text only appears when the dispatcher times out, errors, or is unavailable.
- `status.sh` shows the current coach mode, spoon budget and use, focus text, and a Git-backed alignment signal in a DAILY CONTEXT section.
- When the AI status coach is on, `status.sh` also shows a GitHub-first reset section. It uses today's commits, recent pushes, project context, and the same scan cleaner as the morning coach.
- Recent GitHub push labels now use the local calendar day instead of a rolling 24-hour bucket, and the daily commit recaps follow any branch that was pushed that day instead of only the repo default branch.
- The recent-repo scan now prefers the authenticated owner-repo listing before falling back to the public profile listing, so private repos you own can appear in `startday`, `status`, and `goodevening`.
- `startday.sh`, `status.sh`, and `goodevening.sh` now hide repos listed in `github_inactive_repos.txt` from their GitHub activity signal and show those parked repo names in a separate reactivation list instead.

## Correlation Shortcuts

- `corr-sleep` correlates `sleep_minutes` against `health.txt`.
- `corr-steps` correlates `steps` against `health.txt`.
- `corr-rhr` correlates `resting_heart_rate` against `health.txt`.
- `corr-hrv` correlates `hrv` against `health.txt`.

## Data Location

All saved data lives here:

- `${XDG_DATA_HOME:-$HOME/.config}/dotfiles-data/`

Key files:

- `todo.txt`, `todo_done.txt`
- `ideas.txt`
- `journal.txt`
- `health.txt`, `spoons.txt`
- `fitbit/*.txt`
- `coach_mode.txt`, `coach_log.txt`, `coach_adherence.txt`
