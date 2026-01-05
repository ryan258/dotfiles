# AI Quick Reference

## Swarm Intelligence: 66+ Specialists at Your Command

**All free-tier models.** Use them without guilt or cost concerns.

> **🚀 UPGRADE:** The `content`, `creative`, and `dhp-*` tools now use the **Swarm Orchestration** engine. This means instead of one AI, you get a dynamic team coordinated by a Chief of Staff.

> **⚙️ CONFIGURATION:** All models listed below are **defaults** tailored for each role. You can change any of them in your `.env` file (see `dotfiles/.env`).

---

## 🐝 What is Swarm Orchestration?

When you run `content "Topic"` or `creative "Idea"`, the system now:

1. **Plans:** A Chief of Staff analyzes your request and breaks it into atomic tasks.
2. **Staffs:** Dynamic matching selects the perfect specialists from **66 agents** (e.g., "Historical Storyteller", "React Native Expert", "Stoic Coach").
3. **Executes:** Tasks run in parallel waves for maximum speed.
4. **Synthesizes:** The Chief of Staff compiles all work into a cohesive final result.

**You don't need to do anything different.** Just run the commands as usual.

---

## 🛠 1. Technical (`tech`)

**Default Model:** DeepSeek R1 (Configurable in `.env`)
**Alias:** `tech`

### When to Use

- Debug code errors
- Optimize scripts
- Understand error messages
- Code reviews
- Performance analysis

### Examples

**Debug a script error:**

```bash
tech "I'm getting 'command not found' for jq but it's installed"
```

**Pipe code for review:**

```bash
cat scripts/todo.sh | tech --stream
```

**Analyze an error:**

```bash
./broken_script.sh 2>&1 | tech "Why did this fail?"
```

**Optimize a function:**

```bash
echo "How can I make this bash function faster?" | tech <<'EOF'
function slow_function() {
    for file in $(find . -name "*.txt"); do
        cat $file | grep "pattern"
    done
}
EOF
```

---

## ✍️ 2. Content (`content`)

**Default Model:** Qwen3 Coder (Configurable in `.env`)
**Alias:** `content`

### When to Use

- Blog posts
- Guides and tutorials
- SEO-optimized content
- Technical documentation

### Examples

**Basic content generation:**

```bash
content "Write a guide about managing energy with chronic illness"
```

**With context from your life:**

```bash
content "Blog post about productivity with MS" --context
# Includes: recent journal entries + active todos
```

**Full context (includes git, README, etc.):**

```bash
content "Technical guide to this project" --full-context
```

**Pipe a topic:**

```bash
echo "How to use AI for personal productivity" | content
```

---

## 🎨 3. Creative (`creative`)

**Default Model:** Llama 4 Maverick (Configurable in `.env`)
**Alias:** `creative`

### When to Use

- Story generation
- Creative narratives
- Personal essays
- Fictional scenarios

### Examples

**Generate a story:**

```bash
creative "A developer learning to work with chronic illness"
```

**Story package:**

```bash
creative "Story about overcoming limitations through automation"
# Generates: outline, character sketches, plot points, themes
```

**Personal essay:**

```bash
creative "Essay about finding productivity systems that work with MS"
```

---

## 📝 4. Copywriting (`copy`)

**Default Model:** Llama 4 Maverick (Configurable in `.env`)
**Alias:** `copy`

### When to Use

- Marketing copy
- Email sequences
- Landing pages
- Calls-to-action
- Product descriptions

### Examples

**Email sequence:**

```bash
copy "3-email welcome sequence for blog subscribers interested in productivity with chronic illness"
```

**Landing page:**

```bash
copy "Landing page for a productivity course for people with MS"
```

**Call-to-action:**

```bash
copy "CTA for newsletter signup, focus on practical tips"
```

---

## 🧭 5. Strategy (`strategy`)

**Default Model:** Polaris Alpha (Configurable in `.env`)
**Alias:** `strategy`
**Role:** Your Chief of Staff

### When to Use

- Big decisions
- Prioritization
- Planning
- Problem-solving
- Direction setting

### Examples

**Big decision:**

```bash
strategy "Should I focus on technical writing or personal essays?"
```

**Prioritization:**

```bash
strategy "I have 3 blog ideas and limited energy. How do I choose?" <<'EOF'
Ideas:
1. Technical guide to bash automation
2. Personal story about MS diagnosis
3. Productivity tips for chronic illness
EOF
```

