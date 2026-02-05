#!/usr/bin/env bash
# Common utilities shared across all scripts
# Provides: validation, logging, data access, error handling, security

if [ -n "${COMMON_SH_LOADED:-}" ]; then
    return 0
fi
readonly COMMON_SH_LOADED=true

#=============================================================================
# Script Directory Resolution
#=============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Handle case where script is in lib/ or root
if [[ ! -f "$SCRIPT_DIR/lib/file_ops.sh" ]]; then
    # Try one level up if we are in lib
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [[ -f "$SCRIPT_DIR/lib/file_ops.sh" ]]; then
    source "$SCRIPT_DIR/lib/file_ops.sh"
elif [[ -f "$SCRIPT_DIR/../lib/file_ops.sh" ]]; then
    source "$SCRIPT_DIR/../lib/file_ops.sh"
fi

if [[ -f "$SCRIPT_DIR/lib/config.sh" ]]; then
    source "$SCRIPT_DIR/lib/config.sh"
elif [[ -f "$SCRIPT_DIR/../lib/config.sh" ]]; then
    source "$SCRIPT_DIR/../lib/config.sh"
fi

#=============================================================================
# Exit Code Constants
#=============================================================================

readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_INVALID_ARGS=2
readonly EXIT_FILE_NOT_FOUND=3
readonly EXIT_PERMISSION=4
readonly EXIT_SERVICE_ERROR=5

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
    local data_dir="${DATA_DIR:-$HOME/.config/dotfiles-data}"
    local todo_file="${TODO_FILE:-$data_dir/todo.txt}"

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
    local data_dir="${DATA_DIR:-$HOME/.config/dotfiles-data}"
    local todo_file="${TODO_FILE:-$data_dir/todo.txt}"

    if [[ -f "$todo_file" ]]; then
        wc -l < "$todo_file" | tr -d ' '
    else
        echo "0"
    fi
}

#=============================================================================
# Logging
#=============================================================================

SYSTEM_LOG_FILE="${SYSTEM_LOG_FILE:-${SYSTEM_LOG:-$HOME/.config/dotfiles-data/system.log}}"

# Log a message with timestamp
# Usage: log_message "info" "Script started"
log_message() {
    local level="$1"
    local message="$2"
    local script_name="${3:-$(basename "$0")}"
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$SYSTEM_LOG_FILE")"

    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $script_name: $message" >> "$SYSTEM_LOG_FILE"
}

log_info()  { log_message "INFO" "$1" "${2:-}"; }
log_warn()  { log_message "WARN" "$1" "${2:-}"; }
log_error() { log_message "ERROR" "$1" "${2:-}"; }

#=============================================================================
# Error Handling
#=============================================================================

# Check if script is being sourced or executed
is_sourced() {
    [[ "${BASH_SOURCE[0]}" != "${0}" ]]
}

# Standard error exit with logging
# Usage: die "Error message" [exit_code]
die() {
    local message="$1"
    local exit_code="${2:-$EXIT_ERROR}"

    log_error "$message"
    echo "Error: $message" >&2
    
    if is_sourced; then
        return "$exit_code"
    fi
    exit "$exit_code"
}

# Check command exists
# Usage: require_cmd "jq" "brew install jq"
require_cmd() {
    local cmd="$1"
    local install_hint="${2:-}"

    if ! command -v "$cmd" &>/dev/null; then
        local msg="Required command not found: $cmd"
        [[ -n "$install_hint" ]] && msg+=". Install with: $install_hint"
        die "$msg" "$EXIT_FILE_NOT_FOUND"
    fi
}

# Check file exists or die
# Usage: require_file "$config_path" "config file"
require_file() {
    local path="$1"
    local name="${2:-file}"

    [[ -f "$path" ]] || die "$name not found: $path" "$EXIT_FILE_NOT_FOUND"
}

# Check directory exists or die
# Usage: require_dir "$data_dir" "data directory"
require_dir() {
    local path="$1"
    local name="${2:-directory}"

    [[ -d "$path" ]] || die "$name not found: $path" "$EXIT_FILE_NOT_FOUND"
}

#=============================================================================
# Log Rotation
#=============================================================================

