# Alias Reference (Derived)

This file is a quick alias map derived from `../zsh/aliases.zsh`.
Canonical policy lives in `../CLAUDE.md`.

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
- `morphling` — Universal adaptive specialist (interactive mode via `morphling.sh`)
- `memory` / `memory-search` — Knowledge base store and recall
- Unified entry: `dispatch <squad> "brief"`
- Orchestration: `dhp-chain`, `dhp-project`, `ai-suggest`
- `cyborg` — Dedicated Cyborg Lab ingest/resume agent (not a dispatcher)

## Autopilot Aliases (Brain-Fog Days)

- `ap` — Auto-document current repo (Morphling pre-analysis + Cyborg pipeline)
- `apy` — Auto-document, auto-confirm all prompts
- `apb "idea"` — Build + document a project from an idea
- `apby "idea"` — Build + document, auto-confirm
- `apc` — Continue/resume a previous autopilot session

## Navigation + Utility

- `g` (directory navigation/suggestions)
- `dotfiles-check` (system validation)
- `whatis <command>` (command help)
- `memo` (personal cheatsheet)

## Notes

- `copy` remains clipboard utility behavior.
- `aicopy` remains AI copywriter dispatcher alias.
- `cyborg` is not a general dispatcher alias; it is a standalone repo agent documented in `../bin/cyborg-readme.md`.
- `grep` is intentionally shadowed to force colorized output (`ggrep --color=auto` when available).
- `memo` is now a direct alias to `cheatsheet.sh` (legacy `memo.sh` wrapper removed).
- Dispatcher aliases now resolve through `DOTFILES_ALIAS_ROOT` (fallback: `$HOME/dotfiles`) instead of hardcoded `~/dotfiles` paths.
- For canonical behavior and guardrails, use `../CLAUDE.md`.
