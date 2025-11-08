# AI Staff HQ Integration Roadmap

**Purpose:** Maximize the AI Staff HQ dispatcher system to create a seamless AI workforce integration
**Status:** Foundation laid, building full integration
**Location:** `~/dotfiles/`
**Last Updated:** November 7, 2025

---

## 🎯 Vision

Transform the dotfiles system into an AI-augmented productivity powerhouse by deeply integrating the 42-specialist AI-Staff-HQ workforce with existing daily workflows. The dispatcher scripts (dhp\*) become the high-speed interface for complex creative, technical, and content tasks.

---

## ✅ Current State (November 7, 2025)

**What's Working:**
- ✅ AI-Staff-HQ submodule properly configured at `ai-staff-hq/`
- ✅ Three dispatcher scripts created in `bin/`:
  - `dhp-tech.sh` - Technical debugging (stdin → Automation Specialist → stdout)
  - `dhp-creative.sh` - Horror story first-pass packages
  - `dhp-content.sh` - SEO-optimized evergreen guides
- ✅ Environment variables in `.env` for API keys and model configuration
- ✅ All dispatchers integrate with specialist YAML files and OpenRouter API

**Current Gaps:**
- ⚠️ `bin/` directory is untracked (not in version control)
- ⚠️ Duplicate `.env` entry in `.gitignore`
- ⚠️ No integration with core dotfiles workflows (startday, todo, journal, blog)
- ⚠️ Limited to 3 dispatchers out of 42 possible specialists
- ⚠️ No usage tracking or analytics for dispatcher effectiveness
- ⚠️ No aliases for quick dispatcher access
- ⚠️ Missing documentation in cheatsheet and README

---

## 🚀 Phase 1: Foundation & Infrastructure (Priority: HIGH)

**Goal:** Fix gaps, add to version control, create baseline integration

### 1.1 Fix Immediate Issues ✅ (Do First)

- [ ] Clean up `.gitignore` duplicate `.env` entry
- [ ] Add `bin/` directory to git (commit dispatcher scripts)
- [ ] Verify `.env` has all required variables:
  - `OPENROUTER_API_KEY`
  - `DHP_TECH_MODEL`
  - `DHP_CREATIVE_MODEL`
  - `DHP_CONTENT_MODEL`
- [ ] Document required environment variables in README
- [ ] Add `bin/` to PATH (update `.zprofile` if not already there)

### 1.2 Create Dispatcher Aliases

**Target:** `zsh/aliases.zsh`

Add convenient aliases for all three dispatchers:
```bash
# AI Staff HQ Dispatchers
alias dhp-tech="dhp-tech.sh"
alias dhp-creative="dhp-creative.sh"
alias dhp-content="dhp-content.sh"
alias dhp="dhp-tech.sh"  # default to tech
```

Consider shorthand versions:
```bash
alias tech="dhp-tech.sh"
alias creative="dhp-creative.sh"
alias content="dhp-content.sh"
```

### 1.3 Document Dispatcher System

**Target Files:**
- `README.md` - Add AI Staff HQ section
- `bin/README.md` - Already exists, verify it's up to date
- `scripts/cheatsheet.sh` - Add dispatcher commands

**Documentation should include:**
- What each dispatcher does
- Usage examples
- Required environment variables
- Link to AI-Staff-HQ repo

### 1.4 Add Dispatcher Validation to System Check

**Target:** `scripts/dotfiles_check.sh`

Add checks for:
- `bin/` directory exists
- Dispatcher scripts are executable
- `.env` file exists and is readable
- Required environment variables are set (`OPENROUTER_API_KEY`, model configs)
- OpenRouter API connection test (optional)

---

## 🔧 Phase 2: Workflow Integration (Priority: HIGH)

**Goal:** Connect dispatchers to existing daily workflows

### 2.1 Blog Workflow Integration

**Target:** `scripts/blog.sh`

Add new subcommands:
- `blog generate <stub-name>` - Uses `dhp-content.sh` to generate full guide from stub
- `blog refine <file>` - Uses Content Specialist to polish existing draft
- `blog ideas` - Already exists, document dispatcher can help expand ideas

