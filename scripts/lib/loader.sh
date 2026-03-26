#!/usr/bin/env bash
# scripts/lib/loader.sh - Central library loader
# NOTE: SOURCED file. Do NOT use set -euo pipefail.
#
# Use this loader only for coaching-heavy composite scripts that need the full
# daily stack preloaded (currently startday.sh, status.sh, and goodevening.sh).
# Most scripts should source common.sh and then only the specific libraries
# they need.

if [[ -n "${_LOADER_LOADED:-}" ]]; then
    return 0
fi
readonly _LOADER_LOADED=true

_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_load_lib() {
    local lib="$1"
    local required="${2:-true}"
    if [ -f "$_LOADER_DIR/$lib" ]; then
        # shellcheck disable=SC1090
        source "$_LOADER_DIR/$lib"
    elif [ "$required" = "true" ]; then
        echo "Error: Required library $lib not found at $_LOADER_DIR/$lib" >&2
        return 1
    fi
}

# 1. Base utilities
_load_lib "common.sh"
_load_lib "config.sh"
_load_lib "date_utils.sh"

# 2. Domain operations
_load_lib "github_ops.sh" "false"
_load_lib "health_ops.sh" "false"
_load_lib "time_tracking.sh" "false"
_load_lib "spoon_budget.sh" "false"

# 3. Coaching architecture
_load_lib "coach_ops.sh"
_load_lib "coach_metrics.sh"
_load_lib "coach_prompts.sh"
_load_lib "coach_scoring.sh"
_load_lib "coaching.sh"
_load_lib "coach_chat.sh" "false"

return 0
