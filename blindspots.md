# **Dotfiles Evolution: A 20-Point Implementation Plan**

This document outlines a 20-point plan to evolve the existing dotfiles system. The goals are to:

1. **Increase Resilience:** Add data backups and system health checks.  
2. **Add Proactive Intelligence:** Turn data logs into actionable insights and trend analysis.  
3. **Reduce Friction:** Automate system maintenance and streamline complex workflows.  
4. **Integrate Siloed Tools:** Connect the todo system with git, the blog, and the journal.  
5. **Strengthen Cognitive Support:** Implement proactive nudges, focus tools, and just-in-time help to actively combat brain fog and perfectionism.

## **Phase 1: Resilience & Data Insight**

### **\[Blindspot 1\]: Data Resilience**

* **Critique:** The system's core data in \~/.config/dotfiles-data/ is not automatically backed up, creating a single point of failure.  
* **Implementation Plan:**  
  1. Create a new script: scripts/backup\_data.sh.  
  2. This script will compress the *entire* \~/.config/dotfiles-data/ directory into a timestamped .tar.gz file.  
  3. The script should save this backup to a user-configurable, safe location (e.g., \~/Backups/dotfiles\_data/).  
  4. Modify scripts/goodevening.sh: Add a line at the end to *silently* run backup\_data.sh.  
* **Target Files:**  
  * scripts/backup\_data.sh (New)  
  * scripts/goodevening.sh (Modified)

### **\[Blindspot 2\]: Data Insight**

* **Critique:** health.sh and meds.sh are good at capturing data but provide no long-term trend analysis.  
* **Implementation Plan:**  
  1. Modify scripts/health.sh: Add a new dashboard subcommand.  
     * This command will use awk and grep on health.txt to calculate and print stats for the last 30 days: "Average energy level", "Symptom frequency (e.g., Fatigue: 12 times)", "Average energy on days 'fog' was logged".  
  2. Modify scripts/meds.sh: Add a new dashboard subcommand.  
     * This command will parse medication schedules and dose logs to calculate and print adherence percentages (e.g., "Medication X Adherence (30d): 92% (55/60 doses)").  
* **Target Files:**  
  * scripts/health.sh (Modified)  
  * scripts/meds.sh (Modified)

### **\[Blindspot 3\]: Stale Task Accumulation**

* **Critique:** todo.sh is a flat list that can accumulate stale tasks, causing anxiety.  
* **Implementation Plan:**  
  1. Modify scripts/todo.sh (add subcommand): Prepend a YYYY-MM-DD| timestamp to each new task (e.g., echo "$(date \+%Y-%m-%d)|$task\_text" \>\> "$TODO\_FILE").  
  2. Modify scripts/todo.sh (list subcommand): Update the cat \-n command to use awk to parse the timestamp and print it, while still printing the line number.  
  3. Modify scripts/startday.sh: Add a new "⏰ STALE TASKS" section. This will parse todo.txt and print any tasks with a timestamp older than 7 days.  
* **Target Files:**  
  * scripts/todo.sh (Modified)  
  * scripts/startday.sh (Modified)

### **\[Blindspot 4\]: System Fragility**

* **Critique:** The complex system has deferred dependency checks. A missing tool (jq) or script could cause a silent failure.  
* **Implementation Plan:**  
  1. Create scripts/dotfiles\_check.sh: This "doctor" script will validate the full system.  
  2. It must verify: 1\) Key script files exist, 2\) \~/.config/dotfiles-data exists, 3\) Binary dependencies (jq, curl, gawk, osascript) are in the PATH, 4\) \~/.github\_token exists.  
  3. It should print a simple "All systems OK" or a detailed list of errors.  
  4. Add an alias: alias dotfiles\_check="dotfiles\_check.sh".  
* **Target Files:**  
  * scripts/dotfiles\_check.sh (New)  
  * zsh/aliases.zsh (Modified)

## **Phase 2: Friction Reduction & Usability**

### **\[Blindspot 5\]: "Write-Only" Journal**

* **Critique:** journal.sh is excellent for capture but has poor retrieval, limiting its use as a "second brain".  
* **Implementation Plan:**  
  1. Modify scripts/journal.sh: Add a search \<term\> subcommand. This will be a user-friendly wrapper for grep \-i "$term" $JOURNAL\_FILE.  
  2. Modify scripts/journal.sh: Add an onthisday subcommand. This will grep the journal for entries with the current month and day from previous years (e.g., grep \-i "....-$(date \+%m-%d)" $JOURNAL\_FILE).  
