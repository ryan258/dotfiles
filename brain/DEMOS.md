# AI-Staff-HQ Demo Commands

> Quick reference for all swarms and workflows in the ai-staff-hq system.

This document provides copy-paste demo commands for every workflow. Each example is designed to showcase the workflow's capabilities with minimal setup.

---

## Quick Start

```bash
# Ensure the Brain is running for memory features
~/dotfiles/brain/start_brain.sh

# All dhp-* commands are available after sourcing your shell config
source ~/.zshrc
```

---

## Core Workflows

### Content Creation

Creates SEO-optimized, evergreen guides in Hugo-ready markdown.

```bash
# Basic content guide
dhp-content.sh "Beginner's Guide to Terminal Productivity"

# With local project context injected
dhp-content.sh --context "Building CLI Tools with Python"

# With full repository context
dhp-content.sh --full-context "Advanced Git Workflows"

# Inject a specific persona playbook
dhp-content.sh --persona "Technical Writer" "API Documentation Best Practices"

# Verbose mode (see specialist assignments and wave execution)
dhp-content.sh --verbose "Home Automation on a Budget"

# Stream JSON events for real-time monitoring
dhp-content.sh --stream "Mechanical Keyboard Basics"
```

**Specialists:** Market Analyst, Creative Strategist, Copywriter, Data Analyst
**Output:** Hugo-ready markdown with front matter

---

### Creative Writing

Produces complete 2000-3000 word stories with rich prose.

```bash
# Short story from concept
dhp-creative.sh "A lighthouse keeper discovers messages in bottles from the future"

# Genre-specific prompt
dhp-creative.sh "Noir detective story set in a city where it never stops raining"

# With verbose execution details
dhp-creative.sh --verbose "Two rival AIs fall in love through a shared database"

# Piped input for longer prompts
cat story_prompt.txt | dhp-creative.sh
```

**Specialists:** Narrative Designer, Creative Writer, Copywriter, Art Director
**Temperature:** 0.85 (high creativity)

---

### Brand Strategy

Develops comprehensive brand positioning, voice, and messaging frameworks.

```bash
# New brand development
dhp-brand.sh "Premium AI tutoring service for graduate students"

# Rebrand analysis
dhp-brand.sh "Rebrand a legacy consulting firm for the AI era"

# Personal brand
dhp-brand.sh --verbose "Personal brand for an AI researcher and educator"

# Product brand
dhp-brand.sh "Sustainable smart home device line"
```

**Specialists:** Brand Builder, Market Analyst, Creative Strategist
**Output:** Brand playbook with voice/tone, positioning, messaging pillars

---

### Market Analysis

Conducts comprehensive market research with SEO keyword opportunities.

```bash
# Market opportunity analysis
dhp-market.sh "AI productivity tools for software engineers"

# Competitive landscape
dhp-market.sh "Smart home security camera market 2024"

# Niche market research
dhp-market.sh --verbose "Mechanical keyboard enthusiast market"

# Trend analysis
dhp-market.sh "Remote work tools adoption trends"
```

**Specialists:** Market Analyst, Data Analyst, Trend Forecaster, SEO Specialist
**Output:** Market report with keywords, trends, audience insights

---

### Strategic Analysis

High-level strategic planning and decision support.

```bash
# Business strategy
dhp-strategy.sh "Scale from consulting to SaaS product company"

# Career strategy
dhp-strategy.sh "Transition from engineer to technical founder"

# Investment decision
dhp-strategy.sh --verbose "Evaluate build vs buy for AI infrastructure"

# Risk assessment
dhp-strategy.sh "Risks of open-sourcing our core algorithm"
```

**Specialists:** Chief of Staff, Market Analyst, Strategic Planner, Data Analyst
**Temperature:** 0.6 (analytical, structured)

---

### Technical Analysis

Code review, bug analysis, and optimization recommendations.

```bash
# Code review
dhp-tech.sh "Review this authentication middleware for security issues"

# Bug analysis (piped input)
cat buggy_code.py | dhp-tech.sh

# Architecture review
dhp-tech.sh "Evaluate microservices vs monolith for our scale"

# Performance optimization
echo "SELECT * FROM users WHERE created_at > '2024-01-01'" | dhp-tech.sh
```

