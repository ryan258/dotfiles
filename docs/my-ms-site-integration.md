# My MS & AI Journey – Blog Integration Guide

This doc captures how the dotfiles toolkit connects to the `my-ms-ai-blog` Hugo project so everything stays in lockstep. Treat it as the canonical “how does `blog.sh` talk to my site?” reference.

---

## TL;DR

- Set `BLOG_DIR` and related paths in `.env`.
- Use `blog status`, `blog generate`, and `blog refine` for the core workflow.
- This doc is the source of truth for blog integration.

## 1. Required Environment Variables

Add these to `~/dotfiles/.env` (already ignored by git):

```bash
BLOG_DIR="$HOME/Projects/my-ms-ai-blog"
BLOG_CONTENT_DIR="$BLOG_DIR/content"              # Default content root
BLOG_POSTS_DIR_OVERRIDE="$BLOG_DIR/content/blog"  # Where finished posts live
BLOG_DRAFTS_DIR_OVERRIDE="$BLOG_DIR/drafts/first" # (Optional) draft staging
BLOG_ARCHETYPES_DIR="$BLOG_DIR/archetypes"        # Hugo archetypes for --archetype flag
BLOG_STANDARDS_FILE="$BLOG_DIR/GUIDE-WRITING-STANDARDS.md"
BLOG_CONTRIBUTING_FILE="$BLOG_DIR/CONTRIBUTING.md"
CONTENT_OUTPUT_DIR="$BLOG_DIR/drafts/first"       # Where AI drafts land
```

Reload your shell (`source ~/.zshrc`) so every `blog` command sees these paths.

---

### CLI Shortcuts

To reduce typing overhead (especially on low-energy days), these subcommand aliases work:

| Full Command | Shortcut | Notes |
|--------------|----------|-------|
| `blog status` | `blog s` | Dashboard |
| `blog generate` | `blog g` | Supports `-p` persona, `-a` archetype, `-s` section, `-f` file |
| `blog refine` | `blog r` | Polish existing posts |
| `blog ideas` | `blog i` | Journal search |
| `blog draft` | `blog d` | Hugo archetype scaffolding |
| `blog workflow` | `blog w` | Full workflow helper |
| `blog publish` | `blog p` | Build + status summary |
| `blog validate` | `blog v` | Runs validation pipeline |

---

## 2. Generating Content

Use the new flexible `blog generate` flow:

```bash
# Generate directly from a brief + persona + archetype + section
blog generate -p "Calm Coach" -a guide -s guides/brain-fog \
  "Energy-first planning walkthrough for foggy days"

# Feed an existing draft as context
blog generate -a blog -s blog/general --file "$BLOG_DIR/drafts/idea.md"

# Pipe from stdin
cat ~/Desktop/musings.txt | blog generate -p "Mark" -a prompt-card -s prompts
```

**Persona Quick Reference**

| Name (use with `-p`) | Focus | Typical prompt phrasing |
|----------------------|-------|-------------------------|
| `Brenda`             | Overwhelmed patient advocate | “Explain medical bureaucracy without jargon” |
| `Mark`               | Fatigued energy manager      | “Hands-free workflows, low clicks” |
| `Sarah`              | Foggy systems builder        | “Triage piles, systems thinking” |

These map directly to the persona blocks in `docs/personas.md`. Call them via `blog g -p "Brenda" ...`.

### Section Flag (`-s/--section`)

Use `-s` to control where generated drafts land:

| Syntax | Meaning | Example |
|--------|---------|---------|
| `-s guide` | Use the predefined section for guides (maps to `content/guides`) | `blog g ... -s guide` |
| `-s guides/brain-fog` | Direct path under `content/` | `blog g ... -s guides/brain-fog` |
| `-s guide:brain-fog` | Base section + subsection shorthand | `blog g ... -s guide:brain-fog` |

If you omit `-s`, the command uses the archetype’s default section (e.g., `-a guide` implies `content/guides`). Drafts are saved directly into `$BLOG_DIR/content/<section>/`.

**Exemplars:** Each section automatically injects a representative “North Star” post as context (full file is provided to the AI; you control which one via env config). Examples:
- `guides/brain-fog` → `content/guides/brain-fog/daily-briefing.md`
- `guides/ai-frameworks` → `content/guides/ai-frameworks/advanced-prompting.md`
- `blog` → `content/blog/automation-and-disability.md`
- `shortcuts/system-instructions` → `content/shortcuts/system-instructions/brain-fog-assistant-persona.md`

If an exemplar is missing, the workflow logs a warning and continues.

You can customize these mappings in `.env` via the multiline `BLOG_SECTION_EXEMPLARS` variable (format: `section_prefix|relative/path.md`). See `.env.example` for the default list.

### Prompt Stack (What the AI Sees)

Each `blog g` call assembles the prompt in this order:
1. **Archetype template** from `archetypes/<type>.md`
2. **Section exemplar** pulled from `BLOG_SECTION_EXEMPLARS`
3. **Persona playbook** from `docs/personas.md` (`-p/--persona`)
4. **Your brief/input** plus optional local context (`-c`/`-C`)

