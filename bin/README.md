# Your AI Tool Shortcut Menu

This folder holds 13 fast tools (and 4 extra tricks) that give you instant help from your AI-Staff-HQ team. Each tool connects you right to a smart AI helper so you don't have to copy and paste anything!

**Latest Update:** 
- ✅ All tools can print answers live on your screen (use `--stream`)
- ✅ Errors are reported clearly so you know what broke
- ✅ We deleted 1,500 lines of messy code to make it faster!

---

## Fast Cheat Sheet

| Tool | Shortcut Command | What It Does |
| --- | --- | --- |
| `dhp-tech.sh` | `tech` | Fix broken code |
| `dhp-creative.sh` | `creative` | Write big stories |
| `dhp-content.sh` | `content` | Write blog posts |
| `dhp-strategy.sh` | `strategy` | Think about big plans |
| `dhp-coach.sh` | `dhp-coach` | Fast daily pep talk |
| `dhp-brand.sh` | `brand` | Build your brand's voice |
| `dhp-market.sh` | `market` | Research what people buy |
| `dhp-stoic.sh` | `stoic` | Advice for when you feel stuck |
| `dhp-research.sh` | `research` | Learn about hard topics |
| `dhp-narrative.sh` | `narrative` | Fix story plots |
| `dhp-copy.sh` | `aicopy` | Write ads that sell |
| `dhp-morphling.sh`| `dhp-morphling` | The magic helper that can do anything |
| `dhp-finance.sh` | `finance` | Get advice about money and taxes |
| `cyborg-sync` | `cyborg-sync` | Updates mapped site pages from real repo changes |

**Magic Helper:** Typing `morphling` now opens the direct Morphling session from AI-Staff-HQ with full lead-developer capabilities — it can read, write, and list files, plus run shell commands to install deps, compile, and run tests. Use `morphling --swarm` when you want the older dispatcher-style context gathering path.

## ⚙️ Computer and Work (Tech & Copy)

### `tech` (The Code Fixer)
**Goal:** Fix bugs and make your code run faster.
**How to use it:** Pass your broken code right to it!
```bash
# Hand it a broken script
cat broken-script.sh | tech

# Type a fast question
echo "Why does my code crash?" | tech
```

### `aicopy` (The Writer)
**Goal:** Write emails and ads that make people want to click.
**How to use it:**
```bash
echo "Sell a fun coffee mug" | aicopy
```

## 🎨 Art and Reading (Creative & Content)

### `creative` (The Storyteller)
**Goal:** Build a whole story world with characters and chapters.
**How to use it:** Just give it your idea.
```bash
creative "A lighthouse keeper finds a mysterious artifact"

# Watch it type live
creative --stream "A robot learns how to paint"
```

### `content` (The Blogger)
**Goal:** Write long guides that do well on Google (SEO).
**How to use it:**
```bash
content "Guide on overcoming creative blocks with AI"
```

## 🧠 Brains and Business (Strategy & Coaching)

### `strategy` (The Boss)
**Goal:** Help you plan big projects and find clues.
**How to use it:**
```bash
# Look at your old journal notes
tail -20 ~/.config/dotfiles-data/journal.txt | strategy
```

### `stoic` (The Calm Friend)
**Goal:** Help you chill out when you feel stressed or mad.
**How to use it:**
```bash
echo "I am feeling very overwhelmed with homework" | stoic
```

## 🪄 Advanced Magic Tools

| Tool | Shortcut Command | What It Does |
| --- | --- | --- |
| `dhp-project.sh` | `ai-project` | Starts a team of helpers working together |
| `dhp-chain.sh` | `ai-chain` | Passes work from one helper straight to another |
| `ai_suggest.sh` | `ai-suggest` | Automatically guesses what you need help with right now |
| `dhp-context.sh` | `ai-context` | Sneaks your notes to the AI behind the scenes |

### Passing Notes (Chaining)
You can pass the answer from one helper to the next helper like a factory line!
```bash
# Have the Market Analyst write a report, then have the Brand Builder use it!
dhp-chain market brand -- "AI tools for writers"
```

### The Cyborg Lab (`cyborg`)
This is a super smart chat robot that helps you write articles for your blog. It can read your folders, run health checks, build projects from ideas, check the market first, and optionally publish the verified package before it writes the docs.
```bash
# Run the robot in the current folder
cyborg ingest

# Build a project from an idea (Morphling scaffolds, verifies, then Cyborg documents)
cyborg auto --build "CLI that tracks daily energy with spoon theory"

# Build, publish, then document
cyborg auto --build --publish "CLI that scores menus by accessibility"
```

### The Docs Sync Worker (`cyborg-sync`)
This is the non-chat path for keeping project docs on your site up to date. It reads a repo manifest, looks at what changed, updates the mapped site pages, and can make a branch and commit after checks pass.
```bash
# Show the plan for a repo
cyborg-sync --repo ~/Projects/alias-scanner plan

# Update the mapped site pages on the current branch
cyborg-sync --repo ~/Projects/alias-scanner sync --commit

# Or use a review branch when you want one
cyborg-sync --repo ~/Projects/alias-scanner sync --create-branch --commit
```

## 📝 Filling Out Forms (The `spec` tool)
If you have a really big job, you can open a blank form and fill it out. The AI will read the form and do exactly what you want!
```bash
# Open the "tech" form
spec tech
```
When you save and close the file, the computer will automatically send it to the AI for you! Every form you fill out is saved in `~/.config/dotfiles-data/specs/` so you never lose your work.

## 💾 Saving Everything (Swipe Logging)
If you want to save the AI's answer into a notebook so you can read it later, just put the word `swipe` in front of your command!
```bash
swipe tech "How do I fix my internet?"
```

## 🛠️ How to Add a New Helper Tool

1. Try opening `bin/dhp-stoic.sh` and make a copy of it. Name it `dhp-[your-name].sh`.
2. Open the file and follow the directions inside.
3. Make it run by typing `chmod +x bin/dhp-[your-name].sh`.
4. Run the check tool `bash ~/dotfiles/scripts/dotfiles_check.sh` to make sure it works!

**Important:** Make sure you have your `OPENROUTER_API_KEY` saved in your `.env` file, or none of this magic will work!
