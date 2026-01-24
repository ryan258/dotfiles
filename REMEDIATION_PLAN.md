# Dotfiles Codebase Remediation Plan

This plan addresses code smells, orphaned code, and architectural misalignments identified during the comprehensive codebase review.

---

## Phase 1: Critical - Prevent Data Loss

**Priority:** Immediate
**Risk:** Data corruption/loss on script failure

### 1.1 Add Atomic File Operations Library

Create `scripts/lib/file_ops.sh`:

```bash
#!/usr/bin/env bash
# Atomic file operations to prevent data loss

# Atomic write: writes to temp file, then moves atomically
# Usage: atomic_write "content" "/path/to/file"
atomic_write() {
    local content="$1"
    local target="$2"
    local temp_file

    temp_file=$(mktemp "${target}.XXXXXX") || {
        echo "Error: Failed to create temp file for $target" >&2
        return 1
    }

    # Ensure cleanup on failure
    trap "rm -f '$temp_file'" EXIT

    printf '%s' "$content" > "$temp_file" || {
        echo "Error: Failed to write to temp file" >&2
        rm -f "$temp_file"
        return 1
    }

    mv "$temp_file" "$target" || {
        echo "Error: Failed to move temp file to $target" >&2
        rm -f "$temp_file"
        return 1
    }

    trap - EXIT
    return 0
}

# Atomic line prepend: prepends line to file atomically
# Usage: atomic_prepend "new line" "/path/to/file"
atomic_prepend() {
    local new_line="$1"
    local target="$2"
    local temp_file

    temp_file=$(mktemp "${target}.XXXXXX") || return 1
    trap "rm -f '$temp_file'" EXIT

    { echo "$new_line"; cat "$target" 2>/dev/null; } > "$temp_file" || {
        rm -f "$temp_file"
        return 1
    }

    mv "$temp_file" "$target" || {
        rm -f "$temp_file"
        return 1
    }

    trap - EXIT
    return 0
}

# Atomic line delete: removes line N from file atomically
# Usage: atomic_delete_line 5 "/path/to/file"
atomic_delete_line() {
    local line_num="$1"
    local target="$2"
    local temp_file

    temp_file=$(mktemp "${target}.XXXXXX") || return 1
    trap "rm -f '$temp_file'" EXIT

    sed "${line_num}d" "$target" > "$temp_file" || {
        rm -f "$temp_file"
        return 1
    }

    mv "$temp_file" "$target" || {
        rm -f "$temp_file"
        return 1
    }

    trap - EXIT
    return 0
}

# Atomic line replace: replaces line N in file atomically
# Usage: atomic_replace_line 5 "new content" "/path/to/file"
atomic_replace_line() {
    local line_num="$1"
    local new_content="$2"
    local target="$3"
    local temp_file

    temp_file=$(mktemp "${target}.XXXXXX") || return 1
    trap "rm -f '$temp_file'" EXIT

    sed "${line_num}s|.*|${new_content}|" "$target" > "$temp_file" || {
        rm -f "$temp_file"
        return 1
    }

    mv "$temp_file" "$target" || {
        rm -f "$temp_file"
        return 1
    }

    trap - EXIT
    return 0
}
```

### 1.2 Fix todo.sh Data Loss Risks

**File:** `scripts/todo.sh`

Replace all instances of unsafe file operations:

```bash
# BEFORE (line 238 and similar):
echo "$task_line" | cat - "$TODO_FILE" > temp && mv temp "$TODO_FILE"

# AFTER:
source "$SCRIPT_DIR/lib/file_ops.sh"
atomic_prepend "$task_line" "$TODO_FILE" || {
    echo "Error: Failed to update todo file" >&2
    exit 1
}
```

**Specific fixes needed:**
- Line 238: `bump` command - use `atomic_prepend`
- Line 180: task completion - use `atomic_delete_line`
- Line 202: task deletion - use `atomic_delete_line`
- Line 135: priority update - use `atomic_replace_line`

### 1.3 Add Cleanup Traps to All Scripts

Add to scripts that create temp files:

```bash
# Add near top of script, after variable declarations
cleanup() {
    rm -f "$TEMP_FILE" 2>/dev/null
    # Add other temp files as needed
}
trap cleanup EXIT INT TERM
```

