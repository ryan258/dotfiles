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

  * **Productivity & Task Management:** Advanced todo flow with prioritization, git-integrated commits, encouraging feedback, and `todo undo`; quick journaling plus `dump` for long-form context capture; health and medication tracking with dashboards; weekly and daily reviews generated from recorded activity.
  * **Project & Workspace Management:** Scaffold new projects, create timestamped backups, and save/load directory contexts with intelligent state management (auto-activates venvs, launches apps, logs usage, and can suggest where to jump next).
  * **Knowledge Management:** Personal searchable how-to wiki, blog content integration with todo system, journal search/"on this day", and weekly Markdown summaries for looking back.
  * **System & Network Diagnostics:** Quick hardware, CPU, and memory snapshots, battery status, network troubleshooting, system validation, and audit logging so automation never feels opaque.
  * **File & Archive Utilities:** Effortlessly organize `~/Downloads`, find large or duplicate files, manage/inspect archives, and run interactive clutter reviews to keep surfaces clean.
  * **Development Shortcuts:** Automate common Git workflows, manage Python environments, spin up project workspaces, and schedule future commands without leaving the shell.
  * **macOS Integration:** Enhanced clipboard manager with dynamic snippets, saved clip executions, notifications, LaunchAgent-friendly scripts, and a unified shell environment across Terminal and VS Code.

## What's New (November 2025 Refresh)

Round 2 shipped earlier this month and we immediately layered on quality-of-life upgrades to tighten the daily loop:

  * **Focus & Daily Anchor:** A new `focus` command stores the day's intention so `startday` can surface it at the very top of your morning briefing.
  * **Smarter Morning Briefing:** `startday` now pulls GitHub activity, syncs blog stubs to todos, highlights suggested directories via `g suggest`, and links to the latest weekly review file when it's Monday.
  * **Weekly Review Automation:** `week_in_review.sh --file` writes a Markdown recap to `~/Documents/Reviews/Weekly/`, and `setup_weekly_review.sh` can schedule it so Sunday summaries appear automatically.
  * **Safety Nets & Backups:** `goodevening` validates structured data (expects `scripts/data_validate.sh`) before running `backup_data.sh`, so nightly backups only proceed when files look healthy.
  * **Task Flow Upgrades:** `todo undo` rescues accidental completions, and both `todo add`/`todo done` cheer you on. Pair that with the new `dump` script for long-form journaling on foggy days.
  * **Navigation Intelligence:** `g.sh` logs directory usage and can suggest where to jump next; `g prune --auto` keeps dead bookmarks out of the way.

See `CHANGELOG.md` for the play-by-play of the latest blindspots and fixes.

## AI Staff HQ Integration