* **Target Files:**  
  * scripts/journal.sh (Modified)

### **\[Blindspot 6\]: System Maintenance Friction**

* **Critique:** Adding new scripts or setting up a new machine is a high-friction, manual process.  
* **Implementation Plan:**  
  1. Create bootstrap.sh in the repo root: This script will automate new machine setup (install Homebrew, brew install dependencies, create data dir, symlink dotfiles).  
  2. Create scripts/new\_script.sh: This script will automate adding new tools.  
     * Input: new\_script.sh my\_tool  
     * Action: Creates scripts/my\_tool.sh, adds \#\!/bin/bash and set \-euo pipefail, makes it executable, *and* appends alias my\_tool="my\_tool.sh" to zsh/aliases.zsh.  
* **Target Files:**  
  * bootstrap.sh (New)  
  * scripts/new\_script.sh (New)  
  * zsh/aliases.zsh (Modified by new\_script.sh)

### **\[Blindspot 7\]: High-Cost Context Switching**

* **Critique:** Navigation is split across three redundant tools (goto, recent\_dirs, workspace\_manager).  
* **Implementation Plan:**  
  1. Create scripts/g.sh: This new, consolidated navigation script will replace the old ones.  
  2. Implement subcommands: g \<bookmark\> (for goto), g \-r (for recent\_dirs), g \-s \<name\> (for workspace save), g \-l \<name\> (for workspace load).  
  3. Add "Context-Aware Hook" logic: g.sh should parse a config file (e.g., dir\_bookmarks) that can store an optional "on-enter" command (e.g., blog:\~/Projects/blog:blog status). When g blog is run, it will cd *and* execute blog status.  
  4. Modify zsh/aliases.zsh: Remove old aliases for goto, back, workspace and add alias g="source g.sh" (must be sourced to change directory).  
* **Target Files:**  
  * scripts/g.sh (New)  
  * zsh/aliases.sh (Modified)  
  * scripts/goto.sh (Deprecated)  
  * scripts/recent\_dirs.sh (Deprecated)  
  * scripts/workspace\_manager.sh (Deprecated)

### **\[Blindspot 8\]: The Documentation Chasm**

* **Critique:** Help is either "all" (cheatsheet.sh) or "nothing" (failing silently).  
* **Implementation Plan:**  
  1. Modify all core scripts (todo.sh, health.sh, meds.sh, journal.sh, etc.): Update the \*) case in the case "$1" in block. It must: 1\) Print a clear "Error: Unknown command '$1'" to stderr, 2\) Print the full usage/help message, 3\) exit 1\. This provides "Just-in-Time" help.  
  2. Create scripts/whatis.sh: This script will search zsh/aliases.zsh and scripts/README.md for a command and print the matching line (e.g., whatis gaa \-\> alias gaa="git add .").  
  3. Add alias: alias whatis="whatis.sh".  
* **Target Files:**  
  * All scripts with case "$1" in blocks (Modified)  
  * scripts/whatis.sh (New)  
  * zsh/aliases.zsh (Modified)

## **Phase 3: Proactive Automation & Nudges**

### **\[Blindspot 9\]: Passive Health System**

* **Critique:** The health system is manual ("write-only"), which fails on low-energy days.  
* **Implementation Plan:**  
  1. Modify scripts/goodevening.sh: Make it *interactive*. Add prompts that ask "How was your energy today (1-10)?" and "Any symptoms to log?". If input is provided, pipe it to health.sh energy "$input" or health.sh symptom "$input".  
  2. Automate meds.sh remind: Add a cron job (or launchd agent) to run the meds.sh remind command at user-defined intervals (e.g., 8am, 8pm), which will trigger the osascript notification.  
* **Target Files:**  
  * scripts/goodevening.sh (Modified)  
  * (Requires crontab \-e or launchd config, which is outside the repo)

### **\[Blindspot 10\]: Siloed "Blog" and "Dotfiles" Systems**

