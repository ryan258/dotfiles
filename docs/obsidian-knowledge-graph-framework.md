# Obsidian Knowledge Graph Framework

This is the operating guide for the dotfiles-to-Obsidian framework.

The framework turns shell activity, unfinished work, project context, workflows, and web clips into a local Markdown knowledge graph at:

```text
~/Documents/Obsidian/ryan-vault
```

The goal is not to write more notes by hand. The goal is to leave a mechanical trail while you work, then let Codex promote only the useful pieces into durable graph nodes.

## Architecture

The system has six layers:

```text
raw events
  -> daily notes
  -> open loops and explorations
  -> projects and workflows
  -> web clips and source notes
  -> graph maps and graph checks
```

Each layer has a different job:

| Layer | Path | Job |
| --- | --- | --- |
| Command events | `raw/events/` | Append-only shell telemetry |
| Daily notes | `daily/` | The day-level digest and review surface |
| Open loops | `raw/open-loops/`, `wiki/open-loops/` | Unfinished work with dedupe and resolution proposals |
| Explorations | `raw/explorations/` | Temporary side quests with TTL review |
| Projects | `wiki/projects/` | Repo-level graph hubs |
| Workflows | `wiki/workflows/` | Repeated exact command sequences |
| Concepts | `wiki/concepts/` | User-explicit ideas only |
| Web clips | `raw/web-clips/` | Raw external evidence from Obsidian Web Clipper |
| Sources | `wiki/sources/` | Citation-backed summaries promoted from clips |
| Maps | `maps/` | Navigable indexes and graph dashboards |

## Ownership Rules

Follow the fenced ownership model.

Observer owns:

```markdown
<!-- observer:start ... -->
<!-- observer:end ... -->
```

Codex owns:

```markdown
<!-- codex:start ... -->
<!-- codex:end ... -->
```

User owns:

```markdown
<!-- user:start ... -->
<!-- user:end ... -->
```

Do not manually edit observer blocks. Do not let Codex rewrite user-owned prose. Durable notes should be promoted or updated through explicit commands after review.

## Daily Use

Start the day normally:

```bash
startday
```

This now also runs:

```bash
observer startday
```

That creates or updates the daily note and surfaces accepted/surfaced open loops.

Refresh the daily digest whenever useful:

```bash
observer digest
```

The daily note gets these important sections:

```markdown
## Commands
## Significant Events
## Repo Activity
## Open Loops
## Explorations
## Promotion Candidates
## Memory
## Notes
```

`Repo Activity` is load-bearing for V2. It contains mechanical lines like:

```markdown
- Repo: `/Users/ryanjohnson/Projects/dotfiles`
```

Only repo markers inside the observer `repos` block count for project promotion.

## Markers You Can Type

Use these in daily `Notes` or relevant wiki notes.

| Marker | Meaning |
| --- | --- |
| `- [loop] define redaction tests` | Create an open-loop candidate |
| `- [explore] sketch observer UI` | Create a 24-hour exploration sandbox |
| `#promote/source` | Mark a raw web clip for source review |
| `#concept/context-recovery` | Literal concept tag counted for concept candidates |
| `[[raw/web-clips/...]]` | Link a raw clip into the graph and make it a source candidate |

## Open Loops

Open-loop raw state is canonical:

```text
raw/open-loops/*.jsonl
```

Wiki notes are synced views:

```text
wiki/open-loops/*.md
```

Common commands:

```bash
observer open-loop-accept "dotfiles::command-failure::uv-run-pytest" --date 2026-05-11
observer open-loop-resolve "dotfiles::command-failure::uv-run-pytest" --date 2026-05-12 --evidence "pytest passed"
observer open-loop-archive "dotfiles::command-failure::uv-run-pytest" --date 2026-05-26
```

Best practice:

1. Let observer propose candidates.
2. Accept only loops you actually want surfaced.
3. Let passing commands or removed TODOs propose resolution.
4. Resolve/archive through Codex after approval.

## Explorations

Explorations are temporary side quests.

Create one explicitly:

```markdown
- [explore] sketch web clipper source review UI
```

Review actions:

```bash
observer exploration-action "2026-05-11::daily::sketch-web-clipper-source-review-ui" --action extend --date 2026-05-11
observer exploration-action "2026-05-11::daily::sketch-web-clipper-source-review-ui" --action archive --date 2026-05-12
observer exploration-action "2026-05-11::daily::sketch-web-clipper-source-review-ui" --action convert --date 2026-05-12 --evidence "Turn this into a follow-up"
```

Use explorations to protect focus without losing valid side quests.

## Projects

Projects are repo-level graph hubs in:

```text
wiki/projects/
```

A project becomes a candidate when:

- the repo appears in 3 daily repo blocks within 14 days,
- the repo has accepted/surfaced open loops,
- or the repo has a burst of 20+ meaningful commands in 4 hours.

Review candidates:

```bash
observer graph candidates --date 2026-05-11
```

Create a project after approval:

```bash
observer project-note ~/Projects/dotfiles --date 2026-05-11 --description "Personal operating system and Obsidian observer."
```

Refresh an existing project:

```bash
observer project-note ~/Projects/dotfiles --date 2026-05-12 --update
```

Project notes maintain observer blocks for:

- active work,
- top commands,
- accepted/surfaced open loops,
- related workflows.

## Workflows

V2 workflows are exact command sequences, not themes.

A workflow candidate appears when the same full sequence of meaningful command keys appears in the same repo on 3 distinct days.

Example:

```text
startday -> status -> focus
```

Create a workflow after approval:

```bash
observer workflow-note --sequence "startday,status,focus" --repo ~/Projects/dotfiles --date 2026-05-11
```

Workflow notes live in:

```text
wiki/workflows/
```

They show:

- linked command pattern,
- recent daily notes where the exact sequence appeared,
- related command notes.

V2 intentionally does not do subsequence mining. If three days are:

```text
startday -> status -> focus -> journal
startday -> status -> focus -> todo
startday -> status -> focus -> blog
```

that creates no workflow candidate in V2.

## Concepts

Concept notes are user-explicit only.

Allowed:

```bash
observer concept-note --title "Context Recovery" --related "[[wiki/projects/dotfiles|dotfiles]]" --date 2026-05-11
```

Allowed from tags after review:

```bash
observer graph concept-tags --date 2026-05-11
```

If `#concept/context-recovery` appears in 3+ notes and no concept note exists, Codex can ask whether to create it.

Not allowed:

- automatic theme extraction,
- concept notes from prose similarity,
- rewriting user-owned concept prose.

When adding source-backed claims to an existing concept, Codex only touches:

```markdown
<!-- codex:start sourced-claims -->
<!-- codex:end sourced-claims -->
```

Example:

```bash
observer concept-note \
  --title "Context Recovery" \
  --slug context-recovery \
  --related "[[wiki/projects/dotfiles|dotfiles]]" \
  --sourced-claim "Reentry should be cheap from [[wiki/sources/context-recovery-source|source]]." \
  --update
```

## Web Clipper Setup

Configure Obsidian Web Clipper to write only under:

```text
raw/web-clips/
```

Use one of these subfolders:

```text
raw/web-clips/articles/
raw/web-clips/videos/
raw/web-clips/docs/
raw/web-clips/references/
```

Filename rule:

```text
YYYY-MM-DD-domain-title
```

Required raw clip shape:

```markdown
---
type: web-clip
status: raw
title: Page Title
url: https://example.com/page
site: example.com
author:
published:
clipped: YYYY-MM-DD
clip_type: article
tags:
  - source
---

# Page Title

## Source
- URL: https://example.com/page
- Site: example.com
- Author:
- Published:
- Clipped: YYYY-MM-DD

## Highlights
Captured highlights or selected text.

## Raw Content
Clipped page content.

## Processing Notes
<!-- codex:start notes -->
<!-- codex:end notes -->
```

Allowed `clip_type` values:

```text
article
video
docs
reference
```

For videos, avoid pasting huge transcripts. Capture metadata, highlights, and short summaries.

## Source Review

Update the source index:

```bash
observer source-index
```

Source candidates appear when:

- the raw clip has `#promote/source`,
- a daily/project/workflow/concept note links to `[[raw/web-clips/...]]`,
- or Codex is asked to review recent clips through `observer graph source-candidates`.

Review candidates:

```bash
observer graph source-candidates --date 2026-05-11
```

Promote a raw clip after approval:

```bash
observer source-note \
  --clip "raw/web-clips/articles/2026-05-11-example-com-context-recovery.md" \
  --date 2026-05-11 \
  --claim "Reentry should be cheap." \
  --supports "[[wiki/concepts/context-recovery|context recovery]]" \
  --caveats "Single-source claim."
```

The same raw clip cannot be promoted twice. If a Source note already preserves that `source_clip`, the command exits and asks you to work from the existing note instead of silently creating duplicates.

Source notes live in:

```text
wiki/sources/
```

A Source note must preserve:

- `source_url`,
- `source_clip`,
- short claim summary,
- caveats.

It should not copy the entire article into `wiki/sources/`.

## Stale Clips

Raw clips are stale when they are:

- older than 30 days,
- not tagged `#promote/source`,
- not linked from daily/project/workflow/concept notes.

Check stale clips:

```bash
observer graph stale-clips --date 2026-05-11
```

Archive after review:

```bash
observer source-archive --clip "raw/web-clips/articles/2026-03-01-example-com-old.md" --date 2026-05-11
```

This moves the clip to:

```text
raw/web-clips/archive/
```

## Maps

Generated map indexes:

```text
maps/project-index.md
maps/workflow-index.md
maps/source-index.md
maps/memory-index.md
```

Observer owns the mechanical fenced blocks inside these maps. You can annotate around them in user-owned note blocks.

## Graph Checks

Use graph checks as a maintenance dashboard.

```bash
observer graph candidates --date 2026-05-11
observer graph orphans --date 2026-05-11
observer graph broken-links --date 2026-05-11
observer graph stale --date 2026-05-11
observer graph project --name dotfiles --date 2026-05-11
observer graph workflow --name startday-status-focus --date 2026-05-11
observer graph sources --date 2026-05-11
observer graph source-candidates --date 2026-05-11
observer graph stale-clips --date 2026-05-11
observer graph concept-tags --date 2026-05-11
observer graph source-orphans --date 2026-05-11
```

Graph checks report. They do not rewrite notes unless you explicitly run a creation/update/archive command.

## Optimal Workflow With Codex

Use Codex as the operator, not the uncontrolled writer.

Recommended daily flow:

1. Run `startday`.
2. Work normally.
3. Run `observer digest` when you want the vault updated.
4. Ask Codex: review today’s open-loop candidates.
5. Accept only useful loops.
6. Ask Codex: review graph candidates.
7. Create Project or Workflow notes only for real recurring work.
8. Clip useful web evidence into `raw/web-clips/`.
9. Link or tag clips that matter.
10. Ask Codex: review recent web clips.
11. Promote only source notes that will help future reasoning.

The graph should stay sparse enough to navigate and dense enough to recover context.

## What To Avoid

Avoid:

- promoting every command,
- accepting every open loop,
- turning every repo touch into a Project,
- turning similar prose into Concepts,
- clipping articles without reviewing them,
- letting Source notes copy whole raw clips,
- editing observer blocks by hand,
- letting Codex rewrite user-owned prose.

The system works because raw capture is cheap and promotion is deliberate.
