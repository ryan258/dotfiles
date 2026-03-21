# Unified Roadmap

_Last updated: March 20, 2026 (v2.2.0 — Cyborg Lab agent, AI coaching system, Morphling convergence, autopilot mode, and comprehensive codebase audit shipped)_

## 0. Vision & Constraints

- **Goal:** Run the dotfiles + AI Staff HQ toolchain as a dependable assistant that also drives the ryanleej.com publishing workflow (while remaining flexible enough to point at any Hugo project or source repo via the Cyborg Lab agent).
- **Platform:** macOS and Linux Terminal environments; blog builds are triggered server-side (DigitalOcean) after we push to the repo—local scripts should prepare commits/pushes rather than deploy directly.
- **Technology:** Shell-first for core infrastructure and daily workflows. Python is used where complexity demands it: the Cyborg Lab agent (`scripts/cyborg_agent.py`), the swarm orchestrator (`bin/dhp-swarm.py`), correlation engine fallbacks, and blog validation. The `ai-staff-hq` submodule is a separate Python/LangGraph web application (see `GUARDRAILS.md` for scope rules).
- **Guiding themes:** reliability first, transparent automation, AI-assisted content ops, energy-aware design (spoon theory), and low-friction routines for brain-fog days.

## 1. Priority Snapshot

- **Shipped (v2.2.0 — March 2026):**
  - **AI Coaching System:** 5-module behavioral analytics engine (metrics, prompts, scoring, ops, facade) with hallucination detection, evidence grounding, configurable drift thresholds, and coaching modes (LOCKED/OVERRIDE/RECOVERY)
  - **Cyborg Lab Agent:** 4,900-line Python agent for interactive content ingestion — scans repos, builds content maps, generates Hugo blog drafts, supports session persistence and resume
  - **Morphling Convergence:** Universal adaptive dispatcher + Cyborg autopilot integration — Morphling pre-analyzes repos, Cyborg documents them, `--build` mode scaffolds projects from ideas
  - **Autopilot Mode:** Brain-fog-day shortcuts (`ap`, `apy`, `apb`, `apby`, `apc`) that run full pipelines with one command and accessible A-E choice prompts
  - **Expanded Dispatchers:** 13 core dispatchers (added finance, morphling, coach) plus project orchestrator, chain, and dispatch router
  - **Codebase Audit:** Comprehensive audit with fixes across critical, architectural, and quality findings — dependency injection, module splitting, error standardization
  - **Test Expansion:** 37 BATS test files covering coaching, dispatchers, context capture, correlation, cyborg, insight, and more
  - **GitNexus Integration:** Code knowledge graph indexing (879 symbols, 1,906 relationships, 46 execution flows)
  - **Idea Management:** Aspirational task backlog with promotion to actionable todos
  - **Insight System:** Falsification-first hypothesis tracking with 4-gate compliance and Bayesian verdict scoring
  - Everything from v2.1.0 (see below)
- **Shipped (v2.1.0 — January 2026):**
  - **Core Infrastructure:** 66 automation scripts, shared library architecture, spec-driven workflow templates, cross-platform date utilities
  - **Energy Management (F2):** Spoon theory budget tracking with depletion prediction, daily initialization, activity-based expenditure, debt tracking
  - **Data Correlation (F3):** Statistical correlation engine with Pearson calculation, daily report generation, multi-dataset analysis
  - **Workflow Intelligence (W2):** ai-suggest with energy scoring and medication adherence signals
  - **Security:** A+ grade — enhanced path validation, input sanitization, credential redaction
  - **AI Integration:** 68 AI Staff HQ specialists, dynamic squad configuration, streaming, multi-specialist orchestration
  - **Blog Workflow:** End-to-end publishing pipeline with AI-powered generation/refinement, validation, and git hooks
- **Now:**
  - Stabilize Cyborg autopilot reliability across diverse repo types
  - Improve coaching evidence grounding accuracy (reduce false-positive hallucination rejections)