* **Critique:** Your \#1 priority, the blog, is disconnected from your main todo.sh productivity loop.  
* **Implementation Plan:**  
  1. Modify scripts/blog.sh: Add a sync\_tasks subcommand. This script will: 1\) Get all stubs from blog stubs, 2\. Get all tasks from todo list, 3\. For any stub not already in todo.txt (e.g., as "BLOG: \<stub\_name\>"), add it via todo.sh add "BLOG: \<stub\_name\>".  
  2. Modify scripts/startday.sh: Add a call to blog sync\_tasks to run it automatically each morning.  
  3. Modify scripts/blog.sh: Add an ideas subcommand that simply runs journal.sh search "blog idea".  
* **Target Files:**  
  * scripts/blog.sh (Modified)  
  * scripts/startday.sh (Modified)

### **\[Blindspot 11\]: Actively Fighting Perfectionism**

* **Critique:** The system documents the "anti-perfectionism" goal but doesn't actively *nudge* you towards it.  
* **Implementation Plan:**  
  1. Modify scripts/goodevening.sh: "Gamify" progress. If *any* tasks were completed, print "🎉 Win: You completed X task(s) today. Progress is progress." If *any* journal entries were made, print "🧠 Win: You logged Y entries. Context captured." If both are zero, print "Today was a rest day. Logging off is a valid and productive choice."  
  2. Modify zsh/aliases.zsh: Add alias pomo="take\_a\_break.sh 25". This weaponizes take\_a\_break.sh as a 25-minute Pomodoro timer.  
* **Target Files:**  
  * scripts/goodevening.sh (Modified)  
  * zsh/aliases.zsh (Modified)

### **\[Blindspot 12\]: High-Friction "State" Management**

* **Critique:** Starting work requires multiple "setup tax" commands (cd, activate venv, launch apps).  
* **Implementation Plan:**  
  1. Evolve scripts/workspace\_manager.sh into scripts/state\_manager.sh (or just enhance the new scripts/g.sh).  
  2. The save command must also detect and save: 1\) The path to venv/bin/activate if it exists, 2\) A list of associated apps (e.g., g \-a code to link the "code" app).  
  3. The load command (g \<name\>) must: 1\) cd to the directory, 2\) *Automatically* source the venv if one is saved, 3\) *Automatically* launch all linked apps via app\_launcher.sh.  
* **Target Files:**  
  * scripts/workspace\_manager.sh (Modified) or scripts/g.sh (Modified)  
  * scripts/app\_launcher.sh (May need modification to be called by another script)

## **Phase 4: Intelligent Workflow Integration**

### **\[Blindspot 13\]: "Git Commit" Context Gap**

* **Critique:** todo.sh (intent) and git (action) are disconnected.  
* **Implementation Plan:**  
  1. Modify scripts/todo.sh: Add a commit subcommand.  
  2. todo commit \<num\> "message" will: 1\) Run git commit \-m "message", 2\) Run the internal logic for todo done \<num\>.  
  3. todo commit \<num\> (with no message) will: 1\) Extract the task text for \<num\>, 2\) Run git commit \-m "Done: \[Task Text\]", 3\) Run the internal logic for todo done \<num\>.  
* **Target Files:**  
  * scripts/todo.sh (Modified)

### **\[Blindspot 14\]: "Now vs. Later" Task Ambiguity**

* **Critique:** todo.sh is a flat list that creates cognitive load.  
* **Implementation Plan:**  
  1. Modify scripts/todo.sh: Add a bump \<num\> subcommand that moves the specified task to the top of todo.txt.  
  2. Modify scripts/todo.sh: Add a top \<count\> subcommand that prints only the top \<count\> tasks.  
  3. Modify zsh/aliases.zsh: Add alias next="todo top 1".  
  4. Modify scripts/startday.sh and scripts/status.sh: Change the "TODAY'S TASKS" section to only show todo top 3 instead of the full list.  
* **Target Files:**  
  * scripts/todo.sh (Modified)  
  * zsh/aliases.zsh (Modified)  
  * scripts/startday.sh (Modified)  
  * scripts/status.sh (Modified)

### **\[Blindspot 15\]: The "Command Black Hole"**

* **Critique:** No system exists for scheduling a command or reminder for a *specific* future time.  
* **Implementation Plan:**  
  1. Create scripts/schedule.sh: This script will be a user-friendly wrapper for the macOS at command.  
  2. schedule.sh "2:30 PM" "remind 'Call Mom'" will echo "remind 'Call Mom'" | at 2:30 PM.  
  3. Modify scripts/startday.sh: Add a new "SCHEDULED TASKS" section that runs atq (which lists pending at jobs).  
