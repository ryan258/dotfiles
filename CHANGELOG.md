# Dotfiles System - Changelog

**Last Updated:** November 8, 2025

This document tracks all major implementations, improvements, and fixes to the Daily Context System.

---

## November 2025: AI Integration & Foundation Complete

### Dispatcher Robustness & Streaming Improvements (November 8, 2025)

**Phase 6: Error Handling & Streaming ✅**

Addressed critical blindspots in dispatcher system for robustness and user experience.

**Created Shared Library (`bin/dhp-lib.sh`):**
- ✅ Centralized API interaction logic in `call_openrouter()` function
- ✅ Error detection: Checks for `.error` field in API responses
- ✅ Proper error reporting: Clear messages to stderr with non-zero exit codes
- ✅ Streaming support: Server-Sent Events (SSE) parsing for real-time output
- ✅ Dual-mode operation: Streaming (`--stream` flag) and traditional (default)

**Updated All 10 API-Calling Dispatchers:**
- ✅ `dhp-tech.sh` - Added library integration, error handling, streaming support
- ✅ `dhp-creative.sh` - Added library integration, error handling, streaming support
- ✅ `dhp-content.sh` - Added library integration, error handling, streaming support (with existing --context flag)
- ✅ `dhp-strategy.sh` - Added library integration, error handling, streaming support
- ✅ `dhp-brand.sh` - Added library integration, error handling, streaming support
- ✅ `dhp-market.sh` - Added library integration, error handling, streaming support
- ✅ `dhp-stoic.sh` - Added library integration, error handling, streaming support
- ✅ `dhp-research.sh` - Added library integration, error handling, streaming support
- ✅ `dhp-narrative.sh` - Added library integration, error handling, streaming support
- ✅ `dhp-copy.sh` - Added library integration, error handling, streaming support

**Error Handling Improvements:**
- ✅ No more silent failures - API errors now properly reported
- ✅ Before: `curl ... | jq -r '.choices[0].message.content'` (returns empty on error)
- ✅ After: `call_openrouter()` checks for errors and exits with code 1
- ✅ Example error: `Error: API returned an error: Invalid API key`
- ✅ Failed dispatchers now report: `FAILED: '<Name>' encountered an error.`

**Streaming Output Features:**
- ✅ Real-time text display as AI generates responses
- ✅ All 10 dispatchers support `--stream` flag
- ✅ Usage: `cat script.sh | dhp-tech --stream`
- ✅ Usage: `dhp-creative --stream "Story idea"`
- ✅ Usage: `dhp-content --stream --context "Guide topic"`
- ✅ Same error handling in streaming mode
- ✅ Backward compatible (opt-in via flag)

**Code Quality Improvements:**
- ✅ Eliminated ~1,500 lines of duplicated curl/jq logic
- ✅ Centralized API logic: Bug fixes now update all dispatchers automatically
- ✅ Consistent behavior: All dispatchers handle errors identically
- ✅ Improved maintainability: API changes only require updating one file

**Configuration Improvements:**
- ✅ Added `CREATIVE_OUTPUT_DIR` to `.env.example` and `.env`
- ✅ Added `CONTENT_OUTPUT_DIR` to `.env.example` and `.env`
- ✅ Removed hard-coded paths from `dhp-creative.sh` and `dhp-content.sh`
- ✅ Output directories now configurable via environment variables

**AI Staff HQ v3 Integration:**
- ✅ Upgraded submodule from main branch to v3 branch
- ✅ Updated specialist paths for new v3 structure:
  - `creative/copywriter.yaml` → `producers/copywriter.yaml`
  - `creative/narrative-designer.yaml` → `producers/narrative-designer.yaml`
  - `personal/stoic-coach.yaml` → `health-lifestyle/stoic-coach.yaml`
  - `personal/head-librarian.yaml` → `strategy/academic-researcher.yaml`
- ✅ Updated all affected dispatchers to use new paths
- ✅ Verified all 41 specialist YAML files present in v3

**Documentation:**
- ✅ Updated `blindspots.md` with resolved items
- ✅ Updated usage messages in all 10 dispatchers to include `--stream` flag
- ✅ Added examples for streaming mode usage

