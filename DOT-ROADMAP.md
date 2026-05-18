# Dotfiles Narrowing Roadmap

_Created: May 18, 2026_

## 1. Decision Record

This roadmap captures the current direction for narrowing the repo without breaking the daily system.

- Main goal: split the non-dotfiles products into sibling repos.
- Change tolerance: small behavior changes are acceptable if existing aliases and commands still work.
- Future dotfiles boundary: keep the daily loop, shared shell libraries, data tools, aliases, and tests in this repo.
- Coach direction: deterministic metrics first, AI as a short framing layer, while keeping GitHub, Fitbit, and Drive tracking.
- AI dispatchers: collapse the many `dhp-*` wrappers into one registry-driven entrypoint while preserving current aliases.
- Data storage: keep flat files for now.
- Documentation: keep current docs, but make stale inventories/counts generated instead of manually maintained.
- First practical step: use this file as the thorough roadmap before implementation.
- Compatibility priority: preserve every current command and alias unless removal is separately approved later.

## 2. Roadmap Principle

The repo should become easier to operate on low-energy days.

That means the daily commands stay boring and reliable:

- `startday`
- `status`
- `goodevening`
- `todo`
- `journal`
- `health`
- `meds`
- `s-check`
- `s-spend`
- `focus`
- `schedule`
- `remind`
- `gcal`
- `drive`
- `tech`
- `strategy`
- `aicopy`
- `cyborg`
- any existing alias the shell currently exposes

The user should not have to relearn muscle memory during the cleanup. Internals can move; the surface should stay stable.

## 3. Scope Boundary

### 3.1 Dotfiles Core

The root `dotfiles` repo should keep:

- Daily loop commands: morning, midday, evening, status, focus, schedule, reminders.
- Personal data commands: todo, journal, done, ideas, time tracking.
- Health and energy commands: health, meds, spoons, Fitbit import/sync summaries.
- Context helpers needed by the daily loop: GitHub, Drive, calendar, current repo, recent work.
- Shared Bash libraries under `scripts/lib/`.
- Shell config and aliases under `zsh/`.
- Tests that protect the daily loop and compatibility wrappers.
- Documentation needed to operate and repair the daily system.

### 3.2 Compatibility Layer

The repo may keep thin wrappers for tools that move elsewhere.

Examples:

- `bin/cyborg` may become a wrapper that finds and runs the Cyborg sibling repo.
- `scripts/observer.sh` may become a wrapper that finds and runs the observer sibling repo.
- `ai-staff-hq` commands may become wrappers or documented install links.
- Existing aliases remain in `zsh/aliases.zsh`, but non-core ones can point to wrappers.

The compatibility layer is allowed because preserving commands is more important than making the repo perfectly minimal on day one.

### 3.3 Sibling Products

These should move out of root dotfiles over time:

- Cyborg content/build/publish system.
- Observer/Obsidian knowledge graph capture system.
- AI Staff HQ / LangGraph agent workforce.
- Blog factory and market-validation workflows that are not needed by the daily loop.

Each sibling product should own its own README, tests, dependencies, secrets, roadmap, and changelog.

## 4. Alias Policy

Yes, the repo split includes aliases.

But because compatibility priority is `preserve every current command and alias`, alias cleanup must be staged.

### 4.1 Alias Classes

Class A: Daily core aliases

- Keep directly in `zsh/aliases.zsh`.
- Examples: `startday`, `status`, `goodevening`, `todo`, `journal`, `health`, `s-check`, `focus`, `gcal`, `drive`.

Class B: Compatibility aliases

- Keep in `zsh/aliases.zsh`.
- Point to wrappers in this repo.
- Used for moved products like `cyborg`, `observer`, `ap`, `apb`, `morphling`, and dispatcher aliases.

Class C: Optional convenience aliases

- Keep for now.
- Later move into grouped sourced files if the alias file remains hard to scan.
- No deletion without explicit approval.

Class D: Risky or surprising aliases

- Keep for compatibility, but document them clearly.
- Examples include aliases that shadow standard commands or perform multi-step git operations.
- Later changes require separate approval because muscle memory may depend on them.

### 4.2 Alias Acceptance Criteria

Before any alias migration is considered done:

