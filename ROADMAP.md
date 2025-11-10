# Unified Roadmap

_Last updated: November 10 2025_

## 0. Vision & Constraints
- **Goal:** Run the dotfiles + AI Staff HQ toolchain as a dependable assistant that also drives the ryanleej.com publishing workflow (while remaining flexible enough to point at other Hugo projects).
- **Platform:** macOS Terminal environment; blog builds are triggered server-side (DigitalOcean) after we push to the repo—local scripts should prepare commits/pushes rather than deploy directly.
- **Guiding themes:** reliability first, transparent automation, AI-assisted content ops, and low-friction routines for days with limited energy.

## 1. Priority Snapshot
- **Now (unblock daily workflows):**
  - Fix the critical shell bugs (journal search crash, missing validators, clipboard execution, streaming error handling) so dispatchers + rituals are trustworthy.
  - Stand up dispatcher logging/governance so failures are observable and sensitive context is gated.
  - Baseline blog CLI so it can prep a DigitalOcean-ready push (draft → validate → git push), including a `blog validate` quality gate and automatic visibility into drafts/latest content.
- **Next (quality of life + configurability):**
  - Externalize squad/model config, shared flag parsing, and context filters.
  - Add blog validation, idea management, and versioning automations tied to the todo/journal loops.
  - Expand test coverage/smoke checks for the morning/evening routines.
- **Later (analytics + growth):**
  - Usage dashboards, AI budget tracking, social automation, full persona-driven workflows, and Netlify/Vercel deploy adapters if needed.

## 2. Workstreams & Task Backlog
Task IDs (`R`, `C`, `O`, `W`, `B`, `T`) map to Reliability, Config, Observability, Workflow, Blog, and Testing respectively.

### 2.1 Reliability & Safety (Bugs)
- [ ] **R9 · `image_resizer` overwrites** — Ensure repeated runs don’t overwrite existing `_resized` files by generating unique filenames. _File: `ai-staff-hq/tools/scripts/image_resizer.py`_
- [ ] **R10 · `app_launcher` regex lookups** — Use fixed-string matching so shortnames like `.` don’t explode. _File: `scripts/app_launcher.sh`_
- [ ] **R11 · `week_in_review` & `backup_data` guard rails** — Fail fast with clear errors when data files/dirs are missing before running `gawk`/`tar`. _Files: `scripts/week_in_review.sh`, `scripts/backup_data.sh`_
- [ ] **R12 · `health dashboard` runaway scans** — Cache/git-limit the commits-per-day correlation so invoking the dashboard doesn’t traverse every repo each run. _File: `scripts/health.sh`_
### 2.2 Configuration & Flexibility
- [ ] **C1 · Dynamic squads/config file** — Move the dispatcher squad definitions into `ai-staff-hq/squads.yaml` so scripts can load teams without edits. _Files: `bin/dhp-*.sh`, new config loader_
- [ ] **C2 · Model parameter controls** — Allow temperature/max tokens/top_p to be set via CLI flags or `.env` so creative vs deterministic tasks can be tuned. _Files: `bin/dhp-*.sh`, `.env.example`_
- [ ] **C3 · Single dispatcher entry point** — Provide a `dispatch` wrapper that accepts a squad name and input, reducing the need to copy/modify scripts. _Files: new `bin/dispatch.sh`, aliases_
- [ ] **C4 · Shared flag/validation helpers** — Extract `validate_dependencies`, `validate_api_key`, and shared flag parsing into `dhp-lib.sh` (or another helper) to delete duplicate code. _Files: `bin/dhp-lib.sh`, `bin/dhp-*.sh`_

### 2.3 Observability, Streaming & Governance
- [ ] **O1 · Streaming exit codes** — Refactor `call_openrouter` streaming branch to avoid subshell loss, propagate HTTP errors, and only print SUCCESS on true success. _File: `bin/dhp-lib.sh`_
- [ ] **O2 · Dispatcher usage logging** — Log each call to `~/.config/dotfiles-data/dispatcher_usage.log` (timestamp, dispatcher, model, tokens, duration, exit code, streaming flag). Provide a `dispatcher stats` view. _Files: `bin/dhp-lib.sh`, new script_
- [ ] **O3 · Context redaction & controls** — Add allow/deny lists plus preview/approval for `dhp-context.sh` so journal/todo snippets don’t leak sensitive info by default. _Files: `bin/dhp-context.sh`, `.env` knobs_
- [ ] **O4 · API key governance** — Support per-dispatcher keys/aliases, rotation reminders, and a `dispatcher auth test` command. Cache metadata (created date, scopes) for proactive warnings. _Files: `.env`, helper script_

