# MS-Friendly Features Guide
## How Your Dotfiles System Supports You Through Energy Fluctuations

This system was built with MS challenges in mind: brain fog, fatigue, energy fluctuations, and the need for maximum efficiency on low-energy days.

---

## 🧠 Brain Fog Protection

### Minimal Keystrokes
**Problem:** Remembering complex commands is hard on foggy days.
**Solution:** Everything is aliased to 2-5 characters.

Examples:
- `todo` instead of `~/dotfiles/scripts/todo.sh`
- `gs` instead of `git status`
- `ll` instead of `ls -lah`
- `..` instead of `cd ..`

**150+ aliases** mean you rarely need to remember full paths or commands.

---

### Auto-Completion & Suggestions
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

### Visual Clarity
**Problem:** Walls of text are overwhelming.
**Solution:** Clean, scannable output.

- Tables for structured data
- Color coding (git status, priorities)
- Top N filtering (`todo top` shows 3, not 47)
- Emoji indicators (when helpful, not excessive)
- Clear section headers

---

### Forgiving Design
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

## ⚡ Energy Management

### Track Your Energy
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

### Symptom Tracking
```bash
health symptom "brain fog, fatigue"
health symptom "headache" --severity 8
health list            # See recent symptoms
health summary         # 30-day overview
```

**Why this matters:** You can spot triggers, track medication effectiveness, prepare for doctor appointments.

---

### Medication Adherence
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

### Break Reminders
**Problem:** Hyper-focus until you crash.
**Solution:** Automated breaks.

```bash
break                  # 15-minute break
pomo                   # 25-minute work session
remind +1h "Stretch"   # Custom reminders
```

You'll get macOS notifications when time's up.

---

### Daily Routines That Run Themselves
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

## 📊 Pattern Recognition

### AI Analysis of Your Data
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

### Week in Review
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

## 🎯 Focus & Prioritization

### Daily Focus Intention
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

### Top N Filtering
```bash
todo top               # Top 3 tasks only
todo top 5             # Top 5
```

**Why this matters:** Seeing 30 tasks is paralyzing. Seeing 3 is actionable.

---

### Stale Task Detection
```bash
startday               # Shows tasks >7 days old
```

**Why this matters:** Tasks that sit too long are probably wrong. The system surfaces them for review.

---

## 🤖 AI Offloading

### Delegate to AI
**Problem:** Some tasks require more energy than you have.
**Solution:** AI specialists do the heavy lifting.

```bash
todo debug 3           # AI analyzes task 3
todo delegate 5 tech   # Send task 5 to tech AI
```

**All 10 AI dispatchers are free-tier.** Use them without guilt.

---

### Context-Aware AI
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

### AI Suggests What to Do
```bash
ai_suggest
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

## 💾 Data Safety

### Auto-Backup
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

### Git-Backed Todo List
```bash
todo commit
```

**What it does:** Commits `todo.txt` to git with timestamp.

**Why this matters:** Version control for your tasks. Never lose a todo.

---

### Validation Before Backup
```bash
data-validate
```

**Runs automatically in `goodevening`.** Checks data integrity before backup.

---

## 🧘 Mental Health Support

### Stoic Coaching
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

### Encouraging Feedback
**Every task completion:**
```
✅ Task completed! Keep up the great work!
✅ Nice! One more thing done!
✅ Awesome progress!
```

**Randomized positive reinforcement.** Small dopamine hits matter.

---

### Win Celebration
```bash
goodevening
```

**Shows:**
- Completed tasks today
- Journal entries today
- "You're doing great!" messages

**Why this matters:** MS can make you feel unproductive. Celebrating small wins counters that.

---

## 🔄 Low-Friction Workflows

### No Setup Required
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

### Chain Common Workflows
```bash
# Morning routine
startday && todo top && g suggest

# Evening cleanup
goodevening && todo clear

# Blog workflow
blog ideas && blog generate "Title" -p guide && blog status
```

---

### Keyboard-Driven (No Mouse)
Everything is command-line. No:
- Clicking through menus
- Visual focus/hand-eye coordination
- Mouse precision

**Why this matters:** Fine motor control can be affected by MS. Keyboard is faster and more reliable.

---

## 📈 Progress Visibility

### System Health Check
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

### Git Progress
```bash
my-progress            # Recent commits in current repo
projects               # GitHub repos worked on recently
```

**Why this matters:** You've done more than you remember.

---

## 🎨 Customization for Your Needs

### Enable/Disable AI Features
In `.env`:
```bash
AI_BRIEFING_ENABLED=true       # Morning AI briefing
AI_REFLECTION_ENABLED=true     # Evening AI reflection
```

**Default:** Both disabled (opt-in, not opt-out).

---

### Adjust Defaults
```bash
export TODO_TOP_DEFAULT=5      # Show 5 tasks instead of 3
export BREAK_DURATION=20       # 20-minute breaks
export API_COOLDOWN_SECONDS=2  # Slower API rate limiting
```

---

### Blog Integration
```bash
export BLOG_DIR="/path/to/hugo/blog"
export BLOG_SECTION_EXEMPLARS="/path/to/examples"
```

---

## 🧩 Real-World Scenarios

### Scenario 1: Brain Fog Morning
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

### Scenario 2: Low Energy Day
**You have energy for maybe 1-2 hours of work.**

```bash
health energy 4        # Log low energy
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

---

### Scenario 3: Medication Brain
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

### Scenario 4: Doctor Appointment Prep
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

### Scenario 5: Good Energy Day
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

## 🎯 Key Takeaways

### The System Assumes:
✅ You will have brain fog
✅ You will have low-energy days
✅ You will forget things
✅ You will need encouragement
✅ Your energy is unpredictable

### The System Provides:
✅ Minimal cognitive load
✅ Maximum automation
✅ Forgiving recovery
✅ Pattern recognition
✅ Win celebration
✅ Data safety
✅ Progress visibility

### You Don't Need to Remember:
❌ Where you were working
❌ What you were doing
❌ Complex commands
❌ To back up data
❌ To track patterns
❌ To celebrate wins

**The system remembers for you.**

---

## 🚀 Getting Started

### Day 1: Just Observe
```bash
startday               # See what it shows
focus set "Learn the system"  # Set intention
spoons init 12         # Start energy tracking
todo "Try one thing"   # Add one task
journal "Day 1"        # One entry
goodevening            # Evening routine
focus done             # Complete the focus
```

### Week 1: Add Health Tracking
```bash
health energy 7        # Daily
meds log "Medication"  # As taken
```

### Week 2: Try One AI Dispatcher
```bash
tech "question"        # Or stoic, or content
```

### Month 1: Full Integration
```bash
# Morning: automatic
# During: status, todo, journal
# Evening: goodevening
# Weekly: weekreview
```

---

## 📞 When You Need Help

```bash
whatis <command>       # What does this do?
dotfiles-check         # Is everything working?
ai_suggest             # What should I do next?
```

**Documentation:**
- `docs/discover.md` - Feature discovery
- `docs/daily-cheatsheet.md` - One-page reference
- `docs/happy-path.md` - Daily walkthrough
- `TROUBLESHOOTING.md` - Common issues

---

**You built this for yourself. Trust it. Use it. You deserve tools that work _with_ your energy, not against it.** 🎯
