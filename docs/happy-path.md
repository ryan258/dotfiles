# Daily Happy Path: Your Brain Fog Survival Guide

This document outlines the ideal daily workflow using your context-recovery system. Designed specifically for MS brain fog days when remembering what to do is hard.

## Morning Routine (Automatic)

### What Happens
When you open your first terminal of the day, `startday` runs automatically and shows:
- Yesterday's journal entries (what you were working on)
- Active GitHub projects (pushed in last 7 days)
- Blog status (auto-syncs blog stubs to your todo list)
- Upcoming health appointments with countdown
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
```

## Evening: Close the Loop

### End of Day Summary
Before you finish for the day:

```bash
goodevening
```

This shows:
- **Gamified progress:** Celebrates tasks completed and journal entries logged (progress is progress!)
- Tasks you completed today
- Today's journal entries
- **Project safety checks:**
  - Uncommitted changes
  - Large diffs (>100 lines)
  - Stale branches (>7 days old)
  - Unpushed commits
- **Automated cleanup:** Removes completed tasks older than 7 days
- **Automated backup:** Silently backs up all your data to `~/Backups/dotfiles_data/`

**Note:** The interactive prompts for health tracking are available but currently commented out (optional feature).

## Weekly Review

Once a week (Sunday evenings work well):

```bash
weekreview
```

Shows:
- Completed tasks from last 7 days
- Journal entries from last 7 days
- Git contributions this week

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
| `todo add "task"` or `ta "task"` | Add a task |
| `todo list` or `t` | See all tasks |
| `todo top 3` | See top 3 priorities |
| `todo bump <num>` | Move task to top |
| `todo done <num>` | Complete a task |
| `todo commit <num>` | Commit code + complete task |
| `health energy <1-10>` | Log energy level |
| `health symptom "..."` | Log symptoms |
| `health dashboard` | 30-day health trends |
| `meds check` | Check medication schedule |
| `meds dashboard` | Adherence tracking |
| `weekreview` | Weekly summary |
| `g save <name>` | Bookmark this directory |
| `g <name>` | Jump to bookmark (with venv/apps) |
| `pomo` | 25-minute Pomodoro timer |
| `howto <name>` | Personal how-to wiki |
| `systemlog` | View automation activity |

## The Most Important Rules

1. **Let startday guide your morning:** It automatically brings back yesterday's context - just read and absorb.

2. **Use `next` when overwhelmed:** Don't look at the full todo list. Just see your top priority and focus on that one thing.

3. **Journal liberally:** Every thought, every discovery, every struggle. Search is powerful now - make your journal searchable.

4. **Trust the automation:** The system now tracks patterns (health dashboards), syncs your blog to todos, backs up data, and shows you stale tasks. Let it work for you.

5. **Celebrate progress:** `goodevening` now gamifies your wins. Even one task or one journal entry counts as progress.

## Tips for Bad Brain Fog Days

1. **Use `next` instead of `todo list`**: Looking at a full task list can be overwhelming
   ```bash
   next      # Just see task #1, that's all you need right now
   ```

2. **Smaller tasks**: Break everything into tiny pieces
   ```bash
   todo add "Read auth code - just 10 minutes"
   todo add "Write 1 paragraph of blog post"
   ```

3. **Log your health data**: Track the correlation between symptoms and productivity
   ```bash
   health energy 3
   health symptom "Heavy fog today, fatigue"
   journal "Heavy fog today, taking frequent breaks"
   ```

4. **Use status liberally**: Every time you lose your place
   ```bash
   status    # Run this often, no shame
   ```

5. **Use search when confused**: Your past self left breadcrumbs
   ```bash
   journal search "what was I working on"
   journal search "authentication"     # Find that work you did before
   ```

6. **Take a Pomodoro**: 25 minutes of focus, then break
   ```bash
   pomo      # Timer + notification when done
   ```

7. **Trust the system**: Your notes are there, searchable, and backed up. You don't have to remember. That's the point.

## Data Location

All your data is centralized in `~/.config/dotfiles-data/`:
- `journal.txt` - All journal entries (searchable)
- `todo.txt` & `todo_done.txt` - Task lists with timestamps
- `health.txt` - Health appointments, symptoms, energy ratings
- `medications.txt` - Medication schedules and dose logs
- `system.log` - Audit trail of all automation activity
- `dir_bookmarks` - Saved navigation bookmarks
- `clipboard_history/` - Saved clipboard snippets
- `how-to/` - Your personal how-to wiki articles

**Automatic Backups:** This directory is automatically backed up daily to `~/Backups/dotfiles_data/` by `goodevening`. Your data is safe.

**View Activity:** Run `systemlog` anytime to see what automated tasks have run (backups, blog syncs, task cleanups, etc.).

---

**Remember:** The system exists because your brain doesn't always work the same way every day. That's okay. Use it. Trust it. Search it. Let the automation work for you. It's got your back.

**Pro tip for brain fog days:** Just run `next` and `journal search` - those two commands can get you unstuck when nothing else makes sense.
