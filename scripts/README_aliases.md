# Alias Reference (Derived)

This file is a quick alias map based on `../zsh/aliases.zsh`.
The full rules live in `../CLAUDE.md`.

## Core Daily Aliases

- `startday`
- `status`
- `goodevening`
- `todo` / `t`
- `idea`
- `journal` / `j`
- `focus`
- `health`
- `spoons`

## AI Aliases

- `tech`, `content`, `strategy`, `creative`, `brand`, `market`, `research`, `stoic`, `narrative`, `aicopy`, `finance`
- `morphling` -- A flexible AI helper (interactive mode via `morphling.sh`)
- `memory` / `memory-search` -- Save and find things in the knowledge base
- Single entry point: `dispatch <squad> "brief"`
- Chaining tools: `dhp-chain`, `dhp-project`, `ai-suggest`
- `cyborg` -- Cyborg Lab agent for scanning repos and writing docs (not a dispatcher)

## Autopilot Aliases (Brain-Fog Days)

- `ap` -- Auto-document the current repo (Morphling scans it, then Cyborg writes about it)
- `apy` -- Auto-document and auto-confirm all prompts
- `apb "idea"` -- Build a project from an idea, then document it
- `apby "idea"` -- Build, document, and auto-confirm
- `apc` -- Pick up where you left off in a past session

## Navigation + Utility

- `g` (jump to folders and get suggestions)
- `dotfiles-check` (run system checks)
- `whatis <command>` (look up a command)
- `memo` (your personal cheat sheet)

## Notes

- `copy` is the clipboard tool (like Ctrl+C for the terminal).
- `aicopy` is the AI copywriter. Different from `copy`.
- `cyborg` is not a normal AI alias. It is its own tool. See `../bin/cyborg-readme.md`.
- `grep` is changed on purpose to add color (`ggrep --color=auto` when it exists).
- `memo` now points straight to `cheatsheet.sh`. The old `memo.sh` wrapper is gone.
- AI aliases find their scripts through `DOTFILES_ALIAS_ROOT` (falls back to `$HOME/dotfiles`).
- For the full rules and limits, see `../CLAUDE.md`.
