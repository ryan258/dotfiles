# **Dotfiles Evolution: A 20-Point Implementation Plan (Round 2)**

This document outlines the next 20-point plan to continue the evolution of the dotfiles system, building on the foundational work already completed. The goals for this round are to:

1.  **Introduce Proactive Intelligence:** Make tools that learn from user behavior.
2.  **Deepen Workflow Integrations:** Connect previously separate tools into seamless workflows.
3.  **Enhance User Experience & Polish:** Improve feedback, interactivity, and aesthetics.
4.  **Increase System-Wide Resilience:** Add safeguards, observability, and self-management capabilities.

---

## **Phase 1: Enhanced Intelligence & UX**

### **[Blindspot 21]: "Dumb" Navigation**

*   **Critique:** The `g` command is powerful for explicit navigation but doesn't learn from usage patterns. It can't suggest frequently or recently used directories.
*   **Implementation Plan:**
    1.  Modify `g.sh`: Add a logging mechanism to track the frequency and recency of directory access.
    2.  Implement `g -i` (interactive) or `g --suggest`: This new subcommand will display a sorted list of suggested directories based on a combined frequency/recency score, allowing the user to select one with a number.
    3.  The `cd` hook that updates `recent_dirs` should also feed into this new tracking system.

### **[Blindspot 22]: "Silent" Task Management**

*   **Critique:** The `todo.sh` script is functional but lacks positive reinforcement. Completing a task is a quiet, anticlimactic event.
*   **Implementation Plan:**
    1.  Modify `todo.sh` (`done` subcommand): After a task is completed, print a random, encouraging message (e.g., "Great job!", "Another one bites the dust!", "Progress!").
    2.  Modify `todo.sh` (`add` subcommand): After adding a task, confirm with a message like "Task added. You've got this."

### **[Blindspot 23]: "Static" Morning Routine**

*   **Critique:** The `startday.sh` script is informative but presents the same categories of information every single day, which can lead to it being ignored.
*   **Implementation Plan:**
    1.  Create a "focus of the day" feature. This could be a simple text file (`~/.config/dotfiles-data/daily_focus.txt`) that the user can set.
    2.  Modify `startday.sh`: At the very top, display the "Focus for Today" if it's set.
    3.  Add a `focus` command/alias that allows the user to set or clear the focus for the day (e.g., `focus "Ship the new API"`).

### **[Blindspot 24]: "Manual" Weekly Review**

*   **Critique:** The `week_in_review.sh` script is useful but relies on the user to remember to run it. A weekly summary should be an automated artifact.
*   **Implementation Plan:**
    1.  Modify `week_in_review.sh`: Add a `--file` flag that saves the output to a timestamped markdown file in a new directory, e.g., `~/Documents/Reviews/Weekly/2025-W45.md`.
    2.  Create a new script or use `schedule.sh` to set up a recurring job (e.g., every Sunday at 8 PM) that automatically runs `week_in_review.sh --file`.

### **[Blindspot 25]: "Isolated" Health Data**

*   **Critique:** The `health.sh` data is valuable but completely isolated. There's no way to see if low energy levels correlate with lower code output or fewer completed tasks.
*   **Implementation Plan:**
    1.  Modify `health.sh` (`dashboard` subcommand): Enhance the dashboard to cross-reference data.
    2.  It should pull data from `todo_done.txt` and the git logs to calculate and display "Tasks completed on low-energy days" vs. "high-energy days".
    3.  Similarly, it could show "Git commits on low-energy days" to provide a more holistic view of productivity vs. wellness.

---

## **Phase 2: Deeper Integration & Automation**

### **[Blindspot 26]: "Disconnected" Reminders**

*   **Critique:** The `remind_me.sh` and `schedule.sh` tools are fire-and-forget. They are not integrated with the `todo.sh` system, creating two separate places for tasks.
*   **Implementation Plan:**
    1.  Modify `schedule.sh`: Add a `--todo` flag.
    2.  `schedule "tomorrow 9am" --todo "Call the doctor"` would schedule the task to be *added* to `todo.txt` at the specified time, rather than just sending a notification.
    3.  This turns the scheduler into a "snooze" or "defer" feature for the todo list.

