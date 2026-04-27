# CLAUDE.md - AI Development Guidelines for Dotfiles System

---

## Directive Zero: Operating Context

**Primary user:** Developer with MS (multiple sclerosis) who needs cognitive support, energy management, and brain-fog-friendly workflows.

This is a personal productivity system built around shell scripts, AI dispatchers, and automation tools:

- Daily workflow automation (startday, goodevening, status)
- Task and journal management
- Health and energy tracking (spoon theory)
- AI-powered assistants via OpenRouter API
- Blog content generation and management

Every design decision should optimize for low-friction, low-cognitive-load interactions. Prefer `A/B/C/D/E` short-choice prompts over freeform input. Prefer autopilot paths for low-energy sessions.

---

## Scope and Precedence

1. Read `GUARDRAILS.md` first to identify scope (`dotfiles` root vs `ai-staff-hq/`).
2. For root (`dotfiles`) files, this `CLAUDE.md` is canonical.
3. `AGENTS.md` is a concise operational companion and must stay aligned with this file.
4. For `ai-staff-hq/` files, use `ai-staff-hq/CLAUDE.md` and sibling guides in that submodule.

### Documentation Governance

`CLAUDE.md` is the only authoritative architecture and behavior contract for root `dotfiles`. The following are derived-view docs — update them to reference the canonical contract when behavior changes:

`README.md`, `docs/README.md`, `docs/daily-loop-handbook.md`, `docs/ai-handbook.md`, `docs/autopilot-happy-path.md`, `docs/general-reference-handbook.md`, `docs/ROADMAP-ENERGY.md`, `scripts/README.md`, `scripts/README_aliases.md`, `docs/archive/phases.md`

---

## Shell Code Intelligence

GitNexus is **not used** on this repo. It cannot extract bash/zsh function symbols, so it provided no value for a predominantly shell codebase. Do **not** run GitNexus tools (`gitnexus_impact`, `gitnexus_context`, `gitnexus_query`, `gitnexus_detect_changes`, `gn analyze`) against this repo or reintroduce a `.gitnexus/` index here. The `scripts/gitnexus.sh` wrapper is kept only as a portable shortcut for use against **other** projects (Python codebases) — it is intentionally not invoked against dotfiles.

For shell code navigation and impact analysis, use **`scripts/bash_intel.sh`** as the canonical tool:

- `bash_intel.sh symbols <file>` — outline a single shell file
- `bash_intel.sh workspace-symbols <query>` — search across all shell files
- `bash_intel.sh definition <symbol>` / `references <symbol>` — jump to or find callers of a function
- `bash_graph.sh scan` / `impact <symbol-or-file>` — inspect shell dependency/source topology
- Pair with `rg` for sourced-vs-executed boundary checks and targeted bats tests

The full operator handbook lives at **`docs/products/bash-intel.md`** — read it before doing non-trivial shell refactors.

---

## Architecture

### Directory Structure

```
dotfiles/
├── scripts/           # Core CLI utilities (todo.sh, journal.sh, health.sh, etc.)
│   └── lib/          # Shared libraries (common.sh, config.sh, etc.)
├── bin/              # AI dispatchers (dhp-*.sh) and dispatcher infrastructure
├── zsh/              # Shell configuration (aliases.zsh)
├── docs/             # Documentation (markdown)
├── tests/            # Test suites
├── templates/        # Spec templates for AI dispatchers
├── ai-staff-hq/      # AI workforce YAML definitions (submodule)
├── brain/            # Knowledge base / memory system
└── .env              # Configuration (API keys, models, paths)
```

### Core Libraries (`scripts/lib/`)

