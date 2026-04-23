#!/usr/bin/env bash
set -euo pipefail

# --- A quick command-line journal ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_lib "date_utils.sh"
require_lib "config.sh"
require_lib "focus_relevance.sh"

JOURNAL_FILE="${JOURNAL_FILE:?JOURNAL_FILE is not set by config.sh}"

# Ensure journal file exists
touch "$JOURNAL_FILE"

# --- Main Logic ---

_journal_recent_stream() {
    local count="${1:-5}"

    if command -v tac >/dev/null 2>&1; then
        tac "$JOURNAL_FILE" | sed -n "1,${count}p"
    else
        tail -r "$JOURNAL_FILE" | sed -n "1,${count}p"
    fi
}

_journal_print_numbered_stream() {
    local heading="$1"
    local stream="$2"

    if [[ -z "$stream" ]]; then
        echo "Journal is empty. Start by writing an entry!"
        return
    fi

    echo "$heading"
    printf '%s\n' "$stream" | awk '{ printf "%d. %s\n", NR, $0 }'
}

_journal_total_entries() {
    if [[ ! -s "$JOURNAL_FILE" ]]; then
        printf '0'
        return
    fi
    wc -l < "$JOURNAL_FILE" | tr -d ' '
}

_journal_resolve_recent_index() {
    local recent_index="${1:-}"
    [[ -n "$recent_index" ]] || die "Usage: $(basename "$0") edit <recent-index> <text>" "$EXIT_INVALID_ARGS"
    validate_numeric "$recent_index" "recent index" || die "Recent index must be numeric" "$EXIT_ERROR"

    local total_entries
    total_entries=$(_journal_total_entries)
    [[ "$total_entries" -gt 0 ]] || die "Journal is empty. Add entries first." "$EXIT_ERROR"
    [[ "$recent_index" -le "$total_entries" ]] || die "Recent index $recent_index not found" "$EXIT_ERROR"

    printf '%s' "$((total_entries - recent_index + 1))"
}