- **Next:**
  - O4: API key governance (per-dispatcher keys, rotation reminders, auth testing)
  - O5: Rate limiting and budget alerts (429 detection, backoff, monthly warnings)
  - T1-T3: Automated testing coverage (morning hook smoke tests, happy-path rehearsals)
- **Later:**
  - S1-S2: AI Staff HQ specialist expansion and YAML validation tooling
  - Brain/knowledge base integration into daily workflows (beyond dispatcher artifact storage)
  - Multi-deploy adapter support (B7) for Netlify/Vercel/rsync

## 2. Workstreams & Task Backlog

Task IDs: `R` Reliability, `C` Config, `O` Observability, `W` Workflow, `B` Blog, `T` Testing, `S` Staff Library, `A` Agent, `K` Coaching.

### 2.1 AI Coaching System (Shipped)

**Status:** Production-ready. Integrated into `startday.sh`, `goodevening.sh`, and `status.sh`.

**Architecture:** Five focused modules behind a thin facade:

| Module | Purpose |
|--------|---------|
| `coach_ops.sh` | Dependency validation gate |
| `coach_metrics.sh` | Behavioral digest, git focus scoring, energy trajectory, adherence tracking (24 functions) |
| `coach_prompts.sh` | Prompt construction for startday/goodevening/status, fallback outputs (30+ functions) |
| `coach_scoring.sh` | Response grounding, hallucination filtering, timeout handling (15 functions) |
| `coaching.sh` | Facade with graceful degradation |

**Key capabilities:**

- [x] **K1 · Behavioral digest** — Collects 7-day tactical + 30-day pattern metrics from tasks, journal, spoons, health, and git
- [x] **K2 · Focus coherence scoring** — Analyzes git commit patterns for project drift (configurable thresholds)
- [x] **K3 · Energy trajectory** — Detects afternoon slumps and energy trends from health data
- [x] **K4 · Evidence grounding** — Validates AI responses against actual data; rejects invented repos, tasks, or journal entries
- [x] **K5 · Coaching modes** — LOCKED (stay on focus), OVERRIDE (user-directed change), RECOVERY (low-energy adaptation)
- [x] **K6 · Suggestion adherence** — Tracks follow-through rates on coach suggestions over time
- [x] **K7 · Late-night commit detection** — Flags commits after 10pm as potential overwork signals
- [x] **K8 · Configurable thresholds** — 13+ tunable parameters via `.env` (drift, energy, fog, focus)

### 2.2 Cyborg Lab Agent (Shipped)

**Status:** Production-ready. Interactive and autopilot modes operational.

**Architecture:** Shell launcher (`bin/cyborg`) + Python agent (`scripts/cyborg_agent.py`, 4,922 lines).

**Key capabilities:**

- [x] **A1 · Repo scanning** — Scans source repos via git ls-files or filesystem walk; detects languages, structure, and notable files
- [x] **A2 · Content mapping** — AI-powered or heuristic mapping of repo features to blog article types (guides, references, protocols, stacks)
- [x] **A3 · Draft generation** — Near-publishable Hugo posts with proper frontmatter, archetype awareness, and cross-linking
- [x] **A4 · Session persistence** — JSON-based session state with resume capability across shell sessions
- [x] **A5 · GitNexus integration** — Knowledge graph queries for enhanced repo understanding (symbols, relationships, execution flows)
- [x] **A6 · Duplicate detection** — Identifies existing blog content that overlaps with proposed articles; supports rewrite modes
- [x] **A7 · Code improvement plans** — Generates actionable code improvement suggestions from repo analysis
- [x] **A8 · Interactive REPL** — Full command set for review, revision, apply, link patching, and GitNexus queries
- [x] **A9 · Morphling convergence** — Shell-side pre-analysis (path 1) and Python-side `--build` scaffolding (path 2)
- [x] **A10 · Autopilot pipeline** — Phased execution: repo context → code improvements → content map → plan → drafts → links
- [x] **A11 · Accessible prompts** — A/B/C/D/E short-choice format for all interactive decisions

### 2.3 Observability, Streaming & Governance

