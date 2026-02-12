# System Overview

This is a derived architecture view. Canonical contracts live in `../CLAUDE.md`.

## Architecture

```text
Terminal (zsh)
  -> aliases + wrappers (`zsh/aliases.zsh`)
  -> scripts (`scripts/*.sh`)
  -> AI dispatchers (`bin/dhp-*.sh`, `bin/dispatch.sh`)
  -> data (`~/.config/dotfiles-data/*`)
```

## Daily Coaching Flow

```text
startday
  -> gather focus/tasks/journal/health/git signals
  -> build deterministic behavior digest (coach_ops)
  -> call strategy dispatcher with timeout guard
  -> fallback to deterministic schema if unavailable

goodevening
  -> gather today outcomes + same digest
  -> call strategy dispatcher with timeout guard
  -> fallback to deterministic schema if unavailable
```

## Data Contracts

- `coach_mode.txt`: `YYYY-MM-DD|LOCKED|source` or `YYYY-MM-DD|OVERRIDE|source`
- `coach_log.txt`: `TYPE|TIMESTAMP|DATE|MODE|FOCUS|METRICS|OUTPUT`
- Core daily files:
  - `todo.txt`
  - `todo_done.txt`
  - `journal.txt`
  - `health.txt`
  - `spoons.txt`

## Reliability Rules

- Coaching calls are timeout-bounded.
- Timeout/error/missing dispatcher returns deterministic structured output.
- User input is sanitized before persistence.
- Paths are validated before file writes.
