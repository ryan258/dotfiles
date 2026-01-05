# Start Here - 5 Minute Orientation

## Everything You Need to Know Right Now

**Feeling lost or forgot what you have?** This page gets you oriented in 5 minutes.

---

## ✅ Is Everything Working?

```bash
dotfiles-check
```

**What it does:** Validates all scripts, dependencies, AI dispatchers, and data directories.
**What you'll see:** ✅ for working components, ❌ for issues.

---

## 📖 The Big Picture

You have **3 systems** working together:

### 1. Daily Routines (Autopilot)

```bash
startday        # Morning briefing (runs automatically once per day)
status          # Mid-day: "Where am I? What am I doing?"
goodevening     # Evening: celebrate wins + auto-backup
```

### 2. Productivity Tools

```bash
todo add "task"        # Task management
journal add "note"     # Quick journaling
health energy 7    # Track energy 1-10
spoons init 12     # Daily energy budget
focus set "thing"  # Set daily intention
g suggest          # Where should I work today?
gcal agenda        # View today's calendar
```

### 3. AI Helpers (Swarm-Powered Team)

```bash
tech "question"            # Technical debugging
content "blog topic"       # Write content
stoic "I'm struggling"     # Mindset coaching
ai_suggest                 # Which AI should I use?
```

---

## 🎯 Your First 5 Minutes

### Minute 1: See What You Have

```bash
# Open this discovery guide
open ~/dotfiles/docs/discover.md

# Or read the one-page cheat sheet
open ~/dotfiles/docs/daily-cheatsheet.md
```

### Minute 2: Try the Daily Loop

```bash
startday        # See what it shows you
```

**You'll see:** Focus, yesterday's context, suggested directories, top tasks, health reminders.

### Minute 3: Add One Task and Journal Entry

```bash
todo add "Try one feature from the discovery guide"
journal add "Exploring my dotfiles system - Day 1"
```

### Minute 4: Try One AI

```bash
ai_suggest      # Get a recommendation
# Then try the suggested AI:
stoic "I want to understand this system better"
```

### Minute 5: Evening Check

```bash
goodevening     # See wins + backup data
```

**Done!** You've completed your first full loop.

---

## 🧭 Navigation Guide

### Where Are the Docs?

```
~/dotfiles/docs/
├── start-here.md              ⭐ You are here
├── daily-cheatsheet.md        ⭐ One-page reference
├── discover.md                ⭐ Complete feature guide
├── ms-friendly-features.md    ⭐ How it helps with MS
├── ai-quick-reference.md      ⭐ AI examples
├── system-overview.md         ⭐ Visual architecture
└── happy-path.md              Daily walkthrough
```

### Most Important Docs for Getting Started

1. **[Daily Cheat Sheet](daily-cheatsheet.md)** - Keep this open while you learn
2. **[Feature Discovery](discover.md)** - Organized by what you want to do
3. **[MS-Friendly Features](ms-friendly-features.md)** - How it supports brain fog and energy fluctuations

### Where Is My Data?

```
~/.config/dotfiles-data/
├── todo.txt, todo_done.txt    # Your tasks
├── journal.txt                # Your journal
├── health.txt                 # Energy and symptoms
├── medications.txt            # Medication tracking
└── system.log                 # Audit trail
```

**Backed up nightly to:** `~/Backups/dotfiles_data/`

---

## 🆘 Brain Fog? Start Here

**Can't focus? Low energy? Try this minimal routine:**

```bash
# Morning (automatic)
# startday runs automatically when you open terminal

# During day (pick just ONE)
todo top        # See top 3 tasks
status          # Quick check-in
dump            # Brain dump thoughts

# Evening
goodevening     # Celebrate + backup
```

**That's it.** On low-energy days, this is enough.

---

## 💡 Most Useful Commands

### Tasks

| Command           | What It Does    |
| ----------------- | --------------- |
| `todo add "task"` | Add a task      |
| `todo top`        | See top 3 only  |
| `todo done 1`     | Complete task 1 |

### Journaling

| Command                    | What It Does                   |
| -------------------------- | ------------------------------ |
| `journal add "note"`       | Quick entry                    |
| `dump`                     | Free-form journaling in editor |
| `journal search "keyword"` | Find past entries              |

