# macOS zsh Alias Pack

This document complements the `~/.zsh_aliases` file. It explains the purpose of each alias/function, the prerequisites they rely on, and a few example flows.

## Quick Start

1. Scripts are located in `~/dotfiles/scripts` and added to PATH via `~/.zprofile`.
2. Aliases are defined in `~/dotfiles/zsh/aliases.zsh` and sourced from `~/.zshrc`.
3. All data files are centralized in `~/.config/dotfiles-data/` and automatically backed up daily by `goodevening.sh`.
4. Confirm required tools (Homebrew, git, Python 3, macOS utilities) are installed. Use `dotfiles_check` to validate your installation.
5. Run `startday` each morning for automated context recovery, or let it run automatically on first terminal open.

## Recent Enhancements (November 2025)

### Phase 6: AI Staff HQ Integration (November 10, 2025)

- **10 AI Dispatchers**: tech, creative, content, strategy, brand, market, stoic, research, narrative, copy
- **Spec Template System**: `spec` command for structured AI requests (8 templates)
- **Optimized Free Models**: DeepSeek R1, Llama 4, Qwen3 - no API costs
- **Real-Time Streaming**: All dispatchers support `--stream` flag
- **AI-Enhanced Workflows**: todo debug/delegate, journal analyze/mood/themes, blog generate/refine
- **Advanced Features**: ai-suggest, dhp-project, dhp-chain, context injection

### Previous Phases: Foundation & Core Features

- **Advanced Task Management**: `todo commit`, `todo bump`, `todo top` with stale task tracking
- **Health & Medication Tracking**: `health dashboard`, `meds dashboard` with 30-day trend analysis
- **Enhanced Journal**: `journal search`, `journal onthisday` for building your second brain
- **Unified Navigation**: `g` command replaces goto/back/workspace with auto-venv and app launching
- **Knowledge Management**: `howto` wiki, `schedule` command wrapper, `review_clutter` for Desktop/Downloads
- **System Intelligence**: `dotfiles_check` validation, `systemlog` audit trail, automated backups
- **Blog Integration**: `blog status`, `blog recent`, `blog ideas`
- **Productivity Nudges**: `pomo` Pomodoro timer, `next` top priority, gamified progress tracking

## Helper Functions

| Function                      | Description                                                                 |
| ----------------------------- | --------------------------------------------------------------------------- |
| `exists <cmd>`                | True if a command is on `PATH`.                                             |
| `script_exists <script>`      | Returns success when `$SCRIPTS_DIR/<script>` exists and is executable.      |
| `run_script <script> [args…]` | Dispatch helper used by most wrappers—logs an error if a script is missing. |

These helpers make the rest of the file resilient—aliases are only created if the backing command exists.

## Navigation

| Alias                                                                          | Expands To                           | Notes                                                         |
| ------------------------------------------------------------------------------ | ------------------------------------ | ------------------------------------------------------------- |
| `..`, `...`, `....`                                                            | `cd ../`, etc.                       | Rapid parent directory navigation.                            |
| `ll`, `la`, `l`, `lt`, `lh`                                                    | Variants of `ls`.                    | Tailored listings for macOS.                                  |
| `here`, `tree`, `newest`, `biggest`, `count`                                   | Directory inspection helpers.        | `tree` uses `find`; `newest` and `biggest` show top 10 items. |
| `downloads`, `down`, `documents`, `docs`, `desktop`, `desk`, `scripts`, `home` | `cd` shortcuts.                      | `scripts` respects `$SCRIPTS_DIR`.                            |
| `cd()`                                                                         | Overrides builtin to record history. | Calls `recent_dirs.sh add` when available.                    |

## System & File Management

