# Alias Reference (Derived)

This file is a quick alias map derived from `../zsh/aliases.zsh`.
Canonical policy lives in `../CLAUDE.md`.

## Core Daily Aliases

- `startday`
- `status`
- `goodevening`
- `todo` / `t`
- `journal` / `j`
- `focus`
- `health`
- `spoons`

## AI Aliases

- `tech`, `content`, `strategy`, `creative`, `brand`, `market`, `research`, `stoic`, `narrative`, `aicopy`, `finance`
- Unified entry: `dispatch <squad> "brief"`

## Navigation + Utility

- `g` (directory navigation/suggestions)
- `dotfiles-check` (system validation)
- `whatis <command>` (command help)

## Notes

- `copy` remains clipboard utility behavior.
- `aicopy` remains AI copywriter dispatcher alias.
- `grep` is intentionally shadowed to force colorized output (`ggrep --color=auto` when available).
- `memo` is now a direct alias to `cheatsheet.sh` (legacy `memo.sh` wrapper removed).
- Dispatcher aliases now resolve through `DOTFILES_ALIAS_ROOT` (fallback: `$HOME/dotfiles`) instead of hardcoded `~/dotfiles` paths.
- For canonical behavior and guardrails, use `../CLAUDE.md`.
