# ~/.zsh_aliases
# Complete shell aliases optimized for macOS/zsh
# Designed to reduce typing and improve workflow efficiency

# =============================================================================
# NAVIGATION & DIRECTORY SHORTCUTS  
# =============================================================================

# Quick directory navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

# Enhanced directory listing (macOS compatible)
alias ll="ls -alF"                 # Detailed list with file types
alias la="ls -A"                   # List all except . and ..
alias l="ls -CF"                   # List in columns with file types
alias lt="ls -altr"                # List by time, newest last
alias lh="ls -alh"                 # List with human-readable sizes

# Quick file operations
alias here="ls -la"                # What's in this directory
alias tree="find . -type d | head -20"  # Show directory structure
alias newest="ls -lt | head -10"   # Show 10 newest files
alias biggest="ls -lS | head -10"  # Show 10 biggest files
alias count="ls -1 | wc -l"        # Count files in directory

# Quick access to common directories
alias downloads="cd ~/Downloads"
alias documents="cd ~/Documents"
alias desktop="cd ~/Desktop"
alias scripts="cd ~/scripts"
alias home="cd ~"
alias docs="cd ~/Documents"
alias down="cd ~/Downloads"
alias desk="cd ~/Desktop"

# =============================================================================
# SYSTEM MANAGEMENT (macOS)
# =============================================================================

# System updates using Homebrew
alias update="brew update && brew upgrade"
alias brewclean="brew cleanup"
alias brewinfo="brew list --versions"

# System information  
alias myip="curl ifconfig.me"              # External IP address
alias localip="ifconfig | grep inet"      # Local IP addresses
alias mem="vm_stat"                        # Memory usage (macOS style)
alias cpu="top -l 1 | head -n 10"         # CPU info

# Process management
alias psg="ps aux | grep"                 # Search for process

# =============================================================================
# FILE OPERATIONS
# =============================================================================

# Safe file operations
alias rm="rm -i"                          # Prompt before removing
alias cp="cp -i"                          # Prompt before overwriting
alias mv="mv -i"                          # Prompt before overwriting

# Archive operations  
alias untar="tar -xvf"                    # Extract tar files
alias targz="tar -czvf"                   # Create tar.gz archive

# File search (macOS compatible)
alias ff="find . -name"                   # Find files by name
alias grep="grep --color=auto"            # Colorized grep

# macOS specific file operations
alias showfiles="defaults write com.apple.finder AppleShowAllFiles YES && killall Finder"
alias hidefiles="defaults write com.apple.finder AppleShowAllFiles NO && killall Finder"
alias spotlight="mdfind"                  # Spotlight search from terminal

# =============================================================================
# GIT SHORTCUTS
# =============================================================================

alias gs="git status"                     # Git status
alias ga="git add"                        # Git add
alias gaa="git add ."                     # Git add all
alias gc="git commit -m"                  # Git commit with message
alias gp="git push"                       # Git push
alias gl="git pull"                       # Git pull
alias gd="git diff"                       # Git diff
alias gb="git branch"                     # Git branch
alias gco="git checkout"                  # Git checkout
alias glog="git log --oneline"            # Compact git log

# =============================================================================
# TEXT EDITING & VIEWING
# =============================================================================

# Quick editors
alias v="vim"                             # Quick vim
alias n="nano"                            # Quick nano
alias e="echo"                            # Quick echo

# macOS applications
alias code="code ."                       # Open VS Code in current directory
alias finder="open ."                     # Open Finder in current directory

# =============================================================================
# UTILITY SHORTCUTS
# =============================================================================

# Clear screen
alias c="clear"                           # Quick clear
alias cls="clear"                         # Windows-style clear

# Date and time
alias now="date"                          # Current date/time
alias timestamp="date +%Y%m%d_%H%M%S"     # Timestamp for filenames

# Disk usage
alias du="du -h"                          # Human readable disk usage
alias df="df -h"                          # Human readable disk free
alias diskspace="df -h"                   # Disk space overview

# Network (macOS style)
alias ping="ping -c 5"                    # Ping only 5 times by default
alias flushdns="sudo dscacheutil -flushcache" # Flush DNS cache