- Existing aliases must still resolve.
- Daily aliases must work in a fresh shell.
- Moved-product aliases must print a clear setup message if the sibling repo is missing.
- Alias tests or shell smoke checks must cover the compatibility path.
- No alias removal happens silently.

### 4.3 Future Deprecation Mechanism

Classification does not reduce alias surface by itself, and that is acceptable for the first pass.

If alias pruning becomes desirable later, use an opt-in warning mechanism before removing anything:

- `DOTFILES_WARN_DEPRECATED=1` enables one-line notices for Class C/D aliases that have a recommended replacement.
- Default behavior remains silent and compatible.
- Warnings must name the old alias, the replacement, and the reason in one short line.
- Removal still requires separate explicit approval after the warning path has existed for a while.
- Daily core aliases should not warn unless there is a direct user-approved replacement.

## 5. Non-Negotiable Invariants

These rules should hold through every phase:

- Do not break `startday`, `status`, or `goodevening`.
- Do not remove flat-file data formats during this roadmap.
- Do not remove GitHub, Fitbit, Drive, calendar, health, or spoon signals from the coach.
- Do not remove existing commands or aliases without explicit approval.
- Do not move secrets into this repo.
- Do not add new product scope to root dotfiles while narrowing is in progress.
- Use tests for behavior changes.
- Keep sourced-vs-executed shell discipline intact.
- Keep graceful degradation: missing APIs should produce useful fallback output, not crashes.

## 6. Phase 0: Baseline and Inventory

Goal: make the current shape visible before moving anything.

Spoon cost: 1-2 spoons.

Rollback: revert the inventory/docs commit; no runtime behavior should depend on this phase.

Deliverables:

- Generate a current command inventory from the filesystem.
- Generate an alias inventory from `zsh/aliases.zsh`.
- Classify aliases into daily core, compatibility, convenience, and risky/surprising.
- Classify scripts into daily core, support library, compatibility wrapper, sibling-product candidate, or support-utility catch-all.
- Record which tests protect each daily command.
- Record which commands rely on external APIs or credentials.
- Record baseline size metrics so later phases can prove they reduced maintenance surface.
- Apply the zero-risk artifact policy cleanup plan before larger refactors begin.

Categories to track:

- Total source LOC under `scripts/` and `bin/`.
- Top-level shell and Python counts under `scripts/`.
- Sourced shell and Python counts under `scripts/lib/`.
- `bin/` entrypoint count.
- `dhp-*.sh` wrapper count.
- Alias count and shell-function count.
- Alias counts by class after classification.
- Coach LOC by file: prompts, metrics, chat, scoring, facade.
- Cyborg/observer/product LOC by file.
- Test file count and daily-loop test coverage.
- Runtime artifact count, including repo-local `logs/`.

Initial frozen baseline source: `docs/generated/baseline-metrics.md`.

Do not update live metric values in this roadmap after Phase 0 is accepted. Later phases compare against the generated baseline file and record before/after movement there or in the phase completion notes.

Target gates to define after classification:

- Dispatcher consolidation should leave one registry-driven source of truth plus compatibility shims or generated wrappers.
- Product extraction should remove product implementation files from root dotfiles while preserving old commands through wrappers.
- Coach reshape should make deterministic brief rendering the primary path and shrink `coach_prompts.sh` to framing-prompt work.
- Alias count does not need to shrink in the first pass, but alias class counts must be known.
- Runtime artifacts should not create review noise inside the repo.

Suggested output files:

- `docs/generated/script-inventory.md`
- `docs/generated/alias-inventory.md`
- `docs/generated/test-coverage-map.md`
- `docs/generated/external-dependencies.md`
- `docs/generated/baseline-metrics.md`

Acceptance criteria:

- The inventories can be regenerated with one command.
- README/docs stop carrying manually typed script counts.
- The worktree has no untracked temp-review directories or root `.DS_Store` clutter.
- `logs/` policy is documented as ignored runtime output or moved outside the repo.
- `.tmp-*-review/` and `.DS_Store` are covered by ignore/cleanup policy.
- The baseline metrics file gives later phases numeric before/after comparisons.

## 7. Phase 1: Generated Documentation Counts

Goal: keep current docs, but remove stale manual counts.

Spoon cost: 1-2 spoons.

Rollback: revert the inventory/docs commit; generated files can be recreated from the baseline command.