- **Completed:** O1-O3 moved to `CHANGELOG.md` (streaming exit codes, dispatcher usage logging, context redaction).
- [ ] **O4 · API key governance** — Support per-dispatcher keys/aliases, rotation reminders, `dispatcher auth test` command, metadata caching for proactive warnings.
- [ ] **O5 · Rate limiting & budget alerts** — Exponential backoff for retries, 429 detection, monthly budget warnings based on cost tracking.

### 2.4 Workflow & UX Improvements

- **Completed:** Publishing & deployment features moved to `CHANGELOG.md`.
- [x] **W3 · Autopilot aliases** — Brain-fog-day shortcuts: `ap` (auto), `apy` (auto+yes), `apb` (build from idea), `apby` (build+yes), `apc` (resume).
- [x] **W4 · Accessibility ergonomics** — Global aliases (`G`, `C`, `L`, `H`, `N`), typo forgiveness, home-row shortcuts, zero-symbol git workflows.
- [x] **W5 · Idea management** — `idea.sh` with add/list/rm/clear/up/to-todo pipeline.

### Phase 1: Context & Energy (Completed)

- [x] **F1: Context Capture** (Save/Restore workspace state) - **Completed**
- [x] **F2: Spoon Theory Budget** (Energy tracking with depletion prediction) - **Completed**
- [x] **F3: Correlation Engine** (Connect energy to output) - **Completed**

### Phase 2: Workflow Enhancements — completed (see `CHANGELOG.md`)

### Phase 3: AI Coaching — completed (see section 2.1)

### Phase 4: Content Automation — completed (see section 2.2)

### 2.5 Blog & Publishing Program

**Design Philosophy:** Tooling works with any Hugo repository (configurable via `BLOG_DIR` in `.env`). The Cyborg Lab agent can target any source repo and any blog root. Deployments happen server-side (DigitalOcean) after git push.

**Current Status:** Core publishing pipeline complete (B1-B6, B8-B12). Content lifecycle features complete. Cyborg Lab provides automated content generation from any source repo.

#### Phases A-D — completed (see `CHANGELOG.md`)

- [x] **B8 · Idea syncing** — `blog ideas sync/list/add`
- [x] **B9 · Version management** — `blog version bump/show/history`
- [x] **B10 · Metrics & exemplars** — `blog metrics` and `blog exemplar`
- [x] **B11 · Social automation** — `blog social` using `dhp-copy` AI
- [x] **B12 · Cyborg Lab integration** — Automated content generation from source repos via `cyborg ingest/auto`
- [ ] **B7 · Multi-deploy adapters** — Netlify/Vercel/rsync beyond default DigitalOcean push model

### 2.6 Testing, Docs & Ops

- **Completed:** T0 moved to `CHANGELOG.md` (initial BATS test suite).
- [x] **T4 · Coaching test suite** — `test_coach_metric_branches.sh`, `test_coach_ops.sh`, `test_coach_prompts.sh`, `test_goodevening_coach.sh`, `test_startday_coach.sh`
- [x] **T5 · Dispatcher tests** — `test_dispatcher_mapping.sh`, `test_dispatcher_unknown_flags.sh`
- [x] **T6 · Integration tests** — `test_cyborg.sh`, `test_correlation_integration.sh`, `test_context_cli.sh`
- [x] **T7 · Syntax validation** — `test_scripts_syntax.sh` (bash -n on all scripts)
- [ ] **T1 · Morning hook smoke test** — Add CI/cron check `zsh -ic startday` to ensure login hooks never regress.
- [ ] **T2 · Happy-path rehearsal** — Document and run weekly `startday → status → goodevening` test flow.
- [ ] **T3 · GitHub helper setup checklist** — Maintain PAT instructions in sync with README/onboarding. Currently documented in TROUBLESHOOTING.md.

### 2.7 AI Staff HQ (Specialist Library & Tooling)

**Current Status:** 68 specialists active across 7 departments. 13 core dispatchers plus project orchestrator, chain router, and dispatch resolver. Morphling provides universal adaptive access to all specialists.

