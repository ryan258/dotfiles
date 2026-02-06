# Dotfiles System - Changelog

**Last Updated:** February 6, 2026

This document tracks all major implementations, improvements, and fixes to the Daily Context System.

---

## Version 2.2.6 (February 6, 2026) - Runtime Hardening & Cleanup Pass

**Status:** ✅ Production Ready

### Fixes
- Hardened path boundary validation in `scripts/lib/common.sh` and `scripts/correlate.sh` to prevent false-safe prefix matches.
- Fixed no-argument `set -u` crashes across utility scripts by normalizing command parsing and usage guards.
- Fixed `scripts/blog.sh` library sourcing to use a script-local path variable that cannot be clobbered by sourced dependencies.
- Fixed `scripts/todo.sh` so `start`, `spend`, `debug`, and `delegate` fail correctly when the referenced task does not exist.
- Fixed `scripts/dotfiles_check.sh` bookmark prune step to run `g.sh prune --auto` without sourced-script side effects.

### Cleanup
- Removed orphaned helpers: `decode_clipboard()` and `get_file_perms()`.
- Standardized dynamic dotfiles root resolution (replacing hardcoded `$HOME/dotfiles`) across helper and dispatcher scripts.
- Added `scripts/memo.sh` compatibility wrapper for the existing `memo` alias target.
- Removed stray commented blob after executable logic in `scripts/dev_shortcuts.sh`.
- Updated alias documentation for current `g` behavior and removed stale command references.

### Tests
- Converted legacy non-Bats test files into real Bats tests (`test_file_ops.sh`, `repro_crash.sh`).
- Fixed missing-library staging in integration fixtures.
- Full suite now passes: `75/75` via `bats tests/*.sh`.

---

## Version 2.2.5 (February 6, 2026) - goodevening Stability Fix

**Status:** ✅ Production Ready

### Fixes
- Fixed `scripts/goodevening.sh` unbound variable crash in the AI reflection block by initializing and reusing `RECENT_PUSHES` consistently.

---

## Version 2.2.4 (February 5, 2026) - GitHub Resilience Patch

**Status:** ✅ Production Ready

### Fixes
- `scripts/github_helper.sh` now uses per-request temp error logs (prevents stale fallback error leakage across runs).
- Public GitHub API fallback now covers both `/users/<name>/events` and `/users/<name>/repos`, improving reliability when token auth is unavailable.
- Added request timeout controls for GitHub API calls: `GITHUB_CONNECT_TIMEOUT` and `GITHUB_REQUEST_TIMEOUT`.
- GitHub debug output is now opt-in via `GITHUB_DEBUG=true` instead of always surfacing low-level warnings.
- `scripts/lib/github_ops.sh` now keeps user-facing output clean by routing helper diagnostics to debug mode while letting caller scripts print concise fallback messages.
- Added troubleshooting and daily workflow documentation for GitHub diagnostics (`GITHUB_DEBUG=true startday refresh`).
- `startday refresh` now clears only AI briefing cache by default (retains GitHub cache for offline/transient network resilience); use `startday refresh --clear-github-cache` for a full cold refresh.

---

## Version 2.2.3 (February 4, 2026) - Maintenance Patch

**Status:** ✅ Production Ready

### Fixes
- Updated `spec_helper.sh` to use `create_temp_file()` for safer temp handling and to source shared utilities.
- Removed a no‑op cleanup trap from `scripts/lib/blog_common.sh`.
- `dhp-lib.sh` now honors `DEFAULT_TEMPERATURE`/`DEFAULT_MAX_TOKENS` when set (falls back to `null`).
- Standardized `status.sh` to use `DATA_DIR` (removed `STATE_DIR` fallback).
- Documented the `finance` dispatcher alias in the quick reference, cheatsheet, and dispatcher README.
- `startday.sh` now shows true “yesterday” journal entries; GitHub activity errors now surface their root cause.
- Fixed GitHub repo exclusion parsing to avoid jq escape errors.
- `startday.sh` now prompts to update spoons even if already initialized, with a default of 10; default daily spoons updated across docs/config.
- AI briefing now receives captured GitHub activity (instead of empty data).
- Added GitHub commit recaps: startday shows yesterday’s commits; goodevening shows yesterday + today.

