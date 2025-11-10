#!/bin/bash
# dev_shortcuts.sh - Development workflow shortcuts for macOS
set -euo pipefail

is_sourced() {
    if [ -n "$ZSH_VERSION" ]; then
        case $ZSH_EVAL_CONTEXT in
            *:file) return 0 ;;
        esac
        return 1
    elif [ -n "$BASH_VERSION" ]; then
        [[ ${BASH_SOURCE[0]} != "$0" ]]
        return
    fi
    return 1
}

case "$1" in
    server)
        # Quick development server
        PORT=${2:-8000}
        echo "Starting development server on port $PORT..."
        echo "Access at: http://localhost:$PORT"
        python3 -m http.server "$PORT"
        ;;
    
    json)
        # Pretty print JSON from clipboard or file
        if [ -z "$2" ]; then
            echo "Pretty printing JSON from clipboard:"
            pbpaste | python3 -m json.tool
        else
            echo "Pretty printing JSON from file: $2"
            python3 -m json.tool "$2"
        fi
        ;;
    
    env)
        # Quick Python virtual environment setup
        if [ ! -d "venv" ]; then
            echo "Creating virtual environment..."
            python3 -m venv venv
        fi
        if is_sourced; then
            echo "Activating virtual environment..."
            # shellcheck source=/dev/null
            source venv/bin/activate
            echo "Virtual environment activated. Use 'deactivate' to exit."
        else
            echo "Virtual environment ready. Run 'source venv/bin/activate' to use it."
        fi
        ;;

    gitquick)
        # Quick git add, commit, push
        shift
        if [ $# -eq 0 ]; then
            echo "Usage: dev gitquick <commit_message>"
            exit 1
        fi
        COMMIT_MESSAGE="$*"
        git add .
        git commit -m "$COMMIT_MESSAGE"
        git push
        printf "Changes committed and pushed: %s\n" "$COMMIT_MESSAGE"
        ;;
    
    *)
        echo "Usage: $0 {server|json|env|gitquick}"
        echo "  server [port]     : Start development server (default port 8000)"
        echo "  json [file]       : Pretty print JSON (from clipboard or file)"
        echo "  env               : Create/activate Python virtual environment"
        echo "  gitquick <msg>    : Quick git add, commit, push"
        ;;
esac # Shell Scripts Collection - macOS/zsh Edition

