# AI Staff HQ Dispatcher System

This directory contains 10 AI dispatcher scripts plus 4 advanced features that provide instant access to specialized AI professionals from the [AI-Staff-HQ](https://github.com/ryan258/AI-Staff-HQ) workforce. Each dispatcher is a high-speed orchestration layer that connects your workflow to the right specialist via OpenRouter API.

**Status:** ✅ 10/10 Dispatchers Active + 4 Advanced Features (Phases 1-3, 5 Complete)

---

## Quick Reference

| Dispatcher | Alias | Purpose | Input Method |
|------------|-------|---------|--------------|
| `dhp-tech.sh` | `tech` | Technical debugging | stdin |
| `dhp-creative.sh` | `creative` | Story packages | argument |
| `dhp-content.sh` | `content` | SEO content | argument |
| `dhp-strategy.sh` | `strategy` | Strategic analysis | stdin |
| `dhp-brand.sh` | `brand` | Brand positioning | stdin |
| `dhp-market.sh` | `market` | Market research | stdin |
| `dhp-stoic.sh` | `stoic` | Stoic coaching | stdin |
| `dhp-research.sh` | `research` | Knowledge synthesis | stdin |
| `dhp-narrative.sh` | `narrative` | Story structure | stdin |
| `dhp-copy.sh` | `copy` | Marketing copy | stdin |

## Advanced Features

| Feature | Alias | Purpose | Usage |
|---------|-------|---------|-------|
| `dhp-project.sh` | `ai-project` | Multi-specialist orchestration | argument |
| `dhp-chain.sh` | `ai-chain` | Sequential dispatcher chaining | special |
| `ai_suggest.sh` | `ai-suggest` | Context-aware suggestions | none |
| `dhp-context.sh` | `ai-context` | Local context injection library | source |

---

## Technical & Development

### `dhp-tech.sh` (Automation Specialist)

**Purpose:** Debug code, optimize scripts, provide technical analysis

**Input:** Reads from stdin
**Model:** `DHP_TECH_MODEL` (default: fast, capable model)
**Specialist:** `ai-staff-hq/staff/technical/automation-specialist.yaml`

**Usage:**
```bash
# Debug a script
cat broken-script.sh | tech

# Get optimization advice
echo "How to optimize this bash loop?" | tech

# Analyze error messages
echo "TypeError: undefined is not a function" | tech
```

**Output:** Bug analysis, fix explanation, corrected code printed to stdout

---

## Creative & Content

### `dhp-creative.sh` (Creative Team)

**Purpose:** Generate complete story packages with beat sheets, characters, sensory details

**Input:** Story idea or logline as argument
**Model:** `DHP_CREATIVE_MODEL` (default: GPT-4o)
**Specialists:** Chief of Staff, Narrative Designer, Persona Architect, Sound Designer
**Output Location:** `~/projects/horror/`

**Usage:**
```bash
creative "A lighthouse keeper finds a mysterious artifact"

# Full command
dhp-creative.sh "Astronaut discovers sentient fog on Europa"
```

**Output:** Markdown file with complete story package saved to projects directory

---

### `dhp-narrative.sh` (Narrative Designer)

**Purpose:** Story structure analysis, plot development, character arcs

**Input:** Reads from stdin
**Model:** `DHP_CREATIVE_MODEL`
**Specialist:** `ai-staff-hq/staff/creative/narrative-designer.yaml`

**Usage:**
```bash
# Analyze story structure
echo "My hero starts weak, gains power, faces dark reflection" | narrative

# Get plot development suggestions
cat story-outline.md | narrative

# Character arc analysis
echo "Character goes from selfish to selfless" | narrative
```

**Output:** Story structure analysis, plot suggestions, character arc recommendations

---

### `dhp-copy.sh` (Copywriter)

**Purpose:** Sales copy, email sequences, landing pages, conversion-focused messaging

**Input:** Reads from stdin
**Model:** `DHP_CREATIVE_MODEL`
**Specialist:** `ai-staff-hq/staff/creative/copywriter.yaml`

**Usage:**
```bash
# Generate sales copy
echo "Product: AI-powered task manager for ADHD" | copy

# Email sequence
echo "Launch sequence for new course on creative writing" | copy

# Landing page copy
echo "SaaS tool for content creators - convert visitors" | copy
```

**Output:** Compelling copy with headlines, body, and call-to-action

---

### `dhp-content.sh` (Content Strategy Team)

**Purpose:** SEO-optimized evergreen guides and blog content

**Input:** Topic as argument
**Model:** `DHP_CONTENT_MODEL` (default: GPT-4o)
**Specialists:** Market Analyst, SEO Specialist, Content Strategist
**Output Location:** `~/projects/ryanleej.com/content/guides/`

**Usage:**
```bash
content "Guide on overcoming creative blocks with AI"

# Full command
dhp-content.sh "Complete guide to stoic philosophy for developers"
```

**Output:** SEO-optimized Hugo-ready markdown outline with research

---

## Strategy & Analysis

### `dhp-strategy.sh` (Chief of Staff)

**Purpose:** Strategic analysis, insights, patterns, and actionable recommendations

**Input:** Reads from stdin
**Model:** `DHP_STRATEGY_MODEL` (defaults to `DHP_CONTENT_MODEL`)
**Specialist:** `ai-staff-hq/staff/strategy/chief-of-staff.yaml`

**Usage:**
```bash
# Analyze journal entries
tail -20 ~/.config/dotfiles-data/journal.txt | strategy

# Strategic planning
echo "Launch AI consulting service - what's the roadmap?" | strategy

# Pattern recognition
cat weekly-metrics.txt | strategy
```

**Output:** Key insights, strategic recommendations, risks/opportunities

**Integrated with:**
- `journal analyze` (7-day insights)
- `journal mood` (14-day sentiment)
- `journal themes` (30-day patterns)

---

### `dhp-brand.sh` (Brand Builder)

**Purpose:** Brand positioning, voice/tone development, competitive analysis

**Input:** Reads from stdin
**Model:** `DHP_STRATEGY_MODEL`
**Specialist:** `ai-staff-hq/staff/strategy/brand-builder.yaml`

**Usage:**
```bash
# Brand positioning
echo "Tech blog focused on AI for creative work" | brand

# Voice and tone
echo "Define brand voice: educational but playful" | brand

# Competitive analysis
echo "Analyze positioning vs. other AI content creators" | brand
```

**Output:** Brand attributes, voice recommendations, differentiation opportunities, messaging pillars

---

### `dhp-market.sh` (Market Analyst)

**Purpose:** SEO keyword research, trend analysis, audience insights

**Input:** Reads from stdin
**Model:** `DHP_STRATEGY_MODEL`
**Specialist:** `ai-staff-hq/staff/strategy/market-analyst.yaml`

**Usage:**
```bash
# SEO research
echo "Keywords for AI productivity tools content" | market

# Trend analysis
echo "Current trends in AI-assisted creative work" | market

# Audience insights
echo "Who's searching for AI writing assistance?" | market
```

**Output:** Keyword opportunities, market trends, audience insights, competitive landscape

---

## Personal Development

### `dhp-stoic.sh` (Stoic Coach)

**Purpose:** Mindset coaching through stoic principles, reframing challenges

**Input:** Reads from stdin
**Model:** `DHP_STRATEGY_MODEL`
**Specialist:** `ai-staff-hq/staff/personal/stoic-coach.yaml`

**Usage:**
```bash
# Handle overwhelm
echo "Overwhelmed by too many tasks and perfectionism" | stoic

# Process setbacks
echo "Project failed after months of work" | stoic

# Daily reflection
echo "Feeling stuck in analysis paralysis" | stoic
```

**Output:** Stoic reframe, control analysis, practical action, relevant quote

---

### `dhp-research.sh` (Head Librarian)

**Purpose:** Research organization, source summarization, knowledge synthesis

**Input:** Reads from stdin
**Model:** `DHP_STRATEGY_MODEL`
**Specialist:** `ai-staff-hq/staff/personal/head-librarian.yaml`

**Usage:**
```bash
# Synthesize research
cat research-notes.md | research

# Organize information
echo "Summarize key points about AI agents" | research

# Connect concepts
cat multiple-sources.txt | research
```

**Output:** Key themes, structured organization, connections, next research directions

---

## Workflow Integrations

These dispatchers are deeply integrated into daily workflow commands:

### Blog Workflow (`scripts/blog.sh`)
```bash
blog generate <stub-name>  # Uses dhp-content.sh
blog refine <file>          # Uses dhp-content.sh
```

### Todo Integration (`scripts/todo.sh`)
```bash
todo debug <num>            # Uses dhp-tech.sh
todo delegate <num> <type>  # Routes to appropriate dispatcher
```

### Journal Analysis (`scripts/journal.sh`)
```bash
journal analyze             # Uses dhp-strategy.sh
journal mood                # Uses dhp-strategy.sh
journal themes              # Uses dhp-strategy.sh
```

### Daily Automation (Optional)
```bash
# Set in .env:
AI_BRIEFING_ENABLED=true    # Uses dhp-strategy.sh in startday
AI_REFLECTION_ENABLED=true  # Uses dhp-strategy.sh in goodevening
```

---

## Configuration

All dispatchers require:

1. **OpenRouter API Key** in `.env`:
   ```bash
   OPENROUTER_API_KEY=your_key_here
   ```

2. **Model Configuration** in `.env`:
   ```bash
   DHP_TECH_MODEL=openai/gpt-4o-mini       # Fast for debugging
   DHP_CREATIVE_MODEL=openai/gpt-4o        # Creative tasks
   DHP_CONTENT_MODEL=openai/gpt-4o         # Content & strategy
   DHP_STRATEGY_MODEL=openai/gpt-4o        # Optional, defaults to content
   ```

3. **AI-Staff-HQ Submodule** at `~/dotfiles/ai-staff-hq/`

---

## Error Handling

All dispatchers include:
- ✅ Dependency checks (curl, jq)
- ✅ API key validation
- ✅ Model configuration validation
- ✅ Specialist file existence checks
- ✅ Clear error messages with actionable guidance

---

## Testing

Verify all dispatchers are working:
```bash
bash ~/dotfiles/scripts/dotfiles_check.sh
# Should report: "✅ Found 10/10 dispatchers"
```

Test individual dispatcher:
```bash
echo "Test input" | tech
```

---

## Development

### Adding a New Dispatcher

1. Create script in `bin/dhp-newname.sh`
2. Follow existing pattern (see `dhp-stoic.sh` for simple stdin example)
3. Make executable: `chmod +x bin/dhp-newname.sh`
4. Add to `zsh/aliases.zsh`
5. Update `scripts/dotfiles_check.sh` DISPATCHERS array
6. Test with `dotfiles_check.sh`
7. Document here

### Dispatcher Template

```bash
#!/bin/bash
set -e

DOTFILES_DIR="$HOME/dotfiles"
AI_STAFF_DIR="$DOTFILES_DIR/ai-staff-hq"

if [ -f "$DOTFILES_DIR/.env" ]; then source "$DOTFILES_DIR/.env"; fi

# Validate dependencies and config
if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
    echo "Error: curl and jq required." >&2; exit 1
fi

if [ -z "$OPENROUTER_API_KEY" ]; then
    echo "Error: OPENROUTER_API_KEY not set." >&2; exit 1
fi

MODEL="${DHP_YOUR_MODEL}"
if [ -z "$MODEL" ]; then
    echo "Error: Model not configured." >&2; exit 1
fi

STAFF_FILE="$AI_STAFF_DIR/staff/department/specialist.yaml"
if [ ! -f "$STAFF_FILE" ]; then
    echo "Error: Specialist not found at $STAFF_FILE" >&2; exit 1
fi

# Read input
PIPED_CONTENT=$(cat -)
if [ -z "$PIPED_CONTENT" ]; then
    echo "Usage: <input> | $0" >&2; exit 1
fi

echo "Activating 'Specialist Name' via OpenRouter..." >&2
echo "---" >&2

# Build prompt
MASTER_PROMPT=$(cat "$STAFF_FILE")
MASTER_PROMPT+="

--- YOUR REQUEST ---
$PIPED_CONTENT

Provide: [what this specialist should deliver]
"

# Call API
JSON_PAYLOAD=$(jq -n --arg model "$MODEL" --arg prompt "$MASTER_PROMPT" \
    '{model: $model, messages: [{role: "user", content: $prompt}]}')

curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD" | jq -r '.choices[0].message.content'

echo -e "\n---" >&2
echo "SUCCESS: 'Specialist Name' complete." >&2
```

---

## Advanced Features Documentation

### `dhp-project.sh` - Multi-Specialist Orchestration

**Purpose:** Coordinate multiple AI specialists for complex projects

**Input:** Project description as argument
**Model:** Uses multiple models across specialists
**Specialists:** Market Analyst, Brand Builder, Chief of Staff, Content Specialist, Copywriter
**Output:** Comprehensive markdown project brief to stdout

**Usage:**
```bash
dhp-project "Launch new blog series on AI productivity"

# Or use alias
ai-project "Create comprehensive onboarding program"

# Save output to file
dhp-project "New product launch strategy" > project-brief.md
```

**Workflow:**
1. **Market Analyst** - Researches topic, identifies opportunities
2. **Brand Builder** - Defines positioning and messaging
3. **Chief of Staff** - Creates strategic plan and timeline
4. **Content Specialist** - Develops content strategy
5. **Copywriter** - Generates promotional copy

**Output:** Complete project brief with all phases integrated

---

### `dhp-chain.sh` - Dispatcher Chaining

**Purpose:** Sequential processing through multiple AI specialists

**Input:** Special syntax: `dispatcher1 dispatcher2 [dispatcher3...] -- "input"`
**Dispatchers:** Any combination of available dispatchers
**Output:** Final result after all processing steps

**Usage:**
```bash
# Story generation → structure analysis → marketing hook
dhp-chain creative narrative copy -- "lighthouse keeper finds mysterious artifact"

# Market research → brand strategy → content plan
dhp-chain market brand content -- "AI productivity tools for developers"

# Technical analysis → strategic review
dhp-chain tech strategy -- "optimize database query performance"

# Save final output
dhp-chain creative narrative -- "story idea" --save story-brief.md
```

**Available Dispatchers:**
- tech, creative, content, strategy, brand, market, stoic, research, narrative, copy

**Features:**
- Progress display after each step
- Intermediate outputs shown to stderr
- Final output to stdout
- Optional `--save <file>` flag

---

### `ai_suggest.sh` - Context-Aware Suggestions

**Purpose:** Analyze current environment and suggest relevant AI dispatchers

**Input:** None (reads environment automatically)
**Output:** Contextual suggestions to stdout

**Usage:**
```bash
ai-suggest
```

**Context Analysis:**
- Current directory and project type
- Git repository status and recent commits
- Active todo items and priorities
- Recent journal entries (last 3 days)
- Time of day (morning/evening suggestions)

**Example Output:**
```
📍 Your Current Context:
Current directory: /Users/you/blog
Git repository: personal-blog
Recent commits:
  abc123 Update content strategy

💡 Suggested Dispatchers:
  📝 **Content Dispatcher**: Generate or refine blog content
     blog generate <stub-name>
     blog refine <file>

  📊 **Journal Analysis**: Get insights from your journal
     journal analyze
```

---

### `dhp-context.sh` - Local Context Injection

**Purpose:** Gather and inject local context into AI dispatcher prompts

**Input:** Source this library to access context functions
**Output:** Context data as text
**Usage:** Function library (not direct execution)

**Main Functions:**

**`gather_context [--minimal|--full]`**
Collects all relevant local context:
```bash
source dhp-context.sh
gather_context --minimal    # Git + top 3 tasks
gather_context --full       # Everything (journal, todos, README, git)
```

**`get_git_context [commit_count]`**
Repository and commit history:
```bash
get_git_context 10  # Last 10 commits
```

**`get_recent_journal [days]`**
Recent journal entries:
```bash
get_recent_journal 7  # Last 7 days
```

**`get_active_todos [limit]`**
Active task list:
```bash
get_active_todos 5  # Top 5 tasks
```

**`get_project_readme`**
Project README (first 50 lines):
```bash
get_project_readme
```

**Context Injection in Dispatchers:**

Example: `dhp-content.sh` with context flags:
```bash
# Minimal context (git status, top tasks)
dhp-content --context "Guide on productivity with AI"

# Full context (journal, todos, README, git history)
dhp-content --full-context "Comprehensive guide topic"
```

**Benefits:**
- Prevents duplicate content creation
- Aligns AI output with current work
- Includes relevant project context automatically
- References recent tasks and journal themes

---

## Resources

- **AI-Staff-HQ Repository:** https://github.com/ryan258/AI-Staff-HQ
- **OpenRouter Dashboard:** https://openrouter.ai/
- **Implementation Roadmap:** `~/dotfiles/ROADMAP.md`
- **Change History:** `~/dotfiles/CHANGELOG.md`
- **Main Documentation:** `~/dotfiles/README.md`

---

**Last Updated:** November 7, 2025
**Status:** Production-ready, 10 dispatchers + 4 advanced features operational
**Phase:** 1, 2, 3, 5 Complete (Infrastructure, Workflow Integration, Dispatcher Expansion, Advanced Features)
