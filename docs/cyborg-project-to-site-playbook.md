# Cyborg Project-to-Site Playbook

This is the end-to-end guide for taking a new project from a local idea to a real project page on your site, then keeping that site content in sync as the project changes.

This guide is written for the workflow you asked for:

- build or refine the project locally
- keep the repo as the source of truth
- update the site with `cyborg-sync`
- publish documentation changes on the current site branch by default
- keep future updates repeatable and low-friction

If you only remember one rule, remember this:

> Use `cyborg` for exploration. Use `cyborg-sync` for repeatable updates after the repo is real.

## What Tool Does What

### `morphling`

Use `morphling` when you want help thinking, shaping, or brainstorming.

- default: direct Morphling session
- `morphling --swarm`: older dispatcher-style path with more context gathering

Good use:

- naming a project
- shaping the scope
- turning rough ideas into a short build plan

Bad use:

- repeatable site updates after every code push

### `cyborg`

Use `cyborg` when you want an interactive writing or repo exploration session.

Good use:

- exploring what pages a repo might deserve
- one-off drafting
- resume-and-review editorial loops
- `cyborg auto --iterate --repo ~/Projects/my-project` when you want the project repo to keep growing from issues or a backlog before you sync site docs
- `cyborg auto --build` when you want idea -> project scaffolding
- `cyborg auto --build --publish` when you want idea -> scaffold -> registry publish -> docs

Bad use:

- your regular “keep the site in sync with the repo” workflow

### `cyborg-sync`

Use `cyborg-sync` for the repeatable path.

It:

- reads your repo diff
- reads your README and notes
- updates mapped site pages
- runs repo checks
- runs site checks
- commits on the current branch if checks pass
- can create a review branch when you ask for it

This is the tool that should carry the long-term load.

## The Long-Term Mental Model

There are three repos in play:

1. your project repo
2. your site repo
3. your dotfiles repo, which holds the tools

The project repo stores:

- the code
- `README.md`
- `.cyborg-docs.toml`
- `.cyborg-docs-notes.md`

The site repo stores:

- the real published pages under `content/`

The dotfiles repo stores:

- `cyborg-sync`
- templates
- the scoped site check script
- the GitHub Action starter

## The Standard Flow

### Phase 1: Cook Up the Project Locally

Start with either:

- a new repo you created yourself
- `cyborg auto --iterate --repo ~/Projects/my-project` if the repo already exists and you want Cyborg to implement the next open issue or backlog item before the docs update cycle
- `cyborg auto --build "idea text"` if you want a project scaffold from an idea
- `cyborg auto --build --publish "idea text"` if you also want the verified package published after the scaffold passes

By default, build mode now runs a quick market validation step against GitHub and npm before the scaffold starts. Use `--no-validate` when you already know the space and want to skip that check.

If you want help shaping the concept first:

```bash
morphling "Help me shape a small, useful project for Cyborg Lab. I want a clear user problem, a tight first version, and simple success criteria."
```

Once the repo exists, get it into a minimally real state before you worry about the site:

- a working repo
- a real `README.md`
- at least one working run path
- at least one real test command

The site docs should follow the repo. The repo should not follow the site.

## Phase 2: Decide the First Site Pages

For a new project, keep the first pass small.

Usually start with:

- one `project` page
- one `workflow` page

Only add more when the repo really supports them:

- another workflow if the product has two clearly different user paths
- an artifact page if the repo produces a reusable output
- a stack page only if setup friction is part of the value

Good question:

> What two or three pages would make this repo easiest to understand and use?

## Phase 3: Add Docs-Sync Files to the Project Repo

Copy the template into the project repo:

```bash
cp /Users/ryanjohnson/dotfiles/templates/cyborg-docs.toml.example .cyborg-docs.toml
```

Then edit it for the project.

Your `.cyborg-docs.toml` should define:

- where the site repo lives
- which git diff range to compare
- repo test commands
- site check commands
- which site pages map to this repo
- whether new pages should be published immediately with `draft = false`

Also create `.cyborg-docs-notes.md`.

This file is the human brief for the worker. Keep it practical.

It should include:

- the exact pages you want
- the real user problem
- facts that must stay true
- writing rules
- any slug or internal-link rules you care about

Commit both of these files to the project repo. They are config, not junk.

## Phase 4: Ignore Disposable AI Run Logs

If a tool drops AI graph logs or similar junk into the repo, ignore them.

For example:

```gitignore
logs/graphs/
```

Keep:

- `.cyborg-docs.toml`
- `.cyborg-docs-notes.md`

Ignore:

- disposable AI execution traces
- temporary run graphs
- local-only log artifacts

## Phase 5: Run the First Manual Sync

Before you automate anything, do one manual run.

First, inspect the plan:

```bash
cyborg-sync --repo ~/Projects/my-project plan
```

Then run a dry run:

```bash
cyborg-sync --repo ~/Projects/my-project sync --dry-run
```

If the plan looks sane, do the real run:

```bash
cyborg-sync --repo ~/Projects/my-project sync --commit
```

What should happen:

- the worker reads the repo diff
- it updates the mapped site pages
- it runs your repo tests
- it runs your site checks
- it commits the generated page updates on the current site branch

If checks fail, `cyborg-sync` should restore the touched files before exiting.

## Phase 6: Review the Site Changes

After a successful run, go to the site repo and inspect:

- the current branch name
- the new pages or updates
- the commit message

Typical checks:

- are the page titles right
- do the internal links resolve
- did it stay inside the archetype
- is the reading level simple enough
- does it sound like the real repo, not generic AI sludge

