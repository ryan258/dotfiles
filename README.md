# Dotfiles: Brain-Fog-Friendly CLI System

This repository is a shell-first operating system for daily execution, energy-aware pacing, and context recovery. It combines `startday`/`goodevening`, task+journal tracking, health signals, and AI dispatchers into a single workflow designed to reduce drift when brain fog is high.

## What It Does

- Runs a daily execution loop (`startday` -> `status` -> `goodevening`)
- Tracks task, journal, health, and spoon-budget signals in plain text files
- Generates AI coaching with deterministic fallback when models fail/time out
- Captures recent GitHub activity and local context to anchor daily planning
- Provides dispatcher aliases (`tech`, `strategy`, `content`, etc.) for focused AI work

## Source of Truth

- Canonical architecture/behavior contract: `CLAUDE.md`
- Scope guardrails: `GUARDRAILS.md`

All other docs are derived views and must align to `CLAUDE.md`.

## Daily Loop

```bash
startday
status
goodevening
```

## Install Quickstart

```bash
git clone https://github.com/ryan258/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
./bootstrap.sh
dotfiles-check
```

`bootstrap.sh` installs baseline dependencies (`jq`, `curl`, `gawk`), creates the data directory at `~/.config/dotfiles-data`, and sets shell startup paths for this repo.

## Prerequisites

- macOS or Linux with Bash
- `python3` available (used for robust date/time and timeout helpers)
- Homebrew if using `bootstrap.sh` on macOS
- Optional: OpenRouter API key for AI dispatchers

## Quick Start

1. Validate setup: `dotfiles-check`
2. Run morning routine: `startday`
3. Work from `todo top` + `focus`
4. Close day: `goodevening`

## Key Docs

- `docs/start-here.md` - 5-minute orientation
- `docs/happy-path.md` - daily operating flow
- `docs/ai-quick-reference.md` - dispatcher usage
- `docs/system-overview.md` - architecture map
- `TROUBLESHOOTING.md` - common failure modes + fixes
- `CHANGELOG.md` - release history

## Tests

```bash
bats tests/*.sh
```

Run this after script/config changes to validate daily-flow and dispatcher behavior.