**Integration Status:** Dispatchers use specialists via dynamic squad configuration (`squads.json`). Spec-driven workflow supports all specialists via templates in `~/dotfiles/templates/`. Brain/Hive Mind stores dispatcher outputs for cross-project recall.

- **Completed:** S0 moved to `CHANGELOG.md` (68 specialists shipped, dynamic squads integrated).
- [x] **S3 · Documentation refresh** — `dhp-swarm` CLI docs, handbooks consolidated into daily-loop, general-reference, and AI handbooks
- [x] **S4 · Swarm CLI Engine** — `bin/dhp-swarm.py` with parallel execution, streaming, and verbose observability
- [x] **S5 · Morphling dispatcher** — Universal adaptive specialist (`dhp-morphling.sh` + `morphling.sh` interactive launcher)
- [x] **S6 · Finance dispatcher** — `dhp-finance.sh` for financial analysis and budgeting
- [x] **S7 · Coach dispatcher** — `dhp-coach.sh` for direct-API coaching (bypasses swarm for speed)
- [ ] **S1 · Extended coverage** — Implement remaining niche specialists to expand beyond 68.
- [ ] **S2 · Specialist validator** — Build lint/validation tooling for YAML schema validation.

### 2.8 Code Quality & Technical Debt

- **Completed:** Q1-Q5 moved to `CHANGELOG.md` (unused variable cleanup, return-value masking, subshell scope, safer parsing, style/quoting).
- [x] **Q6 · Comprehensive codebase audit** — Critical, architectural, and quality findings addressed across the codebase
- [x] **Q7 · Coach module split** — `coach_ops.sh` split into `coach_metrics.sh`, `coach_prompts.sh`, `coach_scoring.sh` for maintainability
- [x] **Q8 · Dependency injection** — Explicit dependency sourcing enforced; libraries declare requirements in headers
- [x] **Q9 · Error standardization** — Consistent exit codes and error handling patterns across all scripts

### 2.9 Knowledge Base & Memory

**Status:** Brain/Hive Mind operational for dispatcher output storage. Not yet integrated into daily workflow scripts.

- [x] **M1 · ChromaDB vector store** — `brain/` directory with start script, ingestion tools, semantic search
- [x] **M2 · Chat log ingestion** — Supports ChatGPT and Claude export formats
- [x] **M3 · Dispatcher integration** — `--brain` flag and `dhp-memory.sh`/`dhp-memory-search.sh` wrappers
- [ ] **M4 · Daily workflow integration** — Surface relevant memories in `startday` briefings and `status` dashboard
- [ ] **M5 · Automatic ingestion** — Auto-ingest coaching logs, journal insights, and correlation findings

## 3. Project Status Summary

### Production-Ready Components (v2.2.0)

**Daily Workflows:** Morning routine with AI coaching briefing and spoon initialization (`startday.sh`), evening routine with reflection and project safety scan (`goodevening.sh`), mid-day context recovery dashboard with repo-local coaching (`status.sh`), task management with spoon and time tracking (`todo.sh`), journaling with AI analysis (`journal.sh`), focus anchoring with history, health tracking, medication management.

**AI Coaching:** 5-module behavioral analytics engine. Collects tactical (7-day) and pattern (30-day) metrics from tasks, journal, spoons, health, and git activity. Builds structured behavior digests. Constructs grounded coaching prompts for morning briefings, evening reflections, and status queries. Validates AI responses against actual data — rejects hallucinated repos, tasks, and journal entries. Supports coaching modes (LOCKED/OVERRIDE/RECOVERY) and configurable thresholds.

**Cyborg Lab Agent:** Interactive content ingestion from any source repo to Hugo blog. Scans repos, builds AI-powered content maps, generates near-publishable drafts with proper frontmatter and cross-linking. Supports autopilot mode for brain-fog days, session persistence and resume, GitNexus knowledge graph integration, duplicate detection, and code improvement suggestions.

