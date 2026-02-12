# Best Practices: Getting the Most Out of Your Dotfiles System

This guide covers proven strategies for maximizing productivity, maintaining data hygiene, and building sustainable workflows with your AI-augmented dotfiles system.

## TL;DR

- Use `startday` and `goodevening` to bookend your day.
- Keep data clean with `data_validate --format` and backups.
- Use `ai-suggest` to pick the right dispatcher when stuck.

> **Quick note on dispatchers:** Use the single-word aliases (they invoke the `dhp-*` scripts directly) for minimal typing. When you need a unified entry point or want to reference squads from `squads.json`, use `dispatch <squad> "brief"`. All scripts have been refactored for improved robustness and maintainability.
>
> **Security Note:** For detailed information on security practices, how to report vulnerabilities, and credential management, please refer to our [Security Policy](../../SECURITY.md).

**Last Updated:** January 1, 2026

---

## Table of Contents

1. [First Week: Building the Habit](#first-week-building-the-habit)
2. [Daily Routines](#daily-routines)
3. [Data Hygiene & Maintenance](#data-hygiene--maintenance)
4. [AI Dispatcher Optimization](#ai-dispatcher-optimization)
5. [Task Management Excellence](#task-management-excellence)
6. [Journal & Knowledge Management](#journal--knowledge-management)
7. [Navigation & Workspace Optimization](#navigation--workspace-optimization)
8. [Health & Energy Tracking](#health--energy-tracking)
9. [Common Pitfalls & How to Avoid Them](#common-pitfalls--how-to-avoid-them)
10. [Advanced Techniques](#advanced-techniques)
11. [Customization Guidelines](#customization-guidelines)
12. [Backup & Recovery Strategy](#backup--recovery-strategy)
13. [Secure Coding Practices](#secure-coding-practices)

---

## First Week: Building the Habit

### Day 1-2: Core Loop Only

**Focus on the essential cycle:**

✅ **DO:**

```bash
# Morning
startday             # Just read it, don't optimize yet
focus set "One thing for today"  # Set daily intention

# During day
todo add "..."       # Add tasks as they come up
journal "..."        # Capture moments

# Evening
focus done           # Archive completion
goodevening          # Celebrate even small wins
```

❌ **DON'T:**

- Try to use every feature at once
- Customize scripts yet
- Set up complex workflows
- Stress about "doing it right"

**Goal:** Get comfortable with the basic rhythm.

---

### Day 3-4: Add Navigation

✅ **DO:**

```bash
# Save your 3-5 most frequent locations
cd ~/projects/my-blog
g save blog

cd ~/dotfiles
g save dotfiles

# Start using g to jump around
g blog
g dotfiles
```

❌ **DON'T:**

- Bookmark every directory you visit
- Try to optimize bookmarks yet
- Set up complex on-enter hooks

**Goal:** Reduce mental overhead of remembering paths.

---

### Day 5-7: Explore AI Features

✅ **DO:**

```bash
# Start with suggestions
ai-suggest

# Try 1-2 dispatchers that match your work
cat script.sh | tech           # If you code
journal analyze                # For insights
echo "challenge" | stoic       # For mindset
```

❌ **DON'T:**

- Try to learn all 12 dispatchers at once
- Set up complex chaining workflows
- Integrate AI into every workflow immediately

**Goal:** Find 2-3 AI features that provide immediate value.

---

### Week 2+: Gradual Expansion

✅ **DO:**

- Add one new feature per week
- Notice friction points and address them
- Build on what's working
- Ask `ai-suggest` when uncertain

❌ **DON'T:**

- Abandon the core loop (startday, journal, todo, goodevening)
- Optimize prematurely
- Create complexity without clear benefit

---

## Daily Routines

### Morning (The Anchor)

**Best Practice: Let `startday` set the tone**

✅ **DO:**

```bash
# 1. Read startday output (runs automatically)
# 2. Set a focus if you can articulate one
focus set "Ship the weekly review feature"

# 3. Add any urgent tasks that come to mind
todo add "Fix critical bug in production"

# 4. Check top 3 priorities
next
todo top 3
```

⏱️ **Time investment:** 2-5 minutes
🎯 **Payoff:** Clear direction for the day

❌ **DON'T:**

- Skip reading the startday output
- Set vague focuses like "be productive"
- Try to plan every minute of your day
- Check email before running startday

---

### Midday (The Check-In)

**Best Practice: Course-correct when you lose focus**

✅ **DO:**

```bash
# When you feel lost:
status              # What am I working on?
focus show          # What's my main goal today?
next                # What's my top priority?

# If context switched unexpectedly:
g suggest           # Where should I be?
```

⏱️ **Time investment:** 1-2 minutes
🎯 **Payoff:** Get back on track quickly

❌ **DON'T:**

- Only check status when things go wrong
- Ignore the warning signs (confusion, paralysis)
- Power through without reassessing

---

### Evening (The Close)

**Best Practice: Celebrate wins and create tomorrow's breadcrumbs**

✅ **DO:**

```bash
# 1. Close the loop
goodevening         # Automated: wins, safety checks, backups

# 2. If AI reflection enabled, review insights
# 3. Set tomorrow's focus if it's clear
focus set "Review and merge the PR"

# 4. Clear your head with a journal entry
journal "Shipped the feature. Felt good. Tomorrow: reviews."
```

⏱️ **Time investment:** 3-5 minutes
🎯 **Payoff:** Closure + tomorrow's starting point

❌ **DON'T:**

- Skip goodevening (breaks the backup chain)
- Beat yourself up for incomplete tasks
- Set overly ambitious focuses for tomorrow

---

### Weekly (The Synthesis)

**Best Practice: Look back to plan forward**

✅ **DO:**

```bash
# 1. Generate the review
weekreview --file   # Saved to ~/Documents/Reviews/Weekly/

# 2. Get AI insights
journal themes      # 30-day patterns
journal analyze     # Last 7 days insights

# 3. Reflect and adjust
# - What worked?
# - What caused friction?
# - What needs to change?
```

⏱️ **Time investment:** 15-30 minutes
🎯 **Payoff:** Strategic insights, pattern recognition

💡 **Pro Tip:** Schedule this with `setup_weekly_review` for Sunday evenings.

---

## Data Hygiene & Maintenance

### Keep Your Todo List Healthy

✅ **DO:**

```bash
# Complete tasks promptly
todo done 1

# Undo mistakes immediately
todo undo

# Review stale tasks (startday shows these)
# Either complete or delete
todo list | grep "old task"  # Find it
todo done <num>              # Or delete manually from file
```

**Signs of a healthy todo list:**

- Most tasks < 7 days old
- Top 3 priorities are actually your priorities
- You complete 3-5 tasks per day on average

❌ **DON'T:**

- Let tasks age indefinitely (causes guilt)
- Keep aspirational tasks that demotivate you
- Use todo as a "someday/maybe" list

**Fix:** Create a separate "ideas.txt" for aspirational items.

---

### Journal for Searchability

✅ **DO:**

```bash
# Use consistent keywords
journal "Working on authentication feature. Using JWT tokens."
journal "Meeting with Sarah about Q4 planning."

# Later you can find it
journal search "authentication"
journal search "Sarah"
```

**Journal hygiene checklist:**

- [ ] Include project names
- [ ] Include people's names
- [ ] Include technical terms (searchable later)
- [ ] Date-stamp important decisions
- [ ] Use `dump` for long-form thoughts

❌ **DON'T:**

- Use only pronouns ("worked on it", "met with them")
- Rely on memory instead of search
- Let journal entries stay vague

---

### Bookmark Pruning

✅ **DO:**

```bash
# Let the system prune dead bookmarks
g prune --auto      # Runs during dotfiles_check

# Manually review bookmarks occasionally
g list

# Remove unused ones
# (Edit ~/.config/dotfiles-data/dir_bookmarks)
```

**Signs of healthy bookmarks:**

- All bookmarks point to existing directories
- You use 80% of them regularly
- No duplicates or near-duplicates

---

### Data Validation

✅ **DO:**

```bash
# Run system validation weekly
dotfiles_check

# Review backups occasionally
ls -lh ~/Backups/dotfiles_data/

# Verify data files look correct
head ~/.config/dotfiles-data/todo.txt
head ~/.config/dotfiles-data/journal.txt
```

**Automated safety:**

- `goodevening` validates data before backup
- System refuses to backup corrupted files
- Central logging tracks all automated actions

---

## AI Dispatcher Optimization

### Start with ai-suggest

**Best Practice: Let context guide you**

✅ **DO:**

```bash
# When unsure which dispatcher to use
ai-suggest

# Follow its recommendations
# It knows your context better than you remember
```

**Why this works:**

- Analyzes git status, todos, journal, time of day
- Suggests relevant dispatchers
- Reduces decision fatigue

---

### Use the Right Dispatcher for the Job

**Quick Decision Tree:**

**Need to...**

- 🐛 Debug or fix something → `tech`
- 🎯 Make a decision or get insights → `strategy`
- 📝 Create content → `content` (with `--context` for related work)
- 🎨 Generate creative ideas → `creative`
- 🏛️ Process a challenge → `stoic`
- 📊 Research market/SEO → `market`
- 📖 Develop story structure → `narrative`
- ✍️ Write marketing copy → `aicopy`
- 🎨 Position brand → `brand`
- 📚 Synthesize research → `research`

**Complex projects → `dhp-project`**
**Multiple steps → `dhp-chain`**

---

### Context Injection Best Practices

✅ **DO:**

```bash
# Use --context when creating related content
content --context "Guide to bash scripting"
# Automatically includes: recent blog posts, git status, top tasks

# Use --full-context for comprehensive awareness
content --full-context "Advanced productivity guide"
# Includes: journal themes, all todos, README, full git history
```

**When to use context:**

- Creating content for an existing blog/project
- Working on related tasks
- Building on previous work
- Need to avoid duplication

**When to skip context:**

- One-off creative projects
- Completely new topics
- Speed is priority over awareness

---

### Streaming for Long-Running Tasks

**Best Practice: Use `--stream` for real-time feedback**

All dispatchers support the `--stream` flag for real-time output as the AI generates responses.

✅ **Use streaming for:**

```bash
# Long creative tasks
creative --stream "Complex story with multiple plot threads"

# Comprehensive content generation
content --stream "5000-word guide to AI productivity"

# Deep strategic analysis
tail -100 ~/.config/dotfiles-data/journal.txt | strategy --stream

# Extensive market research
echo "Complete competitive analysis of AI tools market" | market --stream

# Complex technical debugging
cat large-codebase.py | tech --stream
```

**When to use streaming:**

- Tasks expected to take >10 seconds
- Long-form content generation (guides, stories, reports)
- Complex analysis (strategic insights, market research)
- Interactive exploration and ideation
- When you want to see progress in real-time

❌ **Skip streaming for:**

```bash
# Quick queries (overhead not worth it)
echo "Quick question" | tech

# Batch processing (output piped to other commands)
for file in *.sh; do cat $file | tech; done

# Automated scripts (no human watching)
# cron jobs, background processes

# Piped output where streaming interferes
echo "query" | dispatcher --stream | grep pattern  # ⚠️ Buffering issues
```

**Streaming vs. Non-Streaming:**

```bash
# Without streaming (default)
content "Guide topic"
# ... wait ... wait ... complete output appears

# With streaming (real-time)
content --stream "Guide topic"
# Text appears as it generates:
# "Let me create..."
# "## Introduction..."
# "The key concepts..."
```

**Saving streamed output:**

```bash
# Stream to terminal AND save to file simultaneously
content --stream "Comprehensive guide" > guide.md
# You see content in real-time, file gets saved

# Stream without saving
content --stream "Analysis for review only"
```

---

### Chaining Strategies

✅ **DO:**

```bash
# Chain when output of one enhances input to next
dhp-chain creative narrative aicopy -- "story idea"

# Market research → positioning → content
dhp-chain market brand content -- "AI tools for developers"
```

**Good chaining combinations:**

- `creative → narrative` (concept → structure)
- `market → brand` (research → positioning)
- `brand → content` (positioning → execution)
- `tech → strategy` (debugging → process improvement)

❌ **DON'T:**

- Chain unrelated dispatchers
- Chain more than 3-4 (diminishing returns)
- Chain when single dispatcher would suffice

---

### Save Important AI Outputs

✅ **DO:**

```bash
# Project briefs
dhp-project "New product launch" > ~/Documents/Briefs/product-launch-$(date +%Y%m%d).md

# Strategic analyses
journal analyze > ~/Documents/Analysis/weekly-insights-$(date +%Y%m%d).md

# Content outlines
content "Guide topic" > ~/Documents/Outlines/guide-outline.md
```

**Why save:**

- Reference later without re-running (saves API costs)
- Build a knowledge base
- Track thinking over time

---

## Task Management Excellence

### The Priority System

✅ **DO:**

```bash
# Add tasks with natural priority
todo add "Critical: Fix production bug"
todo add "Review PR before EOD"
todo add "Research: New feature idea"

# Use bump for urgent changes
todo bump 5         # Move task 5 to top

# Focus on top 3
todo top 3
next                # Just see #1
```

**Priority signals:**

- `Critical:` → Must do today
- `Review:` → Depends on someone else
- `Research:` → Can move if needed
- No prefix → Standard priority

---

### The Daily Commit Pattern

✅ **DO:**

```bash
# When you finish coding and task together
todo commit 3
# Automatically: git add, commit, mark task done

# Benefits:
# - Never forget to commit
# - Automatic task completion
# - Clear commit history
```

**When to use `todo commit`:**

- Feature work tied to a task
- Bug fixes from todo list
- Clear 1:1 task-to-code mapping

**When NOT to use:**

- Multiple commits per task needed
- Task not code-related
- Experimental work

---

### Delegation to AI

✅ **DO:**

```bash
# Stuck on technical task?
todo debug 1

# Creative task feels overwhelming?
todo delegate 3 creative

# Content task needs expert help?
todo delegate 5 content
```

**Delegation guidelines:**

- Delegate when stuck, not as first resort
- Review AI output, don't blindly accept
- Use as thought partner, not replacement

---

## Journal & Knowledge Management

### The Journal Pyramid

**Level 1: Quick Captures** (80% of entries)

```bash
journal "Fixed authentication bug"
journal "Good conversation with Alex about API design"
j "Feeling focused today"
```

**Level 2: Contextual Notes** (15% of entries)

```bash
journal "Debugging the auth flow. Issue is in token refresh logic. Need to check Redis expiration."
```

**Level 3: Deep Thinking** (5% of entries)

```bash
dump
# Opens editor for long-form reflection
# Pattern recognition
# Decision documentation
```

**Why this works:**

- Low barrier to entry (quick captures)
- Rich searchable context when needed
- Deep thinking reserved for important moments

---

### Search-Driven Knowledge

✅ **DO:**

```bash
# Always search before asking others
journal search "authentication"
journal search "that meeting"

# Use AI for synthesis
journal themes              # 30-day patterns
journal analyze             # Recent insights

# Cross-reference
journal search "Sarah" | grep "planning"
```

**Make it searchable:**

- Use full names (not "them")
- Include project names
- Use consistent terminology
- Tag important entries (`[DECISION]`, `[LEARNING]`)

---

### The How-To Wiki

✅ **DO:**

```bash
# After solving a complex problem
howto add git-rebase-workflow
# Document: what you learned, steps, gotchas

# Before tackling recurring tasks
howto git-rebase-workflow
# Read your past self's wisdom
```

**What belongs in how-to:**

- Multi-step procedures
- Things you google repeatedly
- Gotchas and edge cases
- Configuration steps

**What doesn't:**

- One-line commands (use aliases)
- Common knowledge
- Project-specific docs (those go in project READMEs)

---

## Navigation & Workspace Optimization

### The 5-Bookmark Rule

**Best Practice: Bookmark only frequently used locations**

✅ **DO:**

```bash
# Bookmark your 5-7 most frequent locations
g save dotfiles    # ~/dotfiles
g save blog        # ~/projects/blog
g save docs        # ~/Documents
g save work        # ~/work/main-project
```

**Signs you have too many bookmarks:**

- You can't remember what they all are
- `g list` output is overwhelming
- You rarely use most of them

**Fix:** Let `g suggest` guide you instead.

---

### Let Usage Drive Suggestions

✅ **DO:**

```bash
# Just navigate normally
cd ~/projects/something
# The system tracks it automatically

# When you need a hint
g suggest
# System recommends based on frequency + recency
```

**Why this works:**

- No manual maintenance
- Adapts to changing patterns
- Surfaces forgotten projects

---

### On-Enter Hooks (Advanced)

✅ **DO:**

```bash
# For frequently visited projects with consistent setup
cd ~/projects/my-python-app
g save myapp --on-enter "source venv/bin/activate"

# Now every time:
g myapp
# Automatically activates venv
```

**Good uses for on-enter hooks:**

- Activate virtual environments
- Source project-specific aliases
- Display project-specific reminders

❌ **DON'T:**

- Use for long-running commands
- Create complex multi-line hooks
- Duplicate what's in your shell config

---

## Health & Energy Tracking

### The Correlation Pattern

**Best Practice: Track consistently to find patterns**

✅ **DO:**

```bash
# Morning and evening
health energy 7

# When you notice symptoms
health symptom "Brain fog, mild headache"

# Review trends
health dashboard

# Cross-reference with productivity
journal search "brain fog"
# Look at what you accomplished those days
```

**Patterns to watch for:**

- Energy levels vs. tasks completed
- Symptoms vs. time of day
- Sleep quality vs. next-day productivity

💡 **New in v2.1.0:** Run `correlate run health.txt todo_done.txt` options to statistically verify these patterns, or check the automated `daily-report` for insights.

---

### Medication Adherence

✅ **DO:**

```bash
# Check schedule daily
meds check

# Log when taken
meds log "Med Name"

# Review adherence
meds dashboard
```

**Why this matters:**

- Spot patterns in missed doses
- Share accurate info with doctors
- Accountability without judgment

---

### Pre-Appointment Exports

✅ **DO:**

```bash
# Before doctor visit
health export > ~/Documents/health-export-$(date +%Y%m%d).txt

# Review before appointment
cat ~/Documents/health-export-*.txt | tail -100
```

**What to include:**

- Energy trends (30 days)
- Symptom patterns
- Medication adherence
- Correlation notes

---

## Common Pitfalls & How to Avoid Them

### Pitfall 1: Perfectionism Paralysis

**Symptom:** Not starting because "the system isn't perfect yet"

✅ **Fix:**

```bash
# Just use the core loop for a week
startday → todo → journal → goodevening

# Perfect is the enemy of done
# The system helps you ship, not achieve perfection
```

---

### Pitfall 2: Todo List Becomes Overwhelming

**Symptom:** 50+ tasks, none getting done

✅ **Fix:**

```bash
# Archive old tasks
cp ~/.config/dotfiles-data/todo.txt ~/Documents/todo-archive-$(date +%Y%m%d).txt

# Start fresh with only essentials
# Keep top 10-15 tasks maximum

# Use 'next' instead of 'todo list'
next
```

---

### Pitfall 3: Journal Without Searching

**Symptom:** Writing but never reading

✅ **Fix:**

```bash
# Make searching habitual
journal search "keyword"
journal onthisday
journal themes

# Let AI help
journal analyze
```

**The feedback loop:**
Write → Search → Discover patterns → Write better

---

### Pitfall 4: Over-Booking with AI

**Symptom:** Calling AI for every little thing, or waiting for complete responses when streaming would give faster feedback

✅ **Fix:**

```bash
# Use ai-suggest to guide usage
ai-suggest

# Reserve AI for:
# - When you're stuck
# - Complex analysis needed
# - Learning opportunities
# - High-leverage tasks

# Don't use AI for:
# - Simple googling
# - Things you know how to do
# - Learning experiences you should have

# Use streaming for:
# - Long tasks where you want real-time feedback
# - Interactive exploration
# - Content you'll review as it generates
```

**AI is a power tool, not a replacement for thinking. Streaming is for efficiency, not every query.**

---

### Pitfall 5: Ignoring System Warnings

**Symptom:** Skipping validation errors or not noticing API errors

✅ **Fix:**

```bash
# Run system check weekly
dotfiles_check

# Actually read the output
# Fix errors immediately
# They're warnings for a reason

# All dispatchers now have error handling
# Example error output you might see:
# "Error: Invalid API key"
# "Error: Rate limit exceeded"
# "Error: Request timeout"

# If you see errors, check:
grep OPENROUTER_API_KEY ~/dotfiles/.env
dotfiles_check
```

**Note:** As of November 8, 2025, all dispatchers detect and report API errors clearly. No more silent failures!

---

## Advanced Techniques

### Workflow Stacking

**Combine features for compound benefits**

✅ **Example: Content Creation Stack**

```bash
# 1. Research with AI (use streaming for long analysis)
echo "SEO keywords for AI productivity" | market --stream > research.txt

# 2. Generate outline with context and streaming
cat research.txt | content --stream --context "AI productivity guide" > outline.md

# 3. Track the work
todo add "Write AI productivity guide"

# 4. Commit when done
todo commit 1

# 5. Promote (streaming for longer copy)
cat outline.md | aicopy --stream > promotional-copy.txt
```

---

### Custom Dispatcher Combinations

**Create your own workflows**

✅ **Example: Weekly Review Automation**

```bash
#!/usr/bin/env bash
set -euo pipefail
# ~/dotfiles/scripts/weekly_ai_review.sh

# Generate standard review
weekreview --file

# Get AI insights (use streaming for interactive review)
journal themes > ~/Documents/Reviews/ai-themes-$(date +%Y%m%d).md
journal analyze > ~/Documents/Reviews/ai-insights-$(date +%Y%m%d).md

# Strategic analysis of the week (stream for real-time insights)
weekreview | strategy --stream > ~/Documents/Reviews/ai-strategy-$(date +%Y%m%d).md

echo "✅ Weekly AI review complete. Check ~/Documents/Reviews/"
```

---

### Context Switching Protocol

**When jumping between projects**

✅ **DO:**

```bash
# Before switching
journal "Stopping work on API feature. Next: Redis caching layer."

# Navigate + activate context
g project-name

# Read context
status
journal search "project-name"

# Set mini-focus
focus set "Complete Redis integration"
```

**Why this works:**

- Leaves breadcrumbs
- Restores context quickly
- Maintains momentum

---

## Customization Guidelines

### When to Customize

✅ **Customize when:**

- You've used the default for 2+ weeks
- You have a clear, repeated friction point
- You know exactly what you want different
- The change will save time/reduce cognitive load

❌ **Don't customize when:**

- You're still learning the system
- "Just to see if I can"
- Without understanding the default behavior
- To add complexity without clear benefit

---

### How to Customize Safely

✅ **DO:**

```bash
# 1. Create a branch
cd ~/dotfiles
git checkout -b custom/my-feature

# 2. Make ONE change at a time
# 3. Test thoroughly
# 4. Live with it for a week

# 5. If it works, commit
git add scripts/my-script.sh
git commit -m "feat: Add custom feature for X use case"

# 6. Merge back
git checkout main
git merge custom/my-feature
```

---

### Customization Ideas

**Safe customizations:**

- New aliases for your frequent commands
- Custom on-enter hooks for projects
- Additional how-to templates
- Project-specific g bookmarks

**Advanced customizations:**

- New dispatcher scripts (follow template in bin/README.md)
- Enhanced validation in dotfiles_check
- Custom weekly review sections
- Integration with other tools

---

## Backup & Recovery Strategy

### The 3-2-1 Rule

**3 copies, 2 different media, 1 offsite**

✅ **DO:**

```bash
# Copy 1: Live data
~/.config/dotfiles-data/

# Copy 2: Daily local backup (automatic)
~/Backups/dotfiles_data/

# Copy 3: Manual offsite backup (weekly)
# Copy ~/Backups/dotfiles_data/ to cloud storage
# Or: git commit and push your dotfiles regularly
```

---

### What to Backup

**Critical (automatic via goodevening):**

- `journal.txt`
- `todo.txt` & `todo_done.txt`
- `health.txt`
- `dir_bookmarks`
- `daily_focus.txt`

**Nice to have (manual):**

- Your customizations in `~/dotfiles/`
- Weekly review markdowns
- How-to wiki entries
- AI output files you saved

---

### Recovery Testing

✅ **DO:**

```bash
# Test recovery once a quarter
# 1. Note current state
ls -la ~/.config/dotfiles-data/

# 2. Restore from backup
cp ~/Backups/dotfiles_data/backup-YYYYMMDD/* ~/.config/dotfiles-data/

# 3. Verify everything works
dotfiles_check
todo list
journal search "test"

# 4. Document any gaps
```

**Why test:**

- Backups are worthless if they don't restore
- Identifies missing backup items
- Builds confidence in the system

---

## Quick Wins Checklist

**After reading this guide, implement these first:**

### Week 1

- [ ] Run `startday` every morning (automatic)
- [ ] Set daily focus with `focus set "..."`
- [ ] Add tasks with `todo add`
- [ ] Journal at least once per day
- [ ] Run `goodevening` before closing laptop

### Week 2

- [ ] Create 3-5 `g save` bookmarks for frequent locations
- [ ] Try `ai-suggest` when unsure what to do
- [ ] Use `next` instead of `todo list` when overwhelmed
- [ ] Run `journal search` to find something from last week

### Week 3

- [ ] Use one AI dispatcher (tech, strategy, or stoic)
- [ ] Track energy levels 3x this week with `health energy`
- [ ] Try `dump` for long-form reflection
- [ ] Run `weekreview --file`

### Week 4

- [ ] Set up automated weekly review with `setup_weekly_review`
- [ ] Create one how-to guide with `howto add`
- [ ] Try `todo commit` for git workflow
- [ ] Experiment with context injection: `content --context`

### Ongoing

- [ ] Run `dotfiles_check` weekly
- [ ] Review `health dashboard` monthly
- [ ] Prune bookmarks quarterly (automatic via `g prune --auto`)
- [ ] Test backup recovery quarterly

---

## Final Principles

### 1. **Consistency Over Perfection**

Better to use the basic loop daily than to build the perfect system you never use.

```bash
# This beats any perfect system:
startday → work → journal → goodevening
```

---

### 2. **Search Over Memory**

Trust the system to remember. Your job is to capture.

```bash
# Don't stress about remembering
# Just make it searchable
journal "worked on X with Y, learned Z"
```

---

### 3. **Automate the Routine, Decide on the Exception**

Let the system handle daily patterns. Save your energy for important decisions.

```bash
# Automatic:
# - Daily backups
# - Data validation
# - Stale task warnings
# - Context suggestions

# You decide:
# - What to focus on
# - What to prioritize
# - When to ask AI for help
```

---

### 4. **Delegate When Stuck, Learn When Flowing**

AI is there for the hard moments, not to replace the learning moments.

```bash
# Stuck? Delegate.
echo "problem I can't solve" | tech

# Flowing? Keep going.
# The satisfaction of solving it yourself > AI solution
```

---

### 5. **Build on What Works**

Notice what you actually use. Do more of that. Ignore the rest.

```bash
# After a month, review:
systemlog | grep "feature-name"

# Used frequently? Optimize it.
# Never used? Remove it.
```

---

## Additional Resources

- **Daily Workflow:** `~/dotfiles/docs/happy-path.md`
- **AI Quick Reference:** `~/dotfiles/docs/ai-quick-reference.md`
- **System Overview:** `~/dotfiles/README.md`
- **Technical Docs:** `~/dotfiles/bin/README.md`
- **Clipboard Workflows:** `~/dotfiles/docs/clipboard.md`

---

## Related Docs

- [Start Here](start-here.md)
- [Happy Path](happy-path.md)
- [System Overview](system-overview.md)
- [AI Quick Reference](ai-quick-reference.md)
- [Troubleshooting](../TROUBLESHOOTING.md)

---

**Remember:** This system exists to reduce cognitive load, not create it. Use what helps, ignore what doesn't, customize when you're ready.

Start simple. Build habits. Let the system grow with you.
