#!/usr/bin/env bash
# Unified configuration management for dotfiles
# Single source of truth for models, paths, and settings
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_DOTFILES_CONFIG_LOADED:-}" ]]; then
    return 0
fi
readonly _DOTFILES_CONFIG_LOADED=true

#=============================================================================
# Environment Loading
#=============================================================================

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
ENV_FILE="${ENV_FILE:-$DOTFILES_DIR/.env}"

# Load environment file (only once)
if [[ -z "${_DOTFILES_ENV_LOADED:-}" ]]; then
    if [[ -f "$ENV_FILE" ]]; then
        set -a
        source "$ENV_FILE"
        set +a
    fi
    export _DOTFILES_ENV_LOADED=1
fi

#=============================================================================
# Path Configuration - SINGLE SOURCE OF TRUTH
#=============================================================================

# XDG-compliant data directories
DATA_DIR="${XDG_DATA_HOME:-$HOME/.config}/dotfiles-data"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"

# Ensure directories exist
ensure_data_dirs() {
    mkdir -p "$DATA_DIR" "$CACHE_DIR" "$CONFIG_DIR"
}

# Data file paths - centralized definitions
TODO_FILE="${TODO_FILE:-$DATA_DIR/todo.txt}"
DONE_FILE="${DONE_FILE:-$DATA_DIR/todo_done.txt}"
JOURNAL_FILE="${JOURNAL_FILE:-$DATA_DIR/journal.txt}"
HEALTH_FILE="${HEALTH_FILE:-$DATA_DIR/health.txt}"
SPOON_LOG="${SPOON_LOG:-$DATA_DIR/spoons.txt}"
TIME_LOG="${TIME_LOG:-$DATA_DIR/time_tracking.txt}"
SYSTEM_LOG="${SYSTEM_LOG:-$DATA_DIR/system.log}"
FOCUS_FILE="${FOCUS_FILE:-$DATA_DIR/daily_focus.txt}"
BRIEFING_CACHE_FILE="${BRIEFING_CACHE_FILE:-$DATA_DIR/.ai_briefing_cache}"
CLIPBOARD_FILE="${CLIPBOARD_FILE:-$DATA_DIR/clipboard_history.txt}"
DISPATCHER_USAGE_LOG="${DISPATCHER_USAGE_LOG:-$DATA_DIR/dispatcher_usage.log}"
MEDS_FILE="${MEDS_FILE:-$DATA_DIR/medications.txt}"
DIR_BOOKMARKS_FILE="${DIR_BOOKMARKS_FILE:-$DATA_DIR/dir_bookmarks}"
DIR_HISTORY_FILE="${DIR_HISTORY_FILE:-$DATA_DIR/dir_history}"
DIR_USAGE_LOG="${DIR_USAGE_LOG:-$DATA_DIR/dir_usage.log}"
FAVORITE_APPS_FILE="${FAVORITE_APPS_FILE:-$DATA_DIR/favorite_apps}"
FOCUS_HISTORY_FILE="${FOCUS_HISTORY_FILE:-$DATA_DIR/focus_history.log}"
SYSTEM_LOG_FILE="${SYSTEM_LOG_FILE:-$SYSTEM_LOG}"
REPORTS_DIR="${REPORTS_DIR:-$DATA_DIR/reports}"
HOWTO_DIR="${HOWTO_DIR:-$DATA_DIR/how-to}"
SPEC_ARCHIVE_DIR="${SPEC_ARCHIVE_DIR:-$DATA_DIR/specs}"
TIDY_IGNORE_FILE="${TIDY_IGNORE_FILE:-$DATA_DIR/tidy_ignore.txt}"
BREAKS_LOG="${BREAKS_LOG:-$DATA_DIR/health_breaks.log}"
GCAL_CREDS_FILE="${GCAL_CREDS_FILE:-$DATA_DIR/google_creds.json}"
GCAL_TOKEN_FILE="${GCAL_TOKEN_FILE:-$DATA_DIR/google_token_cache.json}"

#=============================================================================
# Model Configuration - SINGLE SOURCE OF TRUTH
#=============================================================================

# Get model for a dispatcher type
# Usage: model=$(get_model "TECH")
get_model() {
    local type="${1:-DEFAULT}"
    local env_var="${type}_MODEL"

    # Check environment first, then defaults
    if [[ -n "${!env_var:-}" ]]; then
        echo "${!env_var}"
        return
    fi

    case "$type" in
        TECH) echo "${TECH_MODEL:-moonshotai/kimi-k2:free}" ;;
        STRATEGY) echo "${STRATEGY_MODEL:-moonshotai/kimi-k2:free}" ;;
        CREATIVE) echo "${CREATIVE_MODEL:-moonshotai/kimi-k2:free}" ;;
        CONTENT) echo "${CONTENT_MODEL:-moonshotai/kimi-k2:free}" ;;
        STOIC) echo "${STOIC_MODEL:-moonshotai/kimi-k2:free}" ;;
        RESEARCH) echo "${RESEARCH_MODEL:-moonshotai/kimi-k2:free}" ;;
        MARKET) echo "${MARKET_MODEL:-moonshotai/kimi-k2:free}" ;;
        BRAND) echo "${BRAND_MODEL:-moonshotai/kimi-k2:free}" ;;
        COPY) echo "${COPY_MODEL:-moonshotai/kimi-k2:free}" ;;
        NARRATIVE) echo "${NARRATIVE_MODEL:-moonshotai/kimi-k2:free}" ;;
        MORPHLING) echo "${MORPHLING_MODEL:-moonshotai/kimi-k2:free}" ;;
        DEFAULT|*) echo "${DEFAULT_MODEL:-moonshotai/kimi-k2:free}" ;;
    esac
}

