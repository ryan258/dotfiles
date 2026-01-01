# 🔍 Discover What You Have
## A Use-Case Guide to Your Dotfiles Superpowers

**Built for brain-fog days.** Everything here is designed to minimize keystrokes and cognitive load.

---

## 📋 Table of Contents

- [Daily Essentials](#daily-essentials) - Your everyday toolkit
- [When You're Feeling Overwhelmed](#when-youre-feeling-overwhelmed) - Low-energy helpers
- [Managing Your Health](#managing-your-health) - MS-specific tracking
- [Getting Things Done](#getting-things-done) - Task management
- [Capturing Ideas](#capturing-ideas) - Journaling and notes
- [Finding Stuff Fast](#finding-stuff-fast) - Search and navigation
- [AI Assistants](#ai-assistants) - Your 10 AI helpers
- [Working on Projects](#working-on-projects) - Development workflows
- [Publishing Content](#publishing-content) - Blog and writing
- [System Maintenance](#system-maintenance) - Keep things tidy
- [Quick Wins](#quick-wins) - One-command solutions

---

## Daily Essentials

### Your Morning Routine
```bash
startday
```
**What it does:**
- Shows your focus for today
- Yesterday's journal context
- GitHub projects you worked on recently
- Suggests directories you might want to visit
- Blog status (if you're writing)
- Health reminders
- Stale tasks (>7 days old)
- Your top 3 priorities
- Optional AI briefing (if enabled)

**Pro tip:** This runs automatically once per day when you open a new terminal.

---

### Check In During the Day
```bash
status
```
**What it does:**
- Where you are (directory + git status)
- Recent journal entries
- Top 3 tasks

**When to use:** Lost track of what you're doing? Run `status`.

---

### Your Evening Wrap-Up
```bash
goodevening
```
**What it does:**
- Celebrates your wins (completed tasks, journal entries)
- Checks projects for uncommitted changes
- Validates your data
- Auto-backs up everything
- Optional AI reflection (if enabled)

**Pro tip:** Makes a great ritual to close out your workday.

---

## When You're Feeling Overwhelmed

### Set Your Daily Focus
```bash
focus "One thing I'm focusing on today"
focus show    # See current focus
focus clear   # Clear it
```
**What it does:** Keeps you anchored to your main intention for the day.

---

### See What Matters Most
```bash
todo top      # Show top 3 tasks only
todo top 5    # Show top 5
```
**What it does:** Filters out the noise, shows you just the essentials.

---

### Take a Break
```bash
break         # 15-minute break reminder
pomo          # 25-minute Pomodoro timer
```
**What it does:** Reminds you to rest. You'll get a macOS notification when time's up.

---

### Get AI Help with a Stuck Task
```bash
todo debug 1          # AI analyzes task #1
todo delegate 3 tech  # Send task #3 to AI tech specialist
```
**What it does:** Sometimes you just need another perspective. The AI can help break down or solve a task.

---

### Quick Dump Your Thoughts
```bash
dump
```
**What it does:** Opens your editor for free-form journaling. Everything auto-saves to your journal when you close it.

---

## Managing Your Health

### Track Your Energy
```bash
health energy 7           # Rate today 1-10
health dashboard          # See 30-day trends
```
**What it does:** Tracks energy levels and shows patterns. Correlates with task completion and git commits.

---

### Log Symptoms
```bash
health symptom "headache, fatigue"
health symptom "brain fog" --severity 8
```
**What it does:** Tracks symptoms with timestamps. Can show correlations over time.

---

### Medication Tracking
```bash
meds add "Medication Name" "2x daily" "08:00,20:00"
meds log "Med Name"                    # Log a dose
meds check                             # See what's due
meds dashboard                         # 30-day adherence view
```
**What it does:** Never forget if you took your meds. See adherence patterns.

---

### Health Appointments
```bash
health add "Neurology appointment - Dr. Smith" --date 2025-02-15
health list
```
**What it does:** Keeps all health info in one place.

---

### Get Insights
```bash
health summary     # Overview of recent health data
```
**What it does:** Shows trends and correlations you might miss.

---

## Getting Things Done

### Add Tasks Lightning-Fast
```bash
todo "Call doctor"
todo "Review PR #123" "Fix bug in auth"  # Add multiple
```

---

### See Your Tasks
```bash
todo           # All tasks
todo top       # Top 3 only
todo top 5     # Top 5
```

---

### Complete Tasks
```bash
todo done 1         # Mark task #1 complete
todo done 1 2 3     # Complete multiple
```
**Pro tip:** You get encouraging random feedback each time!

---

### Reorganize Priorities
```bash
todo bump 5         # Move task #5 to top
todo bump 5 2       # Move task #5 to position #2
```

---

### Clean Up Old Tasks
```bash
todo clear          # Remove all completed tasks
```

---

### Commit Tasks to Git
```bash
todo commit
```
**What it does:** Saves your todo.txt to git with a timestamped commit. Great backup strategy.

---

### Undo Last Action
```bash
todo undo
```
**What it does:** Undo the last add/done/clear operation.

---

## Capturing Ideas

### Quick Journal Entry
```bash
journal "Had a good insight about the project architecture"
```

---

### Long-Form Journaling
```bash
dump
```
**What it does:** Opens editor for free-writing. Auto-saves to journal when you close.

---

### Search Your Journal
```bash
journal search "architecture"
journal search "doctor" --days 30
```

---

### See Today's Entries
```bash
journal list
journal list 5      # Last 5 entries
```

---

### Memories: On This Day
```bash
journal onthisday
```
**What it does:** Shows what you wrote on this date in previous years.

---

### AI Analysis of Your Journal
```bash
journal analyze     # 7-day insights
journal mood        # 14-day sentiment analysis
journal themes      # 30-day pattern detection
```
**What it does:** Uses AI to find patterns, themes, and insights you might miss.

---

## Finding Stuff Fast

### Navigate to Saved Locations
```bash
g                   # Show all bookmarks
g recent            # Recently visited directories
g suggest           # AI-suggested dirs based on your usage
g dotfiles          # Jump to a bookmark (if saved)
```

---

### Save a Location
```bash
g save myproject    # Save current directory as "myproject"
g save              # Auto-names based on directory name
```
**Pro tip:** Automatically detects Python virtual environments!

---

### Smart Suggestions
```bash
g suggest           # Top 10 suggestions
g suggest 20        # Top 20
```
**What it does:** Analyzes your directory usage: `score = visits / (days_since + 1)`

---

### Find Files
```bash
findtext "search term"
findbig                # 10 largest files/dirs
```

---

### Clean Up Downloads
```bash
tidy
```
**What it does:** Interactive cleanup of your Downloads folder. Super satisfying.

---

## AI Assistants

You have **10 AI specialists** on call. They're all free-tier models, so use them generously.

### 1. Technical Help (`tech`)
```bash
tech "How do I fix this bash error?"
cat broken_script.sh | tech --stream
```
**When to use:** Debugging code, optimizing scripts, understanding errors.
**Model:** DeepSeek R1 (excellent at technical reasoning)

---

### 2. Content Creation (`content`)
```bash
content "Write a guide about managing energy with chronic illness"
echo "topic: productivity with MS" | content --context
```
**When to use:** Blog posts, guides, SEO-optimized content.
**Model:** Qwen3 Coder
**Pro tip:** Use `--context` to include your recent journal and todos.

---

### 3. Creative Writing (`creative`)
```bash
creative "Story idea: a developer learning to work with chronic illness"
```
**When to use:** Stories, creative projects, narrative development.

---

### 4. Marketing Copy (`copy`)
```bash
copy "Email sequence for new blog subscribers"
```
**When to use:** Marketing emails, landing pages, calls-to-action.

---

### 5. Strategic Thinking (`strategy`)
```bash
strategy "Should I focus on technical writing or personal essays?"
```
**When to use:** Big decisions, planning, prioritization.
**Acts as:** Your Chief of Staff.

---

### 6. Brand Development (`brand`)
```bash
brand "Help me define my personal brand as a developer with MS"
```
**When to use:** Positioning, messaging, differentiation.

---

### 7. Market Research (`market`)
```bash
market "What's the audience for MS + productivity content?"
```
**When to use:** Understanding audiences, trends, opportunities.

---

### 8. Stoic Coaching (`stoic`)
```bash
stoic "I'm frustrated with my energy limitations today"
```
**When to use:** Mindset, resilience, perspective on challenges.

---

### 9. Research (`research`)
```bash
research "Summarize recent research on MS and cognitive function"
```
**When to use:** Learning, synthesizing information, deep dives.

---

### 10. Narrative Structure (`narrative`)
```bash
narrative "Analyze this story structure" < draft.md
```
**When to use:** Story development, plot analysis, structure feedback.

---

### Advanced AI Features

**Chain multiple specialists:**
```bash
dhp-chain creative narrative copy -- "story about overcoming limitations"
```

**Full project brief (5 specialists in sequence):**
```bash
dhp-project "Launch a blog series about productivity with chronic illness"
```

**Get AI suggestions based on your current context:**
```bash
ai_suggest
```
**What it does:** Analyzes your current directory, todos, journal, and time of day to recommend relevant AI specialists.

---

## Working on Projects

### Start a New Project
```bash
start-project       # Interactive wizard
mkproject-py        # Python project with venv
```

---

### Track Your Progress
```bash
my-progress         # Recent git commits in current repo
```

---

### Find Forgotten Projects
```bash
projects            # GitHub repos you worked on recently
```

---

### Save Project Workflows
```bash
howto add deploy "How I deploy this project"
howto deploy       # Later: retrieve the instructions
howto search "docker"
```
**What it does:** Your personal wiki for complex workflows you'll forget.

---

## Publishing Content

### Check Blog Status
```bash
blog status         # See drafts, stubs, recent posts
blog stubs          # List all stub files
```

---

### Generate Content
```bash
blog generate "Title: Managing Energy with MS" -p thoughtful-guide -s guides
blog generate "Quick tip: Keyboard shortcuts" -p practical-tip -s blog
```
**Personas:** thoughtful-guide, practical-tip, technical-deep-dive, personal-story
**Sections:** guides, blog, prompts, shortcuts

---

### Refine Existing Draft
```bash
blog refine drafts/my-post.md -p technical-deep-dive
```

---

### Get Content Ideas from Journal
```bash
blog ideas          # Searches journal for potential blog topics
```

---

### Sync Stubs to Tasks
```bash
blog sync           # Creates todo items for each stub
```

---

## System Maintenance

### Check System Health
```bash
dotfiles-check      # Validates everything
```
**What it does:** Checks scripts, dependencies, data directories, GitHub token, AI dispatchers.

---

### Organize Files
```bash
file-org            # Sort by type/date/size
```

---

### Find Duplicates
```bash
dup-find            # Checksum-based duplicate detection
```

---

### Clean Up Old Files
```bash
review-clutter      # Interactive archive/delete
```

---

### Battery Status
```bash
battery             # Check battery health and charging
```

---

### Network Info
```bash
netinfo             # Wi-Fi status, speed test, diagnostics
```

---

### System Info
```bash
sysinfo             # Hardware, CPU, memory, disk
```

---

## Quick Wins

### Copy Text from All Files
```bash
grab-all-text > output.txt
```
**What it does:** Concatenates all readable files (skips git, binaries). Great for AI context.

---

### Get Notified When Command Finishes
```bash
done npm install
done long-running-script.sh
```
**What it does:** Runs the command, sends macOS notification when done.

---

### Schedule a Reminder
```bash
remind +30m "Take medication"
remind +2h "Check on deployment"
```

---

### Clipboard Manager
```bash
clip save mysnippet "Frequently used text"
clip list
clip load mysnippet    # Copies to clipboard
clip peek mysnippet    # Shows without copying
```

---

### Launch Apps by Shortcut
```bash
app add code "Visual Studio Code"
app code               # Launches VS Code
app list
```

---

### Weekly Review
```bash
weekreview
weekreview --file     # Export to Markdown
```
**What it does:** Summarizes last 7 days of tasks, journal, git commits.

---

### What Is This Command?
```bash
whatis ll
whatis todo
```
**What it does:** Explains aliases and shows documentation.

---

## Pro Tips

### Everything is Logged
Your system tracks:
- Every command via `~/.config/dotfiles-data/system.log`
- Every AI call via `dispatcher_usage.log`
- Every directory visit via `dir_usage.log`

### Your Data is Backed Up
- Every evening: `goodevening` → auto-backup
- Manual backup: `backup-data`
- Location: `~/Backups/dotfiles_data/`

### Customize with `.env`
Enable optional features:
```bash
AI_BRIEFING_ENABLED=true    # Morning AI briefing
AI_REFLECTION_ENABLED=true  # Evening AI reflection
BLOG_DIR=/path/to/blog      # Blog integration
```

### Use Spec Templates
```bash
spec tech       # Opens tech spec template in VS Code
spec creative   # Opens creative spec template
spec content    # Opens content spec template
```
Fill in the template, save, and it auto-pipes to the AI dispatcher.

### Chain Your Workflows
Examples:
```bash
# Morning routine
startday && todo top && g suggest

# Evening cleanup
goodevening && todo clear && weekreview

# Blog workflow
blog ideas && blog generate "Title" -p thoughtful-guide && blog status
```

---

## Need Help?

### Documentation
- `docs/happy-path.md` - Brain-fog-friendly daily walkthrough
- `docs/ai-examples.md` - Real AI dispatcher examples
- `docs/clipboard.md` - Clipboard workflow examples
- `bin/README.md` - Complete AI dispatcher guide
- `scripts/README.md` - All 56 scripts explained

### Validation
```bash
dotfiles-check      # Run the system doctor
```

### Troubleshooting
See `TROUBLESHOOTING.md` for common issues.

---

**Remember:** Everything here is designed for low-energy days. No command requires more than a few keystrokes. You've built an amazing system—use it generously! 🎯
