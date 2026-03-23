# Morphling: Architecture Deep Dive

Morphling is the "Universal Adaptive Specialist" in the dotfiles AI toolkit. This document covers what Morphling is, how it works, where it fits in the broader Cyborg + Blog workflow, and the gap between its declared capabilities and current wiring.

---

## Identity

- **Role:** Universal Adaptive Specialist
- **Motto:** "I am the context. I am the code. I am whatever the problem needs me to be."
- **Personality:** Hyper-malleable, context-obsessed, outcome-driven. A chameleon that adopts the perfect persona for the task at hand.
- **Definition:** `ai-staff-hq/staff/meta/morphling.yaml`

Morphling is the only AI-Staff-HQ specialist with tools enabled. All other specialists are conversation-only; Morphling gets file system access, command execution, and a ReAct agent loop.

---

## Three Pathways

Morphling operates through three distinct pathways, each with different capabilities:

| Pathway | Trigger | Can Read | Can Write | Can Execute | Can Iterate |
|---------|---------|----------|-----------|-------------|-------------|
| Direct mode | `morphling` | Files | Files | Yes (shell) | Yes (multi-turn) |
| Swarm mode | `morphling --swarm` | Context dump | No | No | No (one-shot) |
| Build mode | `cyborg auto --build` | Via AI | Via Python agent | Yes (verify loop) | Yes (up to 3 rounds) |

### Direct Mode (Interactive)

**Invocation:** `morphling` or `morphling -q "query"`

**Flow:**

1. `bin/morphling.sh` validates prerequisites (`uv`, `ai-staff-hq/` submodule)
2. Calls `uv run --project ai-staff-hq python tools/activate.py morphling`
3. Builds system prompt from YAML via `PromptBuilder`
4. Creates `SpecialistAgent` with ReAct executor and 4 tools
5. Maintains conversation state in `~/.ai-staff-hq/sessions/morphling/[session-id].json`

**Tools Available:**

| Tool | Description |
|------|-------------|
| `read_file(path)` | Read any file, resolves paths relative to `USER_CWD` |
| `write_file(path, content)` | Write/create files, auto-creates parent directories |
| `list_directory(path)` | List files and directories |
| `run_command(command, working_directory)` | Run a shell command (60s timeout, 10K output limit) |

**Key properties:**

- Multi-turn conversation with persistent history
- Supports `--resume [session-id]` to continue past sessions
- LangChain ReAct loop: reason, use tool, observe, repeat
- Can explore a project, understand context, and write files iteratively
- Can run tests, install dependencies, compile code, and verify its own work
- Closed-loop build-test-fix: write code, run it, see errors, fix, repeat

This is the lead developer pathway. Morphling can take an idea, write the code, run the tests, and iterate until it works.

### Swarm Mode (Pre-Analysis)

**Invocation:** `morphling --swarm "query"` or piped input

**Flow:**

1. `bin/dhp-morphling.sh` gathers environmental context
2. Builds a context block with git branch, status, directory tree, working directory
3. Pipes structured prompt to OpenRouter
4. Returns a single response

**Context block Morphling receives:**

```
--- GIT CONTEXT ---
Branch: [current]
Status: [git status --short]

--- DIRECTORY STRUCTURE (Depth 2) ---
[tree output]

--- WORKING DIRECTORY ---
[pwd]
```

This is a one-shot path with no tools and no persistence. Used by `cyborg auto` to generate a domain-expert brief about a target repo before the content pipeline runs.

### Build Mode (Project Scaffolding)

**Invocation:** `cyborg auto --build "your project idea"`

**Flow:**

1. Shell launcher (`bin/cyborg`) detects `--build` flag, skips Morphling pre-analysis
2. Python agent calls `build_project_from_idea()` in `scripts/cyborg_agent.py`
3. Sends idea to OpenRouter with `MORPHLING_BUILD_PROMPT`
4. AI returns a JSON scaffold:

```json
{
  "name": "project-slug",
  "description": "One-line description",
  "files": {
    "path/file.py": "full file contents...",
    "README.md": "readme contents..."
  }
}
```

5. Python agent validates and writes all files to `~/Projects/<name>/`
6. Initializes git repo and commits scaffold
7. Passes project path to Cyborg for documentation

**Build prompt instructions:**

