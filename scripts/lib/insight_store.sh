#!/usr/bin/env bash
# scripts/lib/insight_store.sh - Data store helpers for falsification-first insight workflow
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_INSIGHT_STORE_LOADED:-}" ]]; then
    return 0
fi
readonly _INSIGHT_STORE_LOADED=true

# Dependencies:
# - DATA_DIR/INSIGHT_* paths from config.sh.
# - sanitize_for_storage from common.sh.
# - atomic_replace_line from file_ops.sh (via common.sh in callers).
if [[ -z "${DATA_DIR:-}" ]]; then
    echo "Error: DATA_DIR is not set. Source scripts/lib/config.sh before insight_store.sh." >&2
    return 1
fi
if ! command -v sanitize_for_storage >/dev/null 2>&1; then
    echo "Error: sanitize_for_storage is not available. Source scripts/lib/common.sh before insight_store.sh." >&2
    return 1
fi
if ! command -v atomic_replace_line >/dev/null 2>&1; then
    echo "Error: atomic_replace_line is not available. Source scripts/lib/file_ops.sh/common.sh before insight_store.sh." >&2
    return 1
fi

INSIGHT_HYPOTHESES_FILE="${INSIGHT_HYPOTHESES_FILE:-}"
INSIGHT_TESTS_FILE="${INSIGHT_TESTS_FILE:-}"
INSIGHT_EVIDENCE_FILE="${INSIGHT_EVIDENCE_FILE:-}"
INSIGHT_VERDICTS_FILE="${INSIGHT_VERDICTS_FILE:-}"
if [[ -z "$INSIGHT_HYPOTHESES_FILE" || -z "$INSIGHT_TESTS_FILE" || -z "$INSIGHT_EVIDENCE_FILE" || -z "$INSIGHT_VERDICTS_FILE" ]]; then
    echo "Error: Insight data file paths are not set. Source scripts/lib/config.sh before insight_store.sh." >&2
    return 1
fi

# Normalize user text for pipe-delimited storage
# Usage: normalize_insight_field "raw text"
normalize_insight_field() {
    local raw="${1:-}"
    sanitize_for_storage "$raw"
}

# Ensure insight storage files exist
# Usage: ensure_insight_data_files
ensure_insight_data_files() {
    mkdir -p "$DATA_DIR" || {
        echo "Error: Failed to create data directory: $DATA_DIR" >&2
        return 1
    }

    touch "$INSIGHT_HYPOTHESES_FILE" "$INSIGHT_TESTS_FILE" "$INSIGHT_EVIDENCE_FILE" "$INSIGHT_VERDICTS_FILE" || {
        echo "Error: Failed to initialize insight data files" >&2
        return 1
    }

    return 0
}

# Generate next ID for a given file and prefix
# Usage: _insight_next_id "HYP" "/path/to/file"
_insight_next_id() {
    local prefix="$1"
    local file="$2"
    local today
    local highest=0

    today="$(date +%Y%m%d)"

    if [[ -f "$file" && -s "$file" ]]; then
        while IFS='|' read -r record_id _; do
            [[ "$record_id" == "$prefix-$today-"* ]] || continue
            local seq="${record_id##*-}"
            if [[ "$seq" =~ ^[0-9]+$ ]]; then
                local seq_num=$((10#$seq))
                if (( seq_num > highest )); then
                    highest="$seq_num"
                fi
            fi
        done < "$file"
    fi

    printf '%s-%s-%03d' "$prefix" "$today" "$((highest + 1))"
}

# Usage: insight_next_hypothesis_id
insight_next_hypothesis_id() {
    _insight_next_id "HYP" "$INSIGHT_HYPOTHESES_FILE"
}

# Usage: insight_next_test_id
insight_next_test_id() {
    _insight_next_id "TST" "$INSIGHT_TESTS_FILE"
}

# Usage: insight_next_evidence_id
insight_next_evidence_id() {
    _insight_next_id "EVD" "$INSIGHT_EVIDENCE_FILE"
}

# Append a line to a data file
# Usage: insight_append_record "/path/to/file" "line"
insight_append_record() {
    local file="$1"
    local line="$2"

    printf '%s\n' "$line" >> "$file"
}

# Find record by ID (must be first field)
# Usage: insight_find_record_line "/path/to/file" "ID"
insight_find_record_line() {
    local file="$1"
    local record_id="$2"

    [[ -f "$file" ]] || return 1

    awk -F'|' -v id="$record_id" '$1 == id { print $0; found=1; exit 0 } END { if (!found) exit 1 }' "$file"
}

# Find record with line number
# Usage: insight_find_record_with_line_number "/path/to/file" "ID"
insight_find_record_with_line_number() {
    local file="$1"
    local record_id="$2"

    [[ -f "$file" ]] || return 1

    awk -F'|' -v id="$record_id" '$1 == id { print NR "|" $0; found=1; exit 0 } END { if (!found) exit 1 }' "$file"
}

# Replace a record by ID (must be first field)
# Usage: insight_replace_record_line "/path/to/file" "ID" "new|record|line"
insight_replace_record_line() {
    local file="$1"
    local record_id="$2"
    local new_line="$3"
    local record
    local line_num

    record=$(insight_find_record_with_line_number "$file" "$record_id") || return 1
    line_num="${record%%|*}"

    atomic_replace_line "$line_num" "$new_line" "$file"
}

# Hypothesis-specific helpers
insight_get_hypothesis() {
    local hypothesis_id="$1"
    insight_find_record_line "$INSIGHT_HYPOTHESES_FILE" "$hypothesis_id"
}

insight_get_hypothesis_with_line_number() {
    local hypothesis_id="$1"
    insight_find_record_with_line_number "$INSIGHT_HYPOTHESES_FILE" "$hypothesis_id"
}

insight_append_hypothesis() {
    local line="$1"
    insight_append_record "$INSIGHT_HYPOTHESES_FILE" "$line"
}

insight_replace_hypothesis() {
    local hypothesis_id="$1"
    local new_line="$2"
    insight_replace_record_line "$INSIGHT_HYPOTHESES_FILE" "$hypothesis_id" "$new_line"
}

# Test-specific helpers
insight_get_test() {
    local test_id="$1"
    insight_find_record_line "$INSIGHT_TESTS_FILE" "$test_id"
}

insight_append_test() {
    local line="$1"
    insight_append_record "$INSIGHT_TESTS_FILE" "$line"
}

insight_replace_test() {
    local test_id="$1"
    local new_line="$2"
    insight_replace_record_line "$INSIGHT_TESTS_FILE" "$test_id" "$new_line"
}

# Evidence/Verdict appenders
insight_append_evidence() {
    local line="$1"
    insight_append_record "$INSIGHT_EVIDENCE_FILE" "$line"
}

insight_append_verdict() {
    local line="$1"
    insight_append_record "$INSIGHT_VERDICTS_FILE" "$line"
}
