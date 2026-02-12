# Project Guardrails

> [!IMPORTANT]
> **READ THIS FIRST**: This repository contains multiple scopes with different rules.
> Applying the wrong rules to the wrong directory will break the build or violate design standards.

## 1. Scope and Precedence

| Path           | Primary Guide           | Key Restrictions                                                                  |
| -------------- | ----------------------- | --------------------------------------------------------------------------------- |
| `.` (Root)     | `CLAUDE.md`             | **CLI Framework only**. No Web UI themes. Bash strict mode (`set -euo pipefail`). |
| `ai-staff-hq/` | `ai-staff-hq/CLAUDE.md` | **Candlelite Theme REQUIRED** for UI. Python/LangGraph architecture.              |

## 2. Root Project (`dotfiles`)

The root directory is a **command-line productivity environment**.

- **DO NOT** apply "Candlelite Theme" to bash scripts.
- **DO NOT** assume Python UI libraries are available in core scripts.
- **DO** follow the "No-Bloat" layout defined in `CLAUDE.md`.

## 3. Submodules (`ai-staff-hq`)

The `ai-staff-hq` directory is a **distinct web application** submodule.

- It has its own isolated requirements.
- When working inside `ai-staff-hq/`, you **MUST** follow `ai-staff-hq/CLAUDE.md`.
- **Candlelite Theme** is mandatory for all visual components in this submodule.

## 4. Conflict Resolution

If a rule in `ai-staff-hq/CLAUDE.md` conflicts with `CLAUDE.md` (e.g., UI colors vs CLI text), **scope wins**.

- Are you editing a file in `ai-staff-hq/`? -> Follow `ai-staff-hq/CLAUDE.md`.
- Are you editing a script in `scripts/`? -> Follow `CLAUDE.md`.
