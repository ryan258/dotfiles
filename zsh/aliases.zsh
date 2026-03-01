# ~/.zsh_aliases
# Complete shell aliases optimized for macOS/zsh
# Designed to reduce typing and cognitive load for daily workflows.
#
# IMPORTANT: This file is SOURCED by .zshrc — do NOT use set -euo pipefail.
# Use 'return' instead of 'exit'. See CLAUDE.md § Sourced vs Executed Scripts.
#
# Organization:
#   1. Navigation & directories    7. Development shortcuts
#   2. System management (macOS)   8. Clipboard & macOS utilities
#   3. File operations             9. Core productivity scripts
#   4. Git shortcuts              10. AI dispatchers
#   5. Text editing               11. Accessibility & ergonomics
#   6. Utility shortcuts          12. Functions

# =============================================================================
# NAVIGATION & DIRECTORY SHORTCUTS
# =============================================================================

# Resolve dotfiles root for aliases that reference scripts by absolute path.
# Falls back to ~/dotfiles if $DOTFILES_DIR isn't set by config.sh.
DOTFILES_ALIAS_ROOT="${DOTFILES_DIR:-$HOME/dotfiles}"

# Ancestor directory traversal — saves repeated "cd .." typing
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

# Enhanced directory listing (uses macOS /bin/ls flags)
# -a = all (incl dotfiles), -l = long, -F = append type indicator (/ @ *)
# -A = all except . and .., -C = columns, -t = sort by time, -r = reverse,
# -h = human-readable sizes, -S = sort by size
alias ll="ls -alF"                 # Full detail + type indicators
alias la="ls -A"                   # All except . and ..
alias l="ls -CF"                   # Compact columns with type indicators
alias lt="ls -altr"                # Chronological, newest at bottom
alias lh="ls -alh"                 # Sizes in K/M/G instead of bytes

# Quick inspection of the current directory
alias here="ls -la"                # Everything in this directory, long format
alias dtree="find . -type d | head -20"  # Directory tree sketch (avoids shadowing /usr/bin/tree)
alias newest="ls -lt | head -10"   # 10 most recently modified files
alias biggest="ls -lS | head -10"  # 10 largest files by size
alias count="ls -1 | wc -l"        # Count of items in current directory

# Quick-jump to common Finder locations
# Full names for readability; short names below for speed
alias downloads="cd ~/Downloads"
alias documents="cd ~/Documents"
alias desktop="cd ~/Desktop"
alias scripts="cd ~/scripts"
alias home="cd ~"
alias docs="cd ~/Documents"        # Short form of 'documents'
alias down="cd ~/Downloads"        # Short form of 'downloads'
alias desk="cd ~/Desktop"          # Short form of 'desktop'

# =============================================================================
# SYSTEM MANAGEMENT (macOS)
# =============================================================================

# Homebrew package manager — 'update' fetches formulae then upgrades all pkgs
alias update="brew update && brew upgrade"
alias brewclean="brew cleanup"             # Remove old versions and stale downloads
alias brewinfo="brew list --versions"      # Show every installed formula + version

# Quick system diagnostics
alias myip="curl ifconfig.me"              # Public/external IP via ifconfig.me API
alias localip="ifconfig | grep inet"       # All local interface IPs (IPv4 + IPv6)
alias mem="vm_stat"                        # macOS virtual memory stats (page-based)
alias cpu="top -l 1 | head -n 10"         # One-shot top snapshot, header only

# Process search — e.g. `psg python` to find running Python processes
alias psg="ps aux | grep"

# =============================================================================
# FILE OPERATIONS
# =============================================================================

# Safety nets — -i flag prompts "are you sure?" before destructive actions.
# Prevents accidental overwrites/deletions in interactive shell sessions.
alias rm="rm -i"                          # Confirm before every removal
alias cp="cp -i"                          # Confirm before overwriting target
alias mv="mv -i"                          # Confirm before overwriting target

# Archive shortcuts — saves remembering tar flag combos
alias untar="tar -xvf"                    # eXtract Verbosely from File
alias targz="tar -czvf"                   # Create gZipped tar archive Verbosely

# File search — e.g. `ff '*.json'` to find all JSON files recursively
alias ff="find . -name"
# NOTE: grep alias with color is defined at bottom of file (portable ggrep detection)