**Implementation:**
```bash
case "$1" in
  generate)
    stub_name="$2"
    echo "Generating content for: $stub_name"
    echo "$stub_name" | dhp-content.sh "$stub_name"
    ;;
  refine)
    file_path="$2"
    cat "$file_path" | dhp-content.sh "refine"
    ;;
esac
```

### 2.2 Todo → Dispatcher Integration

**Target:** `scripts/todo.sh`

Add new subcommand:
- `todo debug <num>` - For tech tasks, pipes task description through `dhp-tech.sh`
- `todo delegate <num> <dispatcher>` - Delegates task to specified dispatcher

**Use Case:**
User adds task: "Debug the startday.sh script, health section is broken"
User runs: `todo debug 1`
System: Extracts script path, reads file, pipes to dhp-tech.sh, displays analysis

### 2.3 Journal → AI Analysis

**Target:** `scripts/journal.sh`

Add new subcommands:
- `journal analyze` - Sends last 7 days to Chief of Staff for insights
- `journal mood` - Sentiment analysis on recent entries
- `journal themes` - Extract recurring themes/patterns

**Use Case:**
```bash
journal analyze
# Sends last week's entries to Chief of Staff
# Returns: "Key themes: perfectionism blocking progress, energy levels correlating with blog output, need for system simplification"
```

### 2.4 Startday AI Briefing

**Target:** `scripts/startday.sh`

Add optional AI section:
- [ ] AI-generated daily focus suggestion based on recent journal + tasks
- [ ] AI-powered task prioritization recommendation
- [ ] Brief motivational message from Stoic Coach

**Implementation Considerations:**
- Make it opt-in via config flag
- Cache results to avoid API calls on every terminal open
- Run only once per day like startday guard

### 2.5 Goodevening AI Reflection

**Target:** `scripts/goodevening.sh`

Add optional AI section:
- [ ] AI-powered daily reflection prompts
- [ ] Accomplishment summary from Chief of Staff
- [ ] Tomorrow planning suggestions

---

## 🎨 Phase 3: Expand Dispatcher Coverage (Priority: MEDIUM)

**Goal:** Create dispatchers for more specialist types

### 3.1 Strategy Dispatchers

**New Scripts to Create:**

1. `bin/dhp-strategy.sh` - Chief of Staff coordination
   - Multi-specialist project planning
   - Resource allocation
   - Timeline estimation

2. `bin/dhp-brand.sh` - Brand Builder
   - Brand positioning analysis
   - Voice/tone development
   - Competitive analysis

3. `bin/dhp-market.sh` - Market Analyst
   - SEO keyword research
   - Trend analysis
   - Audience insights

### 3.2 Personal Dispatchers

**New Scripts to Create:**

1. `bin/dhp-stoic.sh` - Stoic Coach
   - Daily stoic reflection
   - Mindset coaching on challenges
   - Journaling prompts

2. `bin/dhp-health.sh` - Patient Advocate
   - Medical research summarization
   - Appointment preparation
   - Symptom pattern analysis

3. `bin/dhp-research.sh` - Head Librarian
   - Research topic organization
   - Source summarization
   - Knowledge synthesis

### 3.3 Kitchen Dispatchers

**New Scripts to Create:**

1. `bin/dhp-chef.sh` - Executive Chef
   - Recipe development
   - Menu planning
   - Ingredient substitution

2. `bin/dhp-nutrition.sh` - Nutritionist
   - Meal planning for health goals
   - Nutrition label analysis
   - Diet optimization

### 3.4 Creative Dispatchers (Expand)

**New Scripts to Create:**

1. `bin/dhp-narrative.sh` - Narrative Designer
   - Story structure analysis
   - Plot development
   - Character arc planning

2. `bin/dhp-copy.sh` - Copywriter
   - Sales copy
   - Email sequences
   - Landing page copy

---

## 🧠 Phase 4: Intelligence & Analytics (Priority: MEDIUM)

**Goal:** Track usage, measure effectiveness, optimize workflows

