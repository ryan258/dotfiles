# Documentation Index

This folder is the entry point for the root `dotfiles` documentation. Use it as the map for the repo's daily workflows, AI tooling, repo-aware agents, and troubleshooting guides.

## Current Inventory Snapshot

Current root-repo counts as of April 23, 2026:

- `scripts/`: 73 shell utilities plus 5 Python helpers
- `scripts/lib/`: 25 sourced shell libraries plus 2 Python modules
- `bin/`: 30 non-markdown entry points, including 21 `dhp-*.sh` executables
- `tests/`: 49 Bats test files

## Start Here

```bash
dotfiles-check
startday
todo top
status
goodevening
```

Low-energy day:

```bash
ap
```

## Core Guides

### [Daily Loop Handbook](daily-loop-handbook.md)

Use this first if you want the operational routine:

- morning, midday, and evening check-ins
- focus, todo, journal, and health flow
- reset and recovery patterns for brain-fog days

### [AI Handbook](ai-handbook.md)

Use this when you need the AI command map:

- dispatcher aliases such as `tech`, `strategy`, and `content`
- orchestration commands such as `dispatch`, `ai-project`, and `ai-chain`
- Brain commands such as `memory` and `memory-search`
- repo-aware agents such as `cyborg`, `cyborg-sync`, and autopilot aliases

### [General Reference Handbook](general-reference-handbook.md)

Use this for the high-level architecture and the cross-cutting mental model:

- daily coaching flow
- Cyborg and autopilot overview
- Brain and data contracts
- MS-friendly design principles

## Command Guides

### [scripts/README.md](../scripts/README.md)

Current command inventory and script-group coverage for `scripts/`.

### [scripts/README_aliases.md](../scripts/README_aliases.md)

Alias map derived from `zsh/aliases.zsh`.

### [bin/README.md](../bin/README.md)

Dispatcher and agent entry points under `bin/`.

## Cyborg, Autopilot, and Site Sync

### [Autopilot Easy Mode](autopilot-happy-path.md)

Shortest path for `ap`, `apy`, `apb`, `apbp`, and resume flows.

### [Autopilot Architecture](../bin/autopilot-readme.md)

Detailed Morphling + Cyborg pipeline behavior for existing repos, iterate mode, build mode, and publish mode.

### [Cyborg Agent Wiki](../bin/cyborg-readme.md)

Interactive Cyborg usage, mental model, and session lifecycle.

### [Cyborg Docs Sync](cyborg-docs-sync.md)

Manifest-driven `cyborg-sync` workflow for repeatable project-to-site updates.

### [Cyborg Project-to-Site Playbook](cyborg-project-to-site-playbook.md)

End-to-end workflow from local repo to mapped site pages.

### [Morphling](../MORPHLING.md)

Direct vs swarm Morphling modes and build-pipeline usage.

## Brain and Memory

### [Brain Handbook](../brain/HANDBOOK.md)

Shared vector-store memory, ingestion, and recall.

### [brain/README.md](../brain/README.md)

Quick-start view of Brain service layout and CLI usage.

## Troubleshooting and Planning

### [Troubleshooting](../TROUBLESHOOTING.md)

Repair steps for missing commands, API keys, GitHub tokens, and shell issues.

### [Energy Road Map](ROADMAP-ENERGY.md)

Choose work based on current energy instead of deadline pressure.

### [Archive Phases](archive/phases.md)

Historical planning and masterplan context.

## Scope and Rules

- `../GUARDRAILS.md` chooses the correct scope (`dotfiles` root vs `ai-staff-hq/`).
- `../CLAUDE.md` is the canonical root-project contract.
- `../AGENTS.md` is the aligned operational checklist for AI coding assistants.
