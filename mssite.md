# MS Blog Site Reference

**Root:** `/Users/ryanjohnson/Projects/my-ms-ai-blog`  
**Engine:** Hugo (PaperMod theme, Dark default)  
**Primary Sections:** prompts, shortcuts, guides, blog  
**Base URL:** `https://ryanleej.com/`

## Directory Overview
- `content/` – Published posts (organized by section). Key subsections:
  - `guides/` (subfolders for `brain-fog`, `keyboard-efficiency`, `ai-frameworks`, `productivity-systems`)
  - `shortcuts/` (subfolders `keyboard-shortcuts`, `automations`, `system-instructions`)
  - `prompts/`, `blog/`, and `_archive/` (retired articles)
  - Section index pages (e.g., `guides/brain-fog/_index.md`, `shortcuts/_index.md`) define navigation copy.
- `drafts/` – Work-in-progress posts surfaced by `blog status`.  
- `archetypes/` – Hugo scaffolding templates for new content (blog, guide, prompt-card, shortcut spotlights, default).  
- `assets/`, `static/`, `layouts/`, `themes/` – Standard Hugo asset/theme structure (`PaperMod`).  
- `public/` – Latest build output (safe to delete/regenerate).  
- `openspec/`, `docs/` – Spec workflows and authoring references.  
- Supporting docs: `GUIDE-WRITING-STANDARDS.md`, `VERSIONING-POLICY.md`, `content-backlog.md`, `todo-ia.md`, etc.

## Key Config (hugo.toml)
- `languageCode = "en-us"`, `title = "My MS & AI Journey"`.  
- `relativeURLs = true`, `canonifyURLs = false`.  
- `pagination.pagerSize = 12`.  
- `params.mainSections = ["prompts", "shortcuts", "guides", "blog"]`.  
- Features enabled: TOC, breadcrumbs, share buttons, code copy, RSS, fuse.js search.  
- Social links: GitHub `ryan258`, LinkedIn `ryanleejohnson`, Twitter `@ryanwithms`.  
- Analytics: Google Analytics `G-QK3SYFSVNS`.  
- Sitemap weekly, taxonomies `categories` and `tags`.

## Validation Targets (for `blog validate`)
- Front matter completeness (title, date, summary, tags).  
- Accessibility & standards: see `GUIDE-WRITING-STANDARDS.md`.  
- Link health within `content/`.  
- Draft backlog surfaced via `drafts/` + `content-backlog.md`.  
- Versioning rules: per `VERSIONING-POLICY.md`.

## Useful Paths
- `BLOG_DIR` (in `.env`): `/Users/ryanjohnson/Projects/my-ms-ai-blog`.  
- Recent content command: `scripts/blog_recent_content.sh` reads `BLOG_CONTENT_DIR`.  
- Spec workflows: `openspec/`, `docs/AGENTS.md`, etc.  
- Build command: `hugo --gc --minify` from repo root.
