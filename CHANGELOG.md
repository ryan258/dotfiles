# **Dotfiles Evolution: A 20-Point Implementation Plan (Round 2)**

This document outlines the next 20-point plan to continue the evolution of the dotfiles system, building on the foundational work already completed. This revision prioritizes based on real-world usage analysis and system exploration findings.

**Status:** ✅ **20/20 Complete (100%)** - FINISHED
**Last Updated:** November 5, 2025 (Implementation Complete)
**Previous Round:** All 20 blindspots (1-20) completed November 2, 2025

## **📊 Implementation Progress**

| Phase | Status | Complete | Remaining |
|-------|--------|----------|-----------|
| **Quick Wins** | ✅ DONE | 5/5 (100%) | 0 |
| **High Impact** | ✅ DONE | 6/6 (100%) | 0 |
| **Medium Priority** | ✅ DONE | 4/4 (100%) | 0 |
| **System Polish** | ✅ DONE | 5/5 (100%) | 0 |
| **TOTAL** | ✅ **100% DONE** | **20/20** | **0** |

**All work complete!**

## **Goals for Round 2:**

1.  **Fix Critical Data Integrity Gaps:** Address fragility in core systems before adding features.
2.  **Deepen Workflow Integrations:** Connect previously separate tools into seamless workflows.
3.  **Introduce Proactive Intelligence:** Make tools that learn from user behavior.
4.  **Enhance User Experience & Polish:** Improve feedback, interactivity, and aesthetics.

---

## **Phase 1: Critical Fixes & Data Integrity**

*Priority: HIGH - These address system fragility and data loss risks*

### **[Blindspot 21]: No "Undo" for Tasks** ✅ COMPLETE

*   **Critique:** If a user accidentally marks a task as done with `todo done`, there is no easy way to revert it. The task is moved to a separate file, and restoring it is a manual process. This is a critical UX gap that users will hit immediately.
*   **Implementation Status:** ✅ Implemented in todo.sh lines 139-154
*   **Implementation Plan:**
    1.  Create a new `todo.sh` subcommand: `todo undo`.
    2.  This command will read the last line from `todo_done.txt`, remove it from that file, and append it back to `todo.txt`.
    3.  It should print a confirmation message like "Restored task: [Task Text]".
    4.  Consider adding `todo undo 3` to restore the 3rd most recent completion.

### **[Blindspot 22]: Fragile Timestamp Gate** ✅ COMPLETE

*   **Critique:** `startday.sh` uses `/tmp/startday_run_today` to prevent running multiple times per day. However, `/tmp` is cleared on system reboot. If the system reboots mid-day, startday will run again on the next terminal, potentially causing confusion or duplicate operations.
*   **Implementation Status:** ✅ Implemented in .zshrc lines 23-39, uses persistent file at `~/.config/dotfiles-data/.startday_last_run`
*   **Implementation Plan:**
    1.  Move the timestamp gate file from `/tmp/startday_run_today` to `~/.config/dotfiles-data/.startday_last_run`.
    2.  Store the actual date (not just a flag) so you can detect rollovers correctly.
    3.  This makes the gate persistent across reboots.

### **[Blindspot 23]: Task Text Pipe Delimiter Risk** ✅ COMPLETE

*   **Critique:** Tasks are stored with pipe `|` delimiters for timestamps. If a user adds a task containing a literal `|` character, it will break parsing in scripts like `startday.sh` when detecting stale tasks.
*   **Implementation Status:** ✅ Implemented in todo.sh line 24, strips pipe characters on input: `task_text=$(echo "$task_text" | tr -d '|')`
*   **Implementation Plan:**
    1.  Modify `todo.sh` (`add` subcommand): Strip or escape pipe characters from task text before saving.
    2.  Alternatively, use a more robust delimiter like `::` or switch to a different format (tab-delimited).
    3.  Add a migration step to clean existing tasks if needed.

### **[Blindspot 24]: No Data Validation Mechanism** ✅ COMPLETE

*   **Critique:** Data files (`todo.txt`, `health.txt`, `journal.txt`) are manually edited by scripts. If corruption occurs (disk error, interrupted write, manual editing mistake), there's no detection or recovery mechanism.
*   **Implementation Status:** ✅ Implemented in data_validate.sh, validates format of all data files and suggests backup restoration if errors found
*   **Implementation Plan:**
    1.  Create a new script: `data_validate.sh`.
    2.  Check each data file for:
        *   Existence and readability
        *   Proper format (line count, delimiter presence)
        *   Timestamp validity
    3.  Run this automatically in `goodevening.sh` before backup.
    4.  If corruption is detected, log a warning and optionally restore from the most recent backup.

### **[Blindspot 25]: Error Suppression Hides Real Issues** ✅ COMPLETE

