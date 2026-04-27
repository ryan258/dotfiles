# scripts/ Overview

This is the command map for `scripts/`.
The canonical contract and coding rules live in `../CLAUDE.md`.

## Current Inventory

- 76 top-level shell utilities
- 6 top-level Python helpers
- 25 sourced shell libraries plus 2 Python modules under `scripts/lib/`

## Daily Loop and Context Commands

- `startday.sh`, `status.sh`, `goodevening.sh`
- `focus.sh`, `repo_tracker.sh`, `schedule.sh`, `gcal.sh`, `drive.sh`
- `week_in_review.sh`, `my_progress.sh`, `gh-projects.sh`

## Tasks, Notes, and Time

- `todo.sh`, `done.sh`, `idea.sh`, `journal.sh`
- `time_tracker.sh`, `take_a_break.sh`, `remind_me.sh`
- `generate_report.sh`, `setup_weekly_review.sh`

- `todo.sh` keeps `list` backward-compatible for all open tasks and now adds `all`, `current`, and `stale` so the coach can separate active work from cleanup.
- `journal.sh` now supports `list [n]`, `all`, `rel`, `edit <recent-index> <text>`, and `rm <recent-index>` without changing the flat-file journal format.
- `drive.sh` adds read-only Google Drive activity and recall helpers: `auth`, `status`, `recent [days]`, `recall [query...]`, and `read <id>`.
- `drive.sh auth` now uses a desktop-app loopback browser flow with a bounded local listener instead of the older device-flow setup.

## Health, Energy, and Wearables

- `health.sh`, `meds.sh`, `spoon_manager.sh`
- `fitbit_import.sh`, `fitbit_sync.sh`
- `correlate.sh`, `insight.sh`

## Blog, Context Capture, and Data Inspection

- `blog.sh`, `blog_recent_content.sh`
- `pdf_to_markdown.sh`, `grab_all_text.sh`, `context.sh`
- `dump.sh`, `data_validate.sh`

## Project, GitHub, and Scaffolding Utilities

- `start_project.sh`, `mkproject_py.sh`, `new_script.sh`
- `github_helper.sh`, `dotfiles_check.sh`, `validate_env.sh`
- `bash_intel.sh`, `bash_graph.sh`, `gitnexus.sh`, `open_file.sh`, `run_with_modern_bash.sh`

## Code Intelligence

- `bash_intel.sh` is the **canonical** code-intelligence tool for this repo. It wraps `bash-language-server` (LSP) for symbols, workspace searches, definitions, and references across `.sh`/`.bash`/`.zsh` files. It uses `BASH_LANGUAGE_SERVER_BIN` when configured, a `bash-language-server` binary on `PATH` when installed, or `npx --yes bash-language-server start` as a fallback. If a cold `npx` startup is slow, set `BASH_INTEL_TIMEOUT_MS=60000`.
- `bash_graph.sh` is the scoped shell dependency graph for this repo. It scans shell files for function definitions, conservative function references, `source`/`.` edges, aliases, and impact summaries. Use it when you need source topology that the language server does not model.
- `gitnexus.sh` is kept as a **portable cross-project shortcut** for running GitNexus in other repos (Python codebases where it actually adds value). It is **not** used against the dotfiles repo itself — GitNexus does not extract bash/zsh function symbols, so it provided no value here. Do not run `gitnexus analyze` against this repo or commit a `.gitnexus/` index.
- See `docs/products/bash-intel.md` for the full operator handbook (commands, workflows, optimization tips, troubleshooting).

## File, Media, and Maintenance Utilities

- `archive_manager.sh`, `backup_data.sh`, `backup_project.sh`
- `clipboard_manager.sh`, `duplicate_finder.sh`, `file_organizer.sh`
- `findbig.sh`, `findtext.sh`, `logs.sh`, `media_converter.sh`
- `network_info.sh`, `process_manager.sh`, `system_info.sh`
- `text_processor.sh`, `tidy_downloads.sh`, `unpacker.sh`, `weather.sh`

## Cyborg Support Workers

These are support scripts used by the `bin/cyborg` and `cyborg-sync` entry points rather than everyday direct commands:

- `cyborg_agent.py`
- `cyborg_build.py`
- `cyborg_docs_sync.py`
- `cyborg_support.py`
- `cyborg_scoped_site_check.sh`

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

- **Core Mechanics:** `coach_ops.sh` validates tools. `coach_metrics.sh`, `coach_prompts.sh`, and `coach_scoring.sh` handle metric collection, prompt building, and state logging.
- **Interaction:** `coach_chat.sh` acts as a deterministic control surface after each briefing. It intercepts quick commands (`/t` todo, `/f` focus, `/j` journal, `/d` drive, `/q` quit) and prefers short `A/B/C/D/E` menu choices to minimize typing overhead. Disable with `AI_COACH_CHAT_ENABLED=false`.
- **Fast Path:** Daily coaching (`startday`, `goodevening`, `status --coach`) uses `dhp-coach.sh` for a single, fast call to OpenRouter. Configure the model via `AI_COACH_MODEL` in `.env`.
- **Context Gathering:** The coach consumes a wide array of signals: manual energy/fog checks, Fitbit metrics, spoon usage, daily focus text, and a bounded local context bundle (last 7 days of journal lines, top tasks, blog snapshots, schedule).
- **Strategy Evidence:** While Git is the strongest code-day signal, the behavior digest also counts focus-related journal hits and relevant Google Drive docs (`drive.sh recent`) as valid strategy evidence. When a top relevant doc is available, the coach prompt can include a cached Drive excerpt without doing an extra network fetch during prompt assembly.
- **GitHub Blindspots:** `startday` and `goodevening` generate a capped 3-5 item action-oriented scan of recent repos and commits, post-processed to remove debug noise. `goodevening` also checks repo safety.
- **Repo Filtering:** Repos listed in `github_inactive_repos.txt` are excluded from the main activity signal and shown in a reactivation list. You can manage this manually with `repo_tracker.sh`.
- **Coach Modes:** The coach supports four modes: LOCKED (stay focused), FLOW (follow energy), OVERRIDE (explore with limits), and RECOVERY (low-energy days). Mode switching is suggested dynamically based on thresholds set in `config.sh`.

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

## Data Repair

- `repair_todo_done.sh` merges legacy `todo_done` files/backups (including bracketed formats) into the canonical `todo_done.txt` if your completed-task history was wiped or split across older locations.