**Impact:**
- **Robustness:** API errors now caught and reported clearly
- **User Experience:** Real-time streaming dramatically improves feedback for long tasks
- **Code Quality:** Centralized logic reduces maintenance burden
- **Backward Compatibility:** No breaking changes, existing scripts work unchanged

### AI Staff HQ Integration (November 7, 2025)

**Added AI-Staff-HQ Submodule:**
- Integrated AI-Staff-HQ repository as git submodule at `ai-staff-hq/`
- Added 42 specialized AI professionals across 7 departments:
  - Creative (8): Art Director, Copywriter, Narrative Designer, Sound Designer, etc.
  - Strategy (5): Chief of Staff, Creative Strategist, Brand Builder, Market Analyst, Actuary
  - Technical (5): Automation Specialist, Prompt Engineer, Toolmaker, Productivity Architect
  - Kitchen (11): Executive Chef, Sous Chef, Pastry Chef, Sommelier, Nutritionist, etc.
  - Personal (3): Stoic Coach, Patient Advocate, Head Librarian
  - Commercialization (1): Literary Agent
  - Specialized (8): Historical Storyteller, Futurist, Transmedia Producer, etc.

#### Phase 1: Foundation & Infrastructure ✅

**Infrastructure Fixes:**
- ✅ Cleaned up `.gitignore` duplicate `.env` entry
- ✅ Added `bin/` directory to version control with all dispatcher scripts
- ✅ Verified `.env` configuration with all required variables
- ✅ Created `.env.example` template file for setup guidance
- ✅ Added `bin/` to PATH in `.zprofile` for global dispatcher access

**Dispatcher Aliases (21 total):**
- ✅ Added full-name aliases: `dhp-tech`, `dhp-creative`, `dhp-content`, etc.
- ✅ Added shorthand aliases: `tech`, `creative`, `content`, `strategy`, `brand`, `market`, `stoic`, `research`, `narrative`, `copy`
- ✅ Added default alias: `dhp` → `dhp-tech.sh`

**System Validation:**
- ✅ Enhanced `dotfiles_check.sh` with dispatcher validation
- ✅ Validates all 10 dispatchers exist and are executable
- ✅ Checks `.env` file existence and readability
- ✅ Validates required environment variables (API keys, model configs)
- ✅ Reports: "✅ Found 10/10 dispatchers"

**Documentation:**
- ✅ Updated `README.md` with comprehensive AI Staff HQ section
- ✅ Updated `bin/README.md` with complete dispatcher reference (440 lines)
- ✅ Updated `cheatsheet.sh` with categorized dispatcher examples
- ✅ All dispatchers documented with usage examples and workflow integrations

#### Phase 2: Workflow Integration ✅

**Blog Workflow Integration (`blog.sh`):**
- ✅ `blog generate <stub-name>` - AI-generate full content from blog stub using `dhp-content.sh`
- ✅ `blog refine <file>` - AI-polish existing draft with Content Specialist
- ✅ Integrated with existing `blog ideas` and `blog sync` commands

**Todo Integration (`todo.sh`):**
- ✅ `todo debug <num>` - Debug technical tasks using `dhp-tech.sh`
- ✅ `todo delegate <num> <type>` - Delegate tasks to AI specialists (tech/creative/content)
- ✅ Automatically detects script names in task descriptions for targeted debugging

**Journal Analysis (`journal.sh`):**
- ✅ `journal analyze` - Strategic insights from last 7 days via Chief of Staff
- ✅ `journal mood` - Sentiment analysis on last 14 days
- ✅ `journal themes` - Theme extraction from last 30 days
- ✅ All use `dhp-strategy.sh` for analysis

**Daily Automation:**
- ✅ Added optional AI briefing to `startday.sh` (enabled via `AI_BRIEFING_ENABLED=true`)
- ✅ Daily AI focus suggestions with caching to avoid repeated API calls
- ✅ Added optional AI reflection to `goodevening.sh` (enabled via `AI_REFLECTION_ENABLED=true`)
- ✅ Evening accomplishment summaries and tomorrow planning suggestions
- ✅ Both features opt-in via `.env` configuration

#### Phase 3: Dispatcher Expansion ✅

**10 Active Dispatchers:**

**Technical (1):**
- ✅ `dhp-tech.sh` - Automation Specialist for code debugging, optimization, technical analysis

