# Daily Happy Path: Your Brain Fog Survival Guide

This document outlines the ideal daily workflow using your context-recovery system. Designed specifically for MS brain fog days when remembering what to do is hard.

## Morning Routine (Automatic)

### What Happens
When you open your first terminal of the day, `startday` runs automatically (only once per calendar day) and shows:
- 🎯 Focus for today (if you set one with `focus "..."`)
- Yesterday's journal entries (what you were working on)
- Active GitHub projects (pushed in last 7 days from any machine)
- Suggested directories based on recent/frequent usage (`g suggest`)
- Blog status (auto-syncs blog stubs to your todo list)
- Weekly review pointer on Mondays (links to the Markdown summary saved in `~/Documents/Reviews/Weekly/`)
- Upcoming health appointments with countdown plus today's energy/symptom snapshot
- Scheduled commands/reminders (from `schedule` command)
- Stale tasks (older than 7 days - might want to address these)
- Your top 3 priority tasks (not the full overwhelming list)

### What You Do
**Nothing!** Just read the output. It brings back yesterday's context.

```bash
# Startday runs automatically on first terminal open
# If you want to run it manually:
startday
```

## Morning: Capture Your Intentions

### Set Today's Focus
Give your morning dashboard an anchor:

```bash
focus "Ship the insights capsule"
focus show       # Remind yourself later in the day
focus clear      # When you want to reset
```

Whatever you set here appears at the top of `startday` (and you can re-run `startday` manually anytime).

### Add Today's Tasks
As ideas come to you, quickly add them:

```bash
todo add "Review PR for insight-capsule"
todo add "Write blog post outline"
todo add "Call doctor about prescription"
```

**Shortcut:**
```bash
ta "Quick task"    # Alias for 'todo add'
```

### Check What's On Your Plate
```bash
todo list          # See all tasks
# or
t                  # Shortcut alias

# Just see your top priority:
next               # Shows only task #1

# See top 3 priorities:
todo top 3
```

### Prioritize Tasks
Move important tasks to the top of your list:

```bash
todo bump 5        # Move task #5 to the top
```

## During the Day: Stay Grounded

### Mid-Day Context Check
When you lose track of what you're doing (brain fog moment):

```bash
status
```

This shows:
- Where you are (directory, git branch)
- Last journal entry
- Today's journal entries
- Today's tasks

Need a nudge on where to jump next?

```bash
g suggest | head -3   # Top smart directory suggestions
```

### Journal Important Moments
Capture context as things happen:

```bash
journal "Figured out the authentication bug - it was the token expiry"
journal "Meeting with Sarah - decided to refactor the API layer"
journal "Feeling foggy today, taking it slow"
journal "blog idea: write about MS and developer tools"
```

**Shortcut:**
```bash
j "Quick note"     # Alias for 'journal'
```

**Need to brain dump paragraphs?**
```bash
dump               # Opens $EDITOR, saves everything to the journal for today
```

**Search Your Past:**
```bash
journal search "authentication"    # Find when you worked on auth
journal search "blog idea"         # Find all your blog ideas
journal onthisday                  # See what you did this day in previous years
```

### Mark Tasks Complete
As you finish things:

```bash
todo done 1        # Complete task #1
todo done 3        # Complete task #3

# Commit code AND complete task in one step:
todo commit 2 "Fixed authentication bug"
# Or let it auto-generate the commit message from the task:
todo commit 2

# Undo an accidental completion:
todo undo         # Restores the most recently completed task
```

## Evening: Close the Loop

### End of Day Summary
Before you finish for the day:

```bash
goodevening
```

This shows:
- Tasks you completed today
- Today's journal entries
- **Gamified progress:** Celebrates tasks completed and journal entries logged (progress is progress!)
- **Project safety checks:**
  - Uncommitted changes
  - Large diffs (>100 lines)
  - Stale branches (>7 days old)
  - Unpushed commits