**Scripts requiring this fix:**
- `scripts/todo.sh`
- `scripts/blog.sh`
- `scripts/health.sh`
- `scripts/journal.sh`

### 1.4 Remove .bak File Creation

Replace all `sed -i.bak` with atomic operations:

```bash
# BEFORE:
sed -i.bak "s/old/new/" "$FILE"

# AFTER:
source "$SCRIPT_DIR/lib/file_ops.sh"
content=$(sed "s/old/new/" "$FILE")
atomic_write "$content" "$FILE"
```

---

## Phase 2: High Priority - Reduce Duplication

**Priority:** Within 1 week
**Impact:** Maintainability, bug prevention

### 2.1 Create Common Utilities Library

Create `scripts/lib/common.sh`:

```bash
#!/usr/bin/env bash
# Common utilities shared across all scripts

# Source file operations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/file_ops.sh"

#=============================================================================
# Input Validation
#=============================================================================

# Validate that a value is a positive integer
# Usage: validate_numeric "$value" "task number"
validate_numeric() {
    local value="$1"
    local name="${2:-value}"

    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "Error: $name must be a positive integer, got '$value'" >&2
        return 1
    fi
    return 0
}

# Validate that a value is within a range
# Usage: validate_range "$value" 1 100 "spoon count"
validate_range() {
    local value="$1"
    local min="$2"
    local max="$3"
    local name="${4:-value}"

    validate_numeric "$value" "$name" || return 1

    if (( value < min || value > max )); then
        echo "Error: $name must be between $min and $max, got $value" >&2
        return 1
    fi
    return 0
}

# Validate that a file exists
# Usage: validate_file_exists "$path" "config file"
validate_file_exists() {
    local path="$1"
    local name="${2:-file}"

    if [[ ! -f "$path" ]]; then
        echo "Error: $name not found: $path" >&2
        return 1
    fi
    return 0
}

#=============================================================================
# Todo Data Access
#=============================================================================

# Get a task line by number
# Usage: get_todo_line 5
get_todo_line() {
    local task_num="$1"
    local todo_file="${TODO_FILE:-$HOME/.config/dotfiles-data/todo.txt}"

    validate_numeric "$task_num" "task number" || return 1
    validate_file_exists "$todo_file" "todo file" || return 1

    sed -n "${task_num}p" "$todo_file"
}

# Get task text (without metadata) by number
# Usage: get_todo_text 5
get_todo_text() {
    local task_num="$1"
    local line

    line=$(get_todo_line "$task_num") || return 1
    echo "$line" | cut -d'|' -f2-
}

# Get task priority by number
# Usage: get_todo_priority 5
get_todo_priority() {
    local task_num="$1"
    local line

    line=$(get_todo_line "$task_num") || return 1
    echo "$line" | cut -d'|' -f1
}

# Count total tasks
# Usage: count_todos
count_todos() {
    local todo_file="${TODO_FILE:-$HOME/.config/dotfiles-data/todo.txt}"

    if [[ -f "$todo_file" ]]; then
        wc -l < "$todo_file" | tr -d ' '
    else
        echo "0"
    fi
}

#=============================================================================
# Logging
#=============================================================================

SYSTEM_LOG_FILE="${SYSTEM_LOG_FILE:-$HOME/.config/dotfiles-data/system.log}"

# Log a message with timestamp
# Usage: log_message "info" "Script started"
log_message() {
    local level="$1"
    local message="$2"
    local script_name="${3:-$(basename "$0")}"

    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $script_name: $message" >> "$SYSTEM_LOG_FILE"
}

log_info()  { log_message "INFO" "$1" "${2:-}"; }
log_warn()  { log_message "WARN" "$1" "${2:-}"; }
log_error() { log_message "ERROR" "$1" "${2:-}"; }

#=============================================================================
# Library Sourcing Helper
#=============================================================================

# Source a library file with error handling
# Usage: require_lib "date_utils.sh"
require_lib() {
    local lib_name="$1"
    local lib_path="$SCRIPT_DIR/lib/$lib_name"

    if [[ -f "$lib_path" ]]; then
        source "$lib_path"
    else
        echo "Error: Required library not found: $lib_path" >&2
        exit 1
    fi
}
```

### 2.2 Refactor todo.sh to Use Common Library

**Current state:** 455 lines with inline case statement
**Target state:** ~200 lines with extracted functions

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

