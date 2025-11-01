# Daily Happy Path: Your Brain Fog Survival Guide

This document outlines the ideal daily workflow using your context-recovery system. Designed specifically for MS brain fog days when remembering what to do is hard.

## Morning Routine (Automatic)

### What Happens
When you open your first terminal of the day, `startday` runs automatically and shows:
- Yesterday's journal entries (what you were working on)
- Active GitHub projects (pushed in last 7 days)
- Blog status
- Upcoming health appointments
- Today's task list

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
```

**Shortcut:**
```bash
j "Quick note"     # Alias for 'journal'
```

### Mark Tasks Complete
As you finish things:

```bash
todo done 1        # Complete task #1
todo done 3        # Complete task #3
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
- Projects with uncommitted changes
- **Prompts you:** "What should tomorrow-you remember about today?"

Type your answer to capture your context for tomorrow. This is THE most important step - it closes the loop.

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

### Add Appointments
```bash
health add "Neurologist follow-up" "2025-12-15 14:00"
health add "Physical therapy" "2025-11-10 09:30"
```

### Check Upcoming
```bash
health list
```

Shows appointments with countdown in days.

## Emergency: "Where Was I?"

If you come back after a break and have NO idea what you were doing:

```bash
# 1. Check context
status

# 2. Read recent journal
journal            # Shows last 5 entries

# 3. See what you were working on
todo list

# 4. Check what you completed recently
cat ~/.config/dotfiles-data/todo_done.txt | tail -10
```

## Navigation Helpers

### Save Important Directories
```bash
# In the directory you want to bookmark:
goto save project-name

# Later, jump back:
goto project-name
```

### Jump to Recent Directories
```bash
back               # Interactive picker of recent dirs
```

## Quick Reference Card

| Command | What It Does |
|---------|--------------|
| `startday` | Morning briefing (runs automatically) |
| `status` | Mid-day context check |
| `goodevening` | End-of-day summary & tomorrow prompt |
| `journal "msg"` or `j "msg"` | Capture a moment |
| `todo add "task"` or `ta "task"` | Add a task |
| `todo list` or `t` | See tasks |
| `todo done <num>` | Complete a task |
| `health add "..." "date"` | Track appointment |
| `weekreview` | Weekly summary |
| `goto save <name>` | Bookmark this directory |
| `goto <name>` | Jump to bookmark |

## The Most Important Rule

**Always answer the goodevening prompt.** That one sentence you write at the end of the day is what brings you back tomorrow. It's your context lifeline.

Example good answers:
- "Working on auth bug, found it's in token validation"
- "Started refactoring API, got models done, routes next"
- "Rough brain fog day, just did small tasks, that's okay"

## Tips for Bad Brain Fog Days

1. **Smaller tasks**: Break everything into tiny pieces
   ```bash
   todo add "Read auth code - just 10 minutes"
   todo add "Write 1 paragraph of blog post"
   ```

2. **Journal your struggles**: It helps you see patterns
   ```bash
   journal "Heavy fog today, taking frequent breaks"
   ```

3. **Use status often**: Every time you lose your place
   ```bash
   status    # Run this liberally, no shame
   ```

4. **Trust the system**: Your notes are there. You don't have to remember. That's the point.

## Data Location

All your data is centralized in `~/.config/dotfiles-data/`:
- `journal.txt` - All journal entries
- `todo.txt` & `todo_done.txt` - Task lists
- `health.txt` - Health appointments

This directory can be easily backed up or synced to the cloud for safety.

---

**Remember:** The system exists because your brain doesn't always work the same way every day. That's okay. Use it. Trust it. It's got your back.
