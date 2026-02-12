#!/usr/bin/env bash
# dhp-config.sh: shared helpers for dispatcher configuration
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_DHP_CONFIG_LOADED:-}" ]]; then
    return 0
fi
readonly _DHP_CONFIG_LOADED=true

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
DHP_SQUADS_FILE="${DHP_SQUADS_FILE:-$DOTFILES_DIR/ai-staff-hq/squads.json}"
