#!/usr/bin/env bash
# dev_shortcuts.sh - Development workflow shortcuts for macOS
# NOTE: Dual-use. When sourced, do NOT enable strict mode.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/common.sh"
else
    echo "Error: common utilities not found at $SCRIPT_DIR/lib/common.sh" >&2
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        exit 1
    fi
    return 1
fi

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
fi

is_sourced() {
    if [ -n "${ZSH_VERSION:-}" ]; then
        case $ZSH_EVAL_CONTEXT in
            *:file) return 0 ;;
        esac
        return 1
    elif [ -n "${BASH_VERSION:-}" ]; then
        [[ ${BASH_SOURCE[0]} != "$0" ]]
        return
    fi
    return 1
}

dev_fail() {
    local message="$1"
    local code="${2:-$EXIT_ERROR}"
    log_error "$message" "dev_shortcuts.sh"
    echo "Error: $message" >&2
    if is_sourced; then
        return "$code"
    fi
    exit "$code"
}

case "${1:-}" in
    server)
        # Quick development server
        PORT_RAW=${2:-8000}
        PORT=$(sanitize_input "$PORT_RAW")
        PORT=${PORT//$'\n'/ }
        validate_range "$PORT" 1 65535 "port" || dev_fail "Invalid port: $PORT" "$EXIT_INVALID_ARGS"
        echo "Starting development server on port $PORT..."
        echo "Access at: http://localhost:$PORT"
        python3 -m http.server "$PORT"
        ;;
    
    json)
        # Pretty print JSON from clipboard or file
        if [ -z "${2:-}" ]; then
            echo "Pretty printing JSON from clipboard:"
            pbpaste | python3 -m json.tool
        else
            FILE=$(sanitize_input "$2")
            FILE=${FILE//$'\n'/ }
            FILE=$(validate_path "$FILE") || dev_fail "Invalid JSON file path: $FILE" "$EXIT_INVALID_ARGS"
            if [ ! -f "$FILE" ]; then
                dev_fail "JSON file not found: $FILE" "$EXIT_FILE_NOT_FOUND"
            fi
            echo "Pretty printing JSON from file: $FILE"
            python3 -m json.tool "$FILE"
        fi
        ;;
    
    env)
        # Quick Python virtual environment setup
        if [ ! -d "venv" ]; then
            echo "Creating virtual environment..."
            python3 -m venv venv
        fi
        if is_sourced; then
            echo "Activating virtual environment..."
            # shellcheck source=/dev/null
            source venv/bin/activate
            echo "Virtual environment activated. Use 'deactivate' to exit."
        else
            echo "Virtual environment ready. Run 'source venv/bin/activate' to use it."
        fi
        ;;

    gitquick)
        # Quick git add, commit, push
        shift
        if [ $# -eq 0 ]; then
            echo "Usage: dev gitquick <commit_message>"
            dev_fail "Missing commit message for gitquick." "$EXIT_INVALID_ARGS"
        fi
        COMMIT_MESSAGE=$(sanitize_input "$*")
        COMMIT_MESSAGE=${COMMIT_MESSAGE//$'\n'/ }
        git add .
        git commit -m "$COMMIT_MESSAGE"
        git push
        printf "Changes committed and pushed: %s\n" "$COMMIT_MESSAGE"
        ;;
    
    *)
        echo "Usage: $0 {server|json|env|gitquick}"
        echo "  server [port]     : Start development server (default port 8000)"
        echo "  json [file]       : Pretty print JSON (from clipboard or file)"
        echo "  env               : Create/activate Python virtual environment"
        echo "  gitquick <msg>    : Quick git add, commit, push"
        ;;
esac