### Health

| Command            | What It Does        |
| ------------------ | ------------------- |
| `health energy 7`  | Rate energy 1-10    |
| `meds log "Med"`   | Log medication      |
| `spoons init 12`   | Daily energy budget |
| `spoons history`   | Usage patterns      |
| `health dashboard` | 30-day trends       |

### Navigation

| Command            | What It Does            |
| ------------------ | ----------------------- |
| `g suggest`        | Where should I work?    |
| `g save myproject` | Bookmark this directory |
| `g myproject`      | Jump to bookmark        |

### AI

| Command            | What It Does     |
| ------------------ | ---------------- |
| `tech "question"`  | Debug code       |
| `content "topic"`  | Write content    |
| `stoic "struggle"` | Get perspective  |
| `ai_suggest`       | Which AI to use? |

### Help

| Command          | What It Does      |
| ---------------- | ----------------- |
| `whatis command` | Explain a command |
| `dotfiles-check` | Validate system   |

---

## 🎯 Choose Your Path

### Path 1: "I Just Want the Basics"

**Read:** [Daily Cheat Sheet](daily-cheatsheet.md)
**Try:** `startday`, `todo`, `journal`, `goodevening`
**Time:** 10 minutes

---

### Path 2: "I Want to Understand Everything"

**Read:** [Feature Discovery Guide](discover.md)
**Read:** [System Overview](system-overview.md)
**Try:** One feature from each category
**Time:** 1 hour

---

### Path 3: "I Have MS and Need Accessibility Features"

**Read:** [MS-Friendly Features Guide](ms-friendly-features.md)
**Read:** [Daily Cheat Sheet](daily-cheatsheet.md)
**Try:** Health tracking + minimal daily routine
**Time:** 20 minutes

---

### Path 4: "I Want to Use AI"

**Read:** [AI Quick Reference](ai-quick-reference.md)
**Try:** `ai_suggest` then one dispatcher
**Try:** `spec tech` for structured prompting
**Time:** 15 minutes

---

## 🚀 Next Steps After Orientation

### Day 1

- Run the daily loop: `startday` → work → `goodevening`
- Add 2-3 tasks with `todo`
- Try one AI dispatcher

### Week 1

- Track energy daily: `health energy [1-10]`
- Log medications: `meds log "Med Name"`
- Use `g suggest` for navigation

### Week 2

- Read [Feature Discovery Guide](discover.md)
- Try features that sound useful
- Customize `.env` if needed

### Week 3

- Explore all 10 AI dispatchers
- Set up blog integration (if you write)
- Create bookmarks for common directories

### Month 1

- Review [MS-Friendly Features](ms-friendly-features.md)
- Optimize your personal workflow
- Check `weekreview` every Sunday

---

## 📞 Getting Help

### Documentation

```bash
# Command-specific help
whatis todo
whatis g
whatis health

# System validation
dotfiles-check

# AI suggestions
ai_suggest
```

### Guides by Topic

- **Daily workflow:** [Happy Path](happy-path.md)
- **All features:** [Discovery Guide](discover.md)
- **AI help:** [AI Quick Reference](ai-quick-reference.md)
- **Accessibility:** [MS-Friendly Features](ms-friendly-features.md)
- **Architecture:** [System Overview](system-overview.md)
- **Best practices:** [Best Practices](best-practices.md)

### Troubleshooting

See `~/dotfiles/TROUBLESHOOTING.md` for common issues.

---

## 🎯 Remember

✅ **Minimum keystrokes** - Everything is 2-5 characters
✅ **Low cognitive load** - Designed for brain-fog days
✅ **Auto-backup** - Data saved nightly via `goodevening`
✅ **Forgiving** - `todo undo`, git-backed, validation
✅ **Free AI** - Use all 10 specialists without cost
✅ **Help available** - `whatis`, `ai_suggest`, docs

---

## 🏁 You're Ready!

Pick a path above and start exploring. You can't break anything—everything is backed up and has recovery mechanisms.

**Most important:**

1. Run `dotfiles-check` to verify everything works
2. Read [Daily Cheat Sheet](daily-cheatsheet.md)
3. Try the daily loop once
4. Explore [Discovery Guide](discover.md) when you're ready

**You've got this!** 🎯
