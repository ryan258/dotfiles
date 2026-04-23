#!/usr/bin/env bash
# coach_chat.sh - Interactive post-briefing coach conversation
# NOTE: This file is SOURCED, not executed. Do not set -euo pipefail.
#
# Dependencies:
# - config.sh (for DATA_DIR, FOCUS_FILE, TODO_FILE, JOURNAL_FILE paths)
# - common.sh (for sanitize_input)

if [[ -n "${_COACH_CHAT_LOADED:-}" ]]; then
    return 0
fi
readonly _COACH_CHAT_LOADED=true

_coach_chat_root_dir() {
    printf '%s\n' "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}

# Start an interactive coaching session after a briefing.
# Usage: coach_start_chat <briefing_text> <session_type>
# session_type: startday | status | goodevening
coach_start_chat() {
    local briefing="$1"
    local session_type="${2:-general}"

    if [[ "${AI_COACH_CHAT_ENABLED:-true}" == "false" ]]; then
        log_info "Coach chat skipped because AI_COACH_CHAT_ENABLED=false."
        return 0
    fi

    # Skip if not running in an interactive terminal
    if [[ ! -t 0 ]] && [[ ! -t 2 ]]; then
        return 0
    fi

    local chat_py="${DOTFILES_DIR:-$HOME/dotfiles}/bin/coach-chat.py"
    if [[ ! -f "$chat_py" ]]; then
        log_info "Coach chat skipped because bin/coach-chat.py was not found."
        return 0
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        log_info "Coach chat skipped because python3 is unavailable."
        return 0
    fi

    local system_prompt
    system_prompt="You are a concise daily coach for a developer with MS and ADHD. \
You just delivered a ${session_type} coaching briefing (shown as your first message below).

Interactive follow-up rules:
- Keep responses to 2-5 sentences unless the user asks for detail.
- When clarification would improve the coaching, prefer a short A-E multiple-choice question instead of an open-ended question. Always include E as a custom answer.
- Prefer one clarifying question per turn; ask two only if both are brief and necessary.
- If the user shares a reflection or explains why they did something, acknowledge it and suggest they capture it: say \"Capture that with: /j <your words>\"
- If the user mentions a task or next step, suggest: \"Track that with: /t <task description>\"
- If the user wants to change direction, suggest: \"Update focus with: /f <new focus>\"
- Reference the briefing context freely. You remember everything you just said.
- Available timer commands the user can run: pomo (25-min focus), tbreak <min> (break timer), remind '+Xm' 'message' (timed reminder).
- Stay grounded, specific, and MS+ADHD-aware. Validate exploration. Never shame.
- Do not repeat the briefing. Build on it."

    # Create temp workspace
    local _cc_dir
    _cc_dir=$(mktemp -d "${TMPDIR:-/tmp}/coach_chat.XXXXXX") || return 1
    trap 'rm -rf "${_cc_dir:-}" 2>/dev/null || true' EXIT INT TERM
    local _cc_history="$_cc_dir/history.json"
    local _cc_sysprompt="$_cc_dir/system.txt"
    local _cc_briefing="$_cc_dir/briefing.txt"
    local _cc_menu_state="$_cc_dir/menu_state.tsv"

    printf '%s' "$system_prompt" > "$_cc_sysprompt"
    printf '%s' "$briefing" > "$_cc_briefing"

    if ! python3 "$chat_py" init "$_cc_history" "$_cc_sysprompt" "$_cc_briefing" 2>/dev/null; then
        log_warn "Coach chat could not initialize; continuing without the interactive follow-up."
        rm -rf "$_cc_dir" 2>/dev/null || true
        return 0
    fi

    echo "" >&2
    echo "--- Coach Chat (type /q to exit, /help for commands) ---" >&2
    echo "Short aliases: /t todo  /i idea  /f focus  /j journal  /d drive" >&2
    echo "" >&2

    local user_input=""
    local response=""
    local turn_status=0

    while true; do
        printf '\033[1mcoach>\033[0m ' >&2
        if ! IFS= read -r user_input </dev/tty 2>/dev/null; then
            # EOF (Ctrl-D)
            echo "" >&2
            break
        fi

        # Trim leading/trailing whitespace
        user_input="${user_input#"${user_input%%[![:space:]]*}"}"
        user_input="${user_input%"${user_input##*[![:space:]]}"}"

        [[ -z "$user_input" ]] && continue

        if _coach_chat_handle_menu_reply "$user_input" "$_cc_menu_state"; then
            continue
        fi

        # Slash commands handled locally
        case "$user_input" in
            /q|/quit|/done|/exit)
                echo "Take care." >&2
                break
                ;;
            /help|/h)
                _coach_chat_show_help "$_cc_menu_state"
                continue
                ;;
            /t*|/todo*|/i*|/idea*|/f*|/focus*|/j*|/journal*|/d*|/drive*)
                _coach_chat_handle_local_command "$user_input" "$_cc_menu_state"
                continue
                ;;
        esac

        # Send to AI
        response=""
        turn_status=0
        response=$(python3 "$chat_py" turn "$_cc_history" "$user_input" 2>/dev/null) || turn_status=$?

        if [[ "$turn_status" -ne 0 ]] || [[ -z "$response" ]]; then
            echo "(Couldn't get a response. Try again or /q to exit)" >&2
        else
            echo "" >&2
            echo "$response" >&2
            echo "" >&2
        fi
    done

    # Cleanup
    rm -rf "$_cc_dir" 2>/dev/null || true
}

