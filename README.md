# Dotfiles: A macOS Productivity Toolkit

This repository contains a personal collection of shell scripts, aliases, and configurations designed to create a powerful, efficient, and accessible command-line environment on macOS. The toolkit is built on Zsh and automates common development and system management tasks, reducing repetitive actions and minimizing cognitive load.

## Core Philosophy

This setup is guided by a few key principles:

  * **Efficiency:** Every script and alias is designed to save keystrokes and streamline complex operations into simple commands.
  * **Accessibility:** By simplifying workflows and providing clear feedback, the toolkit aims to be usable and helpful even on low-energy days.
  * **Robustness:** Scripts are written defensively, with checks for dependencies and safe error handling.
  * **Seamless Integration:** The tools deeply integrate with macOS-specific features like `osascript` for notifications, `pmset` for battery status, and Finder for file operations.

## Features

This toolkit provides a wide range of enhancements, including:

  * **Productivity & Task Management:** Keep track of your day with command-line tools for todos, journaling, and quick notes.
  * **Project & Workspace Management:** Scaffold new projects, create timestamped backups, and save/load directory contexts with bookmarks.
  * **System & Network Diagnostics:** Get a quick overview of your system's hardware, CPU, and memory usage, check battery status, and troubleshoot network issues.
  * **File & Archive Utilities:** Effortlessly organize your `Downloads` folder, find large or duplicate files, and manage archives like `.zip` and `.tar.gz`.
  * **Development Shortcuts:** Automate common Git workflows, manage Python virtual environments, and spin up local web servers.
  * **macOS Integration:** Manage clipboard history, launch favorite applications, and receive system notifications when long-running tasks are complete.

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

1.  **Clone the Repository:**

    ```bash
    git clone https://github.com/ryan258/dotfiles.git ~/dotfiles
    ```

2.  **Run the Setup Workflow:**
    Follow the steps outlined in the initial setup plan to back up your existing files and link the new configuration. The core of this involves creating a `~/.zshenv` file with the following content:

    ```bash
    export ZDOTDIR="$HOME/dotfiles/zsh"
    ```

3.  **Make Scripts Executable:**
    Ensure all utility scripts are ready to run.

    ```bash
    chmod +x ~/dotfiles/scripts/*.sh
    ```

4.  **Restart Your Shell:**
    Close and reopen your terminal or run `zsh -l` to apply the new configuration.

## How It Works

This setup uses a modern Zsh structure to keep your home directory clean:

  * `~/.zshenv`: This is the first file Zsh reads. It sets the `$ZDOTDIR` variable, telling Zsh to look for its configuration files inside `~/dotfiles/zsh/`.
  * `~/dotfiles/zsh/.zprofile`: This file runs once at login and is the correct place to manage your `$PATH`, ensuring compatibility with macOS tools.
  * `~/dotfiles/zsh/.zshrc`: This runs every time you open a new shell. It sources your aliases and other interactive configurations.
  * `~/dotfiles/zsh/aliases.zsh`: This is where the magic happens! It contains hundreds of shortcuts and helper functions that form the core of the workflow.

### Data Storage

All script data is centralized in `~/.config/dotfiles-data/` for easy backup and management:

  * `journal.txt` – Timestamped journal entries
  * `todo.txt` & `todo_done.txt` – Active and completed tasks
  * `health.txt` – Health appointments with reminders
  * `dir_bookmarks` & `dir_history` – Directory navigation data
  * `favorite_apps` – Application launcher shortcuts
  * `clipboard_history/` – Saved clipboard snippets

This single directory can be easily backed up, synced, or excluded from version control.

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
| `todo`         | A powerful command-line todo list manager (`add`, `list`, `done`).       |
| `journal`      | Append a timestamped entry to your daily journal.                     |
| `startday`     | A morning routine that shows tasks and suggests a workspace.        |
| `goodevening`  | An interactive end-of-day summary of completed tasks, journal entries, and uncommitted changes. |
| `graballtext`  | Capture readable text from the repo into `all_text_contents.txt` for quick review or search. |
| `backup`       | Creates a timestamped backup of the current project directory.    |
| `newproject`   | Interactively scaffolds a new project with a standard directory structure. |
| `newpython`    | Bootstraps a Python project with a virtual environment and `.gitignore`. |
| `projects`     | Find and get details about forgotten projects (`projects forgotten`, `projects recall <name>`). |
| `blog`         | Tools for managing blog content (`blog status`, `blog stubs`, `blog random`). |
| `goto` (source)  | Bookmark directories and jump to them by name (`goto save proj`, `goto proj`). |
| `back` (source)  | Interactively jump to a recently visited directory.                 |
| `done`         | Run any long command and get a system notification when it's finished.  |

### Clipboard Workflows

Make the macOS clipboard part of your shell toolkit—`docs/clipboard.md` walks through practical `pbcopy`/`pbpaste` pipelines plus real-world usage examples for zero-mouse context switches.

### Magic the Gathering Collection

This toolkit includes a specialized script for pricing a Magic: The Gathering collection stored in a CSV file.

  * `mtg [collection.csv]`: Fetches the latest Card Kingdom buylist, processes your `collection.csv` file against it, and outputs a new CSV with matched prices. The processing logic is handled by the accompanying `mtg_tracker.py` Python script.

## Customization

Adding your own commands is easy:

  * **To add a new alias:** Open `~/dotfiles/zsh/aliases.zsh` and add your shortcut in the relevant section.
  * **To add a new script:**
    1.  Place the new script file in `~/dotfiles/scripts/`.
    2.  Make it executable: `chmod +x ~/dotfiles/scripts/your_script.sh`.
    3.  (Optional) Add a convenient alias for it in `aliases.zsh`.

## Maintenance

To maintain code quality and prevent common shell scripting errors, it is recommended to run `shellcheck` on any modified scripts.

```bash
# Install shellcheck if you don't have it
brew install shellcheck

# Run it on all scripts
shellcheck ~/dotfiles/scripts/*.sh
```