**Planning:**

```bash
strategy "Help me plan a blog series on productivity with chronic illness"
```

**Problem-solving:**

```bash
strategy "My blog gets traffic but no engagement. What should I do?"
```

---

## 🎯 6. Brand (`brand`)

**Default Model:** Polaris Alpha (Configurable in `.env`)
**Alias:** `brand`

### When to Use

- Define your brand
- Positioning
- Messaging
- Differentiation
- Voice and tone

### Examples

**Define personal brand:**

```bash
brand "Help me define my personal brand as a developer with MS"
```

**Positioning:**

```bash
brand "How should I position myself in the productivity + chronic illness space?"
```

**Messaging:**

```bash
brand "What core message should my blog communicate?"
```

**Voice and tone:**

```bash
brand "Define voice and tone for content about MS that's honest but not depressing"
```

---

## 📊 7. Market Research (`market`)

**Default Model:** Polaris Alpha (Configurable in `.env`)
**Alias:** `market`

### When to Use

- Audience research
- Trends analysis
- Opportunity identification
- Competitive analysis

### Examples

**Audience research:**

```bash
market "What's the audience for MS + productivity content?"
```

**Trends:**

```bash
market "Current trends in chronic illness content and communities"
```

**Opportunity:**

```bash
market "Gaps in existing productivity content for people with disabilities"
```

**Competitive analysis:**

```bash
market "Who are the main voices in MS + productivity space?"
```

---

## 🧘 8. Stoic Coaching (`stoic`)

**Default Model:** Gemma 3 9B (Configurable in `.env`)
**Alias:** `stoic`

### When to Use

- Frustration with limitations
- Dealing with unpredictability
- Need perspective
- Mindset challenges
- Resilience building

### Examples

**Daily frustration:**

```bash
stoic "I'm frustrated with my energy limitations today"
```

**Unpredictability:**

```bash
stoic "How do I handle not knowing if tomorrow will be a good day?"
```

**Comparison trap:**

```bash
stoic "I keep comparing my output to healthy developers"
```

**Reframing:**

```bash
stoic "Help me reframe 'I can only work 2 hours' into something empowering"
```

**Long-term perspective:**

```bash
stoic "How do I stay motivated when progress is so slow?"
```

---

## 🔬 9. Research (`research`)

**Default Model:** Gemma 3 9B (Configurable in `.env`)
**Alias:** `research`

### When to Use

- Learn new topics
- Synthesize information
- Deep dives
- Knowledge summaries

### Examples

**Medical research:**

```bash
research "Summarize recent research on MS and cognitive function"
```

**Technology deep-dive:**

```bash
research "Best practices for bash scripting in 2025"
```

**Synthesis:**

```bash
research "Compare different productivity systems for people with chronic illness"
```

**Learning:**

```bash
research "Explain how AI language models work at a high level"
```

---

## 📖 10. Narrative (`narrative`)

**Default Model:** Llama 4 Maverick (Configurable in `.env`)
**Alias:** `narrative`

### When to Use

- Story structure analysis
- Plot development
- Narrative feedback
- Character development

### Examples

**Analyze structure:**

```bash
cat draft.md | narrative "Analyze the story structure"
```

**Plot feedback:**

```bash
narrative "Review this plot outline for pacing" < outline.txt
```

**Character development:**

```bash
narrative "Help me develop a character who has MS but it's not their defining trait"
```

---

## 🚀 Advanced Features

### Chain Multiple Specialists

```bash
dhp-chain creative narrative copy -- "Blog post about automation helping with chronic illness"
```

**What it does:** Passes your prompt through creative → narrative → copy in sequence.

---

### Full Project Brief

```bash
dhp-project "Launch a blog series about productivity with chronic illness"
```

**What it does:** Runs 5 specialists in order:

1. Market Analyst (audience research)
2. Brand Builder (positioning)
3. Chief of Staff (strategy)
4. Content Specialist (content plan)
5. Copywriter (marketing copy)

**Output:** Comprehensive markdown project brief.

---

### Context-Aware Suggestions

```bash
ai_suggest
```

**What it does:** Analyzes your current situation and recommends which AI to use.

**Analyzes:**

- Current directory
- Git status
- Active todos
- Recent journal
- Time of day
- Health signals

**Example output:**

```
You're in a blog directory with drafts.
Recent journal mentions "energy management".
Suggested AI specialists:
  - content: Write about energy management
  - creative: Turn journal into personal essay
  - strategy: Plan blog series structure
```

