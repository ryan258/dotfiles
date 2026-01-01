# Implementation Plan: 35 Feature Additions to Dotfiles System

**Scope:** Full implementation of all 35 features from `docs/feature-opportunities.md`
**Approach:** Incremental (one feature at a time)
**Testing:** Full BATS test coverage
**AI Integration:** Maximum (15+ features with AI analysis)
**Timeline:** 12-16 weeks (phased delivery)

---

## Executive Summary

This plan implements 35 new productivity features for a dotfiles system designed for users with MS and chronic illness. Features are sequenced to build shared infrastructure first, then incrementally add capabilities while maintaining system stability.

**Key Strategy:**
1. Build 4 shared libraries that multiple features depend on
2. Implement in 6 phases with clear milestones
3. Full BATS test coverage (5+ tests per feature, 90%+ coverage)
4. Seamless integration with existing daily routines
5. Maximum AI leverage using existing dispatcher infrastructure

---

## Phase 0: Pre-Implementation (Week 0)

### Setup Shared Infrastructure

**Goal:** Create foundations that multiple features will use

#### 0.1 Enhanced BATS Testing Framework
**Files to create:**
- `tests/helpers/test_helpers.sh` - Shared test utilities
- `tests/helpers/mock_ai.sh` - Mock AI dispatcher responses
- `tests/helpers/assertions.sh` - Custom BATS assertions

**What it provides:**
- `setup_test_environment()` - Standard test data directory creation
- `teardown_test_environment()` - Cleanup
- `assert_file_contains()` - File content assertions
- `mock_ai_response()` - Simulate AI dispatcher outputs
- `assert_valid_timestamp()` - Date format validation

**Testing:** Self-test the test framework

---

#### 0.2 Shared Library: Time Tracking Core
**File:** `scripts/lib/time_tracking.sh`

**Functions to implement:**
```bash
start_timer <task_id> [task_text]
stop_timer [task_id]
get_active_timer
get_task_time <task_id>
format_duration <seconds>
generate_time_report <start_date> <end_date>
```

**Data format:** `~/.config/dotfiles-data/time_tracking.txt`
```
START|TASK_ID|TASK_TEXT|TIMESTAMP
STOP|TASK_ID|TIMESTAMP
```

**Used by:** F1 (Time Tracking), F27 (Test Run Logger), F28 (Debug Sessions)

**Testing:** `tests/test_time_tracking_lib.sh` (8 tests)

---

#### 0.3 Shared Library: Spoon Budget System
**File:** `scripts/lib/spoon_budget.sh`

**Functions to implement:**
```bash
init_daily_spoons <count>
spend_spoons <count> <activity>
get_remaining_spoons
predict_spoons_for_date <date>
get_spoon_history <days>
calculate_activity_cost <activity_type>
```

**Data format:** `~/.config/dotfiles-data/spoons.txt`
```
BUDGET|DATE|INITIAL_COUNT
SPEND|DATE|TIME|COUNT|ACTIVITY|REMAINING
```

**Used by:** F2 (Spoon Tracker), F4 (Energy-Task Matching), F11 (Good Day Queue), F21 (Streaks)

**Testing:** `tests/test_spoon_budget_lib.sh` (10 tests)

---

#### 0.4 Shared Library: Correlation Engine
**File:** `scripts/lib/correlation_engine.sh`

**Functions to implement:**
```bash
correlate_two_datasets <file1> <file2> <date_field>
find_patterns <data_file> <pattern_type>
predict_value <historical_data> <current_inputs>
calculate_pearson_correlation <dataset1> <dataset2>
generate_insight_text <correlation_data>
```

**Dependencies:** Python3 (for numpy/pandas calculations)

**Used by:** F7 (Symptom Correlation), F17 (Weather), F18 (Sleep), F25 (Medication Effectiveness), F31 (Predictive Energy)

**Testing:** `tests/test_correlation_engine_lib.sh` (12 tests)

---

#### 0.5 Shared Library: Context Capture
**File:** `scripts/lib/context_capture.sh`

**Functions to implement:**
```bash
capture_current_context [name]
restore_context <name>
list_contexts
diff_contexts <name1> <name2>
capture_git_state
capture_open_files
capture_vscode_state
```

**Data format:** `~/.config/dotfiles-data/contexts/<name>/`
```
contexts/
  feature-x/
    git_state.txt
    directory.txt
    tasks.txt
    notes.txt
    timestamp.txt
```

**Used by:** F3 (Context Preservation), F29 (Code Snapshots)

**Testing:** `tests/test_context_capture_lib.sh` (9 tests)

---

## Phase 1: Foundation Features (Weeks 1-3)

### F1: Time Tracking Integration ⭐⭐⭐
**Priority:** Critical (foundation for multiple features)
**Complexity:** Medium
**Estimated time:** 4-5 days

**Files to create/modify:**
- **NEW:** `scripts/time_tracker.sh` (main script, ~250 lines)
- **MODIFY:** `scripts/todo.sh` (add `start`, `stop`, `time` subcommands)
- **MODIFY:** `zsh/aliases.zsh` (add `t-start`, `t-stop`, `t-time` aliases)
- **MODIFY:** `scripts/goodevening.sh` (show time summary)
- **NEW:** `tests/test_time_tracking.sh` (15+ tests)

**Implementation approach:**
1. Use `time_tracking.sh` library for core logic
2. Add subcommands to todo.sh:
   - `todo start 1` → calls `start_timer 1 "task text"`
   - `todo stop` → calls `stop_timer`, shows duration
   - `todo time 1` → shows time spent on task
   - `todo report` → daily/weekly time breakdown
3. Persist active timer to `~/.config/dotfiles-data/.active_timer`
4. Show in `goodevening`: "You spent X hours on Y tasks today"

