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

| Pathway     | Trigger               | Can Read     | Can Write        | Can Execute       | Can Iterate          |
| ----------- | --------------------- | ------------ | ---------------- | ----------------- | -------------------- |
| Direct mode | `morphling`           | Files        | Files            | Yes (shell)       | Yes (multi-turn)     |
| Swarm mode  | `morphling --swarm`   | Context dump | No               | No                | No (one-shot)        |
| Build mode  | `cyborg auto --build` | Via AI       | Via Python agent | Yes (verify loop) | Yes (up to 3 rounds) |

### Direct Mode (Interactive)

**Invocation:** `morphling` or `morphling -q "query"`

**Flow:**

1. `bin/morphling.sh` validates prerequisites (`uv`, `ai-staff-hq/` submodule)
2. Calls `uv run --project ai-staff-hq python tools/activate.py morphling`
3. Builds system prompt from YAML via `PromptBuilder`
4. Creates `SpecialistAgent` with ReAct executor and 4 tools
5. Maintains conversation state in `~/.ai-staff-hq/sessions/morphling/[session-id].json`

**Tools Available:**

| Tool                                      | Description                                          |
| ----------------------------------------- | ---------------------------------------------------- |
| `read_file(path)`                         | Read any file, resolves paths relative to `USER_CWD` |
| `write_file(path, content)`               | Write/create files, auto-creates parent directories  |
| `list_directory(path)`                    | List files and directories                           |
| `run_command(command, working_directory)` | Run a shell command (60s timeout, 10K output limit)  |

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
2. Market validation: searches GitHub + npm for existing solutions, AI synthesizes a competitive landscape report, user decides to proceed/revise/cancel (skip with `--no-validate`)
3. Python agent calls `build_project_from_idea()` in `scripts/cyborg_build.py`
4. Sends idea to OpenRouter with `MORPHLING_BUILD_PROMPT`
5. AI returns a JSON scaffold:

```json
{
  "name": "project-slug",
  "description": "One-line description",
  "keywords": ["keyword1", "keyword2", "keyword3"],
  "license": "MIT",
  "files": {
    "path/file.py": "full file contents...",
    "README.md": "readme contents..."
  }
}
```

6. Python agent validates and writes all files to `~/Projects/<name>/`
7. Initializes git repo and commits scaffold
8. If `--publish`: detects ecosystem, validates prerequisites, creates GitHub repo, publishes to registry
9. Passes project path to Cyborg for documentation

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

### Publishing (`--publish` flag)

When `--publish` is added to the build command, the pipeline extends from verified project to installable package:

```bash
cyborg auto --build --publish "CLI that scores menus by accessibility"
```

**Supported ecosystems:**

| Marker | Registry | What Happens |
| --- | --- | --- |
| `package.json` | npm | `npm publish --access public` |
| `pyproject.toml` | PyPI | `python3 -m build` + `twine upload dist/*` |
| `setup.py` | PyPI | `python3 -m build` + `twine upload dist/*` |
| `Cargo.toml` | crates.io | `cargo publish` |
| `go.mod` | GitHub Releases | `gh release create v0.1.0` |

**Prerequisites:** Set registry tokens in `.env` (see `.env.example` for details):

- npm: `NPM_TOKEN`
- PyPI: `TWINE_USERNAME` + `TWINE_PASSWORD`
- crates.io: `CARGO_REGISTRY_TOKEN`
- Go: `gh auth login` (uses GitHub CLI auth)

**Safety:** Publish is irreversible. The pipeline confirms before publishing unless `--yes` is passed. If prerequisites are missing, publish is skipped with a clear message — the rest of the pipeline continues normally.

**Aliases:** `apbp` (build+publish) and `apbpy` (build+publish+yes).

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

| Path         | Trigger                      | Flow                                                                                                          |
| ------------ | ---------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Pre-analysis | `cyborg auto`                | Morphling `--swarm` reads repo, brief exported as `CYBORG_MORPHLING_BRIEF`, Cyborg drafts with domain context |
| Build mode   | `cyborg auto --build "idea"` | Morphling scaffolds project, Cyborg scans and documents the fresh repo                                        |

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

| Constant           | Value |
| ------------------ | ----- |
| `MAX_README_CHARS` | 6000  |
| `MAX_DIFF_CHARS`   | 18000 |
| `MAX_PAGE_CHARS`   | 14000 |
| `MAX_NOTES_CHARS`  | 4000  |

**Quality thresholds:**

| Constant                 | Value                |
| ------------------------ | -------------------- |
| `CONFIDENCE_THRESHOLD`   | 0.72 (configurable)  |
| `READABILITY_WARN_GRADE` | 6.5 (Flesch-Kincaid) |
| `DESCRIPTION_MIN_CHARS`  | 140                  |
| `DESCRIPTION_MAX_CHARS`  | 160                  |

**Page types:** project, workflow, artifact, log, reference, stack, protocol

**Command execution (run_command tool):**

| Constant                   | Value |
| -------------------------- | ----- |
| `_DEFAULT_TIMEOUT_SECONDS` | 60    |
| `_MAX_OUTPUT_CHARS`        | 10000 |

**Build-verify loop:**

| Constant                       | Value |
| ------------------------------ | ----- |
| `BUILD_VERIFY_MAX_ROUNDS`      | 3     |
| `BUILD_VERIFY_TIMEOUT_SECONDS` | 120   |

Supported project types for auto-verification:

| Marker File        | Install Command                   | Test Command                      |
| ------------------ | --------------------------------- | --------------------------------- |
| `package.json`     | `npm install`                     | `npm test`                        |
| `requirements.txt` | `pip install -r requirements.txt` | `python -m pytest`                |
| `setup.py`         | `pip install -e .`                | `python -m pytest`                |
| `pyproject.toml`   | `pip install -e .`                | `python -m pytest`                |
| `go.mod`           | —                                 | `go build ./... && go test ./...` |
| `Cargo.toml`       | —                                 | `cargo build && cargo test`       |
| `Makefile`         | —                                 | `make`                            |

**API defaults:**

- Model fallback chain: `CYBORG_DOCS_SYNC_MODEL` > `CYBORG_MODEL` > `CONTENT_MODEL` > `STRATEGY_MODEL` > Nemotron free tier
- Temperature: 0.25 (low variance for documentation)
- Response format: JSON only

---

## Capabilities

### What Morphling Can Do

