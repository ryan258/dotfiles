# Documentation Index

This folder is the entry point for the root `dotfiles` documentation. Use it as the map for the repo's daily workflows, AI tooling, repo-aware agents, and troubleshooting guides.

## Current Inventory

Generated inventory docs are the source of truth for root-repo counts:

- [baseline-metrics.md](generated/baseline-metrics.md) - frozen Phase 0 baseline and numeric exit gates
- [script-inventory.md](generated/script-inventory.md) - script, library, `bin/`, and dispatcher inventory
- [alias-inventory.md](generated/alias-inventory.md) - alias classes and shell functions
- [test-coverage-map.md](generated/test-coverage-map.md) - test inventory and daily-loop coverage map
- [external-dependencies.md](generated/external-dependencies.md) - optional service and credential-like config surface

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
- AI Staff HQ optional product boundary
- Blog Factory optional product boundary
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

Boundary note for shortcuts now implemented by `~/Projects/cyborg-agent`.

### [Autopilot Architecture](../bin/autopilot-readme.md)

Boundary note for the extracted autopilot guide.

### [Cyborg Agent Wiki](../bin/cyborg-readme.md)

Boundary note for the extracted Cyborg agent guide.

### [Cyborg Docs Sync](cyborg-docs-sync.md)

Boundary note for the extracted `cyborg-sync` workflow.

### [Cyborg Project-to-Site Playbook](cyborg-project-to-site-playbook.md)

Boundary note for the extracted project-to-site playbook.

### [Morphling](../MORPHLING.md)

Direct vs swarm Morphling modes and build-pipeline usage.

### [AI Staff HQ Boundary](ai-staff-hq-boundary.md)

Optional product boundary for `AI_STAFF_DIR`, dispatcher swarms, and Morphling.

### [Blog Factory Boundary](blog-factory-boundary.md)

Optional product boundary for `BLOG_FACTORY_HOME`, `blog`, and `blog-recent`.

## Brain and Memory

### [Obsidian Observer Boundary](obsidian-knowledge-graph-framework.md)

Dotfiles compatibility note for the extracted Observer product:

- sibling repo lives at `~/Projects/obsidian-observer`
- `observer` alias and `scripts/observer.sh` wrapper stay in dotfiles
- daily hooks degrade quietly when the optional product is missing

### [Brain Handbook](../brain/HANDBOOK.md)

Shared vector-store memory, ingestion, and recall.

### [brain/README.md](../brain/README.md)

Quick-start view of Brain service layout and CLI usage.

## Troubleshooting and Planning

### [Library Loading](library-loading.md)

The current caller-owned shell loading strategy and the transitional `common.sh` bootstrap exception.

### [Artifact And Log Policy](artifact-log-policy.md)

Runtime artifact locations, log rotation, and cleanup behavior.

### [Troubleshooting](../TROUBLESHOOTING.md)

Repair steps for missing commands, API keys, GitHub tokens, and shell issues.

### [Energy Road Map](ROADMAP-ENERGY.md)

Choose work based on current energy instead of deadline pressure.

### [Karpathy Protocol for Dotfiles](kplan.md)

Low-bandwidth operator handbook for delegating execution to agents while using bash-intel, `rg`, tests, and diffs for blast-radius review.

### [Archive Phases](archive/phases.md)

Historical planning and masterplan context.

## Scope and Rules

- `../GUARDRAILS.md` chooses the correct scope (`dotfiles` root vs `ai-staff-hq/`).
- `../CLAUDE.md` is the canonical root-project contract.
- `../AGENTS.md` is the aligned operational checklist for AI coding assistants.
