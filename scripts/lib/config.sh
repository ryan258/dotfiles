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

# Load environment file once per shell per resolved path.
# Do not trust legacy exported _DOTFILES_ENV_LOADED markers from parent shells:
# they can freeze stale AI/model settings after .env changes.
if [[ "${_DOTFILES_ENV_FILE_LOADED:-}" != "$ENV_FILE" ]]; then
    if [[ -f "$ENV_FILE" ]]; then
        _dotfiles_allexport_was_set=false
        case $- in
            *a*) _dotfiles_allexport_was_set=true ;;
        esac
        set -a
        source "$ENV_FILE"
        if [[ "$_dotfiles_allexport_was_set" == "false" ]]; then
            set +a
        fi
        unset _dotfiles_allexport_was_set
    fi
    _DOTFILES_ENV_FILE_LOADED="$ENV_FILE"
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
TODO_ID_FILE="${TODO_ID_FILE:-$DATA_DIR/todo_next_id}"
DONE_FILE="${DONE_FILE:-$DATA_DIR/todo_done.txt}"
IDEA_FILE="${IDEA_FILE:-$DATA_DIR/ideas.txt}"
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
HEALTH_CACHE_DIR="${HEALTH_CACHE_DIR:-$DATA_DIR/cache}"
GCAL_CREDS_FILE="${GCAL_CREDS_FILE:-$DATA_DIR/google_creds.json}"
GCAL_TOKEN_FILE="${GCAL_TOKEN_FILE:-$DATA_DIR/google_token_cache.json}"
GDRIVE_CREDS_FILE="${GDRIVE_CREDS_FILE:-$DATA_DIR/google_drive_creds.json}"
GDRIVE_TOKEN_FILE="${GDRIVE_TOKEN_FILE:-$DATA_DIR/google_drive_token_cache.json}"
GDRIVE_CACHE_FILE="${GDRIVE_CACHE_FILE:-$CACHE_DIR/google_drive_search_cache.json}"
GDRIVE_CONNECT_TIMEOUT_SECONDS="${GDRIVE_CONNECT_TIMEOUT_SECONDS:-5}"
GDRIVE_MAX_TIME_SECONDS="${GDRIVE_MAX_TIME_SECONDS:-20}"
DOTFILES_BACKUP_DIR="${DOTFILES_BACKUP_DIR:-$HOME/Backups/dotfiles_data}"
DOTFILES_BACKUP_GDRIVE_REMOTE="${DOTFILES_BACKUP_GDRIVE_REMOTE:-gdrive}"
DOTFILES_BACKUP_GDRIVE_FOLDER="${DOTFILES_BACKUP_GDRIVE_FOLDER:-Backups/dotfiles_data}"
PROJECT_BACKUP_DIR="${PROJECT_BACKUP_DIR:-$HOME/Backups}"
PROJECT_BACKUP_GDRIVE_REMOTE="${PROJECT_BACKUP_GDRIVE_REMOTE:-gdrive}"
PROJECT_BACKUP_GDRIVE_BASE_FOLDER="${PROJECT_BACKUP_GDRIVE_BASE_FOLDER:-Backups}"
INSIGHT_HYPOTHESES_FILE="${INSIGHT_HYPOTHESES_FILE:-$DATA_DIR/insight_hypotheses.txt}"
INSIGHT_TESTS_FILE="${INSIGHT_TESTS_FILE:-$DATA_DIR/insight_tests.txt}"
INSIGHT_EVIDENCE_FILE="${INSIGHT_EVIDENCE_FILE:-$DATA_DIR/insight_evidence.txt}"
INSIGHT_VERDICTS_FILE="${INSIGHT_VERDICTS_FILE:-$DATA_DIR/insight_verdicts.txt}"
COACH_LOG_FILE="${COACH_LOG_FILE:-$DATA_DIR/coach_log.txt}"
COACH_MODE_FILE="${COACH_MODE_FILE:-$DATA_DIR/coach_mode.txt}"
CONTEXT_ROOT="${CONTEXT_ROOT:-$DATA_DIR/contexts}"
GITHUB_TOKEN_FILE="${GITHUB_TOKEN_FILE:-$HOME/.github_token}"
GITHUB_TOKEN_FALLBACK="${GITHUB_TOKEN_FALLBACK:-$DATA_DIR/github_token}"
GITHUB_CACHE_DIR="${GITHUB_CACHE_DIR:-$DATA_DIR/cache/github}"
GITHUB_INACTIVE_REPOS_FILE="${GITHUB_INACTIVE_REPOS_FILE:-$DATA_DIR/github_inactive_repos.txt}"
GITHUB_EXCLUDE_FORKS="${GITHUB_EXCLUDE_FORKS:-true}"
DOWNLOADS_DIR="${DOWNLOADS_DIR:-$HOME/Downloads}"
DOCUMENTS_DIR="${DOCUMENTS_DIR:-$HOME/Documents}"
PICTURES_DIR="${PICTURES_DIR:-$HOME/Pictures}"
MUSIC_DIR="${MUSIC_DIR:-$HOME/Music}"
DOWNLOAD_ARCHIVES_DIR="${DOWNLOAD_ARCHIVES_DIR:-$DOCUMENTS_DIR/Archives}"

#=============================================================================
# Model Configuration - SINGLE SOURCE OF TRUTH
#=============================================================================

MODEL_FALLBACK="${MODEL_FALLBACK:-nvidia/nemotron-3-super-120b-a12b:free}"

# Get model for a dispatcher type
# Usage: model=$(get_model "TECH")
get_model() {
    local type="${1:-DEFAULT}"
    local env_var="${type}_MODEL"

    if [[ -n "${!env_var:-}" ]]; then
        echo "${!env_var}"
    elif [[ -n "${DEFAULT_MODEL:-}" ]]; then
        echo "${DEFAULT_MODEL}"
    else
        echo "${MODEL_FALLBACK}"
    fi
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

# Base output directory for AI Staff HQ dispatchers.
# `AI_OUTPUT_BASE` is the legacy alias; prefer setting `DHP_OUTPUT_BASE`.
# If both are set, dispatchers use `DHP_OUTPUT_BASE`.
if [[ -z "${DHP_OUTPUT_BASE:-}" ]]; then
    DHP_OUTPUT_BASE="${AI_OUTPUT_BASE:-$HOME/Documents/AI_Staff_HQ_Outputs}"
fi
AI_OUTPUT_BASE="${AI_OUTPUT_BASE:-$DHP_OUTPUT_BASE}"

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
        BRAND) echo "${DHP_BRAND_OUTPUT_DIR:-$DHP_OUTPUT_BASE/Strategy/Brand}" ;;
        CONTENT) echo "${DHP_CONTENT_OUTPUT_DIR:-$DHP_OUTPUT_BASE/Content/Guides}" ;;
        COPY) echo "${DHP_COPY_OUTPUT_DIR:-$DHP_OUTPUT_BASE/Creative/Copywriting}" ;;
        CREATIVE) echo "${DHP_CREATIVE_OUTPUT_DIR:-$DHP_OUTPUT_BASE/Creative/Stories}" ;;
        FINANCE) echo "${DHP_FINANCE_OUTPUT_DIR:-$DHP_OUTPUT_BASE/Strategy/Finance}" ;;
        MARKET) echo "${DHP_MARKET_OUTPUT_DIR:-$DHP_OUTPUT_BASE/Strategy/Market_Research}" ;;
        MORPHLING) echo "${DHP_MORPHLING_OUTPUT_DIR:-$DHP_OUTPUT_BASE/Morphling}" ;;
        NARRATIVE) echo "${DHP_NARRATIVE_OUTPUT_DIR:-$DHP_OUTPUT_BASE/Creative/Narratives}" ;;
        PROJECT) echo "${DHP_PROJECT_OUTPUT_DIR:-$DHP_OUTPUT_BASE/Strategy/Projects}" ;;
        RESEARCH) echo "${DHP_RESEARCH_OUTPUT_DIR:-$DHP_OUTPUT_BASE/Personal_Development/Research}" ;;
        STOIC) echo "${DHP_STOIC_OUTPUT_DIR:-$DHP_OUTPUT_BASE/Personal_Development/Stoic_Coaching}" ;;
        STRATEGY) echo "${DHP_STRATEGY_OUTPUT_DIR:-$DHP_OUTPUT_BASE/Strategy/Analysis}" ;;
        TECH) echo "${DHP_TECH_OUTPUT_DIR:-$DHP_OUTPUT_BASE/Technical/Code_Analysis}" ;;
        COACH) echo "${DHP_COACH_OUTPUT_DIR:-$DHP_OUTPUT_BASE/Strategy/Coach}" ;;
        *) echo "$DHP_OUTPUT_BASE/General" ;;
    esac
}

#=============================================================================
# Feature Flags
#=============================================================================

# AI-powered features (consume API credits when enabled)
AI_BRIEFING_ENABLED="${AI_BRIEFING_ENABLED:-true}"
AI_STATUS_ENABLED="${AI_STATUS_ENABLED:-false}"
AI_REFLECTION_ENABLED="${AI_REFLECTION_ENABLED:-true}"
AI_BRIEFING_TEMPERATURE="${AI_BRIEFING_TEMPERATURE:-0.25}"
AI_STATUS_TEMPERATURE="${AI_STATUS_TEMPERATURE:-0.2}"
COACH_MODEL="${COACH_MODEL:-${AI_COACH_MODEL:-nvidia/nemotron-3-nano-30b-a3b:free}}"
AI_COACH_MODEL="$COACH_MODEL"
AI_COACH_DISPATCHER="${AI_COACH_DISPATCHER:-dhp-coach.sh}"
AI_COACH_LOG_ENABLED="${AI_COACH_LOG_ENABLED:-true}"
AI_COACH_TACTICAL_DAYS="${AI_COACH_TACTICAL_DAYS:-7}"
AI_COACH_PATTERN_DAYS="${AI_COACH_PATTERN_DAYS:-30}"
AI_COACH_MODE_DEFAULT="${AI_COACH_MODE_DEFAULT:-LOCKED}"
AI_COACH_LOCAL_CONTEXT_ENABLED="${AI_COACH_LOCAL_CONTEXT_ENABLED:-true}"
AI_COACH_LOCAL_CONTEXT_DAYS="${AI_COACH_LOCAL_CONTEXT_DAYS:-7}"
AI_COACH_LOCAL_CONTEXT_DIR_LOG_MAX_LINES="${AI_COACH_LOCAL_CONTEXT_DIR_LOG_MAX_LINES:-120}"
WEEKLY_REVIEW_DIR="${WEEKLY_REVIEW_DIR:-$HOME/Documents/Reviews/Weekly}"
AI_COACH_REQUEST_TIMEOUT_SECONDS="${AI_COACH_REQUEST_TIMEOUT_SECONDS:-35}"
AI_COACH_RETRY_ON_TIMEOUT="${AI_COACH_RETRY_ON_TIMEOUT:-false}"
AI_COACH_RETRY_TIMEOUT_SECONDS="${AI_COACH_RETRY_TIMEOUT_SECONDS:-90}"
GOOGLE_DRIVE_DEFAULT_DAYS="${GOOGLE_DRIVE_DEFAULT_DAYS:-7}"

# Logging features
SWIPE_LOG_ENABLED="${SWIPE_LOG_ENABLED:-true}"
SWIPE_LOG_FILE="${SWIPE_LOG_FILE:-$HOME/Documents/swipe.md}"

#=============================================================================
# Script Settings
#=============================================================================

# Task management
STALE_TASK_DAYS="${STALE_TASK_DAYS:-7}"
AI_COACH_DRIFT_STALE_TASK_DAYS="${AI_COACH_DRIFT_STALE_TASK_DAYS:-$STALE_TASK_DAYS}"
MAX_SUGGESTIONS="${MAX_SUGGESTIONS:-10}"
REVIEW_LOOKBACK_DAYS="${REVIEW_LOOKBACK_DAYS:-7}"

# Spoon theory defaults
DEFAULT_DAILY_SPOONS="${DEFAULT_DAILY_SPOONS:-10}"

# Coaching drift & health thresholds (overridable via .env)
COACH_DRIFT_STALE_THRESHOLD="${COACH_DRIFT_STALE_THRESHOLD:-4}"
COACH_DRIFT_LOW_COMPLETION_THRESHOLD="${COACH_DRIFT_LOW_COMPLETION_THRESHOLD:-2}"
COACH_DRIFT_UNIQUE_DIRS_THRESHOLD="${COACH_DRIFT_UNIQUE_DIRS_THRESHOLD:-10}"
COACH_DRIFT_SWITCHES_THRESHOLD="${COACH_DRIFT_SWITCHES_THRESHOLD:-80}"
COACH_LOW_ENERGY_THRESHOLD="${COACH_LOW_ENERGY_THRESHOLD:-4}"
COACH_HIGH_FOG_THRESHOLD="${COACH_HIGH_FOG_THRESHOLD:-6}"
COACH_TREND_DELTA_THRESHOLD="${COACH_TREND_DELTA_THRESHOLD:-0.2}"
COACH_FOCUS_GIT_HIGH_THRESHOLD="${COACH_FOCUS_GIT_HIGH_THRESHOLD:-60}"
COACH_FOCUS_GIT_LOW_THRESHOLD="${COACH_FOCUS_GIT_LOW_THRESHOLD:-40}"
COACH_FOCUS_ACTIVE_REPO_DRIFT_THRESHOLD="${COACH_FOCUS_ACTIVE_REPO_DRIFT_THRESHOLD:-2}"
COACH_FOCUS_PRIMARY_REPO_SHARE_THRESHOLD="${COACH_FOCUS_PRIMARY_REPO_SHARE_THRESHOLD:-60}"
COACH_ADHERENCE_FILE="${COACH_ADHERENCE_FILE:-$DATA_DIR/coach_adherence.txt}"

# goodevening project scan controls
GOODEVENING_PROJECT_SCAN_LIMIT="${GOODEVENING_PROJECT_SCAN_LIMIT:-20}"
GOODEVENING_PROJECT_SCAN_JOBS="${GOODEVENING_PROJECT_SCAN_JOBS:-8}"
GOODEVENING_PROJECT_ISSUE_DETAIL_LIMIT="${GOODEVENING_PROJECT_ISSUE_DETAIL_LIMIT:-8}"

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

BLOG_STATUS_REVIEW_DETAIL_LIMIT="${BLOG_STATUS_REVIEW_DETAIL_LIMIT:-5}"

#=============================================================================
# Initialize
#=============================================================================

# Auto-initialize data directories when config is sourced
ensure_data_dirs
