# Personal macOS Scripts Toolkit

This folder collects small shell utilities that streamline day-to-day work on macOS—from note taking and reminders to system diagnostics and media conversion. Most scripts are intended to be run from Terminal and assume the default macOS tools (`bash`, `python3`, `osascript`, `find`, `zip`, etc.) plus a few optional Homebrew installs for advanced features.

## Getting Started

1. Clone or copy this directory to `~/dotfiles/scripts` (or another location you control).
2. Make every script executable:
   ```bash
   chmod +x ~/dotfiles/scripts/*.sh
   ```
3. Add the directory to your `PATH` in `~/.zprofile`:
   ```bash
   path_prepend "$HOME/dotfiles/scripts"
   export PATH
   ```
4. Reload your shell configuration: `source ~/.zprofile`.

### Data Storage

All script data files are centralized in `~/.config/dotfiles-data/` for easy backup and organization:
- `journal.txt` – Journal entries (searchable)
- `todo.txt` & `todo_done.txt` – Task lists (with timestamps)
- `health.txt` – Health appointments, symptoms, energy ratings
- `medications.txt` – Medication schedules and dose logs
- `system.log` – Central audit log for automation
- `dir_bookmarks` & `dir_history` – Directory navigation data
- `favorite_apps` – Application launcher shortcuts
- `clipboard_history/` – Saved clipboard snippets (supports dynamic snippets)
- `how-to/` – Personal how-to wiki articles

Automated daily backups to `~/Backups/dotfiles_data/` via `goodevening.sh`.

Many helper scripts (for example `goto.sh`, `dev_shortcuts.sh env`, and `recent_dirs.sh`) can change your current directory when they are *sourced* instead of executed. To use them that way, call `source ~/scripts/<script>.sh ...` or set up aliases/functions in your shell configuration.

### Optional Dependencies

Install these tools with Homebrew if you plan to use the related scripts:

| Tool | Used By | Install |
| ---- | ------- | ------- |
| `ffmpeg` | `media_converter.sh video2audio` | `brew install ffmpeg` |
| `imagemagick` | `media_converter.sh resize_image` | `brew install imagemagick` |
| `ghostscript` | `media_converter.sh pdf_compress` | `brew install ghostscript` |
| `jq` | Various JSON helpers (recommended) | `brew install jq` |
| `unrar` | `archive_manager.sh extract *.rar` | `brew install unrar` |

## Usage Reference

Below is a quick snapshot of what each script does and how to call it. Arguments in brackets are optional.

### Productivity & Planning

- `journal.sh {add|list|search|onthisday}` – Append timestamped entries, list recent entries, search for keywords, or see "on this day" from previous years. Building your second brain.
- `todo.sh {add|list|done|clear|commit|bump|top}` – Advanced todo list with git integration (`commit`), prioritization (`bump`, `top`), and timestamp tracking. Highlights stale tasks >7 days old.
- `health.sh {add|symptom|energy|list|summary|dashboard|export|remove}` – Track appointments, log symptoms, rate energy levels (1-10), view 30-day trend dashboards, and export reports for doctors.
- `meds.sh {add|log|list|check|history|dashboard|remove|remind}` – Medication tracking with adherence monitoring, automated reminders (for cron), and 30-day dashboards.
- `week_in_review.sh` – Summarise recent todos, journal entries, and commits from the last seven days.
- `my_progress.sh` – Show your latest Git commits in the current repository.
- `startday.sh` – Automated morning routine: syncs blog stubs to todos, shows yesterday's context, active GitHub projects, blog status, health reminders, stale tasks (>7 days), scheduled commands, and top 3 priorities.
- `goodevening.sh` – End-of-day wrap-up with gamified progress tracking, project safety checks (uncommitted changes, large diffs, stale branches, unpushed commits), task cleanup, and automated data backup.
- `status.sh` – Mid-day dashboard showing your current work context (directory, git), journal, and top 3 tasks.
- `projects.sh {forgotten|recall <name>}` – Find and get details about forgotten projects from GitHub.
- `blog.sh {status|stubs|random|recent|sync|ideas}` – Blog workflow tools with stub age warnings, todo sync, and journal search for blog ideas.
- `greeting.sh` – Quick context summaries for the start of a session.
- `howto.sh {add|<name>|search}` – Personal searchable how-to wiki for complex workflows.
- `schedule.sh "<time>" "<command>"` – User-friendly wrapper for macOS `at` command to schedule future commands.
- `dotfiles_check.sh` – System validation script (doctor) that checks scripts, dependencies, data directory, and GitHub token.
- `backup_data.sh` – Automated backup of entire `~/.config/dotfiles-data/` directory (called by `goodevening.sh`).
- `new_script.sh <name>` – Automate adding new scripts with proper headers, executable permissions, and alias creation.

### Project & Directory Management