_journal_print_all() {
    local content="$1"
    local pager_cmd="${PAGER:-less -FRX}"
    local pager_parts=()

    if [[ -t 1 ]] && [[ -n "$content" ]]; then
        IFS=' ' read -r -a pager_parts <<< "$pager_cmd"
        if [[ ${#pager_parts[@]} -gt 0 ]] && command -v "${pager_parts[0]}" >/dev/null 2>&1; then
            printf '%s\n' "$content" | "${pager_parts[@]}"
            return
        fi
    fi

    printf '%s\n' "$content"
}

_journal_related_entries() {
    local focus_text
    focus_text=$(focus_relevance_current_focus) || {
        echo "No current focus set. Use: /f set <focus>" >&2
        return "$EXIT_ERROR"
    }

    local keywords
    local keywords_csv
    keywords=$(focus_relevance_keywords_from_text "$focus_text")
    if [[ -z "$keywords" ]]; then
        echo "Current focus does not contain usable keywords. Use: /f set <focus>" >&2
        return "$EXIT_ERROR"
    fi
    keywords_csv=$(printf '%s\n' "$keywords" | sed '/^[[:space:]]*$/d' | paste -sd ',' -)

    awk -F'|' -v keys="$keywords_csv" '
        BEGIN {
            split(keys, raw, ",")
            for (i in raw) {
                if (raw[i] != "") {
                    wanted[raw[i]] = 1
                }
            }
        }
        {
            lowered = tolower($0)
            score = 0
            for (key in wanted) {
                if (index(lowered, key) > 0) {
                    score++
                }
            }
            if (score > 0) {
                recent_index = NR
                rows[NR] = score "\t" $0
            }
        }
        END {
            for (i = NR; i >= 1; i--) {
                if (rows[i] != "") {
                    printf "%d\t%s\n", NR - i + 1, rows[i]
                }
            }
        }
    ' "$JOURNAL_FILE" | sort -t "$(printf '\t')" -k2,2nr -k1,1n
}

_journal_ai_analysis() {
    local days="$1"
    local title="$2"
    local reviewing_msg="$3"
    local prompt_msg="$4"

    echo "$title"
    echo "$reviewing_msg"
    echo "---"
    echo ""

    # Get entries from last N days
    local cutoff_date
    cutoff_date=$(date_shift_days "-$days" "%Y-%m-%d")
    local recent_entries
    recent_entries=$(filter_entries_by_date "$JOURNAL_FILE" "$cutoff_date" 1 "since")

    if [ -z "$recent_entries" ]; then
        echo "No journal entries found in the last $days days."
        echo "Add entries with: $(basename "$0") 'your thoughts here'"
        exit 0
    fi

    # Send to Chief of Staff for analysis
    if command -v dhp-strategy.sh &> /dev/null; then
        {
            echo "$prompt_msg"
            echo ""
            echo "Journal entries (last $days days):"
            echo "---"
            echo "$recent_entries"
        } | dhp-strategy.sh
    else
        die "dhp-strategy.sh dispatcher not found. Make sure bin/ is in your PATH" "$EXIT_FILE_NOT_FOUND"
    fi

    echo ""
    echo "✅ Analysis complete"
}

case "${1:-add}" in
  add)
    # Add a new journal entry.
    if [ $# -gt 0 ]; then shift; fi # Removes 'add' if present
    ENTRY="$*"
    if [ -z "$ENTRY" ]; then
        echo "Usage: $(basename "$0") <text>" >&2
        log_error "Missing journal entry text"
        exit "$EXIT_INVALID_ARGS"
    fi
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    ENTRY=$(sanitize_for_storage "$ENTRY")
    printf '%s|%s\n' "$TIMESTAMP" "$ENTRY" >> "$JOURNAL_FILE"
    echo "Entry added to journal."
    ;;

  list)
    count="${2:-5}"
    validate_numeric "$count" "list count" || die "List count must be numeric" "$EXIT_ERROR"
    if [[ ! -s "$JOURNAL_FILE" ]]; then
        echo "Journal is empty. Start by writing an entry!"
        exit 0
    fi
    recent_entries="$(_journal_recent_stream "$count")"
    _journal_print_numbered_stream "--- Last $count Journal Entries ---" "$recent_entries"
    ;;

  all)
    if [[ ! -s "$JOURNAL_FILE" ]]; then
        echo "Journal is empty. Start by writing an entry!"
        exit 0
    fi
    all_entries="$(_journal_recent_stream "$(_journal_total_entries)" | awk '{ printf "%d. %s\n", NR, $0 }')"
    _journal_print_all "$all_entries"
    ;;

  rel)
    if [[ ! -s "$JOURNAL_FILE" ]]; then
        echo "Journal is empty. Start by writing an entry!"
        exit 0
    fi
    related_entries="$(_journal_related_entries)" || exit "$?"
    if [[ -z "$related_entries" ]]; then
        echo "No journal entries related to the current focus."
        exit 0
    fi
    echo "--- Journal Entries Related To Current Focus ---"
    printf '%s\n' "$related_entries" | head -n 10 | awk -F'\t' '{ printf "%s. [score %s] %s\n", $1, $2, $3 }'
    ;;

  edit)
    shift
    recent_index="${1:-}"
    line_index="$(_journal_resolve_recent_index "$recent_index")"
    shift || true
    ENTRY="$*"
    if [[ -z "$ENTRY" ]]; then
        echo "Usage: $(basename "$0") edit <recent-index> <text>" >&2
        exit "$EXIT_INVALID_ARGS"
    fi
    original_line="$(sed -n "${line_index}p" "$JOURNAL_FILE")"
    timestamp="$(printf '%s' "$original_line" | cut -d'|' -f1)"
    ENTRY=$(sanitize_for_storage "$ENTRY")
    atomic_replace_line "$line_index" "${timestamp}|${ENTRY}" "$JOURNAL_FILE" || die "Failed to update journal entry" "$EXIT_ERROR"
    echo "Updated journal entry $recent_index."
    ;;

  rm)
    shift
    recent_index="${1:-}"
    line_index="$(_journal_resolve_recent_index "$recent_index")"
    atomic_delete_line "$line_index" "$JOURNAL_FILE" || die "Failed to remove journal entry" "$EXIT_ERROR"
    echo "Removed journal entry $recent_index."
    ;;

  search)
    # Search for a term in the journal.
    shift
    sort_order="recent"
    while [ $# -gt 0 ]; do
      case "$1" in
        --oldest)
          sort_order="oldest"
          shift
          ;;
        --recent)
          sort_order="recent"
          shift
          ;;
        *)
          break
          ;;
      esac
    done

    if [ $# -eq 0 ]; then
        echo "Usage: $(basename "$0") search [--recent|--oldest] <term>" >&2
        log_error "Missing search term"
        exit "$EXIT_INVALID_ARGS"
    fi

    if [[ ! -s "$JOURNAL_FILE" ]]; then
        echo "Journal is empty. Add entries with: $(basename "$0") \"text\""
        exit 0
    fi

    SEARCH_TERM="$*"
    echo "--- Searching for '$SEARCH_TERM' in journal (sorted by $sort_order) ---"

    if [ "$sort_order" = "recent" ]; then
      if command -v tac >/dev/null 2>&1; then
        search_results=$(tac "$JOURNAL_FILE" | grep -i -- "$SEARCH_TERM" || true)
      else
        search_results=$(tail -r "$JOURNAL_FILE" | grep -i -- "$SEARCH_TERM" || true)
      fi
    else
      search_results=$(grep -i -- "$SEARCH_TERM" "$JOURNAL_FILE" || true)
    fi

    if [ -n "$search_results" ]; then
      echo "$search_results"
    else
      echo "No entries found for '$SEARCH_TERM'."
    fi
    ;;

  onthisday)
    # Show entries from this day in previous years.
    MONTH_DAY=$(date "+%m-%d")
    echo "--- On this day ($MONTH_DAY) ---"
    grep -i "....-$MONTH_DAY" "$JOURNAL_FILE" || echo "No entries found for this day in previous years."
    ;;

  analyze)
    # AI-powered analysis of recent journal entries
    prompt="Please analyze the following journal entries from the past 7 days.
