# System Overview

## How Your Dotfiles System Works

A visual guide to understanding the architecture and data flow.

---

## 🏗 System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         YOUR TERMINAL                            │
│                    (zsh with custom config)                      │
└──────────────────────────┬───────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                       COMMAND LAYER                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   Aliases    │  │   Scripts    │  │      AI      │          │
│  │  (200+ cmds) │  │  (66 files)  │  │ (10 dispatch)│          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└──────────────────────────┬───────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                         DATA LAYER                               │
│              ~/.config/dotfiles-data/                           │
│  • todo.txt, todo_done.txt                                      │
│  • journal.txt                                                   │
│  • health.txt, medications.txt                                  │
│  • dir_bookmarks, dir_history, dir_usage.log                   │
│  • clipboard_history/, how-to/, specs/                         │
│  • system.log, dispatcher_usage.log                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Daily Workflow Loop

```
         🌅 MORNING
           │
           ▼
    ┌─────────────┐
    │  startday   │ ◄── Runs automatically once per day
    └──────┬──────┘
           │
           ├── Shows daily focus
           ├── Yesterday's journal context
           ├── GitHub activity (last 7 days)
           ├── Suggested directories (g suggest)
           ├── Blog status (if configured)
           ├── Health reminders
           ├── Stale tasks (>7 days)
           └── Top 3 priorities

         📝 DURING THE DAY
           │
           ├── todo (add, done, bump, top)
           ├── journal (quick entries)
           ├── dump (long-form journaling)
           ├── g (navigation)
           ├── AI dispatchers (tech, content, stoic, etc.)
           ├── status (check-in)
           └── health/meds tracking

         🌙 EVENING
           │
           ▼
    ┌─────────────┐
    │ goodevening │ ◄── Run manually when done for the day
    └──────┬──────┘
           │
           ├── Celebrate wins (completed tasks, journal entries)
           ├── Project safety checks (uncommitted changes)
           ├── Data validation
           └── Auto-backup to ~/Backups/
```

---

## 📊 Task Management Flow

```
┌──────────────────────────────────────────────────────────────┐
│  todo "Task description"                                      │
└────────────────────┬──────────────────────────────────────────┘
                     │
                     ▼
              ┌────────────┐
              │ todo.txt   │
              └─────┬──────┘
                    │
       ┌────────────┼────────────┐
       ▼            ▼            ▼
  ┌────────┐  ┌─────────┐  ┌──────────┐
  │  todo  │  │todo top │  │todo done │
  │  list  │  │ (top 3) │  │   (1)    │
  └────────┘  └─────────┘  └─────┬────┘
                                  │
                                  ▼
                           ┌──────────────┐
                           │ todo_done.txt│
                           └──────────────┘

Optional:
  todo commit  ──► Git backup
  todo debug   ──► AI analysis
  todo delegate ──► AI dispatcher
  todo undo    ──► Restore last action
```

---

## 🤖 AI Integration Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    YOUR QUESTION/INPUT                       │
└────────────────────┬─────────────────────────────────────────┘
                     │
          ┌──────────┼──────────┐
          ▼          ▼          ▼
    ┌─────────┐ ┌────────┐ ┌─────────┐
    │  Direct │ │  Spec  │ │   AI    │
    │  Input  │ │Template│ │ Suggest │
    └────┬────┘ └───┬────┘ └────┬────┘
         │          │           │
         └──────────┼───────────┘
                    ▼
         ┌──────────────────────┐
         │  Dispatcher Layer    │
         │  (Swarm Orchestration)│
         └──────────┬───────────┘
                    │
      ┌─────────────┼─────────────┐
      ▼             ▼             ▼
  ┌──────┐    ┌──────────┐   ┌────────┐
  │ tech │    │  content │   │ stoic  │
  └──────┘    └──────────┘   └────────┘
                    │
                    ▼
           ┌──────────────────┐
           │   Swarm Engine   │
           │ (Chief of Staff) │
           └────────┬─────────┘
                    │
           ┌────────┴─────────┐
           ▼                  ▼
  ┌────────────────┐  ┌────────────────┐
  │ Task Analyzer  │  │ Capability Idx │
  └────────────────┘  └────────────────┘
           │                  │
           ▼                  ▼
  ┌────────────────────────────────────┐
  │          Parallel Execution         │
  │     (68 Specialists / 7 Depts)     │
  └─────────────────┬──────────────────┘
                    │
                    ▼
           ┌─────────────────┐
           │   AI Response   │
           └────────┬────────┘
                    │
                    ├── Display to terminal
                    └── Save to ~/Documents/AI_Staff_HQ_Outputs/ (default)