- `g.sh {<bookmark>|-r|recent|save|-s|list}` – **Unified navigation system** that replaces goto/back/workspace_manager. Bookmarks directories, tracks recent history, auto-activates Python venvs, launches associated apps, and runs on-enter commands. Must be sourced for directory changes.
- `start_project.sh` – Interactive scaffold for generic projects (`src/`, `docs/`, `assets/`). Source it to automatically `cd` into the new folder.
- `mkproject_py.sh` – Bootstrap a Python project with a virtualenv, `.gitignore`, and starter `main.py`.
- `backup_project.sh` – Run inside any directory to rsync it to `~/Backups` with a timestamped name.
- `dev_shortcuts.sh {server|json|env|gitquick}` – Handy dev helpers: `dev_shortcuts.sh server 9000`, `dev_shortcuts.sh json data.json`, `dev_shortcuts.sh env` (source for auto-activation), or `dev_shortcuts.sh gitquick "Fix build"`.
- ~~`workspace_manager.sh`~~ – **Deprecated:** Use `g.sh` instead for enhanced state management.
- ~~`recent_dirs.sh`~~ – **Deprecated:** Use `g.sh -r` instead.
- ~~`goto.sh`~~ – **Deprecated:** Use `g.sh` instead.

### System & Network Utilities

- `system_info.sh` – Snapshot of hardware, CPU, memory, disk, and public IP information.
- `network_info.sh {status|scan|speed|fix}` – Check Wi-Fi details, list networks, run a download test, or flush DNS and toggle Wi-Fi power.
- `battery_check.sh` – Display macOS battery status plus charging suggestions.
- `process_manager.sh {find|top|memory|kill}` – Inspect or kill processes (`process_manager.sh find node`, `process_manager.sh kill chrome`).

### File, Text, and Archive Helpers

- `archive_manager.sh {create|extract|list}` – Create archives (supports `.zip`, `.tar.gz`) or explore/extract existing ones, e.g. `archive_manager.sh create project.zip src docs`.
- `duplicate_finder.sh [path]` – Find duplicate files by checksum within a directory.
- `file_organizer.sh {bytype|bydate|bysize}` – Sort files into folders based on extension, creation date, or size buckets.
- `findbig.sh` – List the ten largest items in the current directory tree.
- `findtext.sh` – Interactive `grep -r` wrapper for locating text within files.
- `grab_all_text.sh` – Concatenate all readable files (skipping git metadata) into `all_text_contents.txt` for quick searching or backups.
- `text_processor.sh {count|search|replace|clean}` – Compare text statistics, search within a file, replace strings safely, or strip trailing whitespace.
- `tidy_downloads.sh` – Sweep `~/Downloads`, filing images, documents, media, and archives into sensible homes.
- `review_clutter.sh` – **Interactive clutter management** for `~/Desktop` and `~/Downloads`. Prompts for each file >30 days old: (a)rchive to `~/Documents/Archives/YYYY-MM/`, (d)elete, or (s)kip.
- `open_file.sh <query>` – Fuzzy search for files beneath your home directory and open the selected result.
- `unpacker.sh <archive>` – Extract common archive formats (`.tar.gz`, `.zip`, `.rar`, `.7z`).

### Clipboard, Launchers, and Shortcuts

- `app_launcher.sh {add|list|<shortcut>}` – Maintain a favourite-app list and launch shortcuts (`app_launcher.sh add code "Visual Studio Code"`).
- `clipboard_manager.sh {save|load|list|peek}` – Store snippets from the macOS clipboard. **Supports dynamic snippets**: if a saved snippet is executable, it runs and pipes output to clipboard (e.g., save a script that outputs current git branch).
- `whatis.sh <command>` – Look up what an alias or command does by searching `aliases.zsh` and documentation.
- `pbcopy` / `pbpaste` tips live in `../docs/clipboard.md`—learn how to funnel command output straight into the clipboard and back with concrete examples.

### Media & Data Conversion

- `media_converter.sh {video2audio|resize_image|pdf_compress}` – Convert videos to MP3, resize images, or compress PDFs. Requires `ffmpeg`, `ImageMagick`, or `ghostscript` respectively.
- `archive_manager.sh` and `unpacker.sh` (see above) also help when juggling compressed files.

### Notifications, Breaks, and Timers

- `done.sh <command ...>` – Run any long-lived command and receive a notification when it finishes.
- `remind_me.sh +30m "Stretch"` – Schedule a macOS notification for 30 minutes (also supports `+2h`).
- `take_a_break.sh [minutes]` – Health break timer with suggestions; defaults to 15 minutes. Use `pomo` alias for 25-minute Pomodoro timer.

### Weather, Status, and Miscellaneous Tools

- `weather.sh` – Fetch the forecast for the default city (edit the `city` variable to change it).
- `cheatsheet.sh` – Display commonly-used commands for quick reference.

### MTG Collection Tools

- `mtg_price_check.sh [collection.csv]` – Download the Card Kingdom buylist and combine it with your collection CSV, writing results to `~/mtg_prices/`. Requires network access and the companion `mtg_tracker.py` script.

## Contributing & Maintenance

- Keep scripts POSIX-compatible where possible; prefer quoting user input and checking command failures.
- Run `shellcheck *.sh` after making changes to catch quoting and portability regressions.
- Document new utilities in this README so future-you remembers how to use them.

Happy scripting!
