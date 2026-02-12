#!/usr/bin/env bash
set -euo pipefail
# dev_shortcuts.sh - Development workflow shortcuts for macOS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/common.sh"
else
    echo "Error: common utilities not found at $SCRIPT_DIR/lib/common.sh" >&2
    exit 1
fi

dev_fail() {
    local message="$1"
    local code="${2:-$EXIT_ERROR}"
    log_error "$message" "dev_shortcuts.sh"
    echo "Error: $message" >&2
    exit "$code"
}

show_usage() {
    echo "Usage: dev_shortcuts.sh {server|json|env|gitquick}"
    echo "  server [port]     : Start development server (default port 8000)"
    echo "  json [file]       : Pretty print JSON (from clipboard or file)"
    echo "  env               : Create Python virtual environment (venv)"
    echo "  gitquick <msg>    : Quick git add, commit, push"
}

case "${1:-}" in
    server)
        require_cmd "python3" "Install with: brew install python"
        PORT_RAW=${2:-8000}
        PORT=$(sanitize_input "$PORT_RAW")
        PORT=${PORT//$'\n'/ }
        validate_range "$PORT" 1 65535 "port" || dev_fail "Invalid port: $PORT" "$EXIT_INVALID_ARGS"
        echo "Starting development server on port $PORT..."
        echo "Access at: http://localhost:$PORT"
        python3 -m http.server "$PORT"
        ;;

    json)
        if [ -z "${2:-}" ]; then
            require_cmd "python3" "Install with: brew install python"
            echo "Pretty printing JSON from clipboard:"
            pbpaste | python3 -m json.tool
        else
            FILE=$(sanitize_input "$2")
            FILE=${FILE//$'\n'/ }
            FILE=$(validate_path "$FILE") || dev_fail "Invalid JSON file path: $FILE" "$EXIT_INVALID_ARGS"
            if [ ! -f "$FILE" ]; then
                dev_fail "JSON file not found: $FILE" "$EXIT_FILE_NOT_FOUND"
            fi
            require_cmd "python3" "Install with: brew install python"
            echo "Pretty printing JSON from file: $FILE"
            python3 -m json.tool "$FILE"
        fi
        ;;

    env)
        require_cmd "python3" "Install with: brew install python"
        if [ ! -d "venv" ]; then
            echo "Creating virtual environment..."
            python3 -m venv venv
        fi
        echo "Virtual environment ready. Run 'source venv/bin/activate' to use it."
        ;;

    gitquick)
        shift
        if [ $# -eq 0 ]; then
            echo "Usage: dev_shortcuts.sh gitquick <commit_message>"
            dev_fail "Missing commit message for gitquick." "$EXIT_INVALID_ARGS"
        fi
        COMMIT_MESSAGE=$(sanitize_input "$*")
        COMMIT_MESSAGE=${COMMIT_MESSAGE//$'\n'/ }
        git add .
        git commit -m "$COMMIT_MESSAGE"
        git push
        printf "Changes committed and pushed: %s\n" "$COMMIT_MESSAGE"
        ;;

    help|--help|-h)
        show_usage
        ;;

    *)
        show_usage
        dev_fail "Unknown command '${1:-<empty>}'." "$EXIT_INVALID_ARGS"
        ;;
esac