**Specialists:** Software Architect, Prompt Engineer, Quality Control
**Temperature:** 0.2 (precision critical)

---

### Financial Strategy

Tax optimization, S-Corp planning, and R&D credit strategies.

```bash
# Tax planning
dhp-finance.sh "S-Corp salary optimization for $200k profit"

# R&D credits
dhp-finance.sh "Qualify AI development work for R&D tax credits"

# Investment strategy
dhp-finance.sh --verbose "Asset allocation for tech entrepreneur"

# Business structure
dhp-finance.sh "LLC vs S-Corp for solo AI consultant"
```

**Specialists:** Tax Strategist, Investment Advisor, Business Lawyer
**Temperature:** 0.4 (analytical, conservative)

---

### Research Synthesis

Academic-grade research organization and synthesis.

```bash
# Topic research
dhp-research.sh "Current state of retrieval-augmented generation"

# Paper synthesis (piped notes)
cat research_notes.md | dhp-research.sh

# Literature review
dhp-research.sh "Compare transformer architectures for long-context"

# Methodology analysis
dhp-research.sh --verbose "Best practices for LLM evaluation benchmarks"
```

**Specialists:** Academic Researcher, Learning Scientist, Knowledge Base
**Temperature:** 0.5

---

### Copywriting

Sales copy, email sequences, and persuasive content.

```bash
# Landing page copy
dhp-copy.sh "SaaS tool that automates code review with AI"

# Email sequence
dhp-copy.sh "5-email nurture sequence for free trial users"

# Ad copy
dhp-copy.sh --verbose "Facebook ad for productivity app targeting developers"

# Product description (piped brief)
cat product_brief.md | dhp-copy.sh
```

**Specialists:** Copywriter, Conversion Optimizer, Marketing Strategist
**Output:** Headlines, body copy, CTAs ready for use

---

### Narrative Design

Story structure, plot development, and character arc analysis.

```bash
# Story structure
dhp-narrative.sh "Three-act structure for a heist story"

# Character development
dhp-narrative.sh "Character arc for a reluctant hero"

# Plot analysis
dhp-narrative.sh --verbose "Analyze the narrative structure of Breaking Bad"

# World-building
dhp-narrative.sh "Design a magic system with clear limitations"
```

**Specialists:** Narrative Designer, Storyteller, Mythologist
**Temperature:** 0.8

---

### Stoic Coaching

Philosophical guidance and mindset coaching.

```bash
# Challenge response
dhp-stoic.sh "Dealing with imposter syndrome as a senior engineer"

# Decision framework
dhp-stoic.sh "Should I leave a stable job for a risky startup?"

# Daily reflection
echo "I got frustrated in a meeting today" | dhp-stoic.sh

# Perspective shift
dhp-stoic.sh --verbose "Finding meaning in repetitive work"
```

**Specialists:** Stoic Coach, Cognitive Behavioral Therapist, Humanist
**Temperature:** 0.3 (grounded)

---

### Morphling (Universal Adapter)

Shapeshifts into the optimal specialist for any task.

```bash
# Let Morphling decide the best approach
dhp-morphling.sh "Help me prepare for a technical interview"

# Context-aware assistance
dhp-morphling.sh "Debug this React component that won't render"

# Creative task
dhp-morphling.sh "Write a limerick about Kubernetes"

# Analytical task
echo "Quarterly sales data..." | dhp-morphling.sh
```

**Specialists:** Morphling (meta-specialist, adapts to context)
**Features:** Gathers git branch, file structure, working directory for context

---

## Advanced Workflows

### Multi-Phase Project Planning

Orchestrates 5 specialists in sequence for comprehensive project briefs.

```bash
# Product launch
dhp-project.sh "Launch an AI-powered writing assistant"

# Content series
dhp-project.sh "Create a 12-part blog series on machine learning basics"

# Service offering
dhp-project.sh "Design a premium AI consulting package"

# Event planning
dhp-project.sh "Plan a virtual conference for AI practitioners"
```

