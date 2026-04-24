#!/usr/bin/env bats

# test_coach_chat.sh - PTY coverage for coach chat local menus and slash commands.

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    export TEST_ROOT
    TEST_ROOT="$(mktemp -d)"
    export HOME="$TEST_ROOT/home"
    export DATA_DIR="$HOME/.config/dotfiles-data"
    export DOTFILES_DIR="$TEST_ROOT/dotfiles"
    mkdir -p "$DATA_DIR" "$DOTFILES_DIR/scripts/lib" "$DOTFILES_DIR/bin"

    cp "$BATS_TEST_DIRNAME/../scripts/lib/common.sh" "$DOTFILES_DIR/scripts/lib/common.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/config.sh" "$DOTFILES_DIR/scripts/lib/config.sh"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/coach_chat.sh" "$DOTFILES_DIR/scripts/lib/coach_chat.sh"

    cat > "$DOTFILES_DIR/bin/coach-chat.py" <<'EOF'
#!/usr/bin/env python3
import json
import os
import sys

mode = sys.argv[1]
history_path = sys.argv[2]
stub_mode = os.environ.get("COACH_CHAT_STUB_MODE", "reply")
if mode == "init":
    with open(history_path, "w", encoding="utf-8") as handle:
        json.dump({"ok": True}, handle)
    sys.exit(0)
if mode == "turn":
    if stub_mode == "fail":
        print("stub failure from python", file=sys.stderr)
        sys.exit(1)
    if stub_mode == "none":
        print("None")
        sys.exit(0)
    print("Stub coach reply")
    sys.exit(0)
sys.exit(1)
EOF
    chmod +x "$DOTFILES_DIR/bin/coach-chat.py"

    cat > "$DOTFILES_DIR/scripts/todo.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  current)
    cat <<'OUT'
--- CURRENT TODO ---
#1   2026-04-22   Draft strategy memo
OUT
    ;;
  done)
    printf 'Marked todo done: %s\n' "${2:-}"
    ;;
  *)
    printf 'todo stub: %s %s\n' "${1:-}" "${2:-}"
    ;;
esac
EOF
    chmod +x "$DOTFILES_DIR/scripts/todo.sh"

    cat > "$DOTFILES_DIR/scripts/journal.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  list)
    cat <<'OUT'
--- Last 5 Journal Entries ---
1. 2026-04-22 08:00:00|Strategy note
OUT
    ;;
  *)
    printf 'journal stub: %s %s\n' "${1:-}" "${2:-}"
    ;;
esac
EOF
    chmod +x "$DOTFILES_DIR/scripts/journal.sh"

    for script in idea.sh focus.sh drive.sh; do
        cat > "$DOTFILES_DIR/scripts/$script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'stub: %s %s\n' "${1:-}" "${2:-}"
EOF
        chmod +x "$DOTFILES_DIR/scripts/$script"
    done
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "coach chat intercepts menu replies and routes slash commands locally" {
    local runner="$TEST_ROOT/run_coach_chat_expect.sh"

    cat > "$runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export HOME="$HOME"
export DATA_DIR="$DATA_DIR"
export DOTFILES_DIR="$DOTFILES_DIR"
/usr/bin/expect <<'EXPECT'
set timeout 20
spawn bash -lc "source '$env(DOTFILES_DIR)/scripts/lib/config.sh'; source '$env(DOTFILES_DIR)/scripts/lib/common.sh'; source '$env(DOTFILES_DIR)/scripts/lib/coach_chat.sh'; coach_start_chat 'Briefing text' 'status'"
expect -re {Short aliases: /t todo  /i idea  /f focus  /j journal  /d drive}
expect -re {coach>}
send -- "/t\r"
expect -re {Todo menu:}
send -- "A\r"
expect -re {CURRENT TODO}
expect -re {What next\?}
send -- "A\r"
expect -re {Choose a task:}
send -- "1\r"
expect -re {Marked todo done: 1}
expect -re {coach>}
send -- "/j list\r"
expect -re {Last 5 Journal Entries}
expect -re {A\. Edit one of these}
send -- "/q\r"
expect -re {Take care\.}
expect eof
EXPECT
EOF
    chmod +x "$runner"

    run bash "$runner"

    [ "$status" -eq 0 ]
}

@test "coach chat surfaces Python/API stderr instead of swallowing it" {
    local runner="$TEST_ROOT/run_coach_chat_error_expect.sh"

    cat > "$runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export HOME="$HOME"
export DATA_DIR="$DATA_DIR"
export DOTFILES_DIR="$DOTFILES_DIR"
export COACH_CHAT_STUB_MODE=fail
/usr/bin/expect <<'EXPECT'
set timeout 20
spawn bash -lc "source '$env(DOTFILES_DIR)/scripts/lib/config.sh'; source '$env(DOTFILES_DIR)/scripts/lib/common.sh'; source '$env(DOTFILES_DIR)/scripts/lib/coach_chat.sh'; coach_start_chat 'Briefing text' 'status'"
expect -re {coach>}
send -- "hello\r"
expect -re {Coach chat failed: stub failure from python}
send -- "/q\r"
expect -re {Take care\.}
expect eof
EXPECT
EOF
    chmod +x "$runner"

    run bash "$runner"

    [ "$status" -eq 0 ]
}

@test "coach-chat.py content extractor handles structured and missing content" {
    run python3 - <<'PY'
import importlib.util

spec = importlib.util.spec_from_file_location("coach_chat_py", "bin/coach-chat.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

structured = {
    "message": {
        "content": [
            {"type": "text", "text": "First line"},
            {"type": "image", "image_url": "ignored"},
            {"type": "text", "text": "Second line"},
        ]
    }
}

assert module._extract_text_content(structured) == "First line\nSecond line"
assert module._extract_text_content({"message": {"content": None}}) is None
PY

    [ "$status" -eq 0 ]
}