### **[Blindspot 27]: "Unaware" Script Creation**

*   **Critique:** The `new_script.sh` command is helpful but "naive." It will happily create a script and an alias that collides with an existing command or alias, potentially causing unexpected behavior.
*   **Implementation Plan:**
    1.  Modify `new_script.sh`: Before creating the script or alias, it must check if the proposed name is already in use.
    2.  It should check against: 1) existing aliases in `aliases.zsh`, 2) other scripts in the `scripts/` directory, and 3) commands in the system `PATH`.
    3.  If a collision is detected, it should warn the user and exit without making changes.

### **[Blindspot 28]: "Manual" Project Backups**

*   **Critique:** The `backup_project.sh` script is manual. Projects that are not yet on GitHub or haven't been pushed in a while are at risk of data loss.
*   **Implementation Plan:**
    1.  Modify `goodevening.sh`: Add a new "Project Backup" section.
    2.  This section should scan the `~/Projects` directory for repos that have unpushed commits or are not yet tracked by a remote.
    3.  For each such project, it should automatically run `backup_project.sh` to ensure no work is lost. This acts as a safety net for local-only work.

### **[Blindspot 29]: "Naive" File Organization**

*   **Critique:** `tidy_downloads.sh` is a blunt instrument. It moves files based on extension, but it could accidentally move a file that is currently being downloaded or used by an application.
*   **Implementation Plan:**
    1.  Modify `tidy_downloads.sh`: Before moving a file, check if it has been modified in the last 60 seconds.
    2.  Use `find` with the `-mmin -1` flag to identify and skip files that are "hot."
    3.  Add a configuration file (e.g., `~/.config/dotfiles-data/tidy_ignore.txt`) where the user can list filenames or patterns to always ignore.

### **[Blindspot 30]: "Orphaned" Bookmarks**

*   **Critique:** If a directory bookmarked with `g.sh` is deleted or renamed, the bookmark becomes a "dead link" that causes an error. There is no built-in way to clean these up.
*   **Implementation Plan:**
    1.  Create a new subcommand for `g.sh`: `g prune`.
    2.  This command will read the bookmarks file, check if the directory for each bookmark still exists, and interactively prompt the user to remove any bookmarks pointing to non-existent locations.

---

## **Phase 3: Advanced Tooling & Polish**

### **[Blindspot 31]: "Basic" Text Search**

*   **Critique:** `findtext.sh` is a simple `grep` wrapper. For a real "second brain," search needs to be more powerful and interactive.
*   **Implementation Plan:**
    1.  Replace `findtext.sh` with a more advanced tool that uses `fzf` (a command-line fuzzy finder).
    2.  The new script should `rg` (ripgrep) for the search term and pipe the results into `fzf`, allowing the user to interactively filter and preview the matches.
    3.  Selecting a match in `fzf` should open the corresponding file directly in `$EDITOR` at the correct line number.

### **[Blindspot 32]: "Limited" Media Conversion**

*   **Critique:** The `media_converter.sh` script is useful but only handles a few basic conversions. It could be a much more comprehensive media toolkit.
*   **Implementation Plan:**
    1.  Extend `media_converter.sh` with new subcommands:
        *   `gif`: Convert a short video clip into an optimized GIF.
        *   `strip-audio`: Remove the audio track from a video file.
        *   `normalize-audio`: Adjust the volume of an audio file to a standard level.
    2.  This requires adding `ffmpeg` filters and options for each new capability.

### **[Blindspot 33]: "Noisy" Dev Server**

