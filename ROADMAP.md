# Daily Context System - Roadmap

**Purpose:** Combat MS-related brain fog by automatically preserving context across days  
**Status:** Core system working as of October 6, 2025  
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

## 🎯 Enhancement Roadmap

### Priority 4: Blog Content Workflow
**Problem:** 21 posts published, some marked as "content stubs" need expansion

**Note:** `blog.sh` created with `status`, `stubs`, `random`, `recent`. Further enhancements can be tracked here.

**Potential enhancements:**
- Track "last blog work" to remind if it's been >7 days

---

### Priority 5: Health Context Tracking
**Current:** Appointment tracking works well

**Potential enhancements:**
- Medication reminders with time of day
- Symptom logging: `health symptom "description"`
- Energy level tracking: `health energy [1-10]`
- Weekly health summary

**Not urgent** - current system handles immediate need

---

## 🚀 Implementation Priority

1. **Enhance `status`** - ✅ Done
2. **Enhance `goodevening`** - ✅ Done
3. **Forgotten projects** - ✅ Done
4. **Blog workflow tools** - In Progress (`blog.sh` created)
5. **Health enhancements** - To Do

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

**Last Updated:** October 6, 2025  
**Next Review:** When implementing Priority 5 enhancement