* **Target Files:**  
  * scripts/schedule.sh (New)  
  * scripts/startday.sh (Modified)

### **\[Blindspot 16\]: "Static" Clipboard Manager**

* **Critique:** clipboard\_manager.sh only loads static text, wasting potential.  
* **Implementation Plan:**  
  1. Modify scripts/clipboard\_manager.sh (load subcommand): If the file being loaded (e.g., \~/.config/dotfiles-data/clipboard\_history/my\_snippet) is *executable* (\[ \-x "$file\_path" \]), the script must *execute it* and pipe its stdout to pbcopy, rather than cat-ing its content.  
  2. Create a dynamic snippet: echo '\#\!/bin/bash\\ngit branch \--show-current' \> \~/.config/dotfiles-data/clipboard\_history/gitbranch && chmod \+x \~/.config/dotfiles-data/clipboard\_history/gitbranch.  
* **Target Files:**  
  * scripts/clipboard\_manager.sh (Modified)

## **Phase 5: Advanced Knowledge & Environment**

### **\[Blindspot 17\]: "How-To" Memory Gap**

* **Critique:** cheatsheet.sh is too generic. A personal, searchable "how-to" wiki for complex workflows is missing.  
* **Implementation Plan:**  
  1. Create scripts/howto.sh: This script will manage text files in \~/.config/dotfiles-data/how-to/.  
  2. Implement howto add \<name\>: Opens \~/.config/dotfiles-data/how-to/\<name\>.txt in $EDITOR.  
  3. Implement howto \<name\>: cats the content of the file.  
  4. Implement howto search \<term\>: greps all files in the how-to directory.  
  5. Add alias: alias howto="howto.sh".  
* **Target Files:**  
  * scripts/howto.sh (New)  
  * zsh/aliases.zsh (Modified)

### **\[Blindspot 18\]: Digital Clutter Anxiety**

* **Critique:** tidy\_downloads.sh is manual. Clutter on \~/Desktop and \~/Downloads builds up, causing stress.  
* **Implementation Plan:**  
  1. Create scripts/review\_clutter.sh: This script will find files in \~/Desktop and \~/Downloads older than 30 days.  
  2. It will loop through each file and interactively prompt the user: (a)rchive, (d)elete, (s)kip?.  
  3. (a) moves to \~/Documents/Archives/YYYY-MM/, (d) runs rm, (s) does nothing.  
* **Target Files:**  
  * scripts/review\_clutter.sh (New)

### **\[Blindspot 19\]: "Magic" Automation Problem**

* **Critique:** As automation increases, the system becomes "magic" and untrustworthy. A lack of transparency is bad for a cognitive support system.  
* **Implementation Plan:**  
  1. Create a central audit log: \~/.config/dotfiles-data/system.log.  
  2. Modify all automated scripts (goodevening.sh task cleanup, startday.sh run, meds.sh remind, blog.sh sync\_tasks) to append a simple, timestamped, human-readable log entry to system.log. (e.g., echo "$(date): goodevening.sh \- Cleaned 3 old tasks." \>\> $SYSTEM\_LOG\_FILE).  
  3. Modify zsh/aliases.zsh: Add alias systemlog="tail \-n 20 \~/.config/dotfiles-data/system.log".  
* **Target Files:**  
  * scripts/goodevening.sh (Modified)  
  * scripts/startday.sh (Modified)  
  * scripts/meds.sh (Modified)  
  * scripts/blog.sh (Modified)  
  * zsh/aliases.zsh (Modified)

### **\[Blindspot 20\]: The VS Code Shell Conflict**

* **Critique:** The system fails in the VS Code terminal because VS Code runs a login shell (.zprofile) while Terminal.app runs an interactive shell (.zshrc), and aliases are in .zshrc.  
* **Implementation Plan:**  
  1. Modify zsh/.zprofile: Add the following line at the *very end* of the file:  
     \# Source the interactive config for login shells to unify environments  
     \[ \-f "$ZDOTDIR/.zshrc" \] && source "$ZDOTDIR/.zshrc"

  2. This makes login shells (like VS Code's) also source the .zshrc file, loading all aliases and functions and unifying the two environments.  
* **Target Files:**  
  * zsh/.zprofile (Modified)