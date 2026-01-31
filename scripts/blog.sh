#!/bin/bash
# blog.sh - Tools for managing the blog content workflow.
# Modularized refactor
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Configuration ---
if [ -f "$SCRIPT_DIR/lib/config.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/config.sh"
fi

# Date Utilities
DATE_UTILS="$SCRIPT_DIR/lib/date_utils.sh"
if [ -f "$DATE_UTILS" ]; then
    # shellcheck disable=SC1090
    source "$DATE_UTILS"
else
    echo "Error: date utilities not found at $DATE_UTILS" >&2
    exit 1
fi

SYSTEM_LOG_FILE="${SYSTEM_LOG:-$HOME/.config/dotfiles-data/system.log}"

# Shared Utilities
DHP_UTILS="$HOME/dotfiles/bin/dhp-utils.sh"
if [ -f "$DHP_UTILS" ]; then
    # shellcheck disable=SC1090
    source "$DHP_UTILS"
else
    echo "Error: Shared utility library dhp-utils.sh not found." >&2
    exit 1
fi

# Manual Override Check
if [ -f "$HOME/dotfiles/.env" ]; then
    # shellcheck disable=SC1090
    source "$HOME/dotfiles/.env"
fi

# --- Validation ---
BLOG_DIR="${BLOG_DIR:-}"
if [ -z "$BLOG_DIR" ]; then
    echo "Blog workflows are disabled. Set BLOG_DIR in dotfiles/.env to use blog.sh."
    exit 1
fi

# Config aliases from config.sh or local defaults
DRAFTS_DIR="${BLOG_DRAFTS_DIR_OVERRIDE:-${BLOG_DRAFTS_DIR:-$BLOG_DIR/drafts}}"
POSTS_DIR="${BLOG_POSTS_DIR_OVERRIDE:-${BLOG_POSTS_DIR:-$BLOG_DIR/content/posts}}"

# Create directories
mkdir -p "$BLOG_DIR"
mkdir -p "$DRAFTS_DIR"
mkdir -p "$POSTS_DIR"

# Validate paths (Security check)
if [[ "$BLOG_DIR" == "$HOME"* ]]; then
    VALIDATED_BLOG_DIR=$(validate_path "$BLOG_DIR") || exit 1
    BLOG_DIR="$VALIDATED_BLOG_DIR"
fi

if [[ "$DRAFTS_DIR" == "$HOME"* ]]; then
    VALIDATED_DRAFTS_DIR=$(validate_path "$DRAFTS_DIR") || exit 1
    DRAFTS_DIR="$VALIDATED_DRAFTS_DIR"
fi

if [[ "$POSTS_DIR" == "$HOME"* ]]; then
    VALIDATED_POSTS_DIR=$(validate_path "$POSTS_DIR") || exit 1
    POSTS_DIR="$VALIDATED_POSTS_DIR"
fi

if [ ! -d "$POSTS_DIR" ]; then
    echo "Error: Failed to create or access blog directory at $POSTS_DIR"
    exit 1
fi

# --- Load Libraries ---
# shellcheck disable=SC1090
source "$SCRIPT_DIR/lib/blog_common.sh"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/lib/blog_lifecycle.sh"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/lib/blog_gen.sh"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/lib/blog_ops.sh"


# --- Main Logic ---
case "${1:-}" in
    status|stat|s)
        status
        ;;
    stubs|stub|ls-stubs)
        stubs
        ;;
    random|rand|R)
        random_stub
        ;;
    recent|rec)
        recent
        ;;
    ideas|idea|i)
        shift
        blog_ideas "$@"
        ;;
    generate|gen|g)
        generate "$@"
        ;;
    refine|polish|r)
        refine "$@"
        ;;
    draft|d)
        draft_command "$@"
        ;;
    workflow|w)
        workflow_command "$@"
        ;;
    publish|p)
        publish_site
        ;;
    validate|check|v)
        validate_site
        ;;
    hooks|hook)
        if [ "${2:-}" = "install" ]; then
            install_hooks
        else
            echo "Usage: blog hooks install"
            exit 1
        fi
        ;;
    version|ver)
        shift
        blog_version "$@"
        ;;
    metrics|stats)
        shift
        blog_metrics "$@"
        ;;
    exemplar|ex)
        shift
        blog_exemplar "$@"
        ;;
    social|promote)
        shift
        blog_social "$@"
        ;;
    *)
        echo "Usage: blog <command> [args]"
        echo ""
        echo "Management:"
        echo "  status       Show system status"
        echo "  stubs        List content stubs"
        echo "  random       Open a random content stub"
        echo "  recent       List recently modified posts"
        echo "  ideas        Manage ideas (list|add|sync)"
        echo "  version      Manage version (show|bump|history)"
        echo "  metrics      Show blog statistics"
        echo ""
        echo "Content:"
        echo "  draft        Create a new draft (alias for scaffolder)"
        echo "  generate     Generate content with AI"
        echo "  refine       Refine content with AI"
        echo "  workflow     Run full draft->outline->content workflow"
        echo "  social       Generate social media content"
        echo "  exemplar     View section exemplar"
        echo ""
        echo "Ops:"
        echo "  publish      Validate and prepare for deploy"
        echo "  validate     Run local validation"
        echo "  hooks        Install git hooks"
        echo "AI-powered commands:"
        echo "  blog g / blog generate [options] \"topic\"  - Generate content (supports -p persona, -a archetype, -s section, -f file)"
        echo "  blog r / blog refine <file-path>          - Polish and improve existing content"
        echo "  blog d / blog draft <type> <slug>         - Scaffold a new draft from archetypes"
        echo "  blog w / blog workflow <type> <slug> [--title --topic]"
        echo "  blog p / blog publish                    - Validate, build, and summarize site status"
        ;;
esac
