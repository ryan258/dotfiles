# Feature Opportunities
## Brilliant Additions You Haven't Built Yet

Based on deep analysis of your existing system, here are high-impact features that would naturally extend what you already have.

---

## 🎯 **Tier 1: Natural Extensions (Highest Impact)**

These build directly on existing features and fill obvious gaps.

### 1. **Time Tracking Integration** ⭐⭐⭐

**What you have:** Energy tracking, task completion
**What's missing:** Actual time spent

**Proposed commands:**
```bash
todo start 1           # Start timer on task 1
todo stop              # Stop current timer
todo time 1            # Show time spent on task 1
todo report            # Time summary by task/day/week
```

**Why it matters:**
- Learn how long tasks actually take vs. estimated
- Correlate time spent with energy drain
- Better planning for low-energy days
- Show yourself you accomplished more than you think

**Integration points:**
- Add to `todo.txt` format: `YYYY-MM-DD|task|time_spent_minutes`
- Include in `goodevening` wins celebration
- Correlate with `health energy` in dashboards
- AI analysis: "You spent 3 hours on coding and rated energy 4. Pattern: coding drains you."

---

### 2. **Spoon Theory Tracker** ⭐⭐⭐

**What you have:** Energy levels (1-10)
**What's missing:** Spoon budgeting and allocation

**Proposed commands:**
```bash
spoons start 12        # Start day with 12 spoons
spoons spend 3 "Meeting"  # Log spoon cost
spoons left            # How many remaining?
spoons history         # See spending patterns
spoons predict         # AI predicts tomorrow's spoons
```

**Why it matters:**
- Better metaphor than 1-10 for many people with chronic illness
- Plan your day based on available spoons
- Learn true cost of activities
- Prevent over-commitment

**Integration points:**
- Show in `startday`: "You have ~10 spoons today (based on recent patterns)"
- Alert in `status` if running low
- Track spoon costs by activity type
- AI learns: "Meetings cost you 4 spoons on average"

---

### 3. **Context Preservation System** ⭐⭐⭐

**What you have:** Directory navigation, task lists
**What's missing:** Full context capture when brain fog hits

**Proposed commands:**
```bash
ctx save               # Save current state (tabs, windows, todos, notes)
ctx save "feature-x"   # Named context
ctx list               # All saved contexts
ctx load "feature-x"   # Restore everything
ctx diff               # What changed since save?
```

**Why it matters:**
- Brain fog strikes mid-task - save everything instantly
- Context switching is expensive - preserve state
- Return to work after doctor appointment - restore exactly where you were
- Never lose your place

**Implementation ideas:**
- Save: open tabs (if using terminal multiplexer), current directory, recent git commits, active todos, journal entry
- Could integrate with tmux/screen sessions
- VS Code workspace state
- Browser tabs (via AppleScript)

---

### 4. **Energy-Task Matching** ⭐⭐⭐

**What you have:** Energy tracking, task list
**What's missing:** AI recommendations based on current energy

**Proposed commands:**
```bash
todo suggest           # AI suggests tasks for current energy level
todo queue low         # Show pre-tagged easy tasks
todo queue high        # Show pre-tagged hard tasks
todo tag 3 low         # Tag task 3 as low-energy
```

**Why it matters:**
- Stop staring at 30 tasks wondering what you can handle
- Pre-tag tasks when you're clear-headed
- AI learns: "You complete documentation on low-energy days"
- Maximize output even on bad days

**Integration points:**
- `startday` shows energy level and suggests matching tasks
- `health energy 4` auto-suggests low-energy tasks
- Track which tasks get done at which energy levels
- AI analysis: "Code reviews require energy 7+, documentation works at 4+"

---

### 5. **Waiting-For Tracker** ⭐⭐

**What you have:** Task list
**What's missing:** Blocked/waiting tasks

**Proposed commands:**
```bash
waiting "PR review from Sarah"
waiting "Doctor callback" --by 2025-01-15
waiting list
waiting check          # Show overdue items
waiting done 1         # Mark received
```

