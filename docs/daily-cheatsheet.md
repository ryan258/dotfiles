# Daily Cheat Sheet

## Your One-Page Reference for Brain-Fog Days

---

## 🌅 Morning

| Command                      | What It Does                            |
| ---------------------------- | --------------------------------------- |
| `startday`                   | Morning briefing (auto-runs once daily) |
| `focus set "my thing today"` | Set daily intention                     |
| `focus show`                 | View current focus                      |
| `focus done`                 | Mark focus complete + archive           |
| `focus history`              | View past focus entries                 |
| `focus clear`                | Clear current focus                     |
| `spoons init 12`             | Start daily energy budget               |
| `todo top`                   | See top 3 tasks only                    |
| `g suggest`                  | Where should I work today?              |
| `gcal agenda 7`              | View week's calendar                    |

---

## 📝 Tasks

| Command                       | What It Does            |
| ----------------------------- | ----------------------- |
| `todo add "task description"` | Add a task              |
| `todo`                        | See all tasks           |
| `todo top`                    | Top 3 only              |
| `todo done 1`                 | Mark task 1 complete    |
| `todo rm 1`                   | Delete task 1 (no save) |
| `todo bump 5`                 | Move task 5 to top      |
| `t-start 1`                   | Start timer for task 1  |
| `t-stop`                      | Stop timer              |
| `todo debug 2`                | Get AI help with task 2 |

---

## 💭 Journaling

| Command                    | What It Does                |
| -------------------------- | --------------------------- |
| `journal add "thought"`    | Quick entry                 |
| `ja "thought"`             | Quick entry (alias)         |
| `dump`                     | Free-form editor journaling |
| `journal list`             | See recent entries          |
| `journal search "keyword"` | Find past entries           |

---

## 🏥 Health

| Command                     | What It Does             |
| --------------------------- | ------------------------ |
| `health energy 7`           | Rate energy 1-10         |
| `health symptom "headache"` | Log a symptom            |
| `meds log "Med Name"`       | Log medication dose      |
| `meds check`                | What's due now?          |
| `spoons init 12`            | Start daily spoon budget |
| `spoons spend 2`            | Log spoon usage          |
| `spoons check`              | See remaining spoons     |
| `spoons history`            | View spoon usage history |
| `health dashboard`          | 30-day trends            |

---

## 🧭 Navigation

| Command         | What It Does          |
| --------------- | --------------------- |
| `g`             | Show bookmarks        |
| `g recent`      | Recently visited dirs |
| `g suggest`     | Smart suggestions     |
| `g save myname` | Save this directory   |

---

## 🤖 AI Helpers (All Free)

| Command               | When to Use                |
| --------------------- | -------------------------- |
| `tech "question"`     | Debug code, fix errors     |
| `content "topic"`     | Write blog posts, guides   |
| `creative "idea"`     | Stories, creative projects |
| `strategy "question"` | Big decisions, planning    |
| `stoic "struggle"`    | Mindset, perspective       |
| `morphling "any task"`| Auto-adapts to any need    |
| `ai-suggest`          | Not sure which AI to use?  |

**Pipe code to AI:**

```bash
cat script.sh | tech --stream
```

---

## 📊 Check-Ins

| Command       | What It Does             |
| ------------- | ------------------------ |
| `status`      | Mid-day: where am I?     |
| `goodevening` | Evening wrap-up + backup |
| `weekreview`  | Weekly summary           |

---

## 🔍 Finding Things

| Command             | What It Does           |
| ------------------- | ---------------------- |
| `findtext "search"` | Search file contents   |
| `findbig`           | 10 largest files       |
| `tidydown`          | Clean Downloads folder |

---

## 📚 Blog (if BLOG_DIR set)

| Command                                       | What It Does            |
| --------------------------------------------- | ----------------------- |
| `blog status`                                 | See drafts and stubs    |
| `blog ideas`                                  | Mine journal for topics |
| `blog generate "Title" -p persona -s section` | AI create post          |

**Personas:** `thoughtful-guide`, `practical-tip`, `technical-deep-dive`, `personal-story`

---

## 🛠 Quick Utilities

| Command                 | What It Does           |
| ----------------------- | ---------------------- |
| `break`                 | 15-min break reminder  |
| `pomo`                  | 25-min Pomodoro        |
| `remind +30m "text"`    | Schedule reminder      |
| `did long-command`      | Notify when complete   |
| `clip save name "text"` | Save clipboard snippet |
| `whatis commandname`    | What does this do?     |

---

## 🆘 Overwhelmed?

**When you can't focus:**

```bash
focus "Just one thing"
todo top
```

**When you're stuck:**

```bash
todo debug 1           # AI analyzes task
status                 # Where am I?
dump                   # Brain dump to journal
```

**When you need a reset:**

```bash
break                  # Take 15 minutes
health energy 4        # Log low energy
stoic "I'm struggling" # Get perspective
```

---

## 🌙 End of Day

```bash
focus done             # Mark focus complete + archive to history
goodevening            # Celebrate wins + backup
todo clear             # Clean up completed
gcal agenda 1          # Preview tomorrow's schedule
```

---

## 💡 Remember

✅ Every command is designed for **minimum keystrokes**
✅ All data is **auto-backed up** nightly
✅ AI is **free tier** - use it generously
✅ **No judgment** - low energy days are tracked and normal
✅ Type `whatis <command>` if you forget what something does

---

## 📖 More Help

- `docs/discover.md` - Full feature discovery guide
- `docs/happy-path.md` - Daily workflow walkthrough
- `docs/ai-examples.md` - Real AI examples
- `dotfiles-check` - System health validator

---

**You've got this.** 🎯
