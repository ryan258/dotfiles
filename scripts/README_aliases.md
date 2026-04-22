# Alias Reference (Derived)

This file is a quick alias map based on `../zsh/aliases.zsh`.
The full rules live in `../CLAUDE.md`.

## Daily Loop Aliases

- `startday`
- `status`
- `goodevening`
- `todo` / `t`
- `idea`
- `journal` / `j`
- `focus`
- `health`
- `spoons`

## Task, Time, and Energy Shortcuts

- `todoadd`, `todolist`, `tododone`
- `t-start`, `t-stop`, `t-status`
- `pomo`, `tbreak`
- `s-check`, `s-spend`
- `daily-report`, `insight`

## Health Correlation Aliases

- `correlate`
- `corr-sleep`
- `corr-steps`
- `corr-rhr`
- `corr-hrv`

## Blog, Data, and Validation

- `blog`, `blog-recent`
- `dump`, `data_validate`
- `dotfiles-check`
- `pdf2md`

## AI Aliases

- `tech`, `content`, `strategy`, `creative`, `brand`, `market`, `research`, `stoic`, `narrative`, `aicopy`, `finance`
- `morphling` -- Swarm-mode Morphling alias; use `bin/morphling.sh` for direct tool-capable mode
- `memory` / `memory-search` -- Save and find things in the knowledge base
- `dhp` -- Default dispatcher alias, points at `tech`
- `dispatch <dispatcher> "brief"` -- Generic router
- `dhp-chain` / `ai-chain` -- Chain specialists
- `dhp-project` / `ai-project` -- Multi-specialist orchestration
- `ai-suggest` -- Context-aware router
- `ai-context` -- Source local context helpers into the shell
- `swipe` -- Run an AI command and save the output
- `cyborg` -- Repo-aware drafting and autopilot agent (not a dispatcher)

## Autopilot Aliases (Brain-Fog Days)

- `ap` -- Auto-document the current repo (Morphling scans it, then Cyborg writes about it)
- `apy` -- Auto-document and auto-confirm all prompts
- `apb "idea"` -- Build a project from an idea, then document it
- `apby "idea"` -- Build, document, and auto-confirm
- `apbp "idea"` -- Build, publish, and document
- `apbpy "idea"` -- Build, publish, document, and auto-confirm
- `apc` -- Pick up where you left off in a past session

## Navigation + Utility

- `g` (jump to folders and get suggestions)
- `whatis <command>` (look up a command)
- `memo` (your personal cheat sheet)
- `cleanup`, `quickbackup`, `devstart`, `gitcheck`

## Notes

- `copy` is the clipboard tool (like Ctrl+C for the terminal).
- `aicopy` is the AI copywriter. Different from `copy`.
- `cyborg` is not a normal AI alias. It is its own tool. See `../bin/cyborg-readme.md`.
- `cyborg-sync` is a `bin/` command, not a shell alias. It is documented in `../docs/cyborg-docs-sync.md`.
- `grep` is changed on purpose to add color (`ggrep --color=auto` when it exists).
- `memo` now points straight to `cheatsheet.sh`. The old `memo.sh` wrapper is gone.
- AI aliases find their scripts through `DOTFILES_ALIAS_ROOT` (falls back to `$HOME/dotfiles`).
- `corr-sleep`, `corr-steps`, `corr-rhr`, and `corr-hrv` resolve their data paths from `${XDG_DATA_HOME:-$HOME/.config}/dotfiles-data`.
- For the full rules and limits, see `../CLAUDE.md`.