**Energy Management:** Spoon theory budget tracking (`spoon_manager.sh`) with depletion prediction, daily initialization, activity-based expenditure, debt warnings, and integration with tasks and daily routines.

**Data Analysis:** Correlation engine (`correlate.sh`), daily report generation, statistical pattern analysis, insight system with falsification-first hypothesis tracking and 4-gate verdicts.

**Productivity Tools:** Smart bookmark navigation (`g.sh`), project management, file organization, archive management, clipboard management with named slots, application launcher, scheduling, reminders, idea backlog management.

**Blog Publishing:** Complete end-to-end workflow from idea generation through validation to publish-ready commits. AI-powered content generation and refinement. Cyborg Lab provides automated repo-to-blog content pipelines.

**AI Integration:** 13 core dispatchers with real-time streaming, 68 AI Staff HQ specialists, dynamic squad configuration, spec-driven workflow templates, context and persona injection, multi-specialist orchestration, Morphling universal adaptive dispatcher, project orchestrator, chain routing. Brain/Hive Mind for cross-project memory.

**Infrastructure:** 21 shared libraries, robust error handling with named exit codes, cross-platform date utilities (Python-first with BSD/GNU fallbacks), comprehensive input sanitization and path validation, atomic file operations, security hardening, 37 BATS test files, GitNexus code indexing.

**Accessibility:** Autopilot mode (`ap`, `apy`, `apb`, `apby`, `apc`) for brain-fog days, accessible A-E choice prompts, global zsh aliases for reduced typing, typo forgiveness, home-row shortcuts, zero-symbol git workflows.

### Next Steps

**Near-term:**

- Stabilize Cyborg autopilot across diverse repo types and sizes
- Improve coaching evidence grounding accuracy
- O4: API key governance and rotation management

**Mid-term:**

- O5: Rate limiting and budget alerts
- T1-T3: Automated testing (morning hook smoke tests, happy-path rehearsals)
- M4-M5: Brain/knowledge base integration into daily workflows

**Long-term:**

- S1-S2: AI Staff HQ specialist expansion and validation tooling
- B7: Multi-deploy adapter support
- Usage dashboards and API budget tracking

### Reference Documents

- **CHANGELOG.md** — Complete version history and shipped features
- **CLAUDE.md** — Canonical architecture and behavior contract for root dotfiles
- **AGENTS.md** — Operational quick-reference checklist for AI assistants
- **GUARDRAILS.md** — Scope governance (root CLI vs ai-staff-hq submodule)
- **SECURITY.md** — Security policy and vulnerability reporting
- **TROUBLESHOOTING.md** — Common issues and solutions
- **docs/daily-loop-handbook.md** — Morning, during-day, and evening workflow guide
- **docs/autopilot-happy-path.md** — Low-energy automation cheat sheet
- **brain/HANDBOOK.md** — Knowledge base usage guide

### Quality Metrics (March 20, 2026)

- **Test Coverage:** 37 BATS test files covering coaching, dispatchers, cyborg, correlation, context, insight, file ops, spoons, time tracking, status, and syntax validation
- **Critical Bugs:** 0 known issues
- **Security Grade:** A+ (comprehensive audit, enhanced path validation, input sanitization)
- **Code Quality:** A+ (shellcheck compliant, proper error handling, explicit dependency injection)
- **Platform Support:** macOS (primary), Linux (cross-platform via date_utils.sh and POSIX-compatible patterns)
- **Scripts:** 66 automation scripts, 13 core AI dispatchers, 4 advanced orchestration features (project, chain, dispatch, morphling)
- **Libraries:** 21 shared libraries covering coaching (5), blog (4), correlation, dates, file ops, config, common, context, insights (2), spoons, time tracking, GitHub, health
- **Python:** Cyborg Lab agent (4,922 lines), swarm orchestrator, correlation engine helpers
- **Documentation:** 15+ docs including 3 consolidated handbooks, product briefs, and inline help for all commands

---

_This roadmap is a living document. Update it inline rather than creating parallel planning docs to maintain a single source of truth. Last comprehensive review: March 20, 2026._