---

## Version 2.2.2 (February 3, 2026) - Context & Reporting Improvements

**Status:** ✅ Production Ready

This release completes the previously stubbed context and reporting features.

### New Features
- **Context Snapshots:** Added `context.sh` for capture/list/show/restore workflow, with optional auto‑capture on `startday` via `CONTEXT_CAPTURE_ON_START=true` and snapshot counts in `status.sh`.
- **Time Reports:** Implemented `generate_time_report` with date ranges, `--days`, and `--summary`, plus improved `goodevening` time summaries.
- **Correlation Patterns:** Implemented `find-patterns` and `explain` in `correlate.sh` with new pattern analysis in `scripts/lib/correlate.py`.
- **Data Migration Tooling:** Added `scripts/migrate_data.sh` and expanded `scripts/data_validate.sh` format checks.
- **Docs updated?** ✅

### Security & Hygiene
- Sanitized interactive inputs across scheduling, reminders, project creation, process management, and report generation.

### Fixes
- Removed duplicate strict mode in `brain/start_brain.sh`.
- Fixed `clipboard_manager.sh` list output formatting and made `generate_time_report` errors emit to stderr.
- Added colon‑format fallback for bookmark lookups in `g.sh` and corrected `dotfiles_check.sh` step numbering.

### Documentation Stream Summary
- Formalized the canonical doc set and consolidated content into Start Here + AI Quick Reference.
- Added TL;DR + Related Docs blocks across canonical docs; updated doc index links to reduce hunting.
- Added docs owner/maintenance rule and a docs status check in `scripts/dotfiles_check.sh`.
- Completed the remediation/documentation plans, then removed the plan files and documentation archive to reduce clutter.

---

## Version 2.2.1 (February 3, 2026) - Codebase Health Fixes

**Status:** ✅ Production Ready

This release addresses issues identified during a comprehensive codebase health review.

### Alias Conflict Resolution
- **`copy` → `aicopy`**: Resolved conflict between `copy` alias (previously mapped to `dhp-copy.sh`) and macOS `pbcopy` clipboard utility
- `copy` now correctly maps to `pbcopy` for clipboard operations
- `aicopy` is the new alias for the AI copywriting dispatcher (`dhp-copy.sh`)

### Configuration Enhancements (`scripts/lib/config.sh`)
- Added `COPY_MODEL` configuration for the copywriting dispatcher
- Added `NARRATIVE_MODEL` configuration for the narrative dispatcher
- Added `MORPHLING_MODEL` configuration for the morphling dispatcher
- Added `FOCUS_FILE` path configuration
- Added `BRIEFING_CACHE_FILE` path configuration

### Library Improvements (`scripts/lib/common.sh`)
- Added `validate_path()` function for secure path validation
- Prevents path traversal attacks and validates file/directory existence

### Default Value Alignment
- Changed `AI_BRIEFING_ENABLED` default from `false` to `true` in config to match documentation

### Error Handling Improvements
- Scripts now consistently use `set -euo pipefail` for robust error handling
- Improved fail-fast behavior across core scripts

### Documentation Updates
- Updated `bin/README.md` with correct `aicopy` alias
- Updated `docs/ai-examples.md` with `aicopy` examples
- Updated `docs/flex.md` quick reference table
- Updated `scripts/cheatsheet.sh` with current aliases

---

## Version 2.2.0 (January 5, 2026) - Swarm Orchestration

**Status:** ✅ Production Ready

This release introduces Swarm Orchestration for all AI dispatchers, upgrading the AI workflow from single‑agent calls to coordinated multi‑agent execution.

