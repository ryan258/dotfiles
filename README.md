# Dotfiles: A macOS Productivity Toolkit

This repository contains a personal collection of shell scripts, aliases, and configurations designed to create a powerful, efficient, and accessible command-line environment on macOS. The toolkit is built on Zsh and automates common development and system management tasks, reducing repetitive actions and minimizing cognitive load.

## Core Philosophy

This setup is guided by a few key principles:

  * **Efficiency:** Every script and alias is designed to save keystrokes and streamline complex operations into simple commands.
  * **Accessibility:** By simplifying workflows and providing clear feedback, the toolkit aims to be usable and helpful even on low-energy days.
  * **Robustness:** Scripts are written defensively, with checks for dependencies and safe error handling.
  * **Seamless Integration:** The tools deeply integrate with macOS-specific features like `osascript` for notifications, `pmset` for battery status, and Finder for file operations.

## Features

This toolkit provides a comprehensive set of enhancements, including:

  * **Productivity & Task Management:** Advanced command-line tools for todos (with prioritization and git integration), journaling (with search and "on this day"), health/symptom tracking with trend dashboards, and medication adherence monitoring.
  * **Project & Workspace Management:** Scaffold new projects, create timestamped backups, and save/load directory contexts with intelligent state management (auto-activates venvs, launches apps).
  * **Knowledge Management:** Personal searchable how-to wiki, blog content integration with todo system, and journal search capabilities for building a "second brain".
  * **System & Network Diagnostics:** Get a quick overview of your system's hardware, CPU, and memory usage, check battery status, and troubleshoot network issues. Includes system health validation and audit logging.
  * **File & Archive Utilities:** Effortlessly organize your `Downloads` folder, find large or duplicate files, manage archives, and interactive clutter review for Desktop/Downloads.
  * **Development Shortcuts:** Automate common Git workflows with todo integration, manage Python virtual environments, spin up local web servers, and schedule future commands.
  * **macOS Integration:** Enhanced clipboard manager with dynamic snippets, launch favorite applications, receive system notifications, and unified shell environment across Terminal and VS Code.

## What's New in Round 2 (November 2025)

This project has recently completed a major evolution, "Round 2," which focused on deepening integrations, improving data integrity, and adding proactive intelligence. Key improvements include:

  * **Enhanced Error Handling & Data Validation:** The entire system is more robust, with better error handling and a new data validation script to prevent corruption.
  * **Health & Productivity Correlation:** The `health` dashboard now correlates energy levels with task completions and git activity, providing valuable insights into productivity patterns.
  * **Smart Navigation:** The `g` command now logs directory usage, providing intelligent suggestions for frequently used directories.
  * **Automated Weekly Reviews:** A new LaunchAgent automatically generates a weekly review every Sunday.
  * **Safer File Operations:** Scripts like `tidy_downloads` now have safety checks to avoid moving recently modified files.
  * **And much more:** See the `CHANGELOG.md` for a detailed list of all 20+ improvements.

## Prerequisites

This setup assumes you are on macOS with Zsh (the default shell). You will also need:

  * **Homebrew:** The missing package manager for macOS.
  * **Optional Dependencies:** For full functionality, install the following tools via Homebrew:
      * `ffmpeg`: For converting video to audio.
      * `imagemagick`: For resizing images.
      * `ghostscript`: For compressing PDFs.
      * `jq`: For processing JSON (used in various helper scripts).
      * `unrar`: For extracting `.rar` archives.

## Installation

### Automated Setup (Recommended)

1.  **Clone the Repository:**

    ```bash
    git clone https://github.com/ryan258/dotfiles.git ~/dotfiles
    ```

2.  **Run Bootstrap:**
    The bootstrap script automates the entire setup process:

    ```bash
    cd ~/dotfiles
    ./bootstrap.sh
    ```

    This will:
    - Install Homebrew (if needed)
    - Install required dependencies (jq, curl, gawk)
    - Create the data directory at `~/.config/dotfiles-data/`
    - Create `~/.zshenv` to point to the dotfiles
    - Make all scripts executable
    - Validate the installation with `dotfiles_check.sh`

3.  **Restart Your Shell:**
    Close and reopen your terminal or run `zsh -l` to apply the new configuration.

### Manual Setup

If you prefer manual installation:

1.  Clone the repository as above
2.  Create `~/.zshenv` with: `export ZDOTDIR="$HOME/dotfiles/zsh"`
3.  Make scripts executable: `chmod +x ~/dotfiles/scripts/*.sh`
4.  Create data directory: `mkdir -p ~/.config/dotfiles-data`
5.  Install dependencies: `brew install jq gawk`
6.  Verify installation: `dotfiles_check`

## How It Works

This setup uses a modern Zsh structure to keep your home directory clean:

  * `~/.zshenv`: This is the first file Zsh reads. It sets the `$ZDOTDIR` variable, telling Zsh to look for its configuration files inside `~/dotfiles/zsh/`.
  * `~/dotfiles/zsh/.zprofile`: This file runs once at login and is the correct place to manage your `$PATH`, ensuring compatibility with macOS tools.
  * `~/dotfiles/zsh/.zshrc`: This runs every time you open a new shell. It sources your aliases and other interactive configurations.
  * `~/dotfiles/zsh/aliases.zsh`: This is where the magic happens! It contains hundreds of shortcuts and helper functions that form the core of the workflow.

### Data Storage

