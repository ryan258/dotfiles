# Daily Happy Path

Derived daily flow doc. Canonical behavior is in `../CLAUDE.md`.

## Morning Flow (Low-Friction Start)

Run:

```bash
startday
```

`startday` will walk you through:
- focus check/update
- spoon budget check/update
- yesterday context (journal + commit recap)
- recent pushes and suggested working directories
- stale tasks and top 3 tasks
- AI briefing with deterministic fallback if AI is slow/down

Startday coaching schema:
- `North Star`
- `Do Next (ordered 1-3)`
- `Operating insight (working + drift risk)`
- `Anti-tinker rule`
- `Health lens`
- `Evidence check`

## During-Day Flow (Stay On Rails)

Core loop:

```bash
todo top
status
journal add "what I just did + what's next"
health energy 6
health fog 4
```

Use this cadence:
- Before switching tasks, log one sentence in journal.
- If fog rises or energy drops, shorten work block and re-check `todo top`.
- If you catch yourself tinkering, return to `North Star` and only do step 1.

## Emergency Reset (When You Feel Lost)

If you feel scattered:

```bash
status
todo top
focus
```

Then do only one thing:
- run one 10-15 minute block on top task
- add one journal line when done

## Evening Closeout (Preserve Tomorrow Context)

Run:

```bash
goodevening
```

`goodevening` summarizes wins, checks project safety, validates data, runs backup, and generates AI reflection.

Goodevening coaching schema:
- `What worked`
- `Where drift happened`
- `Likely trigger`
- `Tomorrow lock`
- `Health lens`
- `Evidence used`

`Tomorrow lock` should always include:
- first move
- done condition
- anti-tinker boundary

## Refresh Modes

```bash
startday refresh
startday refresh --clear-github-cache
```

- `refresh`: clears AI briefing cache only
- `--clear-github-cache`: clears both AI + GitHub caches

## Coach Config (.env)

```bash
AI_BRIEFING_ENABLED=true
AI_REFLECTION_ENABLED=true
AI_BRIEFING_TEMPERATURE=0.25
AI_COACH_LOG_ENABLED=true
AI_COACH_TACTICAL_DAYS=7
AI_COACH_PATTERN_DAYS=30
AI_COACH_MODE_DEFAULT=LOCKED
AI_COACH_REQUEST_TIMEOUT_SECONDS=35
AI_COACH_RETRY_ON_TIMEOUT=true
AI_COACH_RETRY_TIMEOUT_SECONDS=90
AI_COACH_DRIFT_STALE_TASK_DAYS=7
COACH_LOG_FILE="$HOME/.config/dotfiles-data/coach_log.txt"
COACH_MODE_FILE="$HOME/.config/dotfiles-data/coach_mode.txt"
```

## Data Files Used By Coaching

- `~/.config/dotfiles-data/todo.txt`
- `~/.config/dotfiles-data/todo_done.txt`
- `~/.config/dotfiles-data/journal.txt`
- `~/.config/dotfiles-data/health.txt`
- `~/.config/dotfiles-data/spoons.txt`
- `~/.config/dotfiles-data/coach_mode.txt`
- `~/.config/dotfiles-data/coach_log.txt`
