#!/usr/bin/env bash
# scripts/lib/coach_ops.sh
# Behavioral coaching metrics and persistence helpers.
# NOTE: SOURCED file. Do NOT use set -euo pipefail.
#
# This file validates core coaching runtime dependencies only.
# Per library contract, callers must source sibling modules explicitly:
#   - coach_metrics.sh
#   - coach_prompts.sh
#   - coach_scoring.sh

if [[ -n "${_COACH_OPS_LOADED:-}" ]]; then
    return 0
fi

# Dependencies:
# - DATA_DIR and coach-related config values from config.sh.
# - date helpers from date_utils.sh (date_shift_from, timestamp_to_epoch).
# - optional helpers from common.sh (sanitize_input, validate_path).
if [[ -z "${DATA_DIR:-}" ]]; then
    echo "Error: DATA_DIR is not set. Source scripts/lib/config.sh before coach_ops.sh." >&2
    return 1
fi
if [[ -z "${TODO_FILE:-}" || -z "${DONE_FILE:-}" || -z "${JOURNAL_FILE:-}" || -z "${HEALTH_FILE:-}" || -z "${SPOON_LOG:-}" || -z "${DIR_USAGE_LOG:-}" || -z "${FOCUS_HISTORY_FILE:-}" || -z "${DISPATCHER_USAGE_LOG:-}" || -z "${COACH_MODE_FILE:-}" || -z "${COACH_LOG_FILE:-}" ]]; then
    echo "Error: Coach paths are not fully configured. Source scripts/lib/config.sh before coach_ops.sh." >&2
    return 1
fi
if ! command -v date_shift_from >/dev/null 2>&1 || ! command -v timestamp_to_epoch >/dev/null 2>&1; then
    echo "Error: date_shift_from/timestamp_to_epoch are not available. Source scripts/lib/date_utils.sh before coach_ops.sh." >&2
    return 1
fi

readonly _COACH_OPS_LOADED=true