Current issue:

- README-style docs list old counts for scripts, Python helpers, and tests.
- These counts drift quickly and reduce trust.

Plan:

- Add a small inventory script that prints counts for:
  - top-level `scripts/*.sh`
  - top-level `scripts/*.py`
  - `scripts/lib/*.sh`
  - `scripts/lib/*.py`
  - `bin/` entrypoints
  - `bin/dhp-*.sh`
  - test files
  - aliases and shell functions
- Update docs to refer to generated inventory output.
- Keep all current docs for now because the selected documentation direction is `7C`.
- Add a changelog retention rule: keep recent entries in `CHANGELOG.md`; move entries older than 6 months into rolling half-year archives named `docs/archive/CHANGELOG-YYYYH1.md` or `docs/archive/CHANGELOG-YYYYH2.md`.

Acceptance criteria:

- README can say "see generated inventory" instead of hard-coding brittle totals.
- `scripts/README.md` can show current counts from generated output.
- A future count mismatch becomes a tooling problem, not a manual-edit problem.
- `CHANGELOG.md` has a documented retention rule so it does not grow forever.

## 8. Phase 2: Product Boundary Plan

Goal: split non-dotfiles products while preserving current command names.

Spoon cost: 2-4 spoons.

Rollback: revert wrapper/design changes; no product files should be moved in this phase.

### 8.1 Cyborg Agent

Likely target:

- Sibling repo: `~/Projects/cyborg-agent`.

Move candidates:

- `scripts/cyborg_agent.py`
- `scripts/cyborg_build.py`
- `scripts/cyborg_docs_sync.py`
- `scripts/cyborg_support.py`
- `scripts/cyborg_scoped_site_check.sh`
- `bin/cyborg-readme.md`
- `bin/autopilot-readme.md`
- related Cyborg docs and tests

Keep in dotfiles:

- `bin/cyborg` compatibility wrapper.
- `bin/cyborg-sync` compatibility wrapper if needed.
- `cyborg`, `ap`, `apy`, `apb`, `apby`, `apbp`, `apbpy`, `apc` aliases.
- Configuration pointers such as `CYBORG_HOME` or `CYBORG_LAB_DIR`.

Wrapper behavior:

- If sibling repo exists, run it.
- If missing, print a short setup message and the expected path.
- Never fail with a Python stack trace for a missing optional product.

### 8.2 Observer / Obsidian Capture

Likely target:

- Sibling repo: `~/Projects/obsidian-observer` or `~/Projects/dotfiles-observer`.

Move candidates:

- `scripts/observer.py`
- observer-specific tests
- observer-specific docs

Keep in dotfiles:

- `scripts/observer.sh` wrapper.
- `observer` alias.
- Any daily-loop summary hook that uses observer output, provided it degrades if observer is absent.

### 8.3 AI Staff HQ

Likely target:

- Already behaves like a separate project. Formalize it as a sibling repo or submodule with clearer boundaries.

Keep in dotfiles:

- Only documented integration points and optional wrappers.
- No root-level daily command should require AI Staff HQ to be installed.

### 8.4 Blog Factory

Likely target:

- Move blog publishing, market validation, and content factory workflows with Cyborg or into a dedicated blog automation repo.

Keep in dotfiles:

- Daily loop may keep a lightweight "recent blog status" summary if useful.
- Blog commands should degrade when the sibling product is absent.

Acceptance criteria for Phase 2:

- Daily commands work without sibling products installed.
- Moved products can still be launched through old aliases if installed.
- Missing optional products produce short, actionable messages.
- Root `.env.example` no longer needs product-specific publish tokens unless the root wrapper truly consumes them.

Degradation smoke tests required before each extraction:

- Observer missing: run the daily commands with observer home/helper paths pointed at nonexistent locations.
- Cyborg missing: run `cyborg`, `ap`, and Cyborg-related aliases with the sibling repo missing.
- AI Staff HQ missing: run dispatcher/project commands that currently probe AI Staff HQ with that path unavailable.
- Expected result: command exits cleanly or with a documented nonfatal setup status, prints a short setup/unavailable message, and does not emit a Python stack trace.
- `startday`, `status`, and `goodevening` must still produce deterministic daily output when optional products are absent.

## 9. Phase 3: Dispatcher Consolidation

