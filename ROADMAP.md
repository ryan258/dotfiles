# Daily Context System - Roadmap

**Purpose:** Combat MS-related brain fog by automatically preserving context across days  
**Status:** Core system working as of October 10, 2025  
**Location:** `~/dotfiles/`

---

## 🧠 The Problem

Ryan has MS-related brain fog. Each morning is a reset:
- Forgets what he was working on yesterday
- Loses project context between sessions
- Built systems then forgets to use them
- Perfectionism prevents using "imperfect" tools

**Solution:** Automated daily context system that runs without needing to remember

---

## ✅ What's Working Now

### Morning Routine (Automatic)
- **`startday`** auto-runs on first terminal of the day
- Shows:
  - Yesterday's journal entries
  - Active projects (modified in last 7 days)
  - Blog status (from `blog.sh`)
  - Health appointments with countdown
  - Today's task list

### Core Commands (Manual)
- **`journal "note"`** - Timestamped entries → `~/.daily_journal.txt`
- **`todo add "task"`** - Add tasks → `~/.todo_list.txt`
- **`status`** - Enhanced context dashboard
- **`goodevening`** - Enhanced end-of-day summary
- **`projects`** - Forgotten project recovery tool
- **`blog`** - Blog content workflow tool
- **`health add "desc" "YYYY-MM-DD HH:MM"`** - Track appointments
- **`goto`** - Bookmark project directories
- **`backup`** - Timestamped project backups

---

## 📁 File Structure

```
~/dotfiles/
├── zsh/
│   ├── .zshrc              # Main config, sources aliases, auto-runs startday
│   └── aliases.zsh         # Command aliases
├── scripts/
│   ├── startday.sh         # Morning context display
│   ├── goodevening.sh      # Evening wrap-up
│   ├── health.sh           # Health appointment tracking
│   ├── journal.sh          # Timestamped note taking
│   ├── todo.sh             # Task management
│   ├── status.sh           # Mid-day context check
│   ├── projects.sh         # Forgotten project recovery
│   ├── blog.sh             # Blog content workflow
│   └── ...
└── README.md               # System documentation

Data Files:
~/.daily_journal.txt        # All journal entries
~/.todo_list.txt            # Active tasks
~/.todo_done.txt            # Completed tasks
~/.health_appointments.txt  # Upcoming appointments (format: date|description)
```

---

## 🎯 Next Round Objectives (Q4 2025)

### 1. Morning Routine Reliability
- **Goal:** Resolve the `startday.sh` parse error surfaced during login so the automated morning briefing never fails.
- **Why now:** Broken startup scripts erode trust in the ritual; this is a blocker for daily use.
- **Deliverable:** Patch `startday.sh`, add a smoke-test snippet (e.g., `zsh -ic startday`) to the test guide.

### 2. Daily Happy Path Documentation
- **Goal:** Create `docs/happy-path.md` outlining the ideal morning → mid-day → evening flow using `startday`, `status`, `goodevening`, and supporting aliases.
- **Why now:** Gives future-you and assistants a frictionless script to follow on foggy days.
- **Deliverable:** Concise walkthrough with copy/pasteable commands; link it from `README.md` and the cheatsheet.

### 3. Health Context Expansion (Iteration 1)
- **Goal:** Extend `health.sh` to capture symptom notes and daily energy ratings, surfacing them in `startday`/`goodevening` summaries.
- **Why now:** Aligns tooling with current health tracking needs without taking on the full medication-reminder scope yet.
- **Deliverable:** New subcommands (`health symptom`, `health energy`), appended data store, and dashboard summaries.

## 📋 Backlog & Ideas

- **Blog cadence nudges:** Track last edit date per post and flag stubs older than 7 days.
- **Medication reminders:** CLI to log dosage windows plus optional notifications.
- **Symptom timeline export:** Generate weekly health recap for medical appointments.
- **Automation safety nets:** Auto-detect lingering git branches or large diff counts and surface them in `goodevening`.

Revisit once the three objectives above ship or if priorities shift.

## ✅ Recent Wins

| Item | Date | Notes |
| ---- | ---- | ----- |
| `status` overhaul | 2025-10-04 | Added location, git, journal, and task snapshots. |
| `goodevening` revamp | 2025-10-06 | Lists completed tasks, journal, dirty projects; prompts for tomorrow’s note. |
| `projects` recall tools | 2025-10-06 | Surfaced forgotten repos via GitHub API. |
| Clipboard workflows doc | 2025-10-10 | New `docs/clipboard.md` plus cross-links in README files. |

---

## 🔗 Key Resources

**GitHub:** https://github.com/ryan258/dotfiles  
**Blog:** https://ryanleej.com  
**Blog Repo:** https://github.com/ryan258/my-ms-ai-blog

---

## 📝 Notes for AI Assistants

- **Brain fog is real:** Ryan may not remember yesterday's conversation
- **Perfectionism blocks progress:** Ship working > perfect unused
- **Batch work pattern:** He works in intense sprints, not steady increments
- **Health context matters:** Symptoms affect everything
- **System must be automatic:** Relying on remembering = system failure
- **VS Code terminal:** Has shell integration conflict, use Terminal.app for testing

**Before suggesting new features:** Check if an existing script already does it. The system is more complete than Ryan may remember.

---

**Last Updated:** October 10, 2025  
**Next Review:** After Morning Routine Reliability and Happy Path docs ship
