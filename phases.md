# Dotfiles Masterplan Phases

Last updated: February 11, 2026
Owner: `dotfiles` root project
Canonical behavior contract: `CLAUDE.md`

## Purpose

This file is the single source of truth for the active implementation plan for the
execution coach system in `startday` and `goodevening`.

Use this file to bootstrap new conversations without re-explaining context.

## North Star

Build a reliable, brain-fog-friendly daily coaching system that:

- stays high-signal and actionable,
- uses structured behavior data from `~/.config/dotfiles-data`,
- prevents drift/tinkering,
- remains safe under AI failures/timeouts,
- and preserves context across days.

## Master Status Snapshot

- Phase 0: Completed
- Phase 1: Completed
- Phase 2: Completed
- Phase 3: Completed
- Phase 4: Current (quality tuning and behavior calibration)
- Phase 5: Planned

## Phase 0 - Coherence Reset (Completed)

Objective:

- Make project contracts coherent before adding more features.

Delivered:

- Canonical contract model centered on `CLAUDE.md`.
- Derived docs aligned to canonical contract.
- Portability cleanup (removed machine-specific absolute-path language in derived docs).

Primary artifacts:

- `CLAUDE.md`
- `README.md`
- `docs/start-here.md`
- `docs/system-overview.md`
- `docs/happy-path.md`
- `docs/ai-quick-reference.md`
- `scripts/README.md`
- `scripts/README_aliases.md`

Acceptance checks:

- Derived docs do not contradict canonical behavior.
- Runtime behavior matches docs for startday/goodevening coach flows.

## Phase 1 - Coach Foundation (Completed)

Objective:

- Introduce deterministic coaching data + persistence + strict output contracts.

Delivered:

- New coaching library with sourced-file conventions:
  - `scripts/lib/coach_ops.sh`
- Deterministic collectors and digest builders:
  - tactical metrics (default 7d)
  - pattern metrics (default 30d)
  - malformed-line/data-quality flags
  - drift/working signal classification
- Mode + log persistence:
  - `coach_mode.txt` (`LOCKED`/`OVERRIDE`)
  - `coach_log.txt` (append-only coaching records)
- Strict schema contracts:
  - startday: `North Star`, `Do Next`, `Operating insight`, `Anti-tinker rule`, `Health lens`, `Evidence check`
  - goodevening: `What worked`, `Where drift happened`, `Likely trigger`, `Tomorrow lock`, `Health lens`, `Evidence used`

Primary artifacts:

- `scripts/lib/coach_ops.sh`
- `scripts/startday.sh`
- `scripts/goodevening.sh`
- `scripts/lib/config.sh`
- `.env.example`

Acceptance checks:

- Both flows produce schema-compliant output.
- Mode/log files are pipe-delimited and append safely.

## Phase 2 - Reliability and Safety Hardening (Completed)

Objective:

- Ensure coach output is always available and never hangs.

Delivered:

- Timeout wrapper + retry path for strategy calls.
- Deterministic fallback outputs for startday and goodevening.
- Grounding guard to reject ungrounded scope-expansion in AI "Do Next".
- Path validation fail-closed behavior for coach mode/log files.
- Secure temp-file handling fallback for timeout execution path.
- Cross-platform file mtime helper extracted to shared date utils:
  - `scripts/lib/date_utils.sh:file_mtime_epoch`

Primary artifacts:

- `scripts/lib/coach_ops.sh`
- `scripts/lib/date_utils.sh`
- `scripts/startday.sh`
- `scripts/goodevening.sh`

Acceptance checks:

- No indefinite stall after `AI BRIEFING` or `AI REFLECTION`.
- Timeout/error paths return valid structured fallback output.
- Full test suite remains green.

## Phase 3 - Interface Cleanup and Developer Ergonomics (Completed)

Objective:

- Remove obsolete token-capping semantics and reduce ambiguity in interfaces.

Delivered:

- `--max-tokens` removed from active behavior.
- Unknown flags fail fast through generic parser behavior.
- `max_tokens` removed from active payload path.
- Legacy token-cap docs removed from active docs (history retained in changelog).
- Prompt builders extracted into explicit coach library APIs.
- Redundant coach/logging and variable-shadowing cleanup in daily scripts.

Primary artifacts:

- `bin/dhp-shared.sh`
- `bin/dhp-content.sh`
- `bin/dhp-lib.sh`
- `bin/dispatch.sh`
- `scripts/lib/coach_ops.sh`
- `scripts/startday.sh`
- `scripts/goodevening.sh`

Acceptance checks:

- No active `max_tokens` behavior in runtime paths.
- Existing tests for dispatcher unknown-flag behavior pass.

## Phase 4 - Output Quality Tuning (Current)

Objective:

- Improve practical coaching quality in real daily usage while preserving reliability.

Current focus:

- Increase "high signal, low noise" guidance quality.
- Keep "Do Next" tightly grounded in focus + top tasks.
- Calibrate anti-tinker boundaries for realistic execution.
- Tune wording for disability-aware pacing without over-prescription.

Work items:

- Observe real run output over multiple days.
- Refine prompt constraints only when repeated quality failures are observed.
- Add targeted tests when new failure patterns appear.
- Address codebase-audit items in priority order (P0 -> P3) without regressing coach reliability.

Report remediation status (from `REPORT.md`):

- P0 completed (v2.2.16):
  - #1 `context_capture` eval-style restore output removed (now plain path output + strict context-name validation)
  - #2 `goodevening` temp-file handling hardened with `create_temp_file` + `trap` cleanup
  - #3 `blog.sh` now validates blog paths unconditionally
  - #4 `blog.sh` fails hard on missing required blog libraries
