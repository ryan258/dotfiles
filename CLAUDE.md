# CLAUDE.md - AI Development Guidelines for Dotfiles System

This document defines coding standards, architecture patterns, and conventions that must be followed when working on this dotfiles project. These guidelines ensure consistency, reliability, and maintainability.

---

## Scope and Precedence

1. Read `GUARDRAILS.md` first to identify scope (`dotfiles` root vs `ai-staff-hq/`).
2. For root (`dotfiles`) files, this `CLAUDE.md` is canonical.
3. `AGENTS.md` is a concise operational companion and must stay aligned with this file.
4. For `ai-staff-hq/` files, use `ai-staff-hq/CLAUDE.md` and sibling guides in that submodule.

---

## Documentation Governance (Canonical + Derived)

To prevent drift and contradictions:

1. Canonical root contract:

- `CLAUDE.md` is the only authoritative architecture and behavior contract for root `dotfiles`.

2. Derived-view docs:

- `README.md`
- `docs/README.md`
- `docs/daily-loop-handbook.md`
- `docs/ai-handbook.md`
- `docs/autopilot-happy-path.md`
- `docs/general-reference-handbook.md`
- `docs/ROADMAP-ENERGY.md`
- `scripts/README.md`
- `scripts/README_aliases.md`
- `docs/archive/phases.md`

3. Update workflow when behavior changes:

- First update `CLAUDE.md` contract language (if behavior/interface changed).
- Then update only the affected derived docs to reference the canonical contract.
- Avoid hardcoded counts/version claims in derived docs unless generated automatically.

---

## Project Overview

This is a personal productivity system built around shell scripts, AI dispatchers, and automation tools. It provides:

- Daily workflow automation (startday, goodevening, status)
- Task and journal management
- Health and energy tracking (spoon theory)
- AI-powered assistants via OpenRouter API
- Blog content generation and management

**Primary user context:** Developer with MS (multiple sclerosis) who needs cognitive support, energy management, and brain-fog-friendly workflows.

---

## Directory Structure

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

---

## Mandatory Script Headers

All executed bash scripts must use:

- `#!/usr/bin/env bash`
- `set -euo pipefail`

Header templates differ by script type.

### Executed Utility Scripts (`scripts/*.sh`)

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
```

### Executed Dispatchers (`bin/dhp-*.sh`)

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/dhp-shared.sh"
```

**Requirements:**

- Use `#!/usr/bin/env bash` (NOT `#!/bin/bash`) for portability
- Always enable strict mode with `set -euo pipefail`
- Avoid Bash 4-only features in root `dotfiles` scripts and libraries unless there is an explicit runtime requirement.
- If Bash 4+ features are unavoidable, add a clear runtime guard and update `CLAUDE.md`, `AGENTS.md`, `scripts/README.md`, and `CHANGELOG.md` to note the requirement.
- Bootstrap wrappers that exist only to locate and exec a modern Bash for launchd/cron may use POSIX `sh`; keep that exception narrow and documented inline.
- `scripts/*.sh` should source `common.sh` (and `config.sh` when required)
- `bin/dhp-*.sh` should use `dhp-shared.sh`

### EXCEPTION: Sourced Libraries and "Must Be Sourced" Scripts

**Libraries in `scripts/lib/` and scripts designed to be sourced (not executed) must NOT set `set -euo pipefail`.**

These files should rely on the caller to set shell options. Setting strict mode in a sourced file can:

- Cause the parent shell to exit unexpectedly on minor errors
- Break interactive shell sessions when sourced from `.zshrc`
- Create hard-to-debug failures in the calling script

**Correct pattern for sourced files:**

```bash
#!/usr/bin/env bash
# library-name.sh - Description
# NOTE: This file is SOURCED, not executed. Do not set -euo pipefail.

# Double-source guard
if [[ -n "${_LIBRARY_NAME_LOADED:-}" ]]; then
    return 0
fi
readonly _LIBRARY_NAME_LOADED=true

# Library functions follow...
```