**Creative (3):**
- ✅ `dhp-creative.sh` - Creative Team for complete story packages (horror specialty)
- ✅ `dhp-narrative.sh` - Narrative Designer for story structure, plot development, character arcs
- ✅ `dhp-copy.sh` - Copywriter for sales copy, email sequences, landing pages

**Strategy & Analysis (3):**
- ✅ `dhp-strategy.sh` - Chief of Staff for strategic analysis, insights, patterns
- ✅ `dhp-brand.sh` - Brand Builder for positioning, voice/tone, competitive analysis
- ✅ `dhp-market.sh` - Market Analyst for SEO research, trends, audience insights

**Content (1):**
- ✅ `dhp-content.sh` - Content Strategy Team for SEO-optimized evergreen guides

**Personal Development (2):**
- ✅ `dhp-stoic.sh` - Stoic Coach for mindset coaching, reframing challenges
- ✅ `dhp-research.sh` - Head Librarian for knowledge synthesis, research organization

**Dispatcher Features:**
- ✅ All dispatchers include dependency checks (curl, jq)
- ✅ API key validation with helpful error messages
- ✅ Model configuration validation
- ✅ Specialist file existence checks
- ✅ Consistent stdin/stdout interface for pipeline integration
- ✅ OpenRouter API integration with configurable models

**Configuration:**
- ✅ Environment variables: `OPENROUTER_API_KEY`, `DHP_TECH_MODEL`, `DHP_CREATIVE_MODEL`, `DHP_CONTENT_MODEL`, `DHP_STRATEGY_MODEL`
- ✅ Model defaults: GPT-4o for creative/content, GPT-4o-mini for tech
- ✅ Optional features: `AI_BRIEFING_ENABLED`, `AI_REFLECTION_ENABLED`

#### Phase 5: Advanced Features ✅

**Multi-Specialist Orchestration (`dhp-project.sh`):**
- ✅ Coordinates 5 specialists for complex projects (Market Analyst, Brand Builder, Chief of Staff, Content Specialist, Copywriter)
- ✅ Sequential AI processing with context building between phases
- ✅ Generates comprehensive project briefs in markdown format
- ✅ Alias: `dhp-project`, `ai-project`
- ✅ Usage: `dhp-project "Launch new blog series on AI productivity"`

**Context-Aware Suggestions (`ai_suggest.sh`):**
- ✅ Analyzes current directory, git status, recent commits, and active todos
- ✅ Suggests relevant dispatchers based on detected context
- ✅ Time-based suggestions (morning/evening routines)
- ✅ Detects project type and recommends appropriate AI workflows
- ✅ Alias: `ai-suggest`

**Dispatcher Chaining (`dhp-chain.sh`):**
- ✅ Sequential processing through multiple AI specialists
- ✅ Pipes output from one dispatcher to the next
- ✅ Progress display after each step
- ✅ Optional output saving to file with `--save` flag
- ✅ Alias: `dhp-chain`, `ai-chain`
- ✅ Usage: `dhp-chain creative narrative copy -- "story idea"`

**Local Context Injection (`dhp-context.sh`):**
- ✅ Context gathering library with multiple modes (minimal/full)
- ✅ Collects git history, active todos, recent journal entries, project README
- ✅ Blog context detection for content-related work
- ✅ `--context` flag support added to `dhp-content.sh` (example implementation)
- ✅ Automatically injects relevant local context into AI prompts
- ✅ Functions: `gather_context()`, `get_git_context()`, `get_recent_journal()`, `get_active_todos()`, `get_project_readme()`

**New Aliases (6 total):**
- ✅ `dhp-project`, `ai-project` - Multi-specialist orchestration
- ✅ `dhp-chain`, `ai-chain` - Dispatcher chaining
- ✅ `ai-suggest` - Context-aware suggestions
- ✅ `ai-context` - Source context library

**Enhanced Dispatcher Features:**
- ✅ `dhp-content.sh` now supports `--context` and `--full-context` flags
- ✅ Context injection prevents duplicate content and aligns with current work
- ✅ All context functions tested and validated

---

## Foundation & Hardening (November 1-5, 2025)

### Phase 1: Critical System Repairs ✅