*   **Critique:** `goodevening.sh` uses `2>/dev/null` to suppress git errors when checking for uncommitted changes. This masks real problems like git auth failures, corrupted repos, or permission issues.
*   **Implementation Status:** ✅ Implemented in goodevening.sh:112-118, 101-107, 194-197
*   **Implementation Plan:**
    1.  Modify `goodevening.sh`: Remove `2>/dev/null` from git commands.
    2.  Add explicit error handling: Check `$?` after each git command and log meaningful error messages.
    3.  For expected errors (like "not a git repo"), handle them gracefully without suppression.

### **[Blindspot 26]: Hardcoded Blog Directory Path** ✅ COMPLETE

*   **Critique:** `blog.sh` and related functions have `~/Projects/my-ms-ai-blog` hardcoded throughout. This makes the system fragile if the blog is moved, renamed, or if you want to use the system for a different blog.
*   **Implementation Status:** ✅ Implemented in .zprofile line 8 and blog.sh line 6, uses `BLOG_DIR` env var with fallback to default
*   **Implementation Plan:**
    1.  Add `BLOG_DIR` environment variable to `.zprofile`.
    2.  Update `blog.sh` to read from `$BLOG_DIR` instead of the hardcoded path.
    3.  Fall back to the current path if `BLOG_DIR` is not set (backwards compatibility).
    4.  Update documentation to show how users can customize this.

---

## **Phase 2: High-Impact Integrations**

*Priority: MEDIUM-HIGH - These provide significant productivity gains*

### **[Blindspot 27]: Disconnected Reminders & Scheduling** ✅ COMPLETE

*   **Critique:** The `remind_me.sh` and `schedule.sh` tools are fire-and-forget. They are not integrated with the `todo.sh` system, creating two separate places for tasks and reminders.
*   **Implementation Status:** ✅ Already implemented in schedule.sh:17-26
*   **Implementation Plan:**
    1.  Modify `schedule.sh`: Add a `--todo` flag.
    2.  `schedule "tomorrow 9am" --todo "Call the doctor"` would schedule the task to be *added* to `todo.txt` at the specified time, rather than just sending a notification.
    3.  This turns the scheduler into a "snooze" or "defer" feature for the todo list.
    4.  Update documentation and add to cheatsheet.

### **[Blindspot 28]: Health ↔ Task Correlation Missing** ✅ COMPLETE

*   **Critique:** The `health.sh` data is valuable but completely isolated. There's no way to see if low energy levels correlate with fewer completed tasks or reduced git activity. This insight would be valuable for both the user and medical professionals.
*   **Implementation Status:** ✅ Implemented in health.sh:8-116, functions correlate_tasks and correlate_commits
*   **Implementation Plan:**
    1.  Modify `health.sh` (`dashboard` subcommand): Enhance the dashboard to cross-reference data.
    2.  It should pull data from `todo_done.txt` to calculate "Average tasks completed on low-energy days (1-4)" vs. "high-energy days (7-10)".
    3.  Similarly, parse git logs from `~/Projects` to show "Git commits on low-energy days" vs. "high-energy days".
    4.  Add this as a new section in the 30-day dashboard: "Energy vs. Productivity Correlation".

### **[Blindspot 29]: "Smart" Navigation - Missing Usage Logging** ✅ COMPLETE

*   **Critique:** The `g suggest` command is already implemented with a smart frequency/recency scoring algorithm (lines 60-81 in g.sh), but the `USAGE_LOG` file is never written to. The feature exists but has no data to work with.
*   **Implementation Status:** ✅ Implemented in g.sh:97 and .zshrc:41-48
*   **Current State:**
    -   ✅ `g suggest` algorithm is complete and functional
    -   ✅ Logging mechanism populates the usage data
*   **Implementation Plan:**
    1.  Modify `g.sh`: Add logging in the default action (bookmark navigation) to write `timestamp:directory` to `$USAGE_LOG`.
    2.  Create a `cd` wrapper function in `.zshrc` that logs every directory change to `$USAGE_LOG`.
    3.  Alternatively, hook into zsh's `chpwd` function for automatic logging.
    4.  Once logging is active, `g suggest` will immediately start providing intelligent recommendations.
    5.  Add `g suggest` output to `startday` to surface frequently-used directories each morning.

### **[Blindspot 30]: "Manual" Weekly Review Automation** ✅ COMPLETE

*   **Critique:** The `week_in_review.sh` script is useful but relies on the user to remember to run it. A weekly summary should be an automated artifact saved for future reference.
*   **Implementation Status:** ✅ LaunchAgent created at ~/Library/LaunchAgents/com.dotfiles.weeklyreview.plist, runs every Sunday at 8 PM
*   **Implementation Plan:**
    1.  Modify `week_in_review.sh`: Add a `--file` flag that saves the output to a timestamped markdown file, e.g., `~/Documents/Reviews/Weekly/2025-W45.md`.
    2.  Create the `~/Documents/Reviews/Weekly/` directory structure if it doesn't exist.
    3.  Use `schedule.sh` or a LaunchAgent to set up a recurring job (every Sunday at 8 PM) that automatically runs `week_in_review.sh --file`.
    4.  Add a summary in `startday` on Mondays: "Last week's review saved to: [path]".

---

## **Phase 3: Intelligence & Proactive Features**

