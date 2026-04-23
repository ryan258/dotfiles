# Dotfiles Productivity System

This repo is a command-line productivity environment built around shell scripts, AI dispatchers, daily routines, and repo-aware automation. It is designed for brain-fog-friendly work: short commands, deterministic fallbacks, and strong support for context recovery.

## What It Covers

- Daily coaching and check-ins with `startday`, `status`, and `goodevening`
- Task, journal, focus, reminder, and time-tracking workflows
- Health, meds, spoon-budget, and Fitbit/Google Health tracking
- AI dispatchers for coding, strategy, writing, research, memory, and orchestration
- Repo-aware agents for project documentation, build-and-verify loops, and site sync
- Local flat-file data under `~/.config/dotfiles-data/`

## Current Inventory Snapshot

This snapshot reflects the root repo as audited on April 23, 2026:

- `scripts/`: 76 shell utilities plus 5 Python helpers
- `scripts/lib/`: 25 sourced libraries
- `bin/`: 28 non-markdown entry points, including 21 `dhp-*.sh` executables
- `tests/`: 47 Bats test files

## Install

```bash
git clone https://github.com/ryan258/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
./bootstrap.sh
dotfiles-check
```

`bootstrap.sh` wires the repo into your shell and makes the command aliases available.

## Requirements

- macOS or Linux
- Bash and Python 3
- `OPENROUTER_API_KEY` in `.env` for AI-powered commands
- Optional GitHub token support for GitHub-aware routines and market validation

## Fast Commands To Try

```bash
# Daily loop
startday
status
goodevening

# Tasks and focus
todo add "Fix the login bug"
todo top
focus set "Ship the API"
journal add "Stopped at parser error handling"
todo stale                              # Show tasks older than threshold
journal rel                             # Show focus-related journal entries
drive recent                            # Recent Drive docs matching current focus

# Health and energy
health energy 6
health fog 4
s-check

# AI commands
tech "Why is this crashing?"
strategy "What is the smallest next step?"
memory "Remember that the repo uses Google Health sync"

# Repo-aware automation
cyborg auto
ap
apb "CLI that tracks daily energy with spoon theory"
cyborg-sync --repo ~/Projects/my-project plan
```

## AI and Automation

- `tech`, `content`, `strategy`, `creative`, `brand`, `market`, `research`, `stoic`, `narrative`, `aicopy`, and `finance` are the main dispatcher aliases.
- `memory` and `memory-search` are optional Brain commands for the standalone ChromaDB memory store; they are not part of the default daily coaching path.
- `morphling` is the swarm-mode alias; `bin/morphling.sh` is the direct tool-capable launcher.
- `cyborg` handles repo-aware drafting and autopilot flows.
- `cyborg-sync` is the non-interactive docs-maintenance worker for mapped site pages.

## Documentation Map

- `docs/README.md` - Central index for all user-facing docs
- `docs/daily-loop-handbook.md` - Morning, midday, and evening routines
- `docs/ai-handbook.md` - AI command surface, routing, and repo-aware agents
- `scripts/README.md` - Script inventory and command groups
- `scripts/README_aliases.md` - Alias map from `zsh/aliases.zsh`
- `bin/README.md` - Dispatcher and agent entry points in `bin/`
- `bin/cyborg-readme.md` - Interactive Cyborg workflow
- `bin/autopilot-readme.md` - Morphling + Cyborg autopilot architecture
- `MORPHLING.md` - Direct vs swarm Morphling modes
- `brain/HANDBOOK.md` - Brain knowledge-base usage
- `TROUBLESHOOTING.md` - Common failures and repair steps

## Rules and Scope

- `GUARDRAILS.md` decides whether work belongs in root `dotfiles` or `ai-staff-hq/`.
- `CLAUDE.md` is the canonical root-project contract.
- `AGENTS.md` is the operational checklist aligned with `CLAUDE.md`.

## Testing

Run the Bats suite with:

```bash
bats tests/*.sh
```

For recent changes and doc updates, see `CHANGELOG.md`.
