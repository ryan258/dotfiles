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

This plan, derived from `blindspots.md`, outlines the next evolution of the dotfiles system. The goals are to increase resilience, add proactive intelligence, reduce friction, integrate siloed tools, and strengthen cognitive support.

### **Phase 1: Resilience & Data Insight**

*   **1. Data Resilience:** Automate backups of the `~/.config/dotfiles-data/` directory to a safe location.
*   **2. Data Insight:** Add `dashboard` subcommands to `health.sh` and `meds.sh` for trend analysis.
*   **3. Stale Task Accumulation:** Add timestamps to tasks in `todo.sh` and highlight stale tasks in `startday.sh`.
*   **4. System Fragility:** Create a `dotfiles_check.sh` "doctor" script to validate dependencies and system configuration.

### **Phase 2: Friction Reduction & Usability**

*   **5. "Write-Only" Journal:** Add `search` and `onthisday` subcommands to `journal.sh` for better retrieval.
*   **6. System Maintenance Friction:** Create `bootstrap.sh` for new machine setup and `new_script.sh` to automate adding new tools.
*   **7. High-Cost Context Switching:** Consolidate `goto`, `recent_dirs`, and `workspace_manager` into a single `g.sh` script with context-aware hooks.
*   **8. The Documentation Chasm:** Improve help messages in all core scripts and create a `whatis.sh` command to explain aliases.

### **Phase 3: Proactive Automation & Nudges**

*   **9. Passive Health System:** Make `goodevening.sh` interactive to prompt for health data and automate `meds.sh` reminders with cron.
*   **10. Siloed "Blog" and "Dotfiles" Systems:** Sync blog stubs with `todo.sh` and add a blog ideas search to `journal.sh`.
*   **11. Actively Fighting Perfectionism:** "Gamify" progress in `goodevening.sh` and add a `pomo` alias for a 25-minute Pomodoro timer.
*   **12. High-Friction "State" Management:** Evolve `workspace_manager.sh` to automatically save and load venv state and associated applications.

### **Phase 4: Intelligent Workflow Integration**

*   **13. "Git Commit" Context Gap:** Add a `commit` subcommand to `todo.sh` to commit and complete a task in one step.
*   **14. "Now vs. Later" Task Ambiguity:** Add `bump` and `top` subcommands to `todo.sh` for task prioritization.
*   **15. The "Command Black Hole":** Create `schedule.sh` as a user-friendly wrapper for the `at` command to schedule future commands.
*   **16. "Static" Clipboard Manager:** Allow `clipboard_manager.sh` to execute dynamic snippets.

### **Phase 5: Advanced Knowledge & Environment**

*   **17. "How-To" Memory Gap:** Create `howto.sh` to manage a personal, searchable "how-to" wiki.
*   **18. Digital Clutter Anxiety:** Create `review_clutter.sh` to interactively archive or delete old files from `~/Desktop` and `~/Downloads`.
*   **19. "Magic" Automation Problem:** Create a central audit log and modify automated scripts to log their actions.
*   **20. The VS Code Shell Conflict:** Source `.zshrc` from `.zprofile` to unify shell environments.

## ✅ Recent Wins

| Item | Date | Notes |
| ---- | ---- | ----- |
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