TODO_FILE="$HOME/.config/dotfiles-data/todo.txt"
DONE_FILE="$HOME/.config/dotfiles-data/todo_done.txt"

#=============================================================================
# Subcommand Functions
#=============================================================================

cmd_add() {
    local priority="${1:-3}"
    local task_text="${*:2}"

    validate_range "$priority" 1 5 "priority" || exit 1

    if [[ -z "$task_text" ]]; then
        echo "Error: Task text required" >&2
        exit 1
    fi

    # Sanitize: escape pipe characters instead of silently removing
    task_text="${task_text//|/\\|}"

    echo "${priority}|${task_text}" >> "$TODO_FILE"
    log_info "Added task: $task_text (priority $priority)"
    echo "Added: $task_text"
}

cmd_done() {
    local task_num="$1"

    validate_numeric "$task_num" "task number" || exit 1

    local task_line
    task_line=$(get_todo_line "$task_num") || exit 1

    # Move to done file with timestamp
    echo "$(date '+%Y-%m-%d %H:%M')|$task_line" >> "$DONE_FILE"
    atomic_delete_line "$task_num" "$TODO_FILE" || exit 1

    log_info "Completed task $task_num"
    echo "Completed: $(get_todo_text "$task_num")"
}

cmd_bump() {
    local task_num="$1"

    validate_numeric "$task_num" "task number" || exit 1

    local task_line
    task_line=$(get_todo_line "$task_num") || exit 1

    atomic_delete_line "$task_num" "$TODO_FILE" || exit 1
    atomic_prepend "$task_line" "$TODO_FILE" || exit 1

    log_info "Bumped task $task_num to top"
    echo "Bumped to top: $(echo "$task_line" | cut -d'|' -f2-)"
}

cmd_list() {
    local filter="${1:-all}"

    if [[ ! -f "$TODO_FILE" ]]; then
        echo "No tasks found."
        return 0
    fi

    local count=0
    while IFS='|' read -r priority task; do
        ((count++))
        printf "%3d. [P%s] %s\n" "$count" "$priority" "$task"
    done < "$TODO_FILE"

    if (( count == 0 )); then
        echo "No tasks found."
    fi
}

# ... additional subcommand functions ...

#=============================================================================
# Main Dispatcher
#=============================================================================

main() {
    local cmd="${1:-list}"
    shift || true

    case "$cmd" in
        add)    cmd_add "$@" ;;
        done)   cmd_done "$@" ;;
        bump)   cmd_bump "$@" ;;
        list)   cmd_list "$@" ;;
        start)  cmd_start "$@" ;;
        stop)   cmd_stop "$@" ;;
        pri)    cmd_priority "$@" ;;
        rm)     cmd_remove "$@" ;;
        edit)   cmd_edit "$@" ;;
        *)
            echo "Unknown command: $cmd" >&2
            echo "Usage: todo.sh {add|done|bump|list|start|stop|pri|rm|edit}" >&2
            exit 1
            ;;
    esac
}

main "$@"
```

### 2.3 Standardize Library Sourcing

Replace all boilerplate library sourcing with:

```bash
# BEFORE (repeated in 9+ scripts):
DATE_UTILS="$SCRIPT_DIR/lib/date_utils.sh"
if [ -f "$DATE_UTILS" ]; then
    source "$DATE_UTILS"
else
    echo "Error: date utilities not found..."
    exit 1
fi

# AFTER:
source "$SCRIPT_DIR/lib/common.sh"
require_lib "date_utils.sh"
```

---

## Phase 3: Configuration Consolidation

**Priority:** Within 2 weeks
**Impact:** Single source of truth, easier maintenance

### 3.1 Create Unified Configuration System

Create `scripts/lib/config.sh`:

```bash
#!/usr/bin/env bash
# Unified configuration management

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
CONFIG_FILE="$CONFIG_DIR/config.sh"
ENV_FILE="$HOME/dotfiles/.env"

# Load environment file
load_env() {
    if [[ -f "$ENV_FILE" ]]; then
        set -a
        source "$ENV_FILE"
        set +a
    fi
}