| Capability                               | Pathway                 | How                                         |
| ---------------------------------------- | ----------------------- | ------------------------------------------- |
| Take an idea and build a working project | Build mode              | Scaffold + verify loop                      |
| Run tests and iterate on failures        | Direct mode, Build mode | `run_command` tool / verify loop            |
| Install dependencies                     | Direct mode, Build mode | `run_command` tool / verify loop            |
| Compile and verify code works            | Direct mode, Build mode | `run_command` tool / verify loop            |
| Read, write, and explore project files   | Direct mode             | `read_file`, `write_file`, `list_directory` |
| Analyze a codebase for documentation     | Swarm mode              | Context dump + domain-expert brief          |
| Adapt persona to any domain              | All modes               | YAML-defined shapeshifting                  |
| Multi-turn iterative development         | Direct mode             | ReAct loop with persistent session          |

### Current Limitations

| Limitation                           | Why                            | Workaround                        |
| ------------------------------------ | ------------------------------ | --------------------------------- |
| No git integration in direct mode    | No git tool wired              | Use `run_command("git ...")`      |
| Build mode capped at 3 fix rounds    | Prevents infinite loops        | Drop into direct mode to continue |
| Complex multi-service architectures  | JSON scaffold size constraints | Build services individually       |
| No interactive commands (e.g. `vim`) | Subprocess capture mode        | Use non-interactive alternatives  |

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

- `scripts/cyborg_build.py` — `MORPHLING_BUILD_PROMPT`, `MORPHLING_FIX_PROMPT`, `build_project_from_idea()`, `_verify_and_fix_scaffold()`, `_publish_project()`, `validate_market()`
- `scripts/cyborg_support.py` — shared helpers (`run_command`, `run_command_result`, `slugify`, `prompt_input`)

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

## 50 Billion-Dollar Ideas for `cyborg auto`

These are not tiny utilities. They are category-creating wedges: products you could prototype with `cyborg auto --build`, validate quickly, then compound into real businesses.

### AI Infrastructure and Agent Ops

1. `"platform that watches every AI workflow in a company and explains where the money, latency, and failures come from"`
2. `"agent operations dashboard that replays every tool call, decision, and error across autonomous AI workers"`
3. `"prompt firewall that blocks sensitive data leaks, jailbreaks, and unsafe outputs before they reach production users"`
4. `"evaluation platform that tests AI features against real customer scenarios before every deployment"`
5. `"AI budget optimizer that routes every request to the cheapest model that still meets quality thresholds"`
6. `"policy engine that applies legal, security, and brand rules to every model response in real time"`
7. `"team knowledge graph that connects docs, tickets, repos, and chats into one retrieval layer for internal AI agents"`
8. `"tooling framework that turns any SaaS API into a governed, observable action layer for enterprise agents"`
9. `"incident response copilot that reads logs, traces, and runbooks and suggests the next production fix"`
10. `"AI change review system that compares behavior before and after model upgrades and flags regressions"`

### Healthcare, Accessibility, and Care

11. `"care coordination platform that turns fragmented patient notes into one plain-language action plan for families and clinicians"`
12. `"accessibility observability platform that continuously monitors websites and apps for regressions that hurt disabled users"`
13. `"medication adherence system that adapts reminders to energy, cognition, and symptom patterns instead of fixed schedules"`
14. `"clinical paperwork assistant that rewrites forms, summaries, and care instructions into fifth-grade reading level language"`
15. `"fatigue forecasting app that predicts low-capacity windows from wearable, calendar, weather, and symptom data"`
16. `"home care dashboard that helps adult children coordinate tasks, meds, appointments, and status updates for aging parents"`
17. `"insurance appeal generator that assembles medical evidence and drafts stronger reimbursement appeals automatically"`
18. `"hospital discharge translator that converts discharge packets into step-by-step checklists with risk warnings"`
19. `"chronic illness operations system that combines spoon budgeting, work pacing, symptom tracking, and care planning"`
20. `"accessibility testing cloud that records screen reader, keyboard, contrast, and cognitive-load issues across product releases"`

### Developer Platforms and Software Delivery

21. `"codebase intelligence platform that maps every dependency, workflow, owner, and risk surface across engineering teams"`
22. `"release readiness system that blocks deploys when docs, tests, migrations, or rollback plans are incomplete"`
23. `"bug reproduction engine that turns vague support tickets into isolated failing tests developers can run locally"`
24. `"legacy modernization copilot that reads a monolith, proposes safe extraction plans, and scaffolds the first services"`
25. `"customer-facing changelog platform that converts commits and pull requests into readable release updates automatically"`
26. `"security review workspace that finds dangerous code paths and explains real exploit scenarios in plain English"`
27. `"test gap analyzer that shows exactly which business-critical behaviors are still unverified in a codebase"`
28. `"internal developer portal that auto-generates service docs, runbooks, API references, and onboarding guides from source"`
29. `"migration simulator that previews the impact of framework, runtime, or dependency upgrades before teams attempt them"`
30. `"engineering memory system that captures architecture decisions, incident learnings, and tribal knowledge as a searchable graph"`

### Workflow, Knowledge, and Enterprise Productivity

31. `"company operating system that turns meetings, tickets, docs, and calendars into one shared execution layer"`
32. `"decision log platform that records why teams chose something, who approved it, and what assumptions must still be tested"`
33. `"inbox triage agent that reads email, Slack, and support queues and routes work with confidence scoring"`
34. `"manager dashboard that turns team signals into plain-language summaries of risk, morale, velocity, and blockers"`
35. `"meeting-to-execution pipeline that converts transcripts directly into owners, deadlines, and follow-up workflows"`
36. `"document lifecycle tracker that shows which SOPs, policies, and playbooks are drifting away from reality"`
37. `"personal knowledge assistant that turns your notes, highlights, bookmarks, and voice memos into reusable systems"`
38. `"workflow composer that lets non-technical operators build reliable multi-step automations with guardrails and audit trails"`
39. `"research synthesis platform that scans a field, clusters the evidence, and produces executive briefings with citations"`
40. `"procurement intelligence tool that compares vendors across pricing, compliance, lock-in risk, and migration cost"`

### Commerce, Media, and Market Intelligence

