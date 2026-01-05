# Unified Roadmap

_Last updated: January 4, 2026 (Phase 1 features complete; content lifecycle features shipped; ai_suggest health/meds context added)_

## 0. Vision & Constraints

- **Goal:** Run the dotfiles + AI Staff HQ toolchain as a dependable assistant that also drives the ryanleej.com publishing workflow (while remaining flexible enough to point at other Hugo projects).
- **Platform:** macOS and Linux Terminal environments; blog builds are triggered server-side (DigitalOcean) after we push to the repo—local scripts should prepare commits/pushes rather than deploy directly.
- **Technology:** This project is committed to a shell-first approach. Python or other languages should be minimized to avoid complexity. The `ai-staff-hq` submodule is treated as read-only. Limited Python usage (e.g., blog validation) is acceptable for complex parsing tasks where shell alternatives would be significantly more complex.
- **Guiding themes:** reliability first, transparent automation, AI-assisted content ops, and low-friction routines for days with limited energy.

## 1. Priority Snapshot

- **✅ Completed (v2.1.0 - January 1, 2026):**
  - **Core Infrastructure:** 62 automation scripts, 10 AI dispatchers with streaming support, shared library architecture, spec-driven workflow templates, cross-platform date utilities
  - **Energy Management (F2):** Spoon theory budget tracking with daily initialization, activity-based expenditure, debt tracking, startday/todo integration
  - **Data Correlation (F3):** Statistical correlation engine with Python-based Pearson calculation, daily report generation, multi-dataset analysis, automatic data aggregation
  - **Workflow Intelligence (W2):** ai_suggest includes energy scoring and medication adherence signals for context-aware recommendations
  - **Reliability:** All critical bugs resolved, 14/14 BATS tests passing (11 core + 8 spoon + 3 correlation), zero known critical issues
  - **Security:** A+ security grade, enhanced path validation, input sanitization, credential redaction, comprehensive security documentation
  - **AI Integration:** 41 AI Staff HQ specialists active, dynamic squad configuration, optimized free models, real-time streaming, multi-specialist orchestration
  - **Blog Workflow:** End-to-end publishing pipeline with draft management, AI-powered generation/refinement, validation, workflow orchestration, and git hooks
  - **Documentation:** Professional-grade README, CHANGELOG, SECURITY.md, TROUBLESHOOTING.md, comprehensive usage guides
- **Now (governance & reliability):**
  - Ship API key governance features (O4): per-dispatcher keys, rotation reminders, auth testing, proactive warnings
- **Next (testing & deployment):**
  - Implement automated testing coverage (T1-T3): morning hook smoke tests, happy-path rehearsals, GitHub helper setup validation
  - Add multi-deploy adapter support (B7) for Netlify/Vercel/rsync beyond default DigitalOcean push model
  - Implement rate limiting & budget alerts (O5): 429 detection, backoff, monthly budget warnings
- **Later (specialist expansion & analytics):**
  - Continue AI Staff HQ expansion (S1-S3): remaining 66 specialists, validation tooling, documentation refresh
  - Enhanced observability: usage dashboards, API budget tracking, performance monitoring

## 2. Workstreams & Task Backlog

Task IDs (`R`, `C`, `O`, `W`, `B`, `T`, `S`) map to Reliability, Config, Observability, Workflow, Blog, Testing, and Staff Library respectively.

### 2.3 Observability, Streaming & Governance

- **Completed:** O1-O3 moved to `CHANGELOG.md` (Nov 20, 2025) covering streaming exit codes, dispatcher usage logging, and context redaction.
- [ ] **O4 · API key governance** - _Not yet implemented_. Plan: Support per-dispatcher keys/aliases, rotation reminders, `dispatcher auth test` command, metadata caching for proactive warnings.
- [ ] **O5 · Rate limiting & budget alerts** - _Not yet implemented_. Plan: Implement exponential backoff for retries, detect 429 responses, and add monthly budget warnings based on cost tracking.

### 2.4 Workflow & UX Improvements · Publishing & Deployment — completed (see `CHANGELOG.md`)

### Phase 1: Context & Energy (Completed)

**Goal:** Build the "external brain" and energy management system.

- [x] **F1: Context Capture** (Save/Restore workspace state) - **Completed**
- [x] **F2: Spoon Theory Budget** (Energy tracking) - **Completed**
- [x] **F3: Correlation Engine** (Connect energy to output) - **Completed**

### Phase 2: Workflow Enhancements — completed (see `CHANGELOG.md`)

### 2.5 Blog & Publishing Program

**Design Philosophy:** Tooling works with any Hugo repository (configurable via `BLOG_DIR` in `.env`), defaults to `ryanleej.com`. Deployments happen server-side (DigitalOcean) after git push—local scripts prepare commits/pushes only.

**Current Status:** Core publishing pipeline complete (B1, B2, B3-B6, B12). Content lifecycle features complete (B8-B11). Deployment adapter work pending (B7).

#### Phase A · Blog Script Enhancements — completed (see `CHANGELOG.md`)

#### Phase B · Validation & Quality Gates — completed (see `CHANGELOG.md`)

#### Phase C · Publishing & Deployment — completed (see `CHANGELOG.md`)

#### Phase D · Content Lifecycle Features — completed (see `CHANGELOG.md`)