*Priority: MEDIUM - These improve UX and reduce friction*

### **[Blindspot 31]: "Silent" Task Management** ✅ COMPLETE

*   **Critique:** The `todo.sh` script is functional but lacks positive reinforcement. Completing a task is a quiet, anticlimactic event that provides no dopamine hit for people with brain fog who need encouragement.
*   **Implementation Status:** ✅ Implemented in todo.sh lines 28-33 (add) and 61-67 (done), shows random encouraging messages
*   **Implementation Plan:**
    1.  Modify `todo.sh` (`done` subcommand): After a task is completed, print a random encouraging message from an array (e.g., "Great job! 🎯", "Another one bites the dust!", "You're on fire!", "Progress! Keep going!").
    2.  Modify `todo.sh` (`add` subcommand): After adding a task, confirm with encouraging messages like "Task added. You've got this! 💪" or "Captured! One less thing to remember."
    3.  Keep messages brief and energizing.

### **[Blindspot 32]: "Static" Morning Routine** ✅ COMPLETE

*   **Critique:** The `startday.sh` script presents the same categories of information every single day. Over time, this can lead to it being ignored or becoming background noise.
*   **Implementation Status:** ✅ Implemented in focus.sh, integrated into startday.sh lines 12-16, use `focus "Your goal"` to set daily focus
*   **Implementation Plan:**
    1.  Create a "focus of the day" feature using `~/.config/dotfiles-data/daily_focus.txt`.
    2.  Modify `startday.sh`: At the very top, display the "**Focus for Today:**" if set, making it prominent.
    3.  Add a `focus` command/script: `focus "Ship the new API"` sets it, `focus` alone shows it, `focus clear` removes it.
    4.  This gives each day a clear anchor point even when brain fog is high.

### **[Blindspot 33]: "Unaware" Script Creation** ✅ COMPLETE

*   **Critique:** The `new_script.sh` command is helpful but "naive." It will happily create a script and an alias that collides with an existing command or alias, potentially causing unexpected behavior.
*   **Implementation Status:** ✅ Implemented in new_script.sh:17-62, checks for collisions with scripts, aliases, and system commands
*   **Implementation Plan:**
    1.  Modify `new_script.sh`: Before creating the script or alias, check if the proposed name is already in use.
    2.  Check against: 1) existing aliases in `aliases.zsh`, 2) other scripts in `scripts/` directory, 3) commands in system `PATH` (using `command -v`).
    3.  If a collision is detected, warn the user with specifics ("'todo' already exists as an alias") and exit without making changes.
    4.  Add `--force` flag to override if user really wants the collision.

### **[Blindspot 34]: "Brain Dump" Quick Capture for Long-Form Thoughts** ✅ COMPLETE

*   **Critique:** `journal "text"` is perfect for one-liners, but on severe brain fog days when you need to dump multiple paragraphs or stream-of-consciousness thoughts, typing a long string in quotes is awkward. There's no quick way to open an editor and just write freely.
*   **Implementation Status:** ✅ Implemented in dump.sh, opens $EDITOR for long-form capture, appends to journal with timestamp
*   **Distinction:**
    -   `journal "text"` - Quick one-liner capture (already minimal friction) ✅
    -   `dump` - Multi-paragraph brain dumps via editor ✅
*   **Implementation Plan:**
    1.  Create `dump.sh`: Opens `$EDITOR` with a temp file pre-populated with timestamp header.
    2.  When saved and closed, appends the entire contents to `journal.txt` with timestamp.
    3.  If temp file is empty (user quit without writing), do nothing.
    4.  Make it forgiving: No validation, no structure required, just capture.
    5.  Add to `cheatsheet`: "Foggy brain? Multi-paragraph thoughts? Just `dump`!"
    6.  This complements journal for different capture modes: quick vs. long-form.

### **[Blindspot 35]: Howto Search Not Ranked by Recency** ✅ COMPLETE

*   **Critique:** `journal search` already defaults to showing newest results first (line 36 sets `sort_order="recent"`), but `howto list` doesn't sort by modification time. When reviewing how-to articles, the most recently updated guides are likely most relevant but get buried in alphabetical order.
*   **Implementation Status:** ✅ Fixed howto.sh line 32, now uses `ls -t` to sort by modification time (newest first)
*   **Current State:**
    -   ✅ `journal search` already defaults to recent-first with `--oldest` flag for chronological
    -   ✅ `howto list` now sorts by modification time
*   **Implementation Plan:**
    1.  Modify `howto.sh` (`list` subcommand): Use `ls -lt` instead of `ls` to sort by modification time (newest first).
    2.  Add a `--alpha` flag to revert to alphabetical sorting if needed.
    3.  Consider adding a `howto search <term>` subcommand that uses `grep` with recent-first ordering like journal search.
    4.  Document the existing `journal search` behavior in the cheatsheet (already works correctly!).

---

## **Phase 4: System Polish & Advanced Tooling**

*Priority: LOW-MEDIUM - Nice-to-have improvements*

### **[Blindspot 36]: "Fragile" Bootstrap Process** ✅ COMPLETE