| Alias                                                                       | Command                                | Purpose                    |
| --------------------------------------------------------------------------- | -------------------------------------- | -------------------------- |
| `update`                                                                    | `brew update && brew upgrade`          | Refresh Homebrew packages. |
| `brewclean`, `brewinfo`                                                     | `brew cleanup`, `brew list --versions` | Routine maintenance.       |
| `myip`, `localip`, `mem`, `cpu`, `psg`                                      | System information snippets.           |
| `rm`, `cp`, `mv`                                                            | Interactive variants.                  | Adds confirmation prompts. |
| `untar`, `targz`, `ff`, `grep`, `showfiles`, `hidefiles`, `spotlight`       | File utilities.                        |
| `du`, `df`, `diskspace`, `ping`, `flushdns`, `c`, `cls`, `now`, `timestamp` | Mixed convenience commands.            |

## Editors & Apps

- `v`, `n`, `finder` map to `vim`, `nano`, and `open .`.
- `c.` becomes `code .` only when VS Code is installed (`exists code`).

## Git Shortcuts

Standard `git` abbreviations like `gs`, `gaa`, `gc`, `gd`, `gco`, and `glog` cover status, add, commit, diff, checkout, log, etc.

## Clipboard Helpers

| Function/Alias    | Usage                                                |
| ----------------- | ---------------------------------------------------- |
| `copy <text>`     | Pipe text into the clipboard (`copy reminder text`). |
| `copyfile <path>` | Send a file’s contents to the clipboard.             |
| `paste`           | `pbpaste`.                                           |

`clip` plus `clipsave`, `clipload`, and `cliplist` wrap `clipboard_manager.sh` (when present) for saved snippets.

Want deeper patterns? See `../docs/clipboard.md` for pipelines, formatting tricks, and real-world `pbcopy`/`pbpaste` workflows.

## Script Wrappers

Every script in `$SCRIPTS_DIR` has a corresponding wrapper function which ensures it exists before aliasing. Below are the high-level categories—refer to `README.md` for script-specific behaviour.

### Task & Notes (AI-Enhanced)

- `todo`, `t`, `todoadd`, `todolist`, `tododone` – **AI-Enhanced** task management with `commit`, `bump`, `top`, `debug` (AI debugging), `delegate` (route to AI specialist), `up` (quick edit)
- `next` – Show only your top priority task (`todo top 1`)
- `journal`, `j` – **AI-Enhanced** journal with `search`, `onthisday`, `up` (quick edit), `analyze` (7-day AI insights), `mood` (14-day sentiment), `themes` (30-day patterns)
- `health` – Comprehensive health tracking with symptoms, energy ratings, and `dashboard` for trends
- `meds` – Medication tracking with adherence monitoring and `remind` for automation
- `remind` – macOS notifications via `remind_me.sh`
- `break` – Health timer via `take_a_break.sh`
- `pomo` – 25-minute Pomodoro timer (alias for `take_a_break 25`)
- `weekreview`, `startday`, `goodevening`, `greeting`, `status`, `weather`
- `howto` – Personal searchable how-to wiki
- `schedule` – User-friendly wrapper for `at` command
- `blog` – **AI-Enhanced** blog workflow: `status`, `stubs`, `sync`, `ideas`, `generate` (AI content), `refine` (AI polish)

### Project & Workspace

- `g` – **Unified navigation** (replaces goto/back/workspace) with auto-venv activation and app launching
- ~~`goto`~~ – Deprecated, use `g` instead
- ~~`back`~~, ~~`recent`~~ – Deprecated, use `g -r` instead
- `newproject`, `newpython`, `newpy`, `projects` (find forgotten projects)
- `progress`, `backup`, `findbig`, `tidydown`, `organize`, `openf`, `finddupes`
- `review_clutter` – Interactive tool to archive/delete old Desktop and Downloads files
- `startday`, `goodevening`, `weekreview`

### System Tools

- `dotfiles_check` – Validate entire system (scripts, dependencies, data directory, GitHub token, AI dispatchers)
- `systemlog` – View last 20 automation events from central audit log
- `whatis` – Look up what an alias or command does
- `new_script` – Automate creation of new scripts with proper headers and aliases
- `backup_data` – Manual trigger for data backup (runs automatically in `goodevening`)

