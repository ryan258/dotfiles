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
# =============================================================================

# Task & Time Management
alias todo="~/dotfiles/scripts/todo.sh"
alias todolist="~/dotfiles/scripts/todo.sh list"
alias tododone="~/dotfiles/scripts/todo.sh done"
alias todoadd="~/dotfiles/scripts/todo.sh add"
alias journal="~/dotfiles/scripts/journal.sh"
alias break="~/dotfiles/scripts/take_a_break.sh"

# Health tracking
alias health="~/dotfiles/scripts/health.sh"

# Ultra-short aliases for frequent tasks
alias t="~/dotfiles/scripts/todo.sh list"          # Show todo list
alias j="~/dotfiles/scripts/journal.sh"            # Add journal entry
alias ta="~/dotfiles/scripts/todo.sh add"          # Add todo task

# Information & Utilities
alias memo="~/dotfiles/scripts/memo.sh"
alias weather="~/dotfiles/scripts/weather.sh"
alias findtext="~/dotfiles/scripts/findtext.sh"

# Project & Development Tools
alias newproject="~/dotfiles/scripts/start_project.sh"
alias newpython="~/dotfiles/scripts/mkproject_py.sh"
alias newpy="~/dotfiles/scripts/mkproject_py.sh"
alias progress="~/dotfiles/scripts/my_progress.sh"

# File & System Management
alias backup="~/dotfiles/scripts/backup_project.sh"
alias findbig="~/dotfiles/scripts/findbig.sh"
alias unpack="~/dotfiles/scripts/unpacker.sh"
alias tidydown="~/dotfiles/scripts/tidy_downloads.sh"

# Daily Routine Scripts
alias startday="~/dotfiles/scripts/startday.sh"
alias goodevening="~/dotfiles/scripts/goodevening.sh"
alias greeting="~/dotfiles/scripts/greeting.sh"
alias weekreview="~/dotfiles/scripts/week_in_review.sh"

# =============================================================================
# NAVIGATION & FILE MANAGEMENT SCRIPTS
# =============================================================================

# Smart navigation
alias g="~/dotfiles/scripts/goto.sh"
alias goto="~/dotfiles/scripts/goto.sh"
alias back="~/dotfiles/scripts/recent_dirs.sh"
alias recent="~/dotfiles/scripts/recent_dirs.sh"

# File operations
alias openf="~/dotfiles/scripts/open_file.sh"
# alias open= (disabled — reserved name)
alias finddupes="~/dotfiles/scripts/duplicate_finder.sh"
alias organize="~/dotfiles/scripts/file_organizer.sh"

# =============================================================================
# SYSTEM MONITORING SCRIPTS (macOS)
# =============================================================================

# System information
alias sysinfo="~/dotfiles/scripts/system_info.sh"
alias batterycheck="~/dotfiles/scripts/battery_check.sh"
alias processes="~/dotfiles/scripts/process_manager.sh"
alias netinfo="~/dotfiles/scripts/network_info.sh"

# Quick system checks
alias topcpu="~/dotfiles/scripts/process_manager.sh top"
alias topmem="~/dotfiles/scripts/process_manager.sh memory"
alias netstatus="~/dotfiles/scripts/network_info.sh status"
alias netspeed="~/dotfiles/scripts/network_info.sh speed"

# =============================================================================
# PRODUCTIVITY & AUTOMATION SCRIPTS
# =============================================================================

# Clipboard management
alias clip="~/dotfiles/scripts/clipboard_manager.sh"
alias clipsave="~/dotfiles/scripts/clipboard_manager.sh save"
alias clipload="~/dotfiles/scripts/clipboard_manager.sh load"
alias cliplist="~/dotfiles/scripts/clipboard_manager.sh list"

# Application management
alias app="~/dotfiles/scripts/app_launcher.sh"
alias launch="~/dotfiles/scripts/app_launcher.sh"

# Note taking
alias note="~/dotfiles/scripts/quick_note.sh"
alias noteadd="~/dotfiles/scripts/quick_note.sh add"
alias notesearch="~/dotfiles/scripts/quick_note.sh search"
alias notetoday="~/dotfiles/scripts/quick_note.sh today"