- Shapeshift into the ideal senior engineer for the project
- Pick the best language, framework, and tools
- Generate complete, working source files (no placeholder comments)
- Include README with setup and usage instructions
- Include basic tests or test placeholder
- Keep it focused: minimum viable project

After the scaffold is written, a **build-verify-fix loop** automatically kicks in:

1. Detects the project type from marker files (`package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, `Makefile`)
2. Runs the appropriate install and test commands
3. If tests fail, sends the error output back to the Morphling persona
4. AI returns corrected files, which are written and re-tested
5. Repeats up to 3 rounds, then commits the fixes

This means `cyborg auto --build` produces verified, working projects — not just scaffolds that might compile.

---

## Where Morphling Fits in the Pipeline

```
┌─────────────┐      ┌──────────────┐      ┌──────────────────┐
│  Morphling   │ ───> │    Cyborg     │ ───> │   cyborg-sync    │
│ (understand) │      │  (discover)   │      │   (maintain)     │
│              │      │              │      │                  │
│ Domain-expert│      │ Interactive   │      │ Manifest-driven  │
│ pre-analysis │      │ ingest/draft  │      │ repeatable sync  │
└─────────────┘      └──────────────┘      └──────────────────┘
```

**Two convergence paths with Cyborg:**

| Path | Trigger | Flow |
|------|---------|------|
| Pre-analysis | `cyborg auto` | Morphling `--swarm` reads repo, brief exported as `CYBORG_MORPHLING_BRIEF`, Cyborg drafts with domain context |
| Build mode | `cyborg auto --build "idea"` | Morphling scaffolds project, Cyborg scans and documents the fresh repo |

Both end with the same A-E choice prompt:

- **A** Apply everything
- **B** Drafts only
- **C** Links only
- **D** Save for later
- **E** Drop into interactive

---

## The Full Cyborg + Blog Workflow

### Architecture Overview

```
Project Repo              Cyborg Lab Blog Site         Dotfiles Tools
    |                           |                            |
.cyborg-docs.toml         content/projects/             cyborg-sync
.cyborg-docs-notes.md     content/workflows/            morphling
README.md                 content/artifacts/            cyborg
Code changes              Archetypes/                   cyborg_agent.py
                          site validator                cyborg_docs_sync.py
```

**Two pathways for two energy levels:**

- **High energy / exploratory:** `cyborg` (interactive, chatty, A/B/C/D/E choices)
- **Low energy / repeatable:** `cyborg-sync` (manifest-driven, no decisions, atomic)

### cyborg-sync Pipeline (scripts/cyborg_docs_sync.py)

**Phase 1 — Context Collection:**

- Resolves git diff range (base/head refs with smart fallbacks)
- Reads README (6K limit), `.cyborg-docs-notes.md` (4K), diff (18K, 12 files max)
- Reads existing page content (14K) and parses frontmatter
- Loads blog archetypes for type-specific templates

**Phase 2 — AI Generation (per page):**

- Builds structured JSON payload: page spec, repo data, diff, archetype
- System prompt enforces hard rules: work only from provided data, never invent facts, match archetype exactly, smart-fifth-grader reading level
- AI returns `{markdown, confidence, changed_sections, uncertain_points}`
- Post-processing: frontmatter merge (archetype < existing < AI), metadata normalization, H2 validation, readability check (Flesch-Kincaid <= 6.5), internal link normalization

**Phase 3 — Validate and Commit:**

- Confidence filter (default 0.72 threshold, pages below are skipped)
- Repo checks (test commands from manifest)
- Site checks (scoped validation plus full Hugo link check)
- Atomic rollback on any failure (no partial writes)
- Commits on current branch by default, or `--create-branch` for review branches

### The Manifest System (.cyborg-docs.toml)

The manifest is the contract between project and blog:

```toml
blog_root = "~/Projects/my-ms-ai-blog"
test_commands = ["go test ./..."]
site_check_commands = ["bash scripts/validate-links.sh"]

[[pages]]
key = "project-page"
path = "content/projects/my-project.md"
type = "project"          # project|workflow|artifact|log|reference|stack|protocol
mode = "update"           # update (must exist) or create (write if missing)
track = "Productivity"    # becomes categories frontmatter
draft = false
```

### Safety Properties

- **Confidence filtering** (0.72 threshold) prevents low-quality AI output from landing
- **Archetype enforcement** keeps generated pages consistent with blog templates
- **Readability gating** (Flesch-Kincaid <= 6.5) keeps prose accessible
- **Internal link normalization** uses fuzzy token matching against known site paths
- **Atomic rollback** ensures all-or-nothing commits; check failure restores originals
- **Size limits** (README 6K, diff 18K, page 14K, notes 4K) prevent token explosion
- **Description normalization** (140-160 chars) keeps SEO-consistent metadata

### GitHub Action Integration

Template: `templates/cyborg-docs-sync.github-action.yml`

Triggers on push to `main`. The action checks out the project repo, blog site, and dotfiles, then runs:

```bash
cyborg-sync \
  --repo "$GITHUB_WORKSPACE" \
  --blog-root "$GITHUB_WORKSPACE/my-ms-ai-blog" \
  --base-ref "${{ github.event.before }}" \
  --head-ref "${{ github.sha }}" \
  sync \
  --commit
```

Every push to `main` triggers automatic docs updates, validated and committed to the site repo.

---

## Constants and Defaults

**Size limits (prevent token explosion):**

| Constant | Value |
|----------|-------|
| `MAX_README_CHARS` | 6000 |
| `MAX_DIFF_CHARS` | 18000 |
| `MAX_PAGE_CHARS` | 14000 |
| `MAX_NOTES_CHARS` | 4000 |

**Quality thresholds:**

| Constant | Value |
|----------|-------|
| `CONFIDENCE_THRESHOLD` | 0.72 (configurable) |
| `READABILITY_WARN_GRADE` | 6.5 (Flesch-Kincaid) |
| `DESCRIPTION_MIN_CHARS` | 140 |
| `DESCRIPTION_MAX_CHARS` | 160 |

**Page types:** project, workflow, artifact, log, reference, stack, protocol

**Command execution (run_command tool):**

| Constant | Value |
|----------|-------|
| `_DEFAULT_TIMEOUT_SECONDS` | 60 |
| `_MAX_OUTPUT_CHARS` | 10000 |

**Build-verify loop:**

| Constant | Value |
|----------|-------|
| `BUILD_VERIFY_MAX_ROUNDS` | 3 |
| `BUILD_VERIFY_TIMEOUT_SECONDS` | 120 |

Supported project types for auto-verification:

| Marker File | Install Command | Test Command |
|-------------|----------------|--------------|
| `package.json` | `npm install` | `npm test` |
| `requirements.txt` | `pip install -r requirements.txt` | `python -m pytest` |
| `setup.py` | `pip install -e .` | `python -m pytest` |
| `pyproject.toml` | `pip install -e .` | `python -m pytest` |
| `go.mod` | — | `go build ./... && go test ./...` |
| `Cargo.toml` | — | `cargo build && cargo test` |
| `Makefile` | — | `make` |

**API defaults:**

- Model fallback chain: `CYBORG_DOCS_SYNC_MODEL` > `CYBORG_MODEL` > `CONTENT_MODEL` > `STRATEGY_MODEL` > Nemotron free tier
- Temperature: 0.25 (low variance for documentation)
- Response format: JSON only

---

## Capabilities

### What Morphling Can Do

| Capability | Pathway | How |
|------------|---------|-----|
| Take an idea and build a working project | Build mode | Scaffold + verify loop |
| Run tests and iterate on failures | Direct mode, Build mode | `run_command` tool / verify loop |
| Install dependencies | Direct mode, Build mode | `run_command` tool / verify loop |
| Compile and verify code works | Direct mode, Build mode | `run_command` tool / verify loop |
| Read, write, and explore project files | Direct mode | `read_file`, `write_file`, `list_directory` |
| Analyze a codebase for documentation | Swarm mode | Context dump + domain-expert brief |
| Adapt persona to any domain | All modes | YAML-defined shapeshifting |
| Multi-turn iterative development | Direct mode | ReAct loop with persistent session |

### Current Limitations

| Limitation | Why | Workaround |
|------------|-----|------------|
| No git integration in direct mode | No git tool wired | Use `run_command("git ...")` |
| Build mode capped at 3 fix rounds | Prevents infinite loops | Drop into direct mode to continue |
| Complex multi-service architectures | JSON scaffold size constraints | Build services individually |
| No interactive commands (e.g. `vim`) | Subprocess capture mode | Use non-interactive alternatives |

---

## Key Files

**Core definition:**

- `ai-staff-hq/staff/meta/morphling.yaml` — identity and declared capabilities

**Engine and tools:**

- `ai-staff-hq/tools/engine/core.py` — tool enablement (lines 219-224)
- `ai-staff-hq/tools/engine/capabilities.py` — read_file, write_file, list_directory, run_command
- `ai-staff-hq/tools/engine/prompt.py` — system prompt building

**Launchers:**

- `bin/morphling.sh` — direct mode launcher
- `bin/dhp-morphling.sh` — swarm mode dispatcher

**Build integration:**

- `scripts/cyborg_agent.py` — `MORPHLING_BUILD_PROMPT`, `MORPHLING_FIX_PROMPT`, `build_project_from_idea()`, `_verify_and_fix_scaffold()`

**Cyborg integration:**

- `bin/cyborg` — pre-analysis path (lines 37-118)
- `bin/autopilot-readme.md` — convergence architecture docs

**Tests:**

- `tests/test_morphling_wrapper.sh` — direct vs swarm mode tests

---

## Disrupt the Market With Brilliant Ideas (For Fun and Profit)

Morphling's build pipeline turns a one-liner into a verified, documented, blog-published project. The entire cycle from idea to live content can happen in a single terminal session. Here are recipes for using that to ship fast.

### The 60-Second MVP

You have a shower thought. Before the water gets cold:

```bash
cyborg auto --build --yes "CLI that scores restaurant menus by accessibility for wheelchair users"
```

Morphling picks the stack, writes the code, runs the tests, fixes what breaks, commits it. Cyborg documents it and publishes. You dry off and check the blog.

### The Portfolio Builder

Ship five projects in an afternoon. Each one is verified, documented, and blog-ready:

```bash
cyborg auto --build "rust CLI that converts voice memos to structured meeting notes"
cyborg auto --build "python tool that generates color palettes optimized for color-blind users"
cyborg auto --build "go service that monitors RSS feeds and summarizes new posts with AI"
cyborg auto --build "node CLI that audits npm dependencies for license compliance"
cyborg auto --build "bash toolkit for batch-renaming files with undo support"
```

Each run scaffolds, verifies, and documents independently. The blog accumulates project pages and workflow guides automatically.

### The Prototype-First Pitch

Have a meeting tomorrow? Build the demo tonight:

```bash
# Build the prototype
cyborg auto --build --projects-dir ~/Demos "dashboard that visualizes spoon budget trends over time"

# Polish it in direct mode
cd ~/Demos/spoon-budget-dashboard
morphling
```

In the interactive session, Morphling can read what it built, run the dev server, tweak the UI, and verify everything passes. You walk into the meeting with working code and a blog post explaining it.

### The Competitive Spike

See a gap in the market? Test whether you can fill it before anyone writes a business plan:

```bash
cyborg auto --build "browser extension that highlights AI-generated text on any webpage"
```

If the verify loop passes, you have a working prototype. If it fails after 3 rounds, the idea might be harder than it looks and that is useful information too.

### The Accessibility Angle

Every project Morphling builds gets documented at a smart-fifth-grader reading level (Flesch-Kincaid <= 6.5) and published with proper frontmatter, categories, and internal links. This means:

- Your projects are discoverable
- Your documentation is accessible to people with cognitive fatigue
- Your blog builds itself as a side effect of building things

### The Low-Energy Play

Brain fog day but still want to ship? Three keystrokes:

```bash
apb "your idea here"
```

That is the alias for `cyborg auto --build`. Morphling builds. Morphling verifies. Cyborg documents. You press A. Done.

### Direct Mode: The Senior Engineer on Call

For ideas that need more nuance than a one-shot scaffold, use Morphling directly:

```bash
cd ~/Projects/my-new-thing
morphling
```

Then talk to it like a lead developer:

```
> Read the current test suite and tell me what is missing
> Write integration tests for the API endpoints
> Run the tests
> Fix the two failures you see
> Run them again
> Now add rate limiting to the /api/search endpoint
> Run the tests one more time to make sure nothing broke
```

Morphling reads, writes, runs, and iterates. You steer. The code improves with each loop.

---

## 101 Sure-Fire Million Dollar Project Ideas

Every one of these is a valid `cyborg auto --build` one-liner. Copy, paste, ship.

### Accessibility and Disability Tech

1. `"browser extension that reads any webpage aloud with adjustable speed and voice"`
2. `"app that converts hand-drawn sketches into accessible SVG diagrams with alt text"`
3. `"CLI that audits a website for WCAG 2.2 compliance and generates a fix report"`
4. `"tool that generates audio descriptions of images for visually impaired users"`
5. `"keyboard-only navigation overlay that works on any website"`
6. `"app that translates medical jargon into plain language at a fifth-grade reading level"`
7. `"wearable-friendly API that tracks fatigue patterns and suggests rest windows"`
8. `"service that converts PDF documents into accessible HTML with proper heading structure"`
9. `"browser extension that adjusts page contrast and font size based on time of day and user fatigue"`
10. `"app that generates simplified summaries of legal documents for people with cognitive disabilities"`

### Health and Wellness

11. `"spoon theory energy tracker with predictive budgeting based on historical patterns"`
12. `"medication interaction checker that pulls from FDA databases and explains risks simply"`
13. `"symptom journal that correlates entries with weather, sleep, and activity data"`
14. `"meal planner that adapts to energy levels and available ingredients"`
15. `"hydration tracker that learns your patterns and nudges at optimal times"`
16. `"sleep quality analyzer that reads data from any fitness tracker CSV export"`
17. `"mental health check-in bot that detects mood trends and suggests coping strategies"`
18. `"exercise adapter that modifies workout plans based on daily pain and fatigue levels"`
19. `"brain fog severity tracker that measures cognitive load through simple reaction-time games"`
20. `"chronic illness flare predictor that learns triggers from journal entries"`

### Developer Tools

21. `"git hook that blocks commits containing API keys, passwords, or secrets"`
22. `"CLI that generates comprehensive test suites from reading existing source code"`
23. `"tool that converts any REST API into a type-safe SDK in your language of choice"`
24. `"dependency vulnerability scanner that explains each CVE in plain English"`
25. `"database migration diffing tool that previews exactly what will change before you run it"`
26. `"CLI that generates architecture diagrams from import graphs"`
27. `"log analyzer that clusters errors by root cause and suggests fixes"`
28. `"tool that converts Postman collections into integration test suites"`
29. `"CLI that profiles shell startup time and identifies the slowest sourced files"`
30. `"automated code reviewer that checks for OWASP top 10 vulnerabilities"`

### AI and Machine Learning

31. `"prompt testing framework that runs the same prompt against multiple models and compares outputs"`
32. `"tool that estimates API costs before running a batch of AI requests"`
33. `"local embeddings search engine that indexes your personal documents"`
34. `"AI output detector that scores text for likelihood of being machine-generated"`
35. `"fine-tuning data curator that cleans, deduplicates, and validates JSONL training sets"`
36. `"prompt version control system with A/B testing and metrics tracking"`
37. `"tool that converts natural language descriptions into SQL queries with safety checks"`
38. `"AI model output comparator that visualizes differences across model versions"`
39. `"token counter and cost estimator for any LLM API with budget alerts"`
40. `"RAG pipeline builder that chunks, embeds, and indexes any document collection"`

### Content and Publishing

41. `"blog post generator that reads a GitHub repo and writes a technical walkthrough"`
42. `"SEO analyzer that scores content and suggests improvements without keyword stuffing"`
43. `"RSS-to-newsletter converter that summarizes and curates feeds into weekly digests"`
44. `"readability scorer that rewrites dense paragraphs at a target grade level"`
45. `"markdown-to-podcast script converter optimized for text-to-speech"`
46. `"social media scheduler that generates platform-specific variants from one source post"`
47. `"changelog generator that reads git history and writes human-friendly release notes"`
48. `"documentation freshness checker that flags docs older than their source code"`
49. `"tool that converts conference talks into blog posts from transcript files"`
50. `"content calendar generator that plans posts around trending topics in your niche"`

### Finance and Business

51. `"invoice generator that reads time-tracking CSV files and produces PDF invoices"`
52. `"expense categorizer that reads bank statement CSVs and generates tax-ready reports"`
53. `"S-Corp salary vs distribution optimizer that models different tax scenarios"`
54. `"subscription tracker that monitors recurring charges and alerts on price increases"`
55. `"freelance rate calculator that factors in taxes, insurance, and time off"`
56. `"cash flow forecaster that reads transaction history and predicts upcoming shortfalls"`
57. `"contract clause analyzer that flags unusual terms in freelance agreements"`
58. `"quarterly tax estimator that reads income data and generates IRS payment vouchers"`
59. `"SaaS metrics dashboard that calculates MRR, churn, and LTV from Stripe exports"`
60. `"product pricing optimizer that models demand curves from historical sales data"`

### Productivity and Automation

61. `"meeting summarizer that reads transcript files and extracts action items"`
62. `"email template engine that generates personalized outreach from a CSV contact list"`
63. `"file organization tool that sorts downloads into folders based on content type"`
64. `"clipboard manager that searches history and supports templates"`
65. `"pomodoro timer that adapts work and break intervals based on focus quality"`
66. `"daily standup generator that reads git logs and calendar entries"`
67. `"task dependency visualizer that reads a todo list and generates a critical path diagram"`
68. `"context switcher that saves and restores sets of open files, tabs, and terminal state"`
69. `"recurring task scheduler that escalates overdue items and tracks completion streaks"`
70. `"voice memo transcriber that converts audio files to structured markdown notes"`

### Data and Analytics

71. `"CSV cleaning tool that detects and fixes common data quality issues"`
72. `"data pipeline monitor that alerts when row counts or distributions shift unexpectedly"`
73. `"database schema visualizer that generates ER diagrams from live connections"`
74. `"A/B test significance calculator with clear explanations of results"`
75. `"survey response analyzer that clusters open-text answers by theme"`
76. `"web scraper generator that reads a target page and produces a scraping script"`
77. `"data anonymizer that replaces PII in datasets while preserving statistical properties"`
78. `"JSON schema generator that infers types from example data"`
79. `"log parser that converts unstructured log files into queryable structured data"`
80. `"metrics alerting tool that learns normal ranges and flags anomalies"`

### Education and Learning

81. `"flashcard generator that reads textbook chapters and creates spaced repetition decks"`
82. `"code tutorial builder that converts working code into step-by-step lessons"`
83. `"quiz generator that reads any document and creates multiple-choice questions"`
84. `"concept map generator that reads course notes and visualizes relationships"`
85. `"reading level adapter that rewrites any text at a specified grade level"`
86. `"homework helper that shows work step-by-step without giving direct answers"`
87. `"language learning tool that generates conversation practice from vocabulary lists"`
88. `"study schedule optimizer that spaces topics based on difficulty and retention curves"`
89. `"technical glossary builder that reads a codebase and defines every domain term"`
90. `"lecture note summarizer that extracts key points and generates review sheets"`

### Creative and Media

91. `"color palette generator that creates accessible combinations from a seed color"`
92. `"font pairing recommender that analyzes heading and body combinations"`
93. `"audio drama script formatter optimized for text-to-speech voice synthesis"`
94. `"story structure analyzer that maps narrative beats in any text"`
95. `"thumbnail generator that creates social media preview images from post titles"`
96. `"music practice tracker that logs sessions and visualizes progress over time"`
97. `"writing style analyzer that compares your prose to authors you admire"`
98. `"dialogue rewriter that adjusts character voice consistency across a manuscript"`
99. `"worldbuilding database that tracks characters, locations, and timelines"`
100. `"beat sheet generator that converts a logline into a structured screenplay outline"`

### The Wildcard

101. `"meta-tool that reads this list, picks the idea most likely to succeed based on current market trends, and builds it"`

### How to Use This List

Pick any idea. Paste it:

```bash
cyborg auto --build "the idea you picked from the list above"
```

Morphling builds it. The verify loop tests it. Cyborg documents it. Your blog grows. Repeat until wealthy or bored.

---

## Quick Reference

```bash
# Interactive session (direct mode with file tools)
morphling

# One-shot query (direct mode)
morphling -q "How should I structure this API?"

# Resume a past session
morphling --resume SESSION_ID

# Pre-analysis for Cyborg (swarm mode)
morphling --swarm "Analyze this repo for documentation"

# Scaffold a project from an idea (build mode via Cyborg)
cyborg auto --build "CLI tool that audits npm dependencies for license compliance"

# Full autopilot with Morphling pre-analysis
cyborg auto --repo ~/Projects/my-project
```