**Data integration:**
- Correlate with `health energy` ratings
- Include in `standup` output (F6)
- Feed into `pacing alerts` (F9)

**AI integration:**
- `todo time-analyze` → AI analyzes time patterns via dhp-strategy
- "You consistently underestimate coding tasks by 2x"

**Testing strategy:**
- Test start/stop/time commands
- Test concurrent timer detection (error if already running)
- Test report generation
- Test data persistence across sessions
- Mock time functions for deterministic tests

**Success criteria:**
- [ ] Can start/stop timers on tasks
- [ ] Accurate time tracking (tested with known durations)
- [ ] Integrates with goodevening
- [ ] All 15 tests passing
- [ ] AI analysis provides insights

---

### F2: Spoon Theory Tracker ⭐⭐⭐
**Priority:** High (MS-specific power feature)
**Complexity:** Medium
**Estimated time:** 3-4 days

**Files to create/modify:**
- **NEW:** `scripts/spoons.sh` (main script, ~300 lines)
- **MODIFY:** `scripts/startday.sh` (show predicted spoons)
- **MODIFY:** `scripts/goodevening.sh` (show spoon usage)
- **MODIFY:** `zsh/aliases.zsh` (add `spoons` alias)
- **NEW:** `tests/test_spoons.sh` (12+ tests)

**Implementation approach:**
1. Use `spoon_budget.sh` library
2. Commands:
   - `spoons start 12` → Initialize daily budget
   - `spoons spend 3 "Meeting"` → Log expenditure
   - `spoons left` → Show remaining
   - `spoons history` → Last 7 days
   - `spoons predict` → AI predicts tomorrow's budget
3. Auto-init if no budget set for today
4. Warn when < 3 spoons remain

**Data model:**
```
BUDGET|2025-01-15|12
SPEND|2025-01-15|09:30|3|Meeting with team|9
SPEND|2025-01-15|14:00|2|Code review|7
```

**AI integration:**
- `spoons predict` → dhp-strategy analyzes patterns
  - Input: Last 14 days of energy, sleep, tasks, spoon usage
  - Output: "Predicted spoons tomorrow: 8-10. You usually have low energy after intense days like today."

**Testing strategy:**
- Test budget initialization
- Test spending reduces remaining
- Test overdraft warnings
- Test prediction with historical data
- Test correlation with energy levels

**Success criteria:**
- [ ] Can track spoon budget and expenditure
- [ ] Predictions are reasonable (within ±3 of actual)
- [ ] Integrates with startday/goodevening
- [ ] All 12 tests passing

---

### F4: Energy-Task Matching ⭐⭐⭐
**Priority:** High (huge QoL improvement)
**Complexity:** Medium-High
**Estimated time:** 4-5 days

**Files to create/modify:**
- **MODIFY:** `scripts/todo.sh` (add `suggest`, `queue`, `tag` commands)
- **MODIFY:** `scripts/startday.sh` (show energy-matched tasks)
- **MODIFY:** `scripts/health.sh` (read current energy level)
- **NEW:** `tests/test_energy_task_matching.sh` (18+ tests)

**Implementation approach:**
1. Extend todo.txt format: `DATE|TASK_TEXT|ENERGY_TAG`
   - Tags: `low` (1-4), `medium` (5-7), `high` (8-10)
2. Commands:
   - `todo tag 3 low` → Tag task 3 as low-energy
   - `todo queue low` → Show all low-energy tasks
   - `todo queue high` → Show all high-energy tasks
   - `todo suggest` → AI suggests tasks based on current energy
3. Integration:
   - `health energy 4` → auto-run `todo queue low`
   - `startday` → if energy logged today, show matched tasks

**AI integration:**
- `todo suggest` → dhp-strategy analyzes:
  - Current energy level (from health.txt today)
  - Historical completion patterns (which tasks completed at which energy)
  - Task content (keywords suggesting complexity)
  - Output: Ranked list of tasks with rationale

**Testing strategy:**
- Test tagging preserves task data
- Test filtering by energy level
- Test suggestion with mocked energy data
- Test learning from completion patterns

**Success criteria:**
- [ ] Can tag and filter tasks by energy level
- [ ] AI suggestions are contextually appropriate
- [ ] Historical learning improves over time
- [ ] All 18 tests passing

---

### F6: Automated Standup Generator ⭐⭐
**Priority:** Medium (quick win with existing data)
**Complexity:** Low-Medium
**Estimated time:** 2-3 days

**Files to create/modify:**
- **NEW:** `scripts/standup.sh` (main script, ~200 lines)
- **MODIFY:** `zsh/aliases.zsh` (add `standup` alias)
- **NEW:** `tests/test_standup.sh` (10+ tests)

**Implementation approach:**
1. Gather data from existing sources:
   - `todo_done.txt` → Completed tasks
   - `git log` → Commits across repos
   - `journal.txt` → Highlights
   - `health.txt` → Energy level
2. Generate formatted output:
   - Yesterday section (default)
   - Today section (from focus.txt + top 3 tasks)
   - Blockers (from waiting.txt if F5 exists)
3. Format options:
   - `standup` → Plain text
   - `standup --slack` → Slack markdown
   - `standup --email` → Email HTML
   - `standup week` → Weekly summary

**Output example:**
```
📊 STANDUP - 2025-01-15

YESTERDAY:
✅ Completed 3 tasks:
   - Fixed authentication bug
   - Updated documentation
   - Code review for PR #42
📝 5 commits across 2 repos (dotfiles, myapp)
📖 Journal: "Good energy day, productive session"
⚡ Energy: 8/10

TODAY:
🎯 Focus: Finish API refactor
📋 Top 3 tasks:
   1. Complete user endpoint tests
   2. Update API documentation
   3. Deploy to staging
⚡ Current energy: 7/10

BLOCKERS:
⏳ Waiting on PR review from Sarah (2 days)
```