Goal: collapse `dhp-*.sh` duplication into one registry-driven dispatcher while preserving every current alias.

Spoon cost: multi-session.

Rollback: keep old `dhp-*.sh` files until registry tests pass; if needed, revert the registry commit and restore the old wrappers.

Current direction:

- Keep the user-facing commands.
- Replace duplicated wrappers with a registry table and compatibility shims.

Possible registry format:

- `bin/dhp-registry.tsv`
- `bin/dhp-registry.sh`
- `config/dhp-dispatchers.tsv`

Recommended first version:

- Use a simple TSV or shell-readable registry to avoid adding YAML parsing dependencies.
- Fields:
  - dispatcher id
  - display name
  - model environment variable
  - output directory environment variable
  - default temperature
  - prompt file or prompt key

Prompt storage options:

- Use one Markdown prompt file per dispatcher under `bin/prompts/<id>.md`.
- Keep the registry focused on metadata and file paths.
- Avoid huge inline heredocs in wrapper scripts.
- Avoid storing multi-line prompts directly in TSV.

Compatibility plan:

- `tech` still works.
- `dhp-tech` still works.
- `bin/dhp-tech.sh` either remains as a tiny shim or is generated.
- `dispatch tech` still works.
- `dhp` default behavior stays the same unless separately approved.

Acceptance criteria:

- Existing dispatcher tests pass.
- Each old dispatcher command resolves.
- Output directories and model fallback behavior remain compatible.
- Adding a new dispatcher requires editing one registry entry, not creating another near-duplicate script.
- Hand-maintained simple dispatcher wrapper surface is reduced from the frozen baseline of 21 `dhp-*.sh` files to one registry-driven path plus registry data and prompt files.
- Specialized dispatchers with bespoke logic, such as content, morphling, coach, project, chain, memory, and memory-search, are recorded as custom registry entries instead of forced into the simple wrapper path.
- Any remaining `dhp-*.sh` compatibility files are generated or tiny shims, and the generated inventory report records them separately from hand-maintained dispatcher logic.

## 10. Phase 4: Coach Reshape

Goal: keep the smart coach, but make deterministic computed truth the primary artifact.

Spoon cost: multi-session.

Rollback: leave the old broad prompt path available until deterministic brief tests pass for `startday`, `status`, and `goodevening`.

Important user preference:

- Keep GitHub tracking.
- Keep Fitbit tracking.
- Keep Drive tracking.
- Keep the AI coach useful and smart.
- Do not make the coach dumb or purely static.

Problem to solve:

- The current coach computes many signals, sends a large prompt to AI, then adds guards and cleanup when the AI overreaches.
- That creates maintenance load and makes the user responsible for judging whether the coach invented meaning.

Target shape:

1. Compute deterministic metrics.
2. Render a clear deterministic brief.
3. Ask AI for a short framing layer using the deterministic brief as ground truth.
4. Fall back to deterministic-only output if AI, GitHub, Fitbit, Drive, or calendar integrations are unavailable.

### 10.1 Code Migration Path

Do not create a second coach that runs in parallel forever. Reshape the existing coach in place through a staged adapter path:

1. Add `scripts/lib/coach_brief.sh`.
   - It renders the deterministic brief.
   - It reuses existing `coach_metrics.sh` outputs first.
   - It does not introduce a new data pipeline unless a metric cannot be reused.
2. Point `startday`, `status`, and `goodevening` through the deterministic brief path.
3. Keep the current AI prompt path as a compatibility fallback during the transition.
4. Shrink `coach_prompts.sh` toward one framing-prompt builder that accepts the deterministic brief.
5. Remove hallucination guards, evidence checks, and blindspot post-processing only after the AI no longer owns ground-truth claims.
6. Keep `coach_chat.sh` only for actual post-brief interaction; do not let it duplicate deterministic brief rendering.

Concrete deletion signal for step 5:

- Add a test around the framing prompt builder that inspects the framing-template portion, excluding the embedded deterministic brief.
- The framing template must not contain computed facts, dates, metric values, repo names, or bullet/list examples.
- Numbers, dates, bullets, and lists must come from the deterministic brief, not from AI-owned prompt claims.
- When this passes for `startday`, `status`, and `goodevening`, hallucination guards and post-generation evidence cleanup have a safe deletion path.