### Highlights
- **Universal Swarm Engine:** All `dhp-*` dispatchers route through `bin/dhp-swarm.py` for unified orchestration.
- **Dynamic Specialist Selection:** Requests are decomposed and staffed automatically using the capability index.
- **Parallel Execution:** Tasks execute in waves to reduce latency and increase throughput.
- **Observability:** Added `--verbose` progress output and `--stream` JSON events for long or integrated runs.
- **Documentation:** Updated Swarm guidance and quick reference materials to reflect the new engine.

---

## Version 2.1.0 (January 1, 2026) - Phase 1 Features

**Status:** ✅ Production Ready - Foundation Features Complete

This release implements the first wave of advanced features from the Feature Implementation Plan, focusing on energy management, time tracking, and data correlation. All features include comprehensive test coverage and cross-platform compatibility.

**Quality Metrics:**
- 14/14 comprehensive tests passing (11 previous + 3 new)
- Zero critical bugs
- Cross-platform verified (macOS/Linux)
- Security grade: A+

### New Features

#### F2: Spoon Theory Budget Tracking ⭐⭐⭐
- **Spoon Manager** (`scripts/spoon_manager.sh`): Complete energy budget management system
  - Daily spoon initialization with configurable starting values
  - Activity-based spoon expenditure tracking
  - Real-time remaining budget checks
  - Standard activity cost lookup (meeting=2, coding=1, social=3, travel=4)
- **Integration with `startday.sh`**: Interactive daily spoon budget prompt with sensible defaults
- **Integration with `todo.sh`**: Track spoon cost per task (`todo spend <task_id> <count>`)
- **Data Format**: Pipe-delimited log in `~/.config/dotfiles-data/spoons.txt`
  - `BUDGET|YYYY-MM-DD|count`
  - `SPEND|YYYY-MM-DD|HH:MM|count|activity|remaining`
- **Spoon Debt Tracking**: Allows negative balances with warnings for realistic MS management
- **Aliases**: `spoons`, `s-check`, `s-spend`
- **Tests**: 8/8 tests passing including edge cases and error handling

#### F3: Correlation Engine (Experimental) ⭐⭐⭐
- **Correlation Library** (`scripts/lib/correlation_engine.sh`): Statistical analysis foundation
  - Python-based Pearson correlation calculation
  - Multi-dataset correlation with date alignment
  - Automatic daily data aggregation
  - Insight text generation based on correlation strength
- **CLI Wrapper** (`scripts/correlate.sh`): User-friendly correlation interface
  - Run correlations between any two datasets
  - Configurable column indices (0-based)
  - Path validation for security (restricts to DATA_DIR, /tmp, pwd)
  - Pattern finding (placeholder for future ML)
- **Report Generator** (`scripts/generate_report.sh`): Daily/weekly summary reports
  - Time tracking aggregation with duration calculations
  - Spoon budget summary (budget/spent/remaining)
  - Automatic correlation analysis (spoons vs focus time)
  - Markdown report generation in `~/.config/dotfiles-data/reports/`
- **Python Correlation Module** (`scripts/lib/correlate.py`):
  - Pearson correlation algorithm implementation
  - Date-based dataset merging
  - CSV/pipe-delimited file support
  - Minimum data point validation (warns if <5 points)
- **Aliases**: `correlate`, `daily-report`
- **Tests**: 3/3 tests passing with graceful error handling

### Bug Fixes
- **Time Log Parsing**: Fixed critical bug in `generate_report.sh` where STOP entries were parsed incorrectly due to field count mismatch
- **Cross-Platform Date**: Corrected Linux date calculation in report generation loop
- **Path Validation**: Improved security validation in `correlate.sh` with proper cross-platform path resolution
- **Test Dependencies**: Added missing library imports to correlation integration tests
- **Regex Validation**: Fixed correlation coefficient regex to properly validate numeric formats

### Infrastructure Improvements
- **Shared Libraries**: All new features use modular library architecture
  - `scripts/lib/spoon_budget.sh`: Core spoon theory logic
  - `scripts/lib/correlation_engine.sh`: Statistical analysis wrapper
  - `scripts/lib/correlate.py`: Python calculation engine
