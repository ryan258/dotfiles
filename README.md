# Dotfiles Productivity System

This repo is a command-line productivity environment built around shell scripts, AI dispatchers, daily routines, and repo-aware automation. It is designed for brain-fog-friendly work: short commands, deterministic fallbacks, and strong support for context recovery.

## What It Covers

- Daily coaching and check-ins with `startday`, `status`, and `goodevening`
- Task, journal, focus, reminder, and time-tracking workflows
- Health, meds, spoon-budget, and Fitbit/Google Health tracking
- Optional Obsidian Observer integration via `~/Projects/obsidian-observer`
- Optional Blog Factory integration via `~/Projects/blog-factory`
- AI dispatchers for coding, strategy, writing, research, memory, and orchestration
- Repo-aware agents for project documentation, build-and-verify loops, and site sync
- Optional AI Staff HQ integration via `AI_STAFF_DIR`
- Local flat-file data under `~/.config/dotfiles-data/`

## Current Inventory

Generated inventory docs are the source of truth for repo counts:

- `docs/generated/baseline-metrics.md` - frozen Phase 0 baseline and numeric exit gates
- `docs/generated/script-inventory.md` - script, library, `bin/`, and dispatcher inventory
- `docs/generated/alias-inventory.md` - alias classes and shell functions
- `docs/generated/test-coverage-map.md` - test inventory and daily-loop coverage map
- `docs/generated/external-dependencies.md` - optional service and credential-like config surface

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
- `cyborg` and `cyborg-sync` are compatibility wrappers for the optional `~/Projects/cyborg-agent` sibling repo.
- `blog` and `blog-recent` are compatibility wrappers for the optional `~/Projects/blog-factory` sibling repo.

## Documentation Map

- `docs/README.md` - Central index for all user-facing docs
- `docs/daily-loop-handbook.md` - Morning, midday, and evening routines
- `docs/ai-handbook.md` - AI command surface, routing, and repo-aware agents
- `docs/ai-staff-hq-boundary.md` - AI Staff HQ optional product boundary
- `docs/blog-factory-boundary.md` - Blog Factory optional product boundary
- `docs/library-loading.md` - Shell library loading strategy
- `docs/artifact-log-policy.md` - Runtime artifact and log policy
- `scripts/README.md` - Script inventory and command groups
- `scripts/README_aliases.md` - Alias map from `zsh/aliases.zsh`
- `bin/README.md` - Dispatcher and agent entry points in `bin/`
- `bin/cyborg-readme.md` - Cyborg sibling repo boundary
- `bin/autopilot-readme.md` - Cyborg autopilot boundary
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
