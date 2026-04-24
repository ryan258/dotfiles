# AGENTS.md - AI Development Guidelines for Dotfiles System

> **For AI Coding Assistants:** This document defines the coding standards, architecture patterns, and conventions you MUST follow when working on this dotfiles project. Read this entire file before making any changes.

---

## Scope and Precedence

1. Read `GUARDRAILS.md` first to confirm scope (`dotfiles` root vs `ai-staff-hq/`).
2. For root (`dotfiles`) work, `CLAUDE.md` is the canonical specification.
3. `AGENTS.md` is the quick operational checklist aligned to `CLAUDE.md`.
4. For `ai-staff-hq/`, use the local guides in that submodule.

---

## Critical Rules Summary

Before diving into details, here are the non-negotiable rules:

1. **Executed scripts:** Always use `#!/usr/bin/env bash` and `set -euo pipefail`
2. **Sourced libraries:** NEVER use `set -euo pipefail` (caller controls shell options)
3. **Data files:** All in `~/.config/dotfiles-data/` with pipe-delimited format
4. **User input:** ALWAYS sanitize with `sanitize_input()` before use
5. **Paths:** ALWAYS validate with `validate_path()` - never trust user paths
6. **Aliases:** `copy` = clipboard (pbcopy), `aicopy` = AI copywriter dispatcher
7. **Config loading:** Only `scripts/lib/config.sh` may source `.env` (except `scripts/validate_env.sh`)
8. **DATA_DIR ownership:** Never redefine `DATA_DIR` with per-script home-path fallbacks after sourcing `config.sh`
9. **Library dependencies:** `scripts/lib/*.sh` must not self-source sibling libs (compat exception: `common.sh` bootstrap only); callers source dependencies explicitly

---

## Project Context

This is a personal productivity system for a developer with MS (multiple sclerosis). The system provides:

- Cognitive support and brain-fog-friendly workflows
- Energy management via spoon theory tracking
- Daily automation (startday, goodevening, status)
- AI-powered assistants via OpenRouter API
- Task, journal, and health tracking

**Design priority:** Reliability and graceful degradation over features.

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

## Script Types and Headers

### Type 1: Executed Scripts (standalone utilities, dispatchers)

**Examples:** `todo.sh`, `journal.sh`, `health.sh`, `startday.sh`, `dhp-tech.sh`

For scripts in `scripts/`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Script implementation...
```

For dispatchers in `bin/`:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/dhp-shared.sh"
```

**Requirements:**

- `#!/usr/bin/env bash` (NOT `#!/bin/bash`)
- `set -euo pipefail` (strict mode mandatory)
- Avoid Bash 4-only features in root `dotfiles` scripts/libs unless the requirement is explicit.
- If a Bash 4+ feature is unavoidable, add a runtime guard and document the requirement in `CLAUDE.md`, `AGENTS.md`, `scripts/README.md`, and `CHANGELOG.md`.
- Bootstrap wrappers whose only job is to locate and exec a modern Bash for launchd/cron may use POSIX `sh`; keep that exception narrow and document it inline.
- Resolve script directory for reliable sourcing
- `scripts/*.sh` should source `common.sh` (and `config.sh` when needed)
- `bin/dhp-*.sh` should use `dhp-shared.sh`
- Use `exit` for termination

### Type 2: Sourced Files (libraries, must-be-sourced scripts)

**Examples:** All `scripts/lib/*.sh`, `scripts/g.sh`, `zsh/aliases.zsh`, `bin/dhp-context.sh`, `scripts/spec_helper.sh`

```bash
#!/usr/bin/env bash
# library-name.sh - Description
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

# Double-source guard (required)
if [[ -n "${_LIBRARY_NAME_LOADED:-}" ]]; then
    return 0
fi
readonly _LIBRARY_NAME_LOADED=true

# Functions use 'return', not 'exit'
my_function() {
    # Implementation
    return 0
}
```

**Requirements:**

- NO `set -euo pipefail` (caller controls shell options)
- Double-source guard at top
- Use `return`, never `exit` (exit kills parent shell)
- Document that file must be sourced
- Do not source sibling libraries from inside a library; declare dependency expectations in comments

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
| `coach_chat.sh`   | Menu-driven post-briefing control surface and chat | `scripts/lib/` |
| `focus_relevance.sh` | Focus keyword extraction and relevance scoring | `scripts/lib/` |

**Sourcing pattern:**

```bash
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/config.sh"
```

---

## Data Conventions

### Location

All data in `~/.config/dotfiles-data/` (access via `$DATA_DIR` from config.sh)

