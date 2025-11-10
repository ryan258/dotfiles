#!/bin/bash
# dhp-config.sh: shared helpers for dispatcher configuration

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
DHP_SQUADS_FILE="${DHP_SQUADS_FILE:-$DOTFILES_DIR/ai-staff-hq/squads.json}"

get_squad_staff() {
    local squad="$1"
    if [ -z "$squad" ] || [ ! -f "$DHP_SQUADS_FILE" ]; then
        return 1
    fi
    jq -r --arg name "$squad" '.[$name].staff[]?' "$DHP_SQUADS_FILE"
}