**Phases:**
1. Market Research (Market Analyst)
2. Brand Positioning (Brand Builder)
3. Strategic Planning (Chief of Staff)
4. Content Strategy (Content Specialist)
5. Marketing Copy (Copywriter)

---

### Workflow Chaining

Chain multiple workflows where each output feeds the next.

```bash
# Story pipeline: concept → structure → marketing
dhp-chain.sh creative narrative copy -- "lighthouse keeper mystery"

# Product pipeline: research → brand → content
dhp-chain.sh market brand content -- "AI study buddy app"

# Technical pipeline: analysis → strategy
dhp-chain.sh tech strategy -- "monolith decomposition plan"

# Full creative pipeline
dhp-chain.sh creative narrative copy brand -- "sci-fi podcast series"

# Save final output
dhp-chain.sh market brand content --save output.md -- "smart garden system"
```

**Available Dispatchers:** tech, creative, content, strategy, brand, market, stoic, research, narrative, copy

---

## Direct Swarm Interface

For advanced control, use the Python swarm runner directly.

```bash
# Basic invocation
uv run python bin/dhp-swarm.py "Create a project roadmap for Q1"

# Specify model
uv run python bin/dhp-swarm.py "Write a haiku about debugging" \
  --model "anthropic/claude-3-haiku"

# Control parallelism
uv run python bin/dhp-swarm.py "Analyze this codebase" \
  --max-parallel 3 \
  --no-parallel  # or disable entirely

# Set temperature
uv run python bin/dhp-swarm.py "Creative tagline for AI startup" \
  --temperature 0.9

# Debug mode (detailed execution metrics)
uv run python bin/dhp-swarm.py "Market analysis for EdTech" --debug

# Token budget limit
uv run python bin/dhp-swarm.py "Comprehensive business plan" --budget 10000

# Require approval before execution
uv run python bin/dhp-swarm.py "Sensitive strategy analysis" --require-approval
```

---

## Integration with The Brain

Store valuable outputs in the Hive Mind for cross-project recall.

```bash
# Run workflow and capture output
OUTPUT=$(dhp-content.sh "Guide to Prompt Engineering")

# Store in Brain with metadata
python3 -c "
from brain.lib import memory
client = memory.get_client()
if client:
    memory.add_memory(
        client,
        '''$OUTPUT''',
        metadata={
            'source': 'dhp-content',
            'type': 'guide',
            'topic': 'prompt-engineering',
            'project_context': 'ai-staff-hq'
        }
    )
    print('Stored in Brain!')
"

# Later, recall related content
python3 -c "
from brain.lib import memory
client = memory.get_client()
results = memory.recall(client, 'prompt engineering best practices', n_results=3)
for doc in results['documents'][0]:
    print(doc[:500])
    print('---')
"
```

---

## Common Flags Reference

| Flag | Description | Supported By |
|------|-------------|--------------|
| `--verbose` | Show detailed progress | All workflows |
| `--stream` | Stream JSON events to stderr | All workflows |
| `--context` | Include local project context | content |
| `--full-context` | Include full repo context | content |
| `--persona "Name"` | Inject persona playbook | content |
| `--temperature <0-1>` | Control creativity | content, copy, creative |
| `--max-tokens <n>` | Limit output length | content, copy, creative |
| `--save <file>` | Save output to file | chain |
| `--debug` | Verbose debugging | swarm runner |
| `--model <id>` | Override model | swarm runner |

---

## Tips

1. **Combine with Unix pipes** - All workflows accept piped input
   ```bash
   cat brief.md | dhp-brand.sh --verbose
   ```

2. **Chain for complex projects** - Use `dhp-chain.sh` to build pipelines
   ```bash
   dhp-chain.sh market brand content copy -- "new product idea"
   ```

3. **Store valuable outputs** - Use the Brain to build a knowledge base
   ```bash
   dhp-research.sh "topic" | tee output.md && # save and display
   ```

4. **Debug slow runs** - Use `--verbose` to see which specialists are engaged

5. **Control creativity** - Lower temperature (0.2-0.4) for analytical tasks, higher (0.7-0.9) for creative