**Fix 2: Repaired Core Journaling Loop**
- Fixed `journal.sh` to write to `~/.config/dotfiles-data/journal.txt`
- Updated `week_in_review.sh` to read from correct location
- Fixed awk compatibility (now uses gawk)
- Context-recovery loop fully functional

**Fix 3: Centralized All Data Files**
- Created `~/.config/dotfiles-data/` directory for all system data
- Migrated all data files: `todo.txt`, `journal.txt`, `health.txt`, bookmarks, clipboard history, etc.
- Updated all core scripts: `startday.sh`, `status.sh`, `goodevening.sh`, `week_in_review.sh`
- Single backup location, cleaner home directory

### Phase 2: Simplification & Cleanup ✅

**Fix 4: De-duplicated Redundant Scripts**
- Deleted redundant scripts: `memo.sh`, `quick_note.sh`, and duplicate utilities
- Removed associated aliases from `aliases.zsh`
- Reduced maintenance burden, forces consistent journaling workflow

**Fix 5: Cleaned Up Shell Configuration**
- Updated `.zprofile`: Added `scripts/` to PATH, removed non-existent directories
- Cleaned `.zshrc`: Removed redundant PATH exports and legacy sourcing
- Proper separation: PATH in `.zprofile`, interactive config in `.zshrc`

**Fix 6: Modernized Aliases**
- Updated all 50+ aliases to use simple script names (not hardcoded paths)
- Changed `~/dotfiles/scripts/X.sh` → `X.sh` throughout
- More portable and maintainable

### Phase 3: Robustness & Best Practices ✅

**Fix 7: Hardened Core Scripts**
- Added `set -euo pipefail` to all critical daily-use scripts
- Scripts now fail fast with clear error messages
- Improved reliability for core workflows

---

## Q4 2025 Objectives (November 1-2, 2025)

**All objectives completed ✅**

**0. Remaining Fixes:**
- Fixed all hardcoded paths in aliases
- Updated `TODO_FILE` path in `greeting.sh`
- Fixed `weather.sh` to use PATH lookup

**1. Morning Routine Reliability:**
- Resolved all `startday.sh` issues
- Script runs successfully in bash and zsh environments
- Integrated health tracking without errors

**2. Daily Happy Path Documentation:**
- Created comprehensive `docs/happy-path.md` guide
- Step-by-step instructions for brain fog days
- Linked from README and cheatsheet

**3. Health Context Expansion (Iteration 1):**
- Extended `health.sh` with symptom notes and energy ratings
- New subcommands: `health symptom`, `health energy`, `health summary`
- Integrated into `startday` and `goodevening` dashboards

---

## Dotfiles Evolution: Round 1 (November 2, 2025)

**Status:** ✅ 20/20 Blindspots Complete

### Phase 1: Resilience & Data Insight (4/4) ✅

1. **Data Resilience:** Automated backups via `backup_data.sh`, called in `goodevening.sh`
2. **Data Insight:** Added dashboard subcommands to `health.sh` and `meds.sh` for 30-day trends
3. **Stale Task Tracking:** Added timestamps to tasks, `startday.sh` highlights stale tasks (>7 days)
4. **System Fragility Checks:** Created `dotfiles_check.sh` to validate scripts, dependencies, data

### Phase 2: Friction Reduction & Usability (4/4) ✅

5. **Journal Retrieval:** Added `search` and `onthisday` subcommands to `journal.sh`
6. **System Maintenance:** Created `bootstrap.sh` and `new_script.sh` for automation
7. **Navigation Consolidation:** Consolidated into `g.sh` with bookmarks, recent dirs, context hooks
8. **Documentation:** Improved help messages, created `whatis.sh` to explain aliases

### Phase 3: Proactive Automation & Nudges (4/4) ✅

9. **Health Automation:** Implemented `meds.sh remind` for automated reminders
10. **Blog Integration:** `blog.sh` syncs stubs with `todo.sh`, added `blog ideas` search
11. **Anti-Perfectionism:** Gamified progress in `goodevening.sh`, added `pomo` timer alias
12. **State Management:** Enhanced `g.sh` to save/load venv state and launch apps

### Phase 4: Intelligent Workflow Integration (4/4) ✅

