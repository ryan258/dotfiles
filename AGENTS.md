# AGENTS.md - AI Development Guidelines for Dotfiles System

> **For AI Coding Assistants:** Quick operational checklist aligned to `CLAUDE.md` (the canonical spec). Read this before making changes.

---

## Directive Zero: Operating Context

This is a personal productivity system for a developer with MS (multiple sclerosis). The system provides:

- Cognitive support and brain-fog-friendly workflows
- Energy management via spoon theory tracking
- Daily automation (startday, goodevening, status)
- AI-powered assistants via OpenRouter API
- Task, journal, and health tracking

**Design priority:** Reliability and graceful degradation over features. Prefer `A/B/C/D/E` short-choice prompts over freeform input.

---

## Scope and Precedence

1. Read `GUARDRAILS.md` first to confirm scope (`dotfiles` root vs `ai-staff-hq/`).
2. For root (`dotfiles`) work, `CLAUDE.md` is the canonical specification.
3. `AGENTS.md` is the quick operational checklist aligned to `CLAUDE.md`.
4. For `ai-staff-hq/`, use the local guides in that submodule.

---

## Critical Rules Summary

1. **Executed scripts:** Always use `#!/usr/bin/env bash` and `set -euo pipefail`
2. **Sourced libraries:** NEVER use `set -euo pipefail` (caller controls shell options)
3. **Sourced files:** Use `return`, not `exit` — exit kills the parent shell
4. **Data files:** All in `~/.config/dotfiles-data/` with pipe-delimited format
5. **User input:** ALWAYS sanitize with `sanitize_input()` before use
6. **Paths:** ALWAYS validate with `validate_path()`
7. **Aliases:** `copy` = clipboard (pbcopy), `aicopy` = AI copywriter dispatcher
8. **Config loading:** Only `scripts/lib/config.sh` may source `.env` (except `scripts/validate_env.sh`)
9. **DATA_DIR ownership:** Never redefine `DATA_DIR` with per-script home-path fallbacks after sourcing `config.sh`
10. **Library dependencies:** `scripts/lib/*.sh` must not self-source sibling libs (compat exception: `common.sh` bootstrap only)
11. **Shell intelligence:** Do not run GitNexus against this repo (no shell symbol support). Use `scripts/bash_intel.sh` (LSP-backed) for symbols/definitions/references and `scripts/bash_graph.sh` for shell dependency/source topology, plus `rg`, manual sourced-vs-executed boundary tracing, and bats tests. See `docs/products/bash-intel.md`. (`scripts/gitnexus.sh` is retained only as a portable shortcut for use against other repos.)

---

## Directory Structure

```
dotfiles/
├── scripts/           # Core CLI utilities (executed)
│   └── lib/          # Shared libraries (sourced - NO set -euo pipefail)
├── bin/              # AI dispatchers (dhp-*.sh)
├── zsh/              # Shell config (aliases.zsh - sourced)
├── docs/             # Documentation
├── tests/            # Test suites
├── templates/        # AI dispatcher templates
├── ai-staff-hq/      # AI workforce definitions (submodule)
├── brain/            # Knowledge base
└── .env              # Configuration (never commit)
```

---

## Execution Protocols

### Pre-Flight: Before Writing or Modifying Any Shell File

You MUST determine the file's type before writing a single line:

1. **Is the file in `scripts/lib/`?** Or is it `zsh/aliases.zsh`, `scripts/g.sh`, `bin/dhp-context.sh`, or `scripts/spec_helper.sh`? If yes → **sourced file**.
2. **Does the header say "must be sourced"?** If yes → **sourced file**.
3. **Everything else** → **executed script**.

Applying the wrong type breaks the system: sourced files with `set -euo pipefail` crash the user's shell; executed files without it swallow errors silently.

### Executed Scripts (standalone utilities, dispatchers)

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

- `#!/usr/bin/env bash` (NOT `#!/bin/bash`)
- Avoid Bash 4-only features unless explicit runtime requirement. If unavoidable, add a runtime guard and document in `CLAUDE.md`, `AGENTS.md`, `scripts/README.md`, and `CHANGELOG.md`.
- Bootstrap wrappers for launchd/cron may use POSIX `sh`; keep narrow and documented inline.
- Use `exit` for termination.

### Sourced Files (libraries, must-be-sourced scripts)

**Files:** All `scripts/lib/*.sh`, `scripts/g.sh`, `zsh/aliases.zsh`, `bin/dhp-context.sh`, `scripts/spec_helper.sh`

```bash
#!/usr/bin/env bash
# library-name.sh - Description
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_LIBRARY_NAME_LOADED:-}" ]]; then
    return 0
fi
readonly _LIBRARY_NAME_LOADED=true

my_function() {
    return 0  # NOT exit
}
```

---

## Core Libraries Reference

| Library           | Purpose                                    | Location       |
| ----------------- | ------------------------------------------ | -------------- |
| `common.sh`       | Validation, logging, errors                | `scripts/lib/` |
| `config.sh`       | Paths, models, feature flags               | `scripts/lib/` |
| `file_ops.sh`     | Atomic writes, file validation             | `scripts/lib/` |
| `date_utils.sh`   | Cross-platform dates                       | `scripts/lib/` |
| `health_ops.sh`   | Shared health + wearable helpers           | `scripts/lib/` |
| `spoon_budget.sh` | Energy tracking                            | `scripts/lib/` |
| `blog_common.sh`  | Blog utilities                             | `scripts/lib/` |
| `oauth.sh`        | OAuth token parsing, refresh, secure writes | `scripts/lib/` |
| `coaching.sh`     | Stable facade over coach libraries         | `scripts/lib/` |
| `coach_ops.sh`    | Core coaching mode, log, digest logic      | `scripts/lib/` |
| `coach_metrics.sh` | Tactical and pattern metrics collection  | `scripts/lib/` |
| `coach_prompts.sh` | Coach prompt builders                    | `scripts/lib/` |
| `coach_scoring.sh` | Coaching scoring and classification      | `scripts/lib/` |
| `coach_chat.sh`   | Menu-driven post-briefing control surface  | `scripts/lib/` |
| `github_ops.sh`   | GitHub API helpers                         | `scripts/lib/` |
| `focus_relevance.sh` | Focus keyword extraction and relevance  | `scripts/lib/` |