---

## Dispatcher Reference (bin/dhp-*)

Complete reference for all dispatcher scripts in `~/dotfiles/bin/`.

### Workflow Dispatchers

#### dhp-content.sh

SEO-optimized content creation with persona and context injection.

```
Usage: dhp-content.sh [options] "topic"
       echo "topic" | dhp-content.sh [options]

Options:
  --verbose         Show detailed progress
  --stream          Stream JSON events to stderr
  --context         Include minimal local project context
  --full-context    Include full repository context
  --persona "Name"  Inject persona playbook from docs/personas.md
  --temperature N   Override temperature (default: auto)
  --max-tokens N    Limit output length

Environment:
  CONTENT_MODEL           Override model
  DHP_CONTENT_OUTPUT_DIR  Override output directory

Output: ~/Documents/AI_Staff_HQ_Outputs/Content/Guides/
```

---

#### dhp-creative.sh

Complete story generation with rich prose (2000-3000 words).

```
Usage: dhp-creative.sh [options] "story concept"
       echo "concept" | dhp-creative.sh [options]

Options:
  --verbose         Show detailed progress
  --stream          Stream JSON events to stderr
  --temperature N   Override temperature (default: 0.85)
  --max-tokens N    Limit output length

Environment:
  CREATIVE_MODEL           Override model
  DHP_CREATIVE_OUTPUT_DIR  Override output directory

Output: ~/Documents/AI_Staff_HQ_Outputs/Creative/Stories/
Temperature: 0.85 (high creativity)
```

---

#### dhp-brand.sh

Brand strategy, positioning, voice/tone development.

```
Usage: dhp-brand.sh [options] "brand concept"
       echo "concept" | dhp-brand.sh [options]

Options:
  --verbose    Show detailed progress
  --stream     Stream JSON events to stderr

Environment:
  BRAND_MODEL           Override model
  DHP_BRAND_OUTPUT_DIR  Override output directory

Output: ~/Documents/AI_Staff_HQ_Outputs/Strategy/Brand/
Temperature: 0.7 (balanced)
```

---

#### dhp-market.sh

Market research, SEO keywords, trend analysis, audience insights.

```
Usage: dhp-market.sh [options] "market topic"
       echo "topic" | dhp-market.sh [options]

Options:
  --verbose    Show detailed progress
  --stream     Stream JSON events to stderr

Environment:
  MARKET_MODEL           Override model
  DHP_MARKET_OUTPUT_DIR  Override output directory

Output: ~/Documents/AI_Staff_HQ_Outputs/Strategy/Market_Research/
Temperature: 0.7 (balanced)
```

---

#### dhp-strategy.sh

Strategic analysis and decision support (excludes financial/tax topics).

```
Usage: dhp-strategy.sh [options] "strategic question"
       echo "question" | dhp-strategy.sh [options]

Options:
  --verbose    Show detailed progress
  --stream     Stream JSON events to stderr

Environment:
  STRATEGY_MODEL           Override model
  DHP_STRATEGY_OUTPUT_DIR  Override output directory

Output: ~/Documents/AI_Staff_HQ_Outputs/Strategy/Analysis/
Temperature: 0.6 (analytical)

Note: Includes baked-in context for disability/AI research focus.
      Financial topics are handled by dhp-finance.sh.
```

---

#### dhp-finance.sh

Tax optimization, S-Corp planning, R&D credits, entity structure.

```
Usage: dhp-finance.sh [options] "financial question"
       echo "question" | dhp-finance.sh [options]

Options:
  --verbose    Show detailed progress
  --stream     Stream JSON events to stderr

Environment:
  FINANCE_MODEL           Override model
  DHP_FINANCE_OUTPUT_DIR  Override output directory

Output: ~/Documents/AI_Staff_HQ_Outputs/Strategy/Finance/
Temperature: 0.4 (conservative/analytical)

Note: Includes baked-in context for Medicare disability constraints.
```

---

#### dhp-tech.sh

Code analysis, bug fixing, architecture review, optimization.