- **Input Validation**: Comprehensive numeric and path sanitization
- **Error Handling**: Graceful degradation when dependencies unavailable
- **Test Coverage**: Full BATS test suite for all new features
- **Documentation**: Inline comments document data formats and algorithms

### Known Limitations
- Correlation engine requires Python 3 with standard library
- Daily reports limited to 7-day lookback (configurable in future)
- Pattern finding and prediction features not yet implemented
- AI-powered correlation insights pending integration

---

## Version 2.0.0 (November 12, 2025) - Production Release

**Status:** ✅ Production Ready - All Critical Issues Resolved

This major release represents a comprehensive security audit and hardening of the entire dotfiles system. After multiple review cycles and extensive testing, all 10 critical issues have been resolved. The system is production-ready with enhanced security, monitoring, cross-platform compatibility, and professional documentation.

**Quality Metrics:**
- 11/11 comprehensive tests passing
- Zero critical bugs remaining
- Cross-platform verified (macOS/Linux)
- Security grade: A+
- Code quality: A+

### Critical Bug Fixes
- **API Signature Bug:** Fixed a critical bug in all 10 dispatcher scripts where non-streaming API calls were failing to log the dispatcher name correctly.
- **`jq` Payload Builder:** Corrected a critical issue in `bin/dhp-lib.sh` that caused `temperature` and `max_tokens` parameters to be silently ignored in all API calls.
- **Test Data Safety:** Reworked `tests/test_todo.sh` to use a temporary directory, preventing the accidental deletion of real user data during tests.
- **`validate_path` on macOS:** Fixed a critical bug where `validate_path` would fail on macOS for non-existent paths, breaking scripts like `backup_project.sh` and `blog.sh`.
- **Newline Replacement:** Reverted a faulty parameter expansion that was corrupting text in `scripts/startday.sh` and `scripts/goodevening.sh`.
- **`health.sh` Export:** Fixed a critical bug where the `health.sh export` command would append to existing reports instead of creating a new one.
- **`howto.sh` Compatibility:** Updated `scripts/howto.sh` to use a cross-platform `find` and `stat` solution that works on macOS.

### Security Enhancements
- **Command Injection:** Mitigated a command injection vulnerability in `scripts/g.sh` by replacing `eval` with an allowlist-based `case` statement.
- **Hardcoded Secrets:** Removed a hardcoded GitHub username from `scripts/github_helper.sh` and moved it to the `.env` file.
- **File Permissions:** Added permission checks for the GitHub token file and automated `chmod 600` in `bootstrap.sh`.
- **Input Validation:** Added input length limits and null byte validation to `dhp-shared.sh`.
- **Path Traversal:** Added a `validate_path` function to `dhp-utils.sh` to sanitize file paths and prevent path traversal vulnerabilities.
- **Data Redaction:** Implemented a redaction function in `dhp-context.sh` to filter sensitive information before it is sent to AI models.

### API & Dispatcher Improvements
- **API Call Logging:** Implemented dispatcher usage logging to track API calls, models, and token usage.
- **Rate Limiting:** Added a basic cooldown mechanism to `dhp-lib.sh` to prevent rapid-fire API calls.
- **API Timeouts:** Added a `300s` timeout to all `curl` commands in `dhp-lib.sh`.
- **Error Handling:** Improved error handling in streaming API calls by using `set -o pipefail`.

### Configuration & Code Quality
- **Configuration Validation:** Created a `validate_env.sh` script to validate `.env` configurations and integrated it into `dotfiles_check.sh`.
- **Dependency Versioning:** Added dependency version checks to `bootstrap.sh` to ensure compatibility.
- **ShellCheck Compliance:** Ran `shellcheck` on all scripts and fixed numerous quoting and style issues.
- **Magic Numbers:** Replaced hardcoded "magic numbers" with configurable environment variables in `startday.sh`, `g.sh`, and `week_in_review.sh`.

