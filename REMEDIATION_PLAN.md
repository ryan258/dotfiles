# Remediation Plan (Dotfiles Only)

**Scope:** `dotfiles/` repo only (exclude `ai-staff-hq/`).

**Primary Goals**
1. Enforce AGENTS/CLAUDE standards consistently across scripts and libraries.
2. Make `scripts/lib/config.sh` the single source of truth for paths/models.
3. Migrate existing data in `~/.config/dotfiles-data/` to the standardized formats.
4. Add a repeatable verification and testing plan to ensure migrations are safe and correct.

---

## Assumptions & Decisions
- We will **enforce standards**, not relax them.
- Data in `~/.config/dotfiles-data/` will be migrated to match the final standardized formats.
- The remediation will **not** modify `ai-staff-hq/`.
- Any format contradictions in AGENTS/CLAUDE will be resolved by updating those docs to match the adopted format.

---

## Phase 0 — Define Canonical Standards (Docs First)
**Purpose:** Remove ambiguity before code changes.

1. **Resolve Data Format Conflicts**
   - Decide on canonical pipe-delimited formats for *all* dotfiles data files.
   - Update `AGENTS.md` and `CLAUDE.md` so the “Critical Rules Summary” and the “Data Conventions” table match.
   - Update `docs/` where necessary to reflect the final canonical formats.

2. **Codify Script Type Rules**
   - Ensure AGENTS/CLAUDE clearly state:
     - Executed scripts: `#!/usr/bin/env bash` + `set -euo pipefail`.
     - Sourced libraries/scripts: no `set -euo pipefail`, add double-source guards, use `return` not `exit`.

**Deliverables:**
- Updated `AGENTS.md`, `CLAUDE.md`, and any docs that reference data formats or script headers.

---

## Phase 1 — Create Migration Tooling (No Behavior Changes Yet)
**Purpose:** Prepare safe, auditable migrations.

1. **Add a Data Migration Script**
   - New script (proposed): `scripts/migrate_data.sh`.
   - Must be an executed script with strict mode and proper `SCRIPT_DIR` and `common.sh` sourcing.
   - Must:
     - Validate all paths with `validate_path()`.
     - Sanitize user input where needed.
     - Create a timestamped backup of `~/.config/dotfiles-data/` (e.g., `~/Backups/dotfiles-data-pre-migration-YYYYMMDDHHMMSS`).
     - Convert each affected file to the new pipe-delimited format.
     - Preserve ordering and entries where possible.
     - Emit a migration report summary.

2. **Add a Format Validator**
   - Extend or create a validator (could extend `scripts/data_validate.sh`):
     - Verify each data file matches the new format.
     - Warn on lines that fail parsing.
     - Optionally fix trivial issues (trim whitespace, missing fields).

**Deliverables:**
- `scripts/migrate_data.sh`
- Updated `scripts/data_validate.sh` or new validator

---

## Phase 2 — Data Migration Implementation
**Purpose:** Move the existing data into the new format.

**Target Files & Proposed Formats (to be confirmed in Phase 0):**
- `todo.txt`: `YYYY-MM-DD|task text`
- `todo_done.txt`: `YYYY-MM-DD HH:MM:SS|task text` (migrate from `[timestamp] task`)
- `journal.txt`: `YYYY-MM-DD HH:MM:SS|entry text` (migrate from `[timestamp] entry`)
- `health.txt`: `TYPE|DATE|field1|field2...` (validate/normalize)
- `spoons.txt`: `BUDGET|DATE|count` or `SPEND|DATE|TIME|count|activity|remaining` (validate/normalize)
- `dir_bookmarks`: `name|path|on_enter|venv_path|apps` (migrate from colon-delimited)
- `dir_history`: `timestamp|path` (if currently implicit/line-only, add timestamps where possible)
- `dir_usage.log`: `timestamp|path` (normalize)
- `clipboard_history`: migrate to `clipboard.txt` with `timestamp|name|content` (or similar), update `clipboard_manager.sh` to use the new file.