41. `"competitive intelligence platform that watches product launches, pricing pages, changelogs, and customer sentiment across a market"`
42. `"creator operating system that turns one idea into blog posts, videos, newsletters, social clips, and analytics automatically"`
43. `"e-commerce experimentation engine that generates, launches, and scores merchandising tests without a full growth team"`
44. `"pricing intelligence system that monitors competitors and recommends when to raise, lower, bundle, or reposition offers"`
45. `"customer voice analyzer that turns reviews, calls, chats, and support tickets into product strategy signals"`
46. `"B2B sales prep engine that builds account briefs, objection maps, and personalized demos before each call"`
47. `"micro-SaaS foundry that continuously validates niches, builds tools, and ranks them by traction, margin, and support burden"`
48. `"trust layer for marketplaces that detects fraud, low-quality listings, and reputation gaming before transactions happen"`
49. `"local business AI stack that gives small companies enterprise-grade scheduling, marketing, CRM, and reporting in one product"`
50. `"market map generator that finds boring high-margin software categories with weak incumbents and suggests the fastest wedge"`

### How to Use This List

Pick the wedge, not the final empire. Start with the smallest sharp edge that proves demand:

```bash
cyborg auto --build "agent operations dashboard that replays every tool call, decision, and error across autonomous AI workers"
```

Then iterate toward the platform:

- Add `--publish` when the wedge is ready to ship.
- Use direct `morphling` mode to deepen the product after the first scaffold.
- Let Cyborg document each iteration so the public narrative compounds with the code.

---

## 50 Trillion-Dollar Ideas for `cyborg auto`

These are not single tools. They are wedge products for markets so large they can turn into operating systems, infrastructure layers, or category-defining platforms.

### Climate, Infrastructure, and Cities

1. `"city resilience operating system that predicts flooding, heat risk, grid strain, and emergency response bottlenecks in one dashboard"`
2. `"energy orchestration platform that coordinates home batteries, EVs, solar, and utility pricing in real time"`
3. `"water network intelligence system that detects leaks, contamination risk, and maintenance priorities across entire municipalities"`
4. `"climate retrofit planner that tells every building owner the cheapest path to lower energy use and higher resilience"`
5. `"disaster logistics platform that matches shelters, volunteers, medical supplies, and transport capacity during regional crises"`
6. `"industrial efficiency engine that finds waste across power, materials, labor, and downtime in manufacturing operations"`
7. `"farm resilience platform that combines weather, soil, water, market pricing, and pest signals into one action layer"`
8. `"construction permitting accelerator that translates local regulations into step-by-step plans for builders and homeowners"`
9. `"global supply chain risk graph that shows where shortages, sanctions, weather, or conflict will break production next"`
10. `"waste-to-resource marketplace that turns surplus materials, scrap, and idle equipment into searchable supply"`

### Health, Care, and Human Capability

11. `"longitudinal health memory system that turns years of records, tests, wearables, and symptoms into one usable timeline"`
12. `"care navigation platform that tells patients exactly what to do next across referrals, insurance, meds, labs, and follow-up"`
13. `"rare disease research engine that clusters case reports, studies, and patient experiences into actionable treatment hypotheses"`
14. `"clinical trial matching network that continuously links patients to relevant studies as their conditions change"`
15. `"workplace accommodation operating system that helps companies personalize support for disability, fatigue, pain, and cognition"`
16. `"rehabilitation companion that adapts therapy plans daily based on pain, mobility, adherence, and progress signals"`
17. `"aging-in-place coordination platform that helps families manage meds, tasks, safety risks, and home services for older adults"`
18. `"medical paperwork simplifier that rewrites forms, discharge packets, and benefit letters into plain-language checklists"`
19. `"population health prediction layer that helps clinics identify who needs intervention before a crisis hits"`
20. `"universal accessibility overlay platform that helps software teams ship better keyboard, screen reader, contrast, and cognitive UX"`

### Knowledge, Work, and Organization Design

21. `"company operating graph that connects goals, meetings, tickets, docs, owners, risks, and decisions in one execution model"`
22. `"decision intelligence system that records why choices were made, what assumptions matter, and when they need revalidation"`
23. `"meeting-to-execution engine that turns every conversation into tasks, owners, timelines, blockers, and follow-up automation"`
24. `"enterprise memory layer that captures tribal knowledge from chat, repos, docs, support, and onboarding flows"`
25. `"regulation-to-workflow compiler that turns legal and policy requirements into step-by-step operational checklists"`
26. `"manager copilot that summarizes team health, delivery risk, morale, and staffing gaps from real operating signals"`
27. `"research synthesis platform that continuously scans an industry and produces executive briefings with citations"`
28. `"procurement intelligence network that compares vendors on price, security, lock-in risk, implementation cost, and reliability"`
29. `"skills-to-work marketplace that maps what people actually know and routes them to the highest-value work automatically"`
30. `"global grant and funding engine that matches startups, nonprofits, and researchers to opportunities they can actually win"`

### Software, AI, and Developer Infrastructure

31. `"agent operations platform that monitors every autonomous workflow for cost, quality, latency, failure modes, and governance drift"`
32. `"software change simulator that predicts what will break before teams merge major architectural, dependency, or runtime changes"`
33. `"bug reproduction engine that turns messy support tickets into isolated failing tests developers can run locally"`
34. `"internal developer operating system that auto-generates service docs, runbooks, architecture maps, and onboarding paths"`
35. `"evaluation cloud for AI features that runs product-specific scenarios before every model, prompt, or toolchain change"`
36. `"security reasoning workspace that explains exploit chains, remediation paths, and blast radius in language teams can act on"`
37. `"API-to-agent platform that converts any SaaS product into a safe, observable action layer for enterprise automation"`
38. `"migration factory that helps companies peel capabilities out of monoliths without losing test coverage or operational context"`
39. `"enterprise prompt firewall that blocks data leaks, policy violations, hallucination patterns, and unsafe tool calls"`
40. `"codebase intelligence graph that maps owners, workflows, risk surfaces, customer impact, and hidden dependency chains"`

### Markets, Commerce, and Economic Coordination

