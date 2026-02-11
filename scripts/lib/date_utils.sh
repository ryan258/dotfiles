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

# Shift an anchor date by <offset> days and format with <format>.
# Usage: date_shift_from <YYYY-MM-DD> <offset> [format]
date_shift_from() {
    local anchor="${1:-}"
    local offset="${2:-0}"
    local format="${3:-%Y-%m-%d}"
    local anchor_format=""

    if [[ -z "$anchor" ]]; then
        echo "Error: date_shift_from requires an anchor date." >&2
        return 1
    fi
    if [[ "$offset" == +* ]]; then
        offset="${offset#+}"
    fi

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$anchor" "$offset" "$format" <<'PY'
import sys
from datetime import datetime, timedelta

anchor = sys.argv[1]
offset = int(sys.argv[2])
fmt = sys.argv[3]

for pattern in ("%Y-%m-%d", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M"):
    try:
        dt = datetime.strptime(anchor, pattern)
        break
    except ValueError:
        continue
else:
    print("Error: invalid anchor date for date_shift_from", file=sys.stderr)
    sys.exit(1)

shifted = dt + timedelta(days=offset)
if fmt == "%s":
    print(int(shifted.timestamp()))
else:
    print(shifted.strftime(fmt))
PY
        return
    fi

    if [[ "$anchor" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        anchor_format="%Y-%m-%d"
    elif [[ "$anchor" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
        anchor_format="%Y-%m-%d %H:%M:%S"
    elif [[ "$anchor" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}$ ]]; then
        anchor_format="%Y-%m-%d %H:%M"
    fi

    # Fallback to macOS BSD date if available.
    if [[ -n "$anchor_format" ]] && date -j -f "$anchor_format" "$anchor" "+%Y-%m-%d" >/dev/null 2>&1; then
        local suffix
        if [[ "$offset" == -* ]]; then
            suffix="${offset#-}"
            date -j -f "$anchor_format" "$anchor" -v-"${suffix}"d +"$format"
        else
            date -j -f "$anchor_format" "$anchor" -v+"${offset}"d +"$format"
        fi
        return
    fi

    # Final fallback: GNU date.
    if command -v gdate >/dev/null 2>&1; then
        gdate --date="$anchor $offset day" +"$format"
    else
        date --date="$anchor $offset day" +"$format"
    fi
}

# Get file mtime as epoch seconds with cross-platform fallbacks.
# Usage: file_mtime_epoch <path>
file_mtime_epoch() {
    local target_file="$1"

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$target_file" <<'PY'
import os
import sys

try:
    print(int(os.path.getmtime(sys.argv[1])))
except OSError:
    print(0)
PY
        return
    fi

    if stat -f '%m' "$target_file" >/dev/null 2>&1; then
        stat -f '%m' "$target_file"
    elif stat -c '%Y' "$target_file" >/dev/null 2>&1; then
        stat -c '%Y' "$target_file"
    else
        echo "0"
    fi
}

timestamp_to_epoch() {
    local raw="$1"

    if command -v python3 >/dev/null 2>&1; then
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
        return
    fi

    if date -j -f "%Y-%m-%d" "1970-01-01" "+%s" >/dev/null 2>&1; then
        local fmt
        local epoch=""
        for fmt in "%Y-%m-%d %H:%M:%S" "%Y-%m-%d %H:%M" "%Y-%m-%d %H" "%Y-%m-%d"; do
            epoch=$(date -j -f "$fmt" "$raw" "+%s" 2>/dev/null || true)
            if [[ -n "$epoch" && "$epoch" =~ ^-?[0-9]+$ ]]; then
                printf '%s\n' "$epoch"
                return
            fi
        done
        echo "0"
        return
    fi

    local epoch=""
    if command -v gdate >/dev/null 2>&1; then
        epoch=$(gdate -d "$raw" "+%s" 2>/dev/null || true)
    else
        epoch=$(date -d "$raw" "+%s" 2>/dev/null || true)
    fi

    if [[ -n "$epoch" && "$epoch" =~ ^-?[0-9]+$ ]]; then
        printf '%s\n' "$epoch"
    else
        echo "0"
    fi
}