**Deliverables:**
- Migration performed by `scripts/migrate_data.sh`.
- Backup snapshot created before migration.

---

## Phase 3 — Codebase Conformance
**Purpose:** Bring scripts/libs/dispatchers into standard compliance.

1. **Shebang + Strict Mode Alignment**
   - Executed scripts: `#!/usr/bin/env bash` + `set -euo pipefail`.
   - Sourced files: no strict mode, add double-source guards.
   - Update `scripts/new_script.sh` template to generate compliant headers.

2. **Library Hygiene**
   - Remove strict mode from sourced libs in:
     - `scripts/lib/*.sh`
     - `bin/dhp-*.sh` libraries meant to be sourced
   - Add double-source guards to all sourced libraries that don’t already have them.

3. **Config Consolidation**
   - Ensure `scripts/lib/config.sh` is sourced wherever paths/models are needed.
   - Replace local `DATA_DIR=...` definitions with values from config.
   - Reduce duplication between `scripts/lib/common.sh` and `bin/dhp-utils.sh` (single `validate_path` implementation).

4. **Input Sanitization & Path Validation**
   - Ensure any script that writes user input uses `sanitize_input()` before writes.
   - Ensure any script that uses user paths calls `validate_path()`.
   - Example targets: `scripts/todo.sh`, `scripts/journal.sh`, `scripts/g.sh`, `scripts/clipboard_manager.sh`.

**Deliverables:**
- All scripts/libs aligned with AGENTS/CLAUDE standards.
- Centralized config usage.

---

## Phase 4 — Behavior & Feature Cleanup
**Purpose:** Reduce orphans and TODOs that imply broken or misleading behavior.

1. **Orphaned/Partial Features**
   - Decide whether to finish, deprecate, or remove:
     - `context_capture` library (currently tested but not used in production scripts)
     - `generate_time_report` placeholder
     - `correlate.sh` `find-patterns` / `explain` stubs

2. **Docs Alignment**
   - Update `scripts/README.md`, `docs/*.md`, and any cheat sheets to reflect actual behavior.

**Deliverables:**
- Either completed features or explicit deprecation notes.
- Updated docs.

---

## Testing Plan (Migration-Safe)
**Objective:** Ensure migration correctness and prevent data loss.

1. **Pre-Migration Checks**
   - Run the format validator on existing data and log anomalies.
   - Confirm backup location and available disk space.

2. **Migration Dry Run**
   - Add a `--dry-run` mode to `scripts/migrate_data.sh`:
     - No writes, but outputs planned conversions and counts.

3. **Migration Execution**
   - Run migration with backup enabled.
   - Verify file counts before/after:
     - `wc -l` per data file.
     - Total entries preserved per file.

4. **Post-Migration Validation**
   - Run format validator to confirm compliance.
   - Run key scripts that rely on data files:
     - `todo.sh list`, `todo.sh done`, `journal.sh add`, `journal.sh search`, `g.sh list`, `g.sh save`, `clipboard_manager.sh save/load`, `spoon_manager.sh check`.

5. **Regression Tests**
   - Run BATS tests in `tests/` if available:
     - `tests/test_todo.sh`, `tests/test_spoon_budget_lib.sh`, `tests/test_context_capture_lib.sh`, etc.

**Exit Criteria:**
- All validation passes.
- No data loss (entry counts preserved).
- Key workflows operate correctly.

---

## Rollback Plan
- Restore from the backup created by `scripts/migrate_data.sh`.
- Keep backups for at least 30 days or until the next successful migration.

---

## Suggested Order of Execution
1. Phase 0 (Doc + Standards Alignment)
2. Phase 1 (Migration Tooling)
3. Phase 2 (Data Migration)
4. Phase 3 (Code Conformance)
5. Phase 4 (Feature Cleanup + Docs)
6. Testing Plan

---

## Notes
- This plan assumes a single maintainer and aims for low-risk, reversible steps.
- We should avoid mixing large refactors with migrations in the same commit to ease rollback.
