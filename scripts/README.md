# scripts/ Overview

Derived operational guide for `scripts/`.
Canonical architecture and policy live in `../CLAUDE.md`.

## Daily Commands

- `startday.sh`
- `status.sh`
- `goodevening.sh`
- `todo.sh`
- `journal.sh`
- `health.sh`
- `focus.sh`

## Library Contracts

- Libraries in `scripts/lib/*.sh` are sourced and must not set strict mode.
- Executed scripts use `#!/usr/bin/env bash` + `set -euo pipefail`.
- Data writes require sanitized input and validated paths.

## Coaching Runtime

- `scripts/lib/coach_ops.sh` validates coaching runtime dependencies.
- `scripts/lib/coach_metrics.sh`, `scripts/lib/coach_prompts.sh`, and `scripts/lib/coach_scoring.sh` provide metrics, prompt construction, timeout-guarded AI calls, mode persistence, and append-only coaching logs.
- `startday.sh` and `goodevening.sh` consume structured digest data and persist coaching outcomes.

## Data Location

All runtime data is under:
- `~/.config/dotfiles-data/`

Key files include:
- `todo.txt`, `todo_done.txt`
- `journal.txt`
- `health.txt`, `spoons.txt`
- `coach_mode.txt`, `coach_log.txt`
