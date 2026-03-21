# Dotfiles: Brain-Fog-Friendly CLI System

A shell-first productivity operating system for daily execution, energy-aware pacing, AI coaching, and automated content generation. Built for a developer with MS — designed to reduce cognitive load and keep things moving when brain fog is high.

## What It Does

- Runs a daily execution loop (`startday` -> `status` -> `goodevening`) with AI coaching and deterministic fallbacks
- Tracks tasks, journal, health, and spoon-budget signals in plain text files
- Provides 13 AI dispatchers (`tech`, `strategy`, `content`, `morphling`, etc.) via OpenRouter API
- Generates grounded AI coaching that validates responses against actual data (rejects hallucinations)
- Automates content generation from source repos via the Cyborg Lab agent
- Offers brain-fog autopilot mode (`ap`, `apb`) — one command, AI does the rest

## Architecture at a Glance

```text
Terminal (zsh)
  -> aliases + functions (zsh/aliases.zsh — ~200 aliases)
  -> 66 CLI scripts (scripts/*.sh)
  -> 21 shared libraries (scripts/lib/*.sh)
  -> 13 AI dispatchers + orchestration (bin/dhp-*.sh)
  -> Cyborg Lab agent (bin/cyborg + scripts/cyborg_agent.py)
  -> Brain/knowledge base (brain/ — ChromaDB vector store)
  -> data (~/. config/dotfiles-data/ — pipe-delimited flat files)
```

## Source of Truth

- Canonical architecture/behavior contract: `CLAUDE.md`
- Scope guardrails: `GUARDRAILS.md`
- Feature roadmap: `ROADMAP.md`

All other docs are derived views and must align to `CLAUDE.md`.

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
- `python3` available (used for Cyborg agent, date/time helpers, and coaching timeout handling)
- Homebrew if using `bootstrap.sh` on macOS
- Optional: OpenRouter API key for AI dispatchers and coaching
- Optional: `uv` for Morphling and ai-staff-hq integration

## Quick Start

```bash
# Daily loop
startday                          # Morning briefing + AI coaching
status                            # Mid-day context recovery
goodevening                       # Evening reflection + backup

# Task management
todo add "Fix the login bug"      # Add a task
todo top                          # Show top priority
focus set "Ship the API"          # Set daily focus

# AI dispatchers
tech "Why is this function slow?" # Technical analysis
strategy "Should I refactor?"     # Strategic advice
morphling "Analyze this repo"     # Universal adaptive specialist

# Autopilot (brain-fog days)
ap                                # Auto-document current repo
apb "a CLI energy tracker"        # Build + document from idea
```

## Key Docs

- `docs/README.md` - Documentation index and 5-minute orientation
- `docs/daily-loop-handbook.md` - Morning, during-day, and evening workflows
- `docs/ai-handbook.md` - AI dispatcher usage and patterns
- `docs/autopilot-happy-path.md` - Low-energy automation cheat sheet
- `docs/general-reference-handbook.md` - Full system reference
- `TROUBLESHOOTING.md` - Common failure modes + fixes
- `CHANGELOG.md` - Release history
- `ROADMAP.md` - Feature roadmap and project status

## Tests

```bash
bats tests/*.sh
```

37 test files covering coaching, dispatchers, cyborg, correlation, context, spoons, time tracking, and syntax validation.
