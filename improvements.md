# Improvements Catalog

Comprehensive analysis of the dotfiles project identifying optimization opportunities, code quality improvements, and feature enhancements. Organized by priority and category.

**Analysis date:** 2026-03-22
**Scope:** ~102 shell scripts (19,734 lines), 22 libraries (7,865 lines), 35 test files (4,990 lines), 32 bin/ files (2,727 lines)

---

## Table of Contents

- [High Priority — Architecture & DRY](#high-priority--architecture--dry)
- [Medium Priority — Code Quality](#medium-priority--code-quality)
- [Low Priority — Polish & Consistency](#low-priority--polish--consistency)
- [Test Coverage Gaps](#test-coverage-gaps)
- [Documentation Issues](#documentation-issues)
- [Feature Enhancements](#feature-enhancements)
- [Accessibility Improvements (MS-Specific)](#accessibility-improvements-ms-specific)

---


## Medium Priority — Code Quality

### M1. Health Metrics Aggregation Scattered Across Scripts

**Files:** `startday.sh`, `goodevening.sh`, `status.sh`, `health.sh`

Four scripts independently grep/awk health files for daily summaries using different extraction logic.

**Fix:** Create `health_ops_get_daily_summary()` in `health_ops.sh` returning all metrics (energy, fog, symptoms, spoons) in a structured format. Replace per-script extraction logic.

### M2. GitHub Activity Filtering Uses Brittle Text Parsing

**Files:** `scripts/status.sh` (~lines 58-132), `startday.sh`, `goodevening.sh`

Three scripts parse unstructured text output from GitHub operations using fragile regex and awk patterns.

**Fix:** Refactor `github_ops.sh` to return structured data (pipe-delimited or key=value). Have display logic in callers format the structured data.

### M3. Date-Based Entry Filtering Duplicated

**Files:** `startday.sh`, `goodevening.sh`, `health.sh`, `journal.sh`

The same AWK pattern for filtering pipe-delimited entries by date appears in 4+ scripts.

**Fix:** Add `filter_entries_by_date()` to `date_utils.sh` or a new `data_ops.sh` library.

### M4. morphling.sh Doesn't Use Shared Input Handling

**File:** `bin/morphling.sh` (~line 29)

Uses raw `PIPED_CONTENT="$(cat)"` instead of `dhp_get_input()`, bypassing null-byte and size validation.

**Fix:** Source `dhp-shared.sh` and use `dhp_get_input()`.

### M5. Hardcoded Thresholds Should Be in Config

**Files:** `goodevening.sh` (~line 291-292), `health.sh` (~lines 467-503), `startday.sh` (~lines 525-529)

Magic numbers for energy thresholds (3, 4), fog thresholds (6), signal confidence counts (3, 4) are scattered.

**Fix:** Define in `config.sh`:

```bash
COACH_LOW_ENERGY_THRESHOLD="${COACH_LOW_ENERGY_THRESHOLD:-4}"
COACH_HIGH_FOG_THRESHOLD="${COACH_HIGH_FOG_THRESHOLD:-6}"
COACH_MIN_HIGH_SIGNAL_SOURCES="${COACH_MIN_HIGH_SIGNAL_SOURCES:-4}"
COACH_MIN_MEDIUM_SIGNAL_SOURCES="${COACH_MIN_MEDIUM_SIGNAL_SOURCES:-3}"
```

### M6. health.sh Duplicates date_utils Functionality

**File:** `scripts/health.sh` (~lines 29-43)

`get_file_mtime()` manually implements stat cross-platform fallbacks. `date_utils.sh` already provides `file_mtime_epoch()`.

**Fix:** Replace with `file_mtime_epoch()` from `date_utils.sh`.

### M7. goodevening.sh Date Determination Is 60 Lines

**File:** `scripts/goodevening.sh` (~lines 81-140)

Three parallel code paths (override, valid marker, invalid marker) with repeated date validation.

**Fix:** Extract into `determine_session_date()` function with clear preconditions.

### M8. Todo Line-Number-Based IDs Are Fragile

**File:** `scripts/todo.sh` (throughout)

All task operations use `sed` line numbers. If the file format changes or entries are reordered externally, operations silently target wrong tasks.

**Fix:** Add task IDs (timestamp or sequential counter) as the first field. Use IDs for all operations. This is a larger refactor but prevents data loss from race conditions.

### M9. Repeated validate_numeric Calls

**File:** `scripts/todo.sh` (~lines 64, 94, 127, 144, 181, 244, 262, 344)

The same 2-line validation pattern appears 8+ times.

**Fix:** Create `require_task_number()` wrapper.

### M10. Streaming Mode Doesn't Track Token Usage

**File:** `bin/dhp-lib.sh` (~line 155)

Sync API calls log token counts and estimated cost. Streaming calls log zeros because SSE deltas don't include cumulative usage.

**Fix:** Document this limitation. Consider parsing the final `usage` field from OpenRouter's stream completion event if available.

### M11. Hardcoded Cost Rates

**File:** `bin/dhp-lib.sh` (~lines 47-48)

Default rates ($0.50/$1.50 per million tokens) are arbitrary placeholders, not OpenRouter's actual pricing.

**Fix:** Move to config.sh or fetch from API if available. At minimum, document that costs are estimates.

### M12. dhp-shared.sh Config Failure Returns Instead of Exiting

**File:** `bin/dhp-shared.sh` `dhp_setup_env()` (~line 23)

If `config.sh` isn't found, the function `return 1`s but the dispatcher may continue executing in a partially configured state.

**Fix:** Change to `exit 1` since this runs in executed scripts, not sourced libraries.

### M13. Wrapper Files Without .sh Extension

**Files:** `bin/dhp-memory`, `bin/dhp-memory-search`

Compatibility wrappers exist alongside the `.sh` versions, creating confusion about which to use.

**Fix:** Remove the non-`.sh` wrappers or make them symlinks. Update any references.

---

## Low Priority — Polish & Consistency

### L1. Hardcoded `date` Commands in Libraries

**Files:** `scripts/lib/coach_chat.sh` (~line 158), `scripts/lib/insight_store.sh` (~line 67), `scripts/lib/spoon_budget.sh` (~line 88)

Some libraries use raw `date` commands instead of `date_utils.sh` helpers, creating minor cross-platform inconsistency.

**Fix:** Prefer `date_now`, `date_today` when `date_utils.sh` is loaded.

### L2. Duplicate Sanitization Logic

**Files:** `scripts/lib/coach_metrics.sh` `_coach_escape_field()` (~lines 19-29) vs `scripts/lib/common.sh` `sanitize_for_storage()` (~lines 295-304)

`_coach_escape_field` duplicates and extends `sanitize_for_storage` with extra control-char stripping.

**Fix:** Either call `sanitize_for_storage` and add only the extra step, or enhance `sanitize_for_storage` to handle control characters.

### L3. Inconsistent Error Message Formatting

**Across project**

Some scripts use `echo "Error: ..."`, others use `log_error`, others use emoji prefixes. No single style.

**Fix:** Standardize on `log_error` for operational errors and `die` for fatal errors.

### L4. ez Alias Quoting Issue

**File:** `zsh/aliases.zsh` (~line 607)

```bash
alias ez="code \$DOTFILES_ALIAS_ROOT/zsh/aliases.zsh"
```

The backslash-escaped `$` prevents expansion at definition time. The alias will attempt to expand at call time, which may fail if the variable isn't exported.

**Fix:** Remove the backslash: `alias ez="code $DOTFILES_ALIAS_ROOT/zsh/aliases.zsh"`

### L5. cleanup Alias Should Be a Function

**File:** `zsh/aliases.zsh` (~line 373)

```bash
alias cleanup="cd ~/Downloads && file_organizer.sh bytype && findbig.sh"
```

Compound alias with `cd` is fragile — if either command fails, the user is left in an unexpected directory.

**Fix:** Convert to a function with proper error handling.

### L6. rboot Alias References External Path

**File:** `zsh/aliases.zsh` (~line 128)

```bash
alias rboot="$HOME/Projects/bin/repo-bootstrap.sh"
```

References a script outside the dotfiles repo. Fails silently if the external path doesn't exist.

**Fix:** Remove, guard with existence check, or move the script into this repo.

### L7. fabric-ai.zsh Not Sourced from Main Aliases

**File:** `zsh/aliases/fabric-ai.zsh`

This alias pack exists in a subdirectory but isn't sourced by `aliases.zsh`. The aliases never load unless manually sourced.

**Fix:** Add `source "$ZDOTDIR/aliases/fabric-ai.zsh" 2>/dev/null` to `aliases.zsh`, or document that it requires manual setup.

### L8. Hardcoded Path in .zshrc

**File:** `zsh/.zshrc` (~line 42)

```bash
bash "$HOME/dotfiles/scripts/startday.sh"
```

Should use `$DOTFILES_DIR` for portability.

### L9. Cheatsheet Is Static

**File:** `scripts/cheatsheet.sh`

Command lists are hardcoded. If aliases or dispatchers change, the cheatsheet becomes stale.

**Fix:** Generate at least the dispatcher list dynamically from `bin/dhp-*.sh` and alias sections from `aliases.zsh`.

### L10. Missing Silent Error Context in Libraries

**Files:** `scripts/lib/spoon_budget.sh` `get_remaining_spoons()`, `scripts/lib/health_ops.sh` `show_health_summary()`

Some functions return empty/success on configuration issues without logging, making debugging difficult.

**Fix:** Add `log_warn` or `log_error` before silent returns so issues surface in logs.

### L11. Large Functions Could Be Decomposed

**Files:** `scripts/lib/spoon_budget.sh` `predict_spoon_depletion()` (107 lines), various `coach_prompts.sh` prompt builders

**Fix:** Break into focused helpers (e.g., `_spoon_extract_burn_rate`, `_spoon_project_depletion_time`).

### L12. Inconsistent Alias Path Strategy

**File:** `zsh/aliases.zsh`

Productivity aliases use bare script names (rely on PATH). Dispatcher aliases use absolute `$DOTFILES_ALIAS_ROOT/bin/` paths. If PATH breaks, only half the aliases fail.

**Fix:** Use one strategy consistently. Absolute paths are more reliable.

---

## Test Coverage Gaps

### Current State

- **35 test files** covering ~35% of code by file count
- **~66% of scripts and 8 of 22 libraries have zero tests**
- Tests focus on happy paths; very few negative/error test cases
- No cross-platform compatibility tests
- No performance/startup-time tests

### Critical Coverage Gaps (No Tests At All)

| Category         | Scripts Missing Tests                                                                                                          |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Core data        | `health.sh`, `journal.sh`, `focus.sh`, `done.sh`                                                                               |
| Input validation | `sanitize_input()`, `validate_path()`, `validate_numeric()`, `validate_range()`                                                |
| Blog pipeline    | `blog_gen.sh`, `blog_lifecycle.sh`, `blog_ops.sh`, `blog_common.sh`                                                            |
| Libraries        | `coaching.sh`, `health_ops.sh`, `insight_store.sh`, `insight_score.sh`, `github_ops.sh`, `context_capture.sh`, `coach_chat.sh` |
| Utilities        | `github_helper.sh`, `gcal.sh`, `data_validate.sh`, `validate_env.sh`, `migrate_data.sh`                                        |
| File ops         | `tidy_downloads.sh`, `file_organizer.sh`, `media_converter.sh`, `duplicate_finder.sh`                                          |

### Test Quality Improvements Needed

1. **Negative test cases** — What happens when config is missing? When files are empty? When input contains special characters?
2. **Cross-platform date tests** — macOS BSD date vs GNU date edge cases
3. **Error path testing** — Verify `die()`, `log_error()`, exit codes work correctly
4. **Coach system gaps** — Interactive coach chat has zero tests; mode transitions (LOCKED/FLOW/OVERRIDE/RECOVERY) untested; evidence check fallbacks when GitHub API fails untested
5. **Integration tests** — Full startday -> status -> goodevening flow; todo -> done -> completed tracking

### Test Infrastructure Improvements

- No `tests/README.md` documenting BATS patterns, helpers, or mock strategies
- `mock_ai.sh` is minimal — doesn't simulate actual dispatcher behavior
- No guidance in CLAUDE.md on writing tests beyond basic structure

---

## Documentation Issues

### Stale Counts

| File                                                | Claims                | Actual        | Fix          |
| --------------------------------------------------- | --------------------- | ------------- | ------------ |
| `README.md` (~line 75)                              | "37 automatic tests"  | 33 test files | Update count |
| `docs/README.md` (~line 3)                          | "21 helper files"     | 22 libraries  | Update count |
| `docs/general-reference-handbook.md` (~lines 14-18) | "21 shared libraries" | 22            | Update count |

### Missing Documentation

1. **Testing guide** — CLAUDE.md's "Testing Guidelines" section (~lines 360-365) is minimal. Needs: BATS patterns, mock examples, error-path testing patterns, how to extend test helpers.
2. **`tests/README.md`** — Should exist, covering framework overview, available assertions, mock patterns, data isolation.
3. **Bash 4 requirement** — `time_tracking.sh` requires Bash 4+ for associative arrays. Not mentioned in CLAUDE.md, README, or `validate_env.sh`.
4. **Dispatcher cost tracking limitation** — Streaming mode logs zero tokens. Not documented anywhere.
5. **`CHANGELOG.md.new`** — Stale file in project root (1,832 lines). Should be merged into `CHANGELOG.md` or removed.

---

## Feature Enhancements

### Script UX

| Script           | Enhancement                             | Complexity | Benefit                          |
| ---------------- | --------------------------------------- | ---------- | -------------------------------- |
| `startday.sh`    | `--help` flag                           | Low        | Discoverability                  |
| `startday.sh`    | `--skip-briefing` flag                  | Low        | Faster low-energy starts         |
| `startday.sh`    | `--quiet` flag                          | Low        | Batch/automation support         |
| `goodevening.sh` | `--help` flag                           | Low        | Discoverability                  |
| `goodevening.sh` | `--skip-checks` flag                    | Low        | Faster non-interactive runs      |
| `status.sh`      | `--help` flag                           | Low        | Discoverability                  |
| `status.sh`      | `--export json` output                  | Medium     | Enable external tool consumption |
| `health.sh`      | `--predict` energy depletion forecast   | High       | Planning value for MS management |
| `todo.sh`        | Task priority levels (1-5)              | Medium     | Better prioritization            |
| `journal.sh`     | Tag-based organization (#work, #health) | Medium     | Better searchability             |
| `blog.sh`        | `--dry-run` for publish                 | Low        | Safety before deploy             |

### Dispatcher Infrastructure

| Enhancement                                    | Complexity | Benefit                       |
| ---------------------------------------------- | ---------- | ----------------------------- |
| Retry with exponential backoff on API failures | Medium     | Reliability under rate limits |
| Configurable `--max-parallel` per dispatcher   | Low        | Tunable for system resources  |
| Conversation history for non-coach dispatchers | Medium     | Context-aware multi-turn use  |
| Token usage tracking in streaming mode         | High       | Accurate cost reporting       |

---

## Accessibility Improvements (MS-Specific)

The system is well-designed for the stated MS accessibility goal. These additions would further reduce cognitive load and support energy management:

### A1. Low-Energy Mode

Add `--low-energy` flag to `startday.sh` and `status.sh` that:

- Skips AI briefings (slow, high-cognitive-load)
- Skips GitHub checks (network-dependent, can hang)
- Shows only: focus, spoon budget, top 3 tasks
- Reduces output to essentials

### A2. Energy Cost Estimates Per Task

Add estimated spoon cost to task display. Based on historical time-tracking and energy data, show predictions like:

```
1. Fix login bug [~2 spoons, ~45min]
2. Write blog post [~4 spoons, ~90min]
```

### A3. Aggressive AI Timeouts

Add configurable timeout for all AI calls (default: 30s instead of current 300s). During brain fog, waiting 5 minutes for a response is a workflow killer.

```bash
AI_CALL_TIMEOUT="${AI_CALL_TIMEOUT:-30}"
```

### A4. Circuit Breaker Suggestions

When `health.sh check` triggers the circuit breaker (low energy / high fog), suggest specific low-energy actions instead of just warning:

```
Energy is low. Consider:
  - Review yesterday's journal (journal list)
  - Quick spoon check (s-check)
  - Take a break (break)
```

---

## Summary by Effort

### Quick Wins (< 30 min each)

- L4: Fix ez alias quoting
- L5: Convert cleanup to function
- M9: Create require_task_number()
- M5: Move thresholds to config.sh
- Documentation count fixes (3 files)

### Medium Effort (1-3 hours each)

- M6: Replace health.sh date_utils duplication
- M7: Extract session date determination
- M12: Fix config failure handling

### Larger Efforts (half-day to multi-day)

- M1: Health metrics aggregation library
- M2: Structured GitHub activity data
- M8: Todo task ID system
- Test coverage expansion (ongoing)