_coach_chat_show_help() {
    local state_file="${1:-}"
    if [[ -n "$state_file" ]]; then
        _coach_chat_clear_menu_state "$state_file"
    fi
    cat >&2 <<'HELP'
Commands:
  /t          Todo menu
  /i          Idea menu
  /f          Focus menu
  /j          Journal menu
  /d          Drive menu
  /q          Exit coach chat
  /help       Show this help

Examples:
  /t stale
  /t done 14
  /i to-todo 2
  /f set Finish strategy brief
  /j rel
  /d recent 1

Bare aliases still work for quick capture:
  /t <text>   Add a todo
  /i <text>   Add an idea
  /f <text>   Set focus
  /j <text>   Add a journal entry
  /d <text>   Recall Drive docs for a query

Or just type naturally to chat with your coach when no local menu is active.
HELP
}

_coach_chat_clear_menu_state() {
    local state_file="$1"
    rm -f "$state_file" 2>/dev/null || true
}

_coach_chat_write_menu_state() {
    local state_file="$1"
    shift
    : > "$state_file"
    while [[ $# -gt 0 ]]; do
        printf '%s\n' "$1" >> "$state_file"
        shift
    done
}

_coach_chat_lookup_menu_command() {
    local input="$1"
    local state_file="$2"

    [[ -s "$state_file" ]] || return 1

    awk -F'\t' -v key="$input" '$1 == key { print $2; exit }' "$state_file"
}

_coach_chat_capture_cli() {
    local script_name="$1"
    shift
    local script_path="$(_coach_chat_root_dir)/$script_name"
    [[ -x "$script_path" ]] || {
        echo "Command unavailable: $script_name" >&2
        return 1
    }
    bash "$script_path" "$@" 2>&1
}

_coach_chat_split_args() {
    local text="$1"
    local -a parts=()

    if [[ -n "$text" ]]; then
        read -r -a parts <<< "$text"
    fi

    if [[ "${#parts[@]}" -gt 0 ]]; then
        printf '%s\0' "${parts[@]}"
    fi
}

_coach_chat_print_cli_output() {
    local output="$1"
    if [[ -n "$output" ]]; then
        echo "" >&2
        echo "$output" >&2
        echo "" >&2
    fi
}

_coach_chat_show_numeric_menu() {
    local state_file="$1"
    local heading="$2"
    local command_prefix="$3"
    local entries="$4"
    local back_command="${5:-}"
    local custom_command="${6:-__custom__}"
    local lines=()
    local index=1
    local value=""
    local label=""

    echo "" >&2
    echo "$heading" >&2

    while IFS=$'\t' read -r value label; do
        [[ -n "$value" ]] || continue
        printf '%s. %s\n' "$index" "$label" >&2
        lines+=("${index}"$'\t'"cmd:${command_prefix} ${value}")
        index=$((index + 1))
    done <<< "$entries"

    if [[ "${#lines[@]}" -eq 0 ]]; then
        echo "(Nothing to pick right now.)" >&2
        _coach_chat_write_menu_state "$state_file" "A"$'\t'"menu:main" "E"$'\t'"__custom__"
        return
    fi

    if [[ -n "$back_command" ]]; then
        echo "A. Back" >&2
        lines+=("A"$'\t'"${back_command}")
    fi
    echo "E. Custom command" >&2
    lines+=("E"$'\t'"${custom_command}")

    _coach_chat_write_menu_state "$state_file" "${lines[@]}"
    echo "" >&2
}

_coach_chat_parse_todo_entries() {
    local output="$1"
    printf '%s\n' "$output" | awk '
        /^#/ {
            id = $1
            sub(/^#/, "", id)
            $1 = ""
            sub(/^[[:space:]]+/, "", $0)
            print id "\t" $0
        }
    '
}

_coach_chat_parse_idea_entries() {
    local output="$1"
    printf '%s\n' "$output" | awk '
        $1 ~ /^[0-9]+$/ {
            idx = $1
            $1 = ""
            sub(/^[[:space:]]+/, "", $0)
            print idx "\t" $0
        }
    '
}

_coach_chat_parse_journal_entries() {
    local output="$1"
    printf '%s\n' "$output" | awk '
        $1 ~ /^[0-9]+\.$/ {
            idx = $1
            sub(/\.$/, "", idx)
            $1 = ""
            sub(/^[[:space:]]+/, "", $0)
            print idx "\t" $0
        }
    '
}

_coach_chat_show_main_menu() {
    local state_file="$1"
    echo "" >&2
    echo "What do you want to manage?" >&2
    echo "A. Todos" >&2
    echo "B. Ideas" >&2
    echo "C. Focus" >&2
    echo "D. Journal" >&2
    echo "E. Drive" >&2
    _coach_chat_write_menu_state "$state_file" \
        "A"$'\t'"menu:todo" \
        "B"$'\t'"menu:idea" \
        "C"$'\t'"menu:focus" \
        "D"$'\t'"menu:journal" \
        "E"$'\t'"menu:drive"
    echo "" >&2
}

_coach_chat_show_todo_menu() {
    local state_file="$1"
    echo "" >&2
    echo "Todo menu:" >&2
    echo "A. Current tasks" >&2
    echo "B. Stale tasks" >&2
    echo "C. All tasks" >&2
    echo "D. Add a task" >&2
    echo "E. Custom command" >&2
    _coach_chat_write_menu_state "$state_file" \
        "A"$'\t'"cmd:/t current" \
        "B"$'\t'"cmd:/t stale" \
        "C"$'\t'"cmd:/t all" \
        "D"$'\t'"__pending_text__:/t add" \
        "E"$'\t'"__custom__"
    echo "" >&2
}

_coach_chat_show_idea_menu() {
    local state_file="$1"
    echo "" >&2
    echo "Idea menu:" >&2
    echo "A. List ideas" >&2
    echo "B. Add an idea" >&2
    echo "C. Promote one to todo" >&2
    echo "D. Remove one" >&2
    echo "E. Custom command" >&2
    _coach_chat_write_menu_state "$state_file" \
        "A"$'\t'"cmd:/i list" \
        "B"$'\t'"__pending_text__:/i add" \
        "C"$'\t'"menu:idea-select:to-todo" \
        "D"$'\t'"menu:idea-select:rm" \
        "E"$'\t'"__custom__"
    echo "" >&2
}

_coach_chat_show_focus_menu() {
    local state_file="$1"
    echo "" >&2
    echo "Focus menu:" >&2
    echo "A. Show current focus" >&2
    echo "B. Set focus" >&2
    echo "C. Mark focus done" >&2
    echo "D. Clear focus" >&2
    echo "E. Focus history" >&2
    _coach_chat_write_menu_state "$state_file" \
        "A"$'\t'"cmd:/f show" \
        "B"$'\t'"__pending_text__:/f set" \
        "C"$'\t'"cmd:/f done" \
        "D"$'\t'"cmd:/f clear" \
        "E"$'\t'"cmd:/f history"
    echo "" >&2
}

_coach_chat_show_journal_menu() {
    local state_file="$1"
    echo "" >&2
    echo "Journal menu:" >&2
    echo "A. List recent entries" >&2
    echo "B. Entries related to current focus" >&2
    echo "C. Add an entry" >&2
    echo "D. Remove a recent entry" >&2
    echo "E. Custom command" >&2
    _coach_chat_write_menu_state "$state_file" \
        "A"$'\t'"cmd:/j list" \
        "B"$'\t'"cmd:/j rel" \
        "C"$'\t'"__pending_text__:/j add" \
        "D"$'\t'"menu:journal-select:rm" \
        "E"$'\t'"__custom__"
    echo "" >&2
}

_coach_chat_show_drive_menu() {
    local state_file="$1"
    echo "" >&2
    echo "Drive menu:" >&2
    echo "A. Recent relevant docs today" >&2
    echo "B. Recent relevant docs this week" >&2
    echo "C. Recall docs for current focus" >&2
    echo "D. Status" >&2
    echo "E. Authenticate" >&2
    _coach_chat_write_menu_state "$state_file" \
        "A"$'\t'"cmd:/d recent 1" \
        "B"$'\t'"cmd:/d recent 7" \
        "C"$'\t'"cmd:/d recall" \
        "D"$'\t'"cmd:/d status" \
        "E"$'\t'"cmd:/d auth"
    echo "" >&2
}

_coach_chat_show_todo_followup_menu() {
    local state_file="$1"
    local view="$2"

    echo "What next?" >&2
    if [[ "$view" == "stale" ]]; then
        echo "A. Mark one done" >&2
        echo "B. Move one to ideas" >&2
        echo "C. Remove one" >&2
    else
        echo "A. Mark one done" >&2
        echo "B. Bump one" >&2
        echo "C. Move one to ideas" >&2
    fi
    echo "D. Back to todo menu" >&2
    echo "E. Custom command" >&2

    if [[ "$view" == "stale" ]]; then
        _coach_chat_write_menu_state "$state_file" \
            "A"$'\t'"menu:todo-select:done:${view}" \
            "B"$'\t'"menu:todo-select:to-idea:${view}" \
            "C"$'\t'"menu:todo-select:rm:${view}" \
            "D"$'\t'"menu:todo" \
            "E"$'\t'"__custom__"
    else
        _coach_chat_write_menu_state "$state_file" \
            "A"$'\t'"menu:todo-select:done:${view}" \
            "B"$'\t'"menu:todo-select:bump:${view}" \
            "C"$'\t'"menu:todo-select:to-idea:${view}" \
            "D"$'\t'"menu:todo" \
            "E"$'\t'"__custom__"
    fi
}

_coach_chat_show_todo_selection_menu() {
    local state_file="$1"
    local action="$2"
    local view="$3"
    local output entries

    output=$(_coach_chat_capture_cli "todo.sh" "$view") || {
        _coach_chat_show_todo_menu "$state_file"
        return
    }
    entries=$(_coach_chat_parse_todo_entries "$output")
    _coach_chat_show_numeric_menu "$state_file" "Choose a task:" "/t ${action}" "$entries" "menu:todo-view:${view}"
}

_coach_chat_show_idea_selection_menu() {
    local state_file="$1"
    local action="$2"
    local output entries

    output=$(_coach_chat_capture_cli "idea.sh" list) || {
        _coach_chat_show_idea_menu "$state_file"
        return
    }
    entries=$(_coach_chat_parse_idea_entries "$output")
    _coach_chat_show_numeric_menu "$state_file" "Choose an idea:" "/i ${action}" "$entries" "menu:idea"
}

_coach_chat_show_journal_selection_menu() {
    local state_file="$1"
    local action="$2"
    local output entries

    output=$(_coach_chat_capture_cli "journal.sh" list 5) || {
        _coach_chat_show_journal_menu "$state_file"
        return
    }
    _coach_chat_print_cli_output "$output"
    entries=$(_coach_chat_parse_journal_entries "$output")
    _coach_chat_show_numeric_menu "$state_file" "Choose a journal entry:" "/j ${action}" "$entries" "menu:journal"
}

_coach_chat_handle_state_command() {
    local command="$1"
    local state_file="$2"
    local payload=""
    local action=""
    local view=""

    case "$command" in
        __custom__)
            _coach_chat_clear_menu_state "$state_file"
            echo "Type a custom command like /t stale, /j rel, /d recent, or a freeform message." >&2
            ;;
        __pending_text__:*)
            _coach_chat_write_menu_state "$state_file" "__pending_text__"$'\t'"${command#__pending_text__:}"
            echo "Type the text to save, or /help to cancel." >&2
            ;;
        menu:main) _coach_chat_show_main_menu "$state_file" ;;
        menu:todo) _coach_chat_show_todo_menu "$state_file" ;;
        menu:idea) _coach_chat_show_idea_menu "$state_file" ;;
        menu:focus) _coach_chat_show_focus_menu "$state_file" ;;
        menu:journal) _coach_chat_show_journal_menu "$state_file" ;;
        menu:drive) _coach_chat_show_drive_menu "$state_file" ;;
        menu:todo-view:*) _coach_chat_show_todo_followup_menu "$state_file" "${command#menu:todo-view:}" ;;
        menu:todo-select:*)
            payload="${command#menu:todo-select:}"
            action="${payload%%:*}"
            view="${payload#*:}"
            _coach_chat_show_todo_selection_menu "$state_file" "$action" "$view"
            ;;
        menu:idea-select:*)
            _coach_chat_show_idea_selection_menu "$state_file" "${command#menu:idea-select:}"
            ;;
        menu:journal-select:*)
            _coach_chat_show_journal_selection_menu "$state_file" "${command#menu:journal-select:}"
            ;;
        cmd:*)
            _coach_chat_clear_menu_state "$state_file"
            _coach_chat_handle_local_command "${command#cmd:}" "$state_file"
            ;;
        *)
            _coach_chat_clear_menu_state "$state_file"
            ;;
    esac
}