### 4.1 Dispatcher Usage Tracking

**New Script:** `scripts/dispatcher_log.sh`

Track:
- Which dispatchers are used most
- Success/failure rates
- API costs per dispatcher
- Time saved estimates

**Implementation:**
- Each dispatcher logs to `~/.config/dotfiles-data/dispatcher_usage.log`
- Format: `timestamp|dispatcher|model|tokens|duration|exit_code`
- Add `dispatcher stats` command to view analytics

### 4.2 Dispatcher Dashboard

**Target:** `scripts/status.sh` or new `scripts/ai_dashboard.sh`

Display:
- Dispatcher calls today/this week
- Estimated API costs
- Most-used specialists
- Suggested next dispatchers to try

### 4.3 Cost Management

**New Script:** `scripts/ai_budget.sh`

Features:
- Set monthly budget cap
- Track spending by dispatcher
- Alert when approaching limit
- Cost optimization suggestions

### 4.4 Quality Feedback Loop

**Implementation:**

Add feedback mechanism to dispatcher outputs:
```bash
# After dispatcher runs
echo "Was this helpful? (y/n/retry)"
read feedback
# Log feedback to improve prompts over time
```

---

## 🏗️ Phase 5: Advanced Features (Priority: LOW)

**Goal:** Push the limits of AI-augmented workflows

### 5.1 Multi-Specialist Orchestration

**New Script:** `bin/dhp-project.sh`

Coordinates multiple specialists for complex projects:
```bash
dhp-project "Launch new blog series on AI productivity"

# Internally orchestrates:
# 1. Market Analyst - research topic
# 2. Brand Builder - positioning
# 3. Chief of Staff - project plan
# 4. Content Specialist - outline series
# 5. Copywriter - promotional copy
```

### 5.2 Context-Aware Dispatcher Selection

**New Script:** `scripts/ai_suggest.sh`

Analyzes current context and suggests best dispatcher:
- Reads current directory
- Checks recent git commits
- Reviews active todo items
- Suggests relevant specialist

**Usage:**
```bash
$ ai-suggest
Based on your current context (working in blog repo, recent tech commits), try:
  • dhp-content "Refine latest blog post"
  • dhp-tech < latest-script.sh
```

### 5.3 Dispatcher Chaining

Enable piping between dispatchers:
```bash
dhp-creative "lighthouse keeper story" | dhp-narrative "expand plot" | dhp-copy "create email hook"
```

### 5.4 Local Context Injection

Automatically inject relevant context into dispatcher prompts:
- Recent journal entries
- Current todo list
- Active project README
- Recent git commits

**Implementation:**
Add `--context` flag to all dispatchers:
```bash
dhp-content --context "Write guide on X"
# Automatically includes: recent blog topics, journal mentions of X, todo items about X
```

### 5.5 Voice Interface (Experimental)

Explore voice-to-dispatcher workflows:
```bash
voice-dispatch
# Records audio, transcribes, routes to appropriate dispatcher
```

### 5.6 Dispatcher Templates

**New Directory:** `templates/dispatchers/`

Pre-built dispatcher invocations for common tasks:
```bash
templates/dispatchers/
├── blog-post-from-idea.sh
├── debug-script.sh
├── story-outline.sh
├── weekly-reflection.sh
└── meal-plan.sh
```

---

## 📊 Success Metrics

**How we'll measure success:**

### Quantitative Metrics
- Number of dispatcher calls per day/week
- Average time saved per dispatcher call (estimated)
- Task completion rate increase
- Blog post production rate increase
- Code debugging success rate

### Qualitative Metrics
- User satisfaction with dispatcher outputs
- Reduction in perfectionism paralysis
- Increase in creative output
- Better work-life balance via AI delegation
- Cognitive load reduction on brain fog days

### System Health Metrics
- API error rate < 5%
- Average dispatcher response time < 30s
- Monthly API costs within budget
- Zero security issues with API keys

---

## 🔐 Security & Best Practices

### API Key Management
- ✅ `.env` file in `.gitignore`
- ✅ Never commit API keys
- [ ] Add `.env.example` with placeholder values
- [ ] Document key rotation process
- [ ] Consider encrypted secrets for shared machines