# =============================================================================
# DEVELOPMENT SHORTCUTS
# =============================================================================

# Python
alias python="python3"                    # Use Python 3 by default
alias pip="pip3"                          # Use pip3 by default
alias venv="python3 -m venv"              # Quick virtual environment creation
alias activate="source venv/bin/activate" # Activate virtual environment

# Web development
alias serve="python3 -m http.server"      # Quick HTTP server
alias jsonpp="python3 -m json.tool"       # Pretty print JSON

# =============================================================================
# MACOS CLIPBOARD & UTILITIES
# =============================================================================

# Clipboard operations (macOS)
alias copy="pbcopy"                       # Copy to clipboard
alias paste="pbpaste"                     # Paste from clipboard
alias copyfile="pbcopy <"                 # Copy file contents to clipboard
alias copyfolder="tail -n +1 * | pbcopy"

# macOS system utilities
alias sleep="pmset displaysleepnow"       # Put display to sleep
alias lock="pmset displaysleepnow"        # Lock screen
alias eject="diskutil eject"              # Eject disk
alias battery="pmset -g batt"             # Battery status

# =============================================================================
# CORE PRODUCTIVITY SCRIPTS
alias howto="howto.sh"
alias whatis="whatis.sh"
alias dotfiles_check="dotfiles_check.sh"
alias dotfiles-check="dotfiles_check.sh"  # Alternative with hyphen
# =============================================================================

# Task & Time Management
alias pomo="take_a_break.sh 25"
alias todo="todo.sh"
alias todolist="todo.sh list"
alias tododone="todo.sh done"
alias todoadd="todo.sh add"
alias journal="journal.sh"
alias break="take_a_break.sh"
alias focus="focus.sh"

# Time Tracking
alias t-start="todo.sh start"
alias t-stop="todo.sh stop"
alias t-status="time_tracker.sh status"

# Spoon Budget
alias spoons="spoon_manager.sh"
alias s-check="spoon_manager.sh check"
alias s-spend="spoon_manager.sh spend"

# Correlation & Reports
alias correlate="correlate.sh"
alias daily-report="generate_report.sh daily"

# Health tracking
alias health="health.sh"
alias meds="meds.sh"

# Ultra-short aliases for frequent tasks
alias next="todo.sh top 1"
alias t="todo.sh list"          # Show todo list
alias j="journal.sh"            # Add journal entry
alias ta="todo.sh add"          # Add todo task
alias ja="journal.sh add"       # Add journal entry

# Information & Utilities
alias weather="weather.sh"
alias findtext="findtext.sh"
alias graballtext="grab_all_text.sh"

# Project & Development Tools
alias newproject="start_project.sh"
alias newpython="mkproject_py.sh"
alias newpy="mkproject_py.sh"
alias progress="my_progress.sh"
alias projects="projects.sh"

# File & System Management
alias backup="backup_project.sh"
alias findbig="findbig.sh"
alias unpack="unpacker.sh"
alias tidydown="tidy_downloads.sh"

# Daily Routine Scripts
alias startday="startday.sh"
alias goodevening="goodevening.sh"
alias greeting="greeting.sh"
alias weekreview="week_in_review.sh"

# =============================================================================
# NAVIGATION & FILE MANAGEMENT SCRIPTS
# =============================================================================

# Smart navigation
alias g="source $HOME/dotfiles/scripts/g.sh"

# File operations
alias openf="open_file.sh"
# alias open= (disabled — reserved name)
alias finddupes="duplicate_finder.sh"
alias organize="file_organizer.sh"

# =============================================================================
# SYSTEM MONITORING SCRIPTS (macOS)
alias systemlog="tail -n 20 ~/.config/dotfiles-data/system.log"
# =============================================================================

# System information
alias sysinfo="system_info.sh"
alias batterycheck="battery_check.sh"
alias processes="process_manager.sh"
alias netinfo="network_info.sh"

# Quick system checks
alias topcpu="process_manager.sh top"
alias topmem="process_manager.sh memory"
alias netstatus="network_info.sh status"
alias netspeed="network_info.sh speed"

