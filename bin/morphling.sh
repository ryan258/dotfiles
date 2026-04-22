#!/usr/bin/env bash
set -euo pipefail

# morphling.sh - Launch Morphling in direct mode or swarm mode.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
AI_STAFF_DIR="$DOTFILES_DIR/ai-staff-hq"
SWARM_BIN="$SCRIPT_DIR/dhp-morphling.sh"
ACTIVATE_SCRIPT="$AI_STAFF_DIR/tools/activate.py"

usage() {
    cat <<'EOF'
Usage:
  morphling [options]
  morphling "one-shot question"
  echo "one-shot question" | morphling
  morphling --swarm "dispatcher-style question"

Modes:
  direct (default)  Runs ai-staff-hq's native Morphling session via activate.py
  swarm             Uses the older dispatcher/swarm wrapper

Direct-mode options:
  -q, --query TEXT
  --initial-prompt TEXT
  --model MODEL
  --temperature N
  --resume [SESSION|last]
  --debug

Wrapper options:
  --swarm           Use the dispatcher/swarm path instead of the direct path
  -h, --help        Show this help
EOF
}

# Join leftover words into one plain-text query for direct mode.
join_query() {
    local first=true
    while [[ "$#" -gt 0 ]]; do
        if [[ "$first" == true ]]; then
            printf '%s' "$1"
            first=false
        else
            printf ' %s' "$1"
        fi
        shift
    done
}

if [[ "${1:-}" == "--swarm" ]]; then
    shift
    exec "$SWARM_BIN" "$@"
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ ! -f "$ACTIVATE_SCRIPT" ]]; then
    echo "Error: activate.py not found at $ACTIVATE_SCRIPT" >&2
    exit 1
fi

activate_args=("morphling")
query_text=""
has_query_flag=false

# Treat leftover plain words as the query so `morphling do x` works naturally.
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --swarm)
            exec "$SWARM_BIN" "${@:2}"
            ;;
        -q|--query|--initial-prompt|--model|--temperature)
            if [[ -z "${2:-}" ]]; then
                echo "Error: $1 requires a value." >&2
                exit 1
            fi
            activate_args+=("$1" "$2")
            if [[ "$1" == "-q" || "$1" == "--query" || "$1" == "--initial-prompt" ]]; then
                has_query_flag=true
            fi
            shift 2
            ;;
        --resume)
            if [[ -n "${2:-}" && "${2:-}" != --* ]]; then
                activate_args+=("$1" "$2")
                shift 2
            else
                activate_args+=("$1")
                shift
            fi
            ;;
        --debug)
            activate_args+=("$1")
            shift
            ;;
        --)
            shift
            if [[ "$#" -gt 0 ]]; then
                query_text="$(join_query "$@")"
            fi
            break
            ;;
        --*)
            activate_args+=("$1")
            shift
            ;;
        *)
            query_text="$(join_query "$@")"
            break
            ;;
    esac
done

# Only read stdin when the caller did not already pass a query flag.
if [[ "$has_query_flag" == false && ! -t 0 ]]; then
    stdin_query="$(cat)"
    if [[ -n "$stdin_query" ]]; then
        query_text="$stdin_query"
    fi
fi

if [[ "$has_query_flag" == false && -n "$query_text" ]]; then
    activate_args+=("-q" "$query_text")
fi

exec uv run --project "$AI_STAFF_DIR" python "$ACTIVATE_SCRIPT" "${activate_args[@]}"