### Documentation
- **`SECURITY.md`:** Created a comprehensive security policy document.
- **`TROUBLESHOOTING.md`:** Created a guide for common issues and solutions.
- **`VERSION` File:** Added a `VERSION` file to track the project version.
- **`README.md`:** Updated with links to the new documentation, versioning information, and testing instructions.

### Testing
- **BATS Framework:** Added the BATS testing framework and an example test file (`tests/test_todo.sh`) to provide a foundation for future automated testing.

---

### Code Quality & Technical Debt (November 20, 2025)
- **Cleanup:** Removed unused variables in `dhp-content.sh`, `dhp-project.sh`, and `ai_suggest.sh`.
- **Robustness:** Fixed return value masking in `tidy_downloads.sh` and `spec_helper.sh`.
- **Bug Fixes:** Resolved subshell scope issues in `goodevening.sh` to correctly track project issues.
- **Parsing:** Improved loop robustness in `meds.sh` and `health.sh` to handle input with spaces.

### Roadmap Deliverables Completed (November 20, 2025)
- **Observability (O1-O3):** Streaming exit codes propagate correctly; dispatcher usage logging writes to `dispatcher_usage.log`; context redaction guards sensitive data before AI calls.
- **Workflow (W1, W3):** Squads now load from `ai-staff-hq/squads.json` instead of hardcoded values; macOS-specific scripts are documented with guard rails and cross-platform helpers.
- **Blog & Publishing (B1, B3-B6, B12):** Draft scaffolding and full workflow orchestration landed; validation and pre-commit hooks added; publish command finalized; drafts and recent content surface in status routines.
- **Testing & Operations (T0):** BATS test suite established for `todo.sh`.
- **AI Staff HQ (S0):** 41 specialists shipped across categories with dynamic squad integration.
- **Code Quality (Q1-Q5):** Unused variables removed, return-value masking fixed, subshell state tracked correctly, safer parsing patterns adopted, and shell style/quoting tightened.

## G3 Audit Recommendations (November 20, 2025)

**Status:** ✅ Completed

Addressed findings from the G3 project audit to improve portability, documentation, and observability.

### Portability & Code Quality
- **Refactored Hardcoded Paths:** Replaced absolute paths (e.g., `/Users/ryanjohnson`) with dynamic paths in `setup_weekly_review.sh`, `schedule.sh`, `blog.sh`, and `dotfiles_check.sh`.
- **Standardized Sourced Scripts:** Verified and ensured `bin/dhp-shared.sh` and `zsh/aliases.zsh` do not leak global shell options (`set -e`, etc.) into interactive sessions.

### Documentation
- **Generalized Docs:** Updated `README.md` and `mssite.md` to use generic placeholders (`$HOME`, `<username>`) instead of hardcoded user paths.

### Features
- **Cost Tracking:** Implemented API cost estimation in `bin/dhp-lib.sh` to track and log token usage/costs for AI dispatchers.

---

## November 2025: AI Integration & Foundation Complete

### Persona-Aware Blog Generation (B2)
- Added persona playbook loader (`docs/personas.md`) with `-p/--persona` flag for `blog generate`
- Introduced section-aware workflows: `-s/--section` writes drafts directly into the correct `content/<section>/` folder
- Hugo archetype, section exemplar, persona, and user brief are stacked in every AI call for consistent structure/voice
- Exemplar sources are configurable via `BLOG_SECTION_EXEMPLARS` in `.env`; defaults include guides, blog posts, prompts, and shortcuts
- Dispatchers still save `draft: true` files; publishing now just flips the flag and timestamps

### Reliability & Configuration Hardening
- Resolved R1–R16 reliability issues (path validation, glob fixes, macOS compatibility, data safeguards)
- Added shared utils (`dhp-utils.sh`), dynamic squad config (`ai-staff-hq/squads.json`), universal dispatcher entry point, and model param flags
- Implemented streaming error propagation, usage logging, and context redaction guards

### Reliability Sprint (November 2025)