*   **Critique:** The `bootstrap.sh` script is not fully idempotent. If run a second time, it may cause unintended side effects or fail on already-created symlinks/files.
*   **Implementation Status:** ✅ Enhanced bootstrap.sh:37-59 with safe symlink checks and data file initialization
*   **Implementation Plan:**
    1.  Modify `bootstrap.sh`: Add checks before performing any action.
    2.  Before creating a symlink, check if it already exists and points to the correct location.
    3.  Before installing a dependency, check if it's already installed (`command -v`, `brew list`).
    4.  The script should be safe to run multiple times, only making changes that are actually needed.
    5.  Add a `--force` flag to re-do everything if needed.

### **[Blindspot 37]: No "Dry-Run" Mode for Destructive Scripts** ✅ COMPLETE

*   **Critique:** Scripts that perform destructive or significant file operations (`tidy_downloads.sh`, `review_clutter.sh`, `file_organizer.sh`) lack a "dry-run" mode. Users must trust they'll do the right thing.
*   **Implementation Status:** ✅ Already implemented in tidy_downloads.sh:4-8, review_clutter.sh:6-10, file_organizer.sh:4-8
*   **Implementation Plan:**
    1.  Modify these scripts to accept a `--dry-run` or `-n` flag.
    2.  When this flag is present, print the actions that *would* be taken (e.g., "Would move file.jpg to Images/") without actually performing them.
    3.  This builds trust and allows users to verify behavior before committing.

### **[Blindspot 38]: "Naive" File Organization Safety** ✅ COMPLETE

*   **Critique:** `tidy_downloads.sh` is a blunt instrument. It moves files based on extension, but could accidentally move files currently being downloaded or actively used by applications.
*   **Implementation Status:** ✅ Implemented in tidy_downloads.sh:4-59, with safety checks for recent files and ignore patterns
*   **Implementation Plan:**
    1.  Modify `tidy_downloads.sh`: Before moving a file, check if it has been modified in the last 60 seconds using `find -mmin -1`.
    2.  Skip files that are "hot" (recently modified).
    3.  Add a configuration file `~/.config/dotfiles-data/tidy_ignore.txt` where users can list filenames or patterns to always ignore.
    4.  Add `--force` flag to override safety checks if needed.

### **[Blindspot 39]: "Orphaned" Bookmarks** ✅ COMPLETE

*   **Critique:** If a directory bookmarked with `g.sh` is deleted or renamed, the bookmark becomes a "dead link" that causes an error. There's no built-in way to clean these up.
*   **Implementation Status:** ✅ Implemented g prune command in g.sh:83-136, integrated into dotfiles_check.sh:65-71
*   **Implementation Plan:**
    1.  Create a new subcommand for `g.sh`: `g prune`.
    2.  This command reads the bookmarks file, checks if each directory still exists, and interactively prompts to remove dead bookmarks.
    3.  Add `g prune --auto` to remove all dead links without prompting.
    4.  Run `g prune` automatically in `dotfiles_check.sh`.

### **[Blindspot 40]: Health Export Missing Medication Data** ✅ COMPLETE

*   **Critique:** The `health export` command creates a markdown file for doctors but doesn't include medication data from `meds.sh`. This is incomplete for medical appointments.
*   **Implementation Status:** ✅ Implemented in health.sh:321-372, includes medication list, adherence rates, and recent doses
*   **Implementation Plan:**
    1.  Modify `health.sh` (`export` subcommand): Pull medication data from `~/.config/dotfiles-data/medications.txt`.
    2.  Add a "Current Medications" section to the export with:
        *   Medication names and dosages
        *   Adherence rate from `meds dashboard`
        *   Recent missed doses
    3.  This creates a complete medical snapshot for appointments.

---

## **Summary & Implementation Priority**

### **✅ All Phases Complete (20/20):**

**Phase 1: Quick Wins (5/5)**
- ✅ Blindspot 21: Todo undo
- ✅ Blindspot 26: Blog directory env var
- ✅ Blindspot 31: Silent task encouragement
- ✅ Blindspot 34: Brain dump capture
- ✅ Blindspot 35: Howto list sorting

**Phase 2: High Impact (6/6)**
- ✅ Blindspot 22: Fix timestamp gate fragility
- ✅ Blindspot 23: Task text delimiter safety
- ✅ Blindspot 24: Data validation mechanism
- ✅ Blindspot 25: Error handling in goodevening
- ✅ Blindspot 28: Health ↔ Task correlation
- ✅ Blindspot 32: Daily focus feature

**Phase 3: Medium Priority (4/4)**
- ✅ Blindspot 27: Scheduler ↔ todo integration
- ✅ Blindspot 29: Smart navigation logging
- ✅ Blindspot 30: Weekly review automation
- ✅ Blindspot 33: Script creation collision detection

**Phase 4: System Polish (5/5)**
- ✅ Blindspot 36: Idempotent bootstrap
- ✅ Blindspot 37: Dry-run modes
- ✅ Blindspot 38: File organization safety
- ✅ Blindspot 39: Orphaned bookmark pruning
- ✅ Blindspot 40: Health export with meds