All script data is centralized in `~/.config/dotfiles-data/` for easy backup and management:

  * `journal.txt` – Timestamped journal entries (searchable with `journal search`)
  * `todo.txt` & `todo_done.txt` – Active and completed tasks with timestamps
  * `health.txt` – Health appointments, symptom logs, and energy ratings
  * `medications.txt` – Medication schedules and dose logs
  * `system.log` – Central audit log for all automated actions
  * `dir_bookmarks` & `dir_history` – Directory navigation data
  * `favorite_apps` – Application launcher shortcuts
  * `clipboard_history/` – Saved clipboard snippets (supports dynamic/executable snippets)
  * `how-to/` – Personal how-to wiki articles

This single directory is automatically backed up daily by `goodevening.sh` to `~/Backups/dotfiles_data/`.

## Usage Reference

**New to the system?** Start with the **[Daily Happy Path Guide](docs/happy-path.md)** - a step-by-step walkthrough designed for brain fog days.

Below is a summary of the most common commands. For a complete list, see `scripts/README_aliases.md`.

### Key Aliases

| Alias      | Description                                               |
| :--------- | :-------------------------------------------------------- |
| `update`   | Update and upgrade all Homebrew packages.           |
| `gs`, `gaa`, `gc` | Standard shortcuts for `git status`, `git add .`, `git commit`. |
| `ll`, `la`, `lt` | Enhanced `ls` commands for detailed, sorted views.    |
| `..`, `...`  | Navigate up one or two parent directories.            |
| `info`     | A dashboard showing weather and current to-do items.      |
| `status`   | A dashboard showing your current work context (directory, git), journal, and tasks.     |
| `cleanup`  | Organizes the `~/Downloads` folder and lists large files. |

### Core Scripts

Many scripts can be called directly. Some, marked with `(source)`, provide extra functionality when sourced (e.g., `source script.sh`).

| Command        | Description                                                                 |
| :------------- | :-------------------------------------------------------------------------- |
| `todo`         | Advanced todo list manager with `add`, `list`, `done`, `commit`, `bump`, `top` - integrates with git commits and task prioritization. |
| `journal`      | Timestamped journal with `search` and `onthisday` features for building your second brain. |
| `health`       | Track appointments, symptoms, and energy levels with `dashboard` for 30-day trend analysis. |
| `meds`         | Medication tracking system with `check`, `log`, `remind`, and `dashboard` for adherence monitoring. |
| `startday`     | Automated morning routine showing yesterday's context, active projects, blog status, health reminders, stale tasks, and top 3 priorities. Syncs blog stubs to todos. |
| `goodevening`  | End-of-day summary with gamified progress tracking, project safety checks (uncommitted changes, stale branches), and automated data backups. |
| `g` (source)   | Unified navigation system - bookmarks, recent dirs, auto-activates venvs, launches apps, runs on-enter commands. Replaces goto/back/workspace_manager. |
| `blog`         | Blog workflow tools: `status`, `stubs`, `random`, `sync` (to todos), `ideas` (search journal). |
| `howto`        | Personal searchable how-to wiki for storing and retrieving complex workflows. |
| `schedule`     | User-friendly wrapper for `at` command to schedule future commands and reminders. |
| `whatis`       | Look up what an alias or command does by searching aliases and documentation. |
| `dotfiles_check` | System validation - verifies all scripts, dependencies, data directories, and GitHub token. |
| `backup`       | Creates a timestamped backup of the current project directory. |
| `newproject`   | Interactively scaffolds a new project with a standard directory structure. |
| `newpython`    | Bootstraps a Python project with a virtual environment and `.gitignore`. |
| `projects`     | Find and get details about forgotten projects from GitHub. |
| `review_clutter` | Interactive tool to archive or delete old files from Desktop/Downloads. |
| `graballtext`  | Capture readable text from the repo into `all_text_contents.txt` for quick review or search. |
| `done`         | Run any long command and get a system notification when it's finished. |
| `pomo`         | Start a 25-minute Pomodoro timer with break reminder (alias for `take_a_break 25`). |
| `next`         | Show only your top priority task (alias for `todo top 1`). |
| `systemlog`    | View the last 20 automation events from the central audit log. |

### Clipboard Workflows

Make the macOS clipboard part of your shell toolkit—`docs/clipboard.md` walks through practical `pbcopy`/`pbpaste` pipelines plus real-world usage examples for zero-mouse context switches.

## Customization

Adding your own commands is easy:

  * **To add a new alias:** Open `~/dotfiles/zsh/aliases.zsh` and add your shortcut in the relevant section.
  * **To add a new script (automated):**
    ```bash
    new_script my_tool
    ```
    This automatically creates `scripts/my_tool.sh` with proper headers, makes it executable, and adds an alias to `aliases.zsh`.

  * **To add a new script (manual):**
    1.  Place the new script file in `~/dotfiles/scripts/`.
    2.  Make it executable: `chmod +x ~/dotfiles/scripts/your_script.sh`.
    3.  (Optional) Add a convenient alias for it in `aliases.zsh`.

## Maintenance

### System Validation

Run the built-in doctor script to verify your installation:

```bash
dotfiles_check
```

This validates all scripts, dependencies, data directories, and configuration.

### Code Quality

To maintain code quality and prevent common shell scripting errors, run `shellcheck` on any modified scripts:

```bash
# Install shellcheck if you don't have it
brew install shellcheck

# Run it on all scripts
shellcheck ~/dotfiles/scripts/*.sh
```

### Viewing System Activity

Check the central audit log to see what automated tasks have run:

```bash
systemlog
```

This shows the last 20 automation events from data backups, task cleanups, blog syncs, and medication reminders.