41. `"small business operating system that gives local companies enterprise-grade CRM, scheduling, finance, marketing, and analytics"`
42. `"pricing intelligence network that shows when to raise, lower, bundle, or reposition offers based on live market signals"`
43. `"customer voice engine that turns reviews, calls, chats, and support tickets into product roadmap decisions"`
44. `"trust layer for marketplaces that scores fraud risk, reputation gaming, delivery quality, and dispute patterns before transactions"`
45. `"micro-SaaS foundry that continuously validates niches, ships products, ranks them by traction, and reallocates effort automatically"`
46. `"B2B sales preparation engine that builds account briefs, objection maps, tailored demos, and next-step plans before every call"`
47. `"local services marketplace infrastructure that helps fragmented industries coordinate availability, quality, routing, and payment"`
48. `"real-estate modernization planner that tells owners which upgrades create the most value, resilience, and regulatory compliance"`
49. `"global competitive intelligence layer that watches products, pricing pages, changelogs, hiring, and customer sentiment across a market"`
50. `"market map generator that identifies boring, high-margin software categories with weak incumbents and the fastest entry wedge"`

### How to Use This List

Treat each one like a platform thesis with a tiny starting point:

```bash
cyborg auto --build "agent operations platform that monitors every autonomous workflow for cost, quality, latency, failure modes, and governance drift"
```

Then keep narrowing:

- Build the smallest painful workflow first.
- Use `morphling` direct mode to deepen the wedge after the initial scaffold.
- Let Cyborg document each version so the product narrative compounds while the codebase grows.

---

## 50 Quintillion-Dollar Ideas for `cyborg auto`

These are civilization-scale ideas disguised as build prompts. The real move is not to build the whole empire at once. It is to ship the first useful control surface, data layer, or decision engine that becomes unavoidable.

### Civilization Infrastructure and Resource Coordination

1. `"planetary infrastructure graph that models ports, grids, roads, rail, water, and telecom as one living system"`
2. `"global energy routing layer that coordinates generation, storage, demand response, and cross-border power markets"`
3. `"freshwater intelligence network that predicts drought, contamination, demand spikes, and infrastructure failure before crises hit"`
4. `"materials flow operating system that tracks extraction, recycling, substitution, and industrial reuse across economies"`
5. `"resilience planner for governments that stress-tests cities against heat, flood, fire, migration, and grid instability"`
6. `"construction productivity platform that compresses planning, permitting, procurement, and scheduling into one execution graph"`
7. `"global food logistics optimizer that reduces spoilage and reroutes surplus to the highest-need regions in real time"`
8. `"carbon operations layer that verifies emissions, offsets, retrofits, and capital allocation across supply chains"`
9. `"disaster recovery command system that matches damage reports, crews, inventory, funding, and rebuild priorities after major events"`
10. `"industrial autonomy platform that coordinates factories, warehouses, fleets, and maintenance as one adaptive network"`

### Human Health, Capability, and Longevity

11. `"continuous health memory system that turns every record, scan, lab, wearable, and symptom into one patient intelligence layer"`
12. `"preventive care engine that predicts which interventions will reduce future disease burden for each population"`
13. `"drug discovery coordination platform that links literature, trials, molecular hypotheses, and manufacturing constraints"`
14. `"care labor operating system that helps health systems deploy clinicians, aides, facilities, and remote care capacity optimally"`
15. `"global rehabilitation platform that personalizes recovery plans from injury, stroke, surgery, and chronic illness"`
16. `"universal disability support stack that coordinates benefits, accommodations, transport, care plans, and assistive technology"`
17. `"mental health navigation layer that routes people to the right modality, provider, intensity, and follow-up rhythm"`
18. `"clinical language simplifier that rewrites every medical instruction, form, and discharge packet into usable plain language"`
19. `"aging infrastructure planner that helps societies redesign housing, transport, care, and work for older populations"`
20. `"longevity operations platform that turns prevention, diagnostics, habit design, and risk monitoring into one lifelong system"`

### Knowledge, Governance, and Institutional Intelligence

21. `"government operating graph that links budgets, laws, agencies, procurement, outcomes, and public trust in one model"`
22. `"regulation compiler that converts policy text into executable workflows, checklists, audits, and reporting systems"`
23. `"collective decision platform that shows what a society knows, what it assumes, and where uncertainty still dominates"`
24. `"public evidence engine that clusters research, testimony, economic impact, and stakeholder tradeoffs around major decisions"`
25. `"institutional memory layer that prevents governments and large organizations from forgetting what already failed or worked"`
26. `"treaty coordination system that models geopolitical commitments, incentives, and compliance across nations"`
27. `"civic participation platform that translates complex issues into local tradeoffs citizens can actually understand"`
28. `"grant and public funding optimizer that routes capital to the highest-leverage interventions with transparent scoring"`
29. `"bureaucracy simplification engine that rewrites public forms, services, and eligibility flows into fewer steps"`
30. `"trust infrastructure for institutions that continuously measures clarity, delivery quality, responsiveness, and legitimacy"`

### Software, AI, and Autonomous Systems

31. `"agent economy operating system that coordinates millions of software agents with budgets, permissions, quality controls, and audit trails"`
32. `"global software dependency risk map that shows which components quietly underpin entire industries"`
33. `"machine reasoning observability platform that explains why autonomous systems made each decision and what alternatives existed"`
34. `"enterprise adaptation layer that lets organizations rewire workflows instantly when laws, markets, or models change"`
35. `"AI safety operations cloud that tests frontier systems against misuse, deception, drift, and unintended power-seeking behavior"`
36. `"codebase-to-company graph that maps software changes directly to revenue, customer pain, legal exposure, and operational risk"`
37. `"autonomous research engine that reads entire scientific fields and proposes the next highest-value experiments"`
38. `"robot fleet coordination layer that treats warehouses, hospitals, factories, farms, and cities as one automation surface"`
39. `"knowledge compression engine that distills massive domains into teachable systems without losing critical nuance"`
40. `"personal agent runtime that gives every human a trusted software staff with memory, tools, goals, and guardrails"`

### Planetary Markets, Expansion, and New Coordination Layers

41. `"global market sensing layer that watches pricing, labor, trade, demand, conflict, climate, and logistics in one live map"`
42. `"capital allocation engine that helps investors and governments direct money toward the highest real-world leverage"`
43. `"small business infrastructure cloud that gives every local operator enterprise-grade finance, marketing, staffing, and analytics"`
44. `"talent mobility platform that matches human capability, training pathways, visas, remote work, and regional demand globally"`
45. `"real-world simulation layer that lets cities, firms, and nations rehearse policy or investment decisions before acting"`
46. `"planetary commerce trust network that reduces fraud, counterparty risk, and quality uncertainty across borders"`
47. `"space economy coordination platform that plans launch capacity, orbital assets, lunar logistics, and downstream markets"`
48. `"abundance planner that identifies where automation, energy, and material innovation can collapse costs for essential goods"`
49. `"frontier venture foundry that continuously discovers broken markets, launches wedge products, and compounds them into platforms"`
50. `"civilization dashboard that tracks whether humanity is getting more resilient, capable, healthy, and coordinated over time"`

