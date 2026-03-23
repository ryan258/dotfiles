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

# Start an interactive coaching session after a briefing.
# Usage: coach_start_chat <briefing_text> <session_type>
# session_type: startday | status | goodevening
coach_start_chat() {
    local briefing="$1"
    local session_type="${2:-general}"

    if [[ "${AI_COACH_CHAT_ENABLED:-true}" == "false" ]]; then
        return 0
    fi

    # Skip if not running in an interactive terminal
    if [[ ! -t 0 ]] && [[ ! -t 2 ]]; then
        return 0
    fi

    local chat_py="${DOTFILES_DIR:-$HOME/dotfiles}/bin/coach-chat.py"
    if [[ ! -f "$chat_py" ]]; then
        return 0
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        return 0
    fi

    local system_prompt
    system_prompt="You are a concise daily coach for a developer with MS and ADHD. \
You just delivered a ${session_type} coaching briefing (shown as your first message below).

Interactive follow-up rules:
- Keep responses to 2-5 sentences unless the user asks for detail.
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
    trap 'rm -rf "$_cc_dir" 2>/dev/null || true' EXIT INT TERM
    local _cc_history="$_cc_dir/history.json"
    local _cc_sysprompt="$_cc_dir/system.txt"
    local _cc_briefing="$_cc_dir/briefing.txt"

    printf '%s' "$system_prompt" > "$_cc_sysprompt"
    printf '%s' "$briefing" > "$_cc_briefing"

    if ! python3 "$chat_py" init "$_cc_history" "$_cc_sysprompt" "$_cc_briefing" 2>/dev/null; then
        rm -rf "$_cc_dir" 2>/dev/null || true
        return 0
    fi

    echo "" >&2
    echo "--- Coach Chat (type /q to exit, /help for commands) ---" >&2
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

        # Slash commands handled locally
        case "$user_input" in
            /q|/quit|/done|/exit)
                echo "Take care." >&2
                break
                ;;
            /help|/h)
                _coach_chat_show_help
                continue
                ;;
            /j\ *|/journal\ *)
                local entry="${user_input#/j }"
                [[ "$entry" == "$user_input" ]] && entry="${user_input#/journal }"
                _coach_chat_add_journal "$entry"
                continue
                ;;
            /t\ *|/todo\ *)
                local task="${user_input#/t }"
                [[ "$task" == "$user_input" ]] && task="${user_input#/todo }"
                _coach_chat_add_todo "$task"
                continue
                ;;
            /f\ *|/focus\ *)
                local new_focus="${user_input#/f }"
                [[ "$new_focus" == "$user_input" ]] && new_focus="${user_input#/focus }"
                _coach_chat_update_focus "$new_focus"
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
    cat >&2 <<'HELP'
Commands:
  /j <text>   Save a journal entry
  /t <text>   Add a todo item
  /f <text>   Update your focus
  /q          Exit coach chat
  /help       Show this help

Or just type naturally to chat with your coach.
HELP
}

_coach_chat_add_journal() {
    local entry="$1"
    if [[ -z "$entry" ]]; then
        echo "Usage: /j <journal entry text>" >&2
        return
    fi
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local journal_file="${JOURNAL_FILE:-${DATA_DIR:-$HOME/.config/dotfiles-data}/journal.txt}"

    if type sanitize_input >/dev/null 2>&1; then
        entry=$(sanitize_input "$entry")
    fi

    echo "${timestamp}|${entry}" >> "$journal_file"
    echo "Saved to journal." >&2
}

_coach_chat_add_todo() {
    local task="$1"
    if [[ -z "$task" ]]; then
        echo "Usage: /t <task description>" >&2
        return
    fi
    local today
    today=$(date '+%Y-%m-%d')
    local todo_file="${TODO_FILE:-${DATA_DIR:-$HOME/.config/dotfiles-data}/todo.txt}"

    if type sanitize_input >/dev/null 2>&1; then
        task=$(sanitize_input "$task")
    fi

    local task_id
    if type next_todo_id >/dev/null 2>&1; then
        task_id=$(next_todo_id)
    else
        task_id=$(date '+%s')
    fi
    echo "${task_id}|${today}|${task}" >> "$todo_file"
    echo "Added todo: $task" >&2
}

_coach_chat_update_focus() {
    local new_focus="$1"
    if [[ -z "$new_focus" ]]; then
        echo "Usage: /f <new focus text>" >&2
        return
    fi
    local focus_file="${FOCUS_FILE:-${DATA_DIR:-$HOME/.config/dotfiles-data}/focus.txt}"
    local history_file="${FOCUS_HISTORY_FILE:-${DATA_DIR:-$HOME/.config/dotfiles-data}/focus_history.log}"

    if type sanitize_input >/dev/null 2>&1; then
        new_focus=$(sanitize_input "$new_focus")
    fi

    # Archive existing focus before overwriting (matches focus.sh set behavior)
    if [[ -f "$focus_file" ]] && [[ -s "$focus_file" ]]; then
        local old_focus today
        old_focus=$(cat "$focus_file")
        today=$(date +%Y-%m-%d)
        if type date_today >/dev/null 2>&1; then
            today=$(date_today)
        fi
        mkdir -p "$(dirname "$history_file")"
        printf '%s|%s (Replaced)\n' "$today" "$old_focus" >> "$history_file"
    fi

    printf '%s\n' "$new_focus" > "$focus_file"
    echo "Focus updated to: $new_focus" >&2
}
