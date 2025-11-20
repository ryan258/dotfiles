# Unified Roadmap

_Last updated: November 14, 2025 (comprehensive codebase review)_

## 0. Vision & Constraints
- **Goal:** Run the dotfiles + AI Staff HQ toolchain as a dependable assistant that also drives the ryanleej.com publishing workflow (while remaining flexible enough to point at other Hugo projects).
- **Platform:** macOS and Linux Terminal environments; blog builds are triggered server-side (DigitalOcean) after we push to the repo—local scripts should prepare commits/pushes rather than deploy directly.
- **Technology:** This project is committed to a shell-first approach. Python or other languages should be minimized to avoid complexity. The `ai-staff-hq` submodule is treated as read-only. Limited Python usage (e.g., blog validation) is acceptable for complex parsing tasks where shell alternatives would be significantly more complex.
- **Guiding themes:** reliability first, transparent automation, AI-assisted content ops, and low-friction routines for days with limited energy.

## 1. Priority Snapshot
- **✅ Completed (v2.0.0 production release):**
  - **Core Infrastructure:** 59 automation scripts, 10 AI dispatchers with streaming support, shared library architecture, spec-driven workflow templates, cross-platform date utilities
  - **Reliability:** All critical bugs resolved (R1-R10, R13-R16), 11/11 BATS tests passing, zero known critical issues
  - **Security:** A+ security grade, input validation, path sanitization, credential redaction, comprehensive security documentation
  - **AI Integration:** 41 AI Staff HQ specialists active, dynamic squad configuration, optimized free models, real-time streaming, multi-specialist orchestration
  - **Blog Workflow:** End-to-end publishing pipeline with draft management, AI-powered generation/refinement, validation, workflow orchestration, and git hooks
  - **Documentation:** Professional-grade README, CHANGELOG, SECURITY.md, TROUBLESHOOTING.md, comprehensive usage guides
- **Now (workflow enhancements):**
  - Enhance `ai_suggest` with health.sh energy scoring and medication adherence signals (W2) for truly context-aware dispatcher recommendations
  - Ship API key governance features (O4): per-dispatcher keys, rotation reminders, auth testing, proactive warnings
- **Next (testing & content lifecycle):**
  - Implement automated testing coverage (T1-T3): morning hook smoke tests, happy-path rehearsals, GitHub helper setup validation
  - Build out blog content lifecycle features (B8-B11): idea syncing, version management, metrics/exemplars, social automation
  - Add multi-deploy adapter support (B7) for Netlify/Vercel/rsync beyond default DigitalOcean push model
- **Later (specialist expansion & analytics):**
  - Continue AI Staff HQ expansion (S1-S3): remaining 66 specialists, validation tooling, documentation refresh
  - Enhanced observability: usage dashboards, API budget tracking, performance monitoring

## 2. Workstreams & Task Backlog
Task IDs (`R`, `C`, `O`, `W`, `B`, `T`, `S`) map to Reliability, Config, Observability, Workflow, Blog, Testing, and Staff Library respectively.

### 2.3 Observability, Streaming & Governance
- **Completed:** O1-O3 moved to `CHANGELOG.md` (Nov 20, 2025) covering streaming exit codes, dispatcher usage logging, and context redaction.
- [ ] **O4 · API key governance** - _Not yet implemented_. Plan: Support per-dispatcher keys/aliases, rotation reminders, `dispatcher auth test` command, metadata caching for proactive warnings.
- [ ] **O5 · Rate limiting & budget alerts** - _Not yet implemented_. Plan: Implement exponential backoff for retries, detect 429 responses, and add monthly budget warnings based on cost tracking.

### 2.4 Workflow & UX Improvements
- **Completed:** W1 and W3 moved to `CHANGELOG.md` (config-driven squads, macOS guard rails).
- [ ] **W2 · AI suggestion polish** - `scripts/ai_suggest.sh` currently analyzes cwd/git/todo/journal keywords and detects stress/overwhelm patterns. _Needs enhancement_: Integrate `health.sh` energy scores and `meds.sh` adherence data for energy-aware dispatcher ranking.

### 2.5 Blog & Publishing Program
**Design Philosophy:** Tooling works with any Hugo repository (configurable via `BLOG_DIR` in `.env`), defaults to `ryanleej.com`. Deployments happen server-side (DigitalOcean) after git push—local scripts prepare commits/pushes only.

**Current Status:** Core publishing pipeline complete (B1, B2, B3-B6, B12). Content lifecycle features pending (B7-B11).

#### Phase A · Blog Script Enhancements — completed (see `CHANGELOG.md`)

#### Phase B · Validation & Quality Gates — completed (see `CHANGELOG.md`)

#### Phase C · Publishing & Deployment
- **Completed:** B6 moved to `CHANGELOG.md` (publish command hardened).
- [ ] **B7 · Multi-deploy adapters** - _Not yet implemented_. Plan: Support additional deployment methods (Netlify, Vercel, rsync) via `.env` configuration beyond default DigitalOcean push model.

#### Phase D · Content Lifecycle Features
- [ ] **B8 · Idea syncing** - _Not yet implemented_. Current `blog ideas` only proxies to `journal search`. Plan: Build `blog ideas sync/generate/prioritize/next` to tie journal themes + `content-backlog.md` into `todo.txt`.
- [ ] **B9 · Version management** - _Not yet implemented_. Plan: `blog version bump/check/history` commands following `VERSIONING-POLICY.md` with auto journal logging.
- [ ] **B10 · Metrics & exemplars** - _Not yet implemented_. Plan: `blog metrics` for analytics, `blog exemplar` for North Star template showcase.
- [ ] **B11 · Social automation** - _Not yet implemented_. Plan: `blog social --platform <name>` generates platform-specific content, creates todos for manual sharing.


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

### ✅ Production-Ready Components (v2.0.0)
**Daily Workflows:** Morning routine (`startday.sh`), evening routine (`goodevening.sh`), mid-day dashboard (`status.sh`), task management (`todo.sh`), journaling (`journal.sh`), focus anchors, health tracking, medication management.

**Productivity Tools:** Smart navigation (`g.sh`), project management, file organization, archive management, clipboard management, application launcher, scheduling, reminders.

**Blog Publishing:** Complete end-to-end workflow from idea generation through validation to publish-ready commits. AI-powered content generation and refinement.

**AI Integration:** 10 active dispatchers with real-time streaming, 41 AI specialists, dynamic squad configuration, spec-driven workflow templates, context injection, multi-specialist orchestration.

**Infrastructure:** Shared libraries, robust error handling, cross-platform date utilities, comprehensive validation, security hardening, professional documentation.

### 🚧 In Progress & Next Steps
**Near-term (1-2 weeks):**
- W2: Integrate health energy scores into AI suggestions
- O4: API key governance and rotation management
- B2: Persona-aware blog generation

**Mid-term (1-2 months):**
- T1-T3: Automated testing and smoke tests
- B7-B11: Blog content lifecycle features
- Enhanced observability and analytics

**Long-term (3+ months):**
- S1-S3: AI Staff HQ expansion to 107 specialists
- Advanced workflow automation
- Usage dashboards and budget tracking

### 📚 Reference Documents
- **CHANGELOG.md** - Complete version history and shipped features (v2.0.0 release notes)
- **SECURITY.md** - Security policy and vulnerability reporting
- **TROUBLESHOOTING.md** - Common issues and solutions
- Historic planning docs (`blindspots.md`, `review.md`, `ROADMAP-REVIEW*.md`) preserved for context

### 📊 Quality Metrics (November 14, 2025)
- **Test Coverage:** 11/11 BATS tests passing
- **Critical Bugs:** 0 known issues
- **Security Grade:** A+ (comprehensive audit complete)
- **Code Quality:** A+ (shellcheck compliant, proper error handling)
- **Platform Support:** macOS (primary), Linux (cross-platform utilities)
- **Scripts:** 59 automation scripts, 10 AI dispatchers, 4 advanced AI features
- **Documentation:** 8 comprehensive docs, inline help for all commands

---
_This roadmap is a living document. Update it inline rather than creating parallel planning docs to maintain a single source of truth. Last comprehensive review: November 14, 2025._
