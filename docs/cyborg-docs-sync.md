# Cyborg Docs Sync

`cyborg-sync` is the non-interactive path for keeping Cyborg Lab pages aligned with real repo changes.

It is built for the workflow you described:

- project repos use a local `.cyborg-docs.toml` manifest
- the worker reads repo diff, README, optional notes, existing page content, and the site archetype
- OpenRouter writes the update
- repo checks and site checks run before anything is committed
- low-confidence pages are skipped instead of being pushed through

## Why This Exists

`cyborg ingest` is useful for exploratory drafting, but it is a poor fit for repeatable documentation maintenance after code ships. `cyborg-sync` removes the chat loop and replaces it with a manifest-driven worker.

## Manifest Shape

Copy [templates/cyborg-docs.toml.example](/Users/ryanjohnson/dotfiles/templates/cyborg-docs.toml.example) into the project repo as `.cyborg-docs.toml`.

Use it to define:

- the site repo location
- the git diff range to compare
- repo test commands
- site validation commands
- the exact pages that map to the repo
- whether new pages should publish immediately with `draft = false`

Each `[[pages]]` entry should point at one real page. Start with existing project and workflow pages first. Add create-if-missing behavior only when you trust the mapping.

## Local Commands

Print the grounded plan:

```bash
cyborg-sync --repo ~/Projects/alias-scanner plan
```

Run a dry sync without writing:

```bash
cyborg-sync --repo ~/Projects/alias-scanner sync --dry-run
```

Write changes into a dedicated site branch and commit them after checks pass:

```bash
cyborg-sync --repo ~/Projects/alias-scanner sync --create-branch --commit
```

## Writing Rules

The worker instructs the model to:

- follow the site archetype exactly
- keep frontmatter and section structure valid
- write at a smart fifth-grader reading level
- keep SEO natural instead of stuffed
- preserve existing claims unless the repo change justifies an update

## Validation Strategy

The worker can run anything you list in the manifest:

- repo tests such as `go test ./...` or `npm test`
- site governance checks
- site validation checks
- full link validation

For create-if-missing pages, a scoped site check is usually safer than running full-site governance first. Use [scripts/cyborg_scoped_site_check.sh](/Users/ryanjohnson/dotfiles/scripts/cyborg_scoped_site_check.sh) in the manifest so the worker validates the mapped pages against the site archetypes before the full Hugo link build:

```toml
site_check_commands = [
  "bash \"$DOTFILES_DIR/scripts/cyborg_scoped_site_check.sh\" content/projects/example-project.md content/workflows/productivity-systems/example-workflow.md",
  "bash scripts/validate-links.sh",
]
```

If a check fails, the worker restores the touched files before exiting.

## GitHub Actions

Use [templates/cyborg-docs-sync.github-action.yml](/Users/ryanjohnson/dotfiles/templates/cyborg-docs-sync.github-action.yml) as the starting point for the per-repo automation.

That path matches your preference:

- run on push to `main`
- keep a manifest in each project repo
- prepare a dedicated site branch
- commit only after checks pass