### How to Use This List

Do not start with the quintillion-dollar story. Start with the narrowest painful workflow that could become its kernel:

```bash
cyborg auto --build "machine reasoning observability platform that explains why autonomous systems made each decision and what alternatives existed"
```

Then turn the wedge into infrastructure:

- Ship the smallest control panel first.
- Use `morphling` direct mode to deepen the data model, automation, and UX after the first scaffold.
- Let Cyborg document every iteration so the ambition compounds into a believable product arc.

---

## 100 Super-Impactful Accessibility Chrome Extension Ideas for `cyborg auto`

These are closer to urgent public-good products than novelty hacks. Most of them solve painful, everyday failures in reading, navigation, forms, communication, cognition, and online safety.

### Reading, Vision, and Page Clarity

1. `"Chrome extension that rewrites cluttered webpages into a clean reading mode with preserved headings, landmarks, and alt text"`
2. `"Chrome extension that lets users click any paragraph and hear it read aloud with sentence highlighting and speed control"`
3. `"Chrome extension that detects low-contrast text on the current page and offers one-click readable theme overrides"`
4. `"Chrome extension that enlarges only the important interactive elements on a page without breaking layout"`
5. `"Chrome extension that converts inaccessible PDFs opened in the browser into clean HTML reading views"`
6. `"Chrome extension that overlays plain-language summaries above dense news, legal, or medical articles"`
7. `"Chrome extension that automatically replaces tiny fonts with fatigue-friendly typography tuned for long reading sessions"`
8. `"Chrome extension that creates a focus mask so only the current paragraph or sentence stays visually emphasized"`
9. `"Chrome extension that warns when a page hides key content behind hover-only interactions that keyboard and screen-reader users miss"`
10. `"Chrome extension that generates image descriptions for unlabeled images and lets users rate or improve them"`

### Cognitive Load, Brain Fog, and Comprehension

11. `"Chrome extension that turns long pages into step-by-step summaries with expandable detail levels"`
12. `"Chrome extension that translates jargon, acronyms, and bureaucratic language into plain English inline"`
13. `"Chrome extension that breaks long forms into one-question-at-a-time flows for lower cognitive load"`
14. `"Chrome extension that highlights deadlines, required actions, dates, and consequences inside confusing emails or portals"`
15. `"Chrome extension that creates a quick 'what matters on this page' briefing before the user reads the full content"`
16. `"Chrome extension that turns complex comparison tables into simple pros, cons, and differences"`
17. `"Chrome extension that identifies walls of text and offers an easy-read version with shorter paragraphs and clearer structure"`
18. `"Chrome extension that adds persistent notes and reminders to any website for users who lose context when switching tabs"`
19. `"Chrome extension that converts multi-step government or insurance workflows into checklists with progress tracking"`
20. `"Chrome extension that detects dark patterns and explains what a site is trying to push the user into doing"`

### ADHD, Executive Function, and Attention Support

21. `"Chrome extension that hides distracting sidebars, autoplay areas, and recommendation feeds with one click"`
22. `"Chrome extension that creates a 'task mode' for the current tab and keeps only the next required action visible"`
23. `"Chrome extension that detects when a user has too many tabs related to one task and groups them into a guided workflow"`
24. `"Chrome extension that adds micro-deadlines and visual progress bars to long applications or checkout flows"`
25. `"Chrome extension that pauses infinite scroll and converts it into clear page chunks to reduce doom-scrolling"`
26. `"Chrome extension that reads a to-do item from the clipboard and opens only the websites needed to complete it"`
27. `"Chrome extension that blocks attention traps on selected sites until the user completes a chosen action"`
28. `"Chrome extension that turns documentation pages into collapsible 'start here / do this / optional details' sections"`
29. `"Chrome extension that detects when a tab title changes to urgent bait and suppresses manipulative notification language"`
30. `"Chrome extension that keeps a simple running memory of what the user was doing on each tab before they got interrupted"`

### Dyslexia and Reading Support

31. `"Chrome extension that lets users toggle dyslexia-friendly fonts, spacing, and line lengths site by site"`
32. `"Chrome extension that highlights one line at a time to reduce visual skipping while reading"`
33. `"Chrome extension that offers syllable chunking and word breakdowns for difficult text"`
34. `"Chrome extension that replaces confusable glyphs with more readable alternatives where possible"`
35. `"Chrome extension that reads selected text aloud while visually tracking the spoken word"`
36. `"Chrome extension that lets users click unfamiliar words for plain-language definitions without opening a new tab"`
37. `"Chrome extension that restructures long menus and navigation lists into clearer grouped sections"`
38. `"Chrome extension that adds reading rulers and custom color overlays for visual stress reduction"`
39. `"Chrome extension that converts scanned text images on webpages into selectable, readable text"`
40. `"Chrome extension that rewrites headings and link text when sites use vague labels like 'learn more' or 'click here'"`

### Hearing, Captions, and Communication Access

41. `"Chrome extension that adds better live captions to any browser audio source with speaker separation"`
42. `"Chrome extension that turns video transcripts into searchable chapter markers for lectures, meetings, and webinars"`
43. `"Chrome extension that detects unlabeled autoplay video and surfaces transcript-first controls"`
44. `"Chrome extension that summarizes long meeting recordings into decisions, action items, and unresolved questions"`
45. `"Chrome extension that converts audio-only customer support systems into live text relay workflows in the browser"`
46. `"Chrome extension that highlights where a video's captions diverge badly from the spoken content"`
47. `"Chrome extension that offers simple sign-language-friendly page layouts with less clutter and clearer sequencing"`
48. `"Chrome extension that lets users pin live transcript panels next to any streaming audio tab"`
49. `"Chrome extension that extracts key moments from class recordings so users can jump to the relevant explanation"`
50. `"Chrome extension that turns voice-heavy product demos into text-first walkthroughs with screenshots and steps"`

### Motor Accessibility, Hands-Free Use, and Input Support