### **🎉 All 20 blindspots completed!**

---

## **Revision History**

### **November 5, 2025 - Implementation Complete 🎉**

**Status:** 20/20 blindspots complete (100%)
**Implementation Time:** ~4 hours total session

**Completed in this session:**
- ✅ Blindspot 25: Error handling in goodevening.sh
- ✅ Blindspot 28: Health ↔ task correlation with productivity metrics
- ✅ Blindspot 29: Smart navigation usage logging (chpwd hook)
- ✅ Blindspot 30: Weekly review automation (LaunchAgent)
- ✅ Blindspot 33: Collision detection in new_script.sh
- ✅ Blindspot 36: Idempotent bootstrap with safety checks
- ✅ Blindspot 38: File organization safety (recently modified files, ignore patterns)
- ✅ Blindspot 39: Bookmark pruning command (g prune)
- ✅ Blindspot 40: Medication data in health export

**Already implemented (discovered during review):**
- ✅ Blindspot 27: Scheduler ↔ todo integration (--todo flag existed)
- ✅ Blindspot 37: Dry-run modes (all scripts had them)

**Key improvements:**
- Enhanced error handling throughout system
- Added safety checks for file operations
- Implemented smart directory tracking
- Automated weekly reviews via LaunchAgent
- Comprehensive health exports with medication data
- Better script creation safety with collision detection

### **November 5, 2025 - Previous Session**

**Status:** 9/20 blindspots complete (45%)
**Completed:** Blindspots 21, 22, 23, 24, 26, 31, 32, 34, 35

Many blindspots were discovered to already be implemented:
- Todo undo, timestamp gate, pipe safety, BLOG_DIR, focus, task encouragement
- Data validation script existed but was malformed - fixed
- Created new: dump.sh for brain dumps
- Fixed: howto.sh sorting to use recency

### **November 5, 2025 - Final Review & Corrections**
After comprehensive system exploration and code review, made the following corrections:

**Blindspot 29 (Smart Navigation):**
- **Discovery:** `g suggest` algorithm is already fully implemented (lines 60-81 in g.sh)
- **Real Issue:** No logging mechanism populates the usage data
- **Updated Plan:** Focus on adding logging hooks, not building the algorithm

**Blindspot 35 (Search Ranking):**
- **Discovery:** `journal search` already defaults to recent-first (line 36 in journal.sh)
- **Real Issue:** Only `howto list` lacks recency sorting
- **Updated Plan:** Fix howto sorting, document existing journal behavior

**Blindspot 34 (Brain Dump):**
- **Clarification:** Distinguishes between `journal` (one-liners) and `dump` (long-form editor capture)
- **Value Proposition:** Complements existing journal for different capture modes

### **November 5, 2025 - Initial Draft**
The original blindspots have been reorganized and re-prioritized based on system exploration findings. Key changes:
- Critical data integrity issues moved to Phase 1
- High-value integrations promoted to Phase 2
- Cosmetic improvements demoted to Phase 4
- 10 new blindspots added based on real-world usage patterns

**Status:** Ready for implementation. All 20 blindspots reviewed and approved.

---

# **Dotfiles Evolution: A 20-Point Implementation Plan**

This document outlines a 20-point plan to evolve the existing dotfiles system. The goals are to:

1. **Increase Resilience:** Add data backups and system health checks.  
2. **Add Proactive Intelligence:** Turn data logs into actionable insights and trend analysis.  
3. **Reduce Friction:** Automate system maintenance and streamline complex workflows.  
4. **Integrate Siloed Tools:** Connect the todo system with git, the blog, and the journal.  
5. **Strengthen Cognitive Support:** Implement proactive nudges, focus tools, and just-in-time help to actively combat brain fog and perfectionism.

## **Phase 1: Resilience & Data Insight**

### **✅ [Blindspot 1]: Data Resilience**

* **Critique:** The system's core data in ~/.config/dotfiles-data/ is not automatically backed up, creating a single point of failure.  
* **Implementation Plan:**  
  1. Create a new script: scripts/backup_data.sh.  
  2. This script will compress the *entire* ~/.config/dotfiles-data/ directory into a timestamped .tar.gz file.  
  3. The script should save this backup to a user-configurable, safe location (e.g., ~/Backups/dotfiles_data/).  
  4. Modify scripts/goodevening.sh: Add a line at the end to *silently* run backup_data.sh.  
* **Target Files:**  
  * scripts/backup_data.sh (New)  
  * scripts/goodevening.sh (Modified)

### **✅ [Blindspot 2]: Data Insight**

* **Critique:** health.sh and meds.sh are good at capturing data but provide no long-term trend analysis.  
* **Implementation Plan:**  
  1. Modify scripts/health.sh: Add a new dashboard subcommand.  
     * This command will use awk and grep on health.txt to calculate and print stats for the last 30 days: "Average energy level", "Symptom frequency (e.g., Fatigue: 12 times)", "Average energy on days 'fog' was logged".  
  2. Modify scripts/meds.sh: Add a new dashboard subcommand.  
     * This command will parse medication schedules and dose logs to calculate and print adherence percentages (e.g., "Medication X Adherence (30d): 92% (55/60 doses)").  