| Library           | Purpose                                           | When to Use                |
| ----------------- | ------------------------------------------------- | -------------------------- |
| `common.sh`       | Validation, logging, error handling, data access  | Always source this         |
| `config.sh`       | Paths, models, feature flags, environment loading | When needing configuration |
| `file_ops.sh`     | Atomic writes, file validation                    | File manipulation          |
| `date_utils.sh`   | Cross-platform date handling                      | Date calculations          |
| `health_ops.sh`   | Shared health + wearable helpers                  | Health summaries and Fitbit context |
| `spoon_budget.sh` | Energy tracking                                   | Spoon-related features     |
| `blog_common.sh`  | Blog utilities                                    | Blog operations            |
| `oauth.sh`        | Shared OAuth token parsing, refresh, secure writes | Google Drive, Calendar, Fitbit sync |
| `coaching.sh`     | Stable facade over the coach_* family (see below) | Daily briefing workflows   |
| `coach_ops.sh`    | Core coaching implementation (mode, log, digest)  | Used internally by coaching.sh |
| `coach_metrics.sh`| Tactical + pattern metrics collection             | Used by coaching.sh        |
| `coach_prompts.sh`| Coach prompt builders                             | Used by coaching.sh        |
| `coach_scoring.sh`| Coaching scoring and classification               | Used by coaching.sh        |
| `coach_chat.sh`   | Menu-driven post-briefing control surface and chat | After startday/status/goodevening |
| `github_ops.sh`   | GitHub API helpers (repos, commits, pushes)       | Daily briefing workflows   |
| `focus_relevance.sh` | Focus keyword extraction and relevance scoring | Drive filtering, journal rel, strategy evidence |

### The `coaching.sh` Facade

`scripts/lib/coaching.sh` wraps `coach_ops.sh`, `coach_metrics.sh`, `coach_prompts.sh`, `coach_scoring.sh`. Workflow entry points (`startday.sh`, `status.sh`, `goodevening.sh`) call `coaching_*` functions so the underlying coach libraries can evolve without breaking callers. New coaching logic goes into the appropriate `coach_*.sh` file; the facade only needs a new one-line pass-through when a public function is added.

### Config and Environment

- Only `scripts/lib/config.sh` may source `.env` (exception: `scripts/validate_env.sh` for validation).
- After sourcing `config.sh`, do not redefine `DATA_DIR` or other config vars with script-local `${VAR:-...}` fallbacks.
- Scripts should fail fast if `config.sh` cannot be sourced.

### Library Dependency Contract

- Libraries in `scripts/lib/` must not self-source sibling libraries.
- Compatibility exception: `common.sh` may bootstrap `file_ops.sh`/`config.sh` while migration is in progress; do not add new self-sourcing patterns elsewhere.
- Each library should declare required dependencies in a short header comment.
- Callers are responsible for sourcing dependencies in the correct order.
- Dependency failures should be explicit and immediate, not silently auto-healed.

### Data Files

All user data lives in `~/.config/dotfiles-data/` (XDG-compliant). Access via `config.sh` (`$DATA_DIR`, `$TODO_FILE`, `$JOURNAL_FILE`, etc.).

| File            | Format                           | Example                                      |
| --------------- | -------------------------------- | -------------------------------------------- |
| `todo.txt`      | `ID\|DATE\|task text`            | `42\|2025-01-15\|Fix login bug`              |
| `todo_done.txt` | `YYYY-MM-DD HH:MM:SS\|task text` | `2025-01-15 14:30:00\|Fix login bug`         |
| `journal.txt`   | `YYYY-MM-DD HH:MM:SS\|entry`     | `2025-01-15 09:00:00\|Morning reflection...` |
| `health.txt`    | `TYPE\|DATE\|fields...`          | `SYMPTOM\|2025-01-15\|fatigue\|3`            |
| `spoons.txt`    | `TYPE\|DATE\|fields...`          | `BUDGET\|2025-01-15\|12`                     |
| `github_inactive_repos.txt` | `repo\|YYYY-MM-DD\|note` | `dotfiles\|2026-03-30\|good place` |

Always sanitize user input before writing: `sanitized=$(sanitize_input "$user_input")`

### Error Handling

