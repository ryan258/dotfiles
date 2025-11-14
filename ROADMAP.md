# Unified Roadmap

_Last updated: November 13, 2025 (post-v2.0.0 assessment)_

## 0. Vision & Constraints
- **Goal:** Run the dotfiles + AI Staff HQ toolchain as a dependable assistant that also drives the ryanleej.com publishing workflow (while remaining flexible enough to point at other Hugo projects).
- **Platform:** macOS and Linux Terminal environments; blog builds are triggered server-side (DigitalOcean) after we push to the repo—local scripts should prepare commits/pushes rather than deploy directly.
- **Guiding themes:** reliability first, transparent automation, AI-assisted content ops, and low-friction routines for days with limited energy.

## 1. Priority Snapshot
- **✅ Completed (v2.0.0 release + AI Staff refresh):**
  - Ten blocker-level shell bugs closed, dispatcher streaming + shared library shipped, spec-driven workflow templates landed, and path/data validation now guards the daily routines.
  - Security/Troubleshooting docs, bootstrap + `.env` validation, and the AI Staff HQ expansion to 41 specialists keep the toolkit documented and production-ready on macOS.
- **Now (stability + guard rails):**
  - Close remaining reliability fixes (R12-R16): deterministic image_resizer outputs, fixed-string `app_launcher`, backup/review guard rails, health dashboard caching, and cross-platform `date` helpers.
  - Ship API key governance + `ai_suggest` mood/health signals (O4, W2) and add smoke/cron coverage (T1-T3) so startday/goodevening remain trustworthy outside the happy path.
- **Next (workflow automation):**
  - Implement blog helpers/validators/publish wrappers (B1-B5, B8) so the editorial loop can run end-to-end from the CLI.
  - Continue Staff HQ expansion/documentation (S1-S3) and broaden routine coverage with additional dispatcher + hook rehearsals.
- **Later (analytics + growth):**
  - Usage dashboards, API budget tracking, persona-driven social automation, and multi-deploy adapters (B6-B11 plus observability follow-ups) once stability tasks are green.

## 2. Workstreams & Task Backlog
Task IDs (`R`, `C`, `O`, `W`, `B`, `T`, `S`) map to Reliability, Config, Observability, Workflow, Blog, Testing, and Staff Library respectively.

