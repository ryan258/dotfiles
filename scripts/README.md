# scripts/ Overview

Derived operational guide for `scripts/`.
Canonical architecture and policy live in `../CLAUDE.md`.

## Daily Commands

- `startday.sh`
- `status.sh`
- `goodevening.sh`
- `todo.sh`
- `idea.sh`
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
- Drift and health thresholds (`COACH_*_THRESHOLD`) are defined in `config.sh` and overridable via `.env`.
- `startday.sh` and `goodevening.sh` consume structured digest data, persist coaching outcomes, and display signal confidence with explicit missing/sparse source reasons.
- `status.sh` shows current coach mode, spoon budget/depletion, focus text, and a low-latency (tasks-only) focus coherence signal in a DAILY CONTEXT section.

## Data Location

All runtime data is under:

- `~/.config/dotfiles-data/`

Key files include:

- `todo.txt`, `todo_done.txt`
- `ideas.txt`
- `journal.txt`
- `health.txt`, `spoons.txt`
- `coach_mode.txt`, `coach_log.txt`, `coach_adherence.txt`