51. `"Chrome extension that adds large, customizable click targets to small buttons and links on difficult websites"`
52. `"Chrome extension that enables dwell-click browsing for users who cannot reliably use standard mouse input"`
53. `"Chrome extension that creates universal keyboard shortcuts for common actions across inconsistent web apps"`
54. `"Chrome extension that reduces drag-and-drop interactions into accessible click-to-move alternatives"`
55. `"Chrome extension that adds voice-command overlays for forms, navigation, and common browser tasks"`
56. `"Chrome extension that detects short timeout warnings and automatically asks sites for more time when possible"`
57. `"Chrome extension that reveals hidden controls that normally appear only on hover or precise mouse movement"`
58. `"Chrome extension that converts complex date pickers into direct text-entry fields with validation help"`
59. `"Chrome extension that gives users a single sticky action bar for Back, Next, Submit, Save, and Help on confusing sites"`
60. `"Chrome extension that lets users build custom macros for repetitive browser tasks without scripting"`

### Screen Reader, Keyboard, and Structural Web Access

61. `"Chrome extension that audits the current page's heading order, landmark structure, and form labels in real time"`
62. `"Chrome extension that inserts missing skip links and keyboard navigation helpers on broken sites"`
63. `"Chrome extension that exposes the accessible name and role of any focused element with one hotkey"`
64. `"Chrome extension that warns when focus gets trapped inside modals, menus, or widgets"`
65. `"Chrome extension that adds a keyboard-first table navigator for large data tables and dashboards"`
66. `"Chrome extension that turns div-based fake buttons and links into more accessible keyboard-operable controls where safe"`
67. `"Chrome extension that detects ARIA misuse patterns and offers end-user fixes or developer reports"`
68. `"Chrome extension that creates a simplified landmarks panel for fast page navigation on noisy websites"`
69. `"Chrome extension that announces dynamic page changes in a more understandable way for screen-reader users"`
70. `"Chrome extension that preserves keyboard focus and reading position when sites unexpectedly rerender content"`

### Forms, Portals, Government, and Healthcare Access

71. `"Chrome extension that simplifies appointment booking portals into a cleaner, accessible scheduling flow"`
72. `"Chrome extension that explains medical portal messages in plain language and highlights what needs action"`
73. `"Chrome extension that adds save-state recovery to long government forms so users do not lose progress"`
74. `"Chrome extension that flags inaccessible CAPTCHA flows and offers alternative-access guidance immediately"`
75. `"Chrome extension that turns insurance claim pages into checklists with required documents, deadlines, and next steps"`
76. `"Chrome extension that helps users compare healthcare bills and identify likely errors or duplicate charges"`
77. `"Chrome extension that rewrites unemployment, disability, or benefits portals into smaller guided steps"`
78. `"Chrome extension that detects when an e-commerce checkout becomes inaccessible and switches to a repair mode"`
79. `"Chrome extension that explains hidden fees, auto-renewals, and consent checkboxes before purchase or sign-up"`
80. `"Chrome extension that helps users prepare accommodations request forms with templates and supporting language"`

### Safety, Trust, and Online Self-Advocacy

81. `"Chrome extension that detects scam patterns, manipulative urgency, and fake accessibility statements on websites"`
82. `"Chrome extension that rates a site's likely accessibility before a user invests time in an application or purchase"`
83. `"Chrome extension that creates one-click accessibility issue reports users can send to a website owner"`
84. `"Chrome extension that helps users document access barriers with screenshots, DOM evidence, and reproduction steps"`
85. `"Chrome extension that warns when a site is likely to trap users in chatbots instead of offering human support"`
86. `"Chrome extension that identifies inaccessible telehealth flows before an appointment starts and suggests alternatives"`
87. `"Chrome extension that keeps an accessibility incident log for recurring barriers across school, work, and services"`
88. `"Chrome extension that helps users compare accommodations policies across employers, schools, and event sites"`
89. `"Chrome extension that spots misleading cookie banners and makes rejection options equally visible"`
90. `"Chrome extension that turns terms of service and privacy policies into plain-language risk summaries for disabled users"`

### Work, School, and Everyday Participation

91. `"Chrome extension that turns LMS course pages into accessible weekly study plans with priorities and deadlines"`
92. `"Chrome extension that reformats discussion boards into easier-to-follow conversation threads with clearer speaker labels"`
93. `"Chrome extension that extracts action items from workplace portals, HR systems, and benefits dashboards"`
94. `"Chrome extension that turns job application sites into lower-friction accessible workflows with progress saving"`
95. `"Chrome extension that rewrites event registration pages with clearer access info, contact points, and logistics"`
96. `"Chrome extension that helps users compare accessibility details across airline, hotel, and transit booking sites"`
97. `"Chrome extension that creates a distraction-reduced telework mode across email, chat, calendar, and docs"`
98. `"Chrome extension that summarizes school parent portals into missing work, deadlines, announcements, and forms"`
99. `"Chrome extension that converts recipe, shopping, and delivery sites into fatigue-friendly step-by-step flows"`
100. `"Chrome extension that learns a user's accessibility preferences once and applies them consistently across the web"`

### How to Use This List

Pick one painful workflow and build the smallest useful version first:

```bash
cyborg auto --build "Chrome extension that highlights deadlines, required actions, dates, and consequences inside confusing emails or portals"
```

Then deepen it:

- Use `morphling` direct mode to refine content scripts, accessibility settings, and onboarding flow.
- Keep the first release narrow enough to test with real users quickly.
- Let Cyborg document the problem, the design choices, and the iteration history as the extension grows.

---

## 100 Super-Impactful Dotfiles Ideas for `cyborg auto`

These are not generic app ideas. They are high-leverage upgrades for this exact dotfiles system: better cognitive support, better automation, better health-aware workflows, and better reliability for daily life under real constraints.

### Daily Loop, Energy, and Pacing

1. `"adaptive startday flow that changes its prompt depth based on sleep, pain, fatigue, and calendar intensity"`
2. `"spoon-aware daily planner that caps workload automatically and suggests what to defer before overload hits"`
3. `"brain-fog mode that rewrites every daily script output into shorter, calmer, more structured text"`
4. `"energy triage command that ranks today's tasks by impact per spoon instead of urgency alone"`
5. `"recovery-first scheduler that inserts rest blocks when symptom signals and calendar load collide"`
6. `"shutdown assistant that turns unfinished work into tomorrow-ready checklists before goodevening completes"`
7. `"bad-day mode that collapses the whole daily system into three essential actions and hides everything else"`
8. `"friction detector that watches where daily scripts get abandoned and suggests simplifications"`
9. `"calendar strain analyzer that predicts which meetings are likely to cause cognitive crash afterward"`
10. `"decision minimizer that converts complex morning planning into A B C D short-choice prompts only"`

