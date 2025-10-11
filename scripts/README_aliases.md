# macOS zsh Alias Pack

This document complements the `~/.zsh_aliases` file. It explains the purpose of each alias/function, the prerequisites they rely on, and a few example flows.

## Quick Start

1. Ensure your scripts live under a directory exported as `SCRIPTS_DIR` (defaults to `~/scripts`).
2. Copy `.zsh_aliases` into your home directory and source it from `~/.zshrc`:
   ```bash
   echo 'source ~/.zsh_aliases' >> ~/.zshrc
   ```
3. Reload your shell: `source ~/.zshrc`.
4. Confirm required tools (Homebrew, git, Python 3, macOS utilities) are installed. Third-party dependencies (e.g. VS Code, `ffmpeg`) are optional, and the aliases gracefully skip features that aren’t available.

## Helper Functions

| Function | Description |
| -------- | ----------- |
| `exists <cmd>` | True if a command is on `PATH`. |
| `script_exists <script>` | Returns success when `$SCRIPTS_DIR/<script>` exists and is executable. |
| `run_script <script> [args…]` | Dispatch helper used by most wrappers—logs an error if a script is missing. |

These helpers make the rest of the file resilient—aliases are only created if the backing command exists.

## Navigation

| Alias | Expands To | Notes |
| ----- | ---------- | ----- |
| `..`, `...`, `....` | `cd ../`, etc. | Rapid parent directory navigation. |
| `ll`, `la`, `l`, `lt`, `lh` | Variants of `ls`. | Tailored listings for macOS. |
| `here`, `tree`, `newest`, `biggest`, `count` | Directory inspection helpers. | `tree` uses `find`; `newest` and `biggest` show top 10 items. |
| `downloads`, `down`, `documents`, `docs`, `desktop`, `desk`, `scripts`, `home` | `cd` shortcuts. | `scripts` respects `$SCRIPTS_DIR`. |
| `cd()` | Overrides builtin to record history. | Calls `recent_dirs.sh add` when available. |

## System & File Management

| Alias | Command | Purpose |
| ----- | ------- | ------- |
| `update` | `brew update && brew upgrade` | Refresh Homebrew packages. |
| `brewclean`, `brewinfo` | `brew cleanup`, `brew list --versions` | Routine maintenance. |
| `myip`, `localip`, `mem`, `cpu`, `psg` | System information snippets. |
| `rm`, `cp`, `mv` | Interactive variants. | Adds confirmation prompts. |
| `untar`, `targz`, `ff`, `grep`, `showfiles`, `hidefiles`, `spotlight` | File utilities. |
| `du`, `df`, `diskspace`, `ping`, `flushdns`, `c`, `cls`, `now`, `timestamp` | Mixed convenience commands. |

## Editors & Apps

- `v`, `n`, `finder` map to `vim`, `nano`, and `open .`.
- `c.` becomes `code .` only when VS Code is installed (`exists code`).

## Git Shortcuts

Standard `git` abbreviations like `gs`, `gaa`, `gc`, `gd`, `gco`, and `glog` cover status, add, commit, diff, checkout, log, etc.

## Clipboard Helpers

| Function/Alias | Usage |
| -------------- | ----- |
| `copy <text>` | Pipe text into the clipboard (`copy reminder text`). |
| `copyfile <path>` | Send a file’s contents to the clipboard. |
| `paste` | `pbpaste`. |

`clip` plus `clipsave`, `clipload`, and `cliplist` wrap `clipboard_manager.sh` (when present) for saved snippets.

Want deeper patterns? See `../docs/clipboard.md` for pipelines, formatting tricks, and real-world `pbcopy`/`pbpaste` workflows.

## Script Wrappers

Every script in `$SCRIPTS_DIR` has a corresponding wrapper function which ensures it exists before aliasing. Below are the high-level categories—refer to `README.md` for script-specific behaviour.

### Task & Notes

- `todo`, `t`, `todoadd`, `todolist`, `tododone`
- `journal`, `j`
- `memo`
- `note`, `noteadd`, `notesearch`, `notetoday`
- `remind` (macOS notifications via `remind_me.sh`)
- `break` (health timer)
- `weekreview`, `startday`, `goodevening`, `greeting`, `weather`

### Project & Workspace

- `goto`, `g`
- `back`, `recent`
- `newproject`, `newpython`, `newpy`
- `progress`, `backup`, `findbig`, `tidydown`, `organize`, `openf`, `finddupes`
- `startday`, `goodevening`, `weekreview`

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

- `done` (wrapper for `done.sh` via `finish()`)
- `app`, `launch` (favorite app launcher)
- `clip` + subcommands (clipboard manager)

## Compound Helpers

| Alias | Description |
| ----- | ----------- |
| `info` | Weather + todo list summary. |
| `status` | Journal + todo list snapshot. |
| `overview` | System info + battery summary. |
| `cleanup` | Organize `~/Downloads` and list large files. |
| `quickbackup` | Run `backup_project.sh` and print success message. |
| `devstart` | Activate the dev venv and open VS Code (requires both). |
| `gitcheck` | Show recent progress then `git status`. |

## Utility Functions

| Function | Purpose |
| -------- | ------- |
| `mkcd <dir>` | Create and `cd` into a directory. |
| `backup_file <path>` | Append a timestamped copy beside the original. |
| `pman <topic>` | Render man pages into Preview. |
| `search <pattern>` | `find . -name "*pattern*" -type f`. |
| `morning` | Weather, todo list, and Git status for the current repo. |
| `endday` | End-of-day checklist and Git summary. |

## Tips

- Keep `$SCRIPTS_DIR` on your `PATH` so manual calls work (`export PATH="$SCRIPTS_DIR:$PATH"`).
- Run `run_script <name>` to confirm a wrapper can find its script.
- The `cd` override only records directory history when `recent_dirs.sh` is executable; remove the block if you prefer the default behaviour.
- Add new scripts by placing them in `$SCRIPTS_DIR`, making them executable, and mirroring the wrapper style shown above.

Happy aliasing!
