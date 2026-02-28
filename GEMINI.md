# GEMINI.md - AI Development Guidelines for Dotfiles System

> [!IMPORTANT]
> **CONTEXT AWARENESS REQUIRED**: You are working in a multi-scope repository.
> Before making changes, check `GUARDRAILS.md` to ensure you are applying the correct standards for the current directory.

## Primary Directives

1. **Read `GUARDRAILS.md`**: Understand which scope you are in (`Root` vs `ai-staff-hq`).
2. **For root (`dotfiles`) files, follow `CLAUDE.md` as canonical**.
3. **Use `AGENTS.md` as a quick checklist** aligned with `CLAUDE.md`.
4. **Use this guide as a Gemini-specific adapter** for the same rules.

## Submodule Work

If you are asked to work on **AI-Staff-HQ**:

1. Switch context to `ai-staff-hq/`.
2. Read `ai-staff-hq/GEMINI.md` and `ai-staff-hq/CLAUDE.md`.
3. **THEN** apply the Candlelite theme and web-ui standards.

---

## Critical Rules - Read First

These rules are NON-NEGOTIABLE for the root dotfiles project:

| Rule              | Details                                         |
| ----------------- | ----------------------------------------------- |
| Executed scripts  | Use `#!/usr/bin/env bash` + `set -euo pipefail` |
| Sourced libraries | NEVER use `set -euo pipefail`                   |
| Data location     | `~/.config/dotfiles-data/` only                 |
| User input        | ALWAYS sanitize with `sanitize_input()`         |
| User paths        | ALWAYS validate with `validate_path()`          |
| `copy` alias      | Maps to `pbcopy` (clipboard)                    |
| `aicopy` alias    | Maps to AI copywriter dispatcher                |

---

## Project Overview

**What this is:** Personal productivity system for a developer with MS (multiple sclerosis)

**Key features:**

- Daily workflow automation (startday, goodevening, status)
- Task and journal management
- Health/energy tracking (spoon theory)
- AI assistants via OpenRouter API
- Blog content generation

**Design philosophy:** Reliability and cognitive support over feature richness

---

## Directory Map

```
dotfiles/
├── scripts/           # Executed utilities
│   └── lib/          # Sourced libraries (NO set -euo pipefail!)
├── bin/              # AI dispatchers (dhp-*.sh)
├── zsh/              # Shell config (sourced)
├── docs/             # Documentation
├── tests/            # Tests
├── templates/        # AI dispatcher templates
├── brain/            # Knowledge base
├── ai-staff-hq/      # AI definitions (submodule - different rules!)
└── .env              # Config (never commit)
```

---

## Two Types of Bash Files

### 1. EXECUTED Scripts

**These ARE standalone programs.**

Location: `scripts/*.sh` and executed dispatchers in `bin/`

Examples: `todo.sh`, `journal.sh`, `startday.sh`, `dhp-tech.sh`

For scripts in `scripts/`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
```

For dispatchers in `bin/`:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/dhp-shared.sh"
```

**Key points:**

- MUST have `set -euo pipefail`
- Use `exit` for termination
- Can be run directly: `./script.sh`

---

### 2. SOURCED Files (Libraries)

**These are NOT standalone - they're loaded into other scripts.**

Location: `scripts/lib/*.sh`, `zsh/aliases.zsh`, `scripts/g.sh`, `bin/dhp-context.sh`, `scripts/spec_helper.sh`

**Required header:**

```bash
#!/usr/bin/env bash
# filename.sh - Description
# SOURCED FILE - Do NOT use set -euo pipefail

if [[ -n "${_FILENAME_LOADED:-}" ]]; then
    return 0
fi
readonly _FILENAME_LOADED=true

# Implementation...
```

**Key points:**

- NEVER use `set -euo pipefail` (breaks parent shell)
- MUST have double-source guard
- Use `return`, NEVER `exit`
- Loaded via: `source script.sh`

---

## Why Sourced Files Can't Use Strict Mode

If a sourced file sets `set -e`:

- Any error in the library kills the parent shell
- Interactive shells become unusable
- Hard-to-debug cascading failures

**The caller decides shell options, not the library.**

---

## Data Files

### Location

Everything in: `~/.config/dotfiles-data/`

Access via config.sh:

```bash
source "$SCRIPT_DIR/lib/config.sh"
# Now use: $DATA_DIR, $TODO_FILE, $JOURNAL_FILE
```

### Formats