# Calendar management
alias gcal="gcal.sh"
# Note: 'calendar' also aliased to gcal.sh, overrides system command
alias calendar="gcal.sh"

# =============================================================================
# PRODUCTIVITY & AUTOMATION SCRIPTS
# =============================================================================

# Clipboard management
alias clip="clipboard_manager.sh"
alias clipsave="clipboard_manager.sh save"
alias clipload="clipboard_manager.sh load"
alias cliplist="clipboard_manager.sh list"

# Application management
alias app="app_launcher.sh"
alias launch="app_launcher.sh"



# Reminders and notifications
alias remind="remind_me.sh"
alias did="done.sh"       # Renamed from 'done' (reserved keyword)

# Development shortcuts
alias dev="dev_shortcuts.sh"
alias server="dev_shortcuts.sh server"
alias json="dev_shortcuts.sh json"
# alias env="dev_shortcuts.sh env"  # disabled — reserved name
alias gitquick="dev_shortcuts.sh gitquick"

# =============================================================================
# FILE PROCESSING & ANALYSIS SCRIPTS
# =============================================================================

# Text processing
alias textproc="text_processor.sh"
alias wordcount="text_processor.sh count"
alias textsearch="text_processor.sh search"
alias textreplace="text_processor.sh replace"
alias textclean="text_processor.sh clean"

# Media conversion
alias media="media_converter.sh"
alias video2audio="media_converter.sh video2audio"
alias resizeimg="media_converter.sh resize_image"
alias compresspdf="media_converter.sh pdf_compress"
alias stitch="media_converter.sh audio_stitch"

# Archive management
alias archive="archive_manager.sh"
alias archcreate="archive_manager.sh create"
alias archextract="archive_manager.sh extract"
alias archlist="archive_manager.sh list"

# Finance & Data Analysis
# alias mtg="mtg_price_check.sh"  # Removed - MTG tools moved to private repo

# =============================================================================
# COMPOUND ALIASES (USEFUL COMBINATIONS)
# =============================================================================

# Information dashboards
alias info="weather.sh && echo && todo.sh list"
alias status="status.sh"
alias overview="system_info.sh && echo && battery_check.sh"

# Quick maintenance
alias cleanup="cd ~/Downloads && file_organizer.sh bytype && findbig.sh"
alias quickbackup="backup_project.sh && echo 'Backup complete!'"

# Development workflow
alias devstart="dev_shortcuts.sh env && code ."
alias gitcheck="my_progress.sh && git status"

# =============================================================================
# FUNCTIONS (SLIGHTLY MORE COMPLEX ALIASES)
# =============================================================================

# Create directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Quick backup of a file
backup_file() {
    cp "$1"{,.backup-$(date +%Y%m%d-%H%M%S)}
    echo "Backed up $1"
}

# Open man page in Preview (macOS specific)
pman() {
    man -t "$1" | open -f -a Preview
}

# Quick search in current directory
search() {
    find . -name "*$1*" -type f
}

# Enhanced cd that tracks history for the suggestion engine
cd() {
    builtin cd "$@" && echo "$(date +%s):$(pwd)" >> "$HOME/.config/dotfiles-data/dir_usage.log"
}

# Quick git status and todo check
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

# Quick end-of-day routine
endday() {
    echo "=== End of Day Summary ==="
    my_progress.sh 2>/dev/null || echo "Not in a git repository"
    echo ""
    echo "Don't forget to:"
    echo "- Save your work"
    echo "- Update your journal"
    echo "- Plan tomorrow's tasks"
}

# Managing SSH Keys
alias wk='with-keys'
alias wr='with-req --'



# =============================================================================
# INSTRUCTIONS FOR USE
# =============================================================================

# To use this file:
# 1. Save it as ~/.zsh_aliases
# 2. Add this line to your ~/.zshrc file:
#    source ~/.zsh_aliases
# 3. Create the ~/scripts directory: mkdir ~/scripts
# 4. Copy all the script files to # 5. Make scripts executable: chmod +x *.sh
# 6. Reload your shell: source ~/.zshrc

# =============================================================================
# CUSTOMIZATION NOTES
# =============================================================================

