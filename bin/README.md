# AI Staff HQ Dispatcher System

This directory contains 12 AI dispatcher scripts plus 4 advanced features that provide instant access to specialized AI professionals from the [AI-Staff-HQ](https://github.com/ryan258/AI-Staff-HQ) workforce. Each dispatcher is a high-speed orchestration layer that connects your workflow to the right specialist via OpenRouter API.

**Status:** ✅ 12/12 Dispatchers Active + 4 Advanced Features (Phases 1-3, 5-6 Complete)

**Latest Update (February 3, 2026):**

- ✅ All dispatchers support real-time streaming with `--stream` flag
- ✅ Robust error handling via shared library (`dhp-lib.sh`)
- ✅ No more silent failures - API errors reported clearly
- ✅ ~1,500 lines of duplicate code eliminated

---

## Quick Reference

| Dispatcher         | Alias       | Purpose             | Input Method |
| ------------------ | ----------- | ------------------- | ------------ |
| `dhp-tech.sh`      | `tech`      | Technical debugging | stdin        |
| `dhp-creative.sh`  | `creative`  | Story packages      | argument     |
| `dhp-content.sh`   | `content`   | SEO content         | argument     |
| `dhp-strategy.sh`  | `strategy`  | Strategic analysis  | stdin        |
| `dhp-brand.sh`     | `brand`     | Brand positioning   | stdin        |
| `dhp-market.sh`    | `market`    | Market research     | stdin        |
| `dhp-stoic.sh`     | `stoic`     | Stoic coaching      | stdin        |
| `dhp-research.sh`  | `research`  | Knowledge synthesis | stdin        |
| `dhp-narrative.sh` | `narrative` | Story structure     | stdin        |
| `dhp-copy.sh`      | `aicopy`    | Marketing copy      | stdin        |
| `dhp-morphling.sh` | `dhp-morphling` | Universal adaptive dispatcher | argument |
| `dhp-finance.sh`   | `finance`   | Financial strategy  | stdin/arg    |

**Morphling launcher:** `morphling` now points to `bin/morphling.sh` for interactive specialist mode from any directory.

## Advanced Features

| Feature          | Alias        | Purpose                         | Usage    |
| ---------------- | ------------ | ------------------------------- | -------- |
| `dhp-project.sh` | `ai-project` | Multi-specialist orchestration  | argument |
| `dhp-chain.sh`   | `ai-chain`   | Sequential dispatcher chaining  | special  |
| `ai_suggest.sh`  | `ai-suggest` | Context-aware suggestions       | none     |
| `dhp-context.sh` | `ai-context` | Local context injection library | source   |

---

## Technical & Development

### `dhp-tech.sh` (Automation Specialist)

**Purpose:** Debug code, optimize scripts, provide technical analysis

**Input:** Reads from stdin
**Model:** `TECH_MODEL` (default: `moonshotai/kimi-k2:free`)
**Specialist:** `ai-staff-hq/staff/tech/automation-specialist.yaml`

**Usage:**

```bash
# Debug a script
cat broken-script.sh | tech

# Debug with real-time streaming
cat broken-script.sh | tech --stream

# Get optimization advice
echo "How to optimize this bash loop?" | tech

# Analyze error messages
echo "TypeError: undefined is not a function" | tech
```

**Flags:**

- `--stream` - Enable real-time streaming output

**Output:** Bug analysis, fix explanation, corrected code printed to stdout

---

## Creative & Content

### `dhp-creative.sh` (Creative Team)

**Purpose:** Generate complete story packages with beat sheets, characters, sensory details

**Input:** Story idea or logline as argument
**Model:** `CREATIVE_MODEL` (default: `moonshotai/kimi-k2:free`)
**Specialists:** Chief of Staff, Narrative Designer, Creative Strategist, Meditation Instructor
**Output Location:** Configurable via `CREATIVE_OUTPUT_DIR` (default: `~/Projects/creative-writing/`)

**Usage:**

```bash
creative "A lighthouse keeper finds a mysterious artifact"

# With real-time streaming
creative --stream "Astronaut discovers sentient fog on Europa"

# Full command
dhp-creative.sh --stream "Software engineer's AI becomes sentient"
```

**Flags:**

- `--stream` - Enable real-time streaming output

**Output:** Markdown file with complete story package saved to projects directory

---

### `dhp-narrative.sh` (Narrative Designer)

**Purpose:** Story structure analysis, plot development, character arcs

**Input:** Reads from stdin
**Model:** `CREATIVE_MODEL`
**Specialist:** `ai-staff-hq/staff/producers/narrative-designer.yaml`

**Usage:**

```bash
# Analyze story structure
echo "My hero starts weak, gains power, faces dark reflection" | narrative

# With streaming for long analysis
cat story-outline.md | narrative --stream

# Character arc analysis
echo "Character goes from selfish to selfless" | narrative
```

**Flags:**

- `--stream` - Enable real-time streaming output

**Output:** Story structure analysis, plot suggestions, character arc recommendations

---

### `dhp-copy.sh` (Copywriter)

**Purpose:** Sales copy, email sequences, landing pages, conversion-focused messaging

**Input:** Reads from stdin
**Model:** `CREATIVE_MODEL`
**Specialist:** `ai-staff-hq/staff/producers/copywriter.yaml`

**Usage:**

```bash
# Generate sales copy
echo "Product: AI-powered task manager for ADHD" | aicopy

# Email sequence with streaming
echo "Launch sequence for new course on creative writing" | aicopy --stream

# Landing page copy
echo "SaaS tool for content creators - convert visitors" | aicopy
```

**Flags:**

- `--stream` - Enable real-time streaming output

**Output:** Compelling copy with headlines, body, and call-to-action

---

### `dhp-content.sh` (Content Strategy Team)

**Purpose:** SEO-optimized evergreen guides and blog content

**Input:** Topic as argument
**Model:** `CONTENT_MODEL` (default: `moonshotai/kimi-k2:free`)
**Specialists:** Chief of Staff, Market Analyst, Copywriter
**Output Location:** Configurable via `CONTENT_OUTPUT_DIR` (falls back to `$BLOG_DIR/content/guides/`)

**Usage:**

```bash
content "Guide on overcoming creative blocks with AI"

# With streaming for long content
content --stream "Complete guide to stoic philosophy for developers"

# With context injection
dhp-content.sh --context "Guide on productivity with AI"

# Streaming + context
dhp-content.sh --stream --context "Advanced Git workflows"
```

**Flags:**

- `--stream` - Enable real-time streaming output
- `--context` - Include minimal local context (git, top tasks)
- `--full-context` - Include full context (journal, todos, README, git)

**Output:** SEO-optimized Hugo-ready markdown outline with research

---

## Strategy & Analysis

### `dhp-strategy.sh` (Chief of Staff)

**Purpose:** Strategic analysis, insights, patterns, and actionable recommendations

**Input:** Reads from stdin
**Model:** `STRATEGY_MODEL` (defaults to `DEFAULT_MODEL` / `moonshotai/kimi-k2:free`)
**Specialist:** `ai-staff-hq/staff/strategy/chief-of-staff.yaml`

**Usage:**

```bash
# Analyze journal entries
tail -20 ~/.config/dotfiles-data/journal.txt | strategy

# Strategic planning with streaming
echo "Launch AI consulting service - what's the roadmap?" | strategy --stream

# Pattern recognition
cat weekly-metrics.txt | strategy
```

**Flags:**

- `--stream` - Enable real-time streaming output

**Output:** Key insights, strategic recommendations, risks/opportunities

**Integrated with:**

- `journal analyze` (7-day insights)
- `journal mood` (14-day sentiment)
- `journal themes` (30-day patterns)

---

### `dhp-brand.sh` (Brand Builder)

**Purpose:** Brand positioning, voice/tone development, competitive analysis

**Input:** Reads from stdin
**Model:** `BRAND_MODEL` (falls back to `STRATEGY_MODEL`)
**Specialist:** `ai-staff-hq/staff/strategy/brand-builder.yaml`

**Usage:**

```bash
# Brand positioning
echo "Tech blog focused on AI for creative work" | brand

# Voice and tone with streaming
echo "Define brand voice: educational but playful" | brand --stream

# Competitive analysis
echo "Analyze positioning vs. other AI content creators" | brand
```

**Flags:**

- `--stream` - Enable real-time streaming output

**Output:** Brand attributes, voice recommendations, differentiation opportunities, messaging pillars

---

### `dhp-market.sh` (Market Analyst)

**Purpose:** SEO keyword research, trend analysis, audience insights

**Input:** Reads from stdin
**Model:** `STRATEGY_MODEL`
**Specialist:** `ai-staff-hq/staff/strategy/market-analyst.yaml`

**Usage:**

```bash
# SEO research
echo "Keywords for AI productivity tools content" | market

# Trend analysis with streaming
echo "Current trends in AI-assisted creative work" | market --stream

# Audience insights
echo "Who's searching for AI writing assistance?" | market
```

**Flags:**

- `--stream` - Enable real-time streaming output

**Output:** Keyword opportunities, market trends, audience insights, competitive landscape

---

### `dhp-finance.sh` (Financial Strategy)

**Purpose:** Tax and admin strategy (S‑Corp, R&D credits, Medicare SGA constraints)

**Input:** Reads from stdin or arguments
**Model:** `FINANCE_MODEL` (default: `moonshotai/kimi-k2:free`)
**Usage:**

```bash
# Direct invocation
dhp-finance.sh "S-Corp vs LLC tradeoffs for an R&D lab"

# Unified entry point
dispatch finance "Medicare SGA safe income planning"

# Alias
finance "Medicare SGA safe income planning"
```

**Flags:**

- `--stream` - Enable real-time streaming output

**Output:** Focused financial strategy and administrative checklist

---

## Personal Development

### `dhp-stoic.sh` (Stoic Coach)

**Purpose:** Mindset coaching through stoic principles, reframing challenges

**Input:** Reads from stdin
**Model:** `STRATEGY_MODEL`
**Specialist:** `ai-staff-hq/staff/health-lifestyle/stoic-coach.yaml`

**Usage:**

```bash
# Handle overwhelm
echo "Overwhelmed by too many tasks and perfectionism" | stoic

# Process setbacks with streaming
echo "Project failed after months of work" | stoic --stream

# Daily reflection
echo "Feeling stuck in analysis paralysis" | stoic
```

**Flags:**

- `--stream` - Enable real-time streaming output

**Output:** Stoic reframe, control analysis, practical action, relevant quote

---

### `dhp-research.sh` (Academic Researcher)

**Purpose:** Research organization, source summarization, knowledge synthesis

**Input:** Reads from stdin
**Model:** `STRATEGY_MODEL`
**Specialist:** `ai-staff-hq/staff/strategy/academic-researcher.yaml`

**Usage:**

```bash
# Synthesize research
cat research-notes.md | research

# Organize information with streaming
echo "Summarize key points about AI agents" | research --stream

# Connect concepts
cat multiple-sources.txt | research
```

**Flags:**

- `--stream` - Enable real-time streaming output

**Output:** Key themes, structured organization, connections, next research directions

---

## Universal Adaptive Specialist

### `morphling.sh` (Interactive Morphling Launcher)

**Purpose:** Launch the AI-Staff-HQ Morphling specialist from any working directory

**Input:** Optional query argument, optional stdin, or interactive mode
**Specialist:** `ai-staff-hq/staff/meta/morphling.yaml`

**Usage:**

```bash
# Interactive session
morphling

# One-shot query
morphling "Review this code for security issues"

# Piped one-shot query
cat error.log | morphling
```

---

### `dhp-morphling.sh` (Morphling)

**Purpose:** Universal "shapeshifting" specialist that auto-adapts to any task by analyzing context

**Input:** Task description as argument
**Model:** `MORPHLING_MODEL` (default: `moonshotai/kimi-k2:free`)
**Specialist:** `ai-staff-hq/staff/meta/morphling.yaml`
**Output Location:** `~/Documents/AI_Staff_HQ_Outputs/Morphling/`

**Usage:**

```bash
# Let Morphling analyze context and adapt
dhp-morphling "Review this code for security issues"

# Use in any directory - it gathers context automatically
cd ~/Projects/my-app && dhp-morphling "What should I focus on next?"

# Pipe content for analysis
cat error.log | dhp-morphling "Diagnose this issue"
```

**Context Gathering:**
Morphling automatically gathers:

- Git branch and status (if in a repo)
- Directory structure (depth 2, using `tree` or `fd`)
- Current working directory

**How It Works:**

1. Gathers environmental context (git, directory structure, working dir)
2. Analyzes your request alongside the context
3. Determines the optimal persona/role for the task
4. Shapeshifts into that expert and executes

**Best For:**

- When you're unsure which specialist to use
- General-purpose tasks that span multiple domains
- Quick context-aware assistance in any project

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
   DEFAULT_MODEL=moonshotai/kimi-k2:free
   TECH_MODEL=moonshotai/kimi-k2:free
   CREATIVE_MODEL=moonshotai/kimi-k2:free
   CONTENT_MODEL=moonshotai/kimi-k2:free
   STRATEGY_MODEL=moonshotai/kimi-k2:free
   BRAND_MODEL=moonshotai/kimi-k2:free   # Optional brand override
   MORPHLING_MODEL=moonshotai/kimi-k2:free
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
# Should report: "✅ Found 12/12 dispatchers"
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
#!/usr/bin/env bash
set -euo pipefail

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

MODEL="${YOUR_MODEL}"
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
dhp-chain creative narrative aicopy -- "lighthouse keeper finds mysterious artifact"

# Market research → brand strategy → content plan
dhp-chain market brand content -- "AI productivity tools for developers"

# Technical analysis → strategic review
dhp-chain tech strategy -- "optimize database query performance"

# Save final output
dhp-chain creative narrative -- "story idea" --save story-brief.md
```

**Available Dispatchers:**

- tech, creative, content, strategy, brand, market, stoic, research, narrative, aicopy

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
- Health signals: latest daily energy score from `health.sh`
- Medication adherence: overdue doses flagged via `meds.sh check`
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

## Spec-Driven Workflow

For complex dispatcher tasks, use the `spec` command to open structured templates that guide you through providing comprehensive input to AI specialists.

### Using Structured Specs

```bash
spec tech      # Opens tech-spec.txt template in VS Code
spec creative  # Opens creative-spec.txt template
spec content   # Opens content-spec.txt template
spec strategy  # Opens strategy-spec.txt template
spec market    # Opens market-spec.txt template
spec research  # Opens research-spec.txt template
spec stoic     # Opens stoic-spec.txt template
```

### Workflow

1. Run `spec <dispatcher>` (e.g., `spec tech`)
2. Your editor (VS Code) opens with a pre-filled template
3. Fill in the template sections with your requirements
4. Save and close the file
5. The spec automatically pipes to the appropriate dispatcher
6. Completed spec saved to `~/.config/dotfiles-data/specs/` for reuse

### Available Templates

Each dispatcher has a custom-tailored template:

**`tech-spec.txt`** - Technical debugging and analysis

- Issue description, expected vs. current behavior
- Environment context and recent changes
- Areas to investigate, output format

**`creative-spec.txt`** - Creative writing projects

- Story type, length, setting, protagonist
- Core conflict, tone, structure
- Elements to avoid

**`content-spec.txt`** - Content creation

- Title/topic, target audience, length
- Structure (opening, body, conclusion)
- SEO keywords, tone, inclusions

**`strategy-spec.txt`** - Strategic analysis

- Current state, decision/question
- Constraints (time, resources, requirements)
- Options to evaluate, criteria

**`market-spec.txt`** - Market research

- Research focus, key questions
- Comparison baseline, use case
- Depth required

**`research-spec.txt`** - Knowledge synthesis

- Source material, analysis scope
- Depth required, output format, tone

**`stoic-spec.txt`** - Stoic coaching

- Situation, emotional state
- What you've tried, reflection questions
- Expected output type

**`dispatcher-spec-template.txt`** - Generic fallback

- Used for any dispatcher without a specific template

### Reusing Specs

All completed specs are automatically saved with timestamps:

```bash
# List saved specs
ls ~/.config/dotfiles-data/specs/

# Reuse a previous spec
cat ~/.config/dotfiles-data/specs/20251110-100534-tech.txt | tech

# Edit and reuse
code ~/.config/dotfiles-data/specs/20251110-100534-creative.txt
# Make changes, then pipe to dispatcher
```

### Multi-line Input Methods

If you prefer not to use the spec templates:

**Heredoc (recommended for multi-line input):**

```bash
tech <<EOF
Your multi-line
spec here
EOF
```

**Backslash continuation:**

```bash
tech "Line 1 \
Line 2 \
Line 3"
```

**Direct piping:**

```bash
echo "Quick question or analysis request" | tech
```

### Configuration

The spec workflow uses your configured editor:

```bash
# Set in ~/.zshrc
export EDITOR="code --wait"   # VS Code (default)
export EDITOR="vim"            # Vim
export EDITOR="nano"           # Nano
```

### Benefits

- **Structured thinking** - Templates guide comprehensive input
- **Reusability** - Save and reuse successful spec patterns
- **Consistency** - Same format every time improves AI output
- **Documentation** - Archived specs serve as project history
- **Less context switching** - Editor + dispatcher in one workflow

---

---

## Swipe Logging

### `swipe.sh` - Output Logging Wrapper

**Purpose:** Wrap any command and automatically log its output to a swipe file

**Usage:**

```bash
# Log any command output
swipe tech "Summarize today's wins"
swipe creative "Story idea"

# Works with any dispatcher alias
swipe market "Analyze competitors"
```

**Configuration:**

```bash
# Enable in .env
SWIPE_LOG_ENABLED=true
SWIPE_LOG_FILE=~/Documents/swipe.md  # Optional, defaults to this

# Disable logging (commands still run, just no logging)
SWIPE_LOG_ENABLED=false
```

**Output Format:** Commands are logged to the swipe file as timestamped markdown entries with the command and its output preserved in code blocks.

---

## Resources

- **AI-Staff-HQ Repository:** https://github.com/ryan258/AI-Staff-HQ
- **OpenRouter Dashboard:** https://openrouter.ai/
- **Implementation Roadmap:** `~/dotfiles/ROADMAP.md`
- **Change History:** `~/dotfiles/CHANGELOG.md`
- **Main Documentation:** `~/dotfiles/README.md`

---

**Last Updated:** November 10, 2025
**Status:** Production-ready, 12 dispatchers + 4 advanced features + spec workflow operational
**Phase:** 1, 2, 3, 5, 6 Complete (Infrastructure, Workflow Integration, Dispatcher Expansion, Advanced Features, Model Configuration + Spec System)
