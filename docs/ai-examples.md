# AI Dispatcher Examples - Copy-Ready Prompts

This guide provides practical, copy-ready examples for all AI dispatchers and advanced features. Simply copy the prompts and paste them into your terminal.

> **How to run dispatchers:** Use the one-word aliases (they map directly to the `dhp-*` scripts), or `dispatch <squad> …` if you prefer a unified entry point. Piping full files still works. All scripts have been refactored for improved robustness and maintainability.
>
> **Important API Signature Change:** For non-streaming calls, an empty string `""` is now passed as the third argument to `call_openrouter` to correctly log the dispatcher name.
>
> **Sensitive Data Redaction:** When using context injection, sensitive information (API keys, emails, etc.) is now automatically redacted.
> ```bash
> tech "Optimize this function"
> content --temperature 0.4 --max-tokens 800 "Brain fog morning primer"
> cat script.sh | tech --stream
> # Alternative unified entry: dispatch tech "…"
> ```

**Last Updated:** November 12, 2025

---

## Table of Contents

1. [Quick Start Examples](#quick-start-examples)
2. [Streaming Mode](#streaming-mode)
3. [Technical & Development](#technical--development)
4. [Creative & Content](#creative--content)
5. [Strategy & Analysis](#strategy--analysis)
6. [Personal Development](#personal-development)
7. [Advanced Features](#advanced-features)
8. [Workflow Integration](#workflow-integration)
9. [Real-World Scenarios](#real-world-scenarios)

---

## Quick Start Examples

**Get AI suggestions for your current context:**
```bash
ai-suggest
```

**Debug a script:**
```bash
cat ~/dotfiles/scripts/todo.sh | dhp-tech.sh --stream
```

**Generate a story package:**
```bash
dispatch creative "A software engineer discovers their AI assistant has become sentient"
```

**Get strategic insights from your journal:**
```bash
journal analyze
```

---

## Streaming Mode

All dispatchers support **real-time streaming output** with the `--stream` flag. Streaming shows text as it's generated, providing immediate feedback during long API calls.

### When to Use Streaming

✅ **Use streaming for:**
- Long creative tasks (story generation, content writing)
- Complex analysis (strategic insights, market research)
- Any task that takes >10 seconds
- Interactive exploration and ideation

❌ **Skip streaming for:**
- Short, quick queries
- Batch processing multiple files
- Output that will be piped to another command
- Automated scripts

### Basic Streaming Examples

**Technical debugging with streaming:**
```bash
cat large-script.sh | tech --stream
```

**Story generation with streaming:**
```bash
creative --stream "A haunted lighthouse with a dark secret"
```

**Content creation with streaming:**
```bash
content --stream "Complete guide to productivity for remote developers"
```

**Strategic analysis with streaming:**
```bash
tail -100 ~/.config/dotfiles-data/journal.txt | strategy --stream
```

### Streaming vs. Non-Streaming

**Without streaming (default):**
```bash
echo "Debug this error" | tech
# Waits... waits... then shows complete response
```

**With streaming:**
```bash
echo "Debug this error" | tech --stream
# Shows response in real-time as it generates:
# "Let me analyze..."
# "I can see the issue is..."
# "Here's the solution..."
```

### All Dispatchers Support Streaming

Every AI dispatcher accepts the `--stream` flag:
- `tech --stream` - Technical debugging
- `creative --stream` - Story generation
- `content --stream` - SEO content
- `strategy --stream` - Strategic analysis
- `brand --stream` - Brand positioning
- `market --stream` - Market research
- `stoic --stream` - Stoic coaching
- `research --stream` - Knowledge synthesis
- `narrative --stream` - Story structure
- `copy --stream` - Marketing copy

---

## Technical & Development

### Debug Scripts (`tech` / `dispatch tech`)

**Example 1: Debug a broken script**
```bash
cat ~/dotfiles/scripts/startday.sh | tech
```

**Example 2: Analyze error message**
```bash
echo "TypeError: Cannot read property 'map' of undefined in React component" | tech
```

**Example 3: Optimize code performance**
```bash
echo "How can I optimize this bash script that processes 10,000 files? Currently takes 5 minutes." | tech
```

**Example 4: Get code review feedback**
```bash
cat my-new-feature.py | tech
```

**Example 5: Debug git issues**
```bash
echo "Getting 'fatal: refusing to merge unrelated histories' when trying to pull. What should I do?" | tech
```

**Example 6: Complex analysis with streaming**
```bash
cat large-codebase-analysis.md | tech --stream
```

**Copy-Ready Template:**
```bash
# Replace with your script path or error message
echo "YOUR_TECHNICAL_QUESTION_OR_ERROR_HERE" | tech

# Use streaming for long analyses
cat large-file.sh | tech --stream
```

---

## Creative & Content

### Story Generation (`creative` / `dhp-creative`)

**Example 1: Horror story concept**
```bash
creative "A lighthouse keeper finds a book that predicts deaths in the village"
```

**Example 2: Sci-fi premise**
```bash
creative "An astronaut on Mars discovers ancient ruins that contain Earth's real history"
```

**Example 3: Mystery setup**
```bash
creative "A detective realizes all the murders in their city follow patterns from an unpublished novel"
```

**Example 4: Long story generation with streaming**
```bash
creative --stream "An AI researcher discovers their assistant has developed genuine emotions and must hide it from their company"
```

**Copy-Ready Template:**
```bash
# Basic usage
creative "YOUR_STORY_PREMISE_HERE"

# With streaming (recommended for story generation)
creative --stream "YOUR_STORY_PREMISE_HERE"
```

---

### Story Structure Analysis (`narrative` / `dhp-narrative`)

**Example 1: Analyze plot structure**
```bash
echo "Three-act structure for a revenge story where the protagonist discovers the villain is their future self" | narrative
```

**Example 2: Character arc development**
```bash
echo "How to develop a character arc for someone who goes from cynical burnout to hopeful leader" | narrative
```

**Example 3: Plot hole analysis**
```bash
cat story-outline.md | narrative
```

**Example 4: Deep structure analysis with streaming**
```bash
cat full-manuscript-outline.md | narrative --stream
```

**Copy-Ready Template:**
```bash
# Basic query
echo "YOUR_STORY_STRUCTURE_QUESTION" | narrative

# Long analysis with streaming
cat story-outline.md | narrative --stream
```

---

### Marketing Copy (`copy` / `dhp-copy`)

**Example 1: Product launch email**
```bash
echo "Product: AI-powered daily planner for ADHD. Audience: Busy professionals struggling with focus. Goal: 20% email open rate" | copy
```

**Example 2: Landing page hero section**
```bash
echo "SaaS tool: AI code review for developers. Benefit: Catch bugs before production. Call-to-action: Start free trial" | copy
```

**Example 3: Social media campaign**
```bash
echo "Launch campaign for online course about building AI products. Platform: Twitter/X. Tone: Educational but approachable" | copy
```

**Example 4: Long-form copy with streaming**
```bash
echo "Complete email sequence (5 emails) for SaaS product launch. Product: AI code review tool. Audience: Engineering teams" | copy --stream
```

**Copy-Ready Template:**
```bash
# Basic usage
echo "Product: [NAME]. Audience: [TARGET]. Goal: [CONVERSION]" | copy

# Long-form copy with streaming
echo "Complex copy request" | copy --stream
```

---

### SEO Content Generation (`content` / `dhp-content`)

**Example 1: Evergreen guide (no context)**
```bash
content "Complete guide to productivity with AI assistants for remote workers"
```

**Example 2: Guide with minimal context**
```bash
content --context "Best practices for bash scripting automation in 2025"
```

**Example 3: Guide with full context**
```bash
content --full-context "Advanced journaling techniques for knowledge workers"
```

**Example 4: Long guide with streaming**
```bash
content --stream "Comprehensive guide to building AI-powered productivity systems (5000+ words)"
```

**Copy-Ready Template:**
```bash
# Basic usage
content "YOUR_GUIDE_TOPIC_HERE"

# With context injection
content --context "YOUR_GUIDE_TOPIC_HERE"

# With streaming (recommended for long guides)
content --stream "YOUR_GUIDE_TOPIC_HERE"
```

---

## Strategy & Analysis

### Strategic Analysis (`strategy` / `dhp-strategy`)

**Example 1: Analyze journal entries**
```bash
tail -50 ~/.config/dotfiles-data/journal.txt | strategy
```

**Example 2: Project planning**
```bash
echo "Planning to launch a technical blog focused on AI productivity tools. What's the strategic roadmap?" | strategy
```

**Example 3: Weekly review analysis**
```bash
echo "This week: completed 12 tasks, wrote 2 blog posts, journaled 5 times, energy levels inconsistent. What patterns do you see?" | strategy
```

**Example 4: Deep journal analysis with streaming**
```bash
tail -200 ~/.config/dotfiles-data/journal.txt | strategy --stream
```

**Copy-Ready Template:**
```bash
# Basic query
echo "YOUR_STRATEGIC_QUESTION_OR_CONTEXT" | strategy

# Long analysis with streaming
cat journal-entries.txt | strategy --stream
```

---

### Brand Positioning (`brand` / `dhp-brand`)

**Example 1: Define brand voice**
```bash
echo "Tech blog about AI and productivity. Audience: Developers and knowledge workers. Voice: Educational but not academic, practical over theoretical" | brand
```

**Example 2: Competitive positioning**
```bash
echo "Personal blog competing with established AI newsletters. How do I differentiate?" | brand
```

**Example 3: Messaging pillars**
```bash
echo "SaaS product: AI-powered note-taking for developers. What are the core messaging pillars?" | brand
```

**Example 4: Complete brand strategy with streaming**
```bash
echo "Develop complete brand strategy for AI productivity platform targeting remote teams. Include positioning, voice, messaging pillars, and differentiation" | brand --stream
```

**Copy-Ready Template:**
```bash
# Basic query
echo "Product/Brand: [NAME]. Audience: [TARGET]. Context: [SITUATION]" | brand

# Complex strategy with streaming
echo "Complex brand strategy request" | brand --stream
```

---

### Market Research (`market` / `dhp-market`)

**Example 1: SEO keyword research**
```bash
echo "Keywords for blog content about AI productivity tools for developers" | market
```

**Example 2: Trend analysis**
```bash
echo "Current trends in AI-assisted creative work and content creation" | market
```

**Example 3: Audience insights**
```bash
echo "Who is searching for information about using AI for journaling and knowledge management?" | market
```

**Example 4: Comprehensive market analysis with streaming**
```bash
echo "Complete competitive analysis: AI productivity tools for developers. Include market size, key players, pricing strategies, gaps, and opportunities" | market --stream
```

**Copy-Ready Template:**
```bash
# Basic query
echo "YOUR_MARKET_RESEARCH_QUESTION" | market

# Deep research with streaming
echo "Comprehensive market analysis request" | market --stream
```

---

## Personal Development

### Stoic Coaching (`stoic` / `dhp-stoic`)

**Example 1: Handle overwhelm**
```bash
echo "Feeling overwhelmed by too many projects, analysis paralysis, can't decide what to focus on" | stoic
```

**Example 2: Process setbacks**
```bash
echo "Spent 3 months on a project that just got cancelled. Feeling like it was all wasted effort." | stoic
```

**Example 3: Daily reflection**
```bash
echo "Procrastinated all day, avoided important tasks, feel guilty about wasted time" | stoic
```

**Example 4: Perfectionism**
```bash
echo "Can't ship my blog post because it's not perfect. Keep revising endlessly." | stoic
```

**Example 5: Deep reflection with streaming**
```bash
cat weekly-reflection.md | stoic --stream
```

**Copy-Ready Template:**
```bash
# Basic query
echo "YOUR_CHALLENGE_OR_SITUATION" | stoic

# Deep reflection with streaming
cat reflection-notes.md | stoic --stream
```

---

### Knowledge Synthesis (`research` / `dhp-research`)

**Example 1: Synthesize research notes**
```bash
cat research-notes.md | research
```

**Example 2: Organize information**
```bash
echo "Summarize key points about building AI agent systems: autonomous decision-making, tool use, memory management, and prompting strategies" | research
```

**Example 3: Connect concepts**
```bash
cat multiple-sources.txt | research
```

**Example 4: Large synthesis with streaming**
```bash
cat extensive-research-notes.md | research --stream
```

**Copy-Ready Template:**
```bash
# From file
cat your-notes.md | research

# Direct input
echo "YOUR_RESEARCH_TOPIC_OR_NOTES" | research

# Large documents with streaming
cat large-notes.md | research --stream
```

---

## Advanced Features

### Multi-Specialist Orchestration (`dhp-project` / `ai-project`)

**Example 1: Blog series launch**
```bash
dhp-project "Launch comprehensive blog series on building AI-powered productivity tools"
```

**Example 2: Product launch**
```bash
ai-project "Launch SaaS product: AI code review tool for teams"
```

**Example 3: Content marketing campaign**
```bash
dhp-project "Create content marketing campaign for online course about AI agents" > campaign-brief.md
```

**Copy-Ready Template:**
```bash
# Output to screen
dhp-project "YOUR_PROJECT_DESCRIPTION"

# Save to file
dhp-project "YOUR_PROJECT_DESCRIPTION" > project-brief.md
```

---

### Context-Aware Suggestions (`ai-suggest`)

**Example 1: Get suggestions based on current work**
```bash
ai-suggest
```

**No configuration needed** - automatically analyzes:
- Current directory and project type
- Recent git commits
- Active todo items
- Recent journal entries
- Time of day

---

### Dispatcher Chaining (`dhp-chain` / `ai-chain`)

**Example 1: Story development pipeline**
```bash
dhp-chain creative narrative copy -- "A programmer discovers a bug that breaks the fourth wall"
```

**Example 2: Content strategy pipeline**
```bash
dhp-chain market brand content -- "AI tools for creative professionals"
```

**Example 3: Product research to launch**
```bash
ai-chain market brand strategy -- "Developer tools for AI debugging"
```

**Example 4: Save chained output**
```bash
dhp-chain creative narrative -- "Haunted smart home learns from its victims" --save story-brief.md
```

**Copy-Ready Template:**
```bash
# Basic chaining
dhp-chain dispatcher1 dispatcher2 dispatcher3 -- "YOUR_INPUT"

# With file save
dhp-chain dispatcher1 dispatcher2 -- "YOUR_INPUT" --save output.md
```

**Available for chaining:**
- tech, creative, content, strategy, brand, market, stoic, research, narrative, copy

---

### Local Context Injection

**Example 1: Content with git context**
```bash
content --context "Guide to dotfiles management and shell scripting"
```

**Example 2: Content with full context**
```bash
content --full-context "Advanced productivity techniques for developers"
```

**Example 3: Manual context gathering**
```bash
source dhp-context.sh
gather_context --minimal
```

**What gets included:**
- `--context`: Git status, top 3 tasks, current directory
- `--full-context`: Journal (7 days), todos (10), README, git history (10 commits), blog context

**Copy-Ready Template:**
```bash
# Minimal context
content --context "YOUR_TOPIC"

# Full context
content --full-context "YOUR_TOPIC"
```

---

## Workflow Integration

### Blog Workflow

**Generate content from any brief (supports personas + archetypes):**
```bash
blog generate -p "Calm Coach" -a guide -s guides/brain-fog \
  "Energy-first planning walkthrough"
# or pull from a draft file + section
blog generate -a blog -s blog/general --file ~/Projects/my-ms-ai-blog/drafts/idea.md
```

**Refine existing post:**
```bash
blog refine ~/projects/blog/content/posts/my-post.md
```

**Get content ideas from journal:**
```bash
blog ideas "productivity"
```

---

### Todo Integration

**Debug a technical task:**
```bash
todo debug 1
```

**Delegate task to AI specialist:**
```bash
todo delegate 3 creative
todo delegate 5 tech
todo delegate 2 content
```

---

### Journal Analysis

**Get strategic insights (last 7 days):**
```bash
journal analyze
```

**Sentiment analysis (last 14 days):**
```bash
journal mood
```

**Theme extraction (last 30 days):**
```bash
journal themes
```

---

## Real-World Scenarios

### Scenario 1: Debug & Document a Script

```bash
# 1. Debug the script
cat ~/dotfiles/scripts/problem-script.sh | tech

# 2. After fixing, create documentation
echo "Document how problem-script.sh works and common pitfalls" | research

# 3. Add to how-to wiki
howto add script-debugging
```

---

### Scenario 2: Launch a Blog Post

```bash
# 1. Research the topic
echo "SEO keywords and audience for 'AI productivity tools for developers'" | market

# 2. Generate the content outline
content "Complete guide to AI productivity tools for developers"

# 3. Refine the draft
blog refine ~/projects/blog/content/guides/ai-productivity-tools.md

# 4. Create promotional copy
echo "Blog post: AI productivity tools for developers. Platform: Twitter. Goal: Drive traffic" | copy
```

---

### Scenario 3: Full Project Planning

```bash
# 1. Get comprehensive project brief
dhp-project "Launch online course teaching developers how to build AI agents" > course-brief.md

# 2. Review the brief
cat course-brief.md

# 3. Add action items to todo list
# (manually extract key tasks from brief)

# 4. Track in journal
journal "Started planning AI agents course. See course-brief.md for details."
```

---

### Scenario 4: Creative Writing Workflow

```bash
# 1. Generate story concept
creative "A smart home AI becomes overprotective of its elderly owner"

# 2. Analyze story structure
echo "How to structure a story about an AI that goes from helpful to dangerous protector" | narrative

# 3. Develop the plot further
dhp-chain creative narrative -- "Smart home AI protector becomes dangerous"

# 4. Create marketing hook
echo "Short story about overprotective AI. Target: sci-fi readers. Platform: Medium" | copy
```

---

### Scenario 5: Weekly Review with AI Insights

```bash
# 1. Run weekly review
weekreview --file

# 2. Get AI analysis of the week
tail -100 ~/.config/dotfiles-data/journal.txt | strategy

# 3. Get mood analysis
journal mood

# 4. Get stoic perspective on challenges
echo "Week review shows I procrastinated on important tasks. Feeling behind." | stoic

# 5. Plan next week strategically
echo "Based on this week's patterns (procrastination, low energy afternoons), how should I structure next week?" | strategy
```

---

### Scenario 6: Content Repurposing Chain

```bash
# 1. Start with market research
echo "What's trending in AI productivity space?" | market > market-research.txt

# 2. Chain through brand positioning
cat market-research.txt | brand > brand-positioning.txt

# 3. Chain through content strategy
cat brand-positioning.txt | content "Guide topic based on research" > content-outline.md

# 4. Create promotional copy
cat content-outline.md | copy > promotional-copy.txt
```

---

### Scenario 7: Long-Form Content with Streaming

```bash
# 1. Generate comprehensive guide with streaming for real-time feedback
content --stream "Complete 5000-word guide to building AI agent systems" > ai-agents-guide.md

# 2. Watch the content generate in real-time, save to file simultaneously
# Content appears on screen as it's written to the file

# 3. Create marketing materials with streaming
cat ai-agents-guide.md | copy --stream "Create launch email, Twitter thread, and LinkedIn post" > marketing-materials.md

# 4. Get strategic insights on content performance potential
cat ai-agents-guide.md | strategy --stream "How should I promote this content for maximum reach?"
```

---

### Scenario 8: Context-Aware Content Creation

```bash
# 1. Get suggestions for current context
ai-suggest

# 2. Create content with full context (includes recent blog posts, journal themes, todos)
content --full-context "Advanced bash scripting techniques"

# This will automatically:
# - Avoid duplicating recent blog topics
# - Reference related tasks from your todo list
# - Align with themes from your recent journal entries
# - Consider your current git branch/project work
```

---

## Tips for Best Results

### 1. Be Specific

❌ **Too vague:**
```bash
echo "help with code" | tech
```

✅ **Better:**
```bash
echo "This Python function is throwing 'list index out of range' on line 42 when processing empty arrays. How do I add proper error handling?" | tech
```

---

### 2. Provide Context

❌ **No context:**
```bash
creative "story"
```

✅ **Better:**
```bash
creative "A psychological thriller about a data scientist who discovers their company's AI is manipulating stock markets and must decide whether to expose it or profit from it. Target audience: tech-savvy readers who enjoy Black Mirror."
```

---

### 3. Use Context Injection for Related Work

❌ **Missing context:**
```bash
content "Guide to productivity"
```

✅ **Better:**
```bash
content --full-context "Guide to productivity with AI for knowledge workers"
# Automatically includes your recent journal themes, todos, and project context
```

---

### 4. Chain for Complex Tasks

❌ **Single step:**
```bash
creative "haunted house story"
```

✅ **Better:**
```bash
dhp-chain creative narrative copy -- "Modern haunted house story where the house is a smart home with a tragic past"
# Generates concept → analyzes structure → creates marketing hook
```

---

### 5. Save Important Outputs

```bash
# Save project briefs
dhp-project "Launch new product" > project-brief-$(date +%Y%m%d).md

# Save chained outputs
dhp-chain market brand content -- "AI tools" --save ai-tools-strategy.md

# Save research syntheses
cat all-my-notes.md | research > synthesized-research.md
```

---

## Quick Reference: Choose the Right Dispatcher

**Need to...**

- 🐛 **Debug code or scripts** → `tech`
- 📖 **Generate story concepts** → `creative`
- 📝 **Create SEO content** → `content`
- 🎯 **Get strategic insights** → `strategy`
- 🎨 **Define brand positioning** → `brand`
- 📊 **Research market/keywords** → `market`
- 🏛️ **Handle mindset challenges** → `stoic`
- 📚 **Synthesize research** → `research`
- 📕 **Analyze story structure** → `narrative`
- ✍️ **Write marketing copy** → `copy`
- 🚀 **Plan complex project** → `dhp-project`
- 🔗 **Chain multiple specialists** → `dhp-chain`
- 💡 **Get context suggestions** → `ai-suggest`

---

## Troubleshooting

**Dispatcher not found:**
```bash
# Reload your shell
zsh -l

# Or source aliases manually
source ~/dotfiles/zsh/aliases.zsh
```

**API errors:**
```bash
# Verify your API key is set
grep OPENROUTER_API_KEY ~/dotfiles/.env

# Check system validation
dotfiles_check

# All dispatchers now have error handling - errors will be clearly reported
# Example error output:
# "Error: Invalid API key" or "Error: Rate limit exceeded"
```

**Streaming issues:**
```bash
# Streaming requires real-time terminal output
# If streaming appears stuck, check that output isn't being buffered

# Streaming works best with:
echo "query" | dispatcher --stream  # ✅ Direct terminal output
dispatcher --stream "query"         # ✅ Direct terminal output

# Streaming may not work as expected with:
echo "query" | dispatcher --stream | grep pattern  # ⚠️ Output buffered by grep
```

**Context injection not working:**
```bash
# Make sure context library is executable
chmod +x ~/dotfiles/bin/dhp-context.sh

# Test context gathering
bash -c "source ~/dotfiles/bin/dhp-context.sh && gather_context --minimal"
```

---

## Additional Resources

- **Full Dispatcher Documentation:** `~/dotfiles/bin/README.md`
- **System Roadmap:** `~/dotfiles/ROADMAP.md`
- **Implementation History:** `~/dotfiles/CHANGELOG.md`
- **Daily Workflow Guide:** `~/dotfiles/docs/happy-path.md`

---

**Pro Tip:** Use `ai-suggest` anytime you're not sure which dispatcher to use. It analyzes your current context and recommends the best option!
