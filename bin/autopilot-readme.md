# Autopilot: Morphling + Cyborg

Hands-free content pipeline for low-energy and brain-fog sessions.

Morphling analyzes (or builds) the project. Cyborg turns it into blog-ready content. You confirm once at the end.

> **Heavy fog day?** Skip this page and go straight to the [Autopilot Happy Path](../docs/autopilot-happy-path.md) — copy-paste commands, no reading required.

## Quick Start

```bash
# Document an existing repo
cyborg auto

# Document a specific repo
cyborg auto --repo ~/Projects/rockit

# Pitch an idea — Morphling builds the project, Cyborg documents it
cyborg auto --build "a CLI that tracks daily energy with spoon theory"

# Build and publish to the right registry (npm, PyPI, crates.io, GitHub)
cyborg auto --build --publish "terminal pomodoro timer with MS-friendly breaks"

# Skip all confirmations (build + publish + apply docs)
cyborg auto --build --publish --yes "tool that audits deps for license compliance"
```

## How It Works

### Without `--build` (existing repo)

```
 you type one command
        |
        v
 [Morphling pre-analysis]  ← optional, runs if uv + ai-staff-hq available
        |
        v
 [Cyborg autopilot]
   scan → map → plan → draft all → link patches
        |
        v
 [one A-E choice]
   A. Apply everything
   B. Drafts only
   C. Links only
   D. Save for later
   E. Drop into interactive mode
```

### With `--build` (idea only)

```
 you type one command + your idea
        |
        v
 [market validation]         ← searches GitHub + npm, AI analysis
   green/yellow/red verdict
   A. proceed  B. revise  C. cancel
   (skip with --no-validate, auto with --yes)
        |
        v
 [Morphling builds project]  ← scaffolds files in ~/Projects/<name>/
   picks language, framework, structure
   writes working code + README + tests
   git init + commit
        |
        v
 [build-verify-fix loop]     ← up to 3 rounds
   detect project type → install deps → run tests
   if tests fail: send errors to AI → apply fix → retest
   commit fixes when green
        |
        v
 [publish to registry]       ← only with --publish flag
   detect ecosystem → validate tokens/tools
   confirm (unless --yes) → create GitHub repo
   AI-enhance metadata → publish to npm/PyPI/crates.io/GitHub
   tag v0.1.0
        |
        v
 [Cyborg autopilot]
   scan → map → plan → draft all → link patches
        |
        v
 [one A-E choice]
```

## All Flags

| Flag | What it does |
|------|-------------|
| `--repo PATH` | Scan this repo instead of the current directory |
| `--file PATH` | Include a markdown file as supporting material |
| `--build` | Morphling scaffolds the project from your idea first |
| `--publish` | Publish to ecosystem registry after build+verify (npm, PyPI, crates.io, GitHub) |
| `--no-validate` | Skip the pre-build market validation search |
| `--projects-dir PATH` | Where to create the project (default: `~/Projects`) |
| `--yes` | Skip the final confirmation and apply immediately |
| `--no-morphling` | Skip the Morphling pre-analysis step |
| `--blog-root PATH` | Override the Cyborg Lab blog repo location |
| `--stdin-source` | Read stdin as supporting material |

## What Morphling Does

Morphling is the only AI-Staff-HQ specialist with tools enabled. In direct mode (`morphling`), it has four tools: `read_file`, `write_file`, `list_directory`, and `run_command`. This makes it a full lead-developer agent that can write code, run tests, see errors, and fix them in a closed loop. See [MORPHLING.md](../MORPHLING.md) for the complete architecture.

### Pre-analysis mode (default for `cyborg auto`)

When you run `cyborg auto` on an existing repo, the shell launcher pipes a structured prompt to `morphling.sh`. Morphling shapeshifts into a domain expert for that repo and returns a concise brief covering:

- Key concepts and architecture patterns
- Notable implementation choices
- What makes the project interesting
- What would be most valuable to document

This brief gets injected into Cyborg's AI context so drafts are richer and more targeted.

**Requirements:** `uv` installed and `ai-staff-hq/` submodule present. Gracefully skipped if unavailable.

### Build mode (`--build`)

When you pass `--build`, the Python agent calls OpenRouter directly with a Morphling-persona system prompt. The AI:

1. Picks the best language, framework, and tooling for your idea
2. Returns a complete project scaffold as structured JSON
3. Retries empty or unusable scaffold responses before giving up, then writes the files to `~/Projects/<name>/`
4. Runs `git init` and commits the initial scaffold
5. Before building, market validation searches GitHub and npm using `GITHUB_TOKEN` / `GH_TOKEN` or the standard GitHub token files (`~/.github_token`, then `~/.config/dotfiles-data/github_token`) and now prints source-specific auth/network errors instead of a single generic API warning
6. **Runs a build-verify-fix loop** (up to 3 rounds):
   - Detects project type from marker files (`package.json`, `manifest.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, `Makefile`)
   - For Python projects, creates a disposable virtualenv, installs dependencies there, and includes `requirements-dev.txt` when present
   - For browser extensions with `manifest.json` but no package manifest, validates the manifest, checks referenced files, and syntax-checks JavaScript with `node --check` when Node is available
   - The scaffold prompt now forces verified dependency APIs, explicit option semantics, and local adapter seams when third-party integrations are uncertain
   - The scaffold prompt also forces deterministic offline tests instead of live-network or "expected to fail" placeholders
   - If install fails, Morphling fixes manifests/build config first and retries until the round budget is exhausted
   - If tests fail, sends error output back to the Morphling persona and, for Python missing-attribute errors, includes the verified installed module surface from the temp virtualenv
   - OpenRouter scaffold/fix requests now fail on a hard wall-clock timeout instead of hanging indefinitely on a stalled response stream
   - AI returns corrected files, which are applied and re-tested
   - Commits fixes as a separate git commit when verification passes
   - In `--build --yes` mode, any later Cyborg improvement suggestions stay staged instead of being auto-applied, so the generated repo remains at the verified build unless you explicitly apply follow-up edits
7. If `--publish`: creates a GitHub repo, enhances package metadata via AI, and publishes to the right registry
8. Cyborg then scans and documents the verified, working project

**Requirements:** `OPENROUTER_API_KEY` must be set (AI mode). For `--publish`, registry tokens must be configured (see `.env.example`).

## What Cyborg Does in Autopilot

The same pipeline as `cyborg ingest`, but every decision point is auto-resolved:

| Decision point | Manual mode | Autopilot mode |
|---------------|-------------|---------------|
| GitNexus approval | A-E prompt, waits | Auto-enhance small repos, auto-skip large/unavailable |
| Rewrite candidates | A/B/C per match | Auto-selects "update" (safest) |
| Draft targets | `/draft all` or pick keys | Always drafts all |
| Link patches | `/patch-links 1 2 3` | Patches all recommendations |
| Apply changes | `/apply all --yes` | Single A-E choice (or `--yes` to skip) |

The session is still saved, so you can always `cyborg resume` later to review or refine.

## Examples

### Document a project you just finished

```bash
cd ~/Projects/my-new-tool
cyborg auto
```

### Document someone else's repo

```bash
cyborg auto --repo ~/Projects/open-source-thing "focus on the API design"
```

### Turn a napkin idea into a project and blog post

```bash
cyborg auto --build "bash script that picks a random recipe based on energy level and what's in the fridge"
```

### Full hands-off: build, document, and apply

```bash
cyborg auto --build --yes "python CLI for converting voice memos to structured notes"
```

### Build into a custom directory

```bash
cyborg auto --build --projects-dir ~/Labs "rust grep alternative optimized for accessibility"
```

### Pipe extra context from a file

```bash
cat research-notes.md | cyborg auto --stdin-source --repo ~/Projects/foo
```

## Session Recovery

Autopilot saves the session just like `cyborg ingest`. If something goes wrong or you chose "D. Save for later":

```bash
# Resume the latest session
cyborg resume

# Resume a specific session
cyborg resume 20260317-143000-spoon-tracker-abc123
```

Once resumed, you're in full interactive mode with all commands available.

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `OPENROUTER_API_KEY` | Required for AI mode and `--build` |
| `CYBORG_MODEL` | Model override (falls back through `CONTENT_MODEL` → `STRATEGY_MODEL`) |
| `CYBORG_LAB_DIR` | Explicit path to the Cyborg Lab blog repo |
| `CYBORG_DISABLE_AI` | Set to `true` to force deterministic mode (no `--build`) |
| `CYBORG_DISABLE_GITNEXUS` | Set to `true` to skip GitNexus entirely |
| `CYBORG_MORPHLING_BRIEF` | Auto-set by the shell launcher — contains the Morphling pre-analysis. Not user-configured; injected into the session's AI context by `run_autopilot()` |

## Related Files

- [`MORPHLING.md`](../MORPHLING.md) - Morphling architecture deep dive (capabilities, tools, build-verify loop)
- [`cyborg-readme.md`](./cyborg-readme.md) - Full Cyborg agent reference (interactive commands, session lifecycle, safety model)
- [`README.md`](./README.md) - All dispatchers including Morphling
- [`../scripts/cyborg_agent.py`](../scripts/cyborg_agent.py) - Python agent (session state + interactive workflow orchestration)
- [`../scripts/cyborg_build.py`](../scripts/cyborg_build.py) - Build pipeline (scaffold + verify + publish + market validation)
- [`../scripts/cyborg_support.py`](../scripts/cyborg_support.py) - Shared helpers (run_command, slugify, prompt_input)
- [`cyborg`](./cyborg) - Shell launcher (Morphling pre-analysis)
- [`morphling.sh`](./morphling.sh) - Morphling interactive launcher
- [`dhp-morphling.sh`](./dhp-morphling.sh) - Morphling dispatcher