**Testing strategy:**
- Test data aggregation from multiple sources
- Test date range filtering
- Test format conversions (Slack, email)
- Mock git, todo, journal data for deterministic output

**Success criteria:**
- [ ] Generates accurate summaries from real data
- [ ] Multiple format outputs work correctly
- [ ] All 10 tests passing
- [ ] Takes <2 seconds to generate

---

## Phase 2: Workflow Enhancement (Weeks 4-6)

### F3: Context Preservation System ⭐⭐⭐
**Priority:** High (critical for brain fog)
**Complexity:** Medium-High
**Estimated time:** 5-6 days

**Files to create/modify:**
- **NEW:** `scripts/ctx.sh` (main script, ~350 lines)
- **MODIFY:** `scripts/startday.sh` (remind of saved contexts)
- **MODIFY:** `zsh/aliases.zsh` (add `ctx` alias)
- **NEW:** `tests/test_context.sh` (20+ tests)

**Implementation approach:**
1. Use `context_capture.sh` library
2. Capture state from multiple sources:
   - Current directory
   - Git branch + status
   - Active todo items (via todo.sh)
   - Recent journal entries (last 3)
   - Open VS Code workspace (if detectable)
   - tmux/screen session (if running)
3. Commands:
   - `ctx save` → Auto-name from directory
   - `ctx save "feature-x"` → Named save
   - `ctx list` → Show all contexts
   - `ctx load "feature-x"` → Restore state
   - `ctx diff` → Compare current to saved
   - `ctx delete "name"` → Remove context

**Data structure:**
```
~/.config/dotfiles-data/contexts/
  feature-x/
    metadata.txt        (timestamp, directory, branch)
    git_state.txt       (branch, uncommitted changes)
    todos.txt           (active tasks at save time)
    journal.txt         (recent entries)
    notes.txt           (user-added notes)
```

**Testing strategy:**
- Test save captures all data
- Test load restores directory
- Test diff shows changes
- Test delete removes context
- Test handling missing git repos

**Success criteria:**
- [ ] Can save/restore complete work context
- [ ] Restores to correct directory
- [ ] Preserves all captured state
- [ ] All 20 tests passing

---

### F5: Waiting-For Tracker ⭐⭐
**Priority:** Medium
**Complexity:** Low
**Estimated time:** 2-3 days

**Files to create/modify:**
- **NEW:** `scripts/waiting.sh` (main script, ~200 lines)
- **MODIFY:** `scripts/startday.sh` (show overdue items)
- **MODIFY:** `scripts/weekreview.sh` (include waiting items)
- **MODIFY:** `zsh/aliases.zsh` (add `waiting` alias)
- **NEW:** `tests/test_waiting.sh` (12+ tests)

**Implementation approach:**
1. Data format: `~/.config/dotfiles-data/waiting.txt`
```
ITEM|PERSON|DATE_ADDED|DUE_DATE|STATUS
PR review|Sarah|2025-01-10|2025-01-15|pending
```

2. Commands:
   - `waiting "Description" --from "Person" --by YYYY-MM-DD`
   - `waiting list` → Show all pending
   - `waiting check` → Show overdue (past due date)
   - `waiting done 1` → Mark item received
   - `waiting remove 1` → Delete item

**Integration:**
- `startday` → Show items overdue by 2+ days
- `standup` → Include as "Blockers" section
- `weekreview` → Summarize waiting items

**Testing strategy:**
- Test adding items with due dates
- Test overdue detection
- Test completion marking
- Test filtering by person/date

**Success criteria:**
- [ ] Can track blocked work
- [ ] Overdue detection works
- [ ] Integrates with daily routines
- [ ] All 12 tests passing

---

### F12: Task Dependencies ⭐
**Priority:** Low-Medium
**Complexity:** Medium
**Estimated time:** 3-4 days

**Files to create/modify:**
- **MODIFY:** `scripts/todo.sh` (add dependency tracking)
- **NEW:** `~/.config/dotfiles-data/task_deps.txt`
- **NEW:** `tests/test_task_dependencies.sh` (15+ tests)

**Implementation approach:**
1. Data format for dependencies:
```
TASK_ID|DEPENDS_ON_ID
5|3
7|3
```

2. Commands:
   - `todo depends 5 3` → Task 5 depends on task 3
   - `todo ready` → Show tasks with no pending blockers
   - `todo blocked` → Show blocked tasks with reasons
   - `todo deps 5` → Show dependency tree for task 5

3. Logic:
   - When showing tasks, mark blocked items: `[BLOCKED] Task text (waiting on: #3)`
   - When task completed, check for unblocked tasks
   - Prevent circular dependencies

**Testing strategy:**
- Test dependency creation
- Test ready/blocked filtering
- Test circular dependency detection
- Test auto-unblock on completion

**Success criteria:**
- [ ] Can track task dependencies
- [ ] Filtering shows correct actionable tasks
- [ ] Prevents circular deps
- [ ] All 15 tests passing

---

### F13: Idea Incubator ⭐
**Priority:** Low
**Complexity:** Low
**Estimated time:** 2 days

**Files to create/modify:**
- **NEW:** `scripts/idea.sh` (main script, ~150 lines)
- **MODIFY:** `zsh/aliases.zsh` (add `idea` alias)
- **NEW:** `tests/test_idea.sh` (8+ tests)

**Implementation approach:**
1. Data format: `~/.config/dotfiles-data/ideas.txt`
```
DATE|IDEA_TEXT|TAGS
```