**Files that must NOT have `set -euo pipefail`:**

- All files in `scripts/lib/*.sh`
- `zsh/aliases.zsh`
- `scripts/g.sh` (navigation, must be sourced)
- `bin/dhp-context.sh` (context helpers)
- `scripts/spec_helper.sh` (template editing)
- Any script with "must be sourced" in its header

---

## Library Architecture

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
| `coach_chat.sh`   | Interactive post-briefing coach conversation       | After startday/status/goodevening |

### Library Sourcing Pattern

```bash
# With fallback for different execution contexts
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    source "$SCRIPT_DIR/lib/common.sh"
elif [[ -f "$SCRIPT_DIR/../lib/common.sh" ]]; then
    source "$SCRIPT_DIR/../lib/common.sh"
else
    echo "Error: common.sh not found" >&2
    exit 1
fi
```

### Config and Environment Centralization

- Only `scripts/lib/config.sh` may source `.env`.
- Exception: `scripts/validate_env.sh` may read `.env` directly for validation checks.
- After sourcing `config.sh`, do not redefine `DATA_DIR` (or other config vars) with script-local `${VAR:-...}` fallbacks to hardcoded home paths.
- Scripts should fail fast if `config.sh` cannot be sourced; do not silently bypass configuration loading.

### Library Dependency Contract

- Libraries in `scripts/lib/` must not self-source sibling libraries.
- Compatibility exception: `common.sh` may bootstrap `file_ops.sh`/`config.sh` while migration is in progress; do not add new self-sourcing patterns elsewhere.
- Each library should declare required dependencies in a short header comment (e.g., `config.sh`, `common.sh`, `date_utils.sh`).
- Callers (executed scripts/tests) are responsible for sourcing dependencies in the correct order before sourcing dependent libraries.
- Dependency failures should be explicit and immediate (clear error + non-zero return), not silently auto-healed by re-sourcing.

### Double-Source Prevention

Libraries that may be sourced multiple times MUST include a guard:

```bash
# At top of library file
if [[ -n "${_COMMON_SH_LOADED:-}" ]]; then
    return 0
fi
readonly _COMMON_SH_LOADED=true
```

---

## Data File Conventions

### Location

All user data lives in `~/.config/dotfiles-data/` (XDG-compliant).

Access via `config.sh`:

```bash
source "$SCRIPT_DIR/lib/config.sh"
# Now use: $DATA_DIR, $TODO_FILE, $JOURNAL_FILE, etc.
```

### File Formats

| File            | Format                           | Example                                      |
| --------------- | -------------------------------- | -------------------------------------------- |
| `todo.txt`      | `DATE\|task text`                | `2025-01-15\|Fix login bug`                  |
| `todo_done.txt` | `YYYY-MM-DD HH:MM:SS\|task text` | `2025-01-15 14:30:00\|Fix login bug`         |
| `journal.txt`   | `YYYY-MM-DD HH:MM:SS\|entry`     | `2025-01-15 09:00:00\|Morning reflection...` |
| `health.txt`    | `TYPE\|DATE\|fields...`          | `SYMPTOM\|2025-01-15\|fatigue\|3`            |
| `spoons.txt`    | `TYPE\|DATE\|fields...`          | `BUDGET\|2025-01-15\|12`                     |

**Critical:** Always sanitize user input before writing:

```bash
sanitized=$(sanitize_input "$user_input")
```

---

## Error Handling

### Exit Codes

Use named constants from `common.sh`:

```bash
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_INVALID_ARGS=2
readonly EXIT_FILE_NOT_FOUND=3
readonly EXIT_PERMISSION=4
readonly EXIT_SERVICE_ERROR=5
```

### Error Reporting

```bash
# Use die() for fatal errors (logs and exits)
die "Configuration file not found" "$EXIT_FILE_NOT_FOUND"

# Use log functions for non-fatal issues
log_error "API call failed, retrying..."
log_warn "Cache expired, regenerating"
log_info "Processing complete"
```

