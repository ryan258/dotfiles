#!/usr/bin/env bash
set -euo pipefail

# dhp-chain.sh: Dispatcher Chaining Helper
# Enables easy sequential processing through multiple AI specialists

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
source "$SCRIPT_DIR/dhp-shared.sh"
source "$DOTFILES_DIR/scripts/lib/common.sh"
AVAILABLE_DISPATCHERS="$(dhp_available_dispatchers)"

run_dispatcher_capture() {
    local input_mode="$1"
    local input_payload="$2"
    shift 2

    local dispatcher_script="$1"
    shift

    local stderr_file=""
    local output=""
    local status=0

    stderr_file=$(mktemp "${TMPDIR:-/tmp}/dhp-chain.stderr.XXXXXX") \
        || die "Failed to create dispatcher stderr capture file." "$EXIT_ERROR"

    if [[ "$input_mode" == "arg" ]]; then
        if output=$("$dispatcher_script" "$input_payload" "$@" 2>"$stderr_file"); then
            status=0
        else
            status=$?
        fi
    else
        if output=$(printf '%s' "$input_payload" | "$dispatcher_script" "$@" 2>"$stderr_file"); then
            status=0
        else
            status=$?
        fi
    fi

    if [[ -s "$stderr_file" ]]; then
        cat "$stderr_file" >&2
    fi
    rm -f "$stderr_file"

    printf '%s' "$output"
    return "$status"
}

if [ $# -lt 2 ]; then
    cat >&2 <<EOF
Usage: $0 <dispatcher1> <dispatcher2> [dispatcher3...] -- "<initial input>"

Chain multiple dispatchers together for sequential AI processing.

Examples:
  # Story generation → structure analysis → marketing copy
  $0 creative narrative copy -- "lighthouse keeper finds mysterious artifact"

  # Market research → brand strategy → content plan
  $0 market brand content -- "AI productivity tools for developers"

  # Technical analysis → strategic review
  $0 tech strategy -- "optimize database queries"

Available dispatchers:
  $AVAILABLE_DISPATCHERS

Notes:
  - Each dispatcher processes the output of the previous one
  - Results are shown after each step
  - Final output goes to stdout
  - Use '--save <file>' to save final output to a file
EOF
    die "dhp-chain.sh requires at least two dispatchers and an input payload." "$EXIT_INVALID_ARGS"
fi

# Parse arguments
DISPATCHERS=()
COMMON_FLAGS=()
INITIAL_INPUT=""
SAVE_FILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --)
            shift
            INITIAL_INPUT="$*"
            break
            ;;
        --save)
            shift
            if [ -z "${1:-}" ]; then
                die "--save requires a file path." "$EXIT_INVALID_ARGS"
            fi
            SAVE_FILE="$1"
            shift
            ;;
        --brain)
            shift
            COMMON_FLAGS+=("--brain")
            ;;
        *)
            DISPATCHERS+=("$1")
            shift
            ;;
    esac
done

if [ ${#DISPATCHERS[@]} -eq 0 ]; then
    die "No dispatchers specified." "$EXIT_INVALID_ARGS"
fi

if [ -z "$INITIAL_INPUT" ]; then
    die "No initial input provided (use -- to separate input)." "$EXIT_INVALID_ARGS"
fi

echo "🔗 Dispatcher Chain Starting..." >&2
echo "Pipeline: ${DISPATCHERS[*]}" >&2
echo "Input: $INITIAL_INPUT" >&2
echo "" >&2

# Start with initial input
CURRENT_OUTPUT="$INITIAL_INPUT"
STEP=1

# Process through each dispatcher
for dispatcher in "${DISPATCHERS[@]}"; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "Step $STEP: Processing with '$dispatcher' dispatcher..." >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2

    # Resolve dispatcher script via shared mapping.
    if ! DISPATCHER_SCRIPT_NAME="$(dhp_dispatcher_script_name "$dispatcher")"; then
        die "Unknown dispatcher '$dispatcher'. Available: $AVAILABLE_DISPATCHERS" "$EXIT_INVALID_ARGS"
    fi
    DISPATCHER_SCRIPT="$DOTFILES_DIR/bin/$DISPATCHER_SCRIPT_NAME"

    # Creative and content are called with argument input for compatibility.
    case "$DISPATCHER_SCRIPT_NAME" in
        dhp-creative.sh|dhp-content.sh)
            if ! CURRENT_OUTPUT=$(run_dispatcher_capture arg "$CURRENT_OUTPUT" "$DISPATCHER_SCRIPT" "${COMMON_FLAGS[@]}"); then
                die "Step $STEP ($dispatcher) failed." "$EXIT_SERVICE_ERROR"
            fi
            echo "$CURRENT_OUTPUT" >&2
            echo "" >&2
            ((STEP++))
            continue
            ;;
    esac

    # Process through dispatcher (stdin-based)
    # We append common flags like --brain
    if ! CURRENT_OUTPUT=$(run_dispatcher_capture stdin "$CURRENT_OUTPUT" "$DISPATCHER_SCRIPT" "${COMMON_FLAGS[@]}"); then
        die "Step $STEP ($dispatcher) failed." "$EXIT_SERVICE_ERROR"
    fi

    # Show intermediate output
    echo "$CURRENT_OUTPUT" >&2
    echo "" >&2

    ((STEP++))
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "✅ Chain Complete: ${#DISPATCHERS[@]} dispatchers processed" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "" >&2

# Save to file if requested
if [ -n "$SAVE_FILE" ]; then
    echo "$CURRENT_OUTPUT" > "$SAVE_FILE"
    echo "💾 Output saved to: $SAVE_FILE" >&2
else
    # Output final result to stdout
    echo "$CURRENT_OUTPUT"
fi