**Why it matters:**
- Tasks blocked on others clutter your todo
- Easy to forget you're waiting on someone
- Reduces mental load of tracking dependencies
- Shows you're productive even when output is low (it's not you, you're waiting)

**Integration points:**
- Separate file: `~/.config/dotfiles-data/waiting.txt`
- Show in `startday` if items overdue
- Auto-remind weekly in `weekreview`
- AI can draft follow-up messages

---

### 6. **Automated Standup Generator** ⭐⭐

**What you have:** Git commits, completed tasks, journal
**What's missing:** Easy work summary generation

**Proposed commands:**
```bash
standup                # Generate yesterday/today summary
standup week           # Weekly summary
standup --slack        # Format for Slack
standup --email        # Email format
```

**Why it matters:**
- Writing updates is cognitive overhead
- You forget what you accomplished
- System has all the data already
- One command generates professional summary

**Output example:**
```
Yesterday:
- Completed tasks: Fixed auth bug, Updated docs (2 tasks)
- Commits: 5 commits across 3 repos
- Blog: Published "Managing Energy with MS"

Today:
- Focus: Finish API refactor
- Top 3 tasks: [from todo top]
- Energy level: 7/10
```

---

## 🧠 **Tier 2: MS-Specific Power Features**

These directly address chronic illness challenges.

### 7. **Symptom Correlation Engine** ⭐⭐⭐

**What you have:** Symptom logging, energy tracking
**What's missing:** Pattern detection and trigger identification

**Proposed commands:**
```bash
health correlate       # Find patterns
health triggers        # What triggers low energy?
health patterns        # Common symptom combinations
health predict         # Predict tomorrow based on today's inputs
```

**Why it matters:**
- Find triggers you can't see manually
- Data-driven symptom management
- Predict flares before they happen
- Share insights with doctors

**Analysis examples:**
- "Low energy correlates with <6 hours sleep 87% of time"
- "Brain fog appears 2 days after high-stress meetings"
- "Weather below 40°F increases fatigue mentions by 3x"
- "Your energy averages 8 on Wednesdays, 4 on Mondays"

**Data sources:**
- `health.txt` (symptoms, energy)
- `medications.txt` (adherence)
- `journal.txt` (mood mentions)
- `todo_done.txt` (productivity)
- External: Weather API, calendar events

---

### 8. **Flare Mode** ⭐⭐

**What you have:** Energy tracking
**What's missing:** Special mode for really bad days

**Proposed commands:**
```bash
flare start            # Enter flare mode
flare                  # Status and suggestions
flare end              # Exit flare mode
```

**When in flare mode:**
- `startday` shows minimal output, gentle messages
- `todo` only shows pre-tagged "flare-safe" tasks
- AI suggestions focus on rest and recovery
- Auto-suggests: journal symptoms, log energy, rest activities
- Celebrates even tiny wins
- `goodevening` reminds you this is temporary

**Why it matters:**
- Bad days need different tools
- Reduces shame/guilt on flare days
- Tracks flare duration and recovery patterns
- Data for doctor appointments

---

### 9. **Pacing Alerts** ⭐⭐

**What you have:** Break reminders
**What's missing:** Activity pacing warnings

**Proposed commands:**
```bash
pace watch             # Monitor activity level
pace warn              # Get alert when overdoing it
pace history           # See pacing patterns
```

**How it works:**
- Tracks git commits/hour, tasks completed/hour, typing speed
- Warns: "You've been going hard for 2 hours. Classic crash pattern. Take a break?"
- Learns your crash patterns
- Suggests pre-emptive breaks

**Why it matters:**
- Boom-bust cycle is real
- Hard to notice you're overdoing it in the moment
- Prevention better than recovery
- Tracks "productive" vs "sustainable" pace

---

### 10. **Recovery Tracking** ⭐⭐

**What you have:** Energy levels
**What's missing:** Recovery time after activities

**Proposed commands:**
```bash
recovery log "3 hour meeting" --cost 6    # Log energy-expensive activity
recovery predict "conference tomorrow"    # How long to recover?
recovery history                          # Past recovery times
```