Advanced Features:
  dhp-chain    ──► Sequential processing through multiple AIs
  dhp-project  ──► 5-specialist orchestration (market→brand→strategy→content→copy)
  --context    ──► Inject recent journal + todos
  --full-context ──► Inject git status + README + todos + journal
```

---

## 🧭 Navigation System

```
┌─────────────────────────────────────────────────────────────┐
│  Every 'cd' is logged to dir_usage.log                      │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
              ┌──────────────┐
              │ dir_usage.log│
              │ (timestamp:path)
              └──────┬───────┘
                     │
          ┌──────────┼──────────┐
          ▼          ▼          ▼
    ┌─────────┐ ┌─────────┐ ┌──────────┐
    │g suggest│ │g recent │ │ startday │
    └─────────┘ └─────────┘ └──────────┘

Smart Scoring Algorithm:
  score = visit_count / (days_since_last_visit + 1)

Bookmarks (saved with 'g save'):
  ┌─────────────────┐
  │ dir_bookmarks   │
  │ name:path:      │
  │ on_enter_cmd:   │
  │ venv_path:apps  │
  └────────┬────────┘
           │
           ▼
    Auto-activates venv
    Launches apps
    Runs on-enter commands
```

---

## 📚 Blog Publishing Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│  Content Ideas                                               │
├──────────────┬────────────────┬──────────────────────────────┤
│ blog ideas   │ journal search │ blog stubs                   │
│ (mine        │ (find topics)  │ (list existing)              │
│  journal)    │                │                              │
└──────┬───────┴────────┬───────┴──────────┬───────────────────┘
       │                │                  │
       └────────────────┼──────────────────┘
                        ▼
              ┌──────────────────┐
              │ blog generate    │
              │ -p persona       │
              │ -s section       │
              └────────┬─────────┘
                       │
                       ├── Loads persona (thoughtful-guide, practical-tip, etc.)
                       ├── Loads section exemplars
                       └── Calls content dispatcher

                       ▼
              ┌──────────────────┐
              │  Draft Created   │
              │  in BLOG_DIR/    │
              └────────┬─────────┘
                       │
                       ▼
              ┌──────────────────┐
              │  blog refine     │
              │  (AI polish)     │
              └────────┬─────────┘
                       │
                       ▼
              ┌──────────────────┐
              │  blog sync       │
              │  (stubs→todos)   │
              └──────────────────┘
```

---

## 🏥 Health Tracking System

```
┌─────────────────────────────────────────────────────────────┐
│  Health Data Collection                                      │
├──────────────┬────────────────┬──────────────────────────────┤
│ health       │ meds log       │ journal entries              │
│ energy 7     │ "Med Name"     │ (symptom mentions)           │
└──────┬───────┴────────┬───────┴──────────┬───────────────────┘
       │                │                  │
       ├────────────────┼──────────────────┤
       ▼                ▼                  ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  health.txt  │ │medications   │ │  journal.txt │
│  (pipe-      │ │  .txt        │ │  (searchable)│
│   delimited) │ │  (pipe-delim)│ │              │
└──────┬───────┘ └──────┬───────┘ └──────┬───────┘
       │                │                │
       └────────────────┼────────────────┘
                        ▼
              ┌──────────────────┐
              │  Analytics       │
              ├──────────────────┤
              │ health dashboard │ ◄── 30-day trends
              │ meds dashboard   │ ◄── Adherence
              │ health summary   │ ◄── Correlations
              │ journal mood     │ ◄── AI sentiment
              └──────────────────┘
                        │
                        ▼
              Energy correlations:
                • Task completion
                • Git commits
                • Symptom patterns
                • Medication adherence
```