### 10.2 Deterministic Brief

The deterministic brief should include:

- Today's declared focus.
- Current mode: flow, locked, recovery, planning, or fallback.
- Spoon budget and latest spoon state.
- Latest energy/fog signals.
- Fitbit summary when available.
- GitHub/repo activity summary.
- Drive focus evidence summary.
- Calendar pressure and free windows when available.
- Todo load: active, stale, done today.
- One suggested next action computed from clear rules.
- Data quality flags.

### 10.3 AI Framing Layer

The AI should produce:

- One short sentence of framing.
- One short "do next" recommendation.
- Optional A/B/C/D question only when the deterministic data is ambiguous.

The AI should not:

- Invent motives.
- Invent unobserved work.
- Turn missing GitHub activity into moral failure.
- Override deterministic metrics.
- Produce long menus on recovery days.

### 10.4 Keep Smart Signals

The coach can remain smart by computing better deterministic signals:

- GitHub focus alignment.
- Repo continuity.
- Fitbit recovery pressure.
- Drive strategy evidence.
- Calendar load.
- Spoon overspend risk.
- Late-night work risk.
- Context switching pressure.

The difference is that those signals should be shown directly and then summarized, not hidden inside a giant AI prompt.

Acceptance criteria:

- `startday`, `status`, and `goodevening` still provide useful coach output.
- GitHub/Fitbit/Drive data still contributes to the coach.
- AI failure does not remove the deterministic brief.
- Recovery mode produces shorter output.
- Tests cover deterministic output with and without each external signal.
- The old broad prompt path is retired or reduced to a compatibility fallback with a tracked removal condition.
- `coach_prompts.sh` no longer owns deterministic facts or post-generation cleanup as its main job.
- `coach_prompts.sh` shrinks from the frozen baseline of 2,207 LOC to 300 LOC or less, unless a later explicit decision records why a larger framing module is needed.
- `coach_metrics.sh` stays stable or shrinks from the frozen baseline of 1,836 LOC; it should not grow to replace prompt complexity with metric complexity.

## 11. Phase 5: Data Format Stability

Goal: keep flat files for now, while reducing future migration risk.

Spoon cost: 1-2 spoons.

Rollback: revert tests/docs only; no storage migration is allowed in this phase.

Decision:

- No SQLite migration in this roadmap.

Near-term plan:

- Document current flat-file formats clearly.
- Add tests for delimiter-sensitive fields where risk is high.
- Avoid new lossy serializers.
- Prefer explicit export/import helpers over changing hot data storage.

Known issue:

- Some serializers remove `|` to preserve pipe-delimited parsing. This is stable enough for now but should not spread.

Acceptance criteria:

- Existing data files remain readable.
- No storage migration is required to complete repo narrowing.
- Future SQLite discussion is deferred until after repo scope is reduced.

## 12. Phase 6: Library Layering Cleanup

Goal: make the shell library loading rules match reality.

Spoon cost: multi-session if behavior changes; 1 spoon if docs-only.

Rollback: keep the existing `common.sh` bootstrap until all touched scripts pass targeted tests.

Current issue:

- The stated rule says libraries should not self-source sibling libraries.
- `common.sh` still bootstraps some siblings as a compatibility bridge.
- `loader.sh` exists for the daily stack, while many scripts still source ad hoc dependencies.

Plan:

- Do not change this until daily command tests are strong.
- Decide whether `common.sh` bootstrap is permanent or transitional.
- If permanent, update docs to say so.
- If transitional, migrate callers gradually to explicit dependencies.
- Keep `loader.sh` only if it remains valuable for `startday`, `status`, and `goodevening`.

Acceptance criteria:

- There is one documented loading strategy.
- The strategy matches actual code.
- Sourced files still avoid `set -euo pipefail`.
- Executed scripts still use strict mode.

## 13. Phase 7: Artifact and Log Policy Hardening

Goal: finish the artifact policy started in Phase 0.

Spoon cost: 1-2 spoons.

Rollback: restore the prior log path or cleanup rule if a daily command cannot find expected logs.

Phase 0 handles the low-risk cleanup: gitignore coverage, moving or excluding repo-local logs, and removing stranded `.tmp-*-review/` directories after confirmation. Phase 7 covers what remains: log rotation policy, documented cleanup behavior, and anything that surfaced during the larger refactors.