**Why it matters:**
- Learn true cost of activities
- Plan recovery time
- Explain to others why you need rest
- Data for pacing decisions

**Analysis:**
- "90-minute meetings require 24 hours recovery"
- "Social events cost 2x more spoons than expected"
- "You need 2 rest days after conferences"

---

### 11. **Good Day Task Queue** ⭐⭐

**What you have:** Task prioritization
**What's missing:** Strategic task queuing for energy fluctuations

**Proposed commands:**
```bash
todo queue-for-good-day 5     # Save task 5 for high energy
todo good-day-queue           # Show all queued tasks
health energy 9 && todo suggest-from-good-day-queue
```

**Why it matters:**
- Don't waste high-energy days on low-energy tasks
- Capture hard tasks when you think of them, do them when able
- AI alerts: "Your energy is 9 - rare! You have 3 hard tasks queued."

---

## 📊 **Tier 3: Productivity Enhancements**

### 12. **Task Dependencies** ⭐

**What you have:** Task list
**What's missing:** "Can't do X until Y is done"

**Proposed commands:**
```bash
todo depends 5 3       # Task 5 depends on task 3
todo ready             # Show tasks with no blockers
todo blocked           # Show blocked tasks
```

**Why it matters:**
- See what's actually actionable
- Automatic reordering when blockers complete
- Prevents starting impossible tasks

---

### 13. **Idea Incubator** ⭐

**What you have:** Tasks, journal
**What's missing:** Space for ideas that aren't ready to be tasks

**Proposed commands:**
```bash
idea "Maybe write about X"
idea list
idea promote 3         # Convert idea 3 to task
idea search "keyword"
```

**Why it matters:**
- Ideas that aren't ready clutter todo
- Need space for "someday/maybe"
- Reduces pressure to act immediately
- Can review during weekly planning

---

### 14. **Weekly Planning** ⭐

**What you have:** Weekly review (looking back)
**What's missing:** Weekly planning (looking forward)

**Proposed commands:**
```bash
weekplan               # Interactive planning session
weekplan show          # Show this week's plan
weekplan adjust        # Mid-week adjustments
```

**Workflow:**
1. Review last week's data
2. Check upcoming calendar (if integrated)
3. Estimate available spoons
4. Select tasks for the week
5. Distribute across days
6. Save plan, check progress mid-week

---

### 15. **Decision Log** ⭐

**What you have:** Journal
**What's missing:** Structured decision tracking

**Proposed commands:**
```bash
decision "Chose React over Vue" --reason "Team expertise" --tags "tech-stack"
decision list
decision search "react"
decision review        # Review past decisions
```

**Why it matters:**
- Remember why you made choices
- Learn from past decisions
- Share context with future you
- Prevent re-deciding the same thing

---

## 🔗 **Tier 4: Integration Opportunities**

### 16. **Calendar Integration** ⭐⭐

**What you have:** Standalone productivity system
**What's missing:** Awareness of calendar events

**Proposed commands:**
```bash
cal today              # Today's events
cal week               # Week view
cal conflicts          # Tasks vs meetings
cal energy-budget      # Spoon cost of today's calendar
```

**Integration points:**
- `startday` shows meetings for today
- Warn about back-to-back meetings
- Block time for tasks
- Correlate meeting load with energy crashes

**macOS implementation:**
- Read from Calendar.app via AppleScript or SQLite
- Could also integrate with Google Calendar API

---

### 17. **Weather Correlation** ⭐

**What you have:** Symptom tracking
**What's missing:** Weather data

**Implementation:**
- Auto-fetch daily weather via API
- Store in health.txt format
- Correlate with energy/symptoms
- Show in `health correlate`

**Insights:**
- "Your energy drops 2 points when temp < 40°F"
- "Barometric pressure changes correlate with headaches"

---

### 18. **Sleep Tracking Integration** ⭐

**What you have:** Energy tracking
**What's missing:** Sleep data

**Proposed commands:**
```bash
sleep log 7.5          # Log hours slept
sleep quality 6        # Rate 1-10
sleep correlate        # Sleep vs energy analysis
```

**Or integrate with:**
- Apple Health data
- Oura ring
- Other wearables

