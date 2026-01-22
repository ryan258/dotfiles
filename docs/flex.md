# Dispatcher Quick Reference & Examples

Practical examples showing dispatcher usage patterns in the dotfiles environment.

> **Note:** These examples use the current dispatcher setup with configurable models. The default is `xiaomi/mimo-v2-flash:free`, configured via `.env` variables.

## Basic Usage Patterns

### 1. Piped Input
```bash
cat broken-script.sh | tech
echo "Story about a haunted IDE" | creative
tail -50 ~/.config/dotfiles-data/journal.txt | strategy
```

### 2. Quoted Arguments
```bash
tech "Summarize this bash script" < scripts/blog.sh
creative "70s cosmic horror radio broadcast"
content "Write a guide about brain fog command line rituals"
```

### 3. Streaming Output (Real-Time)
```bash
cat large-file.sh | tech --stream
creative --stream "Write a story about..."
content --stream "Complete guide to X"
```

### 4. Temperature Control
```bash
content --temperature 0.35 "Deterministic guide output"
creative --temperature 0.85 "High-creativity story generation"
copy --temperature 0.55 "Balanced marketing copy"
```

## Workflow Integration Examples

### 5. Morning Context Recovery
```bash
focus set "Finish AI blog draft"
gcal agenda 7          # Check week's schedule
startday               # Uses strategy dispatcher for briefing suggestions
```

### 6. Journal Analysis
```bash
journal analyze    # Strategic insights from last 7 days
journal mood       # Sentiment analysis (14 days)
journal themes     # Theme extraction (30 days)
```

### 7. Todo Delegation
```bash
todo debug 1                   # Debug technical task with tech dispatcher
todo delegate 3 creative       # Delegate task to creative specialist
```

### 8. Blog Workflow
```bash
blog generate -p "Calm Coach" -a guide -s guides/brain-fog "Energy-first planning walkthrough"
blog refine my-post.md        # Polish existing draft
```

## Context-Aware Examples

### 9. Local Context Injection
```bash
content --context "Write guide about CLI productivity"
# Includes: git status, top tasks, recent blog topics

content --full-context "Comprehensive guide topic"
# Includes: journal, todos, README, full git history
```

### 10. Git Forensics
```bash
git log -n 10 --oneline | tech --stream "Spot risky commits to revisit"
git diff HEAD~5..HEAD | tech "Summarize recent changes"
```

### 11. Log Analysis
```bash
systemlog | head -n 20 | tech "Highlight impactful entries and failures"
./scripts/data_validate.sh | tech "Summarize validator output issues"
```

## Advanced Features

### 12. Multi-Specialist Orchestration
```bash
dhp-project "Launch new blog series on AI productivity"
# Coordinates: Market Analyst → Brand Builder → Chief of Staff → Content Specialist → Copywriter
# Outputs comprehensive markdown project brief
```

### 13. Dispatcher Chaining
```bash
dhp-chain creative narrative copy -- "lighthouse keeper finds artifact"
# Sequential: creative → narrative → copy
# Use --save <file> to save output
```

### 14. Context-Aware Suggestions
```bash
ai-suggest
# Analyzes current directory, git status, recent commits, todos
# Suggests relevant dispatchers based on context
```

### 15. Spec-Driven Workflow
```bash
spec tech           # Opens tech debugging template in editor
spec creative       # Opens creative writing template
spec content        # Opens content creation template

# Workflow: open → fill → save → auto-dispatch → archive
# Completed specs saved to ~/.config/dotfiles-data/specs/
```

## Swipe Logging

Capture impressive outputs to your swipe log:

```bash
# Enable in .env:
# SWIPE_LOG_ENABLED=true
# SWIPE_LOG_FILE="$HOME/Documents/swipe.md"

swipe tech "Analyze this script" < scripts/startday.sh
swipe creative --stream "Write a story..."
swipe content --context "Guide about fog-friendly workflows"
```

## Quick Command Reference

| Short | Full Script | Purpose |
|-------|-------------|---------|
| `tech` | `dhp-tech.sh` | Code debugging, optimization, technical analysis |
| `creative` | `dhp-creative.sh` | Complete story packages (horror specialty) |
| `content` | `dhp-content.sh` | SEO-optimized guides and evergreen content |
| `strategy` | `dhp-strategy.sh` | Strategic insights via Chief of Staff |
| `brand` | `dhp-brand.sh` | Brand positioning, voice/tone, competitive analysis |
| `market` | `dhp-market.sh` | SEO research, trends, audience insights |
| `stoic` | `dhp-stoic.sh` | Mindset coaching through stoic principles |
| `research` | `dhp-research.sh` | Knowledge organization and synthesis |
| `narrative` | `dhp-narrative.sh` | Story structure, plot development, character arcs |
| `copy` | `dhp-copy.sh` | Sales copy, email sequences, landing pages |

## Tips

- **Streaming** is great for long creative tasks to see progress in real-time
- **Low temperature** (0.3-0.4) for deterministic, consistent output
- **High temperature** (0.7-0.9) for creative, varied output
- **Context injection** prevents duplicate content and aligns with current work
- **Spec templates** guide comprehensive input for better AI output
- **Swipe logging** captures outputs worth revisiting or sharing