# macOS Finder hidden-file toggle (restarts Finder to apply)
alias showfiles="defaults write com.apple.finder AppleShowAllFiles YES && killall Finder"
alias hidefiles="defaults write com.apple.finder AppleShowAllFiles NO && killall Finder"
# Spotlight search from terminal — uses macOS metadata index, very fast
alias spotlight="mdfind"

# =============================================================================
# GIT SHORTCUTS
# Convention: 'g' prefix + first letter(s) of git subcommand
# =============================================================================

alias gs="git status"                     # Working tree status
alias ga="git add"                        # Stage specific files — e.g. `ga file.txt`
alias gaa="git add ."                     # Stage everything in cwd (use with care)
alias gc="git commit -m"                  # Commit with inline message — e.g. `gc "fix bug"`
alias gp="git push"                       # Push current branch to remote
alias gl="git pull"                       # Pull (fetch + merge) from remote
alias gd="git diff"                       # Unstaged changes vs last commit
alias gb="git branch"                     # List or create branches
alias gco="git checkout"                  # Switch branches or restore files
alias glog="git log --oneline"            # Compact one-line-per-commit log
alias gn="npx gitnexus analyze"           # Analyze repo with GitNexus

# =============================================================================
# TEXT EDITING & VIEWING
# =============================================================================

# Single-letter editor launchers — open files fast from terminal
alias v="vim"                             # e.g. `v config.yaml`
alias n="nano"                            # e.g. `n notes.txt` (simpler editor)
alias e="echo"                            # Quick echo for piping/testing

# Open current directory in GUI applications
alias codehere="code ."                   # Launch VS Code rooted here
alias finder="open ."                     # Launch Finder window here

# =============================================================================
# UTILITY SHORTCUTS
# =============================================================================

# Screen clearing — two muscle-memory options
alias c="clear"                           # Minimal keystroke clear
alias cls="clear"                         # For muscle memory from Windows/DOS

# Date and time — handy for filenames and quick checks
alias now="date"                          # Current date/time in default locale
alias timestamp="date +%Y%m%d_%H%M%S"     # Filename-safe timestamp (no colons/spaces)

# Disk usage — -h makes sizes human-readable (K/M/G)
alias du="du -h"                          # Directory size summary
alias df="df -h"                          # Filesystem free space
alias diskspace="df -h"                   # Readable alias for df

# Network utilities
alias ping="ping -c 5"                    # Limit to 5 pings (macOS ping runs forever by default)
alias flushdns="sudo dscacheutil -flushcache" # Clear macOS DNS resolver cache

# =============================================================================
# DEVELOPMENT SHORTCUTS
# =============================================================================

# Python — ensure Python 3 is always the default (macOS ships Python 2 as 'python')
alias python="python3"
alias pip="pip3"
alias venv="python3 -m venv"              # Create venv — e.g. `venv .venv`
alias activate="source venv/bin/activate" # Activate a venv in ./venv/

# Web development utilities (no dependencies beyond Python stdlib)
alias serve="python3 -m http.server"      # HTTP server on :8000 for current dir
alias jsonpp="python3 -m json.tool"       # Pretty-print JSON from stdin or file

# =============================================================================
# MACOS CLIPBOARD & UTILITIES
# =============================================================================

# Clipboard — wraps macOS pbcopy/pbpaste with memorable names
# IMPORTANT: 'copy' = clipboard, NOT the AI copywriter (that's 'aicopy')
alias copy="pbcopy"                       # Pipe text to clipboard — e.g. `echo hi | copy`
alias paste="pbpaste"                     # Emit clipboard contents to stdout
alias copyfile="pbcopy <"                 # Copy a file's contents — e.g. `copyfile notes.txt`
alias copyfolder="tail -n +1 * | pbcopy"  # Copy ALL files' contents in cwd to clipboard

# macOS power and hardware controls
alias screensleep="pmset displaysleepnow" # Immediately sleep the display
alias lock="pmset displaysleepnow"        # Lock screen (display sleep triggers lock)
alias eject="diskutil eject"              # Eject external disk — e.g. `eject /dev/disk2`
alias battery="pmset -g batt"             # Show battery % and charging status

# =============================================================================
# CORE PRODUCTIVITY SCRIPTS
# These wrap scripts in ~/dotfiles/scripts/ — the heart of the productivity system.
# =============================================================================