**NEW:** Your dotfiles now include a complete AI workforce powered by **10 active dispatchers** plus **4 advanced features** (multi-specialist orchestration, context-aware suggestions, dispatcher chaining, and local context injection) accessing 42 specialized professionals through the [AI-Staff-HQ](https://github.com/ryan258/AI-Staff-HQ) submodule.

### Quick Start with Dispatchers

Access your AI specialists instantly via high-speed dispatcher scripts:

```bash
# Technical & Development
cat broken-script.sh | tech           # Debug code issues
echo "Optimize this function" | tech  # Get technical advice

# Creative & Content
creative "lighthouse keeper story"    # Generate story package
narrative "analyze plot structure"    # Story structure analysis
copy "product launch email"           # Marketing copy

# Strategy & Analysis
echo "Brand positioning for tech blog" | brand    # Brand analysis
echo "SEO keywords for AI content" | market       # Market research
tail -50 journal.txt | strategy                   # Strategic insights

# Personal Development
echo "Overwhelmed by perfectionism" | stoic      # Stoic coaching
cat research-notes.md | research                  # Knowledge synthesis

# Advanced Features
ai-suggest                                        # Get context-aware suggestions
dhp-project "new project idea"                    # Multi-specialist orchestration
dhp-chain creative narrative copy -- "idea"       # Chain multiple specialists
dhp-content --context "guide topic"               # Use local context injection
```

### 10 Active AI Dispatchers

**Technical (1):**
- `tech` / `dhp-tech` - Code debugging, optimization, technical analysis

**Creative (3):**
- `creative` / `dhp-creative` - Complete story packages (horror specialty)
- `narrative` / `dhp-narrative` - Story structure, plot development, character arcs
- `copy` / `dhp-copy` - Sales copy, email sequences, landing pages

**Strategy & Analysis (3):**
- `strategy` / `dhp-strategy` - Strategic insights via Chief of Staff
- `brand` / `dhp-brand` - Brand positioning, voice/tone, competitive analysis
- `market` / `dhp-market` - SEO research, trends, audience insights

**Content (1):**
- `content` / `dhp-content` - SEO-optimized guides and evergreen content

**Personal Development (2):**
- `stoic` / `dhp-stoic` - Mindset coaching through stoic principles
- `research` / `dhp-research` - Knowledge organization and synthesis

### Workflow Integrations

AI specialists are deeply integrated into daily workflows:

**Blog Workflow:**
```bash
blog generate my-stub-name    # AI-generate full content from stub
blog refine my-post.md         # AI-polish existing draft
```

**Todo Integration:**
```bash
todo debug 1                   # AI debug a technical task
todo delegate 3 creative       # Delegate task to AI specialist
```

**Journal Analysis:**
```bash
journal analyze                # AI insights from last 7 days
journal mood                   # Sentiment analysis (14 days)
journal themes                 # Theme extraction (30 days)
```

**Optional Daily AI Features:**
Set in `.env` to enable:
- `AI_BRIEFING_ENABLED=true` - Morning AI focus suggestion (cached daily)
- `AI_REFLECTION_ENABLED=true` - Evening AI reflection on accomplishments

### Advanced AI Features

**Multi-Specialist Orchestration:**
```bash
dhp-project "Launch new blog series on AI productivity"
# or: ai-project "project description"

# Coordinates 5 specialists in sequence:
# Market Analyst → Brand Builder → Chief of Staff → Content Specialist → Copywriter
# Outputs comprehensive markdown project brief
```

**Context-Aware Suggestions:**
```bash
ai-suggest

# Analyzes your current context and suggests relevant dispatchers:
# - Current directory and project type
# - Recent git commits and repo status
# - Active todo items and recent journal entries
# - Time-based suggestions (morning/evening)
```

**Dispatcher Chaining:**
```bash
dhp-chain creative narrative copy -- "lighthouse keeper finds artifact"
# or: ai-chain dispatcher1 dispatcher2 -- "input"

# Sequential AI processing:
# creative → generates story → narrative → expands plot → copy → creates hook
# Use --save <file> to save output
```

**Local Context Injection:**
```bash
dhp-content --context "Guide on productivity with AI"
# Includes: git status, top tasks, recent blog topics

dhp-content --full-context "Comprehensive guide topic"
# Includes: journal, todos, README, full git history

# Context injection available via dhp-context.sh library
# Prevents duplicate content, aligns with current work
```

### Setup Requirements

1. **Environment Configuration:** Copy `.env.example` to `.env` and add your OpenRouter API key:
   ```bash
   cp .env.example .env
   # Edit .env and add your OPENROUTER_API_KEY
   ```

2. **Get an API Key:** Sign up at [OpenRouter](https://openrouter.ai/) and create an API key

3. **Configure Models:** The `.env` file includes sensible defaults (GPT-4o family recommended)

4. **Verify Installation:** Run the system check:
   ```bash
   bash scripts/dotfiles_check.sh
   # Should report: "✅ Found 10/10 dispatchers"
   ```

### Full AI Workforce Access

The 10 dispatchers provide access to 42+ specialists across 7 departments:
- **Creative:** Art Director, Copywriter, Narrative Designer, Sound Designer, and more
- **Strategy:** Chief of Staff, Brand Builder, Market Analyst, Creative Strategist
- **Technical:** Automation Specialist, Prompt Engineer, Toolmaker, Productivity Architect
- **Personal:** Stoic Coach, Patient Advocate, Head Librarian
- **Kitchen:** Executive Chef, Nutritionist, Sommelier (11 specialists)
- **Commercialization:** Literary Agent
- **Specialized:** Historical Storyteller, Futurist, Transmedia Producer, and more

See `bin/README.md` for detailed dispatcher documentation, `ROADMAP.md` for implementation status, and `CHANGELOG.md` for complete feature history.

## Daily Loop at a Glance

  * `startday` launches automatically once per calendar day on your first shell, greeting you with the day's focus, fresh GitHub pushes, suggested directories, blog sync results, and health reminders.
  * Capture intentions with `focus "Ship the review"` (clear with `focus clear`) so your morning dashboard anchors you immediately.
  * Use `status` for midday course-correction, `todo` for prioritized tasks (`bump`, `top`, `undo`, `commit`), and `dump`/`journal` to keep context searchable.
  * Close out with `goodevening` to celebrate wins, spot risky repos, validate data, and trigger `backup_data.sh`.
  * Run `weekreview --file` or schedule it with `setup_weekly_review.sh` for an automatic Sunday recap saved to `~/Documents/Reviews/Weekly/`.

Need the expanded playbook? Check `docs/happy-path.md` for the brain-fog-friendly walkthrough.

## Prerequisites

This setup assumes you are on macOS with Zsh (the default shell). You will also need:

  * **Homebrew:** The missing package manager for macOS.
  * **Core CLIs:** `jq`, `curl`, and `gawk` (the bootstrap script installs/updates them for you).
  * **Optional Extras:** Install with Homebrew for specific workflows:
      * `ffmpeg`: Convert video to audio.
      * `imagemagick`: Resize images.
      * `ghostscript`: Compress PDFs.
      * `unrar`: Extract `.rar` archives.

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
  * `dir_bookmarks`, `dir_history`, `dir_usage.log` – Smart navigation bookmarks, history, and frequency scores
  * `favorite_apps` – Application launcher shortcuts
  * `daily_focus.txt` – Stores the current focus surfaced by `startday`
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
| `todo`         | Advanced todo list manager with `add`, `list`, `done`, `undo`, `commit`, `bump`, `top` plus encouraging feedback and git integration. |
| `journal`      | Timestamped journal with `search`, `onthisday`, and quick capture aliases for building your second brain. |
| `dump`         | Launches `$EDITOR` for long-form brain dumps, appending the result to `journal.txt` with a timestamp. |
| `health`       | Track appointments, symptoms, and energy levels with `dashboard` for 30-day trend analysis. |
| `meds`         | Medication tracking system with `check`, `log`, `remind`, and `dashboard` for adherence monitoring. |
| `focus`        | Set, show, or clear the day's focus message surfaced by `startday`. |
| `startday`     | Automated morning routine with focus reminder, GitHub activity, blog sync, suggested directories, health snapshot, weekly review link, stale tasks, and top priorities. |
| `goodevening`  | End-of-day summary with gamified wins, project safety checks, data validation (expects `data_validate.sh`), and automated backups. |
| `weekreview`   | Weekly recap of tasks, journal entries, and git commits; use `--file` to export to Markdown. |
| `setup_weekly_review` | Schedule `weekreview --file` via the friendly `schedule.sh` wrapper for Sunday evenings. |
| `g` (source)   | Unified navigation system – bookmarks, recent dirs, usage logging, suggestions, auto-venv activation, on-enter commands, and optional app launching. |
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