### Health, Symptoms, and Spoon Tracking

11. `"symptom correlation engine that links fatigue, pain, weather, sleep, nutrition, and work patterns over time"`
12. `"medication adherence helper that turns regimen tracking into low-friction check-ins instead of manual logging"`
13. `"flare early-warning system that spots rising-risk patterns in journal, health, and spoon data"`
14. `"plain-language health brief generator that summarizes the last week for doctors, caregivers, or future self"`
15. `"cognitive load tracker that estimates brain-fog severity from task switching, typing pauses, and session breaks"`
16. `"hydration and food nudger that times reminders around actual work rhythms instead of fixed intervals"`
17. `"appointment prep script that builds symptom summaries, medication lists, and questions before visits"`
18. `"post-appointment capture flow that turns messy notes into follow-ups, meds, and next steps"`
19. `"health data import layer that unifies Fitbit, Apple Health exports, sleep data, and symptom records"`
20. `"rest quality analyzer that shows which recovery habits actually improve the next day's usable capacity"`

### Task, Journal, and Personal Operations

21. `"task recommender that suggests the best next action based on spoon budget, deadlines, and setup cost"`
22. `"journal-to-todo extractor that turns freeform entries into optional tasks, reminders, and patterns"`
23. `"anti-overcommit guard that warns when the todo list exceeds realistic energy capacity for the week"`
24. `"task decomposition assistant that breaks vague scary work into tiny executable next actions"`
25. `"stuckness detector that notices repeatedly rescheduled tasks and proposes a different approach"`
26. `"done-list storyteller that turns completed work into morale-building weekly summaries"`
27. `"project heatmap that shows which areas of life are consuming attention without producing progress"`
28. `"morning context packet that merges todos, calendar, last journal entry, and open loops into one briefing"`
29. `"end-of-day reflection helper that asks smarter questions based on what actually happened today"`
30. `"task aging report that surfaces important items silently decaying in the background"`

### AI Dispatchers, Prompting, and Routing

31. `"dispatcher router that picks the right specialist model based on task type, cost, and required rigor"`
32. `"prompt audit tool that shows which templates are causing vague, repetitive, or low-signal responses"`
33. `"response quality scorer that compares outputs from different dispatchers against project-specific criteria"`
34. `"cost-aware AI mode that routes low-stakes requests to cheaper models and saves premium models for critical work"`
35. `"output normalization layer that makes every dispatcher return consistent structure, headings, and action items"`
36. `"memory-aware dispatcher context builder that pulls only the most relevant notes and recent state for a task"`
37. `"AI safety checker that blocks prompts likely to leak secrets or overreach beyond available context"`
38. `"multi-model compare command that runs the same request through several configured models and ranks the outputs"`
39. `"prompt regression suite that detects when model changes make existing workflows worse"`
40. `"human-handoff detector that suggests when a task should stop using AI and become a manual decision"`

### Morphling, Cyborg, and Project Generation

41. `"cyborg iterate mode that reads a backlog and ships the next scoped improvement with verify-fix loops"`
42. `"market-validation memory that remembers which project ideas were already rejected and why"`
43. `"build cost ledger that records tokens, time, test rounds, and publish outcomes for each generated project"`
44. `"project portfolio dashboard that shows which cyborg-built projects are healthy, stale, broken, or promising"`
45. `"compose mode that scaffolds several related tools that share schemas, branding, and docs"`
46. `"demo artifact generator that records terminal GIFs or screenshots automatically after successful builds"`
47. `"idea-to-roadmap translator that turns a one-line prompt into an MVP milestone plan before build starts"`
48. `"publish readiness checker that blocks release when packaging, README, screenshots, or tests are incomplete"`
49. `"post-build critique pass that asks Morphling to review its own scaffold like a harsh senior engineer"`
50. `"cyborg salvage mode that rescues half-finished prototypes and turns them into cleaner reusable building blocks"`

### Docs, Knowledge Base, and Blog Sync

51. `"docs freshness scanner that flags guidance drifting away from actual script behavior across the repo"`
52. `"CLAUDE-to-derived-doc sync assistant that proposes exactly which docs need updates after a behavior change"`
53. `"brain search tool that ranks notes by current relevance instead of raw keyword match"`
54. `"knowledge digestion flow that turns long notes into durable principles, checklists, and next actions"`
55. `"decision log generator that records why major script or automation changes were made"`
56. `"blog opportunity detector that spots changes in this repo that deserve a public write-up"`
57. `"reference handbook builder that assembles one plain-language cheat sheet from scattered docs"`
58. `"session recap tool that turns a day of terminal activity into a useful narrative summary"`
59. `"cross-doc contradiction checker that finds places where root guidance and derived docs drift apart"`
60. `"memory pruning assistant that archives stale notes while preserving the small amount of context that still matters"`

### Automation, Scheduling, and Background Agents

61. `"automation simulator that previews what recurring tasks will actually do before they get scheduled"`
62. `"schedule load balancer that spaces automations so they do not all fire during fragile hours"`
63. `"automation health dashboard that shows failures, skips, stale runs, and noisy tasks in one place"`
64. `"context-aware recurring prompts that change based on weekday, weather, sleep, and backlog state"`
65. `"inbox-opening automation templates for common recurring reviews like finances, health, and project hygiene"`
66. `"automation deduper that warns when two background tasks are effectively doing the same job"`
67. `"daily exception digest that summarizes only failed or unusual automation outcomes"`
68. `"pause-on-overload mode that temporarily disables nonessential recurring tasks on high-fatigue days"`
69. `"automation impact tracker that shows whether a recurring task is saving time or just generating noise"`
70. `"follow-the-sun reminder system that schedules different workflows for high-focus, medium-focus, and low-focus windows"`

### Reliability, Guardrails, and Operational Safety

71. `"shell script lint gate that checks for dotfiles-specific guardrail violations before changes land"`
72. `"path validation test generator that expands coverage for any script touching user-provided paths"`
73. `"sourced-library contract checker that catches accidental set -euo pipefail or exit usage in libs"`
74. `"env drift detector that shows which scripts rely on variables missing from env example or docs"`
75. `"data file integrity scanner that validates delimiter format and repairs common corruption safely"`
76. `"rollback rehearsal tool that tests whether critical automation can fail without damaging user state"`
77. `"command dependency census that lists every external tool the repo assumes and how often it matters"`
78. `"secret exposure watcher that checks logs, docs, and prompts for accidental token leaks"`
79. `"dangerous change classifier that flags edits likely to break low-energy daily workflows"`
80. `"safe-mode fallback runner that keeps essential commands working even when optional AI services fail"`

