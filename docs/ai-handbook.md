# AI Handbook

This repo exposes more than one kind of AI command. Some commands are simple one-shot dispatchers, some orchestrate multiple specialists, some read and write the optional Brain knowledge base, and some are repo-aware agents with their own workflows.

## Core Dispatchers

These aliases route to the `dhp-*.sh` dispatcher family in `bin/`:

- `tech` - technical and coding help
- `content` - long-form writing and content strategy
- `strategy` - planning, prioritization, and decision support
- `creative` - ideation and storytelling
- `brand` - voice and positioning
- `market` - market research and competitor framing
- `research` - deep reading and synthesis
- `stoic` - mindset and reflection
- `narrative` - story and structure work
- `aicopy` - copywriting
- `finance` - finance and tax-oriented prompting

Examples:

```bash
tech "Why is this shell script failing on macOS?"
content --stream "Outline a guide for low-energy developer workflows."
strategy "What is the smallest next step for this repo?"
```

## Morphling

There are two Morphling entry paths:

- `morphling` is the swarm-mode alias backed by `bin/dhp-morphling.sh`
- `bin/morphling.sh` is the direct tool-capable launcher

Use swarm mode when you want one-shot context-rich analysis. Use direct mode when you want the lead-developer flow that can read files, write files, list directories, and run shell commands.

Examples:

```bash
morphling "Analyze this repo's error-handling style."
bin/morphling.sh "Refactor this module to use dependency injection."
bin/morphling.sh --resume last
```

See `../MORPHLING.md` for the full mode breakdown.

## Memory and Recall

These commands integrate with the optional shared Brain knowledge base:

- `memory` - store a fact, decision, or pattern
- `memory-search` - semantically search stored memories

Examples:

```bash
memory "The coaching stack uses Google Health sync, not legacy Fitbit API sync."
memory-search "coach mode thresholds"
```

See `../brain/HANDBOOK.md` for Brain details.
The Brain store is currently a manual/experimental path exposed through `memory` and `memory-search`; the daily coach does not depend on it.

## Routing and Orchestration Commands

These commands help choose, route, or chain AI work:

- `dhp` - default dispatcher alias, points to `tech`
- `dispatch <dispatcher> "brief"` - generic dispatcher router
- `ai-project` / `dhp-project` - multi-specialist orchestration
- `ai-chain` / `dhp-chain` - pipe one specialist into another
- `ai-suggest` - context-aware AI suggestion helper
- `ai-context` - sourced helper for gathering local context
- `swipe` - run an AI command and save the output

Examples:

```bash
dispatch strategy "Plan a weekly review flow for this repo."
dhp-chain market brand -- "Positioning for an accessibility-focused CLI"
ai-project "Create a launch plan for a new utility script."
swipe tech "Explain this stack trace and suggest a fix."
```

## Repo-Aware Agents

These are not simple dispatchers. They have their own workflows and state.

### `cyborg`

Use `cyborg` when you want repo-aware drafting, project analysis, or autopilot flows.

Key paths:

- `cyborg ingest` - interactive Cyborg session
- `cyborg auto` - code-first autopilot on an existing repo
- `cyborg auto --iterate` - pick the next GitHub issue or backlog item and implement it
- `cyborg auto --build` - scaffold a new project from an idea, verify it, then continue
- `cyborg resume` - reopen a saved session

Examples:

```bash
cyborg ingest --repo ~/Projects/my-project
cyborg auto --iterate --repo ~/Projects/my-project
cyborg auto --build "CLI that tracks daily energy with spoon theory"
```

See `../bin/cyborg-readme.md` and `../bin/autopilot-readme.md`.

### `cyborg-sync`

Use `cyborg-sync` when the repo is already real and you want repeatable docs maintenance for mapped site pages.

Examples:

```bash
cyborg-sync --repo ~/Projects/my-project plan
cyborg-sync --repo ~/Projects/my-project sync --dry-run
cyborg-sync --repo ~/Projects/my-project sync --commit
```

See `cyborg-docs-sync.md` and `cyborg-project-to-site-playbook.md`.

## Autopilot Aliases

These shortcuts all route into `cyborg auto`:

- `ap` - autopilot the current repo
- `apy` - autopilot and auto-confirm
- `apb "idea"` - build from an idea, then continue
- `apby "idea"` - build and auto-confirm
- `apbp "idea"` - build, publish, and continue
- `apbpy "idea"` - build, publish, and auto-confirm
- `apc` - resume the last autopilot or Cyborg session

See `autopilot-happy-path.md` for the shortest cheat sheet.

## Blog and Coaching Integration

- Daily briefings call `dhp-coach.sh` internally; that coach path is optimized for the daily loop rather than general manual use.
- The coach behavior digest now incorporates strategy evidence from focus-related journal entries and Drive document activity, so zero-commit planning days are recognized as real progress.
- `blog.sh` is the blog-management CLI. It can use personas and AI-generated content, but it is not a dispatcher alias itself.

## Usage Patterns

Quick prompt:

```bash
strategy "Should I rest today or finish one small task?"
```

Streaming output:

```bash
content --stream "Write a guide about recovering context after interruptions."
```

Pipe a file into a dispatcher:

```bash
cat broken-script.sh | tech
```

Chain two specialists:

```bash
dhp-chain creative aicopy -- "A story about brain fog and recovery"
```

## Setup Notes

- Set `OPENROUTER_API_KEY` in `.env` for AI-powered commands.
- Some repo-aware flows also benefit from GitHub token access.
- `copy` is the clipboard alias. `aicopy` is the AI copywriter. They are intentionally different.
- If you are unsure which command to use, start with `ai-suggest`, `strategy`, or `tech` depending on the task.