2. Commands:
   - `idea "Maybe write about X" --tag blog`
   - `idea list [--tag TAG]`
   - `idea promote 3` → Convert to task via todo.sh
   - `idea search "keyword"`
   - `idea remove 1`

**Testing strategy:**
- Test adding ideas
- Test tagging and filtering
- Test promotion to tasks
- Test search functionality

**Success criteria:**
- [ ] Can capture ideas without task pressure
- [ ] Can convert ideas to tasks
- [ ] All 8 tests passing

---

### F14: Weekly Planning ⭐⭐
**Priority:** Medium
**Complexity:** Medium
**Estimated time:** 3-4 days

**Files to create/modify:**
- **NEW:** `scripts/weekplan.sh` (main script, ~300 lines)
- **MODIFY:** `scripts/weekreview.sh` (link to planning)
- **MODIFY:** `zsh/aliases.zsh` (add `weekplan` alias)
- **NEW:** `tests/test_weekplan.sh` (10+ tests)

**Implementation approach:**
1. Interactive planning session:
   - Show last week's review
   - Estimate available spoons (from F2)
   - Select tasks from backlog
   - Distribute across days
   - Save plan

2. Data format: `~/.config/dotfiles-data/weekplan_YYYY-MM-DD.txt`
```
WEEK_START|2025-01-13
AVAILABLE_SPOONS|60
MONDAY|Task 1|3 spoons
MONDAY|Task 2|2 spoons
TUESDAY|Task 3|4 spoons
```

3. Commands:
   - `weekplan` → Interactive planning
   - `weekplan show` → Show current week plan
   - `weekplan adjust` → Mid-week modifications

**AI integration:**
- AI suggests realistic task distribution based on historical patterns

**Testing strategy:**
- Test plan creation
- Test spoon budget tracking
- Test mid-week adjustments

**Success criteria:**
- [ ] Can plan week with spoon budgeting
- [ ] Shows progress vs plan
- [ ] All 10 tests passing

---

## Phase 3: Health & Recovery (Weeks 7-8)

### F7: Symptom Correlation Engine ⭐⭐⭐
**Priority:** High (MS power feature)
**Complexity:** High
**Estimated time:** 6-7 days

**Files to create/modify:**
- **MODIFY:** `scripts/health.sh` (add correlation commands)
- **NEW:** Python module: `scripts/lib/correlate.py` (statistical analysis)
- **MODIFY:** `scripts/startday.sh` (show insights)
- **NEW:** `tests/test_symptom_correlation.sh` (15+ tests)

**Implementation approach:**
1. Use `correlation_engine.sh` library
2. Commands:
   - `health correlate` → Find all significant patterns
   - `health triggers` → What triggers low energy?
   - `health patterns` → Common symptom combinations
   - `health predict` → Predict tomorrow's energy

3. Data sources:
   - `health.txt` (energy, symptoms)
   - `medications.txt` (adherence)
   - `journal.txt` (mood keywords)
   - `todo_done.txt` (productivity)
   - `spoons.txt` (if F2 exists)
   - External: Weather API (if F17 exists)
   - External: Sleep data (if F18 exists)

4. Analysis types:
   - Temporal: "Brain fog appears 2 days after X"
   - Correlation: "Low energy correlates with <6hr sleep (r=0.87)"
   - Pattern: "Wednesdays average energy 8, Mondays average 4"
   - Prediction: ML model for next-day energy

**AI integration:**
- `health correlate` → dhp-strategy interprets correlations
  - Input: Statistical correlation data
  - Output: "Your energy drops 2 points when temperature is below 40°F. Consider indoor activities on cold days."

**Testing strategy:**
- Test with synthetic datasets
- Test correlation calculation accuracy
- Test prediction with historical data
- Mock external APIs (weather)

**Success criteria:**
- [ ] Finds statistically significant correlations (p < 0.05)
- [ ] Predictions within ±2 points of actual
- [ ] AI generates actionable insights
- [ ] All 15 tests passing

---

### F8: Flare Mode ⭐⭐
**Priority:** Medium (MS-specific)
**Complexity:** Medium
**Estimated time:** 3-4 days

**Files to create/modify:**
- **NEW:** `scripts/flare.sh` (main script, ~200 lines)
- **MODIFY:** `scripts/startday.sh` (flare mode UI)
- **MODIFY:** `scripts/goodevening.sh` (flare tracking)
- **MODIFY:** `scripts/todo.sh` (flare-safe task filtering)
- **NEW:** `tests/test_flare_mode.sh` (12+ tests)

**Implementation approach:**
1. State tracking: `~/.config/dotfiles-data/flare_state.txt`
```
ACTIVE|START_DATE|SEVERITY
```

2. Commands:
   - `flare start [--severity 1-10]`
   - `flare` → Show status and gentle suggestions
   - `flare end` → Exit flare mode

3. Mode behavior changes:
   - `startday` → Minimal output, gentle tone, rest suggestions
   - `todo` → Only show tasks tagged `flare-safe`
   - `todo suggest` → Focus on rest and recovery
   - `goodevening` → "You made it through. This is temporary."

4. Track flare metrics:
   - Duration
   - Severity over time
   - Recovery time after end

**Testing strategy:**
- Test mode activation/deactivation
- Test UI changes in daily routines
- Test flare duration tracking

**Success criteria:**
- [ ] Flare mode changes system behavior
- [ ] Tracks flare patterns for analysis
- [ ] All 12 tests passing

---

### F9: Pacing Alerts ⭐⭐
**Priority:** Medium
**Complexity:** Medium-High
**Estimated time:** 4-5 days

**Files to create/modify:**
- **NEW:** `scripts/pace.sh` (main script, ~250 lines)
- **NEW:** Daemon: `scripts/pace_monitor.sh` (background process)
- **MODIFY:** `zsh/.zprofile` (optional auto-start)
- **NEW:** `tests/test_pacing.sh` (10+ tests)