Use `scripts/lib/date_utils.sh` for all date/time operations — no inline `date -v`, `date -d`, `gdate -d`.

---

## Data Conventions

All data in `~/.config/dotfiles-data/` (access via `$DATA_DIR` from config.sh).

| File            | Format                                                                   |
| --------------- | ------------------------------------------------------------------------ |
| `todo.txt`      | `ID\|YYYY-MM-DD\|task text`                                              |
| `todo_done.txt` | `YYYY-MM-DD HH:MM:SS\|task text`                                         |
| `journal.txt`   | `YYYY-MM-DD HH:MM:SS\|entry`                                             |
| `health.txt`    | `TYPE\|DATE\|field1\|field2...`                                          |
| `spoons.txt`    | `BUDGET\|DATE\|count` or `SPEND\|DATE\|TIME\|count\|activity\|remaining` |

Always sanitize before writing: `sanitized=$(sanitize_input "$user_input")`

---

## Error Handling

Use named exit codes from `common.sh` (`EXIT_SUCCESS=0` through `EXIT_SERVICE_ERROR=5`). Use `die()` for fatal errors, `log_error/log_warn/log_info` for non-fatal. Validate with `validate_numeric`, `validate_range`, `validate_file_exists`, `validate_path`. Check deps with `require_cmd`, `require_file`.

---

## AI Dispatcher Architecture

All dispatchers MUST use `bin/dhp-shared.sh` and call `dhp_dispatch`. Do not bypass this framework — it handles argument parsing, streaming, model selection, and standard flags.

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/dhp-shared.sh"

dhp_dispatch \
    "Dispatcher Name" "MODEL_TYPE" "" "MODEL_ENV_VAR" \
    "DHP_<TYPE>_OUTPUT_DIR" "System prompt" "0.5" "$@"
```

- Naming: `dhp-<type>.sh`, alias short form, model var `<TYPE>_MODEL`
- Standard flags: `--stream`, `--verbose`, `--temperature <float>`

### Standalone Agents

- **`bin/cyborg`** — Cyborg Lab ingest/resume agent. `cyborg auto` for hands-free; `cyborg auto --iterate` for incremental growth; `cyborg auto --build` for market validation + scaffold + build-verify-fix. Add `--publish` to push before docs. See `bin/autopilot-readme.md` and `MORPHLING.md`.
- **`bin/morphling.sh`** — LangChain ReAct agent with `read_file`, `write_file`, `list_directory`, `run_command`. The `morphling` alias points to swarm mode (`bin/dhp-morphling.sh`). See `MORPHLING.md`.
- **`bin/coach-chat.py`** — Multi-turn coach chat handler. Invoked by `scripts/lib/coach_chat.sh`, not directly. Supports `init` and `turn`.

---

## Alias Conventions

| Category       | Pattern     | Examples                       |
| -------------- | ----------- | ------------------------------ |
| Git            | `g` prefix  | `gs`, `ga`, `gc`, `gp`         |
| AI Dispatchers | Type name   | `tech`, `creative`, `strategy` |
| Repo Agents    | Project name | `cyborg`                      |
| Scripts        | Full/abbrev | `todo`, `journal`, `j`         |
| Spoons         | `s-` prefix | `s-check`, `s-spend`           |
| Correlations   | `corr-` prefix | `corr-sleep`, `corr-rhr`    |

Never shadow system commands. `copy` = `pbcopy`, `aicopy` = AI copywriter.

---

## Cross-Platform

- Guard macOS-only features with `[[ "$OSTYPE" == "darwin"* ]]`.
- Use `date_utils.sh` helpers, not inline date commands.
- Check command availability with `require_cmd`.

---

## Testing

When adding or modifying functionality, you MUST write the bats test first, run it to confirm it fails, implement the change, then run it again.

- Framework: `bats-core`
- Files: `tests/test_<module>.sh` with `#!/usr/bin/env bats`
- Helpers: always load `tests/helpers/test_helpers.sh` and `tests/helpers/assertions.sh`
- `setup()` calls `setup_test_environment` (creates isolated `$TEST_DIR`); `teardown()` calls `teardown_test_environment`
- Run single: `bats tests/test_<module>.sh`
- Run suite: `bats tests/*.sh` (check for regressions)

---

## Quick Checklist

### New Executed Script

- [ ] `#!/usr/bin/env bash` + `set -euo pipefail`
- [ ] Source `common.sh` (scripts) or `dhp-shared.sh` (dispatchers)
- [ ] Add alias if needed
- [ ] Document in README, update `CHANGELOG.md`

### New Library (Sourced)

- [ ] NO `set -euo pipefail`
- [ ] Double-source guard
- [ ] Use `return` not `exit`

### New Dispatcher

- [ ] Use `dhp-shared.sh` framework
- [ ] Add alias (`zsh/aliases.zsh`)
- [ ] Add model config to `.env.example`
- [ ] Document in `bin/README.md`

---

_Refer to `CLAUDE.md` for canonical root-project guidance and `GUARDRAILS.md` for scope selection._