* **Target Files:**  
  * scripts/health.sh (Modified)  
  * scripts/meds.sh (Modified)

### **✅ [Blindspot 3]: Stale Task Accumulation**

* **Critique:** todo.sh is a flat list that can accumulate stale tasks, causing anxiety.  
* **Implementation Plan:**  
  1. Modify scripts/todo.sh (add subcommand): Prepend a YYYY-MM-DD| timestamp to each new task (e.g., echo "$(date +%Y-%m-%d)|$task_text" >> "$TODO_FILE").  
  2. Modify scripts/todo.sh (list subcommand): Update the cat -n command to use awk to parse the timestamp and print it, while still printing the line number.  
  3. Modify scripts/startday.sh: Add a new "⏰ STALE TASKS" section. This will parse todo.txt and print any tasks with a timestamp older than 7 days.  
* **Target Files:**  
  * scripts/todo.sh (Modified)  
  * scripts/startday.sh (Modified)

### **✅ [Blindspot 4]: System Fragility**

* **Critique:** The complex system has deferred dependency checks. A missing tool (jq) or script could cause a silent failure.  
* **Implementation Plan:**  
  1. Create scripts/dotfiles_check.sh: This "doctor" script will validate the full system.  
  2. It must verify: 1) Key script files exist, 2) ~/.config/dotfiles-data exists, 3) Binary dependencies (jq, curl, gawk, osascript) are in the PATH, 4) ~/.github_token exists.  
  3. It should print a simple "All systems OK" or a detailed list of errors.  
  4. Add an alias: alias dotfiles_check="dotfiles_check.sh".  
* **Target Files:**  
  * scripts/dotfiles_check.sh (New)  
  * zsh/aliases.zsh (Modified)

## **Phase 2: Friction Reduction & Usability**

### **✅ [Blindspot 5]: "Write-Only" Journal**

* **Critique:** journal.sh is excellent for capture but has poor retrieval, limiting its use as a "second brain".  
* **Implementation Plan:**  
  1. Modify scripts/journal.sh: Add a search <term> subcommand. This will be a user-friendly wrapper for grep -i "$term" $JOURNAL_FILE.  
  2. Modify scripts/journal.sh: Add an onthisday subcommand. This will grep the journal for entries with the current month and day from previous years (e.g., grep -i "....-$(date +%m-%d)" $JOURNAL_FILE).  
* **Target Files:**  
  * scripts/journal.sh (Modified)

### **✅ [Blindspot 6]: System Maintenance Friction**

* **Critique:** Adding new scripts or setting up a new machine is a high-friction, manual process.  
* **Implementation Plan:**  
  1. Create bootstrap.sh in the repo root: This script will automate new machine setup (install Homebrew, brew install dependencies, create data dir, symlink dotfiles).  
  2. Create scripts/new_script.sh: This script will automate adding new tools.  
     * Input: new_script.sh my_tool  
     * Action: Creates scripts/my_tool.sh, adds #!/bin/bash and set -euo pipefail, makes it executable, *and* appends alias my_tool="my_tool.sh" to zsh/aliases.zsh.  
* **Target Files:**  
  * bootstrap.sh (New)  
  * scripts/new_script.sh (New)  
  * zsh/aliases.zsh (Modified by new_script.sh)

### **✅ [Blindspot 7]: High-Cost Context Switching**

* **Critique:** Navigation is split across three redundant tools (goto, recent_dirs, workspace_manager).  
* **Implementation Plan:**  
  1. Create scripts/g.sh: This new, consolidated navigation script will replace the old ones.  
  2. Implement subcommands: g <bookmark> (for goto), g -r (for recent_dirs), g -s <name> (for workspace save), g -l <name> (for workspace load).  
  3. Add "Context-Aware Hook" logic: g.sh should parse a config file (e.g., dir_bookmarks) that can store an optional "on-enter" command (e.g., blog:~/Projects/blog:blog status). When g blog is run, it will cd *and* execute blog status.  
  4. Modify zsh/aliases.zsh: Remove old aliases for goto, back, workspace and add alias g="source g.sh" (must be sourced to change directory).  
* **Target Files:**  
  * scripts/g.sh (New)  
  * zsh/aliases.sh (Modified)  
  * scripts/goto.sh (Deprecated)  
  * scripts/recent_dirs.sh (Deprecated)  
  * scripts/workspace_manager.sh (Deprecated)

### **✅ [Blindspot 8]: The Documentation Chasm**

