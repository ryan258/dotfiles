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
  - Blog status (21 posts live at https://ryanleej.com)
  - Health appointments with countdown
  - Today's task list

**Implementation:** Auto-run via `.zshrc` using daily flag file

### Core Commands (Manual)
- **`journal "note"`** - Timestamped entries → `~/.daily_journal.txt`
- **`todo add "task"`** - Add tasks → `~/.todo_list.txt`
- **`todo done 1`** - Complete task #1
- **`status`** - Show recent journal + current tasks
- **`info`** - Dashboard with weather + todos
- **`health add "desc" "YYYY-MM-DD HH:MM"`** - Track appointments
- **`health list`** - Show upcoming appointments
- **`goto`** - Bookmark project directories
- **`back`** - Recently visited directories
- **`backup`** - Timestamped project backups

### Evening Routine (Exists but Underutilized)
- **`goodevening`** - End-of-day summary (needs enhancement)

---

## 📁 File Structure

```
~/dotfiles/
├── zsh/
│   ├── .zshrc              # Main config, sources aliases, auto-runs startday
│   └── aliases.zsh         # Command aliases
├── scripts/
│   ├── startday.sh         # Morning context display
│   ├── goodevening.sh      # Evening wrap-up (needs work)
│   ├── health.sh           # Health appointment tracking
│   ├── journal.sh          # Timestamped note taking
│   ├── todo.sh             # Task management
│   ├── status.sh           # Mid-day context check
│   └── info.sh             # Dashboard display
└── README.md               # System documentation

Data Files:
~/.daily_journal.txt        # All journal entries
~/.todo_list.txt            # Active tasks
~/.todo_done.txt            # Completed tasks
~/.health_appointments.txt  # Upcoming appointments (format: date|description)
```

---

## 🎯 Enhancement Roadmap

### Priority 1: Mid-Day Context Recovery
**Problem:** When focus is lost, `status` doesn't show enough to recover context

**Current `status` output:**
```
--- Last 5 Journal Entries ---
[timestamps and entries]

--- TODO ---
[numbered task list]
```

**Enhanced `status` should show:**
```
🧭 WHERE YOU ARE:
  • Current directory: [pwd]
  • Current git branch: [if in git repo]
  • Last journal entry: [most recent with timestamp]
  
📝 TODAY'S JOURNAL (since midnight):
  [all entries from today]
  
🚀 ACTIVE PROJECT:
  • [project name from current directory]
  • Last commit: [if in git repo]
  
✅ TASKS:
  [numbered list]
  
💡 Commands: journal | todo | startday | goodevening
```

**Files to modify:**
- `~/dotfiles/scripts/status.sh`

**Implementation notes:**
- Parse journal file for today's entries only (`date +%Y-%m-%d`)
- Detect if pwd is in `~/Projects/*` to identify current project
- Check for `.git` directory to show git status
- Keep it fast (< 1 second to run)

---

### Priority 2: Evening Close-Out
**Problem:** `goodevening` exists but isn't valuable enough to use

**Current behavior:** Basic git status check

**Enhanced `goodevening` should:**
1. Show completed tasks from today (`~/.todo_done.txt` with today's date)
2. Show today's journal entries
3. List active projects with uncommitted changes
4. Prompt: "What should tomorrow-you remember about today?"
5. Add response to journal automatically
6. Clear completed tasks older than 7 days

**Files to modify:**
- `~/dotfiles/scripts/goodevening.sh`

**Implementation notes:**
- Filter todo_done for today's completions
- Scan `~/Projects/*/.git/` for status
- Interactive prompt with journal entry
- Consider making it auto-run on terminal close (complex, maybe v2)

---

### Priority 3: Forgotten Project Recovery
**Problem:** No visibility into projects built months ago

**New command:** `projects forgotten`

**Should show:**
```
🗂️ PROJECTS NOT TOUCHED IN 60+ DAYS:
  • TuckdInTerrors_MonteCarloSim (134 days ago)
  • bppc (87 days ago)
  • quantum (76 days ago)
  
Run 'projects recall <name>' to see details
```

**New command:** `projects recall <name>`
```
📦 Project: bppc
Last modified: 87 days ago
Last commit: "Initial Ren'Py game structure"
README preview: [first 5 lines]
Path: ~/Projects/bppc

Commands: cd to navigate, goto to bookmark
```

**Files to create:**
- `~/dotfiles/scripts/projects.sh`
- Add alias: `alias projects='source $HOME/dotfiles/scripts/projects.sh'`

**Implementation notes:**
- Search `~/Projects/*` for `.git` directories
- Sort by last modification time
- Use `git log -1` for last commit info
- Read README.md if exists

---

### Priority 4: Blog Content Workflow
**Problem:** 21 posts published, some marked as "content stubs" need expansion

**Current status output:**
```
📝 BLOG STATUS (ryanleej.com):
  • Total posts: 21
  • Posts needing content: 0
  • Site: https://ryanleej.com
```

**Note:** Stub count shows 0, but some posts may need work. Need to verify stub detection logic.

**Potential enhancements:**
- List specific stub posts by title
- Show last blog update date
- Quick command to open a random stub for editing
- Track "last blog work" to remind if it's been >7 days

**Files to modify:**
- `~/dotfiles/scripts/startday.sh` (blog status section)

**New script to consider:**
- `~/dotfiles/scripts/blog.sh` with commands:
  - `blog status` - detailed view
  - `blog stubs` - list all content stubs
  - `blog random` - open random stub in editor
  - `blog recent` - show recently modified posts

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

## 🔧 Technical Notes

### Auto-run Implementation
```bash
# In ~/dotfiles/zsh/.zshrc
if [[ ! -f /tmp/startday_ran_today_$(date +%Y%m%d) ]]; then
    source "$HOME/dotfiles/scripts/startday.sh"
    touch /tmp/startday_ran_today_$(date +%Y%m%d)
fi
```

**Why this works:**
- Flag file created with today's date
- Persists across terminal sessions within same day
- Auto-cleans on reboot (lives in /tmp)
- No cron jobs or background processes needed

### Health Appointments Format
```
# ~/.health_appointments.txt
2025-11-18 11:15|Neurologist follow-up
2025-12-01 09:00|Physical therapy eval
```

**Format:** `YYYY-MM-DD HH:MM|Description`  
**Sorting:** File is sorted chronologically by date  
**Display:** Shows days until appointment

### Journal Entry Format
```
# ~/.daily_journal.txt
[2025-10-06 13:50:07] testing journal entry
[2025-10-06 14:15:22] working on blog post about brain fog
```

**Format:** `[YYYY-MM-DD HH:MM:SS] entry text`  
**No size limit** - file grows indefinitely (consider rotation after 1 year)

---

## 🚀 Implementation Priority

1. **Enhance `status`** (30 min) - Most immediate need for mid-day context recovery
2. **Enhance `goodevening`** (30 min) - Creates daily closure habit
3. **Forgotten projects** (45 min) - Reduces "what did I build?" confusion
4. **Blog workflow tools** (1 hour) - Only if blog work becomes active again
5. **Health enhancements** (1 hour) - Nice to have, not urgent

---

## 🎬 Usage Patterns

### Starting Work
1. Open terminal → `startday` runs automatically
2. See what you were doing yesterday
3. See today's tasks
4. See health appointments

### During Work
- **Lost the thread?** → `status`
- **Idea pops up?** → `journal "the idea"`
- **New task?** → `todo add "the task"`
- **Completed something?** → `todo done 1`

### Ending Work
- Run `goodevening` (needs to become habit)
- Review what was done
- Note what tomorrow-you should remember

### Weekly Review
- Check forgotten projects
- Review accumulated journal entries
- Clear old completed tasks
- Update health appointments

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
**Next Review:** When implementing Priority 1 enhancement