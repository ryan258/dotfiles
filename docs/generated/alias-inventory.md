# Alias Inventory

Generated: May 18, 2026

## Summary

- Aliases: 257
- Shell functions: 12
- Daily-core aliases: 22
- Compatibility aliases: 42
- Convenience aliases: 177
- Risky/surprising aliases: 16

## Aliases

| Class | Name | Definition |
| --- | --- | --- |
| convenience | `..` | `alias ..="cd .."` |
| convenience | `...` | `alias ...="cd ../.."` |
| convenience | `....` | `alias ....="cd ../../.."` |
| convenience | `ll` | `alias ll="ls -alF"                 # Full detail + type indicators` |
| convenience | `la` | `alias la="ls -A"                   # All except . and ..` |
| convenience | `l` | `alias l="ls -CF"                   # Compact columns with type indicators` |
| convenience | `lt` | `alias lt="ls -altr"                # Chronological, newest at bottom` |
| convenience | `lh` | `alias lh="ls -alh"                 # Sizes in K/M/G instead of bytes` |
| convenience | `here` | `alias here="ls -la"                # Everything in this directory, long format` |
| convenience | `dtree` | `alias dtree="find . -type d \| head -20"  # Directory tree sketch (avoids shadowing /usr/bin/tree)` |
| convenience | `newest` | `alias newest="ls -lt \| head -10"   # 10 most recently modified files` |
| convenience | `biggest` | `alias biggest="ls -lS \| head -10"  # 10 largest files by size` |
| convenience | `count` | `alias count="ls -1 \| wc -l"        # Count of items in current directory` |
| convenience | `downloads` | `alias downloads="cd ~/Downloads"` |
| convenience | `documents` | `alias documents="cd ~/Documents"` |
| convenience | `desktop` | `alias desktop="cd ~/Desktop"` |
| convenience | `scripts` | `alias scripts='cd "$DOTFILES_ALIAS_ROOT/scripts"'` |
| convenience | `home` | `alias home="cd ~"` |
| convenience | `docs` | `alias docs="cd ~/Documents"        # Short form of 'documents'` |
| convenience | `down` | `alias down="cd ~/Downloads"        # Short form of 'downloads'` |
| convenience | `desk` | `alias desk="cd ~/Desktop"          # Short form of 'desktop'` |
| risky | `update` | `alias update="brew update && brew upgrade"` |
| convenience | `brewclean` | `alias brewclean="brew cleanup"             # Remove old versions and stale downloads` |
| convenience | `brewinfo` | `alias brewinfo="brew list --versions"      # Show every installed formula + version` |
| convenience | `myip` | `alias myip="curl ifconfig.me"              # Public/external IP via ifconfig.me API` |
| convenience | `localip` | `alias localip="ifconfig \| grep inet"       # All local interface IPs (IPv4 + IPv6)` |
| convenience | `mem` | `alias mem="vm_stat"                        # macOS virtual memory stats (page-based)` |
| convenience | `cpu` | `alias cpu="top -l 1 \| head -n 10"         # One-shot top snapshot, header only` |
| convenience | `psg` | `alias psg="ps aux \| grep"` |
| risky | `rm` | `alias rm="rm -i"                          # Confirm before every removal` |
| risky | `cp` | `alias cp="cp -i"                          # Confirm before overwriting target` |
| risky | `mv` | `alias mv="mv -i"                          # Confirm before overwriting target` |
| convenience | `untar` | `alias untar="tar -xvf"                    # eXtract Verbosely from File` |
| convenience | `targz` | `alias targz="tar -czvf"                   # Create gZipped tar archive Verbosely` |
| convenience | `ff` | `alias ff="find . -name"` |
| convenience | `showfiles` | `alias showfiles="defaults write com.apple.finder AppleShowAllFiles YES && killall Finder"` |
| convenience | `hidefiles` | `alias hidefiles="defaults write com.apple.finder AppleShowAllFiles NO && killall Finder"` |
| convenience | `spotlight` | `alias spotlight="mdfind"` |
| convenience | `gs` | `alias gs="git status"                     # Working tree status` |
| convenience | `ga` | `alias ga="git add"                        # Stage specific files  e.g. ga file.txt` |
| convenience | `gaa` | `alias gaa="git add ."                     # Stage everything in cwd (use with care)` |
| convenience | `gc` | `alias gc="git commit -m"                  # Commit with inline message  e.g. gc "fix bug"` |
| convenience | `gp` | `alias gp="git push"                       # Push current branch to remote` |
| convenience | `gl` | `alias gl="git pull"                       # Pull (fetch + merge) from remote` |
| convenience | `gd` | `alias gd="git diff"                       # Unstaged changes vs last commit` |
| convenience | `gb` | `alias gb="git branch"                     # List or create branches` |
| convenience | `gco` | `alias gco="git checkout"                  # Switch branches or restore files` |
| convenience | `glog` | `alias glog="git log --oneline"            # Compact one-line-per-commit log` |
| convenience | `clrnpx` | `alias clrnpx="rm -rf ~/.npm/_npx"` |
| convenience | `v` | `alias v="vim"                             # e.g. v config.yaml` |
| convenience | `n` | `alias n="nano"                            # e.g. n notes.txt (simpler editor)` |
| convenience | `e` | `alias e="echo"                            # Quick echo for piping/testing` |
| convenience | `codehere` | `alias codehere="code ."                   # Launch VS Code rooted here` |
| convenience | `finder` | `alias finder="open ."                     # Launch Finder window here` |
| convenience | `c` | `alias c="clear"                           # Minimal keystroke clear` |
| convenience | `cls` | `alias cls="clear"                         # For muscle memory from Windows/DOS` |
| convenience | `now` | `alias now="date"                          # Current date/time in default locale` |
| convenience | `timestamp` | `alias timestamp="date +%Y%m%d_%H%M%S"     # Filename-safe timestamp (no colons/spaces)` |
| risky | `du` | `alias du="du -h"                          # Directory size summary` |
| risky | `df` | `alias df="df -h"                          # Filesystem free space` |
| convenience | `diskspace` | `alias diskspace="df -h"                   # Readable alias for df` |
| risky | `ping` | `alias ping="ping -c 5"                    # Limit to 5 pings (macOS ping runs forever by default)` |
| convenience | `flushdns` | `alias flushdns="sudo dscacheutil -flushcache" # Clear macOS DNS resolver cache` |
| risky | `python` | `alias python="python3"` |
| risky | `pip` | `alias pip="pip3"` |
| convenience | `venv` | `alias venv="python3 -m venv"              # Create venv  e.g. venv .venv` |
| convenience | `activate` | `alias activate="source venv/bin/activate" # Activate a venv in ./venv/` |
| convenience | `serve` | `alias serve="python3 -m http.server"      # HTTP server on :8000 for current dir` |
| convenience | `jsonpp` | `alias jsonpp="python3 -m json.tool"       # Pretty-print JSON from stdin or file` |
| convenience | `copy` | `alias copy="pbcopy"                       # Pipe text to clipboard  e.g. echo hi \| copy` |
| convenience | `paste` | `alias paste="pbpaste"                     # Emit clipboard contents to stdout` |
| convenience | `copyfile` | `alias copyfile="pbcopy <"                 # Copy a file's contents  e.g. copyfile notes.txt` |
| risky | `copyfolder` | `alias copyfolder="tail -n +1 * \| pbcopy"  # Copy ALL files' contents in cwd to clipboard` |
| convenience | `screensleep` | `alias screensleep="pmset displaysleepnow" # Immediately sleep the display` |
| convenience | `lock` | `alias lock="pmset displaysleepnow"        # Lock screen (display sleep triggers lock)` |
| convenience | `eject` | `alias eject="diskutil eject"              # Eject external disk  e.g. eject /dev/disk2` |
| convenience | `battery` | `alias battery="pmset -g batt"             # Show battery % and charging status` |
| convenience | `howto` | `alias howto="howto.sh"                    # Interactive help / how-to lookup` |
| convenience | `wi` | `alias wi="whatis.sh"                      # Explain a command (named 'wi' to avoid shadowing /usr/bin/whatis)` |
| convenience | `dotfiles_check` | `alias dotfiles_check="dotfiles_check.sh"  # Verify dotfiles installation integrity` |
| convenience | `dotfiles-check` | `alias dotfiles-check="dotfiles_check.sh"  # Hyphenated alternative for the same check` |
| convenience | `pomo` | `alias pomo="take_a_break.sh 25"           # Pomodoro timer  25-minute focus session` |
| daily-core | `todo` | `alias todo="todo.sh"                      # Task manager entry point` |
| convenience | `idea` | `alias idea="idea.sh"                      # Idea manager entry point` |
| daily-core | `todolist` | `alias todolist="todo.sh list"             # List all open tasks` |
| daily-core | `tododone` | `alias tododone="todo.sh done"             # Mark a task as completed` |
| daily-core | `todoadd` | `alias todoadd="todo.sh add"              # Add a new task` |
| daily-core | `journal` | `alias journal="journal.sh"               # Journal entry point` |
| convenience | `tbreak` | `alias tbreak="take_a_break.sh"           # Flexible break timer (default duration)` |
| daily-core | `focus` | `alias focus="focus.sh"                    # Focus mode  block distractions` |
| convenience | `t-start` | `alias t-start="todo.sh start"            # Start timing a task` |
| convenience | `t-stop` | `alias t-stop="todo.sh stop"              # Stop timing the current task` |
| convenience | `t-status` | `alias t-status="time_tracker.sh status"  # Show what's being tracked and elapsed time` |
| daily-core | `spoons` | `alias spoons="spoon_manager.sh"           # Full spoon manager interface` |
| daily-core | `s-check` | `alias s-check="spoon_manager.sh check"    # How many spoons remain today?` |
| daily-core | `s-spend` | `alias s-spend="spoon_manager.sh spend"    # Log spending spoons on an activity` |
| convenience | `correlate` | `alias correlate="correlate.sh"            # Find patterns between health/productivity data` |
| convenience | `corr-sleep` | `alias corr-sleep='correlate.sh run "$DOTFILES_DATA_ROOT/fitbit/sleep_minutes.txt" "$DOTFILES_DATA_ROOT/health.txt" 0 1 1 2' # Sleep minutes vs energy log` |
| convenience | `corr-steps` | `alias corr-steps='correlate.sh run "$DOTFILES_DATA_ROOT/fitbit/steps.txt" "$DOTFILES_DATA_ROOT/health.txt" 0 1 1 2' # Steps vs energy log` |
| convenience | `corr-rhr` | `alias corr-rhr='correlate.sh run "$DOTFILES_DATA_ROOT/fitbit/resting_heart_rate.txt" "$DOTFILES_DATA_ROOT/health.txt" 0 1 1 2' # Resting HR vs energy log` |
| convenience | `corr-hrv` | `alias corr-hrv='correlate.sh run "$DOTFILES_DATA_ROOT/fitbit/hrv.txt" "$DOTFILES_DATA_ROOT/health.txt" 0 1 1 2' # HRV vs energy log` |
| convenience | `daily-report` | `alias daily-report="generate_report.sh daily"  # Generate today's summary report` |
| convenience | `insight` | `alias insight="insight.sh"                # AI-powered insight from recent data` |
| daily-core | `health` | `alias health="health.sh"                  # Log symptoms, energy, and health events` |
| daily-core | `meds` | `alias meds="meds.sh"                      # Medication tracking and reminders` |
| convenience | `next` | `alias next="todo.sh top 1"               # Show the single highest-priority task` |
| daily-core | `t` | `alias t="todo.sh list"                    # 1-key todo list` |
| daily-core | `j` | `alias j="journal.sh"                      # 1-key journal` |
| daily-core | `ta` | `alias ta="todo.sh add"                    # 2-key task add  e.g. ta "Buy groceries"` |
| daily-core | `ja` | `alias ja="journal.sh add"                 # 2-key journal add  e.g. ja "Good energy today"` |
| convenience | `memo` | `alias memo="cheatsheet.sh"               # Show personal cheatsheet / quick reference` |
| daily-core | `schedule` | `alias schedule="schedule.sh"             # View today's schedule` |
| convenience | `clutter` | `alias clutter="review_clutter.sh"        # Review and clean up stale files` |
| convenience | `checkenv` | `alias checkenv="validate_env.sh"         # Validate .env config is complete and correct` |
| convenience | `newscript` | `alias newscript="new_script.sh"          # Scaffold a new bash script with proper headers` |
| convenience | `weather` | `alias weather="weather.sh"               # Current weather forecast` |
| convenience | `findtext` | `alias findtext="findtext.sh"             # Search file contents recursively` |
| convenience | `graballtext` | `alias graballtext="grab_all_text.sh"     # Copy all readable non-ignored text files to clipboard` |
| convenience | `pdf2md` | `alias pdf2md="pdf_to_markdown.sh"        # Convert a PDF into Markdown for cheaper AI ingestion` |
| convenience | `newproject` | `alias newproject="start_project.sh"      # Scaffold a new project directory` |
| convenience | `newpython` | `alias newpython="mkproject_py.sh"        # Scaffold a Python project with venv` |
| convenience | `newpy` | `alias newpy="mkproject_py.sh"            # Short form of newpython` |
| convenience | `progress` | `alias progress="my_progress.sh"          # Show git contribution stats / progress` |
| convenience | `projects` | `alias projects="gh-projects.sh"          # List GitHub projects` |
| convenience | `backup` | `alias backup="backup_project.sh"         # Back up current project directory` |
| convenience | `backup-data` | `alias backup-data="backup_data.sh"       # Back up ~/.config/dotfiles-data/` |
| convenience | `findbig` | `alias findbig="findbig.sh"              # Find large files eating disk space` |
| convenience | `unpack` | `alias unpack="unpacker.sh"              # Smart archive extractor (tar/zip/gz/etc.)` |
| convenience | `tidydown` | `alias tidydown="tidy_downloads.sh"      # Auto-organize ~/Downloads by file type` |
| daily-core | `startday` | `alias startday="startday.sh"             # Morning routine: weather, briefing, todos, spoons` |
| daily-core | `goodevening` | `alias goodevening="goodevening.sh"       # Evening wind-down: journal prompt, summary` |
| convenience | `greeting` | `alias greeting="greeting.sh"             # Quick motivational greeting` |
| convenience | `weekreview` | `alias weekreview="week_in_review.sh"     # Weekly retrospective summary` |
| convenience | `g` | `alias g="source $DOTFILES_ALIAS_ROOT/scripts/g.sh"` |
| convenience | `openf` | `alias openf="open_file.sh"               # Open a file with its default macOS app` |
| convenience | `finddupes` | `alias finddupes="duplicate_finder.sh"     # Find duplicate files by content hash` |
| convenience | `organize` | `alias organize="file_organizer.sh"        # Auto-organize files by type/date` |
| convenience | `systemlog` | `alias systemlog='tail -n 20 "$DOTFILES_DATA_ROOT/system.log"'  # Last 20 log lines` |
| convenience | `logs` | `alias logs="logs.sh"                      # Full log viewer` |
| convenience | `logtail` | `alias logtail="logs.sh tail"              # Follow log in real time` |
| convenience | `logerrors` | `alias logerrors="logs.sh errors"          # Show only error-level entries` |
| convenience | `sysinfo` | `alias sysinfo="system_info.sh"            # CPU, memory, disk, OS summary` |
| convenience | `batterycheck` | `alias batterycheck="battery_check.sh"     # Detailed battery health report` |
| convenience | `processes` | `alias processes="process_manager.sh"      # Interactive process manager` |
| convenience | `netinfo` | `alias netinfo="network_info.sh"           # Network interfaces and connectivity` |
| convenience | `topcpu` | `alias topcpu="process_manager.sh top"     # Processes sorted by CPU usage` |
| convenience | `topmem` | `alias topmem="process_manager.sh memory"  # Processes sorted by memory usage` |
| convenience | `netstatus` | `alias netstatus="network_info.sh status"  # Am I connected? What IP?` |
| convenience | `netspeed` | `alias netspeed="network_info.sh speed"    # Quick bandwidth test` |
| daily-core | `gcal` | `alias gcal="gcal.sh"` |
| risky | `calendar` | `alias calendar="gcal.sh"                  # Note: intentionally shadows /usr/bin/calendar` |
| convenience | `clip` | `alias clip="clipboard_manager.sh"         # Full clipboard manager interface` |
| convenience | `clipsave` | `alias clipsave="clipboard_manager.sh save"   # Save current clipboard to a named slot` |
| convenience | `clipload` | `alias clipload="clipboard_manager.sh load"   # Load a named slot back to clipboard` |
| convenience | `cliplist` | `alias cliplist="clipboard_manager.sh list"   # List all saved clipboard slots` |
| convenience | `app` | `alias app="app_launcher.sh"` |
| convenience | `launch` | `alias launch="app_launcher.sh"            # Synonym for discoverability` |
| daily-core | `remind` | `alias remind="remind_me.sh"              # Set a timed reminder notification` |
| daily-core | `did` | `alias did="done.sh"                      # Log a completed activity ('done' is a shell reserved word)` |
| convenience | `dev` | `alias dev="dev_shortcuts.sh"              # Dev shortcuts menu` |
| convenience | `devenv` | `alias devenv="dev_shortcuts.sh env"       # Load project environment variables` |
| convenience | `server` | `alias server="dev_shortcuts.sh server"    # Start a local dev server` |
| convenience | `json` | `alias json="dev_shortcuts.sh json"        # JSON formatting/inspection` |
| risky | `gitquick` | `alias gitquick="dev_shortcuts.sh gitquick"  # Quick git add+commit+push` |
| convenience | `textproc` | `alias textproc="text_processor.sh"              # Full text processor menu` |
| convenience | `wordcount` | `alias wordcount="text_processor.sh count"       # Word/line/char count` |
| convenience | `textsearch` | `alias textsearch="text_processor.sh search"     # Search within files` |
| convenience | `textreplace` | `alias textreplace="text_processor.sh replace"   # Find-and-replace across files` |
| convenience | `textclean` | `alias textclean="text_processor.sh clean"       # Strip whitespace, fix encoding, etc.` |
| convenience | `media` | `alias media="media_converter.sh"                # Full media converter menu` |
| convenience | `video2audio` | `alias video2audio="media_converter.sh video2audio"   # Extract audio track from video` |
| convenience | `resizeimg` | `alias resizeimg="media_converter.sh resize_image"    # Resize images (preserves aspect)` |
| convenience | `compresspdf` | `alias compresspdf="media_converter.sh pdf_compress"  # Reduce PDF file size` |
| convenience | `stitch` | `alias stitch="media_converter.sh audio_stitch"       # Concatenate audio files` |
| convenience | `archive` | `alias archive="archive_manager.sh"              # Full archive manager menu` |
| convenience | `archcreate` | `alias archcreate="archive_manager.sh create"    # Create a new archive` |
| convenience | `archextract` | `alias archextract="archive_manager.sh extract"  # Extract an archive` |
| convenience | `archlist` | `alias archlist="archive_manager.sh list"        # List archive contents without extracting` |
| convenience | `info` | `alias info="weather.sh && echo && todo.sh list"           # Weather + open tasks` |
| daily-core | `status` | `alias status="status.sh"                                  # Unified status dashboard` |
| compatibility | `observer` | `alias observer="observer.sh"                              # Obsidian observer capture/digest tool` |
| convenience | `overview` | `alias overview="system_info.sh && echo && battery_check.sh"  # Hardware + battery` |
| convenience | `cleanup` | `alias cleanup="cd ~/Downloads && file_organizer.sh bytype && findbig.sh"  # Tidy Downloads, flag large files` |
| risky | `quickbackup` | `alias quickbackup="backup_project.sh && echo 'Backup complete!'"          # One-command project backup` |
| convenience | `devstart` | `alias devstart="dev_shortcuts.sh env && codehere"         # Load env vars, open VS Code` |
| convenience | `gitcheck` | `alias gitcheck="my_progress.sh && git status"             # Contribution stats + working tree` |
| convenience | `blog` | `alias blog="blog.sh"                      # Blog management CLI (create, publish, list)` |
| convenience | `blog-recent` | `alias blog-recent="blog_recent_content.sh"  # Show recently published/drafted blog posts` |
| convenience | `dump` | `alias dump="dump.sh"                      # Dump structured data for debugging/export` |
| convenience | `data_validate` | `alias data_validate="data_validate.sh"    # Validate data files in ~/.config/dotfiles-data/` |
| compatibility | `dhp-tech` | `alias dhp-tech="$DOTFILES_ALIAS_ROOT/bin/dhp-tech.sh"           # Technical/coding assistant` |
| compatibility | `dhp-creative` | `alias dhp-creative="$DOTFILES_ALIAS_ROOT/bin/dhp-creative.sh"   # Creative writing & ideation` |
| compatibility | `dhp-content` | `alias dhp-content="$DOTFILES_ALIAS_ROOT/bin/dhp-content.sh"     # Content strategy & drafting` |
| compatibility | `dhp-strategy` | `alias dhp-strategy="$DOTFILES_ALIAS_ROOT/bin/dhp-strategy.sh"   # Business/life strategy advisor` |
| compatibility | `dhp-brand` | `alias dhp-brand="$DOTFILES_ALIAS_ROOT/bin/dhp-brand.sh"         # Brand voice & identity` |
| compatibility | `dhp-market` | `alias dhp-market="$DOTFILES_ALIAS_ROOT/bin/dhp-market.sh"       # Market analysis & trends` |
| compatibility | `dhp-stoic` | `alias dhp-stoic="$DOTFILES_ALIAS_ROOT/bin/dhp-stoic.sh"         # Stoic philosophy / mindset coach` |
| compatibility | `dhp-research` | `alias dhp-research="$DOTFILES_ALIAS_ROOT/bin/dhp-research.sh"   # Deep research & fact-finding` |
| compatibility | `dhp-narrative` | `alias dhp-narrative="$DOTFILES_ALIAS_ROOT/bin/dhp-narrative.sh"  # Storytelling & narrative design` |
| compatibility | `dhp-copy` | `alias dhp-copy="$DOTFILES_ALIAS_ROOT/bin/dhp-copy.sh"           # Copywriting (ads, emails, etc.)` |
| compatibility | `dhp-finance` | `alias dhp-finance="$DOTFILES_ALIAS_ROOT/bin/dhp-finance.sh"     # Financial analysis & advice` |
| compatibility | `dhp-memory` | `alias dhp-memory="$DOTFILES_ALIAS_ROOT/bin/dhp-memory.sh"       # Store memories to knowledge base` |
| compatibility | `dhp-memory-search` | `alias dhp-memory-search="$DOTFILES_ALIAS_ROOT/bin/dhp-memory-search.sh"  # Search stored memories` |
| compatibility | `tech` | `alias tech="$DOTFILES_ALIAS_ROOT/bin/dhp-tech.sh"` |
| compatibility | `creative` | `alias creative="$DOTFILES_ALIAS_ROOT/bin/dhp-creative.sh"` |
| compatibility | `content` | `alias content="$DOTFILES_ALIAS_ROOT/bin/dhp-content.sh"` |
| compatibility | `strategy` | `alias strategy="$DOTFILES_ALIAS_ROOT/bin/dhp-strategy.sh"` |
| compatibility | `brand` | `alias brand="$DOTFILES_ALIAS_ROOT/bin/dhp-brand.sh"` |
| compatibility | `market` | `alias market="$DOTFILES_ALIAS_ROOT/bin/dhp-market.sh"` |
| compatibility | `stoic` | `alias stoic="$DOTFILES_ALIAS_ROOT/bin/dhp-stoic.sh"` |
| compatibility | `research` | `alias research="$DOTFILES_ALIAS_ROOT/bin/dhp-research.sh"` |
| compatibility | `narrative` | `alias narrative="$DOTFILES_ALIAS_ROOT/bin/dhp-narrative.sh"` |
| compatibility | `aicopy` | `alias aicopy="$DOTFILES_ALIAS_ROOT/bin/dhp-copy.sh"             # 'aicopy' not 'copy' (copy = pbcopy)` |
| compatibility | `morphling` | `alias morphling="$DOTFILES_ALIAS_ROOT/bin/dhp-morphling.sh"      # Shape-shifting multi-persona dispatcher` |
| compatibility | `finance` | `alias finance="$DOTFILES_ALIAS_ROOT/bin/dhp-finance.sh"` |
| compatibility | `memory` | `alias memory="$DOTFILES_ALIAS_ROOT/bin/dhp-memory.sh"` |
| compatibility | `memory-search` | `alias memory-search="$DOTFILES_ALIAS_ROOT/bin/dhp-memory-search.sh"` |
| compatibility | `dhp-morphling` | `alias dhp-morphling="$DOTFILES_ALIAS_ROOT/bin/dhp-morphling.sh"` |
| compatibility | `dhp` | `alias dhp="$DOTFILES_ALIAS_ROOT/bin/dhp-tech.sh"                # Default dispatcher  tech` |
| compatibility | `dispatch` | `alias dispatch="$DOTFILES_ALIAS_ROOT/bin/dispatch.sh"            # Generic dispatch router` |
| compatibility | `dhp-project` | `alias dhp-project="$DOTFILES_ALIAS_ROOT/bin/dhp-project.sh"     # Multi-specialist project orchestration` |
| compatibility | `ai-project` | `alias ai-project="$DOTFILES_ALIAS_ROOT/bin/dhp-project.sh"      # Shorthand for dhp-project` |
| compatibility | `dhp-chain` | `alias dhp-chain="$DOTFILES_ALIAS_ROOT/bin/dhp-chain.sh"         # Chain dispatchers sequentially (pipe output)` |
| compatibility | `ai-chain` | `alias ai-chain="$DOTFILES_ALIAS_ROOT/bin/dhp-chain.sh"          # Shorthand for dhp-chain` |
| compatibility | `cyborg` | `alias cyborg="$DOTFILES_ALIAS_ROOT/bin/cyborg"                  # Cyborg Lab ingest/resume agent` |
| compatibility | `ai-suggest` | `alias ai-suggest="ai_suggest.sh"                                 # Context-aware AI suggestions for current task` |
| compatibility | `ai-context` | `alias ai-context="source $DOTFILES_ALIAS_ROOT/bin/dhp-context.sh"  # Load context-gathering helpers (sourced, not executed)` |
| compatibility | `swipe` | `alias swipe="$DOTFILES_ALIAS_ROOT/bin/swipe.sh"` |
| convenience | `G` | `alias -g G="\| grep -i"                   # Case-insensitive grep filter` |
| convenience | `C` | `alias -g C="\| pbcopy"                    # Pipe output to clipboard` |
| convenience | `L` | `alias -g L="\| less"                      # Pipe output to pager` |
| convenience | `H` | `alias -g H="\| head -n 10"               # Show first 10 lines only` |
| convenience | `N` | `alias -g N="> /dev/null 2>&1"           # Silence all output (stdout + stderr)` |
| convenience | `cd..` | `alias cd..="cd .."                        # Missing space` |
| convenience | `ls-l` | `alias ls-l="ls -l"                        # Hyphen instead of space` |
| convenience | `sl` | `alias sl="ls"                             # Transposed letters` |
| convenience | `dc` | `alias dc="cd"                             # Transposed letters` |
| convenience | `gut` | `alias gut="git"                           # Transposed letters` |
| convenience | `gti` | `alias gti="git"                           # Transposed letters` |
| convenience | `pwd` | `alias pwd="pwd"                           # Already correct (harmless)` |
| convenience | `pdw` | `alias pdw="pwd"                           # Transposed letters` |
| convenience | `vmi` | `alias vmi="vim"                           # Transposed letters` |
| convenience | `hh` | `alias hh="history"                        # Shell history` |
| convenience | `xx` | `alias xx="exit"                           # Exit terminal` |
| convenience | `qq` | `alias qq="exit"                           # Exit terminal (vim-inspired)` |
| convenience | `b` | `alias b="cd -"                            # Bounce back to previous directory` |
| risky | `doneit` | `alias doneit="git add . && git commit -m 'update' && git push"  # Quick ship it` |
| risky | `gwip` | `alias gwip="git add . && git commit -m 'wip'"                   # Save work-in-progress` |
| convenience | `gup` | `alias gup="git pull --rebase"             # Pull with rebase (cleaner history)` |
| convenience | `md` | `alias md="mkdir -p"                       # Make directory (with parents)` |
| convenience | `cx` | `alias cx="chmod +x"                       # Make file executable` |
| convenience | `ez` | `alias ez="code \\$DOTFILES_ALIAS_ROOT/zsh/aliases.zsh"  # Edit this aliases file in VS Code` |
| convenience | `ezrc` | `alias ezrc="code ~/.zshrc"               # Edit .zshrc in VS Code` |
| risky | `reload` | `alias reload="source ~/.zshrc && echo 'Zsh reloaded!'"  # Apply config changes instantly` |
| compatibility | `ap` | `alias ap="$DOTFILES_ALIAS_ROOT/bin/cyborg auto"` |
| compatibility | `apy` | `alias apy="$DOTFILES_ALIAS_ROOT/bin/cyborg auto --yes"` |
| compatibility | `apc` | `alias apc="$DOTFILES_ALIAS_ROOT/bin/cyborg resume"` |

## Shell Functions

- `gitnexus`
- `gn`
- `mkcd`
- `backup_file`
- `pman`
- `search`
- `morning`
- `endday`
- `apb`
- `apby`
- `apbp`
- `apbpy`