---

## 🔒 Data Safety & Backup

```
┌─────────────────────────────────────────────────────────────┐
│  goodevening (evening routine)                               │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
              ┌──────────────────┐
              │  data_validate   │ ◄── Check data integrity
              └────────┬─────────┘
                       │
                 ┌─────┴─────┐
                 │           │
            ✅ Valid    ❌ Invalid
                 │           │
                 │           └── Warning (backup skipped)
                 ▼
              ┌──────────────────┐
              │  backup_data.sh  │
              └────────┬─────────┘
                       │
                       ▼
              ~/Backups/dotfiles_data/
              └── backup_YYYYMMDD_HHMMSS/
                  ├── todo.txt
                  ├── journal.txt
                  ├── health.txt
                  ├── medications.txt
                  ├── dir_bookmarks
                  └── ... (all data files)

Additional Protection:
  • todo commit ──► Git-backed todo list
  • todo undo   ──► Undo last action
  • system.log  ──► Complete audit trail
```

---

## 📁 File Organization

```
~/dotfiles/
├── zsh/                    # Shell configuration
│   ├── .zshrc             # Interactive shell setup
│   ├── .zprofile          # Login shell setup
│   └── aliases.zsh        # 200+ command shortcuts
│
├── scripts/               # Core automation (66 files)
│   ├── todo.sh           # Task management
│   ├── journal.sh        # Journaling system
│   ├── startday.sh       # Morning briefing
│   ├── goodevening.sh    # Evening wrap-up
│   ├── g.sh              # Navigation system
│   ├── blog.sh           # Publishing pipeline
│   ├── health.sh         # Health tracking
│   ├── meds.sh           # Medication management
│   └── ... (48 more)
│
├── bin/                   # AI dispatcher system (23 files)
│   ├── dhp-tech.sh       # Technical AI
│   ├── dhp-content.sh    # Content AI
│   ├── dhp-lib.sh        # Shared API library
│   ├── dhp-utils.sh      # Utility functions
│   └── ... (19 more)
│
├── ai-staff-hq/          # AI specialist definitions (submodule)
│   ├── staff/            # 68 YAML specialist files
│   └── squads.json       # Dispatcher→specialist mapping
│
├── templates/            # Spec-driven workflow templates
│   ├── tech-spec.txt
│   ├── content-spec.txt
│   └── ... (6 more)
│
├── tests/                # BATS test suite
│   ├── test_todo.sh
│   ├── test_ai_suggest.sh
│   └── test_meds.sh
│
├── docs/                 # User documentation
│   ├── discover.md            # Feature discovery guide ⭐ NEW
│   ├── daily-cheatsheet.md    # One-page reference ⭐ NEW
│   ├── ms-friendly-features.md # Accessibility guide ⭐ NEW
│   ├── ai-quick-reference.md  # AI examples ⭐ NEW
│   ├── system-overview.md     # This file ⭐ NEW
│   ├── happy-path.md          # Daily walkthrough
│   ├── best-practices.md
│   ├── clipboard.md
│   └── ... (more guides)
│
├── .env                  # Your private config (gitignored)
├── .env.example          # Template for .env
├── README.md             # Main documentation (27KB)
├── CHANGELOG.md          # Version history (34KB)
├── ROADMAP.md            # Future features
├── SECURITY.md           # Security policy
├── TROUBLESHOOTING.md    # Common issues
└── bootstrap.sh          # Automated setup

~/.config/dotfiles-data/  # Your personal data
├── todo.txt, todo_done.txt
├── journal.txt
├── health.txt, medications.txt
├── dir_bookmarks, dir_history, dir_usage.log
├── daily_focus.txt
├── focus_history.log
├── spoons.txt
├── google_creds.json, google_token_cache.json
├── system.log, dispatcher_usage.log
├── clipboard_history/
├── how-to/
├── specs/
└── cache/

~/Documents/AI_Staff_HQ_Outputs/  # Default AI output folders (override in .env)
```

---

## 🎯 Command Categories

### 🌅 Daily Routines

```
startday        # Morning briefing (auto-runs)
status          # Mid-day check-in
goodevening     # Evening wrap-up + backup
weekreview      # Weekly summary
```

### 📝 Productivity

```
todo            # Task management
journal         # Quick entries
dump            # Long-form journaling
focus           # Daily intention with history
gcal            # Google Calendar integration
```

### 🏥 Health

```
health          # Energy, symptoms, appointments
meds            # Medication tracking
spoons          # Energy budget with history
```

### 🧭 Navigation

```
g               # Bookmarks and suggestions
..              # Up one directory
...             # Up two directories
```

### 🤖 AI Helpers

```
tech            # Technical debugging
content         # Content creation
creative        # Story generation
strategy        # Strategic decisions
stoic           # Mindset coaching
ai-suggest      # Context-aware recommendations
```

### 📚 Content

```
blog            # Publishing pipeline
howto           # Personal wiki
```

### 🔧 Utilities

```
findtext        # Search file contents
findbig         # Largest files
tidydown        # Clean Downloads
clip            # Clipboard manager
remind          # Scheduled reminders
break           # Break timer
```

### 🔍 System

```
dotfiles-check  # System validation
whatis          # Command help
sysinfo         # Hardware info
netinfo         # Network diagnostics
battery         # Battery status
```

---

## 🎓 Learning Path

### Week 1: Core Daily Loop

```
Day 1-2:  Observe startday and goodevening
Day 3-4:  Start using todo (add, done, top)
Day 5-7:  Add journal entries
```

### Week 2: Health Tracking

```
Day 8-10:  Track energy daily (health energy 7)
Day 11-12: Log medications (meds log "Med")
Day 13-14: Review dashboards
```

### Week 3: Navigation

```
Day 15-17: Use g save to bookmark projects
Day 18-19: Try g suggest for smart navigation
Day 20-21: Set up on-enter commands
```

### Week 4: AI Integration

```
Day 22-24: Try one AI (start with stoic or tech)
Day 25-26: Use content with --context flag
Day 27-28: Experiment with ai-suggest
```

### Month 2+: Advanced Features

```
• Set up blog integration
• Create spec templates for common tasks
• Chain AI dispatchers
• Customize workflows
• Explore all 66 scripts
```

---

## 🆘 Common Questions

**Q: Where is my data stored?**
A: `~/.config/dotfiles-data/` - Single source of truth for all personal data.

**Q: Is my data backed up?**
A: Yes, automatically every evening via `goodevening`. Manual backup: `backup-data`.

**Q: How do I check if everything is working?**
A: Run `dotfiles-check` - validates scripts, dependencies, AI dispatchers, and data.

**Q: Which AI should I use?**
A: Run `ai-suggest` for context-aware recommendations based on your current situation.

**Q: I forgot what a command does.**
A: Run `whatis <command>` for documentation.

**Q: How do I customize the system?**
A: Edit `.env` for configuration. See `.env.example` for all options.

**Q: What if I have low energy today?**
A: Use `todo top` (just 3 tasks), `status` (quick check-in), and `focus` (set one intention).

**Q: Can I use this on Linux?**
A: Yes! Most features work cross-platform. Some macOS-specific features (notifications, battery) have Linux alternatives.

---

## 📖 Next Steps

1. **Read the guides:**

   - [Daily Cheat Sheet](daily-cheatsheet.md) - One-page reference
   - [Feature Discovery](discover.md) - What can you do?
   - [MS-Friendly Features](ms-friendly-features.md) - How it helps
   - [AI Quick Reference](ai-quick-reference.md) - Your AI team

2. **Validate your system:**

   ```bash
   dotfiles-check
   ```

3. **Try the daily loop:**

   ```bash
   startday        # Morning
   status          # Mid-day
   goodevening     # Evening
   ```

4. **Explore one category:**

   - Pick something that interests you (health tracking, AI, navigation)
   - Read the relevant section in [discover.md](discover.md)
   - Try 2-3 commands

5. **Ask for help:**
   ```bash
   whatis <command>    # Documentation
   ai-suggest          # What should I do?
   ```

---

**You've built an incredible system. This overview helps you see how all the pieces fit together. Now go discover what it can do for you!** 🚀