### Cost Control
- [ ] Set up API usage alerts
- [ ] Implement rate limiting per dispatcher
- [ ] Add budget cap in scripts
- [ ] Track and review monthly costs

### Error Handling
- [ ] All dispatchers should gracefully handle API failures
- [ ] Provide helpful error messages
- [ ] Log errors for debugging
- [ ] Implement retry logic with exponential backoff

### Privacy
- [ ] Document what data is sent to OpenRouter
- [ ] Add opt-out flags for sensitive data
- [ ] Consider local LLM fallback for private data
- [ ] Clear privacy policy in README

---

## 🎯 Immediate Next Actions

**Start here (in order):**

1. **Fix Infrastructure (30 min)**
   - Clean up `.gitignore`
   - Add `bin/` to git
   - Verify `.env` configuration
   - Add `.env.example` file

2. **Add Aliases (10 min)**
   - Add dispatcher aliases to `aliases.zsh`
   - Test all aliases work
   - Add to cheatsheet

3. **Document System (45 min)**
   - Update README with AI Staff section
   - Verify `bin/README.md` is current
   - Add to cheatsheet
   - Create `docs/ai-staff-guide.md` (optional)

4. **Test Current Dispatchers (30 min)**
   - Run `dhp-tech.sh` on a test script
   - Run `dhp-creative.sh` with a story idea
   - Run `dhp-content.sh` with a blog topic
   - Document any issues

5. **First Integration (1 hour)**
   - Add `blog generate` command
   - Test end-to-end workflow
   - Refine as needed

---

## 🔄 Iteration Plan

**Week 1-2: Foundation**
- Complete Phase 1 (Infrastructure)
- Add aliases and documentation
- Test all existing dispatchers thoroughly

**Week 3-4: First Integrations**
- Implement blog workflow integration
- Add basic todo integration
- Test with real usage

**Month 2: Expand Coverage**
- Add 3-5 new dispatchers (strategy + personal focus)
- Integrate with journal and daily dashboards
- Gather usage data

**Month 3: Intelligence**
- Implement usage tracking
- Create analytics dashboard
- Optimize based on real usage patterns

**Month 4+: Advanced Features**
- Multi-specialist orchestration
- Context-aware suggestions
- Template library

---

## 📝 Notes for Future Development

**Brain Fog Considerations:**
- All dispatchers should have simple, memorable invocations
- Default behaviors should be sensible (minimal flags required)
- Output should be immediately actionable
- Errors should suggest fixes, not just report problems

**Perfectionism Mitigation:**
- Dispatchers output "first drafts" - not perfect, but shippable
- Include encouraging language in outputs
- Frame as "thought partner" not "authority"
- Emphasize iterative improvement over perfection

**System Integration Principles:**
- Dispatchers should feel native to the dotfiles ecosystem
- Consistent with existing command patterns
- Work offline when possible (degrade gracefully)
- Never block critical workflows

**Cost Optimization:**
- Cache responses where appropriate
- Use smaller models for simpler tasks
- Batch requests when possible
- Monitor and optimize prompt efficiency

---

## 🔗 Resources

**Internal:**
- AI-Staff-HQ Submodule: `ai-staff-hq/`
- Dispatcher Scripts: `bin/dhp-*.sh`
- AI Staff Directory: `ai-staff-hq/STAFF-DIRECTORY.md`
- Specialist Files: `ai-staff-hq/staff/*/`

**External:**
- AI-Staff-HQ Repo: https://github.com/ryan258/AI-Staff-HQ
- OpenRouter Docs: https://openrouter.ai/docs
- OpenRouter Models: https://openrouter.ai/models

**Documentation:**
- `docs/happy-path.md` - Daily workflow guide
- `bin/README.md` - Dispatcher documentation
- `CHANGELOG.md` - Implementation history

---

**Last Updated:** November 7, 2025
**Next Review:** Weekly during Phase 1-2, then monthly
**Status:** Foundation laid, Phase 1 ready to begin