# Quick-reference and system health
alias howto="howto.sh"                    # Interactive help / how-to lookup
alias wi="whatis.sh"                      # Explain a command (named 'wi' to avoid shadowing /usr/bin/whatis)
alias dotfiles_check="dotfiles_check.sh"  # Verify dotfiles installation integrity
alias dotfiles-check="dotfiles_check.sh"  # Hyphenated alternative for the same check

# --- Task & Time Management ---
alias pomo="take_a_break.sh 25"           # Pomodoro timer — 25-minute focus session
alias todo="todo.sh"                      # Task manager entry point
alias idea="idea.sh"                      # Idea manager entry point
alias todolist="todo.sh list"             # List all open tasks
alias tododone="todo.sh done"             # Mark a task as completed
alias todoadd="todo.sh add"              # Add a new task
alias journal="journal.sh"               # Journal entry point
alias break="take_a_break.sh"            # Flexible break timer (default duration)
alias focus="focus.sh"                    # Focus mode — block distractions

# --- Time Tracking (task-level start/stop timers) ---
alias t-start="todo.sh start"            # Start timing a task
alias t-stop="todo.sh stop"              # Stop timing the current task
alias t-status="time_tracker.sh status"  # Show what's being tracked and elapsed time

# --- Spoon Budget (energy management for MS) ---
# Spoon theory: each day has a limited energy budget. These track spending.
alias spoons="spoon_manager.sh"           # Full spoon manager interface
alias s-check="spoon_manager.sh check"    # How many spoons remain today?
alias s-spend="spoon_manager.sh spend"    # Log spending spoons on an activity

# --- Correlation & Reports ---
alias correlate="correlate.sh"            # Find patterns between health/productivity data
alias daily-report="generate_report.sh daily"  # Generate today's summary report
alias insight="insight.sh"                # AI-powered insight from recent data

# --- Health Tracking ---
alias health="health.sh"                  # Log symptoms, energy, and health events
alias meds="meds.sh"                      # Medication tracking and reminders

# --- Ultra-Short Aliases (most-used commands deserve fewest keystrokes) ---
alias next="todo.sh top 1"               # Show the single highest-priority task
alias t="todo.sh list"                    # 1-key todo list
alias j="journal.sh"                      # 1-key journal
alias ta="todo.sh add"                    # 2-key task add — e.g. `ta "Buy groceries"`
alias ja="journal.sh add"                 # 2-key journal add — e.g. `ja "Good energy today"`

# --- Information & Utilities ---
alias memo="cheatsheet.sh"               # Show personal cheatsheet / quick reference
alias schedule="schedule.sh"             # View today's schedule
alias clutter="review_clutter.sh"        # Review and clean up stale files
alias checkenv="validate_env.sh"         # Validate .env config is complete and correct
alias newscript="new_script.sh"          # Scaffold a new bash script with proper headers
alias weather="weather.sh"               # Current weather forecast
alias findtext="findtext.sh"             # Search file contents recursively
alias graballtext="grab_all_text.sh"     # Concatenate all text files in a directory

# --- Project & Development Tools ---
alias newproject="start_project.sh"      # Scaffold a new project directory
alias newpython="mkproject_py.sh"        # Scaffold a Python project with venv
alias newpy="mkproject_py.sh"            # Short form of newpython
alias progress="my_progress.sh"          # Show git contribution stats / progress
alias projects="gh-projects.sh"          # List GitHub projects

# --- File & System Management ---
alias backup="backup_project.sh"         # Back up current project directory
alias backup-data="backup_data.sh"       # Back up ~/.config/dotfiles-data/
alias findbig="findbig.sh"              # Find large files eating disk space
alias unpack="unpacker.sh"              # Smart archive extractor (tar/zip/gz/etc.)
alias tidydown="tidy_downloads.sh"      # Auto-organize ~/Downloads by file type

# --- Daily Routine Scripts ---
alias startday="startday.sh"             # Morning routine: weather, briefing, todos, spoons
alias goodevening="goodevening.sh"       # Evening wind-down: journal prompt, summary
alias greeting="greeting.sh"             # Quick motivational greeting
alias weekreview="week_in_review.sh"     # Weekly retrospective summary

# =============================================================================
# NAVIGATION & FILE MANAGEMENT SCRIPTS
# =============================================================================

# Smart bookmark-based navigation — MUST be sourced (changes parent shell's cwd)
# Usage: `g myproject` to jump to a bookmarked directory
alias g="source $DOTFILES_ALIAS_ROOT/scripts/g.sh"