That stack keeps tone/structure/persona consistent while letting the brief drive the subject matter.

---

### Optional Context Flags

`blog generate` can inject local state so drafts reflect what you’re actually working on. Two modes exist:

| Flag | Include this block | Use when… |
|------|--------------------|-----------|
| `-c`, `--context` | Current directory, repo/branch, top 3 todos | You just need light situational awareness (e.g., mention current project or focus tasks). |
| `-C`, `--full-context` | Everything from `-c` **plus** last 7 days of journal entries, top 10 todos, README excerpt, 10 latest commits, recent blog headings | You want the AI to reference journal reflections, git history, or ensure it doesn’t duplicate recent posts. |

Because full context is a lot of text, prefer `-c` by default and reach for `-C` only when the extra detail matters.

Examples:

```bash
# Minimal context
blog g -p Sarah -a guide -c "Digital declutter plan for doom piles"

# Full context (journal/todos/git/blog)
blog g -p Brenda -a blog -C "Doctor visit prep checklist"
```

Behind the scenes, the command:
1. Loads the persona block from `docs/personas.md`.
2. Loads the requested Hugo archetype file (`archetypes/<type>.md`).
3. Passes both into `dhp-content.sh`, which saves the draft to `CONTENT_OUTPUT_DIR`.

---

## 3. Refining Existing Posts

When a draft already exists inside the Hugo repo:

```bash
blog refine "$BLOG_DIR/content/blog/energy-first-planning.md"
```

This pipes the file’s content to `dhp-content.sh "refine blog post"`, letting the AI polish without changing front matter.

---

## 4. Stubs & Legacy Commands

`blog stubs` and `blog random` still look for `content stub` markers. If you no longer rely on stub markers, you can ignore those commands—or remove them later.

---

## 5. Recommended Workflow

1. **Ideate:** Use `blog ideas "topic"` to scan the journal for themes.
2. **Draft:** Run `blog g -p ... -a ... -s ... "brief"` (files land directly in the correct folder).
3. **Review:** Open the generated file in-place under `$BLOG_DIR/content/...` (it stays `draft: true` until publish), edit in VS Code.
4. **Refine:** `blog r path/to/post.md` for last-mile polish.
5. **Validate:** `blog v` before committing.

---

### Copy/Paste Smoke Tests

Run these periodically to verify each exemplar + section path is still wired up correctly (each command writes a `draft: true` file into the matching folder):

```bash
# Guides – AI Frameworks (Advanced Prompting exemplar)
blog g -p "Sarah" -a guide -s guides/ai-frameworks "Smoke test: AI frameworks guide"

# Guides – Brain Fog (Daily Briefing exemplar)
blog g -p "Brenda" -a guide -s guides/brain-fog "Smoke test: Brain fog guide"

# Guides – Keyboard Efficiency (Core Five Shortcuts exemplar)
blog g -p "Mark" -a guide -s guides/keyboard-efficiency "Smoke test: keyboard efficiency guide"

# Guides – Productivity Systems (Prompt Versioning exemplar)
blog g -p "Sarah" -a guide -s guides/productivity-systems "Smoke test: productivity system guide"

# Blog – Automation & Disability exemplar
blog g -p "Brenda" -a blog -s blog "Smoke test: blog post automation"

# Prompts – BLUF Decision exemplar
blog g -p "Sarah" -a prompt-card -s prompts "Smoke test: prompt card"

# Shortcuts – Automations (AI Summary Spotlight exemplar)
blog g -p "Mark" -a shortcut-spotlight -s shortcuts/automations "Smoke test: automation spotlight"

# Shortcuts – Keyboard Shortcuts (Core Five Spotlight exemplar)
blog g -p "Mark" -a shortcut-spotlight -s shortcuts/keyboard-shortcuts "Smoke test: keyboard spotlight"

# Shortcuts – System Instructions (Brain Fog Assistant Persona exemplar)
blog g -p "Brenda" -a system-instruction -s shortcuts/system-instructions "Smoke test: system instruction"
```

Delete the generated drafts afterward if you don’t want to keep them; they’re only meant to validate wiring.

---

## 6. Troubleshooting

- `blog generate` exits immediately: ensure `BLOG_DIR` etc. are set and the archetype file exists under `$BLOG_ARCHETYPES_DIR`.
- Persona errors: verify the heading exists in `docs/personas.md` (e.g., `## Calm Coach`).
- OpenRouter failures: double-check `OPENROUTER_API_KEY` in `.env`.

---

## Related Docs

- [Personas](personas.md)
- [AI Quick Reference](ai-quick-reference.md)
- [System Overview](system-overview.md)
- [Troubleshooting](../TROUBLESHOOTING.md)

---

Keep this doc up to date if Hugo paths or workflows change. It should be the one-stop reference for “how do my dotfiles talk to my MS site?”.***