Focus on:
- Emotional patterns and mood trends
- Recurring themes or concerns
- Progress indicators and wins
- Areas that might need attention"
    _journal_ai_analysis 7 "🤖 Analyzing your journal with AI Staff: Chief of Staff" "Reviewing last 7 days of entries..." "$prompt"
    ;;

  mood)
    # AI-powered sentiment analysis
    prompt="Please perform a sentiment/mood analysis on these journal entries.
Provide:
- Overall mood trend (improving/declining/stable)
- Specific emotional patterns detected
- Day-by-day mood summary if helpful
- Suggestions for emotional wellbeing"
    _journal_ai_analysis 14 "🎭 Analyzing mood from recent journal entries" "Reviewing last 14 days..." "$prompt"
    ;;

  themes)
    # AI-powered theme extraction
    prompt="Please identify recurring themes in these journal entries.
Provide:
- Top 3-5 recurring themes or topics
- Patterns in what I'm focused on or worried about
- Themes that appear to be growing vs. fading
- Any connections between themes"
    _journal_ai_analysis 30 "🔍 Extracting recurring themes from journal" "Analyzing last 30 days..." "$prompt"
    ;;

  up|update)
    # Open the journal file in the editor
    if command -v code >/dev/null 2>&1; then
        code "$JOURNAL_FILE"
    elif [ -n "${EDITOR:-}" ]; then
        "$EDITOR" "$JOURNAL_FILE"
    else
        open "$JOURNAL_FILE"
    fi
    echo "Opening journal file..."
    ;;

  *)
    echo "Error: Unknown command '$1'" >&2
    echo "Usage: $(basename "$0") <text>"
    echo "   or: $(basename "$0") {up|list|search|onthisday|analyze|mood|themes}"
    echo ""
    echo "Standard commands:"
    echo "  journal <text>              : Add a quick journal entry"
    echo "  up                          : Open journal file in editor"
    echo "  list [count]                : Show recent entries (default: 5)"
    echo "  all                         : Show the full journal"
    echo "  rel                         : Show entries related to current focus"
    echo "  edit <recent-index> <text>  : Edit a recent journal entry"
    echo "  rm <recent-index>           : Remove a recent journal entry"
    echo "  search [--recent] <term>    : Search for a term in journal"
    echo "  onthisday                   : Show entries from this day in past years"
    echo ""
    echo "AI-powered commands:"
    echo "  analyze                     : AI analysis of last 7 days (insights & patterns)"
    echo "  mood                        : AI sentiment analysis of last 14 days"
    echo "  themes                      : AI theme extraction from last 30 days"
    log_error "Unknown journal command '$1'"
    exit "$EXIT_INVALID_ARGS"
    ;;
esac