- **Automated cleanup:** Removes completed tasks older than 7 days
- **Data validation:** Runs `scripts/data_validate.sh` (add this script if you haven't yet) to catch corrupted files before backing up
- **Automated backup:** When validation passes, backs up everything in `~/.config/dotfiles-data/` to `~/Backups/dotfiles_data/`

**Note:** The interactive prompts for health tracking are available but currently commented out (optional feature).

## Weekly Review

Once a week (Sunday evenings work well):

```bash
weekreview --file    # Saves to ~/Documents/Reviews/Weekly/YYYY-W##.md
```

Shows:
- Completed tasks from last 7 days
- Journal entries from last 7 days
- Git contributions this week

Want it to run automatically? Use the friendly scheduler wrapper:

```bash
setup_weekly_review    # Schedules next Sunday's export via schedule.sh
```

## Health Tracking

### Track Appointments
```bash
health add "Neurologist follow-up" "2025-12-15 14:00"
health add "Physical therapy" "2025-11-10 09:30"
health list                           # See appointments with countdown
```

### Track Daily Health
Log symptoms and energy levels to spot patterns:

```bash
# Log how you're feeling (1-10 scale):
health energy 6                       # 1-3: Low, 4-6: Medium, 7-10: Good

# Log symptoms as they happen:
health symptom "Heavy brain fog, fatigue"
health symptom "Headache, sensitivity to light"

# See recent data:
health list                           # Last 7 days

# View 30-day trend analysis:
health dashboard                      # Average energy, symptom frequency, patterns
```

### Export for Doctor Visits
Before medical appointments:

```bash
health export 30                      # Export last 30 days to markdown file
# Opens ~/health_export_YYYYMMDD.md ready to email or print
```

### Medication Tracking
Set up and track medications:

```bash
# Add medications with schedule:
meds add "Medication X" "morning,evening"
meds add "Medication Y" "8:00,20:00"

# Log when you take them:
meds log "Medication X"

# Check what needs to be taken:
meds check

# View adherence over time:
meds dashboard                        # 30-day adherence percentages

# Set up automated reminders (optional, requires cron):
# Add to crontab: 0 8,20 * * * /path/to/meds.sh remind
```

## Emergency: "Where Was I?"

If you come back after a break and have NO idea what you were doing:

```bash
# 1. Check context
status

# 2. Read recent journal
journal list                           # Shows last 5 entries

# 3. Search your past work
journal search "project-name"          # Find when you worked on this
journal search "authentication"        # Find specific work

# 4. See what you were working on
next                                   # Just your top priority
todo list                              # Full list if needed

# 5. Check what you completed recently
cat ~/.config/dotfiles-data/todo_done.txt | tail -10

# 6. Check system activity
systemlog                              # See what automated tasks ran
```

## Navigation Helpers

### Save Important Project Locations
The `g` command replaces the old `goto`/`back`/`workspace` tools with intelligent state management:

```bash
# In the directory you want to bookmark:
g save myproject

# Bookmark with auto-launching apps:
g save blog -a code,chrome

# Later, jump back (auto-activates venv, launches apps):
source g.sh myproject
# or use the alias:
g myproject                           # (must be sourced to cd)
```

### Jump to Recent Directories
```bash
g -r               # Show recent directory history
g recent           # Same thing
```

### List All Bookmarks
```bash
g list             # See all saved locations
```

### Let the System Suggest & Tidy
```bash
g suggest | head -3    # Smart suggestions based on frequency + recency
g prune --auto         # Remove bookmarks whose directories disappeared
```

## Productivity Power Tools

### Focus Timer (Pomodoro)
```bash
pomo               # 25-minute focused work timer
break              # 15-minute break timer (or customize)
```

### Knowledge Management
```bash
howto add git-workflow                # Save a how-to guide
howto git-workflow                    # Read the guide later
howto search "docker"                 # Search all guides
```

### Schedule Future Reminders
```bash
schedule "2:30 PM" "remind 'Call Mom'"
schedule "tomorrow 9am" "todo add 'Review PR'"
```

### Look Up Commands
```bash
whatis gs                             # What does 'gs' alias do?
whatis todo                           # Look up any command
```

### System Validation
```bash
dotfiles_check                        # Verify entire system health
systemlog                             # View automation activity log
```

## Quick Reference Card

| Command | What It Does |
|---------|--------------|
| `startday` | Morning briefing with context recovery |
| `status` | Mid-day context check |
| `goodevening` | End-of-day summary with gamification |
| `next` | Show only your top priority task |
| `journal "msg"` or `j "msg"` | Capture a moment |
| `journal search "<term>"` | Find past journal entries |
| `journal onthisday` | See this day in previous years |
| `dump` | Long-form journaling via your `$EDITOR` |
| `todo add "task"` or `ta "task"` | Add a task |
| `todo list` or `t` | See all tasks |
| `todo top 3` | See top 3 priorities |
| `todo bump <num>` | Move task to top |
| `todo done <num>` | Complete a task |
| `todo commit <num>` | Commit code + complete task |
| `todo undo` | Restore the most recently completed task |
| `health energy <1-10>` | Log energy level |
| `health symptom "..."` | Log symptoms |
| `health dashboard` | 30-day health trends |
| `meds check` | Check medication schedule |
| `meds dashboard` | Adherence tracking |
| `weekreview --file` | Weekly summary saved to Markdown |
| `setup_weekly_review` | Schedule the weekly export |
| `focus` / `focus show` | Set or view today's focus |
| `g save <name>` | Bookmark this directory |
| `g <name>` | Jump to bookmark (with venv/apps) |
| `g suggest` | Smart directory suggestions |
| `pomo` | 25-minute Pomodoro timer |
| `howto <name>` | Personal how-to wiki |
| `systemlog` | View automation activity |

## The Most Important Rules

1. **Let `startday` + `focus` anchor you:** Set a focus if you can, then read the briefing—it stitches together blog, health, GitHub, and tasks for you.

2. **Use `next` when overwhelmed:** Don't look at the full todo list. Just see your top priority and focus on that one thing (undo is there if you mis-click).

3. **Journal and `dump` liberally:** Every thought, every discovery, every struggle. Search is powerful now—give your future self breadcrumbs.

4. **Trust the automation:** The system tracks patterns, syncs your blog to todos, validates data before backups, and shows you stale tasks. Let it work for you.

5. **Celebrate progress:** `goodevening` gamifies your wins. Even one task or one journal entry counts as progress.

## Tips for Bad Brain Fog Days

1. **Use `next` instead of `todo list`**: Looking at a full task list can be overwhelming
   ```bash
   next      # Just see task #1, that's all you need right now
   ```

2. **Remind yourself of the plan**: When the morning feels fuzzy
   ```bash
   focus show    # Re-read the focus you set earlier
   startday      # Re-run the dashboard if you need the full picture
   ```

3. **Smaller tasks**: Break everything into tiny pieces
   ```bash
   todo add "Read auth code - just 10 minutes"
   todo add "Write 1 paragraph of blog post"
   ```

4. **Log your health data**: Track the correlation between symptoms and productivity
   ```bash
   health energy 3
   health symptom "Heavy fog today, fatigue"
   journal "Heavy fog today, taking frequent breaks"
   ```

5. **Use status liberally**: Every time you lose your place
   ```bash
   status    # Run this often, no shame
   ```

6. **Capture more context, quickly**: When words are messy
   ```bash
   dump      # Opens your editor for a long-form brain dump
   j "short thought"   # Keep breadcrumbs searchable
   ```

7. **Use search when confused**: Your past self left breadcrumbs
   ```bash
   journal search "what was I working on"
   journal search "authentication"     # Find that work you did before
   ```

8. **Let navigation nudge you**: When you can't remember the project path
   ```bash
   g suggest | head -3   # Smart guesses based on what you use most
   ```

9. **Undo mistakes immediately**: If you complete the wrong task
   ```bash
   todo undo
   ```

10. **Take a Pomodoro**: 25 minutes of focus, then break
   ```bash
   pomo      # Timer + notification when done
   ```

11. **Trust the system**: Your notes are there, searchable, and backed up. You don't have to remember. That's the point.

## Data Location

All your data is centralized in `~/.config/dotfiles-data/`:
- `journal.txt` - All journal entries (searchable)
- `todo.txt` & `todo_done.txt` - Task lists with timestamps
- `health.txt` - Health appointments, symptoms, energy ratings
- `medications.txt` - Medication schedules and dose logs
- `system.log` - Audit trail of all automation activity
- `dir_bookmarks`, `dir_history`, `dir_usage.log` - Smart navigation bookmarks, history, and suggestion weights
- `daily_focus.txt` - Stores the focus message surfaced by `startday`
- `clipboard_history/` - Saved clipboard snippets
- `how-to/` - Your personal how-to wiki articles

**Weekly Reviews:** `weekreview --file` saves Markdown summaries to `~/Documents/Reviews/Weekly/`.

**Automatic Backups:** This directory is automatically backed up daily to `~/Backups/dotfiles_data/` by `goodevening`. Your data is safe.

**View Activity:** Run `systemlog` anytime to see what automated tasks have run (backups, blog syncs, task cleanups, etc.).

---

**Remember:** The system exists because your brain doesn't always work the same way every day. That's okay. Use it. Trust it. Search it. Let the automation work for you. It's got your back.

**Pro tip for brain fog days:** `focus show`, `next`, and `journal search`—those three commands can get you unstuck when nothing else makes sense.