* **Critique:** Help is either "all" (cheatsheet.sh) or "nothing" (failing silently).  
* **Implementation Plan:**  
  1. Modify all core scripts (todo.sh, health.sh, meds.sh, journal.sh, etc.): Update the *) case in the case "$1" in block. It must: 1) Print a clear "Error: Unknown command '$1'" to stderr, 2) Print the full usage/help message, 3) exit 1. This provides "Just-in-Time" help.  
  2. Create scripts/whatis.sh: This script will search zsh/aliases.zsh and scripts/README.md for a command and print the matching line (e.g., whatis gaa -> alias gaa="git add .").  
  3. Add alias: alias whatis="whatis.sh".  
* **Target Files:**  
  * All scripts with case "$1" in blocks (Modified)  
  * scripts/whatis.sh (New)  
  * zsh/aliases.zsh (Modified)

## **Phase 3: Proactive Automation & Nudges**

### **✅ [Blindspot 9]: Passive Health System**

* **Critique:** The health system is manual ("write-only"), which fails on low-energy days.  
* **Implementation Plan:**  
  1. Modify scripts/goodevening.sh: Make it *interactive*. Add prompts that ask "How was your energy today (1-10)?" and "Any symptoms to log?". If input is provided, pipe it to health.sh energy "$input" or health.sh symptom "$input".  
  2. Automate meds.sh remind: Add a cron job (or launchd agent) to run the meds.sh remind command at user-defined intervals (e.g., 8am, 8pm), which will trigger the osascript notification.  
* **Target Files:**  
  * scripts/goodevening.sh (Modified)  
  * (Requires crontab -e or launchd config, which is outside the repo)

### **✅ [Blindspot 10]: Siloed "Blog" and "Dotfiles" Systems**

* **Critique:** Your #1 priority, the blog, is disconnected from your main todo.sh productivity loop.  
* **Implementation Plan:**  
  1. Modify scripts/blog.sh: Add a sync_tasks subcommand. This script will: 1) Get all stubs from blog stubs, 2. Get all tasks from todo list, 3. For any stub not already in todo.txt (e.g., as "BLOG: <stub_name>"), add it via todo.sh add "BLOG: <stub_name>".  
  2. Modify scripts/startday.sh: Add a call to blog sync_tasks to run it automatically each morning.  
  3. Modify scripts/blog.sh: Add an ideas subcommand that simply runs journal.sh search "blog idea".  
* **Target Files:**  
  * scripts/blog.sh (Modified)  
  * scripts/startday.sh (Modified)

### **✅ [Blindspot 11]: Actively Fighting Perfectionism**

* **Critique:** The system documents the "anti-perfectionism" goal but doesn't actively *nudge* you towards it.  
* **Implementation Plan:**  
  1. Modify scripts/goodevening.sh: "Gamify" progress. If *any* tasks were completed, print "🎉 Win: You completed X task(s) today. Progress is progress." If *any* journal entries were made, print "🧠 Win: You logged Y entries. Context captured." If both are zero, print "Today was a rest day. Logging off is a valid and productive choice."  
  2. Modify zsh/aliases.zsh: Add alias pomo="take_a_break.sh 25". This weaponizes take_a_break.sh as a 25-minute Pomodoro timer.  
* **Target Files:**  
  * scripts/goodevening.sh (Modified)  
  * zsh/aliases.zsh (Modified)

### **✅ [Blindspot 12]: High-Friction "State" Management**

* **Critique:** Starting work requires multiple "setup tax" commands (cd, activate venv, launch apps).  
* **Implementation Plan:**  
  1. Evolve scripts/workspace_manager.sh into scripts/state_manager.sh (or just enhance the new scripts/g.sh).  
  2. The save command must also detect and save: 1) The path to venv/bin/activate if it exists, 2) A list of associated apps (e.g., g -a code to link the "code" app).  
  3. The load command (g <name>) must: 1) cd to the directory, 2) *Automatically* source the venv if one is saved, 3) *Automatically* launch all linked apps via app_launcher.sh.  
* **Target Files:**  
  * scripts/workspace_manager.sh (Modified) or scripts/g.sh (Modified)  
  * scripts/app_launcher.sh (May need modification to be called by another script)

## **Phase 4: Intelligent Workflow Integration**

### **✅ [Blindspot 13]: "Git Commit" Context Gap**

* **Critique:** todo.sh (intent) and git (action) are disconnected.  
* **Implementation Plan:**  
  1. Modify scripts/todo.sh: Add a commit subcommand.  
  2. todo commit <num> "message" will: 1) Run git commit -m "message", 2) Run the internal logic for todo done <num>.  
  3. todo commit <num> (with no message) will: 1) Extract the task text for <num>, 2) Run git commit -m "Done: [Task Text]", 3) Run the internal logic for todo done <num>.  
* **Target Files:**  
  * scripts/todo.sh (Modified)

### **✅ [Blindspot 14]: "Now vs. Later" Task Ambiguity**

* **Critique:** todo.sh is a flat list that creates cognitive load.  
* **Implementation Plan:**  
  1. Modify scripts/todo.sh: Add a bump <num> subcommand that moves the specified task to the top of todo.txt.  
  2. Modify scripts/todo.sh: Add a top <count> subcommand that prints only the top <count> tasks.  
  3. Modify zsh/aliases.zsh: Add alias next="todo top 1".  
  4. Modify scripts/startday.sh and scripts/status.sh: Change the "TODAY'S TASKS" section to only show todo top 3 instead of the full list.  