# Rotate log if over size limit
# Usage: rotate_log [log_file] [max_size_bytes]
rotate_log() {
    local log_file="${1:-$SYSTEM_LOG_FILE}"
    local max_size="${2:-10485760}"  # 10MB default

    if [[ -f "$log_file" ]]; then
        local size
        # macOS vs Linux stat compatibility
        if stat -f%z "$log_file" >/dev/null 2>&1; then
            size=$(stat -f%z "$log_file")
        else
            size=$(stat -c%s "$log_file" 2>/dev/null || echo 0)
        fi

        if (( size > max_size )); then
            mv "$log_file" "${log_file}.$(date +%Y%m%d_%H%M%S)"
            # Keep only last 5 rotated logs
            ls -t "${log_file}".* 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
            log_info "Log rotated: $log_file"
        fi
    fi
}

#=============================================================================
# Security Utilities
#=============================================================================

# Sanitize user input for safe use in files
# Usage: sanitized=$(sanitize_input "$user_input")
sanitize_input() {
    local input="$1"
    # Escape pipe characters (our field delimiter)
    input="${input//|/\\|}"
    # Remove control characters except newline and tab
    input=$(printf '%s' "$input" | tr -d '\000-\010\013\014\016-\037')
    printf '%s' "$input"
}

# Validate path is safe (no traversal, within allowed base)
# Usage: validated_path=$(validate_safe_path "$path" "$allowed_base")
validate_safe_path() {
    local path="$1"
    local allowed_base="$2"

    # Resolve to absolute path using python for portability (macOS/Linux)
    local resolved
    if command -v python3 &>/dev/null; then
        resolved=$(python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "$path" 2>/dev/null)
    elif command -v python &>/dev/null; then
        resolved=$(python -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "$path" 2>/dev/null)
    fi

    if [[ -z "$resolved" ]]; then
        # Fallback to simple shell resolution if python failed/missing
        if [[ -d "$path" ]]; then
            resolved=$(cd "$path" && pwd -P)
        else
            echo "Error: Invalid path: $path" >&2
            return 1
        fi
    fi

    # Check it's under allowed base
    # Resolve base too
    local resolved_base
    if command -v python3 &>/dev/null; then
        resolved_base=$(python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "$allowed_base" 2>/dev/null)
    elif command -v python &>/dev/null; then
        resolved_base=$(python -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "$allowed_base" 2>/dev/null)
    fi

    # Debug
    # Debug
    # echo "DEBUG: path=$path resolved=$resolved base=$allowed_base resolved_base=$resolved_base" >&2

    if [[ "$resolved" != "$resolved_base"* ]]; then
        echo "Error: Path outside allowed directory: $path" >&2
        return 1
    fi

    printf '%s' "$resolved"
}

# Create temp file with restrictive permissions
# Usage: temp_file=$(create_temp_file "prefix")
create_temp_file() {
    local prefix="${1:-dotfiles}"
    local temp_file
    temp_file=$(mktemp -t "${prefix}.XXXXXX") || die "Failed to create temp file"
    chmod 600 "$temp_file"
    printf '%s' "$temp_file"
}

#=============================================================================
# Library Sourcing Helper
#=============================================================================

# Source a library file with error handling
# Usage: require_lib "date_utils.sh"
require_lib() {
    local lib_name="$1"

    # Try relative to current script first
    local lib_path="$SCRIPT_DIR/lib/$lib_name"

    if [[ ! -f "$lib_path" ]]; then
        # Try relative to common.sh location
        lib_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$lib_name"
    fi

    if [[ -f "$lib_path" ]]; then
        source "$lib_path"
    else
        die "Required library not found: $lib_name" "$EXIT_FILE_NOT_FOUND"
    fi
}

#=============================================================================
# Path Validation
#=============================================================================

# Validate and canonicalize a path, ensuring it's within user's home directory
# Usage: validated=$(validate_path "$path")
# Returns: 0 on success (prints canonicalized path), 1 on failure (prints error)
validate_path() {
    local input_path="$1"
    if [[ -z "$input_path" ]]; then
        echo "Error: validate_path requires a path argument." >&2
        return 1
    fi

    # Reuse validate_safe_path which handles realpath resolution and base checking
    if ! validate_safe_path "$input_path" "$HOME"; then
        return 1
    fi
}
