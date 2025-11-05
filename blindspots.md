# **Dotfiles Evolution: A 20-Point Implementation Plan (Round 2)**

This document outlines the next 20-point plan to continue the evolution of the dotfiles system, building on the foundational work already completed. This revision prioritizes based on real-world usage analysis and system exploration findings.

**Status:** 🟢 **9/20 Complete (45%)** - In Progress
**Last Updated:** November 5, 2025 (Implementation Session)
**Previous Round:** All 20 blindspots (1-20) completed November 2, 2025

## **📊 Implementation Progress**

| Phase | Status | Complete | Remaining |
|-------|--------|----------|-----------|
| **Quick Wins** | ✅ DONE | 5/5 (100%) | 0 |
| **High Impact** | 🟡 IN PROGRESS | 4/6 (67%) | 2 |
| **Medium Priority** | ❌ TODO | 0/4 (0%) | 4 |
| **System Polish** | ❌ TODO | 0/5 (0%) | 5 |
| **TOTAL** | 🟢 **45% DONE** | **9/20** | **11** |

**Estimated Remaining Work:** ~8-10 hours

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

### **[Blindspot 25]: Error Suppression Hides Real Issues**

*   **Critique:** `goodevening.sh` uses `2>/dev/null` to suppress git errors when checking for uncommitted changes. This masks real problems like git auth failures, corrupted repos, or permission issues.
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

### **[Blindspot 27]: Disconnected Reminders & Scheduling**

*   **Critique:** The `remind_me.sh` and `schedule.sh` tools are fire-and-forget. They are not integrated with the `todo.sh` system, creating two separate places for tasks and reminders.
*   **Implementation Plan:**
    1.  Modify `schedule.sh`: Add a `--todo` flag.
    2.  `schedule "tomorrow 9am" --todo "Call the doctor"` would schedule the task to be *added* to `todo.txt` at the specified time, rather than just sending a notification.
    3.  This turns the scheduler into a "snooze" or "defer" feature for the todo list.
    4.  Update documentation and add to cheatsheet.

### **[Blindspot 28]: Health ↔ Task Correlation Missing**

*   **Critique:** The `health.sh` data is valuable but completely isolated. There's no way to see if low energy levels correlate with fewer completed tasks or reduced git activity. This insight would be valuable for both the user and medical professionals.
*   **Implementation Plan:**
    1.  Modify `health.sh` (`dashboard` subcommand): Enhance the dashboard to cross-reference data.
    2.  It should pull data from `todo_done.txt` to calculate "Average tasks completed on low-energy days (1-4)" vs. "high-energy days (7-10)".
    3.  Similarly, parse git logs from `~/Projects` to show "Git commits on low-energy days" vs. "high-energy days".
    4.  Add this as a new section in the 30-day dashboard: "Energy vs. Productivity Correlation".

### **[Blindspot 29]: "Smart" Navigation - Missing Usage Logging**

*   **Critique:** The `g suggest` command is already implemented with a smart frequency/recency scoring algorithm (lines 60-81 in g.sh), but the `USAGE_LOG` file is never written to. The feature exists but has no data to work with.
*   **Current State:**
    -   ✅ `g suggest` algorithm is complete and functional
    -   ❌ No logging mechanism to populate the usage data
*   **Implementation Plan:**
    1.  Modify `g.sh`: Add logging in the default action (bookmark navigation) to write `timestamp:directory` to `$USAGE_LOG`.
    2.  Create a `cd` wrapper function in `.zshrc` that logs every directory change to `$USAGE_LOG`.
    3.  Alternatively, hook into zsh's `chpwd` function for automatic logging.
    4.  Once logging is active, `g suggest` will immediately start providing intelligent recommendations.
    5.  Add `g suggest` output to `startday` to surface frequently-used directories each morning.

### **[Blindspot 30]: "Manual" Weekly Review Automation**

*   **Critique:** The `week_in_review.sh` script is useful but relies on the user to remember to run it. A weekly summary should be an automated artifact saved for future reference.
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

### **[Blindspot 33]: "Unaware" Script Creation**

*   **Critique:** The `new_script.sh` command is helpful but "naive." It will happily create a script and an alias that collides with an existing command or alias, potentially causing unexpected behavior.
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

### **[Blindspot 36]: "Fragile" Bootstrap Process**

*   **Critique:** The `bootstrap.sh` script is not fully idempotent. If run a second time, it may cause unintended side effects or fail on already-created symlinks/files.
*   **Implementation Plan:**
    1.  Modify `bootstrap.sh`: Add checks before performing any action.
    2.  Before creating a symlink, check if it already exists and points to the correct location.
    3.  Before installing a dependency, check if it's already installed (`command -v`, `brew list`).
    4.  The script should be safe to run multiple times, only making changes that are actually needed.
    5.  Add a `--force` flag to re-do everything if needed.