### 2.1 Reliability & Safety (Bugs)
- [x] **R1 · `jq` Payload Builder Broken** - Fixed the `jq` command in `bin/dhp-lib.sh` to correctly build the JSON payload.
- [x] **R2 · `validate_path` BROKEN on macOS** - Updated `bin/dhp-utils.sh` to use a Python fallback for `realpath`.
- [x] **R3 · Newline Replacement Breaks Text** - Reverted the `sed` to parameter expansion changes in `scripts/startday.sh` and `scripts/goodevening.sh`.
- [x] **R4 · `health.sh` Export Piles Up Data** - Fixed the `export` command in `scripts/health.sh` to truncate the output file before writing to it.
- [x] **R5 · `howto.sh` find -printf NOT FIXED** - Updated `scripts/howto.sh` to use a cross-platform `find` and `stat` solution.
- [x] **R6 · `git config` Failure Kills Script** - Fixed the `git config` command in `scripts/github_helper.sh` to handle the case where `user.name` is not set.
- [x] **R7 · Glob Pattern Matching Broken** - Fixed the glob pattern matching in `scripts/tidy_downloads.sh`.
- [x] **R8 · App Launcher Gets Wrong Arguments** - Fixed the app launcher arguments in `scripts/g.sh`.
- [x] **R9 · Test Isolation Destroying Real Data** - Fixed `tests/test_todo.sh` to use TEST_DATA_DIR with mktemp and override HOME to prevent real data destruction.
- [x] **R10 · Blog.sh Path Validation Breaks Fresh Installs** - Fixed `scripts/blog.sh` to create directories before validation and skip validation for external paths.
- [x] **R12 · `image_resizer` overwrites** — Avoided clobbering `_resized` artifacts by generating deterministic, incrementing filenames whenever collisions occur. _File: `ai-staff-hq/tools/scripts/image_resizer.py`_
- [x] **R13 · `app_launcher` regex lookups** — Switched to fixed-string parsing to support shortnames with regex characters. _File: `scripts/app_launcher.sh`_
- [x] **R14 · `week_in_review` & `backup_data` guard rails** — Added dependency/data checks so missing files or unreadable directories fail fast before invoking `gawk`/`tar`. _Files: `scripts/week_in_review.sh`, `scripts/backup_data.sh`_
- [x] **R15 · `health dashboard` runaway scans** — Added commit-count caching + lookback limits so the dashboard no longer traverses every repo on each invocation. _File: `scripts/health.sh`_
- [x] **R16 · Cross-platform `date` helper** — Introduced `scripts/lib/date_utils.sh` and sourced it in the daily routines and health utilities so macOS-only `date -v` usage no longer breaks Linux runs. _Files: `scripts/startday.sh`, `scripts/goodevening.sh`, `scripts/week_in_review.sh`, `scripts/meds.sh`, `scripts/health.sh`_
### 2.2 Configuration & Flexibility
- [x] **C1 · Dynamic squads/config file** — Move the dispatcher squad definitions into `ai-staff-hq/squads.yaml` so scripts can load teams without edits. _Files: `bin/dhp-*.sh`, new config loader_
- [x] **C2 · Model parameter controls** — Allow temperature/max tokens/top_p to be set via CLI flags or `.env` so creative vs deterministic tasks can be tuned. _Files: `bin/dhp-*.sh`, `.env.example`_
- [x] **C3 · Single dispatcher entry point** — Provide a `dispatch` wrapper that accepts a squad name and input, reducing the need to copy/modify scripts. _Files: new `bin/dispatch.sh`, aliases_
- [x] **C4 · Shared flag/validation helpers** — Extract `validate_dependencies`, `validate_api_key`, and shared flag parsing into `dhp-lib.sh` (or another helper) to delete duplicate code. _Files: `bin/dhp-lib.sh`, `bin/dhp-*.sh`_

### 2.3 Observability, Streaming & Governance
- [x] **O1 · Streaming exit codes** — Refactor `call_openrouter` streaming branch to avoid subshell loss, propagate HTTP errors, and only print SUCCESS on true success. _File: `bin/dhp-lib.sh`_
- [x] **O2 · Dispatcher usage logging** — Log each call to `~/.config/dotfiles-data/dispatcher_usage.log` (timestamp, dispatcher, model, tokens, duration, exit code, streaming flag). Provide a `dispatcher stats` view. _Files: `bin/dhp-lib.sh`, new script_
- [x] **O3 · Context redaction & controls** — Add allow/deny lists plus preview/approval for `dhp-context.sh` so journal/todo snippets don’t leak sensitive info by default. _Files: `bin/dhp-context.sh`, `.env` knobs_
- [ ] **O4 · API key governance** — Support per-dispatcher keys/aliases, rotation reminders, and a `dispatcher auth test` command. Cache metadata (created date, scopes) for proactive warnings. _Files: `.env`, helper script_

### 2.4 Workflow & UX Improvements
- [x] **W1 · Hardcoded squad friction** — Addressed via config-driven squads and the `dispatch` entry point (C1/C3).
- [ ] **W2 · AI suggestion polish** — Current `ai_suggest` only inspects cwd/git/todo keywords; add recent journal mood scoring + health data inputs and better dispatcher ranking so suggestions adapt to energy levels.
- [x] **W3 · Guard rails for `tidy_downloads`, `media_converter`, etc.** — Document macOS-only assumptions (done) and add optional GNU fallbacks where it’s cheap for contributor machines.

### 2.5 Blog & Publishing Program
Design this so the same tooling can point at any Hugo repo, defaulting to `ryanleej.com`, and remember that deployments happen after pushing to the remote (DigitalOcean build).