# Get config value with default
# Usage: config_get "TECH_MODEL" "openrouter/anthropic/claude-3.5-sonnet"
config_get() {
    local key="$1"
    local default="${2:-}"

    # Check environment first, then config file, then default
    local value="${!key:-}"

    if [[ -z "$value" && -f "$CONFIG_FILE" ]]; then
        value=$(grep "^${key}=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2- | tr -d '"'"'")
    fi

    echo "${value:-$default}"
}

#=============================================================================
# Model Configuration
#=============================================================================

# Centralized model defaults - SINGLE SOURCE OF TRUTH
declare -A MODEL_DEFAULTS=(
    [TECH_MODEL]="openrouter/anthropic/claude-3.5-sonnet"
    [STRATEGY_MODEL]="openrouter/anthropic/claude-3.5-sonnet"
    [CREATIVE_MODEL]="openrouter/anthropic/claude-3.5-sonnet"
    [STOIC_MODEL]="openrouter/anthropic/claude-3.5-sonnet"
    [RESEARCH_MODEL]="openrouter/anthropic/claude-3.5-sonnet"
    [FAST_MODEL]="openrouter/anthropic/claude-3-haiku"
)

declare -A TEMPERATURE_DEFAULTS=(
    [TECH]=0.2
    [STRATEGY]=0.4
    [CREATIVE]=0.7
    [STOIC]=0.3
    [RESEARCH]=0.3
    [FAST]=0.2
)

# Get model for a dispatcher type
# Usage: get_model "TECH"
get_model() {
    local type="$1"
    local env_key="${type}_MODEL"
    config_get "$env_key" "${MODEL_DEFAULTS[$env_key]:-}"
}

# Get temperature for a dispatcher type
# Usage: get_temperature "TECH"
get_temperature() {
    local type="$1"
    config_get "${type}_TEMPERATURE" "${TEMPERATURE_DEFAULTS[$type]:-0.3}"
}

#=============================================================================
# Path Configuration
#=============================================================================

# Data directories - SINGLE SOURCE OF TRUTH
DATA_DIR="${XDG_DATA_HOME:-$HOME/.config}/dotfiles-data"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"

# Ensure directories exist
ensure_data_dirs() {
    mkdir -p "$DATA_DIR" "$CACHE_DIR"
}

# Data file paths
TODO_FILE="$DATA_DIR/todo.txt"
DONE_FILE="$DATA_DIR/todo_done.txt"
JOURNAL_FILE="$DATA_DIR/journal.txt"
SPOON_LOG="$DATA_DIR/spoons.txt"
TIME_LOG="$DATA_DIR/time_tracking.txt"
SYSTEM_LOG="$DATA_DIR/system.log"

#=============================================================================
# API Configuration
#=============================================================================

# Cost estimation (per 1M tokens)
API_COST_INPUT="${API_COST_INPUT:-0.50}"
API_COST_OUTPUT="${API_COST_OUTPUT:-1.50}"

# Rate limiting
API_COOLDOWN_SECONDS="${API_COOLDOWN_SECONDS:-2}"

# Initialize configuration
load_env
ensure_data_dirs
```

### 3.2 Update .env Structure

Simplify `.env` to only contain overrides:

```bash
# .env - Configuration overrides
# Only set values that differ from defaults in lib/config.sh

# API Keys (required)
OPENROUTER_API_KEY="your-key-here"

# Model overrides (optional - defaults in lib/config.sh)
# TECH_MODEL="openrouter/anthropic/claude-3.5-sonnet"
# STRATEGY_MODEL="openrouter/anthropic/claude-3.5-sonnet"

# Temperature overrides (optional)
# TECH_TEMPERATURE=0.2

# Path overrides (optional)
# DATA_DIR="$HOME/.config/dotfiles-data"
```

### 3.3 Update All Dispatchers

Replace hardcoded model references:

```bash
# BEFORE (in dhp-tech.sh):
MODEL="${MODEL:-openrouter/anthropic/claude-3.5-sonnet}"
TEMPERATURE="0.2"

# AFTER:
source "$SCRIPT_DIR/../scripts/lib/config.sh"
MODEL=$(get_model "TECH")
TEMPERATURE=$(get_temperature "TECH")
```

---

## Phase 4: Refactor Complex Scripts

**Priority:** Within 1 month
**Impact:** Readability, maintainability

### 4.1 Refactor blog.sh

**Current:** 1,204 lines monolithic
**Target:** ~400 lines main + library modules

Split into:
1. `scripts/blog.sh` - Main dispatcher (~200 lines)
2. `scripts/lib/blog_config.sh` - Section mappings, exemplars (~100 lines)
3. `scripts/lib/blog_lifecycle.sh` - Already exists, enhance
4. `scripts/lib/blog_generation.sh` - Content generation logic (~200 lines)

**Move hardcoded exemplars to config file:**

Create `~/.config/dotfiles/blog_exemplars.yaml`:
```yaml
exemplars:
  guides/ai-frameworks: content/guides/ai-frameworks/advanced-prompting.md
  guides/brain-fog: content/guides/brain-fog/daily-briefing.md
  # ... etc
```

### 4.2 Refactor health.sh

**Current:** 585 lines with mixed concerns
**Target:** ~200 lines main + library

Split into:
1. `scripts/health.sh` - Main interface
2. `scripts/lib/health_cache.sh` - Cache management
3. `scripts/lib/health_correlation.sh` - Correlation logic

**Simplify the complex awk one-liner (lines 52-86):**

```bash
# BEFORE: 30-line awk script inline

# AFTER: Extract to function with clear logic
correlate_energy_tasks() {
    local energy_log="$1"
    local tasks_file="$2"

    # Use Python for complex data manipulation
    python3 << 'EOF' "$energy_log" "$tasks_file"
import sys
import csv
# ... clear, maintainable logic
EOF
}
```

### 4.3 Standardize Subcommand Pattern

Adopt consistent pattern across all multi-command scripts:

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# 2. Subcommand functions (one per command)
cmd_foo() { ... }
cmd_bar() { ... }

# 3. Help text
show_help() {
    cat << 'EOF'
Usage: script.sh <command> [args]

Commands:
    foo    Description of foo
    bar    Description of bar
EOF
}

# 4. Main dispatcher
main() {
    case "${1:-}" in
        foo)  shift; cmd_foo "$@" ;;
        bar)  shift; cmd_bar "$@" ;;
        -h|--help|help) show_help ;;
        "") show_help; exit 1 ;;
        *) echo "Unknown command: $1" >&2; exit 1 ;;
    esac
}

main "$@"
```

---

## Phase 5: Remove Orphaned Code

**Priority:** Within 1 month
**Impact:** Reduced confusion, smaller codebase

### 5.1 Verify and Remove Unused Scripts

**Scripts to verify usage:**

| Script | Status | Action |
|--------|--------|--------|
| `app_launcher.sh` | No references found | Verify with user, then delete |
| `battery_check.sh` | Only in dotfiles_check | Move to lib/ or integrate |
| `cheatsheet.sh` | Hardcoded content | Convert to config file or delete |
| `dhp-config.sh` | Appears empty/unused | Verify, then delete or implement |

**Verification command:**
```bash
# Find all references to a script
grep -r "script_name" ~/dotfiles --include="*.sh" --include="*.zsh"
```

### 5.2 Remove or Implement Stub Commands

**Option A: Remove stubs**
```bash
# In correlate.sh, remove:
find-patterns) echo "Not Implemented" ;;
explain) echo "Coming Soon" ;;
```

**Option B: Implement or document roadmap**
Create `docs/ROADMAP.md` with planned features and timelines.

### 5.3 Consolidate Overlapping Scripts

| Scripts | Resolution |
|---------|------------|
| `whatis.sh` + `howto.sh` | Merge into single `help.sh` |
| `done.sh` + `todo.sh done` | Keep only `todo.sh done`, alias `done` to it |
| `dump.sh` + `journal.sh` | Clarify purposes or merge |

### 5.4 Update Outdated Comments

```bash
# Find TODO/FIXME comments
grep -rn "TODO\|FIXME\|XXX\|HACK" ~/dotfiles/scripts

# Find "coming soon" type comments
grep -rn -i "coming soon\|phase [0-9]\|not implemented" ~/dotfiles/scripts
```

Update or remove based on current state.

---

## Phase 6: Standardize Error Handling

**Priority:** Within 1 month
**Impact:** Reliability, debugging

### 6.1 Create Error Handling Standards

Add to `lib/common.sh`:

```bash
#=============================================================================
# Error Handling
#=============================================================================

# Standard error exit
# Usage: die "Error message"
die() {
    log_error "$1"
    echo "Error: $1" >&2
    exit "${2:-1}"
}

# Check command exists
# Usage: require_cmd "jq" "brew install jq"
require_cmd() {
    local cmd="$1"
    local install_hint="${2:-}"

    if ! command -v "$cmd" &>/dev/null; then
        local msg="Required command not found: $cmd"
        [[ -n "$install_hint" ]] && msg+=". Install with: $install_hint"
        die "$msg"
    fi
}

# Check file exists or die
# Usage: require_file "$config_path" "config file"
require_file() {
    local path="$1"
    local name="${2:-file}"

    [[ -f "$path" ]] || die "$name not found: $path"
}
```

### 6.2 Standardize Error Message Format

```bash
# Consistent format across all scripts:
echo "Error: <what failed> - <why/context>" >&2

# Examples:
echo "Error: Task 5 not found - todo.txt only has 3 tasks" >&2
echo "Error: API call failed - rate limit exceeded, retry in 60s" >&2
echo "Error: Config file invalid - missing required key OPENROUTER_API_KEY" >&2
```

### 6.3 Add Consistent Exit Codes

```bash
# Exit code standards:
# 0 - Success
# 1 - General error
# 2 - Invalid arguments
# 3 - File not found
# 4 - Permission denied
# 5 - External service error (API, network)
# 10+ - Script-specific errors

# Add to lib/common.sh:
EXIT_SUCCESS=0
EXIT_ERROR=1
EXIT_INVALID_ARGS=2
EXIT_FILE_NOT_FOUND=3
EXIT_PERMISSION=4
EXIT_SERVICE_ERROR=5
```

---

## Phase 7: Add Logging Infrastructure

**Priority:** Within 6 weeks
**Impact:** Debugging, audit trail

### 7.1 Implement Log Rotation

Add to `lib/common.sh`:

```bash
# Rotate log if over size limit
rotate_log() {
    local log_file="${1:-$SYSTEM_LOG_FILE}"
    local max_size="${2:-10485760}"  # 10MB default

    if [[ -f "$log_file" ]]; then
        local size
        size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0)

        if (( size > max_size )); then
            mv "$log_file" "${log_file}.$(date +%Y%m%d_%H%M%S)"
            # Keep only last 5 rotated logs
            ls -t "${log_file}".* 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null
        fi
    fi
}
```

### 7.2 Add Logging to All Scripts

Ensure consistent logging:

```bash
# At script start:
log_info "Starting $(basename "$0") with args: $*"

# At script end:
log_info "Completed successfully"

# On error:
log_error "Failed: $error_message"
```

### 7.3 Create Log Viewer

Create `scripts/logs.sh`:

```bash
#!/usr/bin/env bash
# View and search dotfiles logs

source "$SCRIPT_DIR/lib/common.sh"

case "${1:-tail}" in
    tail)   tail -f "$SYSTEM_LOG_FILE" ;;
    today)  grep "$(date +%Y-%m-%d)" "$SYSTEM_LOG_FILE" ;;
    errors) grep "\[ERROR\]" "$SYSTEM_LOG_FILE" ;;
    search) grep -i "${2:-}" "$SYSTEM_LOG_FILE" ;;
    *)      echo "Usage: logs.sh {tail|today|errors|search <term>}" ;;
esac
```

---

## Phase 8: Security Hardening

**Priority:** Within 6 weeks
**Impact:** Data integrity, safety

### 8.1 Input Sanitization

Add to `lib/common.sh`:

```bash
# Sanitize user input for safe use in files
# Usage: sanitized=$(sanitize_input "$user_input")
sanitize_input() {
    local input="$1"
    # Escape pipe characters (field delimiter)
    input="${input//|/\\|}"
    # Remove control characters except newline/tab
    input=$(echo "$input" | tr -d '\000-\010\013\014\016-\037')
    echo "$input"
}

# Validate path is safe (no traversal)
# Usage: validate_safe_path "$path" "$allowed_base"
validate_safe_path() {
    local path="$1"
    local allowed_base="$2"

    # Resolve to absolute path
    local resolved
    resolved=$(realpath -m "$path" 2>/dev/null) || {
        echo "Error: Invalid path: $path" >&2
        return 1
    }

    # Check it's under allowed base
    if [[ "$resolved" != "$allowed_base"* ]]; then
        echo "Error: Path outside allowed directory: $path" >&2
        return 1
    fi

    echo "$resolved"
}
```

### 8.2 Sensitive File Protection

```bash
# Never commit these files
# Add to .gitignore if not present:
.env
*.key
*credentials*
*secret*
```

### 8.3 Temp File Security

```bash
# Always use mktemp with restrictive permissions
create_temp_file() {
    local prefix="${1:-dotfiles}"
    local temp_file
    temp_file=$(mktemp -t "${prefix}.XXXXXX") || die "Failed to create temp file"
    chmod 600 "$temp_file"
    echo "$temp_file"
}
```

---

## Implementation Checklist

### Phase 1: Critical (Week 1) - COMPLETED
- [x] Create `scripts/lib/file_ops.sh` - atomic_write, atomic_prepend, atomic_delete_line, atomic_replace_line
- [x] Fix `todo.sh` data loss risks - now uses atomic operations throughout
- [x] Add cleanup traps to `todo.sh`, `health.sh`, `journal.sh`
- [x] Replace `sed -i.bak` patterns with atomic operations

### Phase 2: High Priority (Week 2) - COMPLETED
- [x] Create `scripts/lib/common.sh` with validation, logging, error handling, security
- [x] Refactor `todo.sh` to use common library
- [x] Update scripts to use `require_lib()` - journal.sh, health.sh, correlate.sh

### Phase 3: Configuration (Week 3) - COMPLETED
- [x] Create `scripts/lib/config.sh` with centralized model/path configuration
- [x] Define MODEL_DEFAULTS, TEMPERATURE_DEFAULTS, OUTPUT_DIRS
- [x] Add helper functions: get_model(), get_temperature(), get_output_dir()

### Phase 4: Refactoring (Weeks 4-5) - COMPLETED
- [x] Refactor `health.sh` - added export feature, uses common library
- [x] Refactor `todo.sh` - extracted subcommands to functions
- [x] Update `spoon_manager.sh` and `spoon_budget.sh` to use common library
- [x] Update `correlate.sh` to use common validation

### Phase 5: Cleanup (Week 5) - COMPLETED
- [x] Verified scripts: app_launcher.sh (used), done.sh (used as 'did'), dhp-config.sh (has squad function)
- [x] Confirmed whatis.sh and howto.sh serve different purposes (lookup vs wiki)
- [x] Updated stub implementations with clearer messages

### Phase 6: Error Handling (Week 6) - COMPLETED
- [x] Added error handling utilities to `lib/common.sh`: die(), require_cmd(), require_file(), require_dir()
- [x] Added exit code constants: EXIT_SUCCESS, EXIT_ERROR, EXIT_INVALID_ARGS, etc.
- [x] Standardized error message format across updated scripts

### Phase 7: Logging (Weeks 6-7) - COMPLETED
- [x] Implemented log rotation in common.sh: rotate_log()
- [x] Created `logs.sh` utility with: tail, today, errors, search, stats, rotate, clean
- [x] Added logging aliases to aliases.zsh

### Phase 8: Security (Week 7) - COMPLETED
- [x] Added sanitize_input() - escapes pipe characters, removes control chars
- [x] Added validate_safe_path() - prevents path traversal
- [x] Added create_temp_file() - creates temp files with restrictive permissions
- [x] Updated dhp-utils.sh to integrate with common library

---

## Success Metrics

After completing all phases:

1. **Zero data loss scenarios** - All file operations are atomic
2. **Single source of truth** - Configuration in one place
3. **< 300 lines per script** - Complex scripts broken into modules
4. **Consistent patterns** - All scripts follow same structure
5. **Comprehensive logging** - All operations logged with rotation
6. **No orphaned code** - All code is referenced and functional
7. **Clear error messages** - Users understand what went wrong

---

## Maintenance Guidelines

Going forward:

1. **Before adding new scripts:**
   - Source `lib/common.sh`
   - Follow subcommand pattern template
   - Add logging
   - Use atomic file operations

2. **Before modifying existing scripts:**
   - Check if related library exists
   - Update library if adding reusable code
   - Maintain consistent style

3. **Quarterly review:**
   - Check for new orphaned code
   - Verify all stubs implemented or removed
   - Review log rotation is working
   - Update configuration defaults as needed