* **Target Files:**  
  * scripts/todo.sh (Modified)  
  * zsh/aliases.zsh (Modified)  
  * scripts/startday.sh (Modified)  
  * scripts/status.sh (Modified)

### **✅ [Blindspot 15]: The "Command Black Hole"**

* **Critique:** No system exists for scheduling a command or reminder for a *specific* future time.  
* **Implementation Plan:**  
  1. Create scripts/schedule.sh: This script will be a user-friendly wrapper for the macOS at command.  
  2. schedule.sh "2:30 PM" "remind 'Call Mom'" will echo "remind 'Call Mom'" | at 2:30 PM.  
  3. Modify scripts/startday.sh: Add a new "SCHEDULED TASKS" section that runs atq (which lists pending at jobs).  
* **Target Files:**  
  * scripts/schedule.sh (New)  
  * scripts/startday.sh (Modified)

### **✅ [Blindspot 16]: "Static" Clipboard Manager**

* **Critique:** clipboard_manager.sh only loads static text, wasting potential.  
* **Implementation Plan:**  
  1. Modify scripts/clipboard_manager.sh (load subcommand): If the file being loaded (e.g., ~/.config/dotfiles-data/clipboard_history/my_snippet) is *executable* ([-x "$file_path"]), the script must *execute it* and pipe its stdout to pbcopy, rather than cat-ing its content.  
  2. Create a dynamic snippet: echo "#!/bin/bash
git branch --show-current" > ~/.config/dotfiles-data/clipboard_history/gitbranch && chmod +x ~/.config/dotfiles-data/clipboard_history/gitbranch.  
* **Target Files:**  
  * scripts/clipboard_manager.sh (Modified)

## **Phase 5: Advanced Knowledge & Environment**

### **✅ [Blindspot 17]: "How-To" Memory Gap**

* **Critique:** cheatsheet.sh is too generic. A personal, searchable "how-to" wiki for complex workflows is missing.  
* **Implementation Plan:**  
  1. Create scripts/howto.sh: This script will manage text files in ~/.config/dotfiles-data/how-to/.  
  2. Implement howto add <name>: Opens ~/.config/dotfiles-data/how-to/<name>.txt in $EDITOR.  
  3. Implement howto <name>: cats the content of the file.  
  4. Implement howto search <term>: greps all files in the how-to directory.  
  5. Add alias: alias howto="howto.sh".  
* **Target Files:**  
  * scripts/howto.sh (New)  
  * zsh/aliases.zsh (Modified)

### **✅ [Blindspot 18]: Digital Clutter Anxiety**

* **Critique:** tidy_downloads.sh is manual. Clutter on ~/Desktop and ~/Downloads builds up, causing stress.  
* **Implementation Plan:**  
  1. Create scripts/review_clutter.sh: This script will find files in ~/Desktop and ~/Downloads older than 30 days.  
  2. It will loop through each file and interactively prompt the user: (a)rchive, (d)elete, (s)kip?.  
  3. (a) moves to ~/Documents/Archives/YYYY-MM/, (d) runs rm, (s) does nothing.  
* **Target Files:**  
  * scripts/review_clutter.sh (New)

### **✅ [Blindspot 19]: "Magic" Automation Problem**

* **Critique:** As automation increases, the system becomes "magic" and untrustworthy. A lack of transparency is bad for a cognitive support system.  
* **Implementation Plan:**  
  1. Create a central audit log: ~/.config/dotfiles-data/system.log.  
  2. Modify all automated scripts (goodevening.sh task cleanup, startday.sh run, meds.sh remind, blog.sh sync_tasks) to append a simple, timestamped, human-readable log entry to system.log. (e.g., echo "$(date): goodevening.sh - Cleaned 3 old tasks." >> $SYSTEM_LOG_FILE).  
  3. Modify zsh/aliases.zsh: Add alias systemlog="tail -n 20 ~/.config/dotfiles-data/system.log".  
* **Target Files:**  
  * scripts/goodevening.sh (Modified)  
  * scripts/startday.sh (Modified)  
  * scripts/meds.sh (Modified)  
  * scripts/blog.sh (Modified)  
  * zsh/aliases.zsh (Modified)

### **✅ [Blindspot 20]: The VS Code Shell Conflict**

* **Critique:** The system fails in the VS Code terminal because VS Code runs a login shell (.zprofile) while Terminal.app runs an interactive shell (.zshrc), and aliases are in .zshrc.  
* **Implementation Plan:**  
  1. Modify zsh/.zprofile: Add the following line at the *very end* of the file:  
     # Source the interactive config for login shells to unify environments  
     [ -f "$ZDOTDIR/.zshrc" ] && source "$ZDOTDIR/.zshrc"

  2. This makes login shells (like VS Code's) also source the .zshrc file, loading all aliases and functions and unifying the two environments.  
* **Target Files:**  
  * zsh/.zprofile (Modified)