# This file is designed to reduce typing and cognitive load on macOS.
# Key principles:
# - Every alias saves significant typing
# - Complex operations become simple commands
# - Related functions are grouped logically
# - Dangerous operations have confirmations built-in
# 
# Feel free to:
# - Comment out aliases you don't need
# - Add your own aliases
# - Modify paths to match your system
# - Customize the compound aliases for your workflow

# =============================================================================
# EXAMPLE WORKFLOWS
# =============================================================================

# Morning routine:
# morning                    # Check weather, todos, git status
# 
# Working on a project:
# g myproject               # Jump to bookmarked project directory
# devstart                  # Start development environment
# 
# End of day:
# ta "Review client feedback"    # Add tomorrow's task
# j "Finished API integration"   # Add journal entry
# endday                         # Show progress summary
# 
# File organization:
# down                      # Go to downloads
# cleanup                   # Organize and show big files
# 
# Quick information:
# info                      # Weather + todos
# overview                  # System info + battery devenv='dev_shortcuts.sh env'
# Portable grep coloring
if command -v ggrep >/dev/null 2>&1; then
    alias grep='ggrep --color=auto'
else
    alias grep='grep'
fi
# Portable grep coloring
if command -v ggrep >/dev/null 2>&1; then
  alias grep='ggrep --color=auto'
else
  alias grep='grep'
fi

# =============================================================================
# BLOG WORKFLOW
# =============================================================================
alias blog="blog.sh"
alias dump='bash ~/dotfiles/scripts/dump.sh'
alias data_validate='bash ~/dotfiles/scripts/data_validate.sh'

# =============================================================================
# AI STAFF HQ DISPATCHERS
# =============================================================================
# Full dispatcher names
alias dhp-tech="$HOME/dotfiles/bin/dhp-tech.sh"
alias dhp-creative="$HOME/dotfiles/bin/dhp-creative.sh"
alias dhp-content="$HOME/dotfiles/bin/dhp-content.sh"
alias dhp-strategy="$HOME/dotfiles/bin/dhp-strategy.sh"
alias dhp-brand="$HOME/dotfiles/bin/dhp-brand.sh"
alias dhp-market="$HOME/dotfiles/bin/dhp-market.sh"
alias dhp-stoic="$HOME/dotfiles/bin/dhp-stoic.sh"
alias dhp-research="$HOME/dotfiles/bin/dhp-research.sh"
alias dhp-narrative="$HOME/dotfiles/bin/dhp-narrative.sh"
alias dhp-copy="$HOME/dotfiles/bin/dhp-copy.sh"

# Shorthand versions for quick access
alias tech="$HOME/dotfiles/bin/dhp-tech.sh"
alias creative="$HOME/dotfiles/bin/dhp-creative.sh"
alias content="$HOME/dotfiles/bin/dhp-content.sh"
alias strategy="$HOME/dotfiles/bin/dhp-strategy.sh"
alias brand="$HOME/dotfiles/bin/dhp-brand.sh"
alias market="$HOME/dotfiles/bin/dhp-market.sh"
alias stoic="$HOME/dotfiles/bin/dhp-stoic.sh"
alias research="$HOME/dotfiles/bin/dhp-research.sh"
alias narrative="$HOME/dotfiles/bin/dhp-narrative.sh"
alias copy="$HOME/dotfiles/bin/dhp-copy.sh"
alias dhp="$HOME/dotfiles/bin/dhp-tech.sh"  # Default to tech dispatcher

# Advanced AI Features (Phase 5)
alias dhp-project="dhp-project.sh"           # Multi-specialist orchestration
alias ai-project="dhp-project.sh"            # Shorthand
alias dhp-chain="dhp-chain.sh"               # Dispatcher chaining
alias ai-chain="dhp-chain.sh"                # Shorthand
alias ai-suggest="ai_suggest.sh"             # Context-aware suggestions
alias ai-context="source dhp-context.sh"     # Context gathering library

# =============================================================================
# Swipe logging
alias swipe="$HOME/dotfiles/bin/swipe.sh"

# SPEC-DRIVEN DISPATCHER WORKFLOW
# =============================================================================
# Structured template workflow for dispatchers
source ~/dotfiles/scripts/spec_helper.sh