_coach_chat_handle_menu_reply() {
    local input="$1"
    local state_file="$2"
    local command=""

    [[ -s "$state_file" ]] || return 1

    command=$(_coach_chat_lookup_menu_command "$input" "$state_file" || true)
    if [[ -n "$command" ]]; then
        _coach_chat_handle_state_command "$command" "$state_file"
        return 0
    fi

    command=$(_coach_chat_lookup_menu_command "__pending_text__" "$state_file" || true)
    if [[ -n "$command" ]] && [[ "$input" == "E" ]]; then
        _coach_chat_clear_menu_state "$state_file"
        echo "Pending text entry cancelled." >&2
        return 0
    fi
    if [[ -n "$command" ]] && [[ "$input" != /* ]]; then
        _coach_chat_clear_menu_state "$state_file"
        _coach_chat_handle_local_command "$command $input" "$state_file"
        return 0
    fi

    if [[ "$input" =~ ^[A-Ea-e0-9]+$ ]]; then
        echo "No local menu item for '$input'. Use /help to cancel or pick one of the shown options." >&2
        return 0
    fi

    return 1
}

_coach_chat_handle_local_command() {
    local input="$1"
    local state_file="$2"
    local alias="${input%%[[:space:]]*}"
    local remainder=""
    local subcmd=""
    local rest=""
    local output=""
    local -a cli_args=()

    remainder="${input#"$alias"}"
    remainder="${remainder#"${remainder%%[![:space:]]*}"}"
    subcmd="${remainder%%[[:space:]]*}"
    if [[ "$subcmd" == "$remainder" ]]; then
        rest=""
    else
        rest="${remainder#"$subcmd"}"
        rest="${rest#"${rest%%[![:space:]]*}"}"
    fi
    if [[ -n "$rest" ]]; then
        while IFS= read -r -d '' arg; do
            cli_args+=("$arg")
        done < <(_coach_chat_split_args "$rest")
    fi

    case "$alias" in
        /t|/todo)
            if [[ -z "$remainder" ]]; then
                _coach_chat_show_todo_menu "$state_file"
                return 0
            fi
            case "$subcmd" in
                list|all|current|stale)
                    output=$(_coach_chat_capture_cli "todo.sh" "$subcmd")
                    _coach_chat_print_cli_output "$output"
                    if [[ "$subcmd" == "list" ]]; then
                        _coach_chat_show_todo_followup_menu "$state_file" "all"
                    else
                        _coach_chat_show_todo_followup_menu "$state_file" "$subcmd"
                    fi
                    ;;
                add|done|rm|bump|to-idea)
                    output=$(_coach_chat_capture_cli "todo.sh" "$subcmd" "${cli_args[@]}")
                    _coach_chat_print_cli_output "$output"
                    ;;
                *)
                    output=$(_coach_chat_capture_cli "todo.sh" add "$remainder")
                    _coach_chat_print_cli_output "$output"
                    ;;
            esac
            return 0
            ;;
        /i|/idea)
            if [[ -z "$remainder" ]]; then
                _coach_chat_show_idea_menu "$state_file"
                return 0
            fi
            case "$subcmd" in
                list)
                    output=$(_coach_chat_capture_cli "idea.sh" list)
                    _coach_chat_print_cli_output "$output"
                    _coach_chat_write_menu_state "$state_file" \
                        "A"$'\t'"menu:idea-select:to-todo" \
                        "B"$'\t'"menu:idea-select:rm" \
                        "C"$'\t'"menu:idea" \
                        "E"$'\t'"__custom__"
                    echo "A. Move one to todo" >&2
                    echo "B. Remove one" >&2
                    echo "C. Back to idea menu" >&2
                    echo "E. Custom command" >&2
                    ;;
                add|rm|to-todo)
                    output=$(_coach_chat_capture_cli "idea.sh" "$subcmd" "${cli_args[@]}")
                    _coach_chat_print_cli_output "$output"
                    ;;
                *)
                    output=$(_coach_chat_capture_cli "idea.sh" add "$remainder")
                    _coach_chat_print_cli_output "$output"
                    ;;
            esac
            return 0
            ;;
        /f|/focus)
            if [[ -z "$remainder" ]]; then
                _coach_chat_show_focus_menu "$state_file"
                return 0
            fi
            case "$subcmd" in
                show|check|set|done|clear|history)
                    if [[ -n "$rest" ]]; then
                        output=$(_coach_chat_capture_cli "focus.sh" "$subcmd" "$rest")
                    else
                        output=$(_coach_chat_capture_cli "focus.sh" "$subcmd")
                    fi
                    _coach_chat_print_cli_output "$output"
                    ;;
                *)
                    output=$(_coach_chat_capture_cli "focus.sh" set "$remainder")
                    _coach_chat_print_cli_output "$output"
                    ;;
            esac
            return 0
            ;;
        /j|/journal)
            if [[ -z "$remainder" ]]; then
                _coach_chat_show_journal_menu "$state_file"
                return 0
            fi
            case "$subcmd" in
                add)
                    output=$(_coach_chat_capture_cli "journal.sh" add "${cli_args[@]}")
                    _coach_chat_print_cli_output "$output"
                    ;;
                list)
                    if [[ "${#cli_args[@]}" -gt 0 ]]; then
                        output=$(_coach_chat_capture_cli "journal.sh" list "${cli_args[@]}")
                    else
                        output=$(_coach_chat_capture_cli "journal.sh" list)
                    fi
                    _coach_chat_print_cli_output "$output"
                    _coach_chat_write_menu_state "$state_file" \
                        "A"$'\t'"menu:journal-select:edit" \
                        "B"$'\t'"menu:journal-select:rm" \
                        "C"$'\t'"cmd:/j all" \
                        "D"$'\t'"menu:journal" \
                        "E"$'\t'"__custom__"
                    echo "A. Edit one of these" >&2
                    echo "B. Remove one of these" >&2
                    echo "C. Show all" >&2
                    echo "D. Back to journal menu" >&2
                    echo "E. Custom command" >&2
                    ;;
                all|rel|search|edit|rm|onthisday|analyze|mood|themes)
                    if [[ "${#cli_args[@]}" -gt 0 ]]; then
                        output=$(_coach_chat_capture_cli "journal.sh" "$subcmd" "${cli_args[@]}")
                    else
                        output=$(_coach_chat_capture_cli "journal.sh" "$subcmd")
                    fi
                    _coach_chat_print_cli_output "$output"
                    ;;
                *)
                    output=$(_coach_chat_capture_cli "journal.sh" add "$remainder")
                    _coach_chat_print_cli_output "$output"
                    ;;
            esac
            return 0
            ;;
        /d|/drive)
            if [[ -z "$remainder" ]]; then
                _coach_chat_show_drive_menu "$state_file"
                return 0
            fi
            case "$subcmd" in
                auth|status|recent|recall)
                    if [[ "${#cli_args[@]}" -gt 0 ]]; then
                        output=$(_coach_chat_capture_cli "drive.sh" "$subcmd" "${cli_args[@]}")
                    else
                        output=$(_coach_chat_capture_cli "drive.sh" "$subcmd")
                    fi
                    _coach_chat_print_cli_output "$output"
                    ;;
                *)
                    output=$(_coach_chat_capture_cli "drive.sh" recall "$remainder")
                    _coach_chat_print_cli_output "$output"
                    ;;
            esac
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}
