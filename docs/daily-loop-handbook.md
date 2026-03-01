# Daily Loop Handbook

This guide walks you through the core daily usage of your dotfiles system. It combines the structured instructions from the "Happy Path" with the quick-reference elements from your daily cheat sheet. Follow this loop to maintain context, focus, and energy throughout your day.

---

## 🌅 Morning Flow (Low-Friction Start)

**Command:**

```bash
startday
```

`startday` sets the tone for your day and runs automatically on the first terminal open of the day. It walks you through:

- **Focus Check:** Reviewing or setting your daily intention.
- **Spoon Budget:** Acknowledging your starting energy capacity.
- **Context Recovery:** Surfacing yesterday's journal, commits, and stale tasks.
- **AI Briefing:** Providing a structured, deterministic coaching plan.

### Morning Coaching Schema

- `North Star`
- `Do Next` (ordered 1-3)
- `Operating Insight` (working + drift risk)
- `Anti-tinker Rule`
- `Health Lens`
- `Evidence Check`

### Refresh Modes

If you need to recalculate your briefing:

```bash
startday refresh                   # Clears AI briefing cache only
startday refresh --clear-github-cache # Clears AI + GitHub caches
```

### Essential Morning Tasks

| Command                      | What It Does                                  |
| ---------------------------- | --------------------------------------------- |
| `focus set "my thing today"` | Set your daily intention                      |
| `spoons init 10`             | Start the daily energy budget                 |
| `health check`               | Check if you are OK to work (circuit breaker) |
| `todo top`                   | View only the top 3 tasks                     |
| `g suggest`                  | AI suggests where you should work today       |
| `gcal agenda 7`              | View your week's calendar                     |

---

## ☀️ During-Day Flow (Stay On Rails)

When you're working, use a tight loop to avoid distraction and maintain momentum.

**Core Loop:**

```bash
todo top
status
journal add "what I just did + what's next"
health energy 6
health fog 4
```

### The Cadence

1. **Before switching tasks:** Log one sentence in your journal (`ja "thought"`).
2. **If fog rises or energy drops:** Shorten your current work block and re-check `todo top`.
3. **If you catch yourself tinkering:** Return to the `North Star` from `startday` and only do step 1.

### Task Management

| Command                       | What It Does                                 |
| ----------------------------- | -------------------------------------------- |
| `todo add "task description"` | Add a task                                   |
| `todo rm 1`                   | Delete task 1 (without saving it to history) |
| `todo done 1`                 | Mark task 1 complete                         |
| `todo bump 5`                 | Move task 5 to the top of your list          |
| `idea add "idea description"` | Capture a new aspirational idea              |
| `idea to-todo 1`              | Promote idea 1 to the todo list              |
| `todo to-idea 1`              | Demote task 1 back to the idea list          |
| `t-start 1` / `t-stop`        | Start/stop a timer for task 1                |
| `todo debug 2`                | Get AI help with task 2                      |

### Emergency Reset (When You Feel Lost)

If you feel scattered or overwhelmed, run:

```bash
status
todo top
focus show
```

**Then do only ONE thing:**

- Run one 10-15 minute block on your top task.
- Add one journal line when you finish it.

---

## 🌙 Evening Closeout (Preserve Context for Tomorrow)

When you are done for the day, protect tomorrow's mental energy by closing out properly.

**Command:**

```bash
goodevening
```

_(Or `goodevening 2026-01-20` to close out a specific past date)._

`goodevening` preserves today's outcomes, summarizes wins, checks project safety, validates data files, runs a system backup, and generates an AI reflection.

### Evening Coaching Schema

- `What Worked`
- `Where Drift Happened`
- `Likely Trigger`
- `Tomorrow Lock`
- `Health Lens`
- `Evidence Used`

**Your `Tomorrow Lock` should always include:**

- Your first move for tomorrow.
- The "done" condition.
- The anti-tinker boundary.

### End of Day Checklist

```bash
focus done             # Mark today's focus complete and archive it
goodevening            # Receive your coaching reflection & backup data
todo clear             # Clean up completed tasks
gcal agenda 1          # Preview tomorrow's schedule
```

---

## 🔍 Additional Check-Ins

| Command              | What It Does                                        |
| -------------------- | --------------------------------------------------- |
| `status`             | Mid-day context reset: Where am I?                  |
| `weekreview`         | Generate a retrospective summary of the last 7 days |
| `context.sh capture` | Snapshot the current context                        |
| `context.sh list`    | List saved context snapshots                        |