# Workspace management
alias workspace="~/dotfiles/scripts/workspace_manager.sh"
alias wsave="~/dotfiles/scripts/workspace_manager.sh save"
alias wload="~/dotfiles/scripts/workspace_manager.sh load"

# Reminders and notifications
alias remind="~/dotfiles/scripts/remind_me.sh"
alias done="~/dotfiles/scripts/done.sh"

# Development shortcuts
alias dev="~/dotfiles/scripts/dev_shortcuts.sh"
alias server="~/dotfiles/scripts/dev_shortcuts.sh server"
alias json="~/dotfiles/scripts/dev_shortcuts.sh json"
# alias env="~/dotfiles/scripts/dev_shortcuts.sh env"  # disabled — reserved name
alias gitquick="~/dotfiles/scripts/dev_shortcuts.sh gitquick"

# =============================================================================
# FILE PROCESSING & ANALYSIS SCRIPTS
# =============================================================================

# Text processing
alias textproc="~/dotfiles/scripts/text_processor.sh"
alias wordcount="~/dotfiles/scripts/text_processor.sh count"
alias textsearch="~/dotfiles/scripts/text_processor.sh search"
alias textreplace="~/dotfiles/scripts/text_processor.sh replace"
alias textclean="~/dotfiles/scripts/text_processor.sh clean"

# Media conversion
alias media="~/dotfiles/scripts/media_converter.sh"
alias video2audio="~/dotfiles/scripts/media_converter.sh video2audio"
alias resizeimg="~/dotfiles/scripts/media_converter.sh resize_image"
alias compresspdf="~/dotfiles/scripts/media_converter.sh pdf_compress"

# Archive management
alias archive="~/dotfiles/scripts/archive_manager.sh"
alias archcreate="~/dotfiles/scripts/archive_manager.sh create"
alias archextract="~/dotfiles/scripts/archive_manager.sh extract"
alias archlist="~/dotfiles/scripts/archive_manager.sh list"

# Finance & Data Analysis
alias mtg="~/dotfiles/scripts/mtg_price_check.sh"

# =============================================================================
# COMPOUND ALIASES (USEFUL COMBINATIONS)
# =============================================================================

# Information dashboards
alias info="~/dotfiles/scripts/weather.sh && echo && ~/dotfiles/scripts/todo.sh list"
alias status="~/dotfiles/scripts/journal.sh && echo && ~/dotfiles/scripts/todo.sh list"
alias overview="~/dotfiles/scripts/system_info.sh && echo && ~/dotfiles/scripts/battery_check.sh"

# Quick maintenance
alias cleanup="cd ~/Downloads && ~/dotfiles/scripts/file_organizer.sh bytype && ~/dotfiles/scripts/findbig.sh"
alias quickbackup="~/dotfiles/scripts/backup_project.sh && echo 'Backup complete!'"

# Development workflow
alias devstart="~/dotfiles/scripts/dev_shortcuts.sh env && code ."
alias gitcheck="~/dotfiles/scripts/my_progress.sh && git status"

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

# Enhanced cd that tracks history for recent_dirs script
cd() {
    builtin cd "$@" && ~/dotfiles/scripts/recent_dirs.sh add 2>/dev/null
}

# Quick git status and todo check
morning() {
    echo "=== Morning Briefing ==="
    ~/dotfiles/scripts/weather.sh
    echo ""
    ~/dotfiles/scripts/todo.sh list
    echo ""
    if [ -d .git ]; then
        echo "=== Git Status ==="
        git status --short
    fi
}

# Quick end-of-day routine
endday() {
    echo "=== End of Day Summary ==="
    ~/dotfiles/scripts/my_progress.sh 2>/dev/null || echo "Not in a git repository"
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
# 4. Copy all the script files to ~/dotfiles/scripts/
# 5. Make scripts executable: chmod +x ~/dotfiles/scripts/*.sh
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
# overview                  # System info + battery devenv='~/dotfiles/scripts/dev_shortcuts.sh env'
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