### Validation Functions

Always validate before use:

```bash
validate_numeric "$count" "task count"
validate_range "$energy" 1 10 "energy level"
validate_file_exists "$config_path" "config file"
validate_path "$user_path"  # Security: prevents traversal
```

### Dependency Checking

```bash
require_cmd "jq" "Install with: brew install jq"
require_cmd "curl"
require_file "$ENV_FILE" ".env configuration"
require_dir "$DATA_DIR" "data directory"
```

---

## AI Dispatcher Architecture

### Dispatcher Structure (`bin/dhp-*.sh`)

Dispatchers MUST use the shared framework:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/dhp-shared.sh"

dhp_dispatch \
    "Dispatcher Name" \
    "model-id" \
    "$HOME/Documents/AI_Staff_HQ_Outputs/Category" \
    "MODEL_ENV_VAR" \
    "OUTPUT_DIR_ENV_VAR" \
    "System prompt/instructions" \
    "0.5" \
    "$@"
```

### Dispatcher Naming

- Script: `dhp-<type>.sh` (e.g., `dhp-tech.sh`, `dhp-creative.sh`)
- Alias: Short form (e.g., `tech`, `creative`, `aicopy`)
- Model var: `<TYPE>_MODEL` (e.g., `TECH_MODEL`)

### Standard Flags (handled by dhp-shared.sh)

- `--stream` - Real-time streaming output
- `--verbose` - Debug logging
- `--temperature <float>` - Override default

## Wearable Context

- Fitbit wearable data should flow into `~/.config/dotfiles-data/fitbit/*.txt` through `scripts/fitbit_sync.sh` or `scripts/fitbit_import.sh`.
- When Google Health auth is already present, `scripts/startday.sh`, `scripts/status.sh`, and `scripts/goodevening.sh` should do a best-effort Fitbit sync before rendering summaries or coach context.
- Coach prompts must treat wearable metrics in the behavior digest as live health context and must not suggest Fitbit setup or migration work when those metrics are already present.
- When both latest manual energy/fog readings and trailing averages are present in the behavior digest, coach prompts should treat the latest values as current state and the averages as recent trend.
- When `scripts/status.sh` is interactive and the AI coach is enabled, it should offer manual energy/fog logging before building the coach digest so that same-run entries affect the briefing immediately.

## Coach Briefing Contract

- `startday`, `status`, and `goodevening` should all use a gentle-partner tone by default and keep outputs high-signal and low-noise.
- Coach outputs should open with what is working unless there is a real risk. Real risk means a clear health/body risk, a same-day blocker, `latest_energy <= 1`, or `latest_fog >= 8`.
- `startday` should feel like a gentle check-in first, then a plan. `status` should feel like a midpoint reset with one immediate next move. `goodevening` should celebrate wins first, then debrief and set up tomorrow lightly.
- In interactive runs, `startday`, `status`, and `goodevening` may ask up to 3 pre-brief clarification questions before calling the AI. Those questions should be answerable in one line using numbered `A/B/C/D/E` choices like `1B 2A 3E`, with `E` reserved for a custom note.
- The daily coach prompts may now include an Additional local context bundle with bounded raw local context from the last 7 days: journal entries, open todos/top tasks, schedule output, suggested directories, blog snapshots, launchpad text, weekly review text, and raw health/spoon/directory-log slices. Git/focus remain primary signals; the local bundle is secondary evidence for specificity.
- GitHub blindspot/opportunity sections should be capped at 5 items. Each item must be concrete, point to an obvious next action, and use real repo names when the evidence supports it.
- Blindspot sections may be post-processed after AI generation to remove raw metric/debug noise such as `dir_usage_malformed`, `commit_context`, or raw `focus_git_status=...` values, then backfill grounded repo-specific actions.
- `scripts/lib/coach_chat.sh` should prefer short `A/B/C/D/E` clarifying questions with `E` as a custom answer when a follow-up question would materially improve the coaching.

### Specialized Standalone Agents

- Not every AI entrypoint needs to be a `dhp-*` dispatcher.
- Repo-specific agents may live in `bin/` as standalone executables when they own a focused workflow that would be awkward to force through `dhp-shared.sh`.
- `bin/cyborg` is the Cyborg Lab ingest/resume agent: an interactive session tool that scans a source repo, proposes a Cyborg Lab content graph, stages near-publishable drafts, stores resumable session artifacts under `~/Projects/cyborg-work` by default (override with `CYBORG_WORK_DIR`), only writes to `my-ms-ai-blog` on explicit apply, and should prefer accessible `A/B/C/D/E` short-choice prompts when it asks the user to choose. `cyborg auto` runs the full pipeline hands-free for low-energy sessions; `cyborg auto --iterate` is the incremental-growth path for existing repos, pulling the next GitHub issue or backlog item, auto-applying the repo change, and running the same build-verify-fix loop against that repo before stopping unless `--docs-after-code` is set; `cyborg auto --build` runs market validation, scaffolds a project via Morphling, runs the build-verify-fix loop, and then hands the verified repo to Cyborg for documentation. Add `--publish` when you want the verified build pushed to its registry before the docs pass. See [`bin/autopilot-readme.md`](bin/autopilot-readme.md) for the convergence architecture and [`MORPHLING.md`](MORPHLING.md) for Morphling's full capabilities including command execution.
- `bin/morphling.sh` is the Morphling launcher. In direct mode (`bin/morphling.sh`) it runs as a LangChain ReAct agent with four tools: `read_file`, `write_file`, `list_directory`, and `run_command` (shell execution with 60s timeout). This makes it a lead-developer agent that can write code, run tests, and iterate until things work. The `morphling` shell alias points to swarm mode (`bin/dhp-morphling.sh`), the one-shot context-rich analysis path with no tool access.
- `bin/coach-chat.py` is the multi-turn coach chat handler. It maintains conversation history in a JSON file and calls OpenRouter for follow-up turns. Invoked by `scripts/lib/coach_chat.sh` — not called directly by users. Supports `init` (create history with system prompt + briefing) and `turn` (append message, call API, return response).
- Standalone agents must still follow root-project rules: strict mode for shell launchers, predictable config loading, explicit path validation, and session state stored in repo-appropriate locations.

### Input Handling

Dispatchers accept input via:

1. Stdin: `cat file.txt | tech`
2. Argument: `creative "story idea"`
3. Both: `echo "context" | tech "question"`

---

## Alias Conventions (`zsh/aliases.zsh`)

### Naming Patterns

| Category       | Pattern             | Examples                       |
| -------------- | ------------------- | ------------------------------ |
| Navigation     | Short/memorable     | `..`, `downloads`, `projects`  |
| Git            | `g` prefix          | `gs`, `ga`, `gc`, `gp`, `gd`   |
| Scripts        | Full name or abbrev | `todo`, `journal`, `j`, `ta`   |
| AI Dispatchers | Type name           | `tech`, `creative`, `strategy` |
| Repo Agents    | Project name        | `cyborg`                       |
| Spoons         | `s-` prefix         | `s-check`, `s-spend`           |
| Correlations   | `corr-` prefix      | `corr-sleep`, `corr-rhr`       |

### Alias vs Function

- **Alias:** Simple command shortcuts
- **Function:** When logic, conditionals, or multiple commands needed

```bash
# Alias - simple
alias gs="git status"

# Function - has logic
ta() {
    if [[ -z "$1" ]]; then
        echo "Usage: ta <task>" >&2
        return 1
    fi
    todo.sh add "$@"
}
```

### Critical Alias Rules

1. **Never shadow system commands** without explicit intent
2. **`copy` = `pbcopy`** (clipboard), **`aicopy` = AI copywriter**
3. **Document non-obvious aliases** with comments
4. **Group by category** with section headers

---

## Sourced vs Executed Scripts

### Scripts That Must Be SOURCED (use `return`, not `exit`)

- All files in `scripts/lib/*.sh` - Shared libraries
- `scripts/g.sh` - Changes directory in parent shell
- `zsh/aliases.zsh` - Defines shell functions
- `bin/dhp-context.sh` - Provides context helpers
- `scripts/spec_helper.sh` - Interactive template editing

**Critical rules for sourced scripts:**

1. **Do NOT use `set -euo pipefail`** - the caller controls shell options
2. **Use `return`, not `exit`** - exit kills the parent shell
3. **Use double-source guards** - prevent re-initialization

Pattern for sourced scripts:

```bash
#!/usr/bin/env bash
# IMPORTANT: This script must be SOURCED, not executed
# Do NOT use set -euo pipefail here - caller controls shell options
# Use 'return' instead of 'exit'

# Double-source guard
if [[ -n "${_MY_SCRIPT_LOADED:-}" ]]; then
    return 0
fi
readonly _MY_SCRIPT_LOADED=true

_my_function() {
    # Implementation
    return 0  # NOT exit 0
}
```

### Scripts That Are EXECUTED (use `exit` and `set -euo pipefail`)

- Standalone utilities: `todo.sh`, `journal.sh`, `health.sh`
- Dispatchers: `dhp-tech.sh`, etc.
- System scripts: `startday.sh`, `goodevening.sh`

These scripts MUST have `set -euo pipefail` at the top.

---

## Cross-Platform Compatibility

### Date Handling

Use `scripts/lib/date_utils.sh` for all date/time operations in root scripts.

- Do not add new inline `date -v`, `date -d`, `gdate -d`, or ad-hoc cross-platform date parsing.
- Prefer helpers such as:
  - `date_shift_days`
  - `date_shift_from`
  - `date_days_ago`
  - `date_now` / `date_today` / `date_epoch_now`
  - `date_now_utc` / `date_shift_days_utc`
  - `timestamp_to_epoch`
  - `file_mtime_epoch`
  - `epoch_to_utc_iso`

### Command Availability

```bash
# Check before using
if command -v jq >/dev/null 2>&1; then
    # Use jq
else
    # Fallback or skip
fi
```

### macOS-Specific

When using macOS-only features, guard them:

```bash
if [[ "$OSTYPE" == "darwin"* ]]; then
    pbcopy < "$file"  # macOS clipboard
fi
```

---

## Security Requirements

### Input Sanitization

**ALWAYS** sanitize user input:

```bash
sanitized=$(sanitize_input "$user_input")
```

### Path Validation

**NEVER** trust user-provided paths:

```bash
validated_path=$(validate_path "$user_path")
```

### Command Execution

**NEVER** use `eval` with user input:

```bash
# BAD - command injection risk
eval "$user_command"

# GOOD - use arrays and explicit commands
allowed_commands=("ls" "cat" "grep")
if [[ " ${allowed_commands[*]} " =~ " $cmd " ]]; then
    "$cmd" "${args[@]}"
fi
```

### Sensitive Data

- API keys in `.env` only (never committed)
- `.env` has `chmod 600`
- Use `redact_sensitive()` before logging

---

## Documentation Requirements

### Script Header Documentation

```bash
#!/usr/bin/env bash
# script-name.sh - One-line description
#
# Detailed description of what this script does,
# its main features, and any important notes.
#
# Usage: script-name.sh <command> [options] [arguments]
#
# Commands:
#   add <item>     Add a new item
#   list           List all items
#   remove <id>    Remove item by ID
#
# Options:
#   -h, --help     Show this help
#   -v, --verbose  Verbose output
#
# Examples:
#   script-name.sh add "New task"
#   script-name.sh list
```

### Function Documentation

```bash
# Brief description of function purpose
# Usage: function_name <required_arg> [optional_arg]
# Arguments:
#   required_arg - Description
#   optional_arg - Description (default: value)
# Returns: Description of output
# Exit codes: 0 on success, 1 on error
function_name() {
    local required_arg="$1"
    local optional_arg="${2:-default}"
    # Implementation
}
```

### Updating Documentation

When modifying functionality:

1. Update relevant `docs/*.md` files
2. Update `CHANGELOG.md` with changes
3. Update `scripts/cheatsheet.sh` if aliases change
4. Update `bin/README.md` for dispatcher changes

---

## Testing Guidelines

### Test Location

Tests live in `tests/` with pattern `test_<module>.sh`

### Test Structure

```bash
#!/usr/bin/env bats

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    setup_test_environment
    # stage scripts/libs into "$TEST_DIR" as needed
}

teardown() {
    teardown_test_environment
}

@test "feature works" {
    run "$TEST_DIR/scripts/example.sh" command
    [ "$status" -eq 0 ]
    [[ "$output" =~ "expected text" ]]
}
```

Run tests with:

```bash
bats tests/*.sh
```

### What to Test

- Library functions in `scripts/lib/`
- Critical paths in main scripts
- Edge cases and error handling
- Integration between components

---

## Markdown Formatting Standards

To ensure clean, standard markdown output and minimal git diffs, you MUST adhere to the following when generating or modifying markdown (.md) documents:

1. **No Trailing Spaces**: Never leave trailing whitespace at the ends of lines.
2. **Code Blocks**: Always enforce exactly one empty line before and after fenced code blocks (```).
3. **Headings**: Always enforce exactly one empty line before headings unless they are the very first line of the document.
4. **Lists**: Use 2 spaces for nested list indentation.
5. **EOF**: Always end the file with a single newline.

---

## Common Anti-Patterns to AVOID

| Anti-Pattern                         | Correct Approach                  |
| ------------------------------------ | --------------------------------- |
| `#!/bin/bash`                        | `#!/usr/bin/env bash`             |
| No error handling (executed scripts) | `set -euo pipefail`               |
| `set -euo pipefail` in sourced libs  | Caller controls shell options     |
| Hard-coded paths                     | Use `$DATA_DIR`, `$DOTFILES_DIR`  |
| Silent failures                      | Log errors, use proper exit codes |
| `eval "$user_input"`                 | Validate and use arrays           |
| Duplicate code                       | Extract to `scripts/lib/`         |
| Magic numbers                        | Use named constants               |
| No input validation                  | Use `validate_*()` functions      |
| `exit` in sourced script             | Use `return`                      |
| Assuming commands exist              | Use `require_cmd()`               |

---

## Quick Reference

### Creating a New Executed Script

1. Use header template with `set -euo pipefail`
2. If in `scripts/`, source `common.sh` (and `config.sh` only when needed)
3. If in `bin/` dispatcher scripts, source `dhp-shared.sh`
4. Add to `zsh/aliases.zsh` if needed
5. Document in appropriate README
6. Add tests for critical functionality

### Creating a New Dispatcher

1. Create `bin/dhp-<name>.sh` using `dhp-shared.sh`
2. Add alias in `zsh/aliases.zsh`
3. Add model config to `.env.example`
4. Document in `bin/README.md`
5. Update `docs/ai-quick-reference.md` with usage examples

### Adding a New Library (Sourced File)

1. Create in `scripts/lib/<name>.sh`
2. **Do NOT add `set -euo pipefail`** - caller controls this
3. Add double-source guard
4. Export functions explicitly
5. Document all public functions
6. Add tests in `tests/test_<name>.sh`

### Modifying Configuration

1. Add defaults to `scripts/lib/config.sh`
2. Add to `.env.example` with documentation
3. Use getter functions for access
4. Document in relevant docs

---

## Version Control

### Commit Messages

Follow conventional commits:

```
feat: add spoon tracking to startday
fix: correct date parsing on macOS
docs: update dispatcher examples
refactor: extract validation to common.sh
test: add spoon budget library tests
```

### What NOT to Commit

- `.env` (use `.env.example` as template)
- `*.log` files
- Temporary/cache files
- Personal data from `~/.config/dotfiles-data/`

---

## Performance Considerations

### Startup Time

- Minimize sourced files in `.zshrc`
- Use lazy loading for heavy operations
- Cache expensive computations (e.g., AI briefings)

### API Calls

- Cache AI responses when appropriate
- Use `BRIEFING_CACHE_FILE` pattern
- Implement rate limiting awareness

---

## Changelog Updates

When making changes, update `CHANGELOG.md`:

```markdown
## Version X.Y.Z (Date) - Brief Title

**Status:** Production Ready / In Development

### Category (e.g., New Features, Bug Fixes)

- **Feature name**: Description of change
- Bullet points for details
```

---

_This document should be updated whenever new patterns are established or existing conventions change._

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **dotfiles** (3901 symbols, 6682 relationships, 300 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## When Debugging

1. `gitnexus_query({query: "<error or symptom>"})` — find execution flows related to the issue
2. `gitnexus_context({name: "<suspect function>"})` — see all callers, callees, and process participation
3. `READ gitnexus://repo/dotfiles/process/{processName}` — trace the full execution flow step by step
4. For regressions: `gitnexus_detect_changes({scope: "compare", base_ref: "main"})` — see what your branch changed

## When Refactoring

- **Renaming**: MUST use `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})` first. Review the preview — graph edits are safe, text_search edits need manual review. Then run with `dry_run: false`.
- **Extracting/Splitting**: MUST run `gitnexus_context({name: "target"})` to see all incoming/outgoing refs, then `gitnexus_impact({target: "target", direction: "upstream"})` to find all external callers before moving code.
- After any refactor: run `gitnexus_detect_changes({scope: "all"})` to verify only expected files changed.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Tools Quick Reference

| Tool | When to use | Command |
|------|-------------|---------|
| `query` | Find code by concept | `gitnexus_query({query: "auth validation"})` |
| `context` | 360-degree view of one symbol | `gitnexus_context({name: "validateUser"})` |
| `impact` | Blast radius before editing | `gitnexus_impact({target: "X", direction: "upstream"})` |
| `detect_changes` | Pre-commit scope check | `gitnexus_detect_changes({scope: "staged"})` |
| `rename` | Safe multi-file rename | `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})` |
| `cypher` | Custom graph queries | `gitnexus_cypher({query: "MATCH ..."})` |

## Impact Risk Levels

| Depth | Meaning | Action |
|-------|---------|--------|
| d=1 | WILL BREAK — direct callers/importers | MUST update these |
| d=2 | LIKELY AFFECTED — indirect deps | Should test |
| d=3 | MAY NEED TESTING — transitive | Test if critical path |

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/dotfiles/context` | Codebase overview, check index freshness |
| `gitnexus://repo/dotfiles/clusters` | All functional areas |
| `gitnexus://repo/dotfiles/processes` | All execution flows |
| `gitnexus://repo/dotfiles/process/{name}` | Step-by-step execution trace |

## Self-Check Before Finishing

Before completing any code modification task, verify:
1. `gitnexus_impact` was run for all modified symbols
2. No HIGH/CRITICAL risk warnings were ignored
3. `gitnexus_detect_changes()` confirms changes match expected scope
4. All d=1 (WILL BREAK) dependents were updated

## Keeping the Index Fresh

After committing code changes, the GitNexus index becomes stale. Re-run analyze to update it:

```bash
npx gitnexus analyze
```

If the index previously included embeddings, preserve them by adding `--embeddings`:

```bash
npx gitnexus analyze --embeddings
```

To check whether embeddings exist, inspect `.gitnexus/meta.json` — the `stats.embeddings` field shows the count (0 means no embeddings). **Running analyze without `--embeddings` will delete any previously generated embeddings.**

> Claude Code users: A PostToolUse hook handles this automatically after `git commit` and `git merge`.

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