```
Usage: dhp-tech.sh [options] "code or technical question"
       echo "code" | dhp-tech.sh [options]

Options:
  --verbose    Show detailed progress
  --stream     Stream JSON events to stderr

Environment:
  TECH_MODEL           Override model
  DHP_TECH_OUTPUT_DIR  Override output directory

Output: ~/Documents/AI_Staff_HQ_Outputs/Technical/Code_Analysis/
Temperature: 0.2 (precision critical)
```

---

#### dhp-research.sh

Academic research synthesis, literature review, knowledge organization.

```
Usage: dhp-research.sh [options] "research topic"
       echo "notes" | dhp-research.sh [options]

Options:
  --verbose    Show detailed progress
  --stream     Stream JSON events to stderr

Environment:
  RESEARCH_MODEL           Override model
  DHP_RESEARCH_OUTPUT_DIR  Override output directory

Output: ~/Documents/AI_Staff_HQ_Outputs/Personal_Development/Research/
Temperature: 0.5 (balanced)
```

---

#### dhp-copy.sh

Sales copy, email sequences, landing pages, CTAs.

```
Usage: dhp-copy.sh [options] "copy brief"
       echo "brief" | dhp-copy.sh [options]

Options:
  --verbose         Show detailed progress
  --stream          Stream JSON events to stderr
  --temperature N   Override temperature (default: 0.7)
  --max-tokens N    Limit output length

Environment:
  CREATIVE_MODEL        Override model
  DHP_COPY_OUTPUT_DIR   Override output directory

Output: ~/Documents/AI_Staff_HQ_Outputs/Creative/Copywriting/
Temperature: 0.7 (balanced creativity)
```

---

#### dhp-narrative.sh

Story structure, plot development, character arcs, world-building.

```
Usage: dhp-narrative.sh [options] "story concept"
       echo "concept" | dhp-narrative.sh [options]

Options:
  --verbose    Show detailed progress
  --stream     Stream JSON events to stderr

Environment:
  CREATIVE_MODEL            Override model
  DHP_NARRATIVE_OUTPUT_DIR  Override output directory

Output: ~/Documents/AI_Staff_HQ_Outputs/Creative/Narratives/
Temperature: 0.8 (creative)
```

---

#### dhp-stoic.sh

Stoic philosophy coaching, mindset guidance, reflections.

```
Usage: dhp-stoic.sh [options] "challenge or question"
       echo "situation" | dhp-stoic.sh [options]

Options:
  --verbose    Show detailed progress
  --stream     Stream JSON events to stderr

Environment:
  STOIC_MODEL           Override model
  DHP_STOIC_OUTPUT_DIR  Override output directory

Output: ~/Documents/AI_Staff_HQ_Outputs/Personal_Development/Stoic_Coaching/
Temperature: 0.3 (grounded)
```

---

#### dhp-morphling.sh

Universal adaptive dispatcher - shapeshifts to optimal specialist.

```
Usage: dhp-morphling.sh [options] "any task"
       echo "task" | dhp-morphling.sh [options]

Options:
  --verbose    Show detailed progress
  --stream     Stream JSON events to stderr

Environment:
  MORPHLING_MODEL           Override model
  DHP_MORPHLING_OUTPUT_DIR  Override output directory

Features:
  - Auto-gathers git branch, status, directory structure
  - Adapts persona based on task context
  - Best for ambiguous or cross-domain tasks

Temperature: 0.7 (flexible)
```

---

### Orchestration Dispatchers

#### dhp-project.sh

Multi-phase project planning with 5 sequential specialists.

```
Usage: dhp-project.sh "project description"

Phases:
  1. Market Research    (Market Analyst)
  2. Brand Positioning  (Brand Builder)
  3. Strategic Planning (Chief of Staff)
  4. Content Strategy   (Content Specialist)
  5. Marketing Copy     (Copywriter)

Environment:
  OPENROUTER_API_KEY  Required

Note: Each phase output feeds into the next. Full project brief
      is synthesized from all 5 specialist contributions.
```

---

#### dhp-chain.sh

Sequential dispatcher chaining - pipe output through multiple workflows.