# File operations
alias openf="open_file.sh"               # Open a file with its default macOS app
# alias open= (disabled — 'open' is a macOS built-in, don't shadow it)
alias finddupes="duplicate_finder.sh"     # Find duplicate files by content hash
alias organize="file_organizer.sh"        # Auto-organize files by type/date

# =============================================================================
# SYSTEM MONITORING SCRIPTS (macOS)
# =============================================================================

# Log inspection — reads from the dotfiles unified log
alias systemlog="tail -n 20 ~/.config/dotfiles-data/system.log"  # Last 20 log lines
alias logs="logs.sh"                      # Full log viewer
alias logtail="logs.sh tail"              # Follow log in real time
alias logerrors="logs.sh errors"          # Show only error-level entries

# System information dashboards
alias sysinfo="system_info.sh"            # CPU, memory, disk, OS summary
alias batterycheck="battery_check.sh"     # Detailed battery health report
alias processes="process_manager.sh"      # Interactive process manager
alias netinfo="network_info.sh"           # Network interfaces and connectivity

# Quick system checks — skip the full dashboard, get one answer
alias topcpu="process_manager.sh top"     # Processes sorted by CPU usage
alias topmem="process_manager.sh memory"  # Processes sorted by memory usage
alias netstatus="network_info.sh status"  # Am I connected? What IP?
alias netspeed="network_info.sh speed"    # Quick bandwidth test

# Calendar integration (Google Calendar via gcal.sh)
alias gcal="gcal.sh"
alias calendar="gcal.sh"                  # Note: intentionally shadows /usr/bin/calendar

# =============================================================================
# PRODUCTIVITY & AUTOMATION SCRIPTS
# =============================================================================

# Clipboard history manager — save/load named clipboard slots
alias clip="clipboard_manager.sh"         # Full clipboard manager interface
alias clipsave="clipboard_manager.sh save"   # Save current clipboard to a named slot
alias clipload="clipboard_manager.sh load"   # Load a named slot back to clipboard
alias cliplist="clipboard_manager.sh list"   # List all saved clipboard slots

# Application launcher (fuzzy app opening)
alias app="app_launcher.sh"
alias launch="app_launcher.sh"            # Synonym for discoverability

# Reminders and "done" logging
alias remind="remind_me.sh"              # Set a timed reminder notification
alias did="done.sh"                      # Log a completed activity ('done' is a shell reserved word)

# Development shortcuts — common dev tasks behind one command
alias dev="dev_shortcuts.sh"              # Dev shortcuts menu
alias server="dev_shortcuts.sh server"    # Start a local dev server
alias json="dev_shortcuts.sh json"        # JSON formatting/inspection
# alias env="dev_shortcuts.sh env"        # Disabled — 'env' is a POSIX built-in
alias gitquick="dev_shortcuts.sh gitquick"  # Quick git add+commit+push

# =============================================================================
# FILE PROCESSING & ANALYSIS SCRIPTS
# =============================================================================

# Text processing — bulk text operations without opening an editor
alias textproc="text_processor.sh"              # Full text processor menu
alias wordcount="text_processor.sh count"       # Word/line/char count
alias textsearch="text_processor.sh search"     # Search within files
alias textreplace="text_processor.sh replace"   # Find-and-replace across files
alias textclean="text_processor.sh clean"       # Strip whitespace, fix encoding, etc.

# Media conversion — wraps ffmpeg/imagemagick with simple interfaces
alias media="media_converter.sh"                # Full media converter menu
alias video2audio="media_converter.sh video2audio"   # Extract audio track from video
alias resizeimg="media_converter.sh resize_image"    # Resize images (preserves aspect)
alias compresspdf="media_converter.sh pdf_compress"  # Reduce PDF file size
alias stitch="media_converter.sh audio_stitch"       # Concatenate audio files

# Archive management — create, extract, inspect archives
alias archive="archive_manager.sh"              # Full archive manager menu
alias archcreate="archive_manager.sh create"    # Create a new archive
alias archextract="archive_manager.sh extract"  # Extract an archive
alias archlist="archive_manager.sh list"        # List archive contents without extracting

# =============================================================================
# COMPOUND ALIASES (multi-command pipelines for common workflows)
# =============================================================================