### 2.4 Workflow & UX Improvements
- [ ] **W1 · Hardcoded squad friction** — (Covered by C1/C3) ensure new squads/models can be added via config, not code edits.
- [ ] **W2 · AI suggestion polish** — Expand `ai_suggest` with recent journal mood + pending health signals to recommend the right dispatcher (optional, later).
- [ ] **W3 · Guard rails for `tidy_downloads`, `media_converter`, etc.** — Document macOS-only assumptions (done) and add optional GNU fallbacks where it’s cheap for contributor machines.

### 2.5 Blog & Publishing Program
Design this so the same tooling can point at any Hugo repo, defaulting to `ryanleej.com`, and remember that deployments happen after pushing to the remote (DigitalOcean build).

#### Phase A · Enhance `blog.sh`
- [ ] **B1 · Draft helpers** — `blog draft <type>` to scaffold archetypes, prefill metadata, and open the editor.
- [ ] **B2 · Persona-aware generation** — Allow `--persona` flags that load staff playbooks (`docs/staff/*.md`) as system prompts for AI dispatchers.
- [ ] **B3 · Workflow runner** — `blog workflow <type>` orchestrates outline → draft → accessibility review → promotion using the appropriate dispatchers.

#### Phase B · Validation & Quality Gates
- [ ] **B4 · `blog validate`** — Automated checks against `GUIDE-WRITING-STANDARDS.md`, front matter completeness, accessibility (alt text, heading hierarchy, MS-friendly language), and link health.
- [ ] **B5 · Pre-commit hook installation** — Optional `blog hooks install` to run validation before git commits touching `content/`.

#### Phase C · Deployment Prep (DigitalOcean push model)
- [ ] **B6 · `blog publish`** — One command that runs validation, builds with Hugo, summarizes git status, and prepares a push to the server-backed repo (no direct deploy; ensure instructions remind that DO handles the build when commits land).
- [ ] **B7 · Deployment config** — Support multiple deploy methods (`digitalocean` repo push default, plus optional Netlify/Vercel/rsync adapters) via `.env`.

#### Phase D · Content Lifecycle Extras
- [ ] **B8 · Idea syncing** — `blog ideas sync/generate/prioritize/next` to tie journal themes + `content-backlog.md` into `todo.txt`.
- [ ] **B9 · Version management** — `blog version bump/check/history` following `VERSIONING-POLICY.md`, with auto journal logging and review reminders.
- [ ] **B10 · Metrics + exemplars** — `blog metrics` and `blog exemplar` commands for analytics lookups and North Star templates.
- [ ] **B11 · Social automation** — `blog social --platform twitter|reddit|linkedin` plus optional todo creation for sharing.
- [x] **B12 · Draft & recent-content visibility** — Surface drafts awaiting review and newest published posts directly in `blog status`/`startday` so the morning loop shows actionable editorial work.

### 2.6 Testing, Docs & Ops
- [ ] **T1 · Morning hook smoke test** — Add a simple `zsh -ic startday` CI/cron check to ensure login hooks never regress (from ROADMAP-REVIEW-TEST).
- [ ] **T2 · Happy-path rehearsal** — Document/run a weekly `startday → status → goodevening` test to ensure the “brain fog” flow stays green.
- [ ] **T3 · GitHub helper setup checklist** — Keep the PAT instructions (from ROADMAP-REVIEW-TEST) in sync with README/onboarding.

## 3. Completed & Reference Notes
- Historic write-ups (`blindspots.md`, `review.md`, `ry.md`, `ROADMAP-REVIEW*.md`) are preserved for context; the actionable backlog now lives here.
- CHANGELOG.md tracks shipped work; update it whenever tasks above graduate from "Now"/"Next" to "Done".

---
_This roadmap is intentionally living. Add/edit tasks inline rather than spinning up parallel planning docs so we always have a single source of truth._