Use named exit codes from `common.sh` (`EXIT_SUCCESS`, `EXIT_ERROR`, `EXIT_INVALID_ARGS`, `EXIT_FILE_NOT_FOUND`, `EXIT_PERMISSION`, `EXIT_SERVICE_ERROR`). Use `die()` for fatal errors, `log_error/log_warn/log_info` for non-fatal. Validate inputs with `validate_numeric`, `validate_range`, `validate_file_exists`, `validate_path`. Check dependencies with `require_cmd`, `require_file`, `require_dir`.

### Security

- Never use `eval` with user input; use explicit commands, arrays, and allowlists instead.
- Always validate user-provided paths with `validate_path()` before reading or writing.
- Store API keys and secrets in `.env` only; never commit them.
- Keep `.env` and generated token/credential files at `chmod 600` when scripts create or repair them.
- Redact secrets before logging command output, API responses, or environment-derived values.

---

## Execution Protocols

### Agent Pre-Flight: Before Writing or Modifying Any Shell File

Before you write a single line, you MUST determine the file's type:

1. **Check the file path.** Is it in `scripts/lib/`? Is it `zsh/aliases.zsh`, `scripts/g.sh`, `bin/dhp-context.sh`, or `scripts/spec_helper.sh`? If yes, it is a **sourced file**.
2. **Check the header.** Does it say "must be sourced" or "SOURCED, not executed"? If yes, it is a **sourced file**.
3. **Everything else** in `scripts/` or `bin/` is an **executed script**.

Then apply the correct constraints below. If you apply the wrong type, the system will break in ways that are difficult to debug — sourced files with `set -euo pipefail` will crash the user's interactive shell; executed files without it will silently swallow errors.

### The One Rule: Sourced vs Executed

Every shell file falls into exactly one category. Getting this wrong causes hard-to-debug failures.

**Executed scripts** (standalone utilities, dispatchers, system scripts):

- MUST have `set -euo pipefail`
- Use `exit` for termination
- Header: `#!/usr/bin/env bash` + `set -euo pipefail`

**Sourced files** (libraries, shell config, navigation scripts):

- Must NOT have `set -euo pipefail` — caller controls shell options
- Use `return`, not `exit` — exit kills the parent shell
- Must include a double-source guard

### Executed Script Headers

```bash
# scripts/*.sh
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# bin/dhp-*.sh
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/dhp-shared.sh"
```

### Sourced File Template

```bash
#!/usr/bin/env bash
# library-name.sh - Description
# NOTE: This file is SOURCED, not executed. Do not set -euo pipefail.

if [[ -n "${_LIBRARY_NAME_LOADED:-}" ]]; then
    return 0
fi
readonly _LIBRARY_NAME_LOADED=true
```

### Files That Must Be Sourced

- All files in `scripts/lib/*.sh`
- `zsh/aliases.zsh`
- `scripts/g.sh` (navigation, changes directory in parent shell)
- `bin/dhp-context.sh` (context helpers)
- `scripts/spec_helper.sh` (template editing)

### Library Sourcing Pattern

```bash
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    source "$SCRIPT_DIR/lib/common.sh"
elif [[ -f "$SCRIPT_DIR/../lib/common.sh" ]]; then
    source "$SCRIPT_DIR/../lib/common.sh"
else
    echo "Error: common.sh not found" >&2
    exit 1
fi
```

### Shell Compatibility

- Use `#!/usr/bin/env bash` (NOT `#!/bin/bash`).
- Avoid Bash 4-only features unless there is an explicit runtime requirement. If unavoidable, add a runtime guard and document in `CLAUDE.md`, `AGENTS.md`, `scripts/README.md`, and `CHANGELOG.md`.
- Bootstrap wrappers for launchd/cron may use POSIX `sh`; keep that exception narrow and documented inline.
- Use `scripts/lib/date_utils.sh` for all date/time operations — no inline `date -v`, `date -d`, `gdate -d`, or ad-hoc cross-platform date parsing.
- Guard macOS-only features with `[[ "$OSTYPE" == "darwin"* ]]`.

---

## AI Dispatcher Standards

### Mandatory Framework