### File Formats (pipe-delimited)

| File            | Format                                                                   |
| --------------- | ------------------------------------------------------------------------ |
| `todo.txt`      | `ID\|YYYY-MM-DD\|task text`                                              |
| `todo_done.txt` | `YYYY-MM-DD HH:MM:SS\|task text`                                         |
| `journal.txt`   | `YYYY-MM-DD HH:MM:SS\|entry`                                             |
| `health.txt`    | `TYPE\|DATE\|field1\|field2...`                                          |
| `spoons.txt`    | `BUDGET\|DATE\|count` or `SPEND\|DATE\|TIME\|count\|activity\|remaining` |

### Input Sanitization (MANDATORY)

```bash
# Always sanitize before writing to data files
sanitized=$(sanitize_input "$user_input")
```

---

## Error Handling

### Exit Codes

```bash
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_INVALID_ARGS=2
readonly EXIT_FILE_NOT_FOUND=3
readonly EXIT_PERMISSION=4
readonly EXIT_SERVICE_ERROR=5
```

### Validation Functions

```bash
validate_numeric "$value" "field name"
validate_range "$value" 1 100 "field name"
validate_file_exists "$path" "description"
validate_path "$user_path"  # Security: prevents traversal
```

### Dependency Checks

```bash
require_cmd "jq" "Install with: brew install jq"
require_file "$config" "configuration file"
```

### Error Reporting

```bash
die "Fatal error message" "$EXIT_ERROR"  # Logs and exits
log_error "Non-fatal error"
log_warn "Warning message"
log_info "Info message"
```

---

## AI Dispatcher Architecture

### Structure

Dispatchers live in `bin/` and use shared framework:

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
    "System prompt" \
    "0.5" \
    "$@"
```

### Naming

- Script: `dhp-<type>.sh`
- Alias: Short form (`tech`, `creative`, `aicopy`)
- Model var: `<TYPE>_MODEL`

### Standard Flags

- `--stream` - Real-time output
- `--verbose` - Debug logging
- `--temperature <float>` - Override default

### Specialized Standalone Agents

- Repo-specific agents may live directly in `bin/` when they own an interactive workflow that does not fit the shared `dhp-*` dispatcher contract.
- `bin/cyborg` is the Cyborg Lab ingest/resume agent: an interactive session tool that scans a source repo, proposes a Cyborg Lab content graph, stages near-publishable drafts, stores resumable session artifacts under `~/Projects/cyborg-work` by default (override with `CYBORG_WORK_DIR`), only writes to `my-ms-ai-blog` on explicit apply, and should prefer accessible `A/B/C/D/E` short-choice prompts when it asks the user to choose. `cyborg auto` runs the full pipeline hands-free for low-energy sessions; `cyborg auto --iterate` is the existing-repo growth path: it picks the next GitHub issue or backlog item, applies the repo change, and runs the same build-verify-fix loop before stopping unless `--docs-after-code` is set. `cyborg auto --build` runs market validation, scaffolds a project via Morphling, runs the build-verify-fix loop, and then hands the verified repo to Cyborg for documentation. Add `--publish` when you want the verified build pushed to its registry before the docs pass. See [`bin/autopilot-readme.md`](bin/autopilot-readme.md) for the convergence architecture and [`MORPHLING.md`](MORPHLING.md) for Morphling's full capabilities including command execution.
- `bin/morphling.sh` is the Morphling launcher. Direct mode (`bin/morphling.sh`) runs a LangChain ReAct agent with four tools: `read_file`, `write_file`, `list_directory`, and `run_command` (shell execution with 60s timeout). This gives it closed-loop lead-developer capabilities — write code, run tests, read errors, fix, repeat. The `morphling` shell alias points to swarm mode (`bin/dhp-morphling.sh`), which is one-shot context-rich analysis with no tool access. See [`MORPHLING.md`](MORPHLING.md) for the full architecture.
- `bin/coach-chat.py` is the multi-turn coach chat handler. It maintains conversation history in a JSON file and calls OpenRouter for follow-up turns. Invoked by `scripts/lib/coach_chat.sh` — not called directly by users. Supports `init` (create history with system prompt + briefing) and `turn` (append message, call API, return response).


---

## Alias Conventions

### Critical Rules

1. `copy` = `pbcopy` (clipboard utility)
2. `aicopy` = AI copywriter dispatcher
3. Never shadow system commands unintentionally
4. Group aliases by category in `zsh/aliases.zsh`

### Patterns

| Category       | Pattern     | Examples                       |
| -------------- | ----------- | ------------------------------ |
| Git            | `g` prefix  | `gs`, `ga`, `gc`, `gp`         |
| AI Dispatchers | Type name   | `tech`, `creative`, `strategy` |
| Repo Agents    | Project name | `cyborg`                      |
| Scripts        | Full/abbrev | `todo`, `journal`, `j`         |
| Spoons         | `s-` prefix | `s-check`, `s-spend`           |
| Correlations   | `corr-` prefix | `corr-sleep`, `corr-rhr`    |

---

## Security Requirements

### Always Do

```bash
# Sanitize all user input
sanitized=$(sanitize_input "$user_input")