### AI Staff HQ Commands (NEW)

- `spec <dispatcher>` – Open structured template for AI request (tech, creative, content, strategy, market, research, stoic)
- `tech` / `dhp-tech` – Technical debugging and code analysis
- `creative` / `dhp-creative` – Story generation with full package
- `content` / `dhp-content` – SEO-optimized content creation
- `strategy` / `dhp-strategy` – Strategic analysis via Chief of Staff
- `brand` / `dhp-brand` – Brand positioning and voice development
- `market` / `dhp-market` – Market research and SEO analysis
- `stoic` / `dhp-stoic` – Stoic coaching and mindset reframing
- `research` / `dhp-research` – Knowledge synthesis and organization
- `narrative` / `dhp-narrative` – Story structure and plot analysis
- `copy` / `dhp-copy` – Marketing copy and sales messaging
- `ai-suggest` – Context-aware dispatcher suggestions
- `ai-project` / `dhp-project` – Multi-specialist orchestration
- `ai-chain` / `dhp-chain` – Sequential dispatcher chaining

**Flags:** All dispatchers support `--stream` for real-time output
**Setup:** `cp .env.example .env` and add your OPENROUTER_API_KEY
**Docs:** See `/bin/README.md` for complete dispatcher documentation

### System Diagnostics

- `sysinfo`, `batterycheck`, `processes`, `topcpu`, `topmem`
- `netinfo`, `netstatus`, `netspeed`

### Text & Media Processing

- `textproc`, `wordcount`, `textsearch`, `textreplace`, `textclean`
- `graballtext` – Runs `grab_all_text.sh` to collate readable files into `all_text_contents.txt`.
- `media`, `video2audio`, `resizeimg`, `compresspdf`
- `archive`, `archcreate`, `archextract`, `archlist`
- `unpack`
- `mtg`

### Development Shortcuts

- `dev`, `server`, `json`, `gitquick`
- `devenv` (sources the virtualenv helper)
- `devstart` (open VS Code after activating the venv)
- `gitcheck`

### Notification & Completion

- `done` – Run long commands with notification on completion
- `app`, `launch` – Favorite app launcher (favorites in `~/.config/dotfiles-data/favorite_apps`)
- `clip` + subcommands – Clipboard manager (saved in `~/.config/dotfiles-data/clipboard_history/`)

## Compound Helpers

| Alias         | Description                                             |
| ------------- | ------------------------------------------------------- |
| `info`        | Weather + todo list summary.                            |
| `status`      | Journal + todo list snapshot.                           |
| `overview`    | System info + battery summary.                          |
| `cleanup`     | Organize `~/Downloads` and list large files.            |
| `quickbackup` | Run `backup_project.sh` and print success message.      |
| `devstart`    | Activate the dev venv and open VS Code (requires both). |
| `gitcheck`    | Show recent progress then `git status`.                 |

## Utility Functions

| Function             | Purpose                                                  |
| -------------------- | -------------------------------------------------------- |
| `mkcd <dir>`         | Create and `cd` into a directory.                        |
| `backup_file <path>` | Append a timestamped copy beside the original.           |
| `pman <topic>`       | Render man pages into Preview.                           |
| `search <pattern>`   | `find . -name "*pattern*" -type f`.                      |
| `morning`            | Weather, todo list, and Git status for the current repo. |
| `endday`             | End-of-day checklist and Git summary.                    |

## Tips

- Scripts directory (`~/dotfiles/scripts`) is added to PATH in `~/.zprofile`.
- All data files are centralized in `~/.config/dotfiles-data/` for easy backup.
- The `cd` override records directory history to `~/.config/dotfiles-data/dir_history`.
- Navigation bookmarks are stored in `~/.config/dotfiles-data/dir_bookmarks`.
- Add new scripts by placing them in `~/dotfiles/scripts/`, making them executable, and adding aliases in `~/dotfiles/zsh/aliases.zsh`.

Happy aliasing!
