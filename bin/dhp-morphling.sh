#!/bin/bash
set -e

# dhp-morphling.sh - Universal "Morphling" Dispatcher (Swarm Edition)
# Adapts to any task by ingesting local context and shapeshifting.

# Source shared libraries
source "$(dirname "$0")/dhp-shared.sh"

# --- 1. SETUP ---
dhp_setup_env

# --- 2. CONTEXT GATHERING ---
# The Morphling thrives on context. We gather as much as possible.
echo "Gathering environmental context for the Morphling..." >&2

CONTEXT_BLOCK=""

# Git Context
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    GIT_BRANCH=$(git branch --show-current)
    GIT_STATUS=$(git status --short)
    CONTEXT_BLOCK="${CONTEXT_BLOCK}
--- GIT CONTEXT ---
Branch: $GIT_BRANCH
Status:
$GIT_STATUS
"
fi

# Directory Structure (depth 2)
if command -v tree >/dev/null 2>&1; then
    TREE_OUTPUT=$(tree -L 2 --noreport -I 'node_modules|__pycache__|venv|.git|dist|build')
    CONTEXT_BLOCK="${CONTEXT_BLOCK}
--- DIRECTORY STRUCTURE (Depth 2) ---
$TREE_OUTPUT
"
elif command -v fd >/dev/null 2>&1; then
     FD_OUTPUT=$(fd --max-depth 2 -E 'node_modules' -E '.git')
     CONTEXT_BLOCK="${CONTEXT_BLOCK}
--- DIRECTORY STRUCTURE (FD Depth 2) ---
$FD_OUTPUT
"
fi

# PWD
Current_Dir=$(pwd)
CONTEXT_BLOCK="${CONTEXT_BLOCK}
--- WORKING DIRECTORY ---
$Current_Dir
"

# --- 3. DISPATCH ---

dhp_dispatch \
    "Morphling Agent" \
    "moonshotai/kimi-k2:free" \
    "$HOME/Documents/AI_Staff_HQ_Outputs/Morphling" \
    "MORPHLING_MODEL" \
    "DHP_MORPHLING_OUTPUT_DIR" \
    "
--- MORPHLING PROTOCOL ACTIVATED ---
You are the Morphling. You are not just an AI assistant; you are a shapeshifting universal specialist.

YOUR SENSORY INPUTS:
$CONTEXT_BLOCK

YOUR PRIME DIRECTIVE:
1. ANALYZE the Request and the Sensory Inputs (Context).
2. DETERMINE the absolute best persona/role to solve this specific problem (e.g., Senior Systems Engineer, Creative Director, Data Scientist).
3. SHAPESHIFT into that persona immediately. Do not announce 'I am becoming...', just BE that expert.
4. EXECUTE the task with the highest level of expertise expected of that role.

ADAPTABILITY MODE: MAX
CONTEXT AWARENESS: MAX
" \
    "0.7" \
    "$@"