# Validate all paths
safe_path=$(validate_path "$user_path")

# Check dependencies exist
require_cmd "jq"
```

### Never Do

```bash
# NEVER eval user input
eval "$user_input"  # DANGEROUS

# NEVER trust paths without validation
cat "$user_provided_path"  # DANGEROUS

# NEVER write unsanitized input to files
echo "$user_input" >> "$data_file"  # DANGEROUS
```

---

## Cross-Platform Notes

### Date Handling

```bash
# Use scripts/lib/date_utils.sh helpers (required)
date_shift_days -1 "%Y-%m-%d"
date_now
date_today
date_epoch_now
timestamp_to_epoch "$raw_timestamp"
```

### macOS-Specific

```bash
if [[ "$OSTYPE" == "darwin"* ]]; then
    pbcopy < "$file"  # macOS only
fi
```

---

## Anti-Patterns to AVOID

| Don't                                   | Do                               |
| --------------------------------------- | -------------------------------- |
| `#!/bin/bash`                           | `#!/usr/bin/env bash`            |
| No error handling in executed scripts   | `set -euo pipefail`              |
| `set -euo pipefail` in sourced libs     | Let caller control shell options |
| Hard-coded paths                        | Use `$DATA_DIR`, `$DOTFILES_DIR` |
| `eval "$user_input"`                    | Validate and use arrays          |
| `exit` in sourced script                | Use `return`                     |
| Silent failures                         | Log errors properly              |
| Assuming commands exist                 | Use `require_cmd()`              |
| Inline `date -v` / `date -d` in scripts | Use `date_utils.sh` helpers      |

---

## Documentation Requirements

When modifying code:

1. Update relevant `docs/*.md` files
2. Update `CHANGELOG.md` with changes
3. Update `scripts/cheatsheet.sh` if aliases change
4. Update `bin/README.md` for dispatcher changes

---

## Testing Conventions

- Framework: `bats-core`
- Test files: `tests/test_*.sh` with `#!/usr/bin/env bats`
- Shared helpers: `tests/helpers/test_helpers.sh`, `tests/helpers/assertions.sh`
- Run full suite: `bats tests/*.sh`

---

## Markdown Formatting Standards

To ensure clean, standard markdown output and minimal git diffs, you MUST adhere to the following when generating or modifying markdown (.md) documents:

1. **No Trailing Spaces**: Never leave trailing whitespace at the ends of lines.
2. **Code Blocks**: Always enforce exactly one empty line before and after fenced code blocks (```).
3. **Headings**: Always enforce exactly one empty line before headings unless they are the very first line of the document.
4. **Lists**: Use 2 spaces for nested list indentation.
5. **EOF**: Always end the file with a single newline.

---

## Quick Checklist

### New Executed Script

- [ ] `#!/usr/bin/env bash`
- [ ] `set -euo pipefail`
- [ ] `scripts/*.sh`: source `common.sh` (plus `config.sh` when needed)
- [ ] `bin/dhp-*.sh`: source `dhp-shared.sh`
- [ ] Add alias if needed
- [ ] Document in README

### New Library (Sourced)

- [ ] NO `set -euo pipefail`
- [ ] Double-source guard
- [ ] Use `return` not `exit`
- [ ] Document as "must be sourced"

### New Dispatcher

- [ ] Use `dhp-shared.sh` framework
- [ ] Add alias (`zsh/aliases.zsh`)
- [ ] Add model config to `.env.example`
- [ ] Document in `bin/README.md`

---

_Refer to `CLAUDE.md` for canonical root-project guidance and `GUARDRAILS.md` for scope selection._

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **dotfiles** (5537 symbols, 6720 relationships, 56 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/dotfiles/context` | Codebase overview, check index freshness |
| `gitnexus://repo/dotfiles/clusters` | All functional areas |
| `gitnexus://repo/dotfiles/processes` | All execution flows |
| `gitnexus://repo/dotfiles/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
