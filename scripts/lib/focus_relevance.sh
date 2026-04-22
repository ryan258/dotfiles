#!/usr/bin/env bash
# focus_relevance.sh - Shared focus keyword extraction and relevance scoring.
# NOTE: This file is SOURCED, not executed. Do not set -euo pipefail.
#
# Dependencies:
# - config.sh (for FOCUS_FILE)

if [[ -n "${_FOCUS_RELEVANCE_LOADED:-}" ]]; then
    return 0
fi
readonly _FOCUS_RELEVANCE_LOADED=true

focus_relevance_current_focus() {
    local focus_file="${FOCUS_FILE:-}"
    [[ -n "$focus_file" ]] || return 1
    [[ -f "$focus_file" ]] || return 1
    [[ -s "$focus_file" ]] || return 1
    cat "$focus_file"
}

focus_relevance_keywords_from_text() {
    local text="$1"
    local min_length="${2:-3}"
    local max_tokens="${3:-8}"

    if [[ -z "$text" ]]; then
        return 0
    fi

    printf '%s' "$text" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '\n' | awk -v min="$min_length" '
        BEGIN {
            split("about after around before being could daily doing during from into just keep made make many more most need only other over really repo repos should some task tasks than that their there these they this those through today tomorrow very what when where while with work works your", stopwords, " ")
            for (i in stopwords) {
                blocked[stopwords[i]] = 1
            }
        }
        length($0) >= min && !blocked[$0] { print }
    ' | sort -u | awk -v max="$max_tokens" 'NR <= max { print }'
}

focus_relevance_keywords_from_current_focus() {
    local focus_text
    focus_text=$(focus_relevance_current_focus) || return 1
    focus_relevance_keywords_from_text "$focus_text"
}

focus_relevance_score_text() {
    local text="$1"
    local keywords="$2"
    local keywords_csv=""

    if [[ -z "$text" ]] || [[ -z "$keywords" ]]; then
        printf '0'
        return 0
    fi

    keywords_csv=$(printf '%s\n' "$keywords" | sed '/^[[:space:]]*$/d' | paste -sd ',' -)

    printf '%s' "$text" | tr '[:upper:]' '[:lower:]' | awk -v keys="$keywords_csv" '
        BEGIN {
            score = 0
            split(keys, raw, ",")
            for (i in raw) {
                if (raw[i] != "") {
                    wanted[raw[i]] = 1
                }
            }
        }
        {
            line = $0
            for (key in wanted) {
                if (index(line, key) > 0) {
                    score++
                }
            }
        }
        END { print score + 0 }
    '
}