- ✅ R1: Fixed `journal search` so it no longer crashes or depends on GNU `tac`.
- ✅ R2: Restored nightly backup validator by adding `scripts/data_validate.sh`.
- ✅ R3: Locked down `clipboard_manager` so it never executes saved clips and the history dir is private.
- ✅ R4: Escaped double quotes in `done.sh` notifications to prevent AppleScript failures.
- ✅ R5: Hardened `blog recent` to handle empty result sets without dumping unrelated files.
- ✅ R6: Removed PATH assumptions from the old stub sync (now removed entirely) by calling `todo.sh` directly.
- ✅ R7: `startday` now degrades gracefully when GitHub helper/jq fail instead of aborting the routine.
- ✅ R8: `file_organizer.py` dry runs no longer create directories or mutate files.

### General Remediation (November 10, 2025)

- ✅ **Script Robustness:** Added `set -euo pipefail` to over 20 scripts to ensure they fail fast and handle errors predictably.
- ✅ **Code Consolidation:**
    - Created `bin/dhp-shared.sh` to centralize setup, flag parsing, and input handling for all dispatcher scripts.
    - Refactored `dhp-brand.sh`, `dhp-tech.sh`, and `dhp-creative.sh` to use the new shared library, removing significant code duplication.
- ✅ **File Cleanup:** Removed 3 obsolete navigation scripts (`goto.sh.deprecated`, `recent_dirs.sh.deprecated`, `workspace_manager.sh.deprecated`) and several `.bak` files.
- ✅ **Documentation:** Updated `README.md` to reflect the script hardening and code consolidation efforts.


### Dispatcher Squad Config (November 2025)

- ✅ Added `ai-staff-hq/squads.json` to define multi-agent dispatcher squads in one place.
- ✅ Created `bin/dhp-config.sh` helper so dispatchers can load squad definitions dynamically.
- ✅ Updated `dhp-content.sh` and `dhp-creative.sh` to read their agent lists from the shared config with sensible fallbacks.
- ✅ Added CLI/env overrides for model temperature/max tokens so dispatchers can tune determinism per call.
- ✅ Introduced `bin/dispatch.sh` so any squad/dispatcher can be invoked through a single entry point, with dispatcher mappings defined in `squads.json`.

### Configuration & Flexibility (November 2025)

- ✅ C1: added `ai-staff-hq/squads.json` + `dhp-config.sh` so squads load from config instead of hardcoding.
- ✅ C2: introduced `--temperature`/`--max-tokens` flags + per-dispatcher env overrides; `call_openrouter` honors them.
- ✅ C3: added `bin/dispatch.sh` to provide a single entry point (falls back to `dhp-*` scripts).
- ✅ C4: created `dhp-utils.sh` with `validate_dependencies`/`ensure_api_key` helpers and wired every dispatcher to it.
- ✅ Dispatchers now accept quoted arguments (no stdin required) via `read_dispatcher_input`, so copy/paste commands work anywhere.
- ✅ Added optional `swipe` wrapper + `.env` knobs to capture impressive outputs into a Markdown log.
### Model Configuration & Spec Template System (November 10, 2025)

**Phase 6: Optimized Models & Structured Workflow ✅**

Upgraded all AI dispatchers with optimized free models and implemented a spec-driven workflow for complex tasks.

**Model Configuration Migration:**
- ✅ Migrated all dispatchers to optimized free models from OpenRouter
- ✅ Added 7 primary dispatcher model configurations to `.env`:
  - `TECH_MODEL` → DeepSeek R1-0528 (671B params, enhanced reasoning)
  - `CREATIVE_MODEL` → Llama 4 Maverick (400B params, multimodal, 1M context)
  - `CONTENT_MODEL` → Qwen3 Coder (480B params, code/technical content)
  - `STRATEGY_MODEL` → Polaris Alpha (256K context, experimental GPT-5.1)
  - `MARKET_MODEL` → Llama 4 Scout (109B params, 10M token context)
  - `RESEARCH_MODEL` → GLM-4.5-Air (106B params, efficient reasoning)
  - `STOIC_MODEL` → DeepSeek R1-0528 (same as tech, excellent depth)
