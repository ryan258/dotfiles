Codebase Audit Report: /Users/ryanjohnson/dotfiles

Executive Summary

Reviewed 65+ scripts, 17 libraries, 27 bin/ files, 27 test files, and all documentation.
The codebase is well-structured with strong conventions and excellent documentation
governance. That said, there are systemic patterns that have accumulated as technical debt.
Below are the findings organized by severity.

---

CRITICAL: Security & Correctness

[DONE] 1. context_capture.sh — eval-intended output pattern (v2.2.16)

Resolved: restore_context() now returns plain directory path. Strict context-name
validation with allowlist regex. New restore_context_dir() helper for sourced contexts.

[DONE] 2. goodevening.sh — temp file without cleanup trap (v2.2.16)

Resolved: Replaced mktemp with create_temp_file(). Added trap-based cleanup with early
init guard. Variable cleared after manual rm.

[DONE] 3. blog.sh — path validation only for $HOME paths (v2.2.16)

Resolved: validate_safe_path() now runs unconditionally for BLOG_DIR, BLOG_DRAFTS_DIR,
and BLOG_POSTS_DIR. Absolute-path check precedes validation.

[DONE] 4. blog.sh — library sourcing without existence checks (v2.2.16)

Resolved: Blog libraries now loaded in a loop with require_file() + source. Missing
library dies with clear error message.

---

HIGH: Architectural Misalignments

[DONE] 5. Hardcoded path fallbacks everywhere (DRY violation) (v2.2.17, v2.2.18)

Resolved: All DATA_DIR home-path fallbacks removed from scripts/ and bin/. Scripts now
consume config-owned variables directly or fail fast with :? guards.

[DONE] 6. Direct .env sourcing bypasses config.sh (v2.2.17)

Resolved: Direct .env sourcing removed from startday.sh, goodevening.sh,
blog_recent_content.sh, dhp-shared.sh, dhp-project.sh, swipe.sh. Only config.sh and
validate_env.sh may source .env.

[DONE] 7. Redundant library re-sourcing in lib/ files (v2.2.17)

Resolved: Self-sourcing removed from coach_ops.sh, time_tracking.sh, spoon_budget.sh,
insight_store.sh, insight_score.sh, blog_lifecycle.sh, context_capture.sh. Replaced with
dependency contract comments and fail-fast guards. Callers/tests updated.

[DONE] 8. Tight coupling between workflow scripts and coach_ops.sh (v2.2.19)

Resolved: Added thin facade `scripts/lib/coaching.sh` and rewired `startday.sh` +
`goodevening.sh` to call `coaching_*` APIs (prompt build, retry invoke, fallback, digest,
mode, log) instead of calling coach_ops internals directly.

[DONE] 9. CURRENT_DAY_FILE as implicit state machine (v2.2.19)

Resolved and hardened (v2.2.19 + v2.2.21):

- `--refresh` => system date
- `current_day` present and valid => use marker
- stale marker (>24h old) => system date with `log_warn`
- marker missing:
  - interactive and before 04:00 => previous day
  - otherwise => system date with `log_warn`
- marker invalid => system date with `log_warn`

[DONE] 10. ~35 scripts have zero test coverage (v2.2.26)

Resolved:

- Added runtime smoke coverage for the previously untested utility scripts called out in this report:
  - `focus.sh`, `status.sh`, `backup_data.sh`, `dev_shortcuts.sh`, `schedule.sh`,
    `logs.sh`, `network_info.sh`, `clipboard_manager.sh`, `dump.sh`, `data_validate.sh`
  - implemented in `tests/test_p2_utility_scripts.sh`
- Added broad syntax coverage for all executable and library scripts:
  - implemented in `tests/test_scripts_syntax.sh`
- Full test suite now includes these additions and remains green (`1..114`).

---

MEDIUM: Code Smells & Inconsistencies

[DONE] 11. POSIX-noncompliant function definitions in blog libraries (v2.2.25)

Resolved: Converted remaining non-POSIX `function name()` definitions in:

- `scripts/lib/blog_ops.sh`
- `scripts/lib/blog_gen.sh`
- `scripts/lib/blog_lifecycle.sh`
  to POSIX-style `name()` declarations.

[DONE] 12. Inconsistent error handling — die() vs inline echo+exit (v2.2.26)

Resolved:

- Extended standardized fatal/argument error handling into additional utility scripts:
  - `scripts/focus.sh`
  - `scripts/status.sh`
  - `scripts/backup_data.sh`
  - `scripts/dev_shortcuts.sh`
  - `scripts/schedule.sh`
  - `scripts/logs.sh`
  - `scripts/network_info.sh`
  - `scripts/clipboard_manager.sh`
  - `scripts/dump.sh`
  - `scripts/data_validate.sh`
