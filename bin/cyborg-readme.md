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
- GitNexus enhancement needs the `gitnexus` CLI reachable via `npx gitnexus`

The launcher resolves the model in this order:

1. `CYBORG_MODEL`
2. `CONTENT_MODEL`
3. `STRATEGY_MODEL`
4. fallback: `moonshotai/kimi-k2:free`

## Git Repo Enhancement Model

For non-git sources, `cyborg` ignores GitNexus and just uses the native scan.

For git repos, `cyborg` now does this automatically:

1. run a zero-write GitNexus health check
2. decide whether GitNexus is healthy enough to use immediately
3. stop for approval before any repo-writing GitNexus step
4. merge GitNexus graph signals with the native scan when the index is healthy

Important boundary:

- health checks are automatic
- `gitnexus analyze` is never automatic
- repo writes only happen after you explicitly approve with `/gitnexus enhance` or `/gitnexus refresh`

What counts as unhealthy:

- no `.gitnexus/meta.json`
- repo not indexed
- current HEAD differs from indexed commit
- tracked repo changes since last analyze
- index older than the freshness threshold
- GitNexus CLI unavailable or status failing

Large repo boundary:

- if tracked source/docs exceed `100 MB`, `cyborg` stops and asks before enhancement

Embeddings policy:

- if embeddings already exist, refresh preserves them
- if they do not exist, `cyborg` only recommends them as an optional upgrade
- embeddings are not auto-enabled

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
2. if the source is a git repo, respond to the GitNexus prompt first when enhancement or refresh is needed
3. let the repo scan complete if a repo is active
4. add intake notes in plain text
5. run `/map`
6. adjust focus with more notes if needed
7. run `/plan`
8. run `/draft all` or target selected keys
9. use `/review <key>` and plain-text notes for editorial passes
10. run `/links` and then `/patch-links ...` if you want existing-page edits
11. use `/rewrite <id> ...` when a refreshed repo maps strongly onto an existing Cyborg Lab page
12. run `/apply drafts --yes`, `/apply links --yes`, or `/apply all --yes`
13. run `cyborg resume <session-id>` later if the session goes cold

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
- rewrite recommendation count
- current review target
- GitNexus health, mode, commit, tracked-size, and embeddings status

### `/gitnexus status|enhance|refresh|skip|explain`

Use `/gitnexus` to control the repo-enhancement layer explicitly.

Subcommands:

- `status` shows current GitNexus health
- `enhance` approves first-time analyze/setup for the current repo
- `refresh` forces a refresh when the repo changed or the index is stale
- `skip` disables GitNexus for the current session and continues natively
- `explain` prints the exact enhancement plan and why it is being proposed

Typical flow when `cyborg` starts in a git repo without a healthy index:

1. automatic zero-write health check runs
2. `cyborg` prints the approval prompt
3. you choose `/gitnexus enhance`, `/gitnexus refresh`, or `/gitnexus skip`

Failure behavior:

- if enhancement fails, `cyborg` stops and offers retry, native continuation, or session stop
- when possible, it also attempts to clean partial GitNexus state created during a failed first-time setup

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
- GitNexus flow/definition signals when a healthy index exists

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
- strong rewrite candidates after a refreshed repo-backed session

In deterministic mode, the default core set is usually:

- `project`
- `workflow-main`
- `artifact-main`
- `log-main`

And it may add:

- `reference-main` when the repo has enough surface area
- `stack-main` when setup/config friction is obvious
- `protocol-main` when prompt contracts are part of the system

If the current repo changed since the last saved session and GitNexus has been refreshed, `/map` can also surface strong existing-page matches that should be handled explicitly before drafting.

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

When strong rewrite candidates exist, `/links` also shows which pages can be handled with `/rewrite`.

### `/rewrite <id> <mode>`

Choose one of three rewrite modes for a strong existing-page match:

- `update` rewrites the matching page in place on the next draft/apply cycle
- `iteration-log` preserves the existing page and routes the new narrative update into a fresh log draft
- `merge` keeps the existing page and stages only related-link style merge behavior

Example:

```bash
/rewrite 1 update
/rewrite 1 iteration-log
/rewrite 1 merge
```

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
- GitNexus health and summary are embedded in `session.json`
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

## Rewrite Flow For Existing Pages

Rewrite choices are only surfaced when all of these are true:

- the session is repo-backed
- GitNexus has been refreshed or is healthy
- the repo changed since the last saved session
- `cyborg` finds a strong existing-page match after the refreshed map is built

Then the flow is:

1. refresh GitNexus if needed
2. run `/map`
3. review the strong match list
4. choose `/rewrite <id> update|iteration-log|merge`
5. draft the affected page(s)
6. review and apply as usual

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
- GitNexus approval and status handling
- content map
- publishing plan
- draft generation
- link recommendations
- rewrite-mode selection
- resume
- explicit apply

This is the main reliability fallback when API access is down or when you want stable local behavior during testing.

## Safety Guarantees

`cyborg` is intentionally strict about writes.

- pending drafts stay in the session preview area until `/apply`
- pending existing-page edits stay in the session staging area until `/apply`
- GitNexus repo writes only happen after explicit approval
- writes into the blog repo are validated against the blog root
- session preview writes are validated against the session preview root
- existing files are backed up under `backups/` before they are overwritten
- repo names used during duplicate detection are treated as fixed strings, not regexes
- local `.gitnexus` files do not count as meaningful repo dirt for freshness checks

## Environment Variables

### Core

- `CYBORG_LAB_DIR` - explicit path to the target Cyborg Lab repo
- `DOTFILES_DIR` - explicit path to the dotfiles repo
- `OPENROUTER_API_KEY` - enables AI mode
- `CYBORG_DISABLE_AI=true` - force deterministic mode
- `CYBORG_DISABLE_GITNEXUS=true` - disable GitNexus integration and stay native
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
/gitnexus enhance
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

### Resume After Repo Changes

```bash
cyborg resume 20260315-101500-rockit-abc123
```

Then:

```text
/gitnexus refresh
/map
/rewrite 1 update
/draft workflow-main
```

Use this when the repo evolved and an existing Cyborg Lab page should be updated in place or spun into a new iteration log.

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

### GitNexus prompt appears before scan/map

That is expected for git repos when GitNexus is missing, stale, too old, too large, or unavailable. Choose:

- `/gitnexus enhance`
- `/gitnexus refresh`
- `/gitnexus skip`

### `Error: Repo path not found`

Your `--repo` path does not exist or is not a directory.

### Session starts without repo scan

You probably launched `cyborg ingest` from a directory that does not look like a project and did not pass `--repo`. Restart with `--repo` if you want repo-backed analysis.

### AI is enabled but drafts are deterministic

An AI request probably failed and `cyborg` fell back to the deterministic path. The session will usually tell you why.

### Resume fails with a numeric-choice error

Interactive `cyborg resume` expects a valid numbered session from the printed list.

### GitNexus says the repo is stale immediately after analyze

`cyborg` ignores local `.gitnexus` infrastructure files for freshness checks. If you still see a stale prompt, the likely cause is a real repo change, indexed commit mismatch, or age threshold.

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
