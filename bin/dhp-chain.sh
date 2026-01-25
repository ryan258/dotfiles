#!/bin/bash
set -e

# dhp-chain.sh: Dispatcher Chaining Helper
# Enables easy sequential processing through multiple AI specialists

DOTFILES_DIR="$HOME/dotfiles"

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
  tech, creative, content, strategy, brand, market, stoic, research, narrative, copy

Notes:
  - Each dispatcher processes the output of the previous one
  - Results are shown after each step
  - Final output goes to stdout
  - Use '--save <file>' to save final output to a file
EOF
    exit 1
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
    echo "Error: No dispatchers specified" >&2
    exit 1
fi

if [ -z "$INITIAL_INPUT" ]; then
    echo "Error: No initial input provided (use -- to separate input)" >&2
    exit 1
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

    # Determine the dispatcher script
    case "$dispatcher" in
        tech|dhp-tech)
            DISPATCHER_SCRIPT="$DOTFILES_DIR/bin/dhp-tech.sh"
            ;;
        creative|dhp-creative)
            # Creative uses arguments, not stdin, so we need special handling
            DISPATCHER_SCRIPT="$DOTFILES_DIR/bin/dhp-creative.sh"
            CURRENT_OUTPUT=$("$DISPATCHER_SCRIPT" "$CURRENT_OUTPUT" "${COMMON_FLAGS[@]}")
            echo "$CURRENT_OUTPUT" >&2
            echo "" >&2
            ((STEP++))
            continue
            ;;
        content|dhp-content)
            # Content also uses arguments
            DISPATCHER_SCRIPT="$DOTFILES_DIR/bin/dhp-content.sh"
            CURRENT_OUTPUT=$("$DISPATCHER_SCRIPT" "$CURRENT_OUTPUT" "${COMMON_FLAGS[@]}")
            echo "$CURRENT_OUTPUT" >&2
            echo "" >&2
            ((STEP++))
            continue
            ;;
        strategy|dhp-strategy)
            DISPATCHER_SCRIPT="$DOTFILES_DIR/bin/dhp-strategy.sh"
            ;;
        brand|dhp-brand)
            DISPATCHER_SCRIPT="$DOTFILES_DIR/bin/dhp-brand.sh"
            ;;
        market|dhp-market)
            DISPATCHER_SCRIPT="$DOTFILES_DIR/bin/dhp-market.sh"
            ;;
        stoic|dhp-stoic)
            DISPATCHER_SCRIPT="$DOTFILES_DIR/bin/dhp-stoic.sh"
            ;;
        research|dhp-research)
            DISPATCHER_SCRIPT="$DOTFILES_DIR/bin/dhp-research.sh"
            ;;
        narrative|dhp-narrative)
            DISPATCHER_SCRIPT="$DOTFILES_DIR/bin/dhp-narrative.sh"
            ;;
        copy|dhp-copy)
            DISPATCHER_SCRIPT="$DOTFILES_DIR/bin/dhp-copy.sh"
            ;;
        *)
            echo "Error: Unknown dispatcher '$dispatcher'" >&2
            echo "Available: tech, creative, content, strategy, brand, market, stoic, research, narrative, copy" >&2
            exit 1
            ;;
    esac

    # Process through dispatcher (stdin-based)
    # We append common flags like --brain
    CURRENT_OUTPUT=$(echo "$CURRENT_OUTPUT" | "$DISPATCHER_SCRIPT" "${COMMON_FLAGS[@]}")

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
