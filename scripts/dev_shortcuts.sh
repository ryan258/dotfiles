#!/usr/bin/env bash
# dev_shortcuts.sh - Development workflow shortcuts for macOS
# NOTE: Dual-use. When sourced, do NOT enable strict mode.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/common.sh"
fi

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
fi

is_sourced() {
    if [ -n "$ZSH_VERSION" ]; then
        case $ZSH_EVAL_CONTEXT in
            *:file) return 0 ;;
        esac
        return 1
    elif [ -n "$BASH_VERSION" ]; then
        [[ ${BASH_SOURCE[0]} != "$0" ]]
        return
    fi
    return 1
}

case "$1" in
    server)
        # Quick development server
        PORT_RAW=${2:-8000}
        PORT=$(sanitize_input "$PORT_RAW")
        PORT=${PORT//$'\n'/ }
        validate_range "$PORT" 1 65535 "port" || exit 1
        echo "Starting development server on port $PORT..."
        echo "Access at: http://localhost:$PORT"
        python3 -m http.server "$PORT"
        ;;
    
    json)
        # Pretty print JSON from clipboard or file
        if [ -z "$2" ]; then
            echo "Pretty printing JSON from clipboard:"
            pbpaste | python3 -m json.tool
        else
            FILE=$(sanitize_input "$2")
            FILE=${FILE//$'\n'/ }
            FILE=$(validate_path "$FILE") || exit 1
            if [ ! -f "$FILE" ]; then
                echo "File not found: $FILE" >&2
                exit 1
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
            exit 1
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
