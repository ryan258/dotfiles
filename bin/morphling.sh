#!/usr/bin/env bash
set -euo pipefail

# morphling.sh - Global launcher for AI-Staff-HQ Morphling specialist.
# Works from any directory by resolving the dotfiles root from this script path.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
AI_STAFF_DIR="$DOTFILES_DIR/ai-staff-hq"

if [[ ! -d "$AI_STAFF_DIR" ]]; then
    echo "Error: AI Staff HQ directory not found at $AI_STAFF_DIR" >&2
    exit 1
fi

# Export User's CWD so agents know where to read/write files
export USER_CWD="$(pwd)"

if ! command -v uv >/dev/null 2>&1; then
    echo "Error: uv is required. Install with: brew install uv" >&2
    exit 1
fi

# No args:
# - If stdin is piped, run one-shot query with piped content.
# - Otherwise, start interactive Morphling session.
if [[ $# -eq 0 ]]; then
    if [[ ! -t 0 ]]; then
        PIPED_CONTENT="$(cat)"
        if [[ -n "$PIPED_CONTENT" ]]; then
            (
                cd "$AI_STAFF_DIR"
                uv run tools/activate.py morphling -q "$PIPED_CONTENT"
            )
            exit $?
        fi
    fi

    (
        cd "$AI_STAFF_DIR"
        uv run tools/activate.py morphling
    )
    exit $?
fi

# If first arg is a flag, forward all args to activate.py.
if [[ "$1" == -* ]]; then
    (
        cd "$AI_STAFF_DIR"
        uv run tools/activate.py morphling "$@"
    )
    exit $?
fi

# Otherwise treat all args as a one-shot query.
QUERY="$*"

# Gather auto-context
CONTEXT_INFO="
--- AUTO-GATHERED CONTEXT ---
Location: $(pwd)
Files:
$(ls -F | head -n 50)

Git Status:
$(git status --short 2>/dev/null || echo "Not a git repo")
-----------------------------"

# If stdin is piped alongside a query, append it as explicit context.
if [[ ! -t 0 ]]; then
    PIPED_CONTENT="$(cat)"
    if [[ -n "$PIPED_CONTENT" ]]; then
        QUERY="${QUERY}

--- CONTEXT (STDIN) ---
${PIPED_CONTENT}"
        
        # Append auto-context to the piped query as well
        QUERY="${QUERY}

${CONTEXT_INFO}"

        # If piping content, we almost certainly want one-shot mode (acting as a filter/processor)
        (
            cd "$AI_STAFF_DIR"
            uv run tools/activate.py morphling -q "$QUERY"
        )
        exit $?
    fi
fi

# If we are here, there is no pipe, just a query argument.
# We want "Continuous Flow": Answer the query, then stay interactive.
# Append auto-context to the initial query
FULL_QUERY="${QUERY}

${CONTEXT_INFO}"

(
    cd "$AI_STAFF_DIR"
    uv run tools/activate.py morphling --initial-prompt "$FULL_QUERY"
)