All dispatchers MUST use `bin/dhp-shared.sh` and call `dhp_dispatch`. Do not create dispatchers that bypass this framework — it handles argument parsing, streaming, model selection, output directory management, and standard flags. Building a dispatcher without it will produce an inconsistent interface that breaks user expectations.

### Dispatcher Structure (`bin/dhp-*.sh`)

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/dhp-shared.sh"

dhp_dispatch \
    "Dispatcher Name" \
    "MODEL_TYPE" \
    "" \
    "MODEL_ENV_VAR" \
    "DHP_<TYPE>_OUTPUT_DIR" \
    "System prompt/instructions" \
    "0.5" \
    "$@"
```

- Naming: script `dhp-<type>.sh`, alias short form (e.g., `tech`), model var `<TYPE>_MODEL`
- Standard flags (via `dhp-shared.sh`): `--stream`, `--verbose`, `--temperature <float>`
- Input: stdin (`cat file.txt | tech`), argument (`creative "story idea"`), or both

### Standalone Agents

Not every AI entrypoint needs the `dhp-*` framework. Repo-specific agents may live in `bin/` as standalone executables when they own a focused workflow.

- **`bin/cyborg`** — Cyborg Lab ingest/resume agent. Interactive session tool for content graph management. `cyborg auto` for hands-free; `cyborg auto --iterate` for incremental growth; `cyborg auto --build` for market validation + scaffold + build-verify-fix. Add `--publish` to push before docs. See `bin/autopilot-readme.md` and `MORPHLING.md`.
- **`bin/morphling.sh`** — LangChain ReAct agent with `read_file`, `write_file`, `list_directory`, `run_command` tools. The `morphling` alias points to swarm mode (`bin/dhp-morphling.sh`), the one-shot analysis path.
- **`bin/coach-chat.py`** — Multi-turn coach chat handler. Invoked by `scripts/lib/coach_chat.sh`, not directly. Supports `init` and `turn` commands.

Standalone agents must follow root-project rules: strict mode for shell launchers, predictable config loading, explicit path validation, session state in repo-appropriate locations.

---

## Coach & Wearable Data Flow

### Data Flow Rules

- Fitbit wearable data flows into `~/.config/dotfiles-data/fitbit/*.txt` via `scripts/fitbit_sync.sh` or `scripts/fitbit_import.sh`.
- When Google Health auth is present, `startday.sh`, `status.sh`, and `goodevening.sh` do best-effort Fitbit sync before rendering.
- If wearable metrics are present in the behavior digest, treat them as live health context — do not suggest Fitbit setup.
- Latest manual energy/fog readings = current state; trailing averages = recent trend.
- Interactive `status.sh` with AI coach enabled should offer manual energy/fog logging before building the digest.

### Coach Briefing Constraints

- **Tone:** Gentle-partner by default, high-signal, low-noise.
- **Lead with wins** unless real risk exists (health/body risk, same-day blocker, `latest_energy <= 1`, or `latest_fog >= 8`).
- **Mode:** `startday` = gentle check-in then plan. `status` = midpoint reset with one next move. `goodevening` = celebrate wins, debrief, set up tomorrow lightly.
- **Pre-brief questions:** Up to 3, answerable via numbered `A/B/C/D/E` choices (`1B 2A 3E`), `E` = custom note.
- **GitHub signals:** Respect `github_inactive_repos.txt` — hide parked repos from active signals, show separately for reactivation. Cap blindspot/opportunity sections at 5 items; each must be concrete with real repo names.
- **Strategy evidence:** Focus-related journal entries and recent Drive docs count as progress on zero-commit days — not "movement unproven."
- **Local context bundle:** Last 7 days of journal, todos, schedule, blog snapshots, launchpad, weekly review, health/spoon slices. Git/focus are primary; local bundle is secondary.
- **Post-processing:** Remove raw metric/debug noise (`dir_usage_malformed`, `commit_context`, `focus_git_status=...`) from blindspot sections; backfill grounded repo-specific actions.

### Post-Briefing Chat

`scripts/lib/coach_chat.sh` is a deterministic menu-driven control surface. It intercepts local commands (`/t` todo, `/i` idea, `/f` focus, `/j` journal, `/d` drive, `/q` quit) and menu choices (`A/B/C/D/E`), only routing freeform text to the AI. Follow-up questions should prefer `A/B/C/D/E` choices with `E` as custom.

### Drive Integration

`scripts/drive.sh` provides read-only Google Drive context via device-flow OAuth. `recent [days]` for focus-filtered cached activity (coach digest). `recall [query]` for manual search. Drive signals are secondary; git is strongest code-day signal.

`scripts/lib/focus_relevance.sh` exports: `focus_relevance_current_focus`, `focus_relevance_keywords_from_text`, `focus_relevance_keywords_from_current_focus`, `focus_relevance_score_text`.

---

## Alias Conventions (`zsh/aliases.zsh`)

| Category       | Pattern             | Examples                       |
| -------------- | ------------------- | ------------------------------ |
| Navigation     | Short/memorable     | `..`, `downloads`, `projects`  |
| Git            | `g` prefix          | `gs`, `ga`, `gc`, `gp`, `gd`   |
| Scripts        | Full name or abbrev | `todo`, `journal`, `j`, `ta`   |
| AI Dispatchers | Type name           | `tech`, `creative`, `strategy` |
| Repo Agents    | Project name        | `cyborg`                       |
| Spoons         | `s-` prefix         | `s-check`, `s-spend`           |
| Correlations   | `corr-` prefix      | `corr-sleep`, `corr-rhr`       |

- **Alias** for simple command shortcuts; **function** when logic/conditionals needed.
- Never shadow system commands without explicit intent.
- `copy` = `pbcopy` (clipboard), `aicopy` = AI copywriter.
- Group by category with section headers; document non-obvious aliases with comments.

---

## Testing

### Agent Workflow: Test-First

When adding or modifying functionality in `scripts/` or `scripts/lib/`, you MUST:

1. **Write the bats test first** in `tests/test_<module>.sh` before writing the implementation.
2. **Run the test** with `bats tests/test_<module>.sh` to confirm it fails for the right reason.
3. **Implement the change.**
4. **Run the test again** to confirm it passes.
5. **Run the full suite** with `bats tests/*.sh` to check for regressions.

### Test Structure

- Framework: `bats-core` (`#!/usr/bin/env bats`)
- Location: `tests/test_<module>.sh`
- Shared helpers: `tests/helpers/test_helpers.sh`, `tests/helpers/assertions.sh` — always load both
- Environment: `setup()` calls `setup_test_environment` which creates an isolated `$TEST_DIR`; `teardown()` cleans it up

```bash
#!/usr/bin/env bats

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() { setup_test_environment; }
teardown() { teardown_test_environment; }

@test "feature works" {
    run "$TEST_DIR/scripts/example.sh" command
    [ "$status" -eq 0 ]
    [[ "$output" =~ "expected text" ]]
}
```

Run single file: `bats tests/test_<module>.sh`
Run full suite: `bats tests/*.sh`

---

## Quick Reference

### New Executed Script

1. Header: `#!/usr/bin/env bash` + `set -euo pipefail`
2. Source `common.sh` (scripts) or `dhp-shared.sh` (dispatchers)
3. Add alias to `zsh/aliases.zsh` if needed
4. Document in appropriate README
5. Add tests for critical functionality
6. Update `CHANGELOG.md`

### New Dispatcher

1. Create `bin/dhp-<name>.sh` using `dhp-shared.sh`
2. Add alias in `zsh/aliases.zsh`
3. Add model config to `.env.example`
4. Document in `bin/README.md`

### New Library (Sourced File)

1. Create in `scripts/lib/<name>.sh`
2. **No `set -euo pipefail`** — caller controls this
3. Add double-source guard
4. Document all public functions
5. Add tests in `tests/test_<name>.sh`

### Configuration Changes

1. Add defaults to `scripts/lib/config.sh`
2. Add to `.env.example` with documentation
3. Use getter functions for access

---

_This document should be updated whenever new patterns are established or existing conventions change._