# A comprehensive collection of shell scripts designed for macOS Terminal (zsh) to reduce repetitive tasks and improve workflow efficiency.
# 
# ## Setup for macOS
# 
# 1. **Create a scripts directory:** `mkdir ~/scripts`
# 2. **Add to your PATH** by adding this line to `~/.zshrc`: 
#    ```bash
#    export PATH="$HOME/scripts:$PATH"
#    ```
# 3. **Set up aliases** by saving the provided aliases as `~/.zsh_aliases`
# 4. **Add this line to your `~/.zshrc`:** `source ~/.zsh_aliases`
# 5. **Make scripts executable:** `chmod +x ~/scripts/*.sh`
# 6. **Reload your shell:** `source ~/.zshrc`
# 
# ## Prerequisites for macOS
# 
# ### Install Homebrew (if not already installed)
# ```bash
# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# ```
# 
# ### Install useful tools via Homebrew
# ```bash
# # Essential tools for the scripts
# brew install jq          # JSON processing (for greeting.sh, weather APIs)
# brew install ffmpeg      # Audio/video processing (for get_audio.sh)
# brew install imagemagick # Image processing (for convert_to_png.sh)
# brew install gnu-sed     # Better sed (use as gsed in scripts)
# brew install coreutils   # GNU versions of core utilities
# brew install findutils   # GNU find, xargs, etc.
# brew install grep        # GNU grep
# ```
# 
# ## Scripts Compatibility Status
# 
# ### ✅ Works as-is on macOS
# These scripts work without modification:
# - **todo.sh** - Task management
# - **journal.sh** - Note taking
# - **memo.sh** - Command cheatsheet
# - **weather.sh** - Weather checking (using wttr.in)
# - **findtext.sh** - Text search in files
# - **start_project.sh** - Project directory creation
# - **mkproject_py.sh** - Python project setup
# - **my_progress.sh** - Git commit history
# - **backup_project.sh** - rsync backups
# - **findbig.sh** - Find large files
# - **unpacker.sh** - Extract archives
# - **week_in_review.sh** - Weekly summary
# 
# ### 🔧 Needs Minor Modifications
# These work with small command changes:
# 
# #### tidy_downloads.sh
# **Issue:** Different default directories
# **Fix:** Update paths in script:
# ```bash
# # Move images
# mv -v *.jpg *.jpeg *.png *.gif ~/Pictures/
# # Move documents  
# mv -v *.pdf *.doc *.docx *.txt ~/Documents/
# # Move audio/video
# mv -v *.mp3 *.wav *.mp4 *.mov ~/Music/
# ```
# 
# #### get_audio.sh
# **Works with ffmpeg installed via Homebrew**
# 
# #### convert_to_png.sh
# **Works with ImageMagick installed via Homebrew**
# 
# ### ❌ Requires Significant Changes
# These need macOS-specific alternatives:
# 
# #### System Monitoring Scripts
# - **hog.sh** - Use `top -n 1` instead of `ps` syntax
# - **battery_check.sh** - Use `pmset -g batt` instead of `/sys/class/power_supply`
# - **cleanup_disk.sh** - Different temp directory locations
# 
# #### Service Management
# - **service.sh** - Replace `systemctl` with `brew services` commands
# - **stopper.sh** - Use `pkill` or Activity Monitor
# 
# #### Notification Scripts
# - **done.sh** - Replace `notify-send` with `osascript` notifications
# - **take_a_break.sh** - Same notification changes needed
# 
# ## macOS-Specific Aliases
# 
# Save this as `~/.zsh_aliases`:
# 
# ```bash
# # ~/.zsh_aliases
# # Shell aliases optimized for macOS/zsh
# 
# # =============================================================================
# # NAVIGATION & DIRECTORY SHORTCUTS  
# # =============================================================================
# 
# # Quick directory navigation
# alias ..="cd .."
# alias ...="cd ../.."
# alias ....="cd ../../.."
# 
# # Enhanced directory listing (macOS compatible)
# alias ll="ls -alF"                 # Detailed list with file types
# alias la="ls -A"                   # List all except . and ..
# alias l="ls -CF"                   # List in columns with file types
# alias lt="ls -altr"                # List by time, newest last
# alias lh="ls -alh"                 # List with human-readable sizes
# 
# # Quick file operations
# alias here="ls -la"                # What's in this directory
# alias tree="find . -type d | head -20"  # Show directory structure
# alias newest="ls -lt | head -10"   # Show 10 newest files
# alias biggest="ls -lS | head -10"  # Show 10 biggest files
# alias count="ls -1 | wc -l"        # Count files in directory
# 
# # Quick access to common directories
# alias downloads="cd ~/Downloads"
# alias documents="cd ~/Documents"
# alias desktop="cd ~/Desktop"
# alias scripts="cd ~/scripts"
# alias home="cd ~"
# alias docs="cd ~/Documents"
# alias down="cd ~/Downloads"
# alias desk="cd ~/Desktop"
# 
# # =============================================================================
# # SYSTEM MANAGEMENT (macOS)
# # =============================================================================
# 
# # System updates using Homebrew
# alias update="brew update && brew upgrade"
# alias brewclean="brew cleanup"
# 
# # System information  
# alias myip="curl ifconfig.me"              # External IP address
# alias localip="ifconfig | grep inet"      # Local IP addresses
# alias mem="vm_stat"                        # Memory usage (macOS style)
# alias cpu="top -l 1 | head -n 10"         # CPU info
# 
# # Process management
# alias psg="ps aux | grep"                 # Search for process
# alias killall="killall"                   # Stop all instances of a program
# 
# # =============================================================================
# # FILE OPERATIONS
# # =============================================================================
# 
# # Safe file operations
# alias rm="rm -i"                          # Prompt before removing
# alias cp="cp -i"                          # Prompt before overwriting
# alias mv="mv -i"                          # Prompt before overwriting
# 
# # Archive operations  
# alias untar="tar -xvf"                    # Extract tar files
# alias targz="tar -czvf"                   # Create tar.gz archive
# 
# # File search (macOS compatible)
# alias ff="find . -name"                   # Find files by name
# alias grep="grep --color=auto"            # Colorized grep
# 
# # macOS specific file operations
# alias showfiles="defaults write com.apple.finder AppleShowAllFiles YES && killall Finder"
# alias hidefiles="defaults write com.apple.finder AppleShowAllFiles NO && killall Finder"
# alias spotlight="mdfind"                  # Spotlight search from terminal
# 
# # =============================================================================
# # GIT SHORTCUTS
# # =============================================================================
# 
# alias gs="git status"                     # Git status
# alias ga="git add"                        # Git add
# alias gaa="git add ."                     # Git add all
# alias gc="git commit -m"                  # Git commit with message
# alias gp="git push"                       # Git push
# alias gl="git pull"                       # Git pull
# alias gd="git diff"                       # Git diff
# alias gb="git branch"                     # Git branch
# alias gco="git checkout"                  # Git checkout
# alias glog="git log --oneline"            # Compact git log
# 
# # =============================================================================
# # TEXT EDITING & VIEWING
# # =============================================================================
# 
# # Quick editors
# alias v="vim"                             # Quick vim
# alias n="nano"                            # Quick nano
# alias e="echo"                            # Quick echo
# 
# # macOS applications
# alias code="code ."                       # Open VS Code in current directory
# alias finder="open ."                     # Open Finder in current directory
# 
# # =============================================================================
# # UTILITY SHORTCUTS
# # =============================================================================
# 
# # Clear screen
# alias c="clear"                           # Quick clear
# alias cls="clear"                         # Windows-style clear
# 
# # Date and time
# alias now="date"                          # Current date/time
# alias timestamp="date +%Y%m%d_%H%M%S"     # Timestamp for filenames
# 
# # Disk usage
# alias du="du -h"                          # Human readable disk usage
# alias df="df -h"                          # Human readable disk free
# alias diskspace="df -h"                   # Disk space overview
# 
# # Network (macOS style)
# alias ping="ping -c 5"                    # Ping only 5 times by default
# alias flushdns="sudo dscacheutil -flushcache" # Flush DNS cache
# 
# # =============================================================================
# # DEVELOPMENT SHORTCUTS
# # =============================================================================
# 
# # Python
# alias python="python3"                    # Use Python 3 by default
# alias pip="pip3"                          # Use pip3 by default
# alias venv="python3 -m venv"              # Quick virtual environment creation
# alias activate="source venv/bin/activate" # Activate virtual environment
# 
# # Web development
# alias serve="python3 -m http.server"      # Quick HTTP server
# alias jsonpp="python3 -m json.tool"       # Pretty print JSON
# 
# # =============================================================================
# # MACOS CLIPBOARD & UTILITIES
# # =============================================================================
# 
# # Clipboard operations (macOS)
# alias copy="pbcopy"                       # Copy to clipboard
# alias paste="pbpaste"                     # Paste from clipboard
# alias copyfile="pbcopy <"                 # Copy file contents to clipboard
# 
# # macOS system utilities
# alias sleep="pmset displaysleepnow"       # Put display to sleep
# alias lock="pmset displaysleepnow"        # Lock screen
# alias eject="diskutil eject"              # Eject disk
# alias battery="pmset -g batt"             # Battery status
# 
# # =============================================================================
# # SHELL SCRIPT ALIASES (WORKING SCRIPTS)
# # =============================================================================
# 
# # File & System Management (macOS compatible)
# alias backup="~/scripts/backup_project.sh"
# alias findbig="~/scripts/findbig.sh"
# alias unpack="~/scripts/unpacker.sh"
# 
# # Project & Development Tools
# alias newproject="~/scripts/start_project.sh"
# alias newpython="~/scripts/mkproject_py.sh"
# alias newpy="~/scripts/mkproject_py.sh"
# alias progress="~/scripts/my_progress.sh"
# 
# # Information & Utilities
# alias memo="~/scripts/memo.sh"
# alias weather="~/scripts/weather.sh"
# alias findtext="~/scripts/findtext.sh"
# 
# # Task & Time Management
# alias todo="~/scripts/todo.sh"
# alias todolist="~/scripts/todo.sh list"
# alias tododone="~/scripts/todo.sh done"
# alias todoadd="~/scripts/todo.sh add"
# alias journal="~/scripts/journal.sh"
# 
# # Ultra-short aliases for frequent tasks
# alias t="~/scripts/todo.sh list"          # Show todo list
# alias j="~/scripts/journal.sh"            # Add journal entry
# alias ta="~/scripts/todo.sh add"          # Add todo task
# 
# # Daily Routine Scripts
# alias startday="~/scripts/startday.sh"
# alias goodevening="~/scripts/goodevening.sh"
# alias greeting="~/scripts/greeting.sh"
# alias weekreview="~/scripts/week_in_review.sh"
# 
# # =============================================================================
# # COMPOUND ALIASES (MACOS OPTIMIZED)
# # =============================================================================
# 
# # Information dashboards
# alias info="~/scripts/weather.sh && echo && ~/scripts/todo.sh list"
# alias status="~/scripts/journal.sh && echo && ~/scripts/todo.sh list"
# alias sysinfo="top -l 1 | head -n 10 && echo && df -h"
# 
# # Quick maintenance
# alias cleanup="cd ~/Downloads && ~/scripts/findbig.sh"
# 
# # =============================================================================
# # FUNCTIONS (SLIGHTLY MORE COMPLEX ALIASES)
# # =============================================================================
# 
# # Create directory and cd into it
# mkcd() {
#     mkdir -p "$1" && cd "$1"
# }
# 
# # Quick backup of a file
# backup_file() {
#     cp "$1"{,.backup-$(date +%Y%m%d-%H%M%S)}
# }
# 
# # Open man page in Preview (macOS specific)
# pman() {
#     man -t "$1" | open -f -a Preview
# }
# 
# # Quick search in current directory
# search() {
#     find . -name "*$1*" -type f
# }
# ```
# 
# ## macOS-Specific Script Modifications
# 
# ### Updated take_a_break.sh for macOS
# ```bash