- ✅ Added 3 fallback model configurations:
  - `FALLBACK_GENERAL` → Mistral Small 3.1 (24B params, low latency)
  - `FALLBACK_CONSISTENT` → Optimus Alpha (OpenRouter in-house)
  - `FALLBACK_MULTIMODAL` → Gemini 2.0 Flash Experimental (multimodal)
- ✅ Updated all 10 dispatcher scripts to read from `.env` with fallbacks:
  - `dhp-tech.sh`, `dhp-creative.sh`, `dhp-content.sh`
  - `dhp-strategy.sh`, `dhp-market.sh`, `dhp-research.sh`
  - `dhp-stoic.sh`, `dhp-copy.sh`, `dhp-narrative.sh`, `dhp-brand.sh`
- ✅ Backward compatibility: Falls back to legacy `DHP_*` variables, then hardcoded defaults
- ✅ All dispatchers now use optimized models suited to their specific tasks

**Spec Template System:**
- ✅ Created `~/dotfiles/templates/` directory with 8 template files
- ✅ Dispatcher-specific templates:
  - `tech-spec.txt` - Debug/technical analysis with context
  - `creative-spec.txt` - Story generation with structure
  - `content-spec.txt` - Content creation with SEO
  - `strategy-spec.txt` - Strategic analysis with constraints
  - `market-spec.txt` - Market research with focus
  - `research-spec.txt` - Knowledge synthesis
  - `stoic-spec.txt` - Stoic coaching with reflection
  - `dispatcher-spec-template.txt` - Generic fallback
- ✅ Created `spec_helper.sh` script for template workflow:
  - Opens dispatcher-specific template in configured editor
  - Auto-pipes completed spec to appropriate dispatcher
  - Archives completed specs to `~/.config/dotfiles-data/specs/`
  - Timestamp-based naming for easy retrieval
  - macOS-compatible temp file handling
- ✅ Added `spec` command alias via `aliases.zsh`
- ✅ Configured `EDITOR="code --wait"` in `.zshrc` for VS Code integration
- ✅ Created specs archive directory at `~/.config/dotfiles-data/specs/`

**Workflow Improvements:**
- ✅ Structured input: Templates guide comprehensive dispatcher requests
- ✅ Reusability: Saved specs can be edited and reused
- ✅ Documentation: Spec archive serves as project history
- ✅ Flexibility: Optional - traditional stdin/heredoc methods still work
- ✅ Editor integration: Works with VS Code, Vim, Nano, or any `$EDITOR`

**Usage Examples:**
```bash
# Use spec-driven workflow
spec tech           # Opens tech template in editor
spec creative       # Opens creative template
spec content        # Opens content template

# Reuse previous specs
ls ~/.config/dotfiles-data/specs/
cat ~/.config/dotfiles-data/specs/20251110-100534-tech.txt | tech

# Traditional methods still work
echo "Quick question" | tech
cat script.sh | tech --stream
```

**Documentation:**
- ✅ Updated `bin/README.md` with comprehensive spec workflow section
- ✅ Added template descriptions and usage examples
- ✅ Documented spec reuse patterns and multi-line input alternatives
- ✅ Updated metadata: Phase 6 complete, November 10, 2025

**Impact:**
- **Cost Optimization:** Free models reduce API costs while maintaining quality
- **Task-Specific Models:** Each dispatcher uses model optimized for its specialty
- **Improved Output Quality:** Structured templates guide better AI responses
- **Knowledge Retention:** Archived specs preserve successful patterns
- **Workflow Efficiency:** Less context switching between editor and terminal

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
- ✅ Added shorthand aliases: `tech`, `creative`, `content`, `strategy`, `brand`, `market`, `stoic`, `research`, `narrative`, `aicopy`
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
- ✅ **New (W2):** Integrated `health.sh` energy scores (low energy → Stoic Coach, high energy → Strategy)
- ✅ **New (W2):** Integrated `meds.sh` adherence checks and refill reminders
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