### Accessibility, UX, and Interaction Design

81. `"universal plain-language output mode that rewrites every script result at a fifth-grade reading level"`
82. `"TTY accessibility layer that improves spacing, color, icons, and prompts for fatigue-friendly terminal use"`
83. `"voice-first wrappers for the most important daily commands with minimal confirmation burden"`
84. `"short-choice interaction standardizer that converts complex prompts across the repo into consistent A B C D flows"`
85. `"screen-reader pass over script outputs that removes decorative noise and clarifies structure"`
86. `"low-vision theme pack for terminal workflows with contrast-safe defaults and larger text assumptions"`
87. `"stress-aware copy editor that softens overwhelming output without hiding important facts"`
88. `"error explainer that translates shell failures into plain-language likely causes and next actions"`
89. `"single-command help mode that answers 'what should I run next' based on current repo and personal state"`
90. `"fatigue-adaptive verbosity system that shortens or expands output depending on user capacity signals"`

### Review, Analytics, and Continuous Improvement

91. `"weekly operations review that summarizes what scripts helped, what failed, and what created hidden overhead"`
92. `"feature adoption tracker that shows which commands are actually used versus which only sound useful"`
93. `"time-to-value analyzer that measures how long each workflow takes before it becomes helpful"`
94. `"frustration journal miner that clusters recurring complaints into roadmap opportunities"`
95. `"test gap finder for bash workflows that matter most on the hardest days"`
96. `"personal ROI dashboard that estimates which automations save the most energy per week"`
97. `"change impact digest that explains how recent repo edits affect everyday commands and routines"`
98. `"confidence score for each workflow that blends test coverage, recent failures, and documentation freshness"`
99. `"roadmap prioritizer that ranks ideas by user pain reduced, cognitive load saved, and implementation effort"`
100. `"meta-builder that reads this section, chooses the most leveraged next improvement for dotfiles, and drafts the first implementation plan"`

### How to Use This List

Some of these fit as direct repo changes and some fit as sidecar tools first. Start with the narrowest painful workflow and prove the value quickly:

```bash
cyborg auto --build "spoon-aware daily planner that caps workload automatically and suggests what to defer before overload hits"
```

Then bring the winning ideas back into this repo:

- Use `morphling` direct mode inside `/Users/ryanjohnson/dotfiles` to adapt the prototype into the real scripts and docs.
- Prefer features that reduce cognitive load or failure risk before features that merely add novelty.
- Let Cyborg document the rationale and workflow impact as each improvement lands.

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

Here's what I see when I look at the
pipeline end-to-end:

Right now the cycle is: idea → build →
verify → document → stop.

The project sits in ~/Projects/, the blog
post sits on your site, and... that's it.
Here are the gaps:

1. ~~Nobody knows it exists~~ ✅ DONE

~~Morphling builds it. Cyborg documents it.
But there's no distribution step.~~ The
`--publish` flag now detects the ecosystem
(npm, PyPI, crates.io, GitHub Releases)
and pushes to the right registry after
build+verify passes. Includes GitHub repo
creation, AI metadata enhancement, and
safety confirmation. Aliases: `apbp`,
`apbpy`.

2. ~~You're building blind~~ ✅ DONE

~~There's no market validation before the
build step.~~ Market validation now runs
automatically with `--build`. Searches
GitHub and npm, AI synthesizes a
competitive landscape report (green/yellow/
red verdict), user chooses to proceed,
revise, or cancel. Skip with
`--no-validate`.

3. Projects never evolve

Build mode is fire-and-forget. After the
initial scaffold + verify, there's no way
to say "now add feature X." What about
`cyborg auto --iterate --repo ~/Projects/my-tool` that reads open GitHub
issues or a local backlog file and
implements the next feature with the same
build-verify-fix loop? Your projects would
grow incrementally instead of being
frozen at MVP.

4. No CI/CD comes with the project

Morphling writes code, tests, and README —
but no GitHub Actions workflow. Every
project should ship with a
`.github/workflows/ci.yml` that runs tests
on push and a release workflow that tags
and publishes. The build prompt could
generate these as part of the scaffold.

5. No demo artifact

A blog post is great. A working demo is
better. What if the build step also
generated a GIF or screenshot of the tool
in action? For CLIs, that's a terminal
recording (asciinema or vhs). For web
apps, a screenshot. That asset goes
straight into the blog post and the
README. People click on projects with
visuals.

6. No portfolio dashboard

You're building lots of projects. There's
no single view. Imagine a morphling status
command that scans ~/Projects/, checks
which ones have passing tests, which ones
have docs, which ones are published, and
shows a table. Or better: a generated
portfolio page on your blog that
auto-updates via cyborg-sync.

7. The projects don't talk to each other

Each build is isolated. But the real power
move is composition — a CLI that produces
data, a service that consumes it, a
dashboard that visualizes it. A `--compose`
mode that takes a system description and
scaffolds multiple linked projects would
let you build product ecosystems, not just
tools.

8. No revenue wiring

If the tagline is "for fun and profit,"
where's the profit? The scaffold could
include Stripe integration for paid CLIs,
a license key checker for premium
features, or a sponsorware model where the
repo starts private and goes public at a
funding goal. Even just generating a
FUNDING.yml and a "sponsor this project"
section in the README would be a start.

9. Cost visibility

Each cyborg auto --build burns API tokens.
You have no idea if an idea cost $0.03 or
$3.00 to prototype. A cost tracker that
logs token usage per build and shows
cumulative spend would tell you which
ideas are cheap to test and which are
expensive.

10. The feedback flywheel

After publishing, there's no loop back.
What if cyborg-sync could read GitHub
stars, issues, and download counts, and
feed that into the next iteration? "This
project has 47 stars and 3 open issues —
here's what users want next." That turns a
one-shot build into a living product.

---

The biggest single unlock is probably #1 +
#4 together — adding --publish plus
auto-generated CI/CD. That turns the
pipeline from "idea → local project" into
"idea → installable tool that tests and
releases itself." Everything else
compounds on top of that.