```
Usage: dhp-chain.sh <dispatcher1> <dispatcher2> [...] -- "input"
       dhp-chain.sh <dispatchers> --save <file> -- "input"

Available Dispatchers:
  tech, creative, content, strategy, brand, market,
  stoic, research, narrative, copy

Options:
  --save <file>   Save final output to file

Examples:
  dhp-chain.sh creative narrative copy -- "story idea"
  dhp-chain.sh market brand content -- "product concept"
  dhp-chain.sh tech strategy --save plan.md -- "refactor proposal"

Note: Each dispatcher processes the previous dispatcher's output.
      Intermediate results are displayed between steps.
```

---

### Library & Utility Scripts

#### dhp-shared.sh

Core shared library sourced by all dispatchers.

```
Provides:
  dhp_setup_env        Initialize environment
  dhp_parse_flags      Parse --verbose, --stream, --temperature, --max-tokens
  dhp_get_input        Handle piped input or positional arguments
  dhp_dispatch         Main dispatcher function
  validate_dependencies Check for required tools
  ensure_api_key       Validate API key is set
  default_output_dir   Resolve output directory with env override

Not invoked directly - sourced by other scripts.
```

---

#### dhp-lib.sh

API interaction library with streaming and logging support.

```
Provides:
  _api_cooldown        Enforce delay between API calls
  _log_api_call        Log usage to ~/.config/dotfiles-data/dispatcher_usage.log
  _build_json_payload  Construct OpenRouter API payload
  stream_api_call      Make streaming API request
  simple_api_call      Make non-streaming API request

Environment:
  API_COOLDOWN_SECONDS  Delay between calls (default: 0)

Not invoked directly - sourced by other scripts.
```

---

#### dhp-context.sh

Context injection library for gathering local project information.

```
Provides:
  gather_context       Collect all available context
  get_recent_journal   Last N journal entries
  get_active_todos     Current todo list
  get_git_context      Recent commits and repo info
  get_project_readme   README from current directory
  redact_sensitive_info Remove API keys, emails, SSNs from output

Data Sources:
  ~/.config/dotfiles-data/todo.txt
  ~/.config/dotfiles-data/journal.txt
  Current git repository

Not invoked directly - sourced by dhp-content.sh and dhp-morphling.sh.
```

---

#### dhp-config.sh

Squad configuration helpers.

```
Provides:
  get_squad_staff      Get specialists for a named squad

Configuration:
  DHP_SQUADS_FILE  Path to squads.json (default: ~/dotfiles/ai-staff-hq/squads.json)

Not invoked directly - sourced by other scripts.
```

---

#### dhp-utils.sh

General utility functions.

```
Provides:
  Utility functions for path handling, string manipulation,
  and other common operations.

Not invoked directly - sourced by other scripts.
```

---

## Environment Variables

### Global Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `OPENROUTER_API_KEY` | API key for OpenRouter | Required |
| `DEFAULT_MODEL` | Default model for all dispatchers | `xiaomi/mimo-v2-flash:free` |
| `API_COOLDOWN_SECONDS` | Delay between API calls | `0` |

### Per-Dispatcher Model Overrides

| Variable | Dispatcher |
|----------|------------|
| `CONTENT_MODEL` | dhp-content.sh |
| `CREATIVE_MODEL` | dhp-creative.sh, dhp-copy.sh, dhp-narrative.sh |
| `BRAND_MODEL` | dhp-brand.sh |
| `MARKET_MODEL` | dhp-market.sh |
| `STRATEGY_MODEL` | dhp-strategy.sh |
| `FINANCE_MODEL` | dhp-finance.sh |
| `TECH_MODEL` | dhp-tech.sh |
| `RESEARCH_MODEL` | dhp-research.sh |
| `STOIC_MODEL` | dhp-stoic.sh |
| `MORPHLING_MODEL` | dhp-morphling.sh |

### Output Directory Overrides

All dispatchers support `DHP_<NAME>_OUTPUT_DIR` environment variables to override the default output location.

```bash
# Example: redirect all content to a custom directory
export DHP_CONTENT_OUTPUT_DIR="$HOME/my-content-project/drafts"
dhp-content.sh "My Custom Guide"
```
