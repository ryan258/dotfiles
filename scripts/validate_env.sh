#!/usr/bin/env bash
set -euo pipefail

# validate_env.sh - Validates essential environment variables and configurations

DOTFILES_DIR="$HOME/dotfiles"
ENV_FILE="$DOTFILES_DIR/.env"
VALIDATION_STATUS=0 # 0 for success, 1 for failure

echo "⚙️  Validating environment configuration..."

# Source .env file if it exists
if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
else
    echo "  ❌ .env file not found at $ENV_FILE. Please create one from .env.example."
    VALIDATION_STATUS=1
fi

# Check OPENROUTER_API_KEY
if [ -z "${OPENROUTER_API_KEY:-}" ]; then
    echo "  ❌ OPENROUTER_API_KEY is not set in .env. AI dispatchers will not function."
    VALIDATION_STATUS=1
else
    echo "  ✅ OPENROUTER_API_KEY is set."
    # Basic format check (starts with sk-)
    if [[ ! "$OPENROUTER_API_KEY" =~ ^sk- ]]; then
        echo "  ⚠️  Warning: OPENROUTER_API_KEY does not start with 'sk-'. Please verify its format."
    fi
fi

# Check GITHUB_USERNAME
if [ -z "${GITHUB_USERNAME:-}" ]; then
    echo "  ⚠️  Warning: GITHUB_USERNAME is not set in .env. GitHub scripts may use 'git config user.name' or fail."
else
    echo "  ✅ GITHUB_USERNAME is set."
fi

# Check BLOG_DIR
if [ -n "${BLOG_DIR:-}" ]; then
    echo "  ✅ BLOG_DIR is set: $BLOG_DIR"
    if [ ! -d "$BLOG_DIR" ]; then
        echo "  ❌ BLOG_DIR ($BLOG_DIR) does not exist or is not a directory."
        VALIDATION_STATUS=1
    else
        echo "  ✅ BLOG_DIR ($BLOG_DIR) exists."
    fi
else
    echo "  ℹ️  BLOG_DIR is not set. Blog workflows will be disabled."
fi

# Check STALE_TASK_DAYS
if [ -z "${STALE_TASK_DAYS:-}" ]; then
    echo "  ℹ️  STALE_TASK_DAYS is not set. Defaulting to 7 days."
elif ! [[ "$STALE_TASK_DAYS" =~ ^[0-9]+$ ]]; then
    echo "  ❌ STALE_TASK_DAYS ('$STALE_TASK_DAYS') is not a valid number."
    VALIDATION_STATUS=1
else
    echo "  ✅ STALE_TASK_DAYS is set to $STALE_TASK_DAYS."
fi

# Check MAX_SUGGESTIONS
if [ -z "${MAX_SUGGESTIONS:-}" ]; then
    echo "  ℹ️  MAX_SUGGESTIONS is not set. Defaulting to 10."
elif ! [[ "$MAX_SUGGESTIONS" =~ ^[0-9]+$ ]]; then
    echo "  ❌ MAX_SUGGESTIONS ('$MAX_SUGGESTIONS') is not a valid number."
    VALIDATION_STATUS=1
else
    echo "  ✅ MAX_SUGGESTIONS is set to $MAX_SUGGESTIONS."
fi

# Check REVIEW_LOOKBACK_DAYS
if [ -z "${REVIEW_LOOKBACK_DAYS:-}" ]; then
    echo "  ℹ️  REVIEW_LOOKBACK_DAYS is not set. Defaulting to 7 days."
elif ! [[ "$REVIEW_LOOKBACK_DAYS" =~ ^[0-9]+$ ]]; then
    echo "  ❌ REVIEW_LOOKBACK_DAYS ('$REVIEW_LOOKBACK_DAYS') is not a valid number."
    VALIDATION_STATUS=1
else
    echo "  ✅ REVIEW_LOOKBACK_DAYS is set to $REVIEW_LOOKBACK_DAYS."
fi

# Check AI_BRIEFING_ENABLED
if [ -z "${AI_BRIEFING_ENABLED:-}" ]; then
    echo "  ℹ️  AI_BRIEFING_ENABLED is not set. Defaulting to false."
elif [[ "$AI_BRIEFING_ENABLED" != "true" && "$AI_BRIEFING_ENABLED" != "false" ]]; then
    echo "  ❌ AI_BRIEFING_ENABLED ('$AI_BRIEFING_ENABLED') must be 'true' or 'false'."
    VALIDATION_STATUS=1
else
    echo "  ✅ AI_BRIEFING_ENABLED is set to $AI_BRIEFING_ENABLED."
fi

# Check AI_REFLECTION_ENABLED
if [ -z "${AI_REFLECTION_ENABLED:-}" ]; then
    echo "  ℹ️  AI_REFLECTION_ENABLED is not set. Defaulting to false."
elif [[ "$AI_REFLECTION_ENABLED" != "true" && "$AI_REFLECTION_ENABLED" != "false" ]]; then
    echo "  ❌ AI_REFLECTION_ENABLED ('$AI_REFLECTION_ENABLED') must be 'true' or 'false'."
    VALIDATION_STATUS=1
else
    echo "  ✅ AI_REFLECTION_ENABLED is set to $AI_REFLECTION_ENABLED."
fi


if [ "$VALIDATION_STATUS" -eq 0 ]; then
    echo "✅ Environment configuration looks good."
else
    echo "❌ Environment configuration has issues. Please review the warnings/errors above."
fi

exit "$VALIDATION_STATUS"