- Utility command failures now consistently return canonical exit semantics and log paths
  instead of ad-hoc `echo ...; exit 1` patterns in core user-facing flows.

[DONE] 13. Inconsistent validation — ad-hoc vs validate\_\*() functions (v2.2.26)

Resolved:

- Added `validate_date_ymd()` to `scripts/lib/common.sh`.
- Replaced ad-hoc validation paths with centralized validators in:
  - `scripts/startday.sh` (spoon count numeric validation)
  - `scripts/goodevening.sh` (date override/marker validation)
  - `scripts/status.sh` (energy/fog range checks)

[DONE] 14. Duplicated sanitize-and-escape pattern (v2.2.20)

Resolved: Added `sanitize_for_storage()` to `scripts/lib/common.sh` and replaced repeated
sanitize+newline-escape blocks in:

- `scripts/todo.sh`
- `scripts/journal.sh`
- `scripts/health.sh`
- `scripts/lib/insight_store.sh`
- `scripts/lib/time_tracking.sh`
- `scripts/lib/spoon_budget.sh`

[DONE] 15. Inconsistent date handling — not all scripts use date_utils.sh (v2.2.26)

Resolved:

- Expanded `scripts/lib/date_utils.sh` with:
  - `date_now`, `date_today`, `date_epoch_now`, `date_hour_24`, `date_weekday_iso`
  - `date_shift_days_utc`, `date_now_utc`, `epoch_to_utc_iso`
- Extended `timestamp_to_epoch()` support for ISO UTC timestamps.
- Removed remaining inline cross-platform date math (`date -v`, `date -d`, `gdate -d`, `date -j -f`)
  outside `date_utils.sh` by migrating:
  - `scripts/goodevening.sh`
  - `scripts/gh-projects.sh`
  - `scripts/meds.sh`
  - `scripts/github_helper.sh`
  - `scripts/gcal.sh`
  - `scripts/generate_report.sh`
  - `scripts/insight.sh`
  - `scripts/lib/github_ops.sh`
  - `scripts/lib/health_ops.sh`

[DONE] 16. Code duplication in dispatchers (v2.2.23, v2.2.24)

Completed:

- `bin/dhp-copy.sh` now uses canonical shared `dhp_dispatch` flow from `bin/dhp-shared.sh`
  instead of custom orchestration/parsing boilerplate.
- Added regression coverage in `tests/test_dispatcher_unknown_flags.sh` for `dhp-copy.sh`
  shared unknown-flag behavior.
- Added shared dispatcher mapping helpers in `bin/dhp-shared.sh`:
  - `dhp_available_dispatchers`
  - `dhp_dispatcher_script_name`
- Rewired both `bin/dhp-chain.sh` and `bin/swipe.sh` to use shared dispatcher mapping.
- Added mapping helper tests in `tests/test_dispatcher_mapping.sh`.

[DONE] 17. dhp-memory and dhp-memory-search missing .sh extension (v2.2.28)

Resolved:

- Added canonical scripts: `bin/dhp-memory.sh`, `bin/dhp-memory-search.sh`.
- Kept extensionless compatibility wrappers (`bin/dhp-memory`, `bin/dhp-memory-search`) that
  `exec` the canonical `.sh` scripts.
- Updated shared caller path in `bin/dhp-shared.sh` to `dhp-memory.sh`.

[DONE] 18. dhp-config.sh is a near-empty placeholder (v2.2.28)

Resolved:

- Removed `bin/dhp-config.sh` placeholder.
- `bin/dispatch.sh` continues to use `DHP_SQUADS_FILE` env override with default fallback.

[DONE] 19. Magic numbers without named constants (v2.2.28)

Resolved:

- Added `DEFAULT_LOG_ROTATE_MAX_BYTES` in `scripts/lib/common.sh`.
- Added `HEALTH_SECONDS_PER_DAY` in `scripts/lib/health_ops.sh`.
- Added `INSIGHT_MIN_INDEPENDENT_SOURCES` in `scripts/lib/insight_score.sh`.
- Added/used named thresholds in `scripts/lib/coach_ops.sh` (including trend delta and
  drift thresholds).

[DONE] 20. goodevening.sh subshell variable scope issue (v2.2.28)

Resolved:

- Replaced fragile subshell/temp-file issue signaling with parent-shell function flow.
- Added `project_has_safety_issue()` in `scripts/goodevening.sh` and direct `found_issues`
  updates in the main loop.

[DONE] 21. correlation_engine.sh — stub function and external dependency (v2.2.28)

Resolved:

- Implemented `predict_value()` with deterministic numeric output.
- Added graceful inline fallbacks for both `correlate_two_datasets()` and `find_patterns()`
  when `correlate.py` is unavailable.
- Added regression coverage in `tests/test_correlation_engine_lib.sh`.

[DONE] 22. Unused or rarely-checked config variables (v2.2.28)

Resolved:

- `STALE_TASK_DAYS` is used in `scripts/startday.sh` and coaching drift metrics.
- `REVIEW_LOOKBACK_DAYS` is now explicitly required/validated in `scripts/week_in_review.sh`.
- `HEALTH_COMMITS_CACHE_TTL` and `HEALTH_COMMITS_LOOKBACK_DAYS` are explicitly required in
  `scripts/health.sh`.

[DONE] 23. dev_shortcuts.sh — non-standard dual-mode pattern (v2.2.28)

Resolved:

- Replaced dual-mode behavior with executed-script-only pattern (`#!/usr/bin/env bash`,
  `set -euo pipefail`).
- Removed sourced-mode branching and standardized usage/error handling.

[DONE] 24. grep alias shadows system command without documentation (v2.2.28)

Resolved:

- Added explicit intent documentation in `scripts/README_aliases.md`.
- Kept grep shadow behavior but documented as intentional.

[DONE] 25. test_ai_suggest.sh references non-existent override (v2.2.28)

Resolved:

- `scripts/ai_suggest.sh` supports `MEDS_SCRIPT_OVERRIDE` for deterministic tests.
- `tests/test_ai_suggest.sh` override path now tests real script behavior.