13. **Git-Todo Integration:** Added `todo commit` subcommand to commit and complete tasks
14. **Task Prioritization:** Added `bump` and `top` subcommands, `next` alias, top 3 in dashboards
15. **Command Scheduling:** Created `schedule.sh` wrapper for `at`, shows scheduled tasks in `startday`
16. **Dynamic Clipboard:** Enhanced `clipboard_manager.sh` to execute dynamic snippets

### Phase 5: Advanced Knowledge & Environment (4/4) ✅

17. **How-To Wiki:** Created `howto.sh` for personal searchable wiki at `~/.config/dotfiles-data/how-to/`
18. **Clutter Management:** Created `review_clutter.sh` for interactive archival/deletion
19. **Audit Logging:** Central `system.log` tracks all automated actions, `systemlog` alias to view
20. **Shell Unification:** `.zprofile` sources `.zshrc` to unify login/interactive environments

---

## Dotfiles Evolution: Round 2 (November 5, 2025)

**Status:** ✅ 20/20 Blindspots Complete

### Phase 1: Critical Fixes & Data Integrity (6/6) ✅

21. **Todo Undo:** Added `todo undo` to restore accidentally completed tasks
22. **Persistent Timestamp Gate:** Moved gate to `~/.config/dotfiles-data/.startday_last_run`
23. **Task Text Safety:** Strip pipe characters to prevent parsing issues
24. **Data Validation:** Created `data_validate.sh` to check file integrity
25. **Error Handling:** Removed `2>/dev/null` suppressions, added explicit error handling
26. **Configurable Blog Path:** Added `BLOG_DIR` environment variable

### Phase 2: High-Impact Integrations (4/4) ✅

27. **Scheduler-Todo Integration:** Added `--todo` flag to schedule tasks for later
28. **Health-Productivity Correlation:** Cross-references energy levels with tasks/commits
29. **Smart Navigation Logging:** Added chpwd hook to track directory usage for `g suggest`
30. **Weekly Review Automation:** LaunchAgent runs weekly reviews automatically, saves to files

### Phase 3: Intelligence & Proactive Features (5/5) ✅

31. **Task Encouragement:** Random positive messages for task completion and addition
32. **Daily Focus:** Created `focus.sh` for daily anchor point, prominently displayed
33. **Script Collision Detection:** `new_script.sh` checks for conflicts before creating
34. **Brain Dump Capture:** Created `dump.sh` for long-form editor-based journaling
35. **Recency Sorting:** Fixed `howto list` to sort by modification time

### Phase 4: System Polish & Advanced Tooling (5/5) ✅

36. **Idempotent Bootstrap:** Enhanced `bootstrap.sh` with safety checks, runs multiple times safely
37. **Dry-Run Modes:** All destructive scripts support `--dry-run` flag
38. **File Organization Safety:** `tidy_downloads.sh` skips recently modified files, ignore patterns
39. **Bookmark Pruning:** `g prune` removes dead bookmarks, integrated into system checks
40. **Complete Health Exports:** `health export` includes medication data for appointments

---

## Key Improvements Summary

**System Reliability:**
- All data centralized in `~/.config/dotfiles-data/`
- Automated backups run nightly via `goodevening.sh`
- Comprehensive validation and error handling
- Idempotent scripts safe to run repeatedly

**Cognitive Support:**
- Daily focus anchor for brain fog days
- Encouraging feedback for task completion
- Automated context recovery each morning
- Weekly reviews run automatically

**Workflow Integration:**
- Blog ↔ Todo synchronization
- Health ↔ Productivity correlation
- Git ↔ Todo commit integration
- Smart navigation with usage tracking

**Proactive Intelligence:**
- Smart directory suggestions based on usage
- Stale task detection and alerts
- Health trend analysis and dashboards
- Automated reminder system

**Quality of Life:**
- Unified shell environments (VS Code + Terminal)
- Comprehensive help and documentation
- Collision detection for new scripts
- Gamified progress tracking

---

## Technical Metrics

**Scripts Created:** 15+ new automation scripts
**Scripts Enhanced:** 30+ existing scripts improved
**Data Files Migrated:** 12+ files centralized
**Blindspots Resolved:** 40 total (20 + 20)
**Test Coverage:** All core scripts tested on macOS
**Dependencies:** jq, curl, gawk, osascript, git

---

## Next Phase

See `ROADMAP.md` for upcoming priorities focused on AI Staff HQ integration and dispatcher system optimization.
