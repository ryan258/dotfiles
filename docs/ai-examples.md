# AI Dispatcher Examples - Copy-Ready Prompts

This guide provides practical, copy-ready examples for all AI dispatchers and advanced features. Simply copy the prompts and paste them into your terminal.

**Last Updated:** November 7, 2025

---

## Table of Contents

1. [Quick Start Examples](#quick-start-examples)
2. [Technical & Development](#technical--development)
3. [Creative & Content](#creative--content)
4. [Strategy & Analysis](#strategy--analysis)
5. [Personal Development](#personal-development)
6. [Advanced Features](#advanced-features)
7. [Workflow Integration](#workflow-integration)
8. [Real-World Scenarios](#real-world-scenarios)

---

## Quick Start Examples

**Get AI suggestions for your current context:**
```bash
ai-suggest
```

**Debug a script:**
```bash
cat ~/dotfiles/scripts/todo.sh | tech
```

**Generate a story package:**
```bash
creative "A software engineer discovers their AI assistant has become sentient"
```

**Get strategic insights from your journal:**
```bash
journal analyze
```

---

## Technical & Development

### Debug Scripts (`tech` / `dhp-tech`)

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

**Copy-Ready Template:**
```bash
# Replace with your script path or error message
echo "YOUR_TECHNICAL_QUESTION_OR_ERROR_HERE" | tech
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

**Copy-Ready Template:**
```bash
creative "YOUR_STORY_PREMISE_HERE"
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

**Copy-Ready Template:**
```bash
echo "YOUR_STORY_STRUCTURE_QUESTION" | narrative
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

**Copy-Ready Template:**
```bash
echo "Product: [NAME]. Audience: [TARGET]. Goal: [CONVERSION]" | copy
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

**Copy-Ready Template:**
```bash
# Basic usage
content "YOUR_GUIDE_TOPIC_HERE"

# With context injection
content --context "YOUR_GUIDE_TOPIC_HERE"
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

**Copy-Ready Template:**
```bash
echo "YOUR_STRATEGIC_QUESTION_OR_CONTEXT" | strategy
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

**Copy-Ready Template:**
```bash
echo "Product/Brand: [NAME]. Audience: [TARGET]. Context: [SITUATION]" | brand
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

**Copy-Ready Template:**
```bash
echo "YOUR_MARKET_RESEARCH_QUESTION" | market
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

**Copy-Ready Template:**
```bash
echo "YOUR_CHALLENGE_OR_SITUATION" | stoic
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

**Copy-Ready Template:**
```bash
# From file
cat your-notes.md | research

# Direct input
echo "YOUR_RESEARCH_TOPIC_OR_NOTES" | research
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

**Generate content from stub:**
```bash
blog generate my-stub-name
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

### Scenario 7: Context-Aware Content Creation

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
