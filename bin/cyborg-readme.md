# Cyborg Agent Wiki

`cyborg` is a dedicated interactive agent for turning a repo, a draft, or a loose idea into a linked Cyborg Lab content set.

It is not a general dispatcher. It is a repo-aware writing workflow that stays focused on the Cyborg Lab publishing model:

- `project`
- `workflow`
- `artifact`
- `log`
- `reference`
- `stack` when setup friction is real
- `protocol` when prompt contracts are clearly part of the system

## What It Does

`cyborg ingest` opens a long-running terminal session that:

1. captures your repo, notes, draft article, or idea
2. scans the source repo with native local heuristics
3. proposes a Cyborg Lab content map
4. turns that into a publishing plan
5. generates near-publishable draft files held in preview
6. recommends cross-link edits for existing Cyborg Lab pages
7. writes into the blog repo only when you explicitly apply changes

`cyborg resume` reopens a saved session and lets you continue the same content graph, draft set, and editorial loop later.

## Mental Model

Use `cyborg` when you have one of these starting points:

- a repo you built and want to decompose into Cyborg Lab content
- a fact-checked markdown draft that should become repo-linked Cyborg Lab pages
- a plain idea that needs to be worked into a publishable content plan

The default source-of-truth rule is:

- if repo and article are both supplied, the repo is canonical
- the markdown draft is treated as supporting material tied to that repo
- your plain-text intake notes shape focus, framing, and publishing order

## Requirements

- `python3` must be installed
- the launcher expects `/Users/ryanjohnson/dotfiles/scripts/lib/config.sh`
- the target Cyborg Lab repo must have a `content/` directory
- AI mode needs `OPENROUTER_API_KEY`

The launcher resolves the model in this order:

1. `CYBORG_MODEL`
2. `CONTENT_MODEL`
3. `STRATEGY_MODEL`
4. fallback: `moonshotai/kimi-k2:free`

## Command Surface

### Start a New Session

```bash
cyborg ingest
cyborg ingest --repo ~/Projects/rockit
cyborg ingest --repo ~/Projects/rockit --file notes/field-report.md
cyborg ingest "idea for turning this repo into a workflow + artifact set"
```

### Resume a Saved Session

```bash
cyborg resume
cyborg resume 20260315-101500-rockit-abc123
```

`cyborg resume` behavior:

- interactive terminal + no session ID: shows a numbered session list
- non-interactive + no session ID: reopens the newest saved session
- explicit session ID: loads that exact session

## Input Modes

`cyborg ingest` can start from five input sources:

### 1. Current Directory

If you run `cyborg ingest` inside a git repo, it uses the repo root.

If there is no git root, it only adopts the current directory as the source repo when the directory looks like a real project. Current heuristics look for signals like:

- `pyproject.toml`, `package.json`, `requirements.txt`, `Cargo.toml`, `go.mod`, `Makefile`, or similar markers
- directories like `src`, `app`, `lib`, `tests`, `docs`, `.github`
- a combination of `README*` plus source files

If those signals are missing, the session becomes note-first instead of scanning an arbitrary directory.

### 2. Explicit Repo Path

```bash
cyborg ingest --repo ~/Projects/rockit
```

If the path is inside a git repo, `cyborg` promotes it to the git root. If the directory exists but is not a git repo, it still uses the directory directly.

### 3. Supporting Markdown File

```bash
cyborg ingest --file notes/field-report.md
```

This file is treated as supporting article material. Missing files fail with a friendly CLI error instead of a Python traceback.

### 4. Pasted stdin

If you want to feed content through stdin before the interactive session starts, use:

```bash
cat notes.md | cyborg ingest --stdin-source --repo .
```

Without `--stdin-source`, stdin belongs to the interactive session itself.

### 5. Plain Idea Text

Anything after `cyborg ingest` is stored as source text:

```bash
cyborg ingest "focus on the setup path and the reusable command sheet"
```

## Blog Repo Resolution

`cyborg` resolves the Cyborg Lab repo in this order:

1. `--blog-root`
2. `CYBORG_LAB_DIR`
3. known default paths:
   `/Users/ryanjohnson/Projects/cyborg/my-ms-ai-blog`
   `/Users/ryanjohnson/Projects/cyborg-lab`
4. interactive prompt

If the path does not contain `content/`, it is rejected.

Interactive prompt behavior:

- blank input cancels instead of looping forever
- invalid paths show an explanation and prompt again

## Session Lifecycle

The intended workflow is:

1. start `cyborg ingest`
2. let the repo scan complete if a repo is active
3. add intake notes in plain text
4. run `/map`
5. adjust focus with more notes if needed
6. run `/plan`
7. run `/draft all` or target selected keys
8. use `/review <key>` and plain-text notes for editorial passes
9. run `/links` and then `/patch-links ...` if you want existing-page edits
10. run `/apply drafts --yes`, `/apply links --yes`, or `/apply all --yes`
11. run `cyborg resume <session-id>` later if the session goes cold

## Interactive Commands

### `/help`

Prints the built-in command help.

### `/status`

Shows:

- session ID
- current phase
- active repo path
- blog root
- counts for intake, planning, and editorial notes
- number of content-map items
- pending draft keys
- pending existing-page edit count
- current review target

### `/scan`

Scans the active repo and writes a repo summary into the session. The scan includes:

- repo root
- file count
- docs count
- tests count
- manifest files
- git remote, recent commits, and git status when available
- language mix by extension
- README excerpt
- docs excerpt
- representative code excerpt
- duplicate candidates already present in the Cyborg Lab repo

Local scanning uses:

- `git ls-files` when inside a git repo
- `rg --files` when git is not available
- recursive filesystem fallback if needed

### `/map`

Builds the content graph for the source material. The output is a content map with:

- summary
- proposed pages
- stable keys
- page types
- target file paths
- rationale for each page
- existing-page recommendations for update-or-link decisions

In deterministic mode, the default core set is usually:

- `project`
- `workflow-main`
- `artifact-main`
- `log-main`

And it may add:

- `reference-main` when the repo has enough surface area
- `stack-main` when setup/config friction is obvious
- `protocol-main` when prompt contracts are part of the system

### `/plan`

Turns the approved content map into a publishing plan. The saved plan includes:

- summary
- phase list
- publish sequence
- editorial questions

The deterministic plan is opinionated:

- lock scope and duplicate decisions first
- draft workflow and artifact before project
- draft the log after the reusable docs exist
- generate existing-page patch suggestions only after recommendation approval

### `/draft [all|key ...]`

Generates near-publishable drafts into the session preview area. Examples:

```bash
/draft all
/draft workflow-main
/draft workflow-main artifact-main project
```

Drafts are stored as pending and are not written into the live blog repo yet.

### `/review <key>`

Marks one pending draft as the active editorial target. After that, any plain text you type is treated as editorial feedback for that specific draft.

When AI revision succeeds, the previous draft body is preserved in session state before the new markdown replaces it.

### `/show <key>`

Prints the full pending draft markdown for the selected key.

### `/links`

Prints the current recommendation list for existing Cyborg Lab pages that should probably absorb links or receive related-page updates.

### `/patch-links 1 2`

Takes numeric IDs from the recommendation list and generates pending edits for those existing pages.

These edits are still staged only. They are not written live until `/apply`.

### `/apply [drafts|links|all]`

Writes the selected pending changes into the Cyborg Lab repo.

Examples:

```bash
/apply drafts --yes
/apply links --yes
/apply all --yes
```

Behavior details:

- in an interactive terminal, omitting `--yes` triggers a confirmation prompt
- in non-interactive mode, `--yes` is required
- `all` now applies link edits even when no drafts are pending
- if nothing is pending, `cyborg` tells you instead of silently doing nothing

### `/quit`

Saves the session and exits. The farewell message includes the exact `cyborg resume <session-id>` command to reopen it later.

## Plain-Text Notes

Plain text does different work depending on the phase:

- before mapping: intake guidance
- after mapping and planning: planning guidance
- during active review: editorial feedback for the selected draft

With AI enabled, `cyborg` responds conversationally and tries to steer the next step. With AI disabled, it still stores the notes and tells you the next useful command.

## Session Files

Every session lives under:

`my-ms-ai-blog/drafts/ingest/<session-id>/`

The session folder can contain:

- `session.json` - full serialized session state
- `transcript.md` - chat transcript
- `scan.md` - repo scan summary
- `content-map.json`
- `content-map.md`
- `publishing-plan.json`
- `publishing-plan.md`
- `preview/` - pending draft files
- `existing-edits/` - pending edits for existing Cyborg Lab pages
- `backups/` - original file backups created during `/apply`

The session ID format is:

`YYYYMMDD-HHMMSS-<seed>-<suffix>`

The seed comes from:

- repo name if a repo is active
- otherwise the first heading in the article text or idea

## What Drafts Look Like

Generated drafts always aim to be near publishable and include frontmatter with `draft: true`.

By type, the deterministic templates currently bias toward:

- `project`: outcome, components, pipeline, artifacts, verification, related
- `workflow`: quick path, need, walkthrough, verification, failure mode, related
- `artifact`: quick use, provenance, verification, failure mode, related
- `log`: signal, intervention, result, next move, sources, related
- `reference`: purpose, index table, sources, related
- `stack`: bottleneck, patch, config/script, verification, rollback, related
- `protocol`: prompt contract, logic, verification, related

The draft frontmatter is also type-aware. For example:

- `workflow` drafts include `jtbd`, `prerequisites`, and workflow categories
- `project` drafts include `status` and `components`
- `artifact` drafts include `artifact_type`, `format`, `generated_by`, and `source_workflow`
- `log` drafts include `log_kind`

## Existing-Page Cross-Link Flow

Cross-linking is deliberately conservative.

The workflow is:

1. `/map` creates recommendation candidates
2. `/links` shows the recommendation list
3. you choose which IDs to act on
4. `/patch-links ...` stages only those edits
5. `/apply links --yes` or `/apply all --yes` writes them live

This is designed to reduce duplicate pages and force an explicit merge-or-link decision.

## AI Mode vs Deterministic Mode

### AI Mode

Enabled when:

- `OPENROUTER_API_KEY` is set
- `CYBORG_DISABLE_AI` is not truthy
- a model is available

AI mode is used for:

- content map generation
- publishing plan generation
- draft generation
- draft revision
- conversational guidance after plain-text notes

### Deterministic Mode

Force it with:

```bash
CYBORG_DISABLE_AI=true cyborg ingest --repo .
```

Deterministic mode still supports the full workflow:

- repo scan
- content map
- publishing plan
- draft generation
- link recommendations
- resume
- explicit apply

This is the main reliability fallback when API access is down or when you want stable local behavior during testing.

## Safety Guarantees

`cyborg` is intentionally strict about writes.

- pending drafts stay in the session preview area until `/apply`
- pending existing-page edits stay in the session staging area until `/apply`
- writes into the blog repo are validated against the blog root
- session preview writes are validated against the session preview root
- existing files are backed up under `backups/` before they are overwritten
- repo names used during duplicate detection are treated as fixed strings, not regexes

## Environment Variables

### Core

- `CYBORG_LAB_DIR` - explicit path to the target Cyborg Lab repo
- `DOTFILES_DIR` - explicit path to the dotfiles repo
- `OPENROUTER_API_KEY` - enables AI mode
- `CYBORG_DISABLE_AI=true` - force deterministic mode
- `CYBORG_MODEL` - primary model override
- `CONTENT_MODEL` - secondary model fallback
- `STRATEGY_MODEL` - tertiary model fallback

### Internal

- `USER_CWD` is set by the shell launcher so the Python process keeps the original directory context

## Typical Workflows

### Repo-First Session

```bash
cd ~/Projects/rockit
cyborg ingest
```

Then:

```text
/map
/plan
/draft workflow-main artifact-main project log-main
/review workflow-main
```

Then type plain editorial notes and finish with:

```text
/links
/patch-links 1 2
/apply all --yes
/quit
```

### Repo + Supporting Draft

```bash
cyborg ingest --repo ~/Projects/rockit --file notes/rockit-field-report.md
```

Use this when the repo should drive the structure but you already have article-grade source material to preserve and restructure.

### Pasted Article Into a Repo-Aware Session

```bash
cat notes/rockit-field-report.md | cyborg ingest --stdin-source --repo ~/Projects/rockit
```

### Idea-First Session

```bash
cyborg ingest "I want a project page, a workflow, and a narrative log for the repo I built last month"
```

This works even before you decide which repo or article should ground the session.

## Troubleshooting

### `Error: required config library is missing`

The launcher could not source:

`/Users/ryanjohnson/dotfiles/scripts/lib/config.sh`

Restore that file or point `DOTFILES_DIR` at the correct dotfiles checkout.

### `Error: Unable to resolve Cyborg Lab root`

Set `CYBORG_LAB_DIR` or pass `--blog-root`.

### `Error: Unable to read source file ...`

Your `--file` path is wrong, unreadable, or outside the allowed home-directory boundary.

### `Error: Repo path not found`

Your `--repo` path does not exist or is not a directory.

### Session starts without repo scan

You probably launched `cyborg ingest` from a directory that does not look like a project and did not pass `--repo`. Restart with `--repo` if you want repo-backed analysis.

### AI is enabled but drafts are deterministic

An AI request probably failed and `cyborg` fell back to the deterministic path. The session will usually tell you why.

### Resume fails with a numeric-choice error

Interactive `cyborg resume` expects a valid numbered session from the printed list.

## Current Boundaries

What `cyborg` does now:

- native local repo scanning
- conservative duplicate detection against the Cyborg Lab repo
- content map and publishing plan generation
- near-publishable draft staging
- editorial revision loop
- patch-ready related-link updates for selected existing pages

What it does not do yet:

- GitNexus-backed graph analysis
- automatic publish flag flips
- browser-based editing UI
- automatic commit creation
- final publish validation against the full Cyborg Lab content contract

## Related Files

- `bin/cyborg`
- `scripts/cyborg_agent.py`
- `tests/test_cyborg.sh`
- `bin/README.md`
- `scripts/README_aliases.md`