# Information dashboards — at-a-glance system + productivity state
alias info="weather.sh && echo && todo.sh list"           # Weather + open tasks
alias status="status.sh"                                  # Unified status dashboard
alias overview="system_info.sh && echo && battery_check.sh"  # Hardware + battery

# Quick maintenance routines
alias cleanup="cd ~/Downloads && file_organizer.sh bytype && findbig.sh"  # Tidy Downloads, flag large files
alias quickbackup="backup_project.sh && echo 'Backup complete!'"          # One-command project backup

# Development workflow starters
alias devstart="dev_shortcuts.sh env && codehere"         # Load env vars, open VS Code
alias gitcheck="my_progress.sh && git status"             # Contribution stats + working tree

# =============================================================================
# FUNCTIONS (logic that can't be expressed as simple aliases)
# Functions are used when we need: conditionals, multiple steps, or arguments
# in non-trivial positions. See CLAUDE.md § Alias vs Function.
# =============================================================================

# Create a directory (including parents) and immediately cd into it
# Usage: mkcd my/new/dir
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Create a timestamped backup copy of a file in the same directory
# Usage: backup_file important.conf  →  important.conf.backup-20260219-143012
backup_file() {
    cp "$1"{,.backup-$(date +%Y%m%d-%H%M%S)}
    echo "Backed up $1"
}

# Render a man page as PDF and open in Preview.app (macOS only)
# Usage: pman git
pman() {
    man -t "$1" | open -f -a Preview
}

# Fuzzy file search in current directory tree by partial name
# Usage: search config  →  finds ./src/config.yaml, ./old/config.bak, etc.
search() {
    find . -name "*$1*" -type f
}

# Lightweight morning briefing — weather, tasks, and git status if in a repo
# For the full morning routine with AI briefing, use `startday` instead.
morning() {
    echo "=== Morning Briefing ==="
    weather.sh
    echo ""
    todo.sh list
    echo ""
    if [ -d .git ]; then
        echo "=== Git Status ==="
        git status --short
    fi
}

# End-of-day checklist and progress summary
# For the full evening routine with journaling prompts, use `goodevening` instead.
endday() {
    echo "=== End of Day Summary ==="
    my_progress.sh 2>/dev/null || echo "Not in a git repository"
    echo ""
    echo "Don't forget to:"
    echo "- Save your work"
    echo "- Update your journal"
    echo "- Plan tomorrow's tasks"
}

# SSH key management helpers
alias wk='with-keys'                      # Run a command with SSH keys loaded
alias wr='with-req --'                    # Run a command with required credentials



# =============================================================================
# SETUP INSTRUCTIONS
# =============================================================================
#
# To use this file:
#   1. Ensure DOTFILES_DIR is set (or this file lives at ~/dotfiles/zsh/aliases.zsh)
#   2. Add to ~/.zshrc:  source "$DOTFILES_DIR/zsh/aliases.zsh"
#   3. Ensure scripts in scripts/ and bin/ are executable: chmod +x *.sh
#   4. Reload shell: source ~/.zshrc  (or use the `reload` alias)
#
# =============================================================================
# CUSTOMIZATION NOTES
# =============================================================================
#
# Design principles:
#   - Every alias saves significant typing or reduces cognitive load
#   - Dangerous operations (rm, cp, mv) have confirmation prompts
#   - Related commands are grouped by workflow, not alphabetically
#   - Ultra-short aliases (t, j, ta, ja) reserved for highest-frequency tasks
#
# To customize:
#   - Comment out aliases you don't use
#   - Add new aliases following the naming conventions in CLAUDE.md
#   - Use `ez` to open this file in VS Code for quick edits
#   - Use `reload` to apply changes without restarting the terminal
#
# =============================================================================
# EXAMPLE WORKFLOWS
# =============================================================================
#
# Morning routine:
#   startday                       # Full morning briefing (AI-powered)
#   morning                        # Lightweight: weather + todos + git
#
# Working on a project:
#   g myproject                    # Jump to bookmarked project directory
#   devstart                       # Load env + open VS Code
#
# End of day:
#   ta "Review client feedback"    # Add tomorrow's task
#   j "Finished API integration"   # Add journal entry
#   goodevening                    # Full evening routine
#
# File organization:
#   down                           # Go to ~/Downloads
#   cleanup                        # Organize by type + flag large files
#
# Quick information:
#   info                           # Weather + todos
#   overview                       # System info + battery
# Intentional grep shadow: force colorized output for interactive use.
# Prefers GNU grep (ggrep via Homebrew) for extended regex support;
# falls back to macOS BSD grep which also supports --color=auto.
if command -v ggrep >/dev/null 2>&1; then
    alias grep='ggrep --color=auto'