**Why it matters:**
- Sleep massively affects energy
- Most obvious correlation to track
- Prove to yourself rest matters

---

### 19. **Screenshot Capture & Annotation** ⭐

**What you have:** Text-based notes
**What's missing:** Visual capture

**Proposed commands:**
```bash
snap                   # Take screenshot, auto-save with timestamp
snap annotate          # Open last screenshot in Preview
snap to-journal        # Add screenshot path to journal
snap gallery           # View all captured screens
```

**Why it matters:**
- Some things are visual
- Error messages, UI bugs, design ideas
- Faster than describing in text
- Low cognitive load capture

---

### 20. **Voice Memo Integration** ⭐⭐

**What you have:** Text-based journal
**What's missing:** Voice capture for when typing is too hard

**Proposed commands:**
```bash
voice                  # Record voice memo
voice list             # List all memos
voice transcribe 1     # AI transcribe to text
voice to-journal 1     # Add transcription to journal
```

**Why it matters:**
- Typing can be hard on bad days
- Hands-free capture while resting
- Faster thought capture
- Accessibility win

**Implementation:**
- macOS: Use `sox` or `ffmpeg` to record
- Transcription: Whisper API (OpenAI) or local Whisper model
- Auto-save to `~/.config/dotfiles-data/voice-memos/`

---

## 🎮 **Tier 5: Gamification & Motivation**

### 21. **Win Streaks** ⭐

**What you have:** Task completion celebration
**What's missing:** Streak tracking

**Proposed commands:**
```bash
streak                 # Show current streaks
streak history         # Best streaks
```

**Tracked streaks:**
- Days with at least 1 completed task
- Days with journal entry
- Days with energy logged
- Days with medication logged
- Current focus streak

**Why it matters:**
- Positive reinforcement
- Visual progress
- Gentle accountability
- Celebrate consistency, not intensity

---

### 22. **Achievement System** ⭐

**Examples:**
- "First Week Complete" - 7 days of using the system
- "Energy Warrior" - 30 days of energy tracking
- "Productivity Scientist" - 100 tasks completed with time tracking
- "Self-Care Champion" - Logged rest on a high-energy day
- "Pattern Detective" - Found your first correlation

**Why it matters:**
- Fun!
- Encourages exploration
- Celebrates milestones
- Positive reinforcement for good habits

---

### 23. **Progress Photos** ⭐

**What you have:** Git commits, task completion
**What's missing:** Visual project progress

**Proposed commands:**
```bash
progress photo "Kitchen renovation"
progress show "Kitchen renovation"
progress gallery
```

**Why it matters:**
- Visual proof of progress
- Great for physical projects
- Memory issues - photos help
- Motivating on low days

---

## 🏥 **Tier 6: Medical Management**

### 24. **Care Team Notes** ⭐⭐

**What you have:** Health tracking
**What's missing:** Provider-specific notes

**Proposed commands:**
```bash
provider add "Dr. Smith" "Neurologist"
provider note "Dr. Smith" "Discussed new treatment option"
provider list
provider history "Dr. Smith"
provider export "Dr. Smith"  # For next appointment
```

**Why it matters:**
- Track provider recommendations
- Remember what each doctor said
- Continuity between appointments
- Share with other providers

---

### 25. **Medication Effectiveness Tracking** ⭐⭐

**What you have:** Medication logging
**What's missing:** Effectiveness analysis

**Proposed commands:**
```bash
meds effective "Med Name"  # Symptom correlation
meds side-effects "Med Name" "headache, nausea"
meds compare               # Before/after starting med
```

**Analysis:**
- Symptom frequency before/after starting medication
- Energy levels correlation
- Side effect patterns
- Data for doctor discussions

---

### 26. **Appointment Prep Automation** ⭐⭐

**What you have:** Health data
**What's missing:** Automated appointment summaries

**Proposed commands:**
```bash
appointment prep "Neurology"
appointment prep "Neurology" --since "2024-06-01"
```

**Generates:**
- Symptom summary (frequency, severity)
- Medication adherence
- Energy trends
- New symptoms
- Questions to ask (from journal mentions)
- Changes since last visit

