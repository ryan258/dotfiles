# Personal macOS Scripts Toolkit

This folder collects small shell utilities that streamline day-to-day work on macOS—from note taking and reminders to system diagnostics and media conversion. Most scripts are intended to be run from Terminal and assume the default macOS tools (`bash`, `python3`, `osascript`, `find`, `zip`, etc.) plus a few optional Homebrew installs for advanced features.

## Getting Started

1. Clone or copy this directory to `~/scripts` (or another location you control).
2. Make every script executable:
   ```bash
   chmod +x ~/scripts/*.sh
   ```
3. Add the directory to your `PATH` so each command is available everywhere. Append the following to `~/.zshrc` (or `~/.bash_profile`):
   ```bash
   export PATH="$HOME/scripts:$PATH"
   ```
4. Reload your shell configuration: `source ~/.zshrc`.

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

- `journal.sh [text]` – Append a journal entry (`journal.sh "Wrapped up sprint"`) or, with no arguments, display the last five entries.
- `memo.sh {add|list|today|clear}` – Lightweight memo pad (`memo.sh add "alias idea"`, `memo.sh list`).
- `quick_note.sh {add|search|recent|today}` – Timestamped notes; for example `quick_note.sh add "Pairing tomorrow at 2"` or `quick_note.sh search pairing`.
- `todo.sh {add|list|done|clear}` – CLI todo list (`todo.sh add "Refactor utils"`, `todo.sh done 2`).
- `week_in_review.sh` – Summarise recent todos, journal entries, and commits from the last seven days.
- `my_progress.sh` – Show your latest Git commits in the current repository.
- `startday.sh` – Morning routine: prints the date, suggests a workspace folder, and lists today’s todos.
- `goodevening.sh` – An interactive end-of-day summary of completed tasks, journal entries, and uncommitted changes.
- `status.sh` – A dashboard showing your current work context (directory, git), journal, and tasks.
- `projects.sh {forgotten|recall <name>}` – Find and get details about forgotten projects.
- `blog.sh {status|stubs|random|recent}` – Tools for managing blog content.
- `greeting.sh` – Quick context summaries for the start of a session.

### Project & Directory Management

- `start_project.sh` – Interactive scaffold for generic projects (`src/`, `docs/`, `assets/`). Source it to automatically `cd` into the new folder.
- `mkproject_py.sh` – Bootstrap a Python project with a virtualenv, `.gitignore`, and starter `main.py`.
- `backup_project.sh` – Run inside any directory to rsync it to `~/Backups` with a timestamped name.
- `dev_shortcuts.sh {server|json|env|gitquick}` – Handy dev helpers: `dev_shortcuts.sh server 9000`, `dev_shortcuts.sh json data.json`, `dev_shortcuts.sh env` (source for auto-activation), or `dev_shortcuts.sh gitquick "Fix build"`.
- `workspace_manager.sh {save|load|list}` – Capture and recall working contexts (`workspace_manager.sh save focus`, `workspace_manager.sh load focus`). Source it for automatic directory switching.
- `recent_dirs.sh [add]` – Maintain a jump list of directories. Hook the `add` subcommand into your `cd` function, or run `recent_dirs.sh` to pick one interactively.
- `goto.sh {save|list|<bookmark>}` – Bookmark directories (`goto.sh save repos`, `goto.sh repos`). Source for automatic navigation.

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
- `open_file.sh <query>` – Fuzzy search for files beneath your home directory and open the selected result.
- `unpacker.sh <archive>` – Extract common archive formats (`.tar.gz`, `.zip`, `.rar`, `.7z`).

### Clipboard, Launchers, and Shortcuts

- `app_launcher.sh {add|list|<shortcut>}` – Maintain a favourite-app list and launch shortcuts (`app_launcher.sh add code "Visual Studio Code"`).
- `clipboard_manager.sh {save|load|list|peek}` – Store snippets from the macOS clipboard (`clipboard_manager.sh save draft`, `clipboard_manager.sh load draft`).

### Media & Data Conversion

- `media_converter.sh {video2audio|resize_image|pdf_compress}` – Convert videos to MP3, resize images, or compress PDFs. Requires `ffmpeg`, `ImageMagick`, or `ghostscript` respectively.
- `archive_manager.sh` and `unpacker.sh` (see above) also help when juggling compressed files.

### Notifications, Breaks, and Timers

- `done.sh <command ...>` – Run any long-lived command and receive a notification when it finishes.
- `script_67777906.sh <command ...>` – Alternate notification wrapper that mirrors `done.sh` but uses emoji titles.
- `remind_me.sh +30m "Stretch"` – Schedule a macOS notification for 30 minutes (also supports `+2h`).
- `take_a_break.sh [minutes]` – Health break timer with suggestions; defaults to 15 minutes.
- `script_58131199.sh [minutes]` – Minimal break timer that simply sleeps and notifies.

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