*   **Critique:** The `dev_shortcuts.sh server` command is handy, but the Python `http.server` logs every single GET request to the console, making it very noisy.
*   **Implementation Plan:**
    1.  Modify `dev_shortcuts.sh` (`server` subcommand): Redirect the `stdout` and `stderr` of the `python3 -m http.server` command to `/dev/null`.
    2.  It should still print the initial "Starting server on port..." message but then remain silent during operation.

### **[Blindspot 34]: "Unstyled" Cheatsheet**

*   **Critique:** The `cheatsheet.sh` is a plain text dump. With a little formatting, it could be much easier to read and scan quickly.
*   **Implementation Plan:**
    1.  Modify `cheatsheet.sh`: Use `tput` or ANSI escape codes to add color and styles.
    2.  Section headers (e.g., "GIT COMMANDS") should be bold and a different color.
    3.  Commands themselves could be highlighted to stand out from their descriptions.

### **[Blindspot 35]: No "Undo" for Tasks**

*   **Critique:** If a user accidentally marks a task as done with `todo done`, there is no easy way to revert it. The task is moved to a separate file, and restoring it is a manual process.
*   **Implementation Plan:**
    1.  Create a new `todo.sh` subcommand: `todo undo`.
    2.  This command will read the last line from `todo_done.txt`, remove it from that file, and append it back to `todo.txt`.
    3.  It should print a confirmation message like "Restored task: [Task Text]".

---

## **Phase 4: System-Wide Resilience & Observability**

### **[Blindspot 36]: "Fragile" Bootstrap Process**

*   **Critique:** The `bootstrap.sh` script is not idempotent. If it's run a second time, it may fail or cause unintended side effects (e.g., re-creating symlinks).
*   **Implementation Plan:**
    1.  Modify `bootstrap.sh`: Add checks before performing any action.
    2.  Before creating a symlink, check if it already exists and points to the correct location.
    3.  Before installing a dependency, check if it's already installed.
    4.  The script should be safe to run multiple times, only making changes that are actually needed.

### **[Blindspot 37]: "Hidden" Automation**

*   **Critique:** The `meds.sh remind` automation is designed to be set up in a user's personal `crontab`, which is opaque and outside the dotfiles repo. This makes it hard to manage and audit.
*   **Implementation Plan:**
    1.  Create a `crontab.example` file in the repository that documents the intended cron jobs.
    2.  Create a new script, `schedule_manager.sh`, that can `install` or `uninstall` the cron jobs from the example file into the user's actual crontab, providing a single point of management.

### **[Blindspot 38]: No "Dry-Run" Mode**

*   **Critique:** Scripts that perform destructive or significant file operations (`tidy_downloads.sh`, `review_clutter.sh`, `file_organizer.sh`) lack a "dry-run" mode. The user has to trust that they will do the right thing.
*   **Implementation Plan:**
    1.  Modify these scripts to accept a `--dry-run` or `-n` flag.
    2.  When this flag is present, the script should print the actions it *would* take (e.g., "Would move file.jpg to Images/") without actually performing them.

### **[Blindspot 39]: "Inconsistent" Logging**

*   **Critique:** While a `system.log` exists, the format and verbosity of log messages are inconsistent across different scripts.
*   **Implementation Plan:**
    1.  Create a dedicated, separate logger script (e.g., `log.sh`).
    2.  This script will take a log level (INFO, WARN, ERROR) and a message, and format it consistently before appending to `system.log`.
    3.  Refactor all other scripts (`goodevening.sh`, `startday.sh`, etc.) to call `log.sh` instead of `echo`ing directly to the log file.

### **[Blindspot 40]: No "Self-Update" Capability**

*   **Critique:** The dotfiles are a git repository, but there is no built-in, easy way for the user to pull the latest changes from the remote.
*   **Implementation Plan:**
    1.  Create a new script: `dotfiles_update.sh`.
    2.  This script will `cd` into the dotfiles directory, run `git pull`, and then perhaps run `dotfiles_check.sh` to ensure the update didn't break anything.
    3.  Add an alias `update_dotfiles` for this script. This makes keeping the toolkit up-to-date a single, simple command.