Plan:

- Keep runtime logs out of git.
- Decide whether repo-local `logs/` should exist at all.
- Prefer:
  - `~/.cache/dotfiles/logs/` for runtime logs.
  - `~/.config/dotfiles-data/` for user data.
  - repo-local files only for source, tests, docs, and fixtures.
- Remove stranded scratch dirs only after confirming they are unused.
- Keep `.DS_Store` ignored and out of the repo.

Acceptance criteria:

- Fresh clones do not accumulate obvious repo-root clutter.
- Log rotation or cleanup behavior is documented.
- Cleanup does not delete user data.

## 14. Phase 8: Product Extraction Execution

Goal: actually move sibling products after wrappers, tests, and docs are ready.

Spoon cost: multi-week.

Rollback: restore moved files from git and point aliases back to in-repo implementations. Do not remove the compatibility wrapper until the sibling product is proven stable.

Recommended order:

1. Observer extraction.
2. Cyborg/blog factory extraction.
3. AI Staff HQ boundary formalization.

Reasoning:

- Observer is the best pattern-prover: narrow wrapper, real daily-loop consumers, and a smaller surface than Cyborg.
- Cyborg should use the lessons from Observer because it has more aliases, workflow state, and publishing/build behavior.
- AI Staff HQ already behaves like a separate project, so the final work is mostly formalizing the boundary rather than proving the wrapper pattern.

Acceptance criteria:

- Dotfiles can be cloned and used for daily life without cloning sibling products.
- Optional products still work if installed.
- Old commands produce either the old behavior or a clear setup message.
- Root repo dependency and secret surface is smaller.
- Non-wrapper product implementation LOC under root dotfiles drops from the frozen baseline of 11,730 LOC to approximately 0 after Observer and Cyborg extraction, with any remaining wrapper LOC recorded separately.

Per-extraction checklist:

1. Sibling repo exists with its own README, tests, changelog, dependency notes, and secret/config guidance.
2. Dotfiles wrapper exists and preserves the old command name.
3. Missing-sibling degradation smoke test passes.
4. Aliases still resolve in a fresh shell.
5. `docs/generated/baseline-metrics.md` or its successor records the before/after LOC and wrapper counts.
6. Daily loop tests still pass.
7. Rollback path is stated in the extraction PR or commit notes.
8. Old in-repo implementation files are removed only after wrapper and degradation tests pass.

## 15. Suggested Implementation Order

1. Add generated inventories.
2. Add baseline metrics and target gates.
3. Apply the low-risk artifact/log cleanup policy.
4. Update docs to refer to generated inventories.
5. Classify aliases and scripts.
6. Add compatibility-wrapper degradation tests for optional products.
7. Consolidate dispatchers behind a registry.
8. Reshape coach output around deterministic brief first.
9. Review Phase 2 boundary decisions in light of dispatcher and coach reshape.
10. Extract Observer, then Cyborg, then AI Staff HQ boundary work.
11. Clean library loading docs and behavior.
12. Finish artifact/log policy hardening.

## 16. What Not To Do Yet

- Do not migrate hot data to SQLite.
- Do not delete aliases.
- Do not remove the smart coach.
- Do not remove GitHub/Fitbit/Drive tracking.
- Do not rewrite the coach in Python before narrowing product scope.
- Do not split repos before compatibility wrappers are designed.
- Do not make a large breaking cleanup PR.

## 17. Definition of Done

This roadmap is complete when:

- Root dotfiles is clearly a daily productivity and shell environment repo.
- Non-daily products live outside the root repo or behind optional compatibility wrappers.
- Every existing command and alias either works or gives a clear setup message.
- The coach uses deterministic metrics as ground truth and AI as a concise framing layer.
- Docs no longer carry stale hand-maintained inventory counts.
- Flat-file data remains intact.
- Daily loop tests pass.
- The baseline metrics file shows before/after movement for LOC, dispatcher wrapper count, product implementation files, coach prompt surface, alias class counts, and runtime artifacts.
- Optional-product absence is covered by smoke tests for daily commands.
- The Phase 3, Phase 4, and Phase 8 numeric targets recorded in `docs/generated/baseline-metrics.md` are met, or each exception is explicitly recorded.