---

## 🎯 Practical Workflows

### Blog Writing Workflow

```bash
# 1. Get ideas from journal
blog ideas

# 2. Generate draft
blog generate "Managing Energy with MS" -p thoughtful-guide -s guides

# 3. Refine with AI
blog refine drafts/managing-energy.md -p technical-deep-dive

# 4. Get marketing copy
copy "Social media promotion for this blog post" < drafts/managing-energy.md
```

---

### Technical Problem-Solving

```bash
# 1. Debug the error
./script.sh 2>&1 | tech "What's wrong?"

# 2. Get optimization suggestions
cat script.sh | tech "How can I make this faster and safer?"

# 3. Research best practices
research "Bash error handling best practices"
```

---

### Personal Development

```bash
# 1. Journal about struggle
journal "Frustrated with unpredictable energy"

# 2. Get stoic perspective
stoic "How do I handle energy unpredictability?"

# 3. Turn into content
creative "Personal essay about working with unpredictable energy"

# 4. Analyze for themes
journal themes
```

---

### Strategic Planning

```bash
# 1. Market research
market "Audience for MS + productivity"

# 2. Brand positioning
brand "Position myself in this space"

# 3. Strategy decision
strategy "Should I focus on blog or video content?"

# 4. Content plan
content "Create 3-month content calendar" --context
```

---

## 💡 Pro Tips

### Use Spec Templates

```bash
spec tech       # Opens technical spec template in VS Code
spec content    # Opens content spec template
spec creative   # Opens creative spec template
```

**How it works:**

1. Command opens template in VS Code
2. Fill in the structured template
3. Save and close
4. Auto-pipes to the appropriate AI dispatcher
5. Output saved for reuse

---

### Pipe Anything

```bash
cat file.txt | tech "Review this"
echo "question" | stoic
git diff | tech "Review these changes"
todo | strategy "Prioritize these tasks"
journal list 10 | narrative "Find story themes"
```

---

### Stream for Real-Time Output

```bash
tech "long question" --stream
content "long article" --stream
```

**Why:** See output as it generates instead of waiting for completion.

---

### Save Output

All dispatcher output is automatically saved to:

```
~/.config/dotfiles-data/ai-output/<dispatcher>/<timestamp>.md
```

**To archive manually:**

```bash
tech "question" > ~/Documents/saved-response.md
```

---

### Check Usage Logs

```bash
cat ~/.config/dotfiles-data/dispatcher_usage.log
```

**Shows:** Which dispatchers you use most, when, and estimated costs (all free).

---

## 🆘 Troubleshooting

### "No API key found"

```bash
# Check .env file
cat ~/dotfiles/.env | grep OPENROUTER_API_KEY

# If missing, add to .env:
echo 'OPENROUTER_API_KEY=your_key_here' >> ~/dotfiles/.env
```

---

### "Rate limit exceeded"

**Increase cooldown in `.env`:**

```bash
API_COOLDOWN_SECONDS=3
```

**Default:** 1 second between calls.

---

### "Command not found: tech"

```bash
# Reload shell configuration
source ~/.zshrc

# Or validate system
dotfiles-check
```

---

### "Dispatcher fails silently"

```bash
# Run with debug output
bash -x $(which tech) "test question"

# Check logs
tail ~/.config/dotfiles-data/system.log
```

---

## 📊 Which AI When?

| Situation                | Use This     |
| ------------------------ | ------------ |
| Code is broken           | `tech`       |
| Need blog content        | `content`    |
| Writing a story          | `creative`   |
| Need marketing copy      | `copy`       |
| Big decision             | `strategy`   |
| Define brand             | `brand`      |
| Research audience        | `market`     |
| Feeling stuck mentally   | `stoic`      |
| Learn something new      | `research`   |
| Story structure feedback | `narrative`  |
| Not sure which to use    | `ai_suggest` |

---

## 🎯 Remember

✅ All dispatchers are **free** - use them generously
✅ You can **pipe** any text to any dispatcher
✅ Use `--stream` for **real-time** output
✅ Use `--context` to include **your recent data**
✅ All output is **automatically saved**
✅ **Chain** multiple AIs for complex tasks
✅ Run `ai_suggest` when you're **not sure** what to do

**The AI is here to help. Use it like you'd use a coworker - frequently and without hesitation.** 🤖
