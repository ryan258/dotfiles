#!/usr/bin/env bash
# Cross-platform date helpers for shell scripts.
# Provides fallback implementations so we avoid direct reliance on BSD-only `date -v`.
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_DATE_UTILS_LOADED:-}" ]]; then
    return 0
fi
readonly _DATE_UTILS_LOADED=true

_dotfiles_date_python_shift() {
    local offset="$1"
    local format="$2"

    python3 - "$offset" "$format" <<'PY'
import sys
from datetime import datetime, timedelta

offset = float(sys.argv[1])
fmt = sys.argv[2]
dt = datetime.now() + timedelta(days=offset)
if fmt == "%s":
    print(int(dt.timestamp()))
else:
    print(dt.strftime(fmt))
PY
}

# Shift the current date by <offset> days and format with <format>.
# Usage: date_shift_days <offset> [format]
date_shift_days() {
    local offset="${1:-0}"
    local format="${2:-%Y-%m-%d}"

    if command -v python3 >/dev/null 2>&1; then
        _dotfiles_date_python_shift "$offset" "$format"
        return
    fi

    # Fallback to macOS BSD date if available.
    if date -v0d >/dev/null 2>&1; then
        local suffix
        if [[ "$offset" == -* ]]; then
            suffix="${offset#-}"
            date -v-"${suffix}"d +"$format"
        else
            date -v+"${offset}"d +"$format"
        fi
        return
    fi

    # Final fallback: GNU date.
    if command -v gdate >/dev/null 2>&1; then
        gdate --date="${offset} day" +"$format"
    else
        date --date="${offset} day" +"$format"
    fi
}

# Convenience wrapper for "n days ago".
date_days_ago() {
    local days="${1:-0}"
    local format="${2:-%Y-%m-%d}"
    date_shift_days "-$days" "$format"
}

timestamp_to_epoch() {
    local raw="$1"
    python3 - "$raw" <<'PY'
import sys
from datetime import datetime

value = sys.argv[1]
formats = ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d %H", "%Y-%m-%d")
for fmt in formats:
    try:
        print(int(datetime.strptime(value, fmt).timestamp()))
        break
    except ValueError:
        continue
else:
    print(0)
PY
}