### **[Blindspot 37]: No "Dry-Run" Mode for Destructive Scripts**

*   **Critique:** Scripts that perform destructive or significant file operations (`tidy_downloads.sh`, `review_clutter.sh`, `file_organizer.sh`) lack a "dry-run" mode. Users must trust they'll do the right thing.
*   **Implementation Plan:**
    1.  Modify these scripts to accept a `--dry-run` or `-n` flag.
    2.  When this flag is present, print the actions that *would* be taken (e.g., "Would move file.jpg to Images/") without actually performing them.
    3.  This builds trust and allows users to verify behavior before committing.

### **[Blindspot 38]: "Naive" File Organization Safety**

*   **Critique:** `tidy_downloads.sh` is a blunt instrument. It moves files based on extension, but could accidentally move files currently being downloaded or actively used by applications.
*   **Implementation Plan:**
    1.  Modify `tidy_downloads.sh`: Before moving a file, check if it has been modified in the last 60 seconds using `find -mmin -1`.
    2.  Skip files that are "hot" (recently modified).
    3.  Add a configuration file `~/.config/dotfiles-data/tidy_ignore.txt` where users can list filenames or patterns to always ignore.
    4.  Add `--force` flag to override safety checks if needed.

### **[Blindspot 39]: "Orphaned" Bookmarks**

*   **Critique:** If a directory bookmarked with `g.sh` is deleted or renamed, the bookmark becomes a "dead link" that causes an error. There's no built-in way to clean these up.
*   **Implementation Plan:**
    1.  Create a new subcommand for `g.sh`: `g prune`.
    2.  This command reads the bookmarks file, checks if each directory still exists, and interactively prompts to remove dead bookmarks.
    3.  Add `g prune --auto` to remove all dead links without prompting.
    4.  Run `g prune` automatically in `dotfiles_check.sh`.

### **[Blindspot 40]: Health Export Missing Medication Data**

*   **Critique:** The `health export` command creates a markdown file for doctors but doesn't include medication data from `meds.sh`. This is incomplete for medical appointments.
*   **Implementation Plan:**
    1.  Modify `health.sh` (`export` subcommand): Pull medication data from `~/.config/dotfiles-data/medications.txt`.
    2.  Add a "Current Medications" section to the export with:
        *   Medication names and dosages
        *   Adherence rate from `meds dashboard`
        *   Recent missed doses
    3.  This creates a complete medical snapshot for appointments.

---

## **Summary & Implementation Priority**

### **✅ Quick Wins COMPLETE (5/5):**
- ✅ Blindspot 21: Todo undo - DONE
- ✅ Blindspot 26: Blog directory env var - DONE
- ✅ Blindspot 31: Silent task encouragement - DONE
- ✅ Blindspot 34: Brain dump capture - DONE
- ✅ Blindspot 35: Howto list sorting - DONE

### **✅ High Impact - Partially Complete (4/6):**
- ✅ Blindspot 22: Fix timestamp gate fragility - DONE
- ✅ Blindspot 23: Task text delimiter safety - DONE
- ✅ Blindspot 24: Data validation mechanism - DONE
- ✅ Blindspot 32: Daily focus feature - DONE
- ❌ Blindspot 25: Error handling in goodevening (30 min) - TODO
- ❌ Blindspot 28: Health ↔ Task correlation (1-2 hours) - TODO

### **❌ Medium Priority - Not Started (0/4):**
- ❌ Blindspot 27: Scheduler ↔ todo integration (1 hour) - TODO
- ❌ Blindspot 29: Smart navigation logging (20 min) - TODO
- ❌ Blindspot 30: Weekly review automation (1 hour) - TODO
- ❌ Blindspot 33: Script creation collision detection (1 hour) - TODO

### **❌ Nice to Have - Not Started (0/5):**
- ❌ Blindspot 36: Idempotent bootstrap (1 hour) - TODO
- ❌ Blindspot 37: Dry-run modes (1 hour) - TODO
- ❌ Blindspot 38: File organization safety (45 min) - TODO
- ❌ Blindspot 39: Orphaned bookmark pruning (30 min) - TODO
- ❌ Blindspot 40: Health export with meds (45 min) - TODO

### **Remaining Work: ~8-10 hours across 11 blindspots**

---

## **Revision History**

### **November 5, 2025 - Implementation Session**

**Status:** 9/20 blindspots complete (45%)
**Completed:** Blindspots 21, 22, 23, 24, 26, 31, 32, 34, 35
**Remaining:** 11 blindspots (estimated 8-10 hours of work)

**What Was Completed:**
- ✅ All 5 Quick Wins
- ✅ 4 of 6 High Impact items
- ✅ 0 of 4 Medium Priority items
- ✅ 0 of 5 Polish items

Many blindspots were discovered to already be implemented during code review:
- Todo undo, timestamp gate, pipe safety, BLOG_DIR, focus, task encouragement already existed
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

*End of Document*