else
    alias grep='grep --color=auto'
fi

# =============================================================================
# BLOG WORKFLOW
# =============================================================================
alias blog="blog.sh"                      # Blog management CLI (create, publish, list)
alias blog-recent="blog_recent_content.sh"  # Show recently published/drafted blog posts
alias dump="dump.sh"                      # Dump structured data for debugging/export
alias data_validate="data_validate.sh"    # Validate data files in ~/.config/dotfiles-data/

# =============================================================================
# AI STAFF HQ DISPATCHERS
# Each dispatcher sends prompts to a specialized AI persona via OpenRouter API.
# All dispatchers accept: stdin, string arg, or both. Flags: --stream, --verbose.
# See bin/README.md and CLAUDE.md § AI Dispatcher Architecture for details.
# =============================================================================

# --- Full dispatcher names (dhp- prefix = "Digital HQ Personnel") ---
alias dhp-tech="$DOTFILES_ALIAS_ROOT/bin/dhp-tech.sh"           # Technical/coding assistant
alias dhp-creative="$DOTFILES_ALIAS_ROOT/bin/dhp-creative.sh"   # Creative writing & ideation
alias dhp-content="$DOTFILES_ALIAS_ROOT/bin/dhp-content.sh"     # Content strategy & drafting
alias dhp-strategy="$DOTFILES_ALIAS_ROOT/bin/dhp-strategy.sh"   # Business/life strategy advisor
alias dhp-brand="$DOTFILES_ALIAS_ROOT/bin/dhp-brand.sh"         # Brand voice & identity
alias dhp-market="$DOTFILES_ALIAS_ROOT/bin/dhp-market.sh"       # Market analysis & trends
alias dhp-stoic="$DOTFILES_ALIAS_ROOT/bin/dhp-stoic.sh"         # Stoic philosophy / mindset coach
alias dhp-research="$DOTFILES_ALIAS_ROOT/bin/dhp-research.sh"   # Deep research & fact-finding
alias dhp-narrative="$DOTFILES_ALIAS_ROOT/bin/dhp-narrative.sh"  # Storytelling & narrative design
alias dhp-copy="$DOTFILES_ALIAS_ROOT/bin/dhp-copy.sh"           # Copywriting (ads, emails, etc.)
alias dhp-finance="$DOTFILES_ALIAS_ROOT/bin/dhp-finance.sh"     # Financial analysis & advice
alias dhp-memory="$DOTFILES_ALIAS_ROOT/bin/dhp-memory.sh"       # Store memories to knowledge base
alias dhp-memory-search="$DOTFILES_ALIAS_ROOT/bin/dhp-memory-search.sh"  # Search stored memories

# --- Shorthand versions (same dispatchers, fewer keystrokes) ---
alias tech="$DOTFILES_ALIAS_ROOT/bin/dhp-tech.sh"
alias creative="$DOTFILES_ALIAS_ROOT/bin/dhp-creative.sh"
alias content="$DOTFILES_ALIAS_ROOT/bin/dhp-content.sh"
alias strategy="$DOTFILES_ALIAS_ROOT/bin/dhp-strategy.sh"
alias brand="$DOTFILES_ALIAS_ROOT/bin/dhp-brand.sh"
alias market="$DOTFILES_ALIAS_ROOT/bin/dhp-market.sh"
alias stoic="$DOTFILES_ALIAS_ROOT/bin/dhp-stoic.sh"
alias research="$DOTFILES_ALIAS_ROOT/bin/dhp-research.sh"
alias narrative="$DOTFILES_ALIAS_ROOT/bin/dhp-narrative.sh"
alias aicopy="$DOTFILES_ALIAS_ROOT/bin/dhp-copy.sh"             # 'aicopy' not 'copy' (copy = pbcopy)
alias morphling="$DOTFILES_ALIAS_ROOT/bin/morphling.sh"          # Shape-shifting multi-persona dispatcher
alias finance="$DOTFILES_ALIAS_ROOT/bin/dhp-finance.sh"
alias memory="$DOTFILES_ALIAS_ROOT/bin/dhp-memory.sh"
alias memory-search="$DOTFILES_ALIAS_ROOT/bin/dhp-memory-search.sh"
alias dhp-morphling="$DOTFILES_ALIAS_ROOT/bin/dhp-morphling.sh"
alias dhp="$DOTFILES_ALIAS_ROOT/bin/dhp-tech.sh"                # Default dispatcher → tech
alias dispatch="$DOTFILES_ALIAS_ROOT/bin/dispatch.sh"            # Generic dispatch router