34. (Retracted — dhp-memory exists; already tracked by #17 naming convention issue)

[DONE] 35. swipe.sh exit code lost through tee pipe

File: bin/swipe.sh:75-78
The `if "$RESOLVED_CMD" "$@" 2>&1 | tee -a "$LOG_FILE"` pattern captures tee's exit code,
not the command's. Should use PIPESTATUS[0] directly after the pipeline:
"$RESOLVED_CMD" "$@" 2>&1 | tee -a "$LOG_FILE"
  CMD_STATUS=${PIPESTATUS[0]}

[DONE] 36. Config fallback regressions (P1 #5 scope missed these)

After sourcing config.sh, these scripts redefine DOTFILES_DIR with hardcoded home-path
fallbacks, violating the centralization contract:

- scripts/status.sh:121 — `DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"`
- scripts/g.sh:55 — same pattern

[DONE] 37. time_tracking.sh uses undeclared date_utils.sh dependency

File: scripts/lib/time_tracking.sh:306
Calls date_shift_days (from date_utils.sh) but never declares or validates this dependency.
Compare with spoon_budget.sh which does this correctly with explicit checks.

[DONE] 38. dhp-context.sh still uses hardcoded date commands

File: bin/dhp-context.sh:64
Uses inline `date -v` / `date -d` instead of date_utils.sh helpers. Missed by #15 scope
(which focused on scripts/, not bin/).

[DONE] 39. Error messages to stdout instead of stderr (8 scripts)

Broader than #12 scope. These scripts write errors to stdout, breaking pipeline composability:

- scripts/meds.sh:108
- scripts/g.sh:256
- scripts/howto.sh:42, 91
- scripts/blog.sh:83
- scripts/mkproject_py.sh:17, 31
- scripts/new_script.sh:90

[DONE] 40. dhp-project.sh orchestration has zero error handling

File: bin/dhp-project.sh:58, 73, 92, 110, 128
Each phase pipes into dispatchers without checking exit codes. Failed phases silently produce
empty context for subsequent phases, generating garbage results.

[DONE] 41. Temp file / FIFO leaks without cleanup traps (partial)

- bin/dhp-shared.sh:165 — FIFO created in call_openrouter_stream without trap; leaked on
  Ctrl+C or abnormal exit.
- scripts/github_helper.sh:188-191 — temp files created without trap cleanup.

[DONE] 42. Dead function: diff_contexts() in context_capture.sh

After verification, only diff_contexts() (context_capture.sh:139) is truly uncalled.
Other functions initially flagged as dead are actually referenced:

- publish_site()/validate_site() called from blog.sh
- generate_insight_text() called from correlate.sh + has tests
- capture_vscode_state() called internally in context_capture.sh
  (predict_value() already tracked in #21)

[DONE] 43. Test files bypass shared helper pattern (6 files)

These tests use manual setup/teardown instead of load helpers + setup_test_environment:

- tests/test_todo.sh
- tests/test_file_ops.sh
- tests/test_ai_suggest.sh
- tests/test_blog_stubs.sh
- tests/test_g.sh
- tests/test_meds.sh

---

LOW: Minor / Nice-to-Have

[DONE] 26. memo.sh is a pure wrapper (v2.2.28)

Resolved:

- Removed `scripts/memo.sh`.
- `memo` now maps directly to `cheatsheet.sh` alias.

[DONE] 27. done.sh is macOS-only with no fallback (v2.2.28)

Resolved:

- Added cross-platform fallback notifier in `scripts/done.sh`:
  - uses `osascript` on macOS when available,
  - otherwise terminal bell + console message.
- Documented fallback behavior in `docs/daily-cheatsheet.md`.

[DONE] 28. focus.sh has an undocumented implicit "set" mode (v2.2.28)

Resolved:

- Removed implicit `focus "task"` fallback.
- Unknown commands now return usage + invalid-args status.

[DONE] 29. health.sh cmd_add() doesn't validate time format (v2.2.28)

Resolved:

- Added strict `YYYY-MM-DD HH:MM` validation in `cmd_add()`.
- Added parse validation via `timestamp_to_epoch` before write.

[DONE] 30. Hardcoded paths in aliases vs $DOTFILES_DIR (v2.2.28)

Resolved:

- Removed hardcoded `~/dotfiles` alias paths in touched script aliases.
- Dispatcher/swipe aliases now route through `DOTFILES_ALIAS_ROOT`.

[DONE] 31. Hard-coded test dates (v2.2.28)

Resolved:

- Converted `tests/test_startday_coach.sh`, `tests/test_goodevening_coach.sh`, and
  `tests/test_coach_ops.sh` fixtures to dynamic date helpers.

[DONE] 32. bin/README.md count discrepancy (v2.2.28)

Resolved:

- Clarified `bin/README.md` as "12 core dispatchers" and explicitly noted that morphling
  and finance are included in that 12-count.

[DONE] 33. startday.sh may double-source config.sh (v2.2.28)

Resolved:

- Removed redundant second config source path in `scripts/startday.sh`.
- Kept compatibility note in `common.sh` while moving startday to explicit ordered sourcing
  (`config.sh` then `common.sh`).

---

Recommended Priority Order
┌────────────────────┬─────────────────────────────────┬──────────────────────────────┐
│ Priority │ Items │ Theme │
├────────────────────┼─────────────────────────────────┼──────────────────────────────┤
│ P0 — DONE │ #1, #2, #3, #4 │ Security & correctness │
├────────────────────┼─────────────────────────────────┼──────────────────────────────┤
│ P1 — DONE │ #5, #6, #7 │ DRY / single source of truth │
├────────────────────┼─────────────────────────────────┼──────────────────────────────┤
│ P2 — DONE │ #8-#16 │ Architecture & consistency │
├────────────────────┼─────────────────────────────────┼──────────────────────────────┤
│ P3a — DONE │ #35, #36, #37 │ High from 2nd audit │
├────────────────────┼─────────────────────────────────┼──────────────────────────────┤
│ P3b — DONE │ #38, #39, #40, #41 │ Medium from 2nd audit │
├────────────────────┼─────────────────────────────────┼──────────────────────────────┤
│ P3c — DONE │ #17-#33, #42, #43 │ Dead code, tests, polish │
└────────────────────┴─────────────────────────────────┴──────────────────────────────┘

Completion log:

- P0 #1-#4: Fixed in v2.2.16 (Feb 11, 2026)
- P1 #5-#7: Fixed in v2.2.17 + v2.2.18 (Feb 11, 2026)
- P2 #8-#9: Fixed in v2.2.19 (Feb 11, 2026)
- P2 #9: Hardened in v2.2.21 (stale marker + pre-04:00 fallback behavior)
- P2 #14: Fixed in v2.2.20 (Feb 11, 2026)
- P2 #16: Partially addressed in v2.2.23 (Pass A: `dhp-copy.sh` migrated to shared dispatch path + tests)
- P2 #16: Completed in v2.2.24 (Pass B: shared dispatcher map helper used by `dhp-chain.sh` + `swipe.sh`)
- P2 #11: Completed in v2.2.25 (POSIX function declarations standardized in blog libraries)
- P2 #10/#12/#13/#15: Completed in v2.2.26 (test expansion, error/validation standardization, and date_utils mandate completion)
- #34 retracted (dhp-memory exists; covered by #17)
- P3a #35-#37: Fixed (swipe.sh exit code, config fallback regressions, time_tracking dep)
- P3b #38-#41: Fixed (dhp-context dates, stderr redirection, dhp-project error handling, github_helper trap)
- P3c #42-#43: Fixed (dead diff_contexts removed, 6 test files migrated to shared helpers)
- P3c #17-#33: Completed in v2.2.28 (naming/config cleanup, fallback hardening, alias/doc fixes, dynamic coach tests)