| File          | Format                                                                   | Example                           |
| ------------- | ------------------------------------------------------------------------ | --------------------------------- |
| todo.txt      | `YYYY-MM-DD\|task text`                                                  | `2025-01-15\|Fix bug`             |
| todo_done.txt | `YYYY-MM-DD HH:MM:SS\|task text`                                         | `2025-01-15 14:30:00\|Fix bug`    |
| journal.txt   | `YYYY-MM-DD HH:MM:SS\|entry`                                             | `2025-01-15 09:00:00\|Entry`      |
| health.txt    | `TYPE\|DATE\|field1\|field2...`                                          | `SYMPTOM\|2025-01-15\|fatigue\|3` |
| spoons.txt    | `BUDGET\|DATE\|count` or `SPEND\|DATE\|TIME\|count\|activity\|remaining` | `BUDGET\|2025-01-15\|12`          |

### Sanitization (REQUIRED)

```bash
clean=$(sanitize_input "$user_input")
echo "$clean" >> "$TODO_FILE"
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

### Validation

```bash
validate_numeric "$val" "count"
validate_path "$path"  # Security check
require_cmd "jq"
```

### Reporting

```bash
die "Fatal error" "$EXIT_ERROR"
log_error "Problem occurred"
log_warn "Warning"
```

---

## AI Dispatchers (bin/dhp-\*.sh)

### Pattern

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/dhp-shared.sh"

dhp_dispatch "Name" "model" "$output_dir" \
    "MODEL_VAR" "OUTPUT_VAR" "prompt" "0.5" "$@"
```

### Naming

- Script: `dhp-<type>.sh`
- Alias: `tech`, `creative`, `aicopy`, etc.
- Config: `<TYPE>_MODEL` in .env

### Flags

- `--stream` - Real-time output
- `--temperature <float>`

---

## Aliases

### Important

| Alias    | Maps To       | Purpose          |
| -------- | ------------- | ---------------- |
| `copy`   | `pbcopy`      | System clipboard |
| `aicopy` | `dhp-copy.sh` | AI copywriting   |

**Never confuse these!**

### Categories

- Git: `gs`, `ga`, `gc`, `gp`
- AI: `tech`, `creative`, `strategy`
- Scripts: `todo`, `journal`, `j`
- Spoons: `s-check`, `s-spend`

---

## Security

### ALWAYS Do

```bash
sanitize_input "$user_input"
validate_path "$user_path"
require_cmd "dependency"
```

### NEVER Do

```bash
eval "$user_input"      # Command injection
cat "$untrusted_path"   # Path traversal
```

---

## Cross-Platform

### Dates

```bash
if date --version >/dev/null 2>&1; then
    date -d "yesterday" +%Y-%m-%d  # GNU/Linux
else
    date -v-1d +%Y-%m-%d  # macOS
fi
```

### macOS Only

```bash
if [[ "$OSTYPE" == "darwin"* ]]; then
    pbcopy < file
fi
```

---

## Anti-Patterns

| BAD                       | GOOD                    |
| ------------------------- | ----------------------- |
| `#!/bin/bash`             | `#!/usr/bin/env bash`   |
| No strict mode (executed) | `set -euo pipefail`     |
| Strict mode (sourced)     | Caller controls options |
| `exit` in library         | `return`                |
| Hard-coded paths          | `$DATA_DIR` variables   |
| `eval "$input"`           | Validate first          |

---

## Markdown Formatting Standards

To ensure clean, standard markdown output and minimal git diffs, you MUST adhere to the following when generating or modifying markdown (.md) documents:

1. **No Trailing Spaces**: Never leave trailing whitespace at the ends of lines.
2. **Code Blocks**: Always enforce exactly one empty line before and after fenced code blocks (```).
3. **Headings**: Always enforce exactly one empty line before headings unless they are the very first line of the document.
4. **Lists**: Use 2 spaces for nested list indentation.
5. **EOF**: Always end the file with a single newline.

---

## Checklists

### New Executed Script

```
[ ] #!/usr/bin/env bash
[ ] set -euo pipefail
[ ] scripts/*.sh: source common.sh (config.sh only if needed)
[ ] bin/dhp-*.sh: source dhp-shared.sh
[ ] Add alias if needed
[ ] Update docs
```

### New Library

```
[ ] NO set -euo pipefail
[ ] Double-source guard
[ ] return, not exit
[ ] Mark as "must be sourced"
```

### New Dispatcher

```
[ ] Use dhp-shared.sh
[ ] Add alias
[ ] Add to .env.example
[ ] Document in bin/README.md
```

---

## Testing

- Use `bats-core` for shell tests.
- Place tests in `tests/test_*.sh` with `#!/usr/bin/env bats`.
- Reuse helpers from `tests/helpers/test_helpers.sh` and `tests/helpers/assertions.sh`.
- Run all tests with: `bats tests/*.sh`

---

## Documentation Updates

When changing code:

1. `docs/*.md` - Feature docs
2. `CHANGELOG.md` - Version history
3. `scripts/cheatsheet.sh` - Alias changes
4. `bin/README.md` - Dispatcher changes

---

## Reference

For complete guidelines, see: `CLAUDE.md`

---

_Follow these rules consistently. When in doubt, check existing code patterns or refer to CLAUDE.md._