# --- Advanced AI Features (Phase 5 — orchestration & chaining) ---
alias dhp-project="$DOTFILES_ALIAS_ROOT/bin/dhp-project.sh"     # Multi-specialist project orchestration
alias ai-project="$DOTFILES_ALIAS_ROOT/bin/dhp-project.sh"      # Shorthand for dhp-project
alias dhp-chain="$DOTFILES_ALIAS_ROOT/bin/dhp-chain.sh"         # Chain dispatchers sequentially (pipe output)
alias ai-chain="$DOTFILES_ALIAS_ROOT/bin/dhp-chain.sh"          # Shorthand for dhp-chain
alias ai-suggest="ai_suggest.sh"                                 # Context-aware AI suggestions for current task
alias ai-context="source $DOTFILES_ALIAS_ROOT/bin/dhp-context.sh"  # Load context-gathering helpers (sourced, not executed)

# =============================================================================
# Swipe logging — capture quick ideas/notes from the command line
alias swipe="$DOTFILES_ALIAS_ROOT/bin/swipe.sh"

# =============================================================================
# ACCESSIBILITY & ERGONOMICS
# Low-strain aliases designed for MS/Carpal Tunnel — minimize hand movement,
# reduce modifier keys, and forgive common typos. Every keystroke saved matters
# on high-fatigue days.
# =============================================================================

# Global Aliases (zsh-only feature: expand ANYWHERE in a command line)
# These replace awkward pipe/redirect sequences with single uppercase letters.
# Example: `ls G txt` expands to `ls | grep -i txt`
alias -g G="| grep -i"                   # Case-insensitive grep filter
alias -g C="| pbcopy"                    # Pipe output to clipboard
alias -g L="| less"                      # Pipe output to pager
alias -g H="| head -n 10"               # Show first 10 lines only
alias -g N="> /dev/null 2>&1"           # Silence all output (stdout + stderr)

# Typo Forgiveness — common mistypes that don't need backspace correction
alias cd..="cd .."                        # Missing space
alias ls-l="ls -l"                        # Hyphen instead of space
alias sl="ls"                             # Transposed letters
alias dc="cd"                             # Transposed letters
alias gut="git"                           # Transposed letters
alias gti="git"                           # Transposed letters
alias pwd="pwd"                           # Already correct (harmless)
alias pdw="pwd"                           # Transposed letters
alias vmi="vim"                           # Transposed letters

# Home-Row Double Taps — fast commands from resting hand position
alias hh="history"                        # Shell history
alias xx="exit"                           # Exit terminal
alias qq="exit"                           # Exit terminal (vim-inspired)
alias b="cd -"                            # Bounce back to previous directory

# Zero-Symbol Git Workflows — no quotes, pipes, or special characters needed
alias doneit="git add . && git commit -m 'update' && git push"  # Quick ship it
alias gwip="git add . && git commit -m 'wip'"                   # Save work-in-progress
alias gup="git pull --rebase"             # Pull with rebase (cleaner history)

# Hyphen-less Primitives — avoid reaching for the hyphen key
alias md="mkdir -p"                       # Make directory (with parents)
alias cx="chmod +x"                       # Make file executable

# Config Edit Shortcuts — quick access to shell configuration
alias ez="code \$DOTFILES_ALIAS_ROOT/zsh/aliases.zsh"  # Edit this aliases file in VS Code
alias ezrc="code ~/.zshrc"               # Edit .zshrc in VS Code
alias reload="source ~/.zshrc && echo 'Zsh reloaded!'"  # Apply config changes instantly

# SPEC-DRIVEN DISPATCHER WORKFLOW
# =============================================================================
# Loads spec_helper.sh which provides functions for creating and editing
# structured spec templates before sending them to AI dispatchers.
# This file is SOURCED (not executed) — see spec_helper.sh header.
source "$DOTFILES_ALIAS_ROOT/scripts/spec_helper.sh"