- [x] **B8 · Idea syncing** - **Completed**. Implemented `blog ideas sync/list/add`.
- [x] **B9 · Version management** - **Completed**. Implemented `blog version bump/show/history` obeying `VERSIONING-POLICY.md`.
- [x] **B10 · Metrics & exemplars** - **Completed**. Implemented `blog metrics` and `blog exemplar`.
- [x] **B11 · Social automation** - **Completed**. Implemented `blog social` using `dhp-copy` AI.

### 2.6 Testing, Docs & Ops

- **Completed:** T0 moved to `CHANGELOG.md` (BATS test suite for `todo.sh`).
- [ ] **T1 · Morning hook smoke test** - _Not yet implemented_. Plan: Add CI/cron check `zsh -ic startday` to ensure login hooks never regress.
- [ ] **T2 · Happy-path rehearsal** - _Not yet implemented_. Plan: Document and run weekly `startday → status → goodevening` test flow to ensure brain-fog-friendly workflows remain reliable.
- [ ] **T3 · GitHub helper setup checklist** - _Not yet implemented_. Plan: Maintain PAT instructions in sync with README/onboarding documentation. Current setup documented in TROUBLESHOOTING.md.

### 2.7 AI Staff HQ (Specialist Library & Tooling)

**Current Status:** 41 specialists active across 9 categories. All specialists have YAML definitions with activation patterns, system prompts, and integration templates.

**Integration Status:** 10 active dispatchers use specialists via dynamic squad configuration (`squads.json`). Spec-driven workflow supports all specialists via templates in `~/dotfiles/templates/`.

- **Completed:** S0 moved to `CHANGELOG.md` (41 specialists shipped, dynamic squads integrated).
- [ ] **S1 · Extended coverage** - _Not yet implemented_. Plan: Implement remaining 66 niche specialists (culinary, audio/podcast, publishing, wellness, specialty commerce) to reach 107 total.
- [ ] **S2 · Specialist validator** - _Not yet implemented_. Plan: Build lint/validation tooling for YAML schema validation and quality checks. Create CLI/CI entry point. Target: `ai-staff-hq/tools/`.
- [ ] **S3 · Documentation refresh** - _Not yet implemented_. Plan: Update `ai-staff-hq/ROADMAP.md` and supporting docs to reflect 41-specialist baseline, v3 structure, spec workflow, and integration patterns.

### 2.8 Code Quality & Technical Debt (from Fixit Audit)

- **Completed:** Q1-Q5 moved to `CHANGELOG.md` (unused variable cleanup, return-value masking fixes, subshell scope corrections, safer parsing, and style/quoting improvements).

## 3. Project Status Summary

### ✅ Production-Ready Components (v2.1.0)

**Daily Workflows:** Morning routine with spoon initialization (`startday.sh`), evening routine (`goodevening.sh`), mid-day dashboard (`status.sh`), task management with spoon tracking (`todo.sh`), journaling (`journal.sh`), focus anchors, health tracking, medication management.

**Energy Management:** Spoon theory budget tracking (`spoon_manager.sh`), daily spoon initialization, activity-based expenditure tracking, debt warnings, integration with tasks and daily routines.

**Data Analysis:** Correlation engine (`correlate.sh`), daily report generation (`generate_report.sh`), statistical pattern analysis, Pearson correlation calculation, automated data aggregation.

**Productivity Tools:** Smart navigation (`g.sh`), project management, file organization, archive management, clipboard management, application launcher, scheduling, reminders.

**Blog Publishing:** Complete end-to-end workflow from idea generation through validation to publish-ready commits. AI-powered content generation and refinement.

**AI Integration:** 10 active dispatchers with real-time streaming, 41 AI specialists, dynamic squad configuration, spec-driven workflow templates, context injection, multi-specialist orchestration.

**Infrastructure:** Shared libraries, robust error handling, cross-platform date utilities, comprehensive validation, security hardening, professional documentation.

### 🚧 In Progress & Next Steps

**Near-term (1-2 weeks):**

- O4: API key governance and rotation management
- T1: Morning hook smoke test

**Mid-term (1-2 months):**

- T2-T3: Happy-path rehearsal and GitHub helper setup checklist

**Long-term (3+ months):**

- S1-S3: AI Staff HQ expansion to 107 specialists
- Advanced workflow automation
- Usage dashboards and budget tracking

### 📚 Reference Documents

- **CHANGELOG.md** - Complete version history and shipped features (v2.0.0 release notes)
- **SECURITY.md** - Security policy and vulnerability reporting
- **TROUBLESHOOTING.md** - Common issues and solutions
- Historic planning docs (`blindspots.md`, `review.md`, `ROADMAP-REVIEW*.md`) preserved for context

### 📊 Quality Metrics (January 4, 2026)

- **Test Coverage:** 14/14 BATS tests passing (11 core + 8 spoon budget + 3 correlation)
- **Critical Bugs:** 0 known issues
- **Security Grade:** A+ (comprehensive audit complete, enhanced path validation)
- **Code Quality:** A+ (shellcheck compliant, proper error handling)
- **Platform Support:** macOS (primary), Linux (cross-platform utilities including date handling)
- **Scripts:** 62 automation scripts, 10 AI dispatchers, 4 advanced AI features
- **Libraries:** 8 shared libraries (time tracking, spoon budget, correlation engine, date utils, context capture, and 3 AI libraries)
- **Documentation:** 8 comprehensive docs, inline help for all commands, data format documentation

---

_This roadmap is a living document. Update it inline rather than creating parallel planning docs to maintain a single source of truth. Last comprehensive review: January 4, 2026._
