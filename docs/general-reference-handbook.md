# General Reference Handbook

This handbook serves as your comprehensive guide to the underlying architecture, specialized non-AI workflows, MS-friendly accessibility features, and system best practices.

## 🏛️ System Overview

This is a derived architecture view. Canonical contracts live in `../CLAUDE.md`.

## Architecture

```text
Terminal (zsh)
  -> aliases + wrappers (`zsh/aliases.zsh`)
  -> scripts (`scripts/*.sh`)
  -> AI dispatchers (`bin/dhp-*.sh`, `bin/dispatch.sh`)
  -> data (`~/.config/dotfiles-data/*`)
```

## Daily Coaching Flow

```text
startday
  -> gather focus/tasks/journal/health/git signals
  -> build deterministic behavior digest (coach_ops)
  -> call strategy dispatcher with timeout guard
  -> fallback to deterministic schema if unavailable

goodevening
  -> gather today outcomes + same digest
  -> call strategy dispatcher with timeout guard
  -> fallback to deterministic schema if unavailable
```

## Data Contracts

- `coach_mode.txt`: `YYYY-MM-DD|LOCKED|source` or `YYYY-MM-DD|OVERRIDE|source`
- `coach_log.txt`: `TYPE|TIMESTAMP|DATE|MODE|FOCUS|METRICS|OUTPUT`
- Core daily files:
  - `todo.txt`
  - `todo_done.txt`
  - `ideas.txt`
  - `journal.txt`
  - `health.txt`
  - `spoons.txt`

## Reliability Rules

- Coaching calls are timeout-bounded.
- Timeout/error/missing dispatcher returns deterministic structured output.
- User input is sanitized before persistence.
- Paths are validated before file writes.

## 🧠 MS-Friendly Features & Accessibility

This system was built with MS challenges in mind: brain fog, fatigue, energy fluctuations, and the need for maximum efficiency on low-energy days.

---

#### TL;DR

- Use `startday`, `status`, and `goodevening` for low-effort context recovery.
- Track energy with `health` and `spoons` to avoid overextending.
- Use `todo top` and `focus` to keep scope small.

#### 🧠 Brain Fog Protection

#### Minimal Keystrokes

**Problem:** Remembering complex commands is hard on foggy days.
**Solution:** Everything is aliased to 2-5 characters.

Examples:

- `todo` instead of `~/dotfiles/scripts/todo.sh`
- `gs` instead of `git status`
- `ll` instead of `ls -lah`
- `..` instead of `cd ..`

**200+ aliases** mean you rarely need to remember full paths or commands.

---

#### Auto-Completion & Suggestions

**Problem:** Can't remember where you were working or what's next.
**Solution:** The system remembers for you.

```bash
g suggest              # System suggests directories by usage
g recent               # Recently visited places
startday               # Morning briefing with yesterday's context
status                 # "Where am I and what am I doing?"
```

**How it works:** Every `cd` is logged. Smart scoring: `visits / (days_since + 1)` surfaces what's relevant.

---

#### Visual Clarity

**Problem:** Walls of text are overwhelming.
**Solution:** Clean, scannable output.

- Tables for structured data
- Color coding (git status, priorities)
- Top N filtering (`todo top` shows 3, not 47)
- Emoji indicators (when helpful, not excessive)
- Clear section headers

---

#### Forgiving Design

**Problem:** Mistakes happen more on foggy days.
**Solution:** Easy undo and recovery.

```bash
todo undo              # Undo last todo operation
git reflog             # All git operations are recoverable
todo commit            # Git-backed todo list
goodevening            # Auto-backup every night
```

Your data is backed up to `~/Backups/dotfiles_data/` with timestamps.

---

#### ⚡ Energy Management

#### Track Your Energy

**Track patterns you can't see in the moment:**

```bash
health energy 7        # Quick 1-10 rating
health dashboard       # 30-day trends with emoji indicators
```

**The system correlates:**

- Energy levels
- Task completion
- Git commits
- Symptoms

**Why this matters:** You'll see patterns like "Tuesdays are usually low" or "I'm more productive after logging energy."

---

#### Symptom Tracking

```bash
health symptom "brain fog, fatigue"
health symptom "headache" --severity 8
health list            # See recent symptoms
health summary         # 30-day overview
```

**Why this matters:** You can spot triggers, track medication effectiveness, prepare for doctor appointments.

---

#### Brain Fog Tracking & Circuit Breaker

**Problem:** Pushing through fog makes everything worse.
**Solution:** Track fog separately and let the system tell you when to stop.

```bash
health fog 3           # Light fog (1-10 scale)
health fog 7           # Heavy fog

# Circuit breaker - the system checks your state:
health check
```

**Circuit breaker rules:**

- **Energy ≤ 3** → 🛑 "STOP high-cognitive tasks. Rest or Low Energy Menu."
- **Fog ≥ 6** → 🛑 "EXTEND deadlines by 24h. Admin/rote work only."
- **Otherwise** → ✅ "SYSTEM OPERATIONAL"

**Why this matters:** You don't have to judge whether you should keep working. The system decides based on objective data you logged.

---

#### Medication Adherence

**Problem:** "Did I take my meds this morning?"
**Solution:** Track every dose.

```bash
meds add "Medication" "2x daily" "08:00,20:00"
meds log "Medication"          # Just took it
meds check                     # What's due now?
meds dashboard                 # 30-day adherence
```

**Automation:** Set up cron reminders:

```bash
meds remind "Medication" "08:00"
```

---

#### Break Reminders

**Problem:** Hyper-focus until you crash.
**Solution:** Automated breaks.

```bash
break                  # 15-minute break
pomo                   # 25-minute work session
remind +1h "Stretch"   # Custom reminders
```

You'll get macOS notifications when time's up.

---

#### Daily Routines That Run Themselves

**Problem:** Remembering to do self-care is hard.
**Solution:** Automation.

**Morning (`startday`):**

- Runs **once per day automatically** when you open terminal
- Shows health reminders
- Suggests where to focus
- No decision fatigue

**Evening (`goodevening`):**

- Run manually when you're done for the day
- Celebrates wins (dopamine hit!)
- Validates and backs up data
- Project safety checks

---

#### 📊 Pattern Recognition

#### AI Analysis of Your Data

**Problem:** You can't see patterns when you're in them.
**Solution:** AI analyzes your journal, tasks, and health.

```bash
journal analyze        # 7-day insights
journal mood           # 14-day sentiment analysis
journal themes         # 30-day pattern detection
health summary         # Energy trends and correlations
```

**Example insights:**

- "You write most on Tuesday mornings"
- "Fatigue mentions increased after starting new medication"
- "Your energy is highest 2 days after completing tasks"

---

#### Week in Review

```bash
weekreview             # Last 7 days summary
weekreview --file      # Export to Markdown
```

**Auto-scheduled:** Set up weekly reviews for Sundays:

```bash
scripts/setup_weekly_review.sh
```

**Why this matters:** Memory issues mean you forget accomplishments. The review reminds you of your progress.

---

#### 🎯 Focus & Prioritization

#### Daily Focus Intention

```bash
focus set "Write one blog post"
focus show             # See current focus
focus done             # Mark complete + archive to history
focus history          # Review past completions
focus clear            # Clear without archiving
```

**Displayed prominently in `startday`.**

**Why this matters:** When you're scattered, one clear intention anchors you. History tracking helps you see what you actually accomplish over time.

---

#### Top N Filtering

```bash
todo top               # Top 3 tasks only
todo top 5             # Top 5
```

**Why this matters:** Seeing 30 tasks is paralyzing. Seeing 3 is actionable.

---

#### Stale Task Detection

```bash
startday               # Shows tasks >7 days old
```

**Why this matters:** Tasks that sit too long are probably wrong. The system surfaces them for review.

---

#### 🤖 AI Offloading

#### Delegate to AI

**Problem:** Some tasks require more energy than you have.
**Solution:** AI specialists do the heavy lifting.

```bash
todo debug 3           # AI analyzes task 3
todo delegate 5 tech   # Send task 5 to tech AI
```

**All 12 AI dispatchers are free-tier.** Use them without guilt.

---

#### Context-Aware AI

**Problem:** Providing context is exhausting.
**Solution:** AI pulls context automatically.

```bash
content "blog topic" --context        # Includes recent journal + todos
content "blog topic" --full-context   # Includes git status + README
```

**What it includes:**

- Recent journal entries
- Active todos
- Current project README
- Git status (if in a repo)

---

#### AI Suggests What to Do

```bash
ai-suggest
```

**Analyzes:**

- Current directory
- Git status
- Active todos
- Recent journal entries
- Time of day
- Health/meds signals

**Returns:** Recommended AI specialists and actions.

**Example:** "You're in a blog directory with uncommitted changes. Try `content` to draft a post or `tech` to debug the build issue."

---

#### 💾 Data Safety

#### Auto-Backup

**Every night:**

```bash
goodevening → backup_data.sh
```

**Manual:**

```bash
backup-data
```

**Location:** `~/Backups/dotfiles_data/` (timestamped)

**What's backed up:**

- `todo.txt`, `todo_done.txt`
- `journal.txt`
- `health.txt`, `medications.txt`
- All bookmarks and usage logs
- Clipboard history
- How-to guides

---

#### Git-Backed Todo List

```bash
todo commit
```

**What it does:** Commits `todo.txt` to git with timestamp.

**Why this matters:** Version control for your tasks. Never lose a todo.

---

#### Validation Before Backup

```bash
data-validate
```

**Runs automatically in `goodevening`.** Checks data integrity before backup.

---

#### 🧘 Mental Health Support

#### Stoic Coaching

```bash
stoic "I'm frustrated with my limitations today"
stoic "How do I handle unpredictability?"
```

**What it does:** Stoic-philosophy-based coaching for perspective and resilience.

**When to use:**

- Frustrated with symptoms
- Overwhelmed by uncertainty
- Need reframing

---

#### Encouraging Feedback

**Every task completion:**

```
✅ Task completed! Keep up the great work!
✅ Nice! One more thing done!
✅ Awesome progress!
```

**Randomized positive reinforcement.** Small dopamine hits matter.

---

#### Win Celebration

```bash
goodevening
```

**Shows:**

- Completed tasks today
- Journal entries today
- "You're doing great!" messages

**Why this matters:** MS can make you feel unproductive. Celebrating small wins counters that.

---

#### 🔄 Low-Friction Workflows

#### No Setup Required

**Morning:**

```bash
# Literally nothing. startday runs automatically.
```

**Mid-day:**

```bash
status                 # One command
```

**Evening:**

```bash
goodevening            # One command
```

---

#### Chain Common Workflows

```bash
# Morning routine
startday && todo top && g suggest

# Evening cleanup
goodevening && todo clear

# Blog workflow
blog ideas && blog generate "Title" -p guide && blog status
```

---

#### Keyboard-Driven (No Mouse)

Everything is command-line. No:

- Clicking through menus
- Visual focus/hand-eye coordination
- Mouse precision

**Why this matters:** Fine motor control can be affected by MS. Keyboard is faster and more reliable.

---

#### 📈 Progress Visibility

#### System Health Check

```bash
dotfiles-check
```

**Validates:**

- All scripts present
- Dependencies installed
- Data directories created
- GitHub token set
- AI dispatchers working

**Output:** ✅ or ❌ for each component.

---

#### Git Progress

```bash
my-progress            # Recent commits in current repo
projects               # GitHub repos worked on recently
```

**Why this matters:** You've done more than you remember.

---

#### 🎨 Customization for Your Needs

#### Enable/Disable AI Features

In `.env`:

```bash
AI_BRIEFING_ENABLED=true       # Morning AI briefing
AI_REFLECTION_ENABLED=true     # Evening AI reflection
```

**Default:** Both disabled (opt-in, not opt-out).

---

#### Adjust Defaults

```bash
export TODO_TOP_DEFAULT=5      # Show 5 tasks instead of 3
export BREAK_DURATION=20       # 20-minute breaks
export API_COOLDOWN_SECONDS=2  # Slower API rate limiting
```

---

#### Blog Integration

```bash
export BLOG_DIR="/path/to/hugo/blog"
export BLOG_SECTION_EXEMPLARS="/path/to/examples"
```

---

#### 🧩 Real-World Scenarios

#### Scenario 1: Brain Fog Morning

**You wake up foggy and can't remember what you were working on.**

```bash
# Terminal opens, startday runs automatically
startday

# Shows:
# - Yesterday's journal context
# - Your focus: "Finish auth refactor"
# - GitHub: Last worked on repo "myapp"
# - Suggested dir: ~/projects/myapp
# - Today's calendar events (if gcal configured)
# - Top 3 tasks

# Jump right in:
g myapp                # Auto-activates venv if present
gcal agenda            # Check today's schedule
status                 # Quick reminder of where you are
todo top               # Just 3 things
```

---

#### Scenario 2: Low Energy Day

**You have energy for maybe 1-2 hours of work.**

```bash
health energy 4        # Log low energy
health fog 5           # Log fog level
health check           # Circuit breaker: ✅ OPERATIONAL (energy 4 > 3, fog 5 < 6)

spoons init 6          # Acknowledge limited budget
focus set "One PR review"  # Set minimal intention
todo top               # See top 3, pick easiest
break                  # Set 15-min break timer

# Work on one thing
spoons spend 3 "Code review"
# Break reminder arrives
# Don't push it

goodevening            # Celebrate what you DID do
focus done             # Archive completion
```

#### Scenario 2b: Circuit Breaker Day

**You wake up and log your state:**

```bash
health energy 2        # Very low
health fog 7           # Heavy fog
health check
# Output: 🛑 CIRCUIT BREAKER TRIPPED: Low Energy (2/10)
#         Action: STOP high-cognitive tasks.
#         Recommendation: Rest, active recovery, or Low Energy Menu items.
```

**What you do:** Accept it. No strategic work today. Maybe light admin, maybe just rest. The system gave you permission to stop.

---

#### Scenario 3: Medication Brain

**Just took meds that make you fuzzy. Need to capture thoughts before they're gone.**

```bash
dump                   # Opens editor
# Brain dump everything
# Save and close
# Auto-saved to journal

# Later when clearer:
journal list           # Review what you wrote
journal search "idea"  # Find that thought
```

---

#### Scenario 4: Doctor Appointment Prep

**Neurology appointment tomorrow. Need to summarize symptoms.**

```bash
health list 30         # Last 30 days
health summary         # Trends
meds dashboard         # Adherence
journal search "fatigue" --days 30

# Export for doctor:
health export appointments.txt
```

---

#### Scenario 5: Good Energy Day

**Rare high-energy day. Maximize output.**

```bash
health energy 9        # Track the good day
spoons init 18         # Extra spoons today!
focus set "Ship feature X"
gcal agenda            # Check if anything scheduled
todo                   # All tasks visible

# Work on multiple things
# Log spoon usage to understand good-day capacity
spoons spend 2 "Planning"
spoons spend 3 "Coding"
git add -A && git commit -m "Progress"
my-progress            # See what you accomplished

# Evening:
focus done             # Archive the win
spoons history         # See the pattern
goodevening            # Celebration + backup
weekreview             # Optional: see the bigger picture
```

---

#### 🎯 Key Takeaways

#### The System Assumes:

✅ You will have brain fog
✅ You will have low-energy days
✅ You will forget things
✅ You will need encouragement
✅ Your energy is unpredictable

#### The System Provides:

✅ Minimal cognitive load
✅ Maximum automation
✅ Forgiving recovery
✅ Pattern recognition
✅ Win celebration
✅ Data safety
✅ Progress visibility

#### You Don't Need to Remember:

❌ Where you were working
❌ What you were doing
❌ Complex commands
❌ To back up data
❌ To track patterns
❌ To celebrate wins

**The system remembers for you.**

---

#### 🚀 Getting Started

#### Day 1: Just Observe

```bash
startday               # See what it shows
focus set "Learn the system"  # Set intention
spoons init 10         # Start energy tracking
todo "Try one thing"   # Add one task
journal "Day 1"        # One entry
goodevening            # Evening routine
focus done             # Complete the focus
```

#### Week 1: Add Health Tracking

```bash
health energy 7        # Daily
meds log "Medication"  # As taken
```

#### Week 2: Try One AI Dispatcher

```bash
tech "question"        # Or stoic, or content
```

#### Month 1: Full Integration

```bash
# Morning: automatic
# During: status, todo, journal
# Evening: goodevening
# Weekly: weekreview
```

---

#### 📞 When You Need Help

```bash
whatis <command>       # What does this do?
dotfiles-check         # Is everything working?
ai-suggest             # What should I do next?
```

**Documentation:**

- `docs/start-here.md` - Feature Discovery section
- `docs/daily-cheatsheet.md` - One-page reference
- `docs/happy-path.md` - Daily walkthrough
- `TROUBLESHOOTING.md` - Common issues

---

#### Related Docs

- [Start Here](start-here.md)
- [Daily Cheat Sheet](daily-cheatsheet.md)
- [Happy Path](happy-path.md)
- [System Overview](system-overview.md)
- [Troubleshooting](../TROUBLESHOOTING.md)

---

**You built this for yourself. Trust it. Use it. You deserve tools that work _with_ your energy, not against it.** 🎯

## ✅ Best Practices & Workflows

This guide covers proven strategies for maximizing productivity, maintaining data hygiene, and building sustainable workflows with your AI-augmented dotfiles system.

#### TL;DR

- Use `startday` and `goodevening` to bookend your day.
- Keep data clean with `data_validate --format` and backups.
- Use `ai-suggest` to pick the right dispatcher when stuck.

> **Quick note on dispatchers:** Use the single-word aliases (they invoke the `dhp-*` scripts directly) for minimal typing. When you need a unified entry point or want to reference squads from `squads.json`, use `dispatch <squad> "brief"`. All scripts have been refactored for improved robustness and maintainability.
>
> **Security Note:** For detailed information on security practices, how to report vulnerabilities, and credential management, please refer to our [Security Policy](../../SECURITY.md).

**Last Updated:** January 1, 2026

---

#### Table of Contents

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

#### First Week: Building the Habit

#### Day 1-2: Core Loop Only

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

#### Day 3-4: Add Navigation

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

#### Day 5-7: Explore AI Features

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

#### Week 2+: Gradual Expansion

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

#### Daily Routines

#### Morning (The Anchor)

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

#### Midday (The Check-In)

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

#### Evening (The Close)

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

#### Weekly (The Synthesis)

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

#### Data Hygiene & Maintenance

#### Keep Your Todo List Healthy

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

**Fix:** Create a separate `ideas.txt` for aspirational items using `idea add "your idea"`. You can promote it later using `idea to-todo <num>`, or demote an aging task using `todo to-idea <num>`.

---

#### Journal for Searchability

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

#### Bookmark Pruning

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

#### Data Validation

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

#### AI Dispatcher Optimization

#### Start with ai-suggest

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

#### Use the Right Dispatcher for the Job

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

#### Context Injection Best Practices

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

#### Streaming for Long-Running Tasks

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

#### Chaining Strategies

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

#### Save Important AI Outputs

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

#### Task Management Excellence

#### The Priority System

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

#### The Daily Commit Pattern

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

#### Delegation to AI

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

#### Journal & Knowledge Management

#### The Journal Pyramid

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

#### Search-Driven Knowledge

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

#### The How-To Wiki

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

#### Navigation & Workspace Optimization

#### The 5-Bookmark Rule

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

#### Let Usage Drive Suggestions

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

#### On-Enter Hooks (Advanced)

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

#### Health & Energy Tracking

#### The Correlation Pattern

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

#### Medication Adherence

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

#### Pre-Appointment Exports

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

#### Common Pitfalls & How to Avoid Them

#### Pitfall 1: Perfectionism Paralysis

**Symptom:** Not starting because "the system isn't perfect yet"

✅ **Fix:**

```bash
# Just use the core loop for a week
startday → todo → journal → goodevening

# Perfect is the enemy of done
# The system helps you ship, not achieve perfection
```

---

#### Pitfall 2: Todo List Becomes Overwhelming

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

#### Pitfall 3: Journal Without Searching

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

#### Pitfall 4: Over-Booking with AI

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

#### Pitfall 5: Ignoring System Warnings

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

#### Advanced Techniques

#### Workflow Stacking

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

#### Custom Dispatcher Combinations

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

#### Context Switching Protocol

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

#### Customization Guidelines

#### When to Customize

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

#### How to Customize Safely

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

#### Customization Ideas

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

#### Backup & Recovery Strategy

#### The 3-2-1 Rule

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

#### What to Backup

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

#### Recovery Testing

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

#### Quick Wins Checklist

**After reading this guide, implement these first:**

#### Week 1

- [ ] Run `startday` every morning (automatic)
- [ ] Set daily focus with `focus set "..."`
- [ ] Add tasks with `todo add`
- [ ] Journal at least once per day
- [ ] Run `goodevening` before closing laptop

#### Week 2

- [ ] Create 3-5 `g save` bookmarks for frequent locations
- [ ] Try `ai-suggest` when unsure what to do
- [ ] Use `next` instead of `todo list` when overwhelmed
- [ ] Run `journal search` to find something from last week

#### Week 3

- [ ] Use one AI dispatcher (tech, strategy, or stoic)
- [ ] Track energy levels 3x this week with `health energy`
- [ ] Try `dump` for long-form reflection
- [ ] Run `weekreview --file`

#### Week 4

- [ ] Set up automated weekly review with `setup_weekly_review`
- [ ] Create one how-to guide with `howto add`
- [ ] Try `todo commit` for git workflow
- [ ] Experiment with context injection: `content --context`

#### Ongoing

- [ ] Run `dotfiles_check` weekly
- [ ] Review `health dashboard` monthly
- [ ] Prune bookmarks quarterly (automatic via `g prune --auto`)
- [ ] Test backup recovery quarterly

---

#### Final Principles

#### 1. **Consistency Over Perfection**

Better to use the basic loop daily than to build the perfect system you never use.

```bash
# This beats any perfect system:
startday → work → journal → goodevening
```

---

#### 2. **Search Over Memory**

Trust the system to remember. Your job is to capture.

```bash
# Don't stress about remembering
# Just make it searchable
journal "worked on X with Y, learned Z"
```

---

#### 3. **Automate the Routine, Decide on the Exception**

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

#### 4. **Delegate When Stuck, Learn When Flowing**

AI is there for the hard moments, not to replace the learning moments.

```bash
# Stuck? Delegate.
echo "problem I can't solve" | tech

# Flowing? Keep going.
# The satisfaction of solving it yourself > AI solution
```

---

#### 5. **Build on What Works**

Notice what you actually use. Do more of that. Ignore the rest.

```bash
# After a month, review:
systemlog | grep "feature-name"

# Used frequently? Optimize it.
# Never used? Remove it.
```

---

#### Additional Resources

- **Daily Workflow:** `~/dotfiles/docs/happy-path.md`
- **AI Quick Reference:** `~/dotfiles/docs/ai-quick-reference.md`
- **System Overview:** `~/dotfiles/README.md`
- **Technical Docs:** `~/dotfiles/bin/README.md`
- **Clipboard Workflows:** `~/dotfiles/docs/clipboard.md`

---

#### Related Docs

- [Start Here](start-here.md)
- [Happy Path](happy-path.md)
- [System Overview](system-overview.md)
- [AI Quick Reference](ai-quick-reference.md)
- [Troubleshooting](../TROUBLESHOOTING.md)

---

**Remember:** This system exists to reduce cognitive load, not create it. Use what helps, ignore what doesn't, customize when you're ready.

Start simple. Build habits. Let the system grow with you.

## 📋 Clipboard Power Moves

macOS ships with `pbcopy` and `pbpaste`, two tiny commands that turn the system clipboard into a first-class shell tool. Combined with pipes and redirects, they let you capture command output, pre-process snippets, and paste them back anywhere without touching the mouse.

#### TL;DR

- Use `pbcopy` and `pbpaste` to move data through pipelines.
- Use `clip save` / `clip load` for reusable snippets.
- Snippets live in `~/.config/dotfiles-data/clipboard_history.txt`.

#### Essentials

- **Copy anything:** `echo "Hello" | pbcopy` or `pbcopy < path/to/file`
- **Paste in scripts:** `pbpaste` prints the clipboard to stdout, so you can redirect or pipe it (`pbpaste > notes.txt`, `pbpaste | jq '.'`).
- **Stay in the shell:** Every example below avoids manual copy/paste steps—perfect for low-energy days.

#### Capture Output Fast

| Goal                           | Command                                                                    |
| ------------------------------ | -------------------------------------------------------------------------- |
| Copy command output            | `ls -al \| pbcopy`                                                         |
| Copy the last command’s output | `!! \| pbcopy` (requires the output to still be in history, use with care) |
| Copy a JSON response           | `curl https://api.example.com \| pbcopy`                                   |
| Copy git diff for review       | `git diff \| pbcopy`                                                       |
| Copy formatted date            | `date '+%Y-%m-%d' \| pbcopy`                                               |

Tip: pair with aliases like `copy` or `copyfile` that already wrap `pbcopy`.

#### Transform Before Copying

Pipes let you massage output _before_ it hits the clipboard:

```bash
rg "TODO" -n src | sort | pbcopy
ps aux | sort -rk 3 | head -n 5 | pbcopy
jq '.items[] | {name, url}' bookmarks.json | pbcopy
```

#### Use Clipboard Content in Pipelines

Once the clipboard holds data, `pbpaste` drops it into any pipeline:

```bash
pbpaste | sed 's/http/https/g' | pbcopy        # replace and put back
pbpaste | code -                               # open in VS Code without a temp file
pbpaste | tee backup.txt | less                # view while saving to a file
pbpaste | sh                                   # run a copied shell snippet (only if you trust it!)
pbpaste | jq '.summary'                        # inspect a copied JSON blob
```

#### Saved Snippet Toolbox (`clip`)

The repo ships with a `clip` helper that stores clipboard snippets in `~/.config/dotfiles-data/clipboard_history.txt`:

```bash
clip save standup    # Save the current clipboard as "standup"
clip list            # Preview the first part of each saved clip
clip load standup    # Restore the snippet to your clipboard
```

- Entries are stored as pipe-delimited lines: `YYYY-MM-DD HH:MM:SS|name|content`.
- Multi-line content is stored with `\n` escapes.
- `clip peek` gives you a quick look at whatever is currently sitting in the clipboard.
- `clip load <name>` returns exit code `3` when the clip name does not exist.

#### Real-World Workflows

#### Save a Command’s Output and Share It

```bash
rg "search term" src | pbcopy          # copy the interesting lines
pbpaste > findings.txt                 # drop them into a file
mail -s "FYI" teammate@example.com < findings.txt
```

#### Capture Logs, Clean Them, and Paste into Slack

```bash
tail -n 200 logs/app.log \
  | rg -v "DEBUG" \
  | sed 's/[0-9]\{4\}-[0-9\-: ]\+/<timestamp>/g' \
  | pbcopy
# ⌘+V in Slack (already formatted)
```

#### Turn Clipboard HTML into Plain Text Notes

```bash
pbpaste | textutil -stdin -convert txt -stdout | pbcopy
pbpaste >> notes/inbox.md
```

#### Quick JSON Pretty-Print for API Responses

```bash
curl -s https://api.example.com/things | pbcopy
pbpaste | jq '.' | pbcopy
pbpaste > responses/pretty.json
```

#### Edit Copied Text in Vim Without Temporary Files

```bash
pbpaste > /tmp/clipboard.$$
vim /tmp/clipboard.$$
pbcopy < /tmp/clipboard.$$
rm /tmp/clipboard.$$
```

#### Round-Trip Macros

Create reusable helpers to round-trip clipboard content through a formatter or sanitizer:

```bash
function clipfmt() {
    pbpaste | "$@" | pbcopy
}
clipfmt jq '.'             # pretty-print JSON in place
clipfmt prettier --parser markdown
```

#### Integrations in This Repo

- `copy`, `paste`, `copyfile`, and `copyfolder` aliases (`zsh/aliases.zsh`).
- `clip`, `clip save`, `clip load`, `clip list`, and `clip peek` wrap `clipboard_manager.sh` (supports executable snippets for dynamic output).
- `graballtext` pairs well with `pbcopy` for quick sharing: `graballtext && pbcopy < all_text_contents.txt`.

#### Troubleshooting

- `pbcopy` reads until EOF—remember to press `Ctrl+D` when typing interactively.
- Large blobs (> few MB) can bloat the clipboard; clear with `pbcopy < /dev/null`.
- If `clip load <name>` says `not found`, run `clip list` to verify the saved name.
- Remote shells (e.g., SSH) do not have access to your local clipboard; use tools like `pbcopy` via `ssh -t` or rely on `tmux` copy modes instead.

---

#### Related Docs

- [Start Here](start-here.md)
- [Daily Cheat Sheet](daily-cheatsheet.md)
- [Best Practices](best-practices.md)
- [Troubleshooting](../TROUBLESHOOTING.md)

---

Stay in flow by letting the clipboard handle the shuffling—your hands stay on the keyboard, and your brain stays focused.

## 🔬 Falsification-First Insight Module

This module adds a hypothesis workflow focused on disproof-before-belief:

1. Create a hypothesis.
2. Plan and run a disconfirming test.
3. Add evidence with provenance.
4. Produce a verdict with hard support gates.

#### Command

```bash
insight.sh <command> [options]
```

#### Core Commands

```bash
# Create a hypothesis
insight.sh new "Claim text" --domain health --novelty 4 --prior 0.50

# Plan a disconfirming test
insight.sh test-plan HYP-20260206-001 --prediction "Expected failure" --fail-criterion "No measurable effect"

# Record test attempt/result
insight.sh test-result TST-20260206-001 --status attempted --result "Ran test with 10-day sample"

# Add evidence
insight.sh evidence add HYP-20260206-001 --direction against --strength 4 --source "paper://doi-or-link" --provenance "paper"

# Produce verdict with gate checks
insight.sh verdict HYP-20260206-001 --confidence 0.62 --counterargument "Selection bias" --response "Compared against baseline cohort"

# Weekly KPI summary
insight.sh weekly --low-spoons
```

#### Data Files

All files live in `~/.config/dotfiles-data/`:

- `insight_hypotheses.txt`  
  `ID|CREATED_AT|DOMAIN|CLAIM|STATUS|PRIOR_CONFIDENCE|NOVELTY|NEXT_TEST|BEST_COUNTERARGUMENT|COUNTERARGUMENT_RESPONSE`
- `insight_tests.txt`  
  `TEST_ID|HYP_ID|CREATED_AT|TYPE|PREDICTION|FAIL_CRITERION|STATUS|RESULT`
- `insight_evidence.txt`  
  `EVID_ID|HYP_ID|TIMESTAMP|DIRECTION|STRENGTH|SOURCE|PROVENANCE|NOTE`
- `insight_verdicts.txt`  
  `HYP_ID|TIMESTAMP|VERDICT|CONFIDENCE|WHY|COUNTEREVIDENCE_SUMMARY`

#### Support Gates

A hypothesis cannot end as `SUPPORTED` unless all gates pass:

1. At least one disconfirming test was attempted.
2. At least two independent evidence sources are logged.
3. Best counterargument and response are both present.
4. Verdict confidence changed from the prior confidence.

If any gate fails, a requested `SUPPORTED` verdict is downgraded to `INCONCLUSIVE`.

---

---

## 📦 Installation & Bootstrap Guide

To install this dotfiles system on a new macOS machine, follow these exact steps. The repo includes a `bootstrap.sh` script that handles dependency installation, directory creation, and path mapping automatically.

### 1. Clone the Repository

```bash
git clone https://github.com/ryan258/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 2. Initialize the AI Submodule

If you plan to use the `dhp-*` AI dispatchers, you must initialize the `ai-staff-hq` submodule:

```bash
git submodule update --init --recursive
```

### 3. Run Bootstrap

The bootstrap script will safely install Homebrew, `jq`, `gawk`, and `curl`, create the `~/.config/dotfiles-data` directory, initialize all empty data files, and inject the proper `PATH` into `~/.zshenv`.

```bash
./bootstrap.sh
# To bypass prompts for existing installations: ./bootstrap.sh --force
```

### 4. Configure Environment Variables

You must configure your API keys and directory paths before using the system.

```bash
cp .env.example .env
nano .env
```

Ensure you set your `OPENROUTER_API_KEY`!

### 5. Finalize Installation

Restart your terminal, or reload your shell:

```bash
source ~/.zshrc
dotfiles-check
```

If `dotfiles-check` returns all green checkmarks, you are fully installed.

---

## 💾 Data Schemas & Formats Reference

All personal data in this system is strictly stored in local, plaintext files under `~/.config/dotfiles-data/`. If you ever need to manually read, grep, or script against your data, use the following schema definitions. **Always use the pipe (`|`) character as the delimiter.**

| File                  | Schema Format                                   | Example                                     |
| --------------------- | ----------------------------------------------- | ------------------------------------------- |
| `todo.txt`            | `YYYY-MM-DD\|task text`                         | `2026-02-27\|Fix markdown bug`              |
| `todo_done.txt`       | `YYYY-MM-DD HH:MM:SS\|task text`                | `2026-02-27 15:30:00\|Fix markdown bug`     |
| `journal.txt`         | `YYYY-MM-DD HH:MM:SS\|entry`                    | `2026-02-27 09:00:00\|Feeling foggy today.` |
| `health.txt`          | `TYPE\|DATE\|field1\|field2...`                 | `SYMPTOM\|2026-02-27\|headache\|3`          |
| `spoons.txt` (Budget) | `BUDGET\|DATE\|count`                           | `BUDGET\|2026-02-27\|12`                    |
| `spoons.txt` (Spend)  | `SPEND\|DATE\|TIME\|count\|activity\|remaining` | `SPEND\|2026-02-27\|10:00\|2\|Coding\|10`   |

---

## 👨‍💻 Developer & Testing Standards

If you intend to modify the core scripts or write your own, you **must** adhere strictly to the rules laid out in `CLAUDE.md` and `GEMINI.md`. This system is designed for high reliability to prevent cascading failures on low-energy days.

### Executed Scripts vs. Sourced Libraries

There are two strict classes of bash files in this codebase:

1. **Executed Scripts (`scripts/*.sh`, `bin/dhp-*.sh`)**:
   These are standalone programs. They **must** start with `#!/usr/bin/env bash` and **must** include `set -euo pipefail` to catch errors immediately. Use `exit` to terminate.

2. **Sourced Libraries (`scripts/lib/*.sh`, `zsh/aliases.zsh`)**:
   These files load into other shells. They **must never** use `set -euo pipefail` because an error here will kill the parent shell or interactive terminal. They must use double-source guards (e.g. `if [[ -n "${_FILENAME_LOADED:-}" ]]; then return 0; fi`) and use `return` instead of `exit`.

### Input Sanitization

Never run `eval` on user input. All input must be sanitized before writing to `~/.config/dotfiles-data/`:

```bash
clean_input=$(sanitize_input "$user_input")
echo "$clean_input" >> "$TODO_FILE"
```

### Testing (Bats)

All shell extensions must be tested using `bats-core`. Tests live in `tests/test_*.sh`. To run the test suite:

```bash
bats tests/*.sh
```

---

## 🔤 Comprehensive Aliases Reference

The following aliases are parsed directly from `zsh/aliases.zsh` to give you an exhaustive list of all commands available in your terminal.

| Alias | Target Command | Description |
| ----- | -------------- | ----------- |

### NAVIGATION & DIRECTORY SHORTCUTS

| Alias       | Target Command                | Description                                            |
| ----------- | ----------------------------- | ------------------------------------------------------ |
| `..`        | `cd ..`                       |                                                        |
| `...`       | `cd ../..`                    |                                                        |
| `....`      | `cd ../../..`                 |                                                        |
| `ll`        | `ls -alF`                     | Full detail + type indicators                          |
| `la`        | `ls -A`                       | All except . and ..                                    |
| `l`         | `ls -CF`                      | Compact columns with type indicators                   |
| `lt`        | `ls -altr`                    | Chronological, newest at bottom                        |
| `lh`        | `ls -alh`                     | Sizes in K/M/G instead of bytes                        |
| `here`      | `ls -la`                      | Everything in this directory, long format              |
| `dtree`     | `find . -type d \| head -20`  | Directory tree sketch (avoids shadowing /usr/bin/tree) |
| `newest`    | `ls -lt \| head -10`          | 10 most recently modified files                        |
| `biggest`   | `ls -lS \| head -10`          | 10 largest files by size                               |
| `count`     | `ls -1 \| wc -l`              | Count of items in current directory                    |
| `downloads` | `cd ~/Downloads`              |                                                        |
| `documents` | `cd ~/Documents`              |                                                        |
| `desktop`   | `cd ~/Desktop`                |                                                        |
| `scripts`   | `cd ~/scripts`                |                                                        |
| `home`      | `cd ~`                        |                                                        |
| `docs`      | `cd ~/Documents`              | Short form of 'documents'                              |
| `down`      | `cd ~/Downloads`              | Short form of 'downloads'                              |
| `desk`      | `cd ~/Desktop`                | Short form of 'desktop'                                |
| `update`    | `brew update && brew upgrade` |                                                        |
| `brewclean` | `brew cleanup`                | Remove old versions and stale downloads                |
| `brewinfo`  | `brew list --versions`        | Show every installed formula + version                 |
| `myip`      | `curl ifconfig.me`            | Public/external IP via ifconfig.me API                 |
| `localip`   | `ifconfig \| grep inet`       | All local interface IPs (IPv4 + IPv6)                  |
| `mem`       | `vm_stat`                     | macOS virtual memory stats (page-based)                |
| `cpu`       | `top -l 1 \| head -n 10`      | One-shot top snapshot, header only                     |
| `psg`       | `ps aux \| grep`              |                                                        |

### FILE OPERATIONS

| Alias       | Target Command                                                            | Description                          |
| ----------- | ------------------------------------------------------------------------- | ------------------------------------ |
| `rm`        | `rm -i`                                                                   | Confirm before every removal         |
| `cp`        | `cp -i`                                                                   | Confirm before overwriting target    |
| `mv`        | `mv -i`                                                                   | Confirm before overwriting target    |
| `untar`     | `tar -xvf`                                                                | eXtract Verbosely from File          |
| `targz`     | `tar -czvf`                                                               | Create gZipped tar archive Verbosely |
| `ff`        | `find . -name`                                                            |                                      |
| `showfiles` | `defaults write com.apple.finder AppleShowAllFiles YES && killall Finder` |                                      |
| `hidefiles` | `defaults write com.apple.finder AppleShowAllFiles NO && killall Finder`  |                                      |
| `spotlight` | `mdfind`                                                                  |                                      |

### GIT SHORTCUTS

| Alias  | Target Command      | Description                                      |
| ------ | ------------------- | ------------------------------------------------ |
| `gs`   | `git status`        | Working tree status                              |
| `ga`   | `git add`           | Stage specific files — e.g. `ga file.txt`        |
| `gaa`  | `git add .`         | Stage everything in cwd (use with care)          |
| `gc`   | `git commit -m`     | Commit with inline message — e.g. `gc "fix bug"` |
| `gp`   | `git push`          | Push current branch to remote                    |
| `gl`   | `git pull`          | Pull (fetch + merge) from remote                 |
| `gd`   | `git diff`          | Unstaged changes vs last commit                  |
| `gb`   | `git branch`        | List or create branches                          |
| `gco`  | `git checkout`      | Switch branches or restore files                 |
| `glog` | `git log --oneline` | Compact one-line-per-commit log                  |

### TEXT EDITING & VIEWING

| Alias      | Target Command | Description                         |
| ---------- | -------------- | ----------------------------------- |
| `v`        | `vim`          | e.g. `v config.yaml`                |
| `n`        | `nano`         | e.g. `n notes.txt` (simpler editor) |
| `e`        | `echo`         | Quick echo for piping/testing       |
| `codehere` | `code .`       | Launch VS Code rooted here          |
| `finder`   | `open .`       | Launch Finder window here           |

### UTILITY SHORTCUTS

| Alias       | Target Command                 | Description                                           |
| ----------- | ------------------------------ | ----------------------------------------------------- |
| `c`         | `clear`                        | Minimal keystroke clear                               |
| `cls`       | `clear`                        | For muscle memory from Windows/DOS                    |
| `now`       | `date`                         | Current date/time in default locale                   |
| `timestamp` | `date +%Y%m%d_%H%M%S`          | Filename-safe timestamp (no colons/spaces)            |
| `du`        | `du -h`                        | Directory size summary                                |
| `df`        | `df -h`                        | Filesystem free space                                 |
| `diskspace` | `df -h`                        | Readable alias for df                                 |
| `ping`      | `ping -c 5`                    | Limit to 5 pings (macOS ping runs forever by default) |
| `flushdns`  | `sudo dscacheutil -flushcache` | Clear macOS DNS resolver cache                        |

### DEVELOPMENT SHORTCUTS

| Alias      | Target Command             | Description                          |
| ---------- | -------------------------- | ------------------------------------ |
| `python`   | `python3`                  |                                      |
| `pip`      | `pip3`                     |                                      |
| `venv`     | `python3 -m venv`          | Create venv — e.g. `venv .venv`      |
| `activate` | `source venv/bin/activate` | Activate a venv in ./venv/           |
| `serve`    | `python3 -m http.server`   | HTTP server on :8000 for current dir |
| `jsonpp`   | `python3 -m json.tool`     | Pretty-print JSON from stdin or file |

### MACOS CLIPBOARD & UTILITIES

| Alias         | Target Command            | Description                                        |
| ------------- | ------------------------- | -------------------------------------------------- |
| `copy`        | `pbcopy`                  | Pipe text to clipboard — e.g. `echo hi \| copy`    |
| `paste`       | `pbpaste`                 | Emit clipboard contents to stdout                  |
| `copyfile`    | `pbcopy <`                | Copy a file's contents — e.g. `copyfile notes.txt` |
| `copyfolder`  | `tail -n +1 \* \| pbcopy` | Copy ALL files' contents in cwd to clipboard       |
| `screensleep` | `pmset displaysleepnow`   | Immediately sleep the display                      |
| `lock`        | `pmset displaysleepnow`   | Lock screen (display sleep triggers lock)          |
| `eject`       | `diskutil eject`          | Eject external disk — e.g. `eject /dev/disk2`      |
| `battery`     | `pmset -g batt`           | Show battery % and charging status                 |

### CORE PRODUCTIVITY SCRIPTS

| Alias            | Target Command             | Description                                                       |
| ---------------- | -------------------------- | ----------------------------------------------------------------- |
| `howto`          | `howto.sh`                 | Interactive help / how-to lookup                                  |
| `wi`             | `whatis.sh`                | Explain a command (named 'wi' to avoid shadowing /usr/bin/whatis) |
| `dotfiles_check` | `dotfiles_check.sh`        | Verify dotfiles installation integrity                            |
| `dotfiles-check` | `dotfiles_check.sh`        | Hyphenated alternative for the same check                         |
| `pomo`           | `take_a_break.sh 25`       | Pomodoro timer — 25-minute focus session                          |
| `todo`           | `todo.sh`                  | Task manager entry point                                          |
| `todolist`       | `todo.sh list`             | List all open tasks                                               |
| `tododone`       | `todo.sh done`             | Mark a task as completed                                          |
| `todoadd`        | `todo.sh add`              | Add a new task                                                    |
| `journal`        | `journal.sh`               | Journal entry point                                               |
| `break`          | `take_a_break.sh`          | Flexible break timer (default duration)                           |
| `focus`          | `focus.sh`                 | Focus mode — block distractions                                   |
| `t-start`        | `todo.sh start`            | Start timing a task                                               |
| `t-stop`         | `todo.sh stop`             | Stop timing the current task                                      |
| `t-status`       | `time_tracker.sh status`   | Show what's being tracked and elapsed time                        |
| `spoons`         | `spoon_manager.sh`         | Full spoon manager interface                                      |
| `s-check`        | `spoon_manager.sh check`   | How many spoons remain today?                                     |
| `s-spend`        | `spoon_manager.sh spend`   | Log spending spoons on an activity                                |
| `correlate`      | `correlate.sh`             | Find patterns between health/productivity data                    |
| `daily-report`   | `generate_report.sh daily` | Generate today's summary report                                   |
| `insight`        | `insight.sh`               | AI-powered insight from recent data                               |
| `health`         | `health.sh`                | Log symptoms, energy, and health events                           |
| `meds`           | `meds.sh`                  | Medication tracking and reminders                                 |
| `next`           | `todo.sh top 1`            | Show the single highest-priority task                             |
| `t`              | `todo.sh list`             | 1-key todo list                                                   |
| `j`              | `journal.sh`               | 1-key journal                                                     |
| `ta`             | `todo.sh add`              | 2-key task add — e.g. `ta "Buy groceries"`                        |
| `ja`             | `journal.sh add`           | 2-key journal add — e.g. `ja "Good energy today"`                 |
| `memo`           | `cheatsheet.sh`            | Show personal cheatsheet / quick reference                        |
| `schedule`       | `schedule.sh`              | View today's schedule                                             |
| `clutter`        | `review_clutter.sh`        | Review and clean up stale files                                   |
| `checkenv`       | `validate_env.sh`          | Validate .env config is complete and correct                      |
| `newscript`      | `new_script.sh`            | Scaffold a new bash script with proper headers                    |
| `weather`        | `weather.sh`               | Current weather forecast                                          |
| `findtext`       | `findtext.sh`              | Search file contents recursively                                  |
| `graballtext`    | `grab_all_text.sh`         | Concatenate all text files in a directory                         |
| `newproject`     | `start_project.sh`         | Scaffold a new project directory                                  |
| `newpython`      | `mkproject_py.sh`          | Scaffold a Python project with venv                               |
| `newpy`          | `mkproject_py.sh`          | Short form of newpython                                           |
| `progress`       | `my_progress.sh`           | Show git contribution stats / progress                            |
| `projects`       | `gh-projects.sh`           | List GitHub projects                                              |
| `backup`         | `backup_project.sh`        | Back up current project directory                                 |
| `backup-data`    | `backup_data.sh`           | Back up ~/.config/dotfiles-data/                                  |
| `findbig`        | `findbig.sh`               | Find large files eating disk space                                |
| `unpack`         | `unpacker.sh`              | Smart archive extractor (tar/zip/gz/etc.)                         |
| `tidydown`       | `tidy_downloads.sh`        | Auto-organize ~/Downloads by file type                            |
| `startday`       | `startday.sh`              | Morning routine: weather, briefing, todos, spoons                 |
| `goodevening`    | `goodevening.sh`           | Evening wind-down: journal prompt, summary                        |
| `greeting`       | `greeting.sh`              | Quick motivational greeting                                       |
| `weekreview`     | `week_in_review.sh`        | Weekly retrospective summary                                      |

### NAVIGATION & FILE MANAGEMENT SCRIPTS

| Alias          | Target Command                                  | Description                                   |
| -------------- | ----------------------------------------------- | --------------------------------------------- |
| `g`            | `source $DOTFILES_ALIAS_ROOT/scripts/g.sh`      |                                               |
| `openf`        | `open_file.sh`                                  | Open a file with its default macOS app        |
| `finddupes`    | `duplicate_finder.sh`                           | Find duplicate files by content hash          |
| `organize`     | `file_organizer.sh`                             | Auto-organize files by type/date              |
| `systemlog`    | `tail -n 20 ~/.config/dotfiles-data/system.log` | Last 20 log lines                             |
| `logs`         | `logs.sh`                                       | Full log viewer                               |
| `logtail`      | `logs.sh tail`                                  | Follow log in real time                       |
| `logerrors`    | `logs.sh errors`                                | Show only error-level entries                 |
| `sysinfo`      | `system_info.sh`                                | CPU, memory, disk, OS summary                 |
| `batterycheck` | `battery_check.sh`                              | Detailed battery health report                |
| `processes`    | `process_manager.sh`                            | Interactive process manager                   |
| `netinfo`      | `network_info.sh`                               | Network interfaces and connectivity           |
| `topcpu`       | `process_manager.sh top`                        | Processes sorted by CPU usage                 |
| `topmem`       | `process_manager.sh memory`                     | Processes sorted by memory usage              |
| `netstatus`    | `network_info.sh status`                        | Am I connected? What IP?                      |
| `netspeed`     | `network_info.sh speed`                         | Quick bandwidth test                          |
| `gcal`         | `gcal.sh`                                       |                                               |
| `calendar`     | `gcal.sh`                                       | Note: intentionally shadows /usr/bin/calendar |

### PRODUCTIVITY & AUTOMATION SCRIPTS

| Alias      | Target Command              | Description                                                |
| ---------- | --------------------------- | ---------------------------------------------------------- |
| `clip`     | `clipboard_manager.sh`      | Full clipboard manager interface                           |
| `clipsave` | `clipboard_manager.sh save` | Save current clipboard to a named slot                     |
| `clipload` | `clipboard_manager.sh load` | Load a named slot back to clipboard                        |
| `cliplist` | `clipboard_manager.sh list` | List all saved clipboard slots                             |
| `app`      | `app_launcher.sh`           |                                                            |
| `launch`   | `app_launcher.sh`           | Synonym for discoverability                                |
| `remind`   | `remind_me.sh`              | Set a timed reminder notification                          |
| `did`      | `done.sh`                   | Log a completed activity ('done' is a shell reserved word) |
| `dev`      | `dev_shortcuts.sh`          | Dev shortcuts menu                                         |
| `server`   | `dev_shortcuts.sh server`   | Start a local dev server                                   |
| `json`     | `dev_shortcuts.sh json`     | JSON formatting/inspection                                 |
| `gitquick` | `dev_shortcuts.sh gitquick` | Quick git add+commit+push                                  |

### FILE PROCESSING & ANALYSIS SCRIPTS

| Alias         | Target Command                                             | Description                              |
| ------------- | ---------------------------------------------------------- | ---------------------------------------- |
| `textproc`    | `text_processor.sh`                                        | Full text processor menu                 |
| `wordcount`   | `text_processor.sh count`                                  | Word/line/char count                     |
| `textsearch`  | `text_processor.sh search`                                 | Search within files                      |
| `textreplace` | `text_processor.sh replace`                                | Find-and-replace across files            |
| `textclean`   | `text_processor.sh clean`                                  | Strip whitespace, fix encoding, etc.     |
| `media`       | `media_converter.sh`                                       | Full media converter menu                |
| `video2audio` | `media_converter.sh video2audio`                           | Extract audio track from video           |
| `resizeimg`   | `media_converter.sh resize_image`                          | Resize images (preserves aspect)         |
| `compresspdf` | `media_converter.sh pdf_compress`                          | Reduce PDF file size                     |
| `stitch`      | `media_converter.sh audio_stitch`                          | Concatenate audio files                  |
| `archive`     | `archive_manager.sh`                                       | Full archive manager menu                |
| `archcreate`  | `archive_manager.sh create`                                | Create a new archive                     |
| `archextract` | `archive_manager.sh extract`                               | Extract an archive                       |
| `archlist`    | `archive_manager.sh list`                                  | List archive contents without extracting |
| `info`        | `weather.sh && echo && todo.sh list`                       | Weather + open tasks                     |
| `status`      | `status.sh`                                                | Unified status dashboard                 |
| `overview`    | `system_info.sh && echo && battery_check.sh`               | Hardware + battery                       |
| `cleanup`     | `cd ~/Downloads && file_organizer.sh bytype && findbig.sh` | Tidy Downloads, flag large files         |
| `quickbackup` | `backup_project.sh && echo 'Backup complete!'`             | One-command project backup               |
| `devstart`    | `dev_shortcuts.sh env && codehere`                         | Load env vars, open VS Code              |
| `gitcheck`    | `my_progress.sh && git status`                             | Contribution stats + working tree        |
| `wk`          | `with-keys`                                                | Run a command with SSH keys loaded       |
| `wr`          | `with-req --`                                              | Run a command with required credentials  |

### SETUP INSTRUCTIONS

| Alias | Target Command | Description |
| ----- | -------------- | ----------- |

### CUSTOMIZATION NOTES

| Alias | Target Command | Description |
| ----- | -------------- | ----------- |

### EXAMPLE WORKFLOWS

| Alias  | Target Command       | Description |
| ------ | -------------------- | ----------- |
| `grep` | `ggrep --color=auto` |             |
| `grep` | `grep --color=auto`  |             |

### BLOG WORKFLOW

| Alias           | Target Command           | Description                                     |
| --------------- | ------------------------ | ----------------------------------------------- |
| `blog`          | `blog.sh`                | Blog management CLI (create, publish, list)     |
| `blog-recent`   | `blog_recent_content.sh` | Show recently published/drafted blog posts      |
| `dump`          | `dump.sh`                | Dump structured data for debugging/export       |
| `data_validate` | `data_validate.sh`       | Validate data files in ~/.config/dotfiles-data/ |

### AI STAFF HQ DISPATCHERS

| Alias               | Target Command                                   | Description                                            |
| ------------------- | ------------------------------------------------ | ------------------------------------------------------ |
| `dhp-tech`          | `$DOTFILES_ALIAS_ROOT/bin/dhp-tech.sh`           | Technical/coding assistant                             |
| `dhp-creative`      | `$DOTFILES_ALIAS_ROOT/bin/dhp-creative.sh`       | Creative writing & ideation                            |
| `dhp-content`       | `$DOTFILES_ALIAS_ROOT/bin/dhp-content.sh`        | Content strategy & drafting                            |
| `dhp-strategy`      | `$DOTFILES_ALIAS_ROOT/bin/dhp-strategy.sh`       | Business/life strategy advisor                         |
| `dhp-brand`         | `$DOTFILES_ALIAS_ROOT/bin/dhp-brand.sh`          | Brand voice & identity                                 |
| `dhp-market`        | `$DOTFILES_ALIAS_ROOT/bin/dhp-market.sh`         | Market analysis & trends                               |
| `dhp-stoic`         | `$DOTFILES_ALIAS_ROOT/bin/dhp-stoic.sh`          | Stoic philosophy / mindset coach                       |
| `dhp-research`      | `$DOTFILES_ALIAS_ROOT/bin/dhp-research.sh`       | Deep research & fact-finding                           |
| `dhp-narrative`     | `$DOTFILES_ALIAS_ROOT/bin/dhp-narrative.sh`      | Storytelling & narrative design                        |
| `dhp-copy`          | `$DOTFILES_ALIAS_ROOT/bin/dhp-copy.sh`           | Copywriting (ads, emails, etc.)                        |
| `dhp-finance`       | `$DOTFILES_ALIAS_ROOT/bin/dhp-finance.sh`        | Financial analysis & advice                            |
| `dhp-memory`        | `$DOTFILES_ALIAS_ROOT/bin/dhp-memory.sh`         | Store memories to knowledge base                       |
| `dhp-memory-search` | `$DOTFILES_ALIAS_ROOT/bin/dhp-memory-search.sh`  | Search stored memories                                 |
| `tech`              | `$DOTFILES_ALIAS_ROOT/bin/dhp-tech.sh`           |                                                        |
| `creative`          | `$DOTFILES_ALIAS_ROOT/bin/dhp-creative.sh`       |                                                        |
| `content`           | `$DOTFILES_ALIAS_ROOT/bin/dhp-content.sh`        |                                                        |
| `strategy`          | `$DOTFILES_ALIAS_ROOT/bin/dhp-strategy.sh`       |                                                        |
| `brand`             | `$DOTFILES_ALIAS_ROOT/bin/dhp-brand.sh`          |                                                        |
| `market`            | `$DOTFILES_ALIAS_ROOT/bin/dhp-market.sh`         |                                                        |
| `stoic`             | `$DOTFILES_ALIAS_ROOT/bin/dhp-stoic.sh`          |                                                        |
| `research`          | `$DOTFILES_ALIAS_ROOT/bin/dhp-research.sh`       |                                                        |
| `narrative`         | `$DOTFILES_ALIAS_ROOT/bin/dhp-narrative.sh`      |                                                        |
| `aicopy`            | `$DOTFILES_ALIAS_ROOT/bin/dhp-copy.sh`           | 'aicopy' not 'copy' (copy = pbcopy)                    |
| `morphling`         | `$DOTFILES_ALIAS_ROOT/bin/morphling.sh`          | Shape-shifting multi-persona dispatcher                |
| `finance`           | `$DOTFILES_ALIAS_ROOT/bin/dhp-finance.sh`        |                                                        |
| `memory`            | `$DOTFILES_ALIAS_ROOT/bin/dhp-memory.sh`         |                                                        |
| `memory-search`     | `$DOTFILES_ALIAS_ROOT/bin/dhp-memory-search.sh`  |                                                        |
| `dhp-morphling`     | `$DOTFILES_ALIAS_ROOT/bin/dhp-morphling.sh`      |                                                        |
| `dhp`               | `$DOTFILES_ALIAS_ROOT/bin/dhp-tech.sh`           | Default dispatcher → tech                              |
| `dispatch`          | `$DOTFILES_ALIAS_ROOT/bin/dispatch.sh`           | Generic dispatch router                                |
| `dhp-project`       | `$DOTFILES_ALIAS_ROOT/bin/dhp-project.sh`        | Multi-specialist project orchestration                 |
| `ai-project`        | `$DOTFILES_ALIAS_ROOT/bin/dhp-project.sh`        | Shorthand for dhp-project                              |
| `dhp-chain`         | `$DOTFILES_ALIAS_ROOT/bin/dhp-chain.sh`          | Chain dispatchers sequentially (pipe output)           |
| `ai-chain`          | `$DOTFILES_ALIAS_ROOT/bin/dhp-chain.sh`          | Shorthand for dhp-chain                                |
| `ai-suggest`        | `ai_suggest.sh`                                  | Context-aware AI suggestions for current task          |
| `ai-context`        | `source $DOTFILES_ALIAS_ROOT/bin/dhp-context.sh` | Load context-gathering helpers (sourced, not executed) |
| `swipe`             | `$DOTFILES_ALIAS_ROOT/bin/swipe.sh`              |                                                        |

### ACCESSIBILITY & ERGONOMICS

| Alias        | Target Command                                    | Description                          |
| ------------ | ------------------------------------------------- | ------------------------------------ |
| `G` (Global) | `\| grep -i`                                      | Case-insensitive grep filter         |
| `C` (Global) | `\| pbcopy`                                       | Pipe output to clipboard             |
| `L` (Global) | `\| less`                                         | Pipe output to pager                 |
| `H` (Global) | `\| head -n 10`                                   | Show first 10 lines only             |
| `N` (Global) | `> /dev/null 2>&1`                                | Silence all output (stdout + stderr) |
| `cd..`       | `cd ..`                                           | Missing space                        |
| `ls-l`       | `ls -l`                                           | Hyphen instead of space              |
| `sl`         | `ls`                                              | Transposed letters                   |
| `dc`         | `cd`                                              | Transposed letters                   |
| `gut`        | `git`                                             | Transposed letters                   |
| `gti`        | `git`                                             | Transposed letters                   |
| `pwd`        | `pwd`                                             | Already correct (harmless)           |
| `pdw`        | `pwd`                                             | Transposed letters                   |
| `vmi`        | `vim`                                             | Transposed letters                   |
| `hh`         | `history`                                         | Shell history                        |
| `xx`         | `exit`                                            | Exit terminal                        |
| `qq`         | `exit`                                            | Exit terminal (vim-inspired)         |
| `b`          | `cd -`                                            | Bounce back to previous directory    |
| `doneit`     | `git add . && git commit -m 'update' && git push` | Quick ship it                        |
| `gwip`       | `git add . && git commit -m 'wip'`                | Save work-in-progress                |
| `gup`        | `git pull --rebase`                               | Pull with rebase (cleaner history)   |
| `md`         | `mkdir -p`                                        | Make directory (with parents)        |
| `cx`         | `chmod +x`                                        | Make file executable                 |
| `ez`         | `code \$DOTFILES_ALIAS_ROOT/zsh/aliases.zsh`      | Edit this aliases file in VS Code    |
| `ezrc`       | `code ~/.zshrc`                                   | Edit .zshrc in VS Code               |
| `reload`     | `source ~/.zshrc && echo 'Zsh reloaded!'`         | Apply config changes instantly       |

### SPEC-DRIVEN DISPATCHER WORKFLOW

| Alias | Target Command | Description |
| ----- | -------------- | ----------- |

---

## 📜 Comprehensive Scripts Reference

The following are detailed usage instructions, descriptions, and examples extracted directly from the source code of the scripts in `~/dotfiles/scripts/`.

### `ai_suggest.sh`

**Usage & Examples:**

```text
  • Debug code: cat script.sh | tech
  • Generate ideas: echo \
  • Get insights: journal analyze
  • Full project planning: dhp-project \
  • Content creation: blog generate <stub>
  • Strategic analysis: echo \
  • Stoic guidance: echo \
  • Knowledge synthesis: cat notes.md | research
  $suggestion
```

### `app_launcher.sh`

**Description:** app_launcher.sh - macOS application launcher with favorites

**Usage & Examples:**

```text
Usage: app_launcher.sh add <shortname> <app_name>
Usage:
  app add <n> <app_name>  : Add favorite app
  app list                  : List favorites
  app <n>                : Launch favorite app
Example: app_launcher.sh add code
```

### `archive_manager.sh`

**Description:** archive_manager.sh - Archive management utilities

**Usage & Examples:**

```text
Usage: archive_manager.sh create <archive_name> <files/folders...>
Usage: archive_manager.sh extract <archive_file>
Usage: archive_manager.sh list <archive_file>
Usage: archive_manager.sh {create|extract|list}
  create <archive> <files>  : Create new archive
  extract <archive>         : Extract archive
  list <archive>           : List archive contents
```

### `backup_project.sh`

**Description:** backup_project.sh - Creates incremental backups using rsync

### `battery_check.sh`

**Description:** battery_check.sh - macOS battery monitoring with suggestions

### `blog.sh`

**Description:** blog.sh - Tools for managing the blog content workflow. Modularized refactor

**Usage & Examples:**

```text
Usage: blog hooks install
Usage: blog <command> [args]
  status       Show system status
  stubs        List content stubs
  random       Open a random content stub
  recent       List recently modified posts
  ideas        Manage ideas (list|add|sync)
  version      Manage version (show|bump|history)
  metrics      Show blog statistics
  draft        Create a new draft (alias for scaffolder)
  generate     Generate content with AI
  refine       Refine content with AI
  workflow     Run full draft->outline->content workflow
  social       Generate social media content
  exemplar     View section exemplar
  publish      Validate and prepare for deploy
  validate     Run local validation
  hooks        Install git hooks
  blog g / blog generate [options] \
  blog r / blog refine <file-path>          - Polish and improve existing content
  blog d / blog draft <type> <slug>         - Scaffold a new draft from archetypes
  blog w / blog workflow <type> <slug> [--title --topic]
  blog p / blog publish                    - Validate, build, and summarize site status
```

### `blog_recent_content.sh`

**Description:** blog_recent_content.sh - show latest Hugo content activity

### `cheatsheet.sh`

**Description:** Add any commands or notes you tend to forget.

**Usage & Examples:**

```text
  git pull                # Get latest changes
  git add .               # Stage all changes
  git commit -m
  git push                # Send changes to remote
  zip -r archive_name.zip /path/to/folder
  df -h
  brew update             # Update Homebrew
  brew upgrade            # Upgrade packages
  brew search <package>   # Search for packages
  brew install <package>  # Install package
  python3 -m venv venv    # Create virtual environment
  source venv/bin/activate # Activate environment
  pip install <package>   # Install package in venv
  deactivate              # Exit virtual environment
  open .                  # Open current directory in Finder
  pbcopy < file.txt       # Copy file contents to clipboard
  pbpaste > file.txt      # Paste clipboard to file
  mdfind
  startday                # Morning routine (auto-runs once/day)
  status                  # Show current context dashboard
  goodevening             # Run end-of-day summary
  journal
  todo add
  todo list               # Show current tasks
  todo done <num>         # Mark task as complete
  insight new
  insight weekly          # Show weekly insight KPIs
  context.sh capture [name] # Snapshot current context
  context.sh list           # List saved contexts
  context.sh restore <name> # Restore instructions
  health add
  health list             # Show upcoming appointments
  weekreview              # Show last 7 days activity
  graballtext             # Dump all readable text into all_text_contents.txt
  projects forgotten      # List old projects
  projects recall <name>  # Show details of an old project
  blog status             # Show blog status
  blog stubs              # List blog posts that are stubs
  NEW: Spec-Driven Workflow (Structured Templates):
    spec tech                    # Open tech debugging template
    dispatch tech \
    spec creative                # Open creative writing template
    spec content                 # Open content creation template
    spec strategy                # Open strategic analysis template
    spec market                  # Open market research template
    spec research                # Open knowledge synthesis template
    spec stoic                   # Open stoic coaching template
    # Fill template → save → auto-pipes to dispatcher → archived
  Quick Direct Access (Traditional):
    cat script.sh | tech         # Debug code
    cat script.sh | tech --stream  # Debug with real-time streaming
    creative
    creative --stream
    narrative
    aicopy
    <input> | strategy           # Strategic analysis
    <input> | brand              # Brand positioning
    <input> | market             # Market research
    finance \
    <challenge> | stoic          # Stoic coaching
    <research> | research        # Knowledge synthesis
    morphling                   # Interactive Morphling (works in any directory)
    morphling \
    dhp-morphling \
  Workflow Integrations:
    blog generate <stub>         # AI-generate content from stub
    blog refine <file>           # AI-polish existing content
    todo debug <num>             # AI-debug a task
    todo delegate <num> <type>   # Delegate to AI specialist
    journal analyze              # AI insights (7 days)
    journal mood                 # AI sentiment analysis (14 days)
    journal themes               # AI theme extraction (30 days)
  Advanced Features:
    ai-suggest                   # Context-aware dispatcher suggestions
    dhp-project
    dhp-chain creative narrative copy --
  Setup: cp .env.example .env && add your OPENROUTER_API_KEY
  Models: Defaults are set in .env; fallback is moonshotai/kimi-k2:free
  Docs: ~/dotfiles/bin/README.md for full dispatcher documentation
  All data stored in: ~/.config/dotfiles-data/
  - journal.txt, todo.txt, todo_done.txt, health.txt
  - dir_bookmarks, dir_history, favorite_apps
  Read the Daily Happy Path Guide:
  cat ~/dotfiles/docs/happy-path.md
  (Step-by-step workflow for brain fog days)
```

### `clipboard_manager.sh`

**Description:** clipboard_manager.sh - Enhanced clipboard management for macOS

**Usage & Examples:**

```text
Usage:
  clip save [name]  : Save current clipboard
  clip load <name>  : Load clip to clipboard
  clip list         : Show all saved clips
  clip peek         : Show current clipboard content
Usage:
  clip save [n]  : Save current clipboard
  clip load <n>  : Load clip to clipboard
  clip list         : Show all saved clips
  clip peek         : Show current clipboard content
```

### `context.sh`

**Description:** context.sh - Capture and restore working context snapshots

**Usage & Examples:**

```text
  Captured: $(cat
  Directory: $(cat
```

### `correlate.sh`

**Description:** scripts/correlate.sh CLI Wrapper for Correlation Engine

**Usage & Examples:**

```text
Usage: $(basename
  run <file1> <file2> [d1] [v1] [d2] [v2]
       Calculate correlation between two datasets.
       d1/v1: Date/Value column index for file 1 (0-based)
       d2/v2: Date/Value column index for file 2 (0-based)
  find-patterns <file> [d] [v]
       Find recurring patterns in a single dataset.
  explain <r|file>
       Explain a correlation coefficient (r) or read it from a file.
Usage: $(basename
```

### `data_validate.sh`

**Usage & Examples:**

```text
Usage: $(basename
  --fix     Automatically fix insecure file permissions (chmod 600)
  --format  Validate file formats against canonical pipe-delimited rules
  ⚠️  WARNING: Unable to determine permissions for $path
  ⚠️  WARNING: Sensitive file ($item) has insecure permissions ($CURRENT_PERMS). Auto-fixing...
  ❌ ERROR: Failed to auto-fix permissions for $path
  ⚠️  WARNING: Sensitive file ($item) has insecure permissions ($CURRENT_PERMS). Should be 600.
```

### `dev_shortcuts.sh`

**Description:** dev_shortcuts.sh - Development workflow shortcuts for macOS

**Usage & Examples:**

```text
Usage: dev_shortcuts.sh {server|json|env|gitquick}
  server [port]     : Start development server (default port 8000)
  json [file]       : Pretty print JSON (from clipboard or file)
  env               : Create Python virtual environment (venv)
  gitquick <msg>    : Quick git add, commit, push
Usage: dev_shortcuts.sh gitquick <commit_message>
```

### `done.sh`

**Description:** done.sh - Run commands with completion notifications

**Usage & Examples:**

```text
Usage: done.sh <your_command_here>
  done.sh sleep 10
  done.sh rsync -avh /source /dest
  done.sh sleep 10
  done.sh rsync -avh /source /dest
```

### `dotfiles_check.sh`

**Usage & Examples:**

```text
  ❌ ERROR: Script is not executable: $script_name
  ❌ ERROR: Scripts directory not found at $SCRIPT_DIR
  ❌ ERROR: Data directory not found at $DATA_DIR
  ❌ ERROR: Command not found in PATH: $cmd
  ⚠️  WARNING: GitHub token not found at $PRIMARY_GITHUB_TOKEN_FILE (or fallback $FALLBACK_GITHUB_TOKEN_FILE). Some features like project listing will fail.
  ⚠️  WARNING: Staff directory not found at $STAFF_DIR. Skipping dispatcher check.
  ⚠️  WARNING: Missing dispatcher for
  ❌ ERROR: Dispatcher not executable: dhp-${slug}.sh
  ❌ ERROR: Docs index missing at $DOCS_INDEX
  ⚠️  WARNING: Missing doc: $doc_path
  ⚠️  WARNING: Docs archive index missing at $ARCHIVE_INDEX
  ❌ ERROR: .env validation failed (run validate_env.sh for details)
  ⚠️  WARNING: validate_env.sh missing or not executable
  Errors:   $ERROR_COUNT
  Warnings: $WARNING_COUNT
```

### `duplicate_finder.sh`

**Description:** duplicate_finder.sh - Find duplicate files on macOS

### `file_organizer.sh`

**Description:** file_organizer.sh - Organize files by type, date, or size

**Usage & Examples:**

```text
  Would move $file to Documents/
  Moved $file to Documents/
  Would move $file to Images/
  Moved $file to Images/
  Would move $file to Audio/
  Moved $file to Audio/
  Would move $file to Video/
  Moved $file to Video/
  Would move $file to Archives/
  Moved $file to Archives/
  Would move $file to Code/
  Moved $file to Code/
  Would move $file to $YEAR/$MONTH/
  Moved $file to $YEAR/$MONTH/
  Would move $file to Small (< 1MB)/
  Moved $file to Small/
  Would move $file to Medium (1-10MB)/
  Moved $file to Medium/
  Would move $file to Large (10-100MB)/
  Moved $file to Large/
  Would move $file to XLarge (> 100MB)/
  Moved $file to XLarge/
Usage: file_organizer.sh {bytype|bydate|bysize} [--dry-run|-n]
  bytype  : Organize files by file type
  bydate  : Organize files by creation date
  bysize  : Organize files by size
```

### `findbig.sh`

**Description:** findbig.sh - Find the 10 largest files/folders in the current directory

### `findtext.sh`

**Description:** findtext.sh - A user-friendly wrapper for grep to find text in files

### `focus.sh`

**Usage & Examples:**

```text
Usage: focus <command> [args]
  (no args)        Show current focus
  set \
  done             Mark focus as complete and archive to history
  history          Show focus history
  clear            Clear current focus (without archiving)
Usage: focus set \
```

### `g.sh`

**Description:** g.sh - Consolidated navigation and state management script IMPORTANT: This script is SOURCED, not executed. Must use 'return' not 'exit' to avoid killing the parent shell

**Usage & Examples:**

```text
Usage: g save <bookmark_name> [-a app1,app2] [on-enter-command]
  ✗ Removed: $name -> $dir (directory not found)
  Dead bookmark found: $name -> $dir
  ✗ Removed: $name
  Kept: $name
  (Note: Configure favorite apps with
```

### `gcal.sh`

**Description:** gcal.sh - Pure Bash Google Calendar Client Uses OAuth 2.0 Device Flow to authenticate without a browser callback or Python. Dependencies: curl, jq

**Usage & Examples:**

```text
Usage: $(basename
  auth                       Authenticate with Google (Interactive)
  agenda [days]              Show agenda for next N days (default: 1)
  add \
  list                       List all calendars
  (No events found)
Usage: calendar add \
   Link: $LINK
```

### `generate_report.sh`

**Description:** scripts/generate_report.sh Generates daily/weekly summaries and correlations

### `gh-projects.sh`

**Description:** gh-projects.sh - Find and recall forgotten projects from GitHub.

**Usage & Examples:**

```text
  • $repo_name ($DAYS_AGO days ago)
Usage: projects recall <project_name>
Usage: projects {forgotten|recall <name>}
```

### `github_helper.sh`

**Description:** github_helper.sh - Functions for interacting with the GitHub API

**Usage & Examples:**

```text
Usage: list_commits_for_date YYYY-MM-DD
Usage: list_commits_for_date YYYY-MM-DD
Usage: github_helper.sh get_repo <repo>
Usage: github_helper.sh get_latest_commit <repo>
Usage: github_helper.sh get_readme_content <repo>
Usage: github_helper.sh list_commits_for_date YYYY-MM-DD
Usage: github_helper.sh {list_repos|get_repo <repo>|get_latest_commit <repo>|get_readme_content <repo>|list_user_events|list_commits_for_date YYYY-MM-DD}
```

### `goodevening.sh`

**Usage & Examples:**

```text
  $(cat
  (No focus set)
  (No tasks completed today)
  (No journal entries for today)
  Total: $(format_duration
  (No time tracked today)
  (No time log found)
  (Time tracking library not found)
  (No recent pushes)
  (Unable to fetch GitHub activity. Check your token or network.)
  (GitHub operations library not loaded)
  Yesterday ($YESTERDAY):
  (Unable to fetch commit activity. Check your token or network.)
  Today ($TODAY):
  (No commits yet today)
  (Unable to fetch commit activity. Check your token or network.)
  (GitHub operations library not loaded)
  🎉 Win: You completed $TASKS_COMPLETED task(s) today. Progress is progress.
  🧠 Win: You logged $JOURNAL_ENTRY_COUNT entries. Context captured.
  🧘 Today was a rest day. Logging off is a valid and productive choice.
  ⚠️  $proj_name: $change_count uncommitted changes
      └─ Large diff: +$additions/-$deletions lines
      └─ Could not determine current branch. Is this a valid git repository?
  ⚠️  $proj_name: On branch
      └─ Branch not pushed to remote
      └─ Failed to check remote status: $remote_check
  ⚠️  $proj_name: Failed to check unpushed commits: $unpushed
  📤 $proj_name: $unpushed unpushed commit(s) on $current_branch
  ✅ All projects clean (no uncommitted changes, stale branches, or unpushed commits)
  (Projects directory not found)
  ⚠️ Blog status unavailable (check BLOG_STATUS_DIR or BLOG_DIR configuration).
  ⚠️ Unable to list recent content (check BLOG_CONTENT_DIR).
  (Old completed tasks removed)
  ✅ Data validation passed.
  ⚠️  WARNING: Backup failed: $backup_output
  ❌ ERROR: Data validation failed. Skipping backup.
```

### `health.sh`

**Description:** health.sh - Track health appointments, symptoms, and energy levels

**Usage & Examples:**

```text
  - Avg tasks on low energy days: N/A (no todo data)
  - Avg tasks on high energy days: N/A (no todo data)
  (Regenerating git commit cache...)
  - Avg commits on low energy days: N/A (no Projects dir)
  - Avg commits on high energy days: N/A (no Projects dir)
  - Avg commits on low energy days: N/A (cache failed)
  - Avg commits on high energy days: N/A (cache failed)
Usage: $(basename
Usage: $(basename
Usage: $(basename
  • $desc - $appt_date (Today)
  • $desc - $appt_date (Tomorrow)
  • $desc - $appt_date (in $days_until days)
  (No appointments tracked)
  (No energy data logged)
  (No symptoms logged)
Usage: $(basename
Usage: $(basename
Usage: $(basename
   Action: STOP high-cognitive tasks.
   Recommendation: Rest, active recovery, or Low Energy Menu items.
   Action: EXTEND deadlines by 24h.
   Recommendation: No strategic decisions. Admin/Rote work only.
   Energy: ${last_energy:-N/A}/10 | Fog: ${last_fog:-N/A}/10
Usage: $(basename
```

### `howto.sh`

**Usage & Examples:**

```text
Usage: howto add <name>
Usage: howto search <term>
```

### `insight.sh`

**Description:** insight.sh - Falsification-first hypothesis workflow Create hypotheses, plan disconfirming tests, collect evidence, and produce verdicts with gate checks that prioritize disproof over belief. Usage: insight.sh <command> [options] Commands: new <claim> Create a new hypothesis test-plan <hyp_id> Add a disconfirming test plan test-result <test_id> Mark a test as attempted/completed evidence add <hyp_id> Add evidence for a hypothesis verdict <hyp_id> Generate/store a verdict with gate checks weekly [--low-spoons] Weekly KPI summary

**Usage & Examples:**

```text
Usage: $(basename
  new <claim> [--domain <name>] [--novelty <1-5>] [--prior <0-1>] [--next-test <text>]
  test-plan <hyp_id> [--prediction <text>] [--fail-criterion <text>]
  test-result <test_id> --status <attempted|passed|failed|inconclusive> --result <text>
  evidence add <hyp_id> --direction <for|against|neutral> --strength <1-5> --source <text> [--provenance <text>] [--note <text>]
  verdict <hyp_id> [--verdict <supported|falsified|inconclusive>] [--confidence <0-1>] [--why <text>] [--counterargument <text>] [--response <text>]
  weekly [--low-spoons]
  $(basename
  $(basename
  $(basename
  $(basename
Usage: $(basename
Usage: $(basename
Usage: $(basename
Usage: $(basename
Usage: $(basename
Usage: $(basename
```

### `journal.sh`

**Usage & Examples:**

```text
Usage: $(basename
Usage: $(basename
Usage: $(basename
   or: $(basename
  journal <text>              : Add a quick journal entry
  up                          : Open journal file in editor
  list                        : Show last 5 entries
  search [--recent] <term>    : Search for a term in journal
  onthisday                   : Show entries from this day in past years
  analyze                     : AI analysis of last 7 days (insights & patterns)
  mood                        : AI sentiment analysis of last 14 days
  themes                      : AI theme extraction from last 30 days
```

### `logs.sh`

**Description:** logs.sh - View and search dotfiles system logs

**Usage & Examples:**

```text
Usage: logs.sh search <term>
  Size: ${size_human}KB
  Total entries: $(wc -l <
  Errors: $(grep -c
  Warnings: $(grep -c
  Info: $(grep -c
  Total API calls: $(wc -l <
```

### `media_converter.sh`

**Description:** media_converter.sh - Media file conversion utilities for macOS

**Usage & Examples:**

```text
Usage: media_converter.sh video2audio <video_file>
Usage: media_converter.sh resize_image <image_file> <width>
Usage: media_converter.sh pdf_compress <pdf_file>
Usage: media_converter.sh audio_stitch [directory]
       media_converter.sh audio_stitch <output_file> <input_file1> <input_file2> ...
Usage: media_converter.sh {video2audio|resize_image|pdf_compress|audio_stitch}
  video2audio <file>      : Extract audio from video
  resize_image <file> <w> : Resize image to specified width
  pdf_compress <file>     : Compress PDF file
  audio_stitch [dir]      : Stitch audio files in dir (default: current)
  audio_stitch <out> <in...>: Stitch specific files
Requires: ffmpeg (install with: brew install ffmpeg)
Example: media_converter.sh resize_image photo.jpg 800
Requires: ImageMagick (install with: brew install imagemagick)
Requires: Ghostscript (install with: brew install ghostscript)
       media_converter.sh audio_stitch <output_file> <input_file1> <input_file2> ...
```

### `meds.sh`

**Description:** meds.sh - Medication tracking and reminder system

**Usage & Examples:**

```text
Usage: meds add \
Usage: meds refill \
Usage: meds log \
  • $med_name - Schedule: $schedule
  (No doses logged)
  ⚠️  $med_name ($time_slot) - NOT TAKEN YET
  ✅ $med_name ($time_slot) - taken
  ✅ All scheduled medications taken for now
  ⚠️  REFILL OVERDUE: $med_name (was due $refill_date)
  ⚠️  Refill due soon: $med_name (in $days_left days, on $refill_date)
Usage: meds remove \
Usage: meds [add|refill|log|list|check|check-refill|history|dashboard|remove|remind]
  meds add \
    Schedule examples: \
  meds check              # Check what needs to be taken
  meds log \
  meds list               # Show all medications & recent doses
  meds history [med] [days]   # Show dose history
  meds dashboard          # Show 30-day adherence dashboard
  meds remove \
  meds remind             # Check & send notifications (for cron)
Example: meds add \
Example: meds refill \
```

### `migrate_data.sh`

**Description:** migrate_data.sh - Migrate dotfiles data files to pipe-delimited canonical formats

### `mkproject_py.sh`

**Description:** mkproject_py.sh - Sets up a complete Python project with virtual environment

### `my_progress.sh`

**Description:** my_progress.sh - Shows your recent Git commits

### `network_info.sh`

**Description:** network_info.sh - Network diagnostics for macOS

**Usage & Examples:**

```text
Usage: network_info.sh {status|scan|speed|fix}
  status : Show current network information
  scan   : Scan for available Wi-Fi networks
  speed  : Test network speed
  fix    : Reset network settings
```

### `new_script.sh`

**Usage & Examples:**

```text
Usage: new_script.sh <script_name> [--force]
  --force    Override name collision warnings
Example: new_script.sh my_tool
```

### `open_file.sh`

**Description:** open_file.sh - Find and open files with fuzzy matching (macOS optimized)

**Usage & Examples:**

```text
Usage: open_file.sh <partial_filename>
Example: open_file.sh budget    (might find
```

### `process_manager.sh`

**Description:** process_manager.sh - Find and manage processes on macOS

**Usage & Examples:**

```text
Usage: process_manager.sh find <process_name>
Usage: process_manager.sh kill <process_name>
Usage: process_manager.sh {find|top|memory|kill} [process_name]
  find <name>   : Find processes by name
  top           : Show top CPU users
  memory        : Show top memory users
  kill <name>   : Safely kill processes by name
```

### `remind_me.sh`

**Description:** remind_me.sh - Simple reminder system using macOS notifications

**Usage & Examples:**

```text
Usage: remind_me.sh <time> <reminder_message>
  remind_me.sh
  remind_me.sh
  remind_me.sh
  remind_me.sh
  remind_me.sh
  remind_me.sh
```

### `review_clutter.sh`

**Usage & Examples:**

```text
  Would archive $file to $ARCHIVE_DIR
  Would delete $file
```

### `schedule.sh`

**Usage & Examples:**

```text
Usage: schedule.sh \
Example: schedule.sh \
```

### `spec_helper.sh`

**Description:** Spec helper for structured dispatcher inputs NOTE: SOURCED file. Do NOT use set -euo pipefail.

**Usage & Examples:**

```text
Usage: spec <dispatcher>
```

### `spoon_manager.sh`

**Description:** scripts/spoon_manager.sh CLI Wrapper for Spoon Theory budget tracking Log Format (spoons.txt): BUDGET|YYYY-MM-DD|count SPEND|YYYY-MM-DD|HH:MM|count|activity|remaining

**Usage & Examples:**

```text
Usage: $(basename
  init <count>                   Initialize daily spoons (default: 10)
  set <count>                    Update today
  spend <count> [activity]       Spend spoons on an activity
  check                          Show remaining spoons
  history [days]                 Show spoon history (default: 7 days)
Usage: $(basename
```

### `start_project.sh`

**Description:** start_project.sh - Creates a standard project directory structure

### `startday.sh`

**Description:** startday.sh - Enhanced morning routine

**Usage & Examples:**

```text
   Focus set to: $new_focus
  You have $remaining spoons remaining today.
  Invalid input, defaulting to 10.
  (Non-interactive mode: defaulting to 10)
  Invalid input, defaulting to 10.
  (Spoon manager not found)
  (No entries for $yesterday)
  (Journal file not found)
  • Last week
  (No recent pushes)
  (Unable to fetch GitHub activity. Check your token or network.)
  (GitHub operations library not loaded)
  (No commits for $yesterday_date)
  (Unable to fetch commit activity. Check your token or network.)
  (GitHub operations library not loaded)
  (No suggestions available)
  ⚠️ Blog status unavailable (check BLOG_STATUS_DIR or BLOG_DIR configuration).
  ⚠️ Unable to list recent content (check BLOG_CONTENT_DIR).
  (Health operations library not loaded)
  (Authentication required. Run
  (calendar script not found)
  (No background jobs)
  (at command not available)
  (todo.sh not found)
  (Cached from this morning)
```

### `status.sh`

**Description:** status.sh - Provides a mid-day context recovery dashboard.

**Usage & Examples:**

```text
  $(cat
  (No focus set)
  • Current directory: $CURRENT_DIR
  • Context snapshots: $CONTEXT_COUNT (context.sh list)
  • Current git branch: $GIT_BRANCH
  • Last journal entry: $LAST_ENTRY
  (No entries for today yet)
  • Project: $PROJECT_NAME
  • Last commit: $LAST_COMMIT
  (Not in a project directory under $PROJECTS_DIR)
  (No commits yet today)
  (Unable to fetch commit activity)
  (GitHub operations library not loaded)
   (Skipped: must be 1-10)
   (Skipped: must be 1-10)
  (todo.sh not found)
```

### `system_info.sh`

**Description:** system_info.sh - Quick system overview for macOS

### `take_a_break.sh`

**Description:** take_a_break.sh - Health-focused break timer with macOS notifications

**Notes:**

- Runs as a single active timer (prevents overlapping break notifications).
- Use `take_a_break.sh --status` to check if a timer is active.
- Use `take_a_break.sh --stop` to cancel the active timer.

**Usage & Examples:**

```text
take_a_break.sh
take_a_break.sh 25
take_a_break.sh --status
take_a_break.sh --stop
```

### `text_processor.sh`

**Description:** text_processor.sh - Text file processing utilities

**Usage & Examples:**

```text
Usage: text_processor.sh count <file>
Usage: text_processor.sh search <pattern> <file>
Usage: text_processor.sh replace <old_text> <new_text> <file>
Usage: text_processor.sh clean <file>
Usage: text_processor.sh {count|search|replace|clean}
  count <file>                    : Count lines, words, characters
  search <pattern> <file>         : Search for text pattern
  replace <old> <new> <file>      : Replace text (creates backup)
  clean <file>                    : Remove extra whitespace
```

### `tidy_downloads.sh`

**Description:** tidy_downloads.sh - macOS version with proper directory handling

**Usage & Examples:**

```text
  Skipped: $img (recently modified or in ignore list)
  Would move $img to ~/Pictures/
  Moved: $img
  Skipped: $doc (recently modified or in ignore list)
  Would move $doc to ~/Documents/
  Moved: $doc
  Skipped: $media (recently modified or in ignore list)
  Would move $media to ~/Music/
  Moved: $media
  Skipped: $archive (recently modified or in ignore list)
  Would move $archive to ~/Documents/Archives/
  Moved: $archive
```

### `time_tracker.sh`

**Description:** scripts/time_tracker.sh CLI Wrapper for time tracking functionality Log Format (time_tracking.txt): START|task_id|description|timestamp (YYYY-MM-DD HH:MM:SS) STOP|task_id|timestamp (YYYY-MM-DD HH:MM:SS)

**Usage & Examples:**

```text
Usage: $(basename
  start <task_id> [description]  Start timer for a task
  stop [task_id]                 Stop the active timer
  status                         Show currently active timer
  report [start end]             Show time usage (YYYY-MM-DD range)
  report --days <n>              Show last N days (default 7)
  report --summary               Show total time only
  check <task_id>                Get total time for a task
Usage: $(basename
```

### `todo.sh`

**Usage & Examples:**

```text
Usage: $(basename
  $(basename
```

### `unpacker.sh`

**Description:** unpacker.sh - Extracts any common archive type

**Usage & Examples:**

```text
Usage: unpacker.sh <filename>
```

### `validate_env.sh`

**Description:** validate_env.sh - Validates essential environment variables and configurations

**Usage & Examples:**

```text
  ❌ .env file not found at $ENV_FILE. Please create one from .env.example.
  ❌ OPENROUTER_API_KEY is not set in .env. AI dispatchers will not function.
  ✅ OPENROUTER_API_KEY is set.
  ⚠️  Warning: OPENROUTER_API_KEY does not start with
  ⚠️  Warning: GITHUB_USERNAME is not set in .env. GitHub scripts may use
  ✅ GITHUB_USERNAME is set.
  ✅ BLOG_DIR is set: $BLOG_DIR
  ❌ BLOG_DIR ($BLOG_DIR) does not exist or is not a directory.
  ✅ BLOG_DIR ($BLOG_DIR) exists.
  ℹ️  BLOG_DIR is not set. Blog workflows will be disabled.
  ℹ️  STALE_TASK_DAYS is not set. Defaulting to 7 days.
  ❌ STALE_TASK_DAYS (
  ✅ STALE_TASK_DAYS is set to $STALE_TASK_DAYS.
  ℹ️  MAX_SUGGESTIONS is not set. Defaulting to 10.
  ❌ MAX_SUGGESTIONS (
  ✅ MAX_SUGGESTIONS is set to $MAX_SUGGESTIONS.
  ℹ️  REVIEW_LOOKBACK_DAYS is not set. Defaulting to 7 days.
  ❌ REVIEW_LOOKBACK_DAYS (
  ✅ REVIEW_LOOKBACK_DAYS is set to $REVIEW_LOOKBACK_DAYS.
  ℹ️  AI_BRIEFING_ENABLED is not set. Defaulting to false.
  ❌ AI_BRIEFING_ENABLED (
  ✅ AI_BRIEFING_ENABLED is set to $AI_BRIEFING_ENABLED.
  ℹ️  AI_REFLECTION_ENABLED is not set. Defaulting to false.
  ❌ AI_REFLECTION_ENABLED (
  ✅ AI_REFLECTION_ENABLED is set to $AI_REFLECTION_ENABLED.
```

### `weather.sh`

**Description:** It uses the website wttr.in, which is designed for terminals. Usage: ./weather.sh [city] Example: ./weather.sh "New York"

### `week_in_review.sh`

**Description:** week_in_review.sh - Generates a report of your activity over the last week

### `whatis.sh`

**Usage & Examples:**

```text
Usage: whatis <command_or_alias>
```