- P1 completed (v2.2.17, v2.2.18):
  - #5 all `DATA_DIR` hardcoded home-path fallbacks removed across `scripts/` and `bin/`
  - #6 direct `.env` sourcing removed from workflow/dispatcher entrypoints; only `config.sh` + `validate_env.sh` may source `.env`
  - #7 library self-sourcing removed from 7 core libs with explicit caller dependency contracts; callers/tests updated
- Partially addressed:
  - #20 goodevening subshell temp-file lifecycle fixed (via #2); subshell communication pattern unchanged
  - #33 double-sourcing accepted and documented as compatibility bridge in `common.sh` header
- P2 completed (v2.2.19):
  - #8 workflow coupling reduced with `scripts/lib/coaching.sh` facade and `coaching_*` calls in `startday.sh`/`goodevening.sh`
  - #9 goodevening date-state logic simplified and documented (system-date fallback + warning when `current_day` marker is missing/invalid)
- P2 hardened (v2.2.21):
  - #9 date-state reliability hardened with stale-marker detection (>24h) and pre-04:00 interactive fallback behavior
  - coach dependency loading aligned (`coach_ops.sh` and facade both required in workflow entrypoints)
- P2 completed (v2.2.20):
  - #14 sanitize+newline-escape duplication removed via shared `sanitize_for_storage()` helper in `common.sh` and adoption in core data writers/libs
- P2 partially addressed (v2.2.23):
  - #16 Pass A completed: `bin/dhp-copy.sh` migrated to shared `dhp_dispatch` path; dispatcher unknown-flag regression test expanded for `dhp-copy.sh`
- P2 completed (v2.2.24):
  - #16 Pass B completed: shared dispatcher mapping helper (`dhp_dispatcher_script_name`) added to `bin/dhp-shared.sh` and adopted by both `bin/dhp-chain.sh` and `bin/swipe.sh`
- P2 completed (v2.2.25):
  - #11 POSIX function declaration cleanup completed in blog libraries (`scripts/lib/blog_ops.sh`, `scripts/lib/blog_gen.sh`, `scripts/lib/blog_lifecycle.sh`)
- P2 completed (v2.2.26):
  - #10 test coverage expansion completed via `tests/test_p2_utility_scripts.sh` and `tests/test_scripts_syntax.sh`
  - #12 error-handling standardization completed across the remaining utility-script P2 scope
  - #13 ad-hoc validation cleanup completed with centralized validators in `startday.sh`, `goodevening.sh`, and `status.sh`
  - #15 date-utils mandate completion finalized; inline `date -v/-d/-j -f` math removed outside `date_utils.sh`
- P3 cleanup completed (v2.2.27):
  - #39/#40/#41 — error standardization, dhp-project hardening, temp-file traps
  - #42/#43 — dead code removal, test helper standardization
  - #10 — test suite expansion (syntax checks, dispatcher mapping, utility scripts)
- Remaining (P3 cleanup complete v2.2.27):
  - P3a: #34-#37 — critical/high regressions (Completed)
  - P3b: #38-#41 — medium hardening (Completed)
  - P3c: #42-#43, #10-#15 — cleanup and polish (Completed)
- Remaining (Low Priority Polish):
  - #17-#33 — minor cleanup, aliases, and non-critical edge cases

Exit criteria:

- Fallback usage becomes uncommon under normal network/model availability.
- AI outputs stay grounded and actionable with minimal manual correction.

## Phase 5 - Continuous Improvement Loop (Planned)

Objective:

- Maintain coherence and quality without regressions.

Planned:

- Weekly review of coach outputs against schema + grounding expectations.
- Periodic threshold tuning for drift/working classification.
- Documentation refresh cadence tied to behavior changes.
- Keep this file current as the master planning source.

Exit criteria:

- No recurring unresolved regressions.
- New conversation handoffs require only this file + current errors/output sample.

## Config Surface (Current)

Key coach-related settings:

- `AI_BRIEFING_ENABLED`
- `AI_REFLECTION_ENABLED`
- `AI_BRIEFING_TEMPERATURE`
- `AI_COACH_LOG_ENABLED`
- `AI_COACH_TACTICAL_DAYS`
- `AI_COACH_PATTERN_DAYS`
- `AI_COACH_MODE_DEFAULT`
- `AI_COACH_REQUEST_TIMEOUT_SECONDS`
- `AI_COACH_RETRY_ON_TIMEOUT`
- `AI_COACH_RETRY_TIMEOUT_SECONDS`
- `AI_COACH_DRIFT_STALE_TASK_DAYS`
- `COACH_LOG_FILE`
- `COACH_MODE_FILE`

Defined in:

- `scripts/lib/config.sh`
- `.env.example`

## Validation Standard

Minimum validation after coach-related edits:

```bash
bash -n scripts/startday.sh scripts/goodevening.sh scripts/lib/coach_ops.sh scripts/lib/date_utils.sh
bats tests/*.sh
```

Current known result:

- Full suite passing (`1..114`).

## Conversation Bootstrap Template

Use this in new chats:

1. "Use `phases.md` as the masterplan source of truth."
2. "Current phase is Phase 4 (Output Quality Tuning)."
3. "Do not rework completed phases unless fixing a regression."
4. "Before editing, run a quick read of: `phases.md`, `CLAUDE.md`, and relevant scripts/tests."