# Get temperature for a dispatcher type
# Usage: temp=$(get_temperature "TECH")
get_temperature() {
    local type="${1:-DEFAULT}"
    local env_var="${type}_TEMPERATURE"

    if [[ -n "${!env_var:-}" ]]; then
        echo "${!env_var}"
        return
    fi

    case "$type" in
        TECH) echo "0.2" ;;
        STRATEGY) echo "0.4" ;;
        CREATIVE) echo "0.7" ;;
        CONTENT) echo "0.5" ;;
        STOIC) echo "0.3" ;;
        RESEARCH) echo "0.3" ;;
        MARKET) echo "0.4" ;;
        BRAND) echo "0.5" ;;
        DEFAULT|*) echo "0.3" ;;
    esac
}

#=============================================================================
# API Configuration
#=============================================================================

# Rate limiting
API_COOLDOWN_SECONDS="${API_COOLDOWN_SECONDS:-1}"

# Cost estimation (per 1M tokens) - for logging purposes
API_COST_INPUT="${API_COST_INPUT:-0.50}"
API_COST_OUTPUT="${API_COST_OUTPUT:-1.50}"

# Check if model is free tier
is_free_model() {
    local model="$1"
    [[ "$model" == *":free" ]]
}

#=============================================================================
# Output Directory Configuration
#=============================================================================

# Base output directory for AI Staff HQ
AI_OUTPUT_BASE="${AI_OUTPUT_BASE:-$HOME/Documents/AI_Staff_HQ_Outputs}"

# Get output directory for a dispatcher type
# Usage: dir=$(get_output_dir "TECH")
get_output_dir() {
    local type="${1:-TECH}"
    local env_var="DHP_${type}_OUTPUT_DIR"

    if [[ -n "${!env_var:-}" ]]; then
        echo "${!env_var}"
        return
    fi

    case "$type" in
        BRAND) echo "${DHP_BRAND_OUTPUT_DIR:-$AI_OUTPUT_BASE/Strategy/Brand}" ;;
        CONTENT) echo "${DHP_CONTENT_OUTPUT_DIR:-$AI_OUTPUT_BASE/Content/Guides}" ;;
        COPY) echo "${DHP_COPY_OUTPUT_DIR:-$AI_OUTPUT_BASE/Creative/Copywriting}" ;;
        CREATIVE) echo "${DHP_CREATIVE_OUTPUT_DIR:-$AI_OUTPUT_BASE/Creative/Stories}" ;;
        MARKET) echo "${DHP_MARKET_OUTPUT_DIR:-$AI_OUTPUT_BASE/Strategy/Market_Research}" ;;
        NARRATIVE) echo "${DHP_NARRATIVE_OUTPUT_DIR:-$AI_OUTPUT_BASE/Creative/Narratives}" ;;
        RESEARCH) echo "${DHP_RESEARCH_OUTPUT_DIR:-$AI_OUTPUT_BASE/Personal_Development/Research}" ;;
        STOIC) echo "${DHP_STOIC_OUTPUT_DIR:-$AI_OUTPUT_BASE/Personal_Development/Stoic_Coaching}" ;;
        STRATEGY) echo "${DHP_STRATEGY_OUTPUT_DIR:-$AI_OUTPUT_BASE/Strategy/Analysis}" ;;
        TECH) echo "${DHP_TECH_OUTPUT_DIR:-$AI_OUTPUT_BASE/Technical/Code_Analysis}" ;;
        *) echo "$AI_OUTPUT_BASE/General" ;;
    esac
}

#=============================================================================
# Feature Flags
#=============================================================================

# AI-powered features (consume API credits when enabled)
AI_BRIEFING_ENABLED="${AI_BRIEFING_ENABLED:-true}"
AI_REFLECTION_ENABLED="${AI_REFLECTION_ENABLED:-true}"

# Logging features
SWIPE_LOG_ENABLED="${SWIPE_LOG_ENABLED:-true}"
SWIPE_LOG_FILE="${SWIPE_LOG_FILE:-$HOME/Documents/swipe.md}"

#=============================================================================
# Script Settings
#=============================================================================

# Task management
STALE_TASK_DAYS="${STALE_TASK_DAYS:-7}"
MAX_SUGGESTIONS="${MAX_SUGGESTIONS:-10}"
REVIEW_LOOKBACK_DAYS="${REVIEW_LOOKBACK_DAYS:-7}"

# Spoon theory defaults
DEFAULT_DAILY_SPOONS="${DEFAULT_DAILY_SPOONS:-10}"

# Health tracking cache
HEALTH_COMMITS_CACHE_TTL="${HEALTH_COMMITS_CACHE_TTL:-3600}"
HEALTH_COMMITS_LOOKBACK_DAYS="${HEALTH_COMMITS_LOOKBACK_DAYS:-90}"

#=============================================================================
# Blog Configuration
#=============================================================================

# Only set if BLOG_DIR is defined
if [[ -n "${BLOG_DIR:-}" ]]; then
    BLOG_CONTENT_DIR="${BLOG_CONTENT_DIR:-$BLOG_DIR/content}"
    BLOG_ARCHETYPES_DIR="${BLOG_ARCHETYPES_DIR:-$BLOG_DIR/archetypes}"
    BLOG_STANDARDS_FILE="${BLOG_STANDARDS_FILE:-$BLOG_DIR/GUIDE-WRITING-STANDARDS.md}"
    BLOG_CONTRIBUTING_FILE="${BLOG_CONTRIBUTING_FILE:-$BLOG_DIR/CONTRIBUTING.md}"
    CONTENT_OUTPUT_DIR="${CONTENT_OUTPUT_DIR:-$BLOG_DIR/drafts/first}"
fi

#=============================================================================
# Initialize
#=============================================================================

# Auto-initialize data directories when config is sourced
ensure_data_dirs
