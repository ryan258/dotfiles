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

Data Files (centralized in ~/.config/dotfiles-data/):
journal.txt                 # All journal entries
todo.txt                    # Active tasks
todo_done.txt              # Completed tasks
health.txt                 # Upcoming appointments (format: date|description)
dir_bookmarks              # Saved directory bookmarks
dir_history                # Recent directory history
favorite_apps              # Application launcher shortcuts
clipboard_history/         # Saved clipboard snippets
```

---

## ✅ Foundation & Hardening (COMPLETED)

**Goal:** Address critical technical debt and configuration issues that affect system reliability.
**Status:** ✅ Completed November 1, 2025 - All fixes implemented and tested

### Phase 1: Critical System Repairs ✅

#### Fix 2: Repair the Core Journaling Loop ✅
**Problem:** `journal.sh` writes to `~/journal.txt` but core scripts (`startday`, `status`, `goodevening`) read from `~/.daily_journal.txt`. This breaks the entire context-recovery loop.

**Action:**
- [x] Edit `scripts/journal.sh`: Changed to use `~/.config/dotfiles-data/journal.txt`
- [x] Edit `scripts/week_in_review.sh`: Updated all journal file references
- [x] Fixed awk compatibility issue (now uses `gawk` for pattern matching)

**Impact:** ✅ Journaling system fully functional and tested.

#### Fix 3: Centralize All Data Files ✅
**Problem:** Data scattered across home directory (`~/journal.txt`, `~/.daily_journal.txt`, `~/.todo_list.txt`, etc.) is fragile and hard to back up.

**Action:**
- [x] Created central data directory: `~/.config/dotfiles-data`
- [x] Updated all scripts to use centralized paths:
  - `todo.sh`: `~/.config/dotfiles-data/todo.txt` & `todo_done.txt`
  - `journal.sh`: `~/.config/dotfiles-data/journal.txt`
  - `health.sh`: `~/.config/dotfiles-data/health.txt`
  - `goto.sh`, `recent_dirs.sh`, `app_launcher.sh`, `clipboard_manager.sh`
- [x] Updated core loop scripts: `startday.sh`, `status.sh`, `goodevening.sh`, `week_in_review.sh`

**Impact:** ✅ Single backup location at `~/.config/dotfiles-data/`, cleaner home directory, all scripts tested.

### Phase 2: Simplification & Cleanup ✅

#### Fix 4: De-duplicate Redundant Scripts ✅
**Problem:** Multiple scripts doing the same thing creates confusion and maintenance burden.

**Action:**
- [x] Deleted redundant scripts: `memo.sh`, `quick_note.sh`, `script_67777906.sh`, `script_58131199.sh`
- [x] Removed all associated aliases from `zsh/aliases.zsh`

**Impact:** ✅ 4 redundant scripts removed, cleaner codebase, forces use of `journal.sh` for all notes.

#### Fix 5: Clean Up Shell Configuration ✅
**Problem:** `PATH` set in multiple files (`.zshrc`, `.zprofile`), redundant sourcing creates confusion.

**Action:**
- [x] Updated `zsh/.zprofile`: Added `path_prepend "$HOME/dotfiles/scripts"`, removed non-existent `scripts/bin`
- [x] Cleaned `zsh/.zshrc`: Removed redundant PATH exports and legacy `.zsh_aliases` sourcing

**Impact:** ✅ Clean separation: PATH in `.zprofile`, interactive config in `.zshrc`.

#### Fix 6: Modernize Aliases ✅
**Problem:** Hardcoded paths (`~/dotfiles/scripts/todo.sh`) are brittle. Now that `scripts/` is in PATH, simplify.

**Action:**
- [x] Updated ALL 50+ aliases in `zsh/aliases.zsh`: Changed `~/dotfiles/scripts/X.sh` → `X.sh`
- [x] All aliases now use simple script names

**Impact:** ✅ More portable, easier to reorganize files later.

### Phase 3: Robustness & Best Practices ✅

#### Fix 7: Harden Shell Scripts ✅
**Problem:** Scripts lack modern safeguards (set -euo pipefail, quoted variables, dependency checks).

**Action:**
- [x] Added `set -euo pipefail` to all critical daily-use scripts:
  - `todo.sh`, `journal.sh`, `health.sh`
  - `startday.sh`, `status.sh`, `goodevening.sh`, `week_in_review.sh`
- [x] All scripts already use proper variable quoting
- [x] Dependency checks deferred (not critical for core functionality)

**Impact:** ✅ Core scripts now fail fast and clearly. Critical daily workflows are hardened.

---

## ✅ Q4 2025 Objectives (COMPLETED)

All Next Round Objectives completed November 2, 2025.
All 20 Blindspots from 'Dotfiles Evolution: A 20-Point Implementation Plan' have been implemented and tested.

### 0. Remaining Fixes ✅
- ✅ Aliases fixed - All hardcoded paths removed in Fix 6 (Foundation & Hardening)
- ✅ Updated TODO_FILE path in greeting.sh
- ✅ Fixed weather.sh call to use PATH lookup

### 1. Morning Routine Reliability ✅
- **Goal:** Resolve the `startday.sh` parse error surfaced during login so the automated morning briefing never fails.
- **Completed:** No parse errors found. Script runs successfully in bash and zsh environments.
- **Deliverable:** ✅ Tested thoroughly, integrated health tracking without errors.

### 2. Daily Happy Path Documentation ✅
- **Goal:** Create `docs/happy-path.md` outlining the ideal morning → mid-day → evening flow.
- **Completed:** Comprehensive guide created with step-by-step instructions for brain fog days.
- **Deliverable:** ✅ `docs/happy-path.md` created, linked from `README.md` and `cheatsheet.sh`.

### 3. Health Context Expansion (Iteration 1) ✅
- **Goal:** Extend `health.sh` to capture symptom notes and daily energy ratings.
- **Completed:** Full symptom and energy tracking system implemented.
- **Deliverable:** ✅ New subcommands (`health symptom`, `health energy`, `health summary`), integrated into `startday` and `goodevening` dashboards.

## 🎯 Dotfiles Evolution: A 20-Point Implementation Plan

**Status:** ✅ ALL 20 BLINDSPOTS COMPLETED (November 2, 2025)

This plan, derived from `blindspots.md`, outlines the evolution of the dotfiles system. The goals are to increase resilience, add proactive intelligence, reduce friction, integrate siloed tools, and strengthen cognitive support.

### **Phase 1: Resilience & Data Insight** ✅

*   ✅ **1. Data Resilience:** Automated backups of `~/.config/dotfiles-data/` via `backup_data.sh`, called silently in `goodevening.sh`.
*   ✅ **2. Data Insight:** Added `dashboard` subcommands to `health.sh` (30-day trend analysis) and `meds.sh` (adherence tracking).
*   ✅ **3. Stale Task Accumulation:** Added timestamps to tasks in `todo.sh`, `startday.sh` highlights stale tasks (>7 days).
*   ✅ **4. System Fragility:** Created `dotfiles_check.sh` to validate scripts, data directory, dependencies (jq, curl, gawk, osascript), and GitHub token.

### **Phase 2: Friction Reduction & Usability** ✅

*   ✅ **5. "Write-Only" Journal:** Added `search` and `onthisday` subcommands to `journal.sh` for better retrieval.
*   ✅ **6. System Maintenance Friction:** Created `bootstrap.sh` for new machine setup and `new_script.sh` to automate adding new tools.
*   ✅ **7. High-Cost Context Switching:** Consolidated navigation into `g.sh` with bookmarks, recent dirs, context-aware hooks, venv/app management.
*   ✅ **8. The Documentation Chasm:** Improved help messages in all core scripts with error handling, created `whatis.sh` to explain aliases.

### **Phase 3: Proactive Automation & Nudges** ✅

*   ⚠️ **9. Passive Health System:** `meds.sh remind` implemented for automation. Interactive `goodevening.sh` health prompts available but commented out (optional feature).
*   ✅ **10. Siloed "Blog" and "Dotfiles" Systems:** `blog.sh` syncs stubs with `todo.sh` (runs in `startday.sh`), added `blog ideas` to search journal.
*   ✅ **11. Actively Fighting Perfectionism:** "Gamified" progress in `goodevening.sh` with win messages, added `pomo` alias for 25-minute Pomodoro timer.
*   ✅ **12. High-Friction "State" Management:** Enhanced `g.sh` to automatically save/load venv state and launch associated applications.

### **Phase 4: Intelligent Workflow Integration** ✅

*   ✅ **13. "Git Commit" Context Gap:** Added `commit` subcommand to `todo.sh` to commit and complete a task in one step.
*   ✅ **14. "Now vs. Later" Task Ambiguity:** Added `bump` and `top` subcommands to `todo.sh`, created `next` alias, updated `startday.sh`/`status.sh` to show top 3.
*   ✅ **15. The "Command Black Hole":** Created `schedule.sh` as wrapper for `at` command, `startday.sh` shows scheduled tasks via `atq`.
*   ✅ **16. "Static" Clipboard Manager:** Enhanced `clipboard_manager.sh` to execute dynamic snippets when files are marked executable.

### **Phase 5: Advanced Knowledge & Environment** ✅

*   ✅ **17. "How-To" Memory Gap:** Created `howto.sh` to manage personal searchable how-to wiki at `~/.config/dotfiles-data/how-to/`.
*   ✅ **18. Digital Clutter Anxiety:** Created `review_clutter.sh` to interactively archive or delete old files from `~/Desktop` and `~/Downloads`.
*   ✅ **19. "Magic" Automation Problem:** Created central audit log at `~/.config/dotfiles-data/system.log`, automated scripts log actions, added `systemlog` alias.
*   ✅ **20. The VS Code Shell Conflict:** `.zprofile` sources `.zshrc` to unify login/interactive shell environments.

## ✅ Recent Wins

| Item | Date | Notes |
| ---- | ---- | ----- |
| 20 Blindspots Implementation | 2025-11-02 | Verified and documented all 20 blindspots from the evolution plan. All features implemented and tested: data backups, health/meds dashboards, stale task tracking, system validation, enhanced journal search, navigation consolidation (g.sh), blog-todo sync, gamification, todo commit/bump/top, schedule wrapper, dynamic clipboard, howto wiki, clutter review, audit logging, and unified shell environments. |
| Backlog Implementation | 2025-11-01 | Completed all 4 backlog items: blog cadence nudges with age warnings, full medication tracking system (`meds.sh`), health export for medical appointments, automation safety nets in goodevening (uncommitted changes, large diffs, lingering branches, unpushed commits). |
| Foundation & Hardening (Phases 1-3) | 2025-11-01 | Fixed broken journaling loop, centralized all data to `~/.config/dotfiles-data/`, deleted 4 redundant scripts, cleaned up shell config, modernized all aliases, hardened core scripts with `set -euo pipefail`. |
| Q4 Objectives 0-3 | 2025-11-01 | Fixed remaining bugs, created Daily Happy Path guide, extended health.sh with symptom and energy tracking. |
| `docs/happy-path.md` | 2025-11-01 | Comprehensive daily workflow guide designed for brain fog days. |
| Health tracking expansion | 2025-11-01 | Added symptom logging, energy ratings (1-10), integrated into daily dashboards. |
| `status` overhaul | 2025-10-04 | Added location, git, journal, and task snapshots. |
| `goodevening` revamp | 2025-10-06 | Lists completed tasks, journal, dirty projects; prompts for tomorrow's note. |
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

**Last Updated:** November 2, 2025
**Next Review:** Q1 2026 - Foundation complete, all Q4 objectives shipped, all backlog items implemented. System is comprehensive and stable. Ready for new priorities.