**Implementation approach:**
1. Monitor activity indicators:
   - Git commits per hour (via `git log --since`)
   - Tasks completed per hour (from time tracking F1)
   - File modifications (via `find`)
   - Optional: Keyboard/typing speed (via macOS accessibility)

2. Commands:
   - `pace watch` → Start monitoring
   - `pace warn` → Show current pace vs. safe threshold
   - `pace history` → See boom-bust patterns
   - `pace stop` → Stop monitoring

3. Alert logic:
   - If activity > 2x average for 2+ hours → Warn
   - Learn personal crash patterns
   - Suggest pre-emptive breaks

**Data format:**
```
ACTIVITY|TIMESTAMP|TYPE|COUNT
ACTIVITY|2025-01-15 14:00|commits|5
ACTIVITY|2025-01-15 14:00|tasks|3
ALERT|2025-01-15 14:30|overexertion|recommended_break
```

**Testing strategy:**
- Test activity detection
- Test threshold calculation
- Test alert triggering
- Mock git/file system data

**Success criteria:**
- [ ] Detects overexertion patterns
- [ ] Alerts before typical crash times
- [ ] All 10 tests passing

---

### F10: Recovery Tracking ⭐⭐
**Priority:** Medium
**Complexity:** Medium
**Estimated time:** 3-4 days

**Files to create/modify:**
- **NEW:** `scripts/recovery.sh` (main script, ~200 lines)
- **MODIFY:** `scripts/health.sh` (integrate recovery data)
- **NEW:** `tests/test_recovery.sh` (10+ tests)

**Implementation approach:**
1. Data format: `~/.config/dotfiles-data/recovery.txt`
```
EVENT|DATE|ACTIVITY|COST|RECOVERY_DAYS
```

2. Commands:
   - `recovery log "3hr meeting" --cost 6`
   - `recovery predict "conference tomorrow"`
   - `recovery history`

3. Learning:
   - Track actual recovery time (when energy returns to baseline)
   - Predict future recovery needs
   - Correlate with activity type

**AI integration:**
- Analyze patterns: "90-minute meetings require 24hr recovery on average"

**Testing strategy:**
- Test logging events
- Test recovery time calculation
- Test prediction accuracy

**Success criteria:**
- [ ] Tracks recovery patterns
- [ ] Predictions improve over time
- [ ] All 10 tests passing

---

### F11: Good Day Task Queue ⭐⭐
**Priority:** Medium
**Complexity:** Low-Medium
**Estimated time:** 2-3 days

**Files to create/modify:**
- **MODIFY:** `scripts/todo.sh` (add queue-for-good-day command)
- **MODIFY:** `scripts/health.sh` (trigger on high energy)
- **NEW:** `tests/test_good_day_queue.sh` (8+ tests)

**Implementation approach:**
1. Extend todo.txt with flag: `DATE|TASK_TEXT|ENERGY_TAG|GOOD_DAY_QUEUE`

2. Commands:
   - `todo queue-for-good-day 5`
   - `todo good-day-queue` → Show all queued
   - When `health energy 9` → Alert: "You have 3 hard tasks queued!"

**Testing strategy:**
- Test queueing tasks
- Test alert triggering
- Test filtering

**Success criteria:**
- [ ] Can queue hard tasks for high-energy days
- [ ] Alerts work on energy logging
- [ ] All 8 tests passing

---

## Phase 4: Medical Management (Weeks 9-10)

### F24: Care Team Notes ⭐⭐
**Priority:** Medium
**Complexity:** Medium
**Estimated time:** 3-4 days

**Files to create/modify:**
- **NEW:** `scripts/provider.sh` (main script, ~250 lines)
- **NEW:** `tests/test_provider.sh` (12+ tests)

**Implementation approach:**
1. Data format: `~/.config/dotfiles-data/providers.txt`
```
PROVIDER|NAME|SPECIALTY|PHONE|EMAIL
NOTE|PROVIDER_NAME|DATE|NOTE_TEXT
```

2. Commands:
   - `provider add "Dr. Smith" "Neurologist" "555-1234"`
   - `provider note "Dr. Smith" "Discussed new treatment"`
   - `provider list`
   - `provider history "Dr. Smith"`
   - `provider export "Dr. Smith"` → For next appointment

**Testing strategy:**
- Test provider management
- Test note tracking
- Test export generation

**Success criteria:**
- [ ] Can track provider interactions
- [ ] Export works for appointments
- [ ] All 12 tests passing

---

### F25: Medication Effectiveness Tracking ⭐⭐
**Priority:** Medium
**Complexity:** Medium
**Estimated time:** 3-4 days

**Files to create/modify:**
- **MODIFY:** `scripts/meds.sh` (add effectiveness tracking)
- **MODIFY:** `scripts/health.sh` (correlate symptoms with meds)
- **NEW:** `tests/test_med_effectiveness.sh` (10+ tests)

**Implementation approach:**
1. Commands:
   - `meds effective "Med Name"` → Symptom correlation
   - `meds side-effects "Med Name" "headache, nausea"`
   - `meds compare` → Before/after analysis

2. Analysis:
   - Symptom frequency before starting medication
   - Symptom frequency after starting
   - Statistical significance (t-test)

**AI integration:**
- Generate plain-language summary for doctor

**Testing strategy:**
- Test with synthetic data
- Test statistical calculations
- Test before/after comparison

**Success criteria:**
- [ ] Shows medication impact on symptoms
- [ ] Statistical analysis is accurate
- [ ] All 10 tests passing

---