**Output formats:**
- PDF for printing
- Markdown for email
- Plain text for copying

---

## 🛠 **Tier 7: Developer Experience**

### 27. **Test Run Logger** ⭐

**What you have:** Git commits
**What's missing:** Test/build tracking

**Proposed commands:**
```bash
testlog run "npm test"       # Run and log result
testlog history              # All test runs
testlog failures             # Recent failures
testlog time                 # Time spent debugging
```

**Why it matters:**
- Track debugging time (often invisible work)
- Show yourself you're productive even if no commits
- Correlate failed tests with energy levels
- Data for estimations

---

### 28. **Debug Session Tracker** ⭐

**What you have:** Task time tracking (proposed)
**What's missing:** Debugging-specific tracking

**Proposed commands:**
```bash
debug start "auth bug"
debug note "Tried X, didn't work"
debug solved "Issue was Y"
debug time                   # Total debug time today
```

**Why it matters:**
- Debugging is invisible work
- Learn how long bugs actually take
- Journal of what you tried
- Prevent re-trying failed solutions

---

### 29. **Code Context Capture** ⭐

**What you have:** Git diff
**What's missing:** Before/after code snapshots

**Proposed commands:**
```bash
snapshot "Refactoring auth"  # Save current state
snapshot list
snapshot diff "Refactoring auth"
snapshot restore "Refactoring auth"
```

**Why it matters:**
- Safe experimentation
- Quick rollback
- Compare approaches
- Memory aid for what you tried

---

## 🎯 **Implementation Priority Recommendation**

Based on impact vs. effort:

### Start Next Week (Highest ROI):
1. **Energy-Task Matching** - Huge quality of life, builds on existing
2. **Time Tracking Integration** - Natural todo extension
3. **Spoon Theory Tracker** - Better than 1-10 for many people
4. **Context Preservation** - Critical for brain fog
5. **Automated Standup** - Almost trivial with existing data

### Month 1:
6. **Symptom Correlation Engine** - High value, moderate effort
7. **Waiting-For Tracker** - Easy win
8. **Calendar Integration** - Big impact
9. **Flare Mode** - MS-specific power feature
10. **Weekly Planning** - Natural weekreview extension

### Month 2:
11. Voice Memo Integration
12. Sleep Tracking
13. Care Team Notes
14. Pacing Alerts
15. Win Streaks

### Backlog:
- Everything else based on personal need

---

## 🤔 **Questions to Consider**

### For Each Feature:
1. **Does it reduce cognitive load or add to it?**
2. **Is it useful on a 3-energy day, or only on 9-energy days?**
3. **Does it provide insights I can't get manually?**
4. **Does it automate something I'm already doing manually?**
5. **Will I actually use it?**

### Your System Philosophy:
- ✅ Minimum keystrokes
- ✅ Brain-fog friendly
- ✅ Data-driven insights
- ✅ Forgiving and recoverable
- ✅ Transparent automation
- ❌ Complex configuration
- ❌ Requires daily maintenance
- ❌ Only useful on high-energy days

---

## 💡 **Wild Ideas (Experimental)**

### 30. **AI Accountability Partner**
Daily check-in with AI that knows your patterns, asks how you're doing, suggests adjustments.

### 31. **Predictive Energy Modeling**
ML model trained on your data to predict tomorrow's energy based on today's inputs.

### 32. **Automatic Task Breakdown**
AI breaks large tasks into tiny sub-tasks automatically.

### 33. **Smart Notification Batching**
Instead of interrupting all day, batch notifications for designated check-in times.

### 34. **Cognitive Load Scoring**
Rate tasks by cognitive load, match to current capacity.

### 35. **Dopamine Menu**
Pre-curated list of activities by energy level and desired feeling state.

---

## 🎯 **Your Call**

Which of these resonates? Want me to:
1. **Implement** any specific feature?
2. **Design** detailed spec for one?
3. **Prototype** a proof-of-concept?
4. **Prioritize** based on your specific needs?

**You've built an incredible foundation. These are the natural next steps.** 🚀