If the generated pages are acceptable, push the current branch.

## Phase 7: Turn It Into the Repeatable Path

Once the first manual run works, add the GitHub Action to the project repo.

Start from:

[cyborg-docs-sync.github-action.yml](/Users/ryanjohnson/dotfiles/templates/cyborg-docs-sync.github-action.yml)

The intended behavior is:

- trigger on push to `main`
- check out the project repo
- check out the site repo
- check out dotfiles
- run `cyborg-sync`
- commit the updated pages to the current site branch after checks pass

This makes the future loop simple:

1. work locally
2. commit code
3. push to `main`
4. let the docs sync job update the current site branch

## The Everyday Update Loop

After the first setup, the repeatable loop should be boring:

### When you change the project locally

Do your normal work:

- code
- README updates
- tests
- commit

Before pushing, ask:

> Did this change something a user should see or do differently?

If no:

- no docs update may be needed

If yes:

- make sure the README and repo still say the true thing
- if needed, refine `.cyborg-docs-notes.md`

### When you push

Push to `main`.

The docs-sync workflow should:

- compare the new commit range
- update only the mapped pages
- run checks
- commit the content changes on the current site branch

### When the change is bigger than the current mapping

If the product grows a second strong user path, add another workflow page to the manifest.

If the repo starts producing a reusable output, add an artifact page.

Do not let the manifest sprawl without a reason.

## What to Commit in Each Repo

### Project Repo

Commit:

- code changes
- README updates
- `.cyborg-docs.toml`
- `.cyborg-docs-notes.md`
- `.gitignore` rules for disposable AI run logs

Do not commit:

- temporary graph logs
- stray AI transcript dumps
- local-only caches

### Site Repo

Commit:

- only the content pages `cyborg-sync` updated

Those should usually land on the current site branch. Add `--create-branch` only when you want a review branch.

### Dotfiles Repo

Commit:

- tooling changes
- templates
- docs for the workflow itself

## How to Decide What Goes in `.cyborg-docs-notes.md`

This file should answer five things clearly:

1. What pages should exist?
2. What user problem does this repo solve?
3. What facts must stay true?
4. What writing rules matter?
5. What internal links are allowed?

If the file gets fluffy, shorten it.

It is a constraint file, not a diary.

## How to Decide What Goes in the Manifest

The manifest is not for prose. It is for wiring.

Use it for:

- page paths
- page types
- track and JTBD
- draft vs published
- repo tests
- site checks

Keep it mechanical.

## Recommended Site Checks for New Pages

For first-time page creation, prefer:

```toml
site_check_commands = [
  "bash \"$DOTFILES_DIR/scripts/cyborg_scoped_site_check.sh\" content/projects/example-project.md content/workflows/productivity-systems/example-workflow.md",
  "bash scripts/validate-links.sh",
]
```

Why:

- the scoped check verifies the mapped pages against the archetypes
- the full Hugo link build catches real broken links
- this avoids getting blocked by unrelated old content debt elsewhere in the site

## Brain-Fog Version

If your brain is cooked, do only this:

1. make the repo real
2. make the README true
3. commit `.cyborg-docs.toml`
4. commit `.cyborg-docs-notes.md`
5. run:

```bash
cyborg-sync --repo ~/Projects/my-project plan
cyborg-sync --repo ~/Projects/my-project sync --dry-run
cyborg-sync --repo ~/Projects/my-project sync --commit
```

6. review the site repo changes
7. push code to `main`
8. let the GitHub Action handle future syncs

## Trouble Signs

Stop and fix the setup if:

- the worker invents pages you did not map
- internal links point to nonexistent cousins
- the generated page is too vague or generic
- the page breaks the archetype
- the page is created as a draft when you meant to publish
- site-wide checks fail because of unrelated old content debt

Typical fixes:

- tighten `.cyborg-docs-notes.md`
- shrink the manifest scope
- use the scoped site check
- explicitly set `draft = false`
- add only the mapped internal links you want

## Suggested Golden Path

For most new projects, use this order:

1. build the repo locally
2. get the README into true shape
3. define one project page and one workflow page
4. add manifest + notes
5. run manual `cyborg-sync`
6. review the site repo changes
7. add the GitHub Action
8. let pushes to `main` drive future site updates

That gives you the least confusing version of the system.

## Examples

### New Project from a Local Repo

```bash
cd ~/Projects/my-project
morphling "Help me sharpen the user problem and first release scope for this repo."
cp /Users/ryanjohnson/dotfiles/templates/cyborg-docs.toml.example .cyborg-docs.toml
$EDITOR .cyborg-docs.toml
$EDITOR .cyborg-docs-notes.md
cyborg-sync --repo ~/Projects/my-project plan
cyborg-sync --repo ~/Projects/my-project sync --dry-run
cyborg-sync --repo ~/Projects/my-project sync --commit
```

### New Project from an Idea

```bash
cyborg auto --build "a project idea" --projects-dir ~/Projects
# or:
cyborg auto --build --publish "a project idea" --projects-dir ~/Projects
cd ~/Projects/new-project
cp /Users/ryanjohnson/dotfiles/templates/cyborg-docs.toml.example .cyborg-docs.toml
$EDITOR .cyborg-docs.toml
$EDITOR .cyborg-docs-notes.md
cyborg-sync --repo ~/Projects/new-project plan
cyborg-sync --repo ~/Projects/new-project sync --commit
```

## Final Rule

Keep the repo true.
Keep the mapping small.
Keep the notes grounded.
Let `cyborg-sync` do the repeatable work.