#### Phase A · Enhance `blog.sh`
- [x] **B1 · Draft helpers** — `blog draft <type>` to scaffold archetypes, prefill metadata, and open the editor.
- [ ] **B2 · Persona-aware generation** — Allow `--persona` flags that load staff playbooks (`docs/staff/*.md`) as system prompts for AI dispatchers.
- [x] **B3 · Workflow runner** — `blog workflow <type>` orchestrates outline → draft → accessibility review → promotion using the appropriate dispatchers.

#### Phase B · Validation & Quality Gates
- [x] **B4 · `blog validate`** — Automated checks against `GUIDE-WRITING-STANDARDS.md`, front matter completeness, accessibility (alt text, heading hierarchy, MS-friendly language), and link health.
- [x] **B5 · Pre-commit hook installation** — Optional `blog hooks install` to run validation before git commits touching `content/`.

#### Phase C · Deployment Prep (DigitalOcean push model)
- [x] **B6 · `blog publish`** — One command that runs validation, builds with Hugo, summarizes git status, and prepares a push to the server-backed repo (no direct deploy; ensure instructions remind that DO handles the build when commits land).
- [ ] **B7 · Deployment config** — Support multiple deploy methods (`digitalocean` repo push default, plus optional Netlify/Vercel/rsync adapters) via `.env`.

#### Phase D · Content Lifecycle Extras
- [ ] **B8 · Idea syncing** — The current `blog ideas` subcommand just proxies `journal search`; add real `blog ideas sync/generate/prioritize/next` flows tying journal themes + `content-backlog.md` into `todo.txt`.
- [ ] **B9 · Version management** — `blog version bump/check/history` following `VERSIONING-POLICY.md`, with auto journal logging and review reminders.
- [ ] **B10 · Metrics + exemplars** — `blog metrics` and `blog exemplar` commands for analytics lookups and North Star templates.
- [ ] **B11 · Social automation** — `blog social --platform twitter|reddit|linkedin` plus optional todo creation for sharing.
- [x] **B12 · Draft & recent-content visibility** — Surface drafts awaiting review and newest published posts directly in `blog status`/`startday` so the morning loop shows actionable editorial work.

### 2.6 Testing, Docs & Ops
- [x] **T0 · BATS Testing Framework** - Added BATS framework and an example test file `tests/test_todo.sh`.
- [ ] **T1 · Morning hook smoke test** — Add a simple `zsh -ic startday` CI/cron check to ensure login hooks never regress (from ROADMAP-REVIEW-TEST).
- [ ] **T2 · Happy-path rehearsal** — Document/run a weekly `startday → status → goodevening` test to ensure the “brain fog” flow stays green.
- [ ] **T3 · GitHub helper setup checklist** — Keep the PAT instructions (from ROADMAP-REVIEW-TEST) in sync with README/onboarding.

### 2.7 AI Staff HQ (Specialist Library & Tooling)
- [x] **S0 · Core expansion** — 41/107 specialists shipped with activation patterns, templates, and documentation (Batches 1-4). _Reference: `ai-staff-hq/IMPLEMENTATION-STATUS.md`_
- [ ] **S1 · Batch 5 coverage** — Implement the remaining 66 niche specialists (culinary, audio/podcast, publishing, wellness, specialty commerce). _Dir: `ai-staff-hq/staff/`_
- [ ] **S2 · Specialist validator** — Build lint/validation tooling (schema + quality checks) for staff YAML plus a CLI/CI entry point. _Files: `ai-staff-hq/tools/` (new), `ai-staff-hq/docs/`_
- [ ] **S3 · Staff roadmap/doc refresh** — Update `ai-staff-hq/ROADMAP.md` and supporting docs to reflect the 41-specialist baseline, spec workflow, and upcoming phases.

## 3. Completed & Reference Notes
- Historic write-ups (`blindspots.md`, `review.md`, `ry.md`, `ROADMAP-REVIEW*.md`) are preserved for context; the actionable backlog now lives here.
- CHANGELOG.md tracks shipped work; update it whenever tasks above graduate from "Now"/"Next" to "Done".

---
_This roadmap is intentionally living. Add/edit tasks inline rather than spinning up parallel planning docs so we always have a single source of truth._