### F26: Appointment Prep Automation ⭐⭐
**Priority:** Medium
**Complexity:** Medium
**Estimated time:** 3-4 days

**Files to create/modify:**
- **NEW:** `scripts/appointment.sh` (main script, ~300 lines)
- **NEW:** `tests/test_appointment_prep.sh` (10+ tests)

**Implementation approach:**
1. Commands:
   - `appointment prep "Neurology"`
   - `appointment prep "Neurology" --since "2024-06-01"`

2. Generates summary from:
   - `health.txt` → Symptom frequency, energy trends
   - `medications.txt` → Adherence rates
   - `journal.txt` → Mentions of symptoms/concerns
   - `provider.txt` → Last visit notes

3. Output formats:
   - PDF (via pandoc)
   - Markdown
   - Plain text

**Testing strategy:**
- Test data aggregation
- Test format generation
- Mock external tools (pandoc)

**Success criteria:**
- [ ] Generates comprehensive summaries
- [ ] Multiple output formats work
- [ ] All 10 tests passing

---

## Phase 5: Developer Experience & Gamification (Weeks 11-12)

### F16: Calendar Integration ⭐⭐
**Priority:** Medium
**Complexity:** High
**Estimated time:** 5-6 days

**Files to create/modify:**
- **NEW:** `scripts/cal.sh` (main script, ~400 lines)
- **NEW:** `scripts/lib/calendar_api.sh` (macOS Calendar.app interface)
- **MODIFY:** `scripts/startday.sh` (show today's events)
- **NEW:** `tests/test_calendar.sh` (15+ tests)

**Implementation approach:**
1. Read from macOS Calendar.app:
   - Via AppleScript: `osascript -e 'tell application "Calendar" ...'`
   - Or SQLite: `~/Library/Calendars/Calendar.sqlitedb`

2. Commands:
   - `cal today` → Today's events
   - `cal week` → Week view
   - `cal conflicts` → Tasks vs meetings overlap
   - `cal energy-budget` → Spoon cost of day's meetings

3. Correlation:
   - Meeting load vs energy crashes
   - Meeting type vs recovery time
   - Alert on back-to-back meetings

**Testing strategy:**
- Test AppleScript interface
- Test event parsing
- Test spoon calculation
- Mock calendar data

**Success criteria:**
- [ ] Can read calendar events
- [ ] Integrates with startday
- [ ] Correlates meetings with energy
- [ ] All 15 tests passing

---

### F20: Voice Memo Integration ⭐⭐
**Priority:** Medium
**Complexity:** Medium-High
**Estimated time:** 4-5 days

**Files to create/modify:**
- **NEW:** `scripts/voice.sh` (main script, ~250 lines)
- **NEW:** `scripts/lib/transcribe.sh` (Whisper API wrapper)
- **NEW:** `tests/test_voice.sh` (10+ tests)

**Implementation approach:**
1. Commands:
   - `voice` → Record audio (via `sox` or `ffmpeg`)
   - `voice list` → List all memos
   - `voice transcribe 1` → AI transcribe via Whisper
   - `voice to-journal 1` → Add to journal

2. Storage: `~/.config/dotfiles-data/voice-memos/YYYYMMDD_HHMMSS.m4a`

3. Transcription:
   - OpenAI Whisper API (free tier)
   - Or local Whisper model

**Testing strategy:**
- Test recording (mock audio input)
- Test transcription API
- Test journal integration

**Success criteria:**
- [ ] Can record voice memos
- [ ] Transcription is accurate
- [ ] Integrates with journal
- [ ] All 10 tests passing

---

### F21: Win Streaks ⭐
**Priority:** Low
**Complexity:** Low
**Estimated time:** 2 days

**Files to create/modify:**
- **NEW:** `scripts/streak.sh` (main script, ~150 lines)
- **MODIFY:** `scripts/goodevening.sh` (show streaks)
- **NEW:** `tests/test_streaks.sh` (8+ tests)

**Implementation approach:**
1. Track streaks:
   - Days with ≥1 completed task
   - Days with journal entry
   - Days with energy logged
   - Days with med logged

2. Commands:
   - `streak` → Show current streaks
   - `streak history` → Best streaks

**Testing strategy:**
- Test streak calculation
- Test break detection
- Test historical tracking

**Success criteria:**
- [ ] Tracks multiple streak types
- [ ] Shows in goodevening
- [ ] All 8 tests passing

---

### F22: Achievement System ⭐
**Priority:** Low
**Complexity:** Low-Medium
**Estimated time:** 2-3 days

**Files to create/modify:**
- **NEW:** `scripts/achievements.sh` (main script, ~200 lines)
- **NEW:** `~/.config/dotfiles-data/achievements.txt`
- **MODIFY:** `scripts/goodevening.sh` (check for unlocks)
- **NEW:** `tests/test_achievements.sh` (10+ tests)

**Implementation approach:**
1. Achievement definitions:
```
ACHIEVEMENT|ID|NAME|DESCRIPTION|CRITERIA
UNLOCK|ID|DATE
```

2. Achievements:
   - "First Week Complete" - 7 days of usage
   - "Energy Warrior" - 30 days energy tracking
   - "Productivity Scientist" - 100 tasks with time tracking
   - "Pattern Detective" - Found first correlation

3. Check achievements in `goodevening`, celebrate unlocks

**Testing strategy:**
- Test achievement detection
- Test unlock notifications
- Test progress tracking

**Success criteria:**
- [ ] Achievements unlock correctly
- [ ] Shows in goodevening
- [ ] All 10 tests passing

---

### F27: Test Run Logger ⭐
**Priority:** Low
**Complexity:** Low
**Estimated time:** 2 days

**Files to create/modify:**
- **NEW:** `scripts/testlog.sh` (main script, ~150 lines)
- **NEW:** `tests/test_testlog.sh` (8+ tests)

**Implementation approach:**
1. Commands:
   - `testlog run "npm test"` → Run and log
   - `testlog history`
   - `testlog failures`

2. Data: `~/.config/dotfiles-data/testlog.txt`
```
RUN|TIMESTAMP|COMMAND|EXIT_CODE|DURATION
```

**Testing strategy:**
- Test command execution
- Test logging
- Test failure detection

**Success criteria:**
- [ ] Logs test runs accurately
- [ ] All 8 tests passing

---

### F28: Debug Session Tracker ⭐
**Priority:** Low
**Complexity:** Low
**Estimated time:** 2 days

**Files to create/modify:**
- **NEW:** `scripts/debug.sh` (main script, ~150 lines)
- **NEW:** `tests/test_debug.sh` (8+ tests)

**Implementation approach:**
1. Commands:
   - `debug start "auth bug"`
   - `debug note "Tried X, didn't work"`
   - `debug solved "Issue was Y"`

2. Data: `~/.config/dotfiles-data/debug.txt`
```
SESSION|ID|BUG_NAME|START_TIME
NOTE|SESSION_ID|TIMESTAMP|NOTE_TEXT
SOLVED|SESSION_ID|END_TIME|SOLUTION
```

**Testing strategy:**
- Test session tracking
- Test note logging
- Test time calculation

**Success criteria:**
- [ ] Tracks debug sessions
- [ ] All 8 tests passing

---

## Phase 6: Advanced & Experimental (Weeks 13-16)

### F15: Decision Log ⭐
**Files:** `scripts/decision.sh`, `tests/test_decision.sh`
**Time:** 2-3 days

### F17: Weather Correlation ⭐
**Files:** `scripts/weather.sh`, modify `health.sh`
**Time:** 3-4 days

### F18: Sleep Tracking Integration ⭐
**Files:** `scripts/sleep.sh`, modify `health.sh`
**Time:** 3-4 days

### F19: Screenshot Capture ⭐
**Files:** `scripts/snap.sh`
**Time:** 2 days

### F23: Progress Photos ⭐
**Files:** `scripts/progress.sh`
**Time:** 2 days

### F29: Code Context Capture ⭐
**Files:** `scripts/snapshot.sh`
**Time:** 2-3 days

### F30: AI Accountability Partner ⭐⭐
**Files:** `scripts/ai_checkin.sh`
**Time:** 4-5 days

### F31: Predictive Energy Modeling ⭐⭐⭐
**Files:** Python ML model in `scripts/lib/predict_energy.py`
**Time:** 6-7 days

### F32: Automatic Task Breakdown ⭐⭐
**Files:** Modify `todo.sh`, add AI integration
**Time:** 3-4 days

### F33: Smart Notification Batching ⭐
**Files:** `scripts/notifications.sh`, daemon
**Time:** 4-5 days

### F34: Cognitive Load Scoring ⭐
**Files:** Modify `todo.sh`
**Time:** 2-3 days

### F35: Dopamine Menu ⭐
**Files:** `scripts/dopamine.sh`
**Time:** 2 days

---

## Testing Strategy

### Test Organization

```
tests/
  helpers/
    test_helpers.sh          # Setup/teardown utilities
    mock_ai.sh               # Mock AI dispatcher responses
    assertions.sh            # Custom assertions

  # Core feature tests
  test_time_tracking.sh      # F1 - 15 tests
  test_spoons.sh             # F2 - 12 tests
  test_context.sh            # F3 - 20 tests
  test_energy_task_matching.sh  # F4 - 18 tests
  test_waiting.sh            # F5 - 12 tests
  test_standup.sh            # F6 - 10 tests
  test_symptom_correlation.sh  # F7 - 15 tests
  # ... (one file per feature)

  # Integration tests
  test_daily_integration.sh  # startday/goodevening integration
  test_ai_integration.sh     # AI dispatcher integration
```

### Test Coverage Goals

- **Unit tests:** 90%+ coverage of functions
- **Integration tests:** All daily routine integration points
- **AI tests:** Mock responses, no actual API calls in tests
- **Edge cases:** Empty data, missing files, invalid input

### Running Tests

```bash
# Run all tests
bats tests/

# Run specific feature tests
bats tests/test_spoons.sh

# Run with coverage (if available)
bats --tap tests/ | coverage_tool
```

---

## Integration Points Summary

### Daily Routines

**startday.sh modifications:**
- Show spoon predictions (F2)
- Show energy-matched tasks (F4)
- Show waiting items (F5)
- Remind of saved contexts (F3)
- Show calendar events (F16)
- Flare mode UI (F8)

**goodevening.sh modifications:**
- Show time summary (F1)
- Show spoon analysis (F2)
- Show streaks (F21)
- Check achievements (F22)
- Track recovery (F10)
- Flare mode tracking (F8)

**status.sh modifications:**
- Show active timer (F1)
- Show remaining spoons (F2)
- Show current context (F3)

### Aliases to Add

```bash
# Time tracking
alias t-start='todo start'
alias t-stop='todo stop'
alias t-time='todo time'

# Spoons
alias spoons='spoons.sh'

# Context
alias ctx='ctx.sh'

# Waiting
alias waiting='waiting.sh'

# Standup
alias standup='standup.sh'

# Flare
alias flare='flare.sh'

# Recovery
alias recovery='recovery.sh'

# Calendar
alias cal='cal.sh'

# Voice
alias voice='voice.sh'

# ... (add for all features)
```

### Validation Additions

**dotfiles_check.sh:**
```bash
# Add new scripts to KEY_SCRIPTS array
KEY_SCRIPTS=(
  ...existing...
  "time_tracker.sh"
  "spoons.sh"
  "ctx.sh"
  "waiting.sh"
  # ... (all new scripts)
)
```

**data_validate.sh:**
```bash
# Add new data files to REQUIRED_ITEMS
REQUIRED_ITEMS=(
  ...existing...
  "time_tracking.txt"
  "spoons.txt"
  "waiting.txt"
  # ... (all new data files)
)
```

---

## AI Integration Summary

### Features with AI Analysis (15 total)

| Feature | AI Dispatcher | Analysis Type |
|---------|---------------|---------------|
| F1 - Time Tracking | dhp-strategy | Time pattern analysis |
| F2 - Spoon Tracker | dhp-strategy | Spoon predictions |
| F4 - Energy-Task Matching | dhp-strategy | Task suggestions |
| F6 - Standup Generator | dhp-content | Format standup |
| F7 - Symptom Correlation | dhp-strategy | Interpret correlations |
| F14 - Weekly Planning | dhp-strategy | Realistic distribution |
| F20 - Voice Memos | dhp-tech | Transcription (Whisper) |
| F25 - Med Effectiveness | dhp-strategy | Plain-language summary |
| F30 - AI Accountability | dhp-stoic | Daily check-in |
| F31 - Predictive Energy | ML model | Energy prediction |
| F32 - Task Breakdown | dhp-strategy | Break down tasks |
| F7 - Weather | dhp-strategy | Weather impact |

### AI Infrastructure Additions

**New dispatchers needed:**
- None (use existing dhp-strategy, dhp-content, dhp-tech, dhp-stoic)

**Mock AI responses for testing:**
```bash
# tests/helpers/mock_ai.sh
mock_ai_response() {
    local dispatcher="$1"
    local input="$2"

    case "$dispatcher" in
        strategy)
            echo "Mocked strategic insight based on: $input"
            ;;
        content)
            echo "Mocked content output"
            ;;
    esac
}
```

---

## Risk Mitigation

### High-Risk Features

| Feature | Risk | Mitigation |
|---------|------|------------|
| F3 - Context Preservation | Data loss on restore | Backup before restore, test extensively |
| F7 - Symptom Correlation | False correlations | Require p < 0.05, show confidence |
| F9 - Pacing Alerts | Battery drain from monitoring | Optional feature, efficient polling |
| F16 - Calendar Integration | Privacy concerns | Read-only, no write access |
| F20 - Voice Memos | Transcription costs | Free tier limits, local Whisper option |
| F31 - Predictive Energy | Inaccurate predictions | Show confidence intervals, learn over time |

### Rollback Strategy

For each feature:
1. Feature flags in .env: `FEATURE_NAME_ENABLED=false`
2. Graceful degradation if disabled
3. Easy removal: delete script, remove alias, remove validation check

---

## Success Metrics

### Per-Feature Metrics

- [ ] All BATS tests passing (5+ per feature)
- [ ] No errors in `dotfiles-check`
- [ ] Integration with daily routines working
- [ ] AI integration functional (if applicable)
- [ ] Documentation in `docs/discover.md` updated

### Overall Project Metrics

- [ ] 35/35 features implemented
- [ ] 400+ total tests passing
- [ ] 90%+ test coverage
- [ ] Zero regression in existing features
- [ ] All features documented

---

## Dependencies & Prerequisites

### System Dependencies

Already installed:
- bash, zsh
- jq, curl, gawk
- python3
- git

New dependencies needed:
- `sox` or `ffmpeg` (for F20 voice recording)
- `pandoc` (for F26 PDF generation)
- `python3-numpy` `python3-pandas` (for F7 correlation analysis)

Install command:
```bash
brew install sox pandoc
pip3 install numpy pandas scikit-learn
```

### External APIs

- **OpenRouter API** (existing) - For AI dispatchers
- **OpenAI Whisper API** (new) - For F20 voice transcription
- **Weather API** (new, optional) - For F17 weather correlation

---

## Timeline & Milestones

### Phase 0: Pre-Implementation (Week 0)
**Milestone:** Shared libraries and test framework ready

### Phase 1: Foundation (Weeks 1-3)
**Milestone:** Time tracking, spoons, energy-task matching, standup working

### Phase 2: Workflow (Weeks 4-6)
**Milestone:** Context preservation, waiting-for, dependencies, ideas, planning working

### Phase 3: Health (Weeks 7-8)
**Milestone:** Symptom correlation, flare mode, pacing, recovery working

### Phase 4: Medical (Weeks 9-10)
**Milestone:** Care team, med effectiveness, appointment prep working

### Phase 5: Dev & Gamification (Weeks 11-12)
**Milestone:** Calendar, voice, streaks, achievements, test/debug logging working

### Phase 6: Advanced (Weeks 13-16)
**Milestone:** All 35 features complete, documented, tested

---

## Next Steps to Begin Implementation

1. **Review this plan** - Confirm approach and priorities
2. **Set up Phase 0** - Build shared libraries and test framework
3. **Implement F1** - Time tracking (first feature)
4. **Iterate** - One feature at a time, test, integrate, document
5. **Maintain quality** - Full tests for each feature before moving to next

---

## Notes

- This is an **incremental plan** - each feature can be implemented independently
- **Test coverage is mandatory** - No feature ships without tests
- **Daily routines stay stable** - Features integrate without breaking existing workflows
- **AI integration is extensive** - 15+ features use AI for insights
- **Designed for MS** - Brain-fog-friendly, energy-aware, recovery-focused

**Estimated total time:** 12-16 weeks (60-80 working days) for all 35 features

---

*Note: User requested plan in `ft-add.md` in project root. This plan is in the system-designated location. After exiting plan mode, this can be copied to `ft-add.md` if desired.*
