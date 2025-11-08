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

**Implementation Complete:**
- ✅ **Phase 1: Foundation & Infrastructure** - All systems operational
- ✅ **Phase 2: Workflow Integration** - Deeply integrated into daily workflows
- ✅ **Phase 3: Dispatcher Expansion** - 10/10 priority dispatchers active
- ✅ **Phase 5: Advanced Features** - Multi-specialist orchestration, context injection, chaining

**What's Working:**
- ✅ AI-Staff-HQ submodule properly configured at `ai-staff-hq/`
- ✅ 10 dispatcher scripts operational in `bin/`:
  - Technical (1): `dhp-tech.sh`
  - Creative (3): `dhp-creative.sh`, `dhp-narrative.sh`, `dhp-copy.sh`
  - Strategy (3): `dhp-strategy.sh`, `dhp-brand.sh`, `dhp-market.sh`
  - Content (1): `dhp-content.sh`
  - Personal (2): `dhp-stoic.sh`, `dhp-research.sh`
- ✅ Advanced AI features:
  - Multi-specialist orchestration (`dhp-project.sh`)
  - Context-aware suggestions (`ai_suggest.sh`)
  - Dispatcher chaining (`dhp-chain.sh`)
  - Local context injection (`dhp-context.sh` with `--context` flag support)
- ✅ Environment variables in `.env` with full configuration
- ✅ All dispatchers integrate with specialist YAML files and OpenRouter API
- ✅ Full integration with core workflows: `blog`, `todo`, `journal`, `startday`, `goodevening`
- ✅ 27 AI aliases (21 dispatcher + 6 advanced features)
- ✅ System validation via `dotfiles_check.sh`
- ✅ Comprehensive documentation in README files

**Next Priorities:**
- 📊 Phase 4: Intelligence & Analytics (optional - usage tracking, cost management)

---

## ✅ Phase 1: Foundation & Infrastructure (COMPLETE)

**Status:** All objectives achieved, system fully operational

**Key Achievements:**
- ✅ Infrastructure fixes: `.gitignore` cleaned, `bin/` in version control, `.env.example` created
- ✅ PATH configuration: `bin/` added to `.zprofile` for global access
- ✅ 21 dispatcher aliases: Full names + shorthand versions in `aliases.zsh`
- ✅ System validation: Enhanced `dotfiles_check.sh` validates all 10 dispatchers
- ✅ Documentation: Comprehensive updates to README.md, bin/README.md, cheatsheet.sh

**See CHANGELOG.md for detailed implementation notes.**

---

## ✅ Phase 2: Workflow Integration (COMPLETE)

**Status:** All dispatchers deeply integrated into daily workflows

**Key Achievements:**
- ✅ Blog workflow: `blog generate`, `blog refine` using `dhp-content.sh`
- ✅ Todo integration: `todo debug`, `todo delegate` with auto-detection
- ✅ Journal analysis: `journal analyze`, `journal mood`, `journal themes` via `dhp-strategy.sh`
- ✅ Daily automation: Optional AI briefing in `startday.sh` (cached daily)
- ✅ Evening reflection: Optional AI summary in `goodevening.sh`
- ✅ Both features opt-in via `AI_BRIEFING_ENABLED` and `AI_REFLECTION_ENABLED` flags

**See CHANGELOG.md for detailed implementation notes.**

---

## ✅ Phase 3: Dispatcher Expansion (COMPLETE)

**Status:** 10/10 priority dispatchers operational, all categories covered

**Key Achievements:**
- ✅ Created 7 new dispatchers (10 total active)
- ✅ Categories covered: Technical (1), Creative (3), Strategy (3), Content (1), Personal (2)
- ✅ All dispatchers: `dhp-strategy`, `dhp-brand`, `dhp-market`, `dhp-stoic`, `dhp-research`, `dhp-narrative`, `dhp-copy`
- ✅ 14 new aliases added (full names + shorthand)
- ✅ System validation updated for all 10 dispatchers
- ✅ All dispatchers tested and validated

**Deferred (low priority):**
- Kitchen dispatchers (dhp-chef, dhp-nutrition) - Can add on-demand

**See CHANGELOG.md for detailed implementation notes.**

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

## ✅ Phase 5: Advanced Features (COMPLETE)

**Status:** Core advanced features implemented, 5.5-5.6 deferred for future needs

**Key Achievements:**
- ✅ Multi-specialist orchestration (`dhp-project.sh`)
- ✅ Context-aware dispatcher suggestions (`ai_suggest.sh`)
- ✅ Dispatcher chaining (`dhp-chain.sh`)
- ✅ Local context injection (`dhp-context.sh` + `--context` flag)
- ✅ 6 new aliases, all features tested and validated

### 5.1 Multi-Specialist Orchestration ✅

**Script:** `bin/dhp-project.sh`

Coordinates 5 specialists for complex projects:
```bash
dhp-project "Launch new blog series on AI productivity"

# Internally orchestrates:
# 1. Market Analyst - research topic
# 2. Brand Builder - positioning
# 3. Chief of Staff - project plan
# 4. Content Specialist - outline series
# 5. Copywriter - promotional copy
```

**Features:**
- Sequential specialist activation with context building
- Comprehensive markdown project brief output
- Aliases: `dhp-project`, `ai-project`

### 5.2 Context-Aware Dispatcher Selection ✅

**Script:** `scripts/ai_suggest.sh`

Analyzes current context and suggests best dispatcher:
- ✅ Reads current directory and project type
- ✅ Checks recent git commits
- ✅ Reviews active todo items
- ✅ Time-based suggestions (morning/evening)
- ✅ Suggests relevant specialist based on context

**Usage:**
```bash
$ ai-suggest
Based on your current context (working in blog repo, recent tech commits), try:
  • dhp-content "Refine latest blog post"
  • dhp-tech < latest-script.sh
```

### 5.3 Dispatcher Chaining ✅

**Script:** `bin/dhp-chain.sh`

Sequential processing through multiple dispatchers:
```bash
dhp-chain creative narrative copy -- "lighthouse keeper story"

# Processes through:
# 1. creative - generates story package
# 2. narrative - expands plot structure
# 3. copy - creates marketing hook
```

**Features:**
- Progress display after each step
- Optional `--save <file>` for output
- Aliases: `dhp-chain`, `ai-chain`

### 5.4 Local Context Injection ✅

**Library:** `bin/dhp-context.sh`

Automatically inject relevant context into dispatcher prompts:
- ✅ Recent journal entries
- ✅ Current todo list
- ✅ Active project README
- ✅ Recent git commits
- ✅ Blog context for content work

**Implementation:**
Added `--context` flag to `dhp-content.sh` (example):
```bash
dhp-content --context "Write guide on X"
# Automatically includes: recent blog topics, git context, top tasks

dhp-content --full-context "Comprehensive guide on Y"
# Includes: journal, todos, README, git history
```

**Functions:**
- `gather_context()` - Main context collection (minimal/full modes)
- `get_git_context()` - Repository and commit history
- `get_recent_journal()` - Last N days of journal entries
- `get_active_todos()` - Top tasks
- `get_project_readme()` - Project documentation

### 5.5 Voice Interface (Deferred)

**Status:** Future enhancement, implement on-demand

Potential voice-to-dispatcher workflows:
```bash
voice-dispatch
# Would record audio, transcribe, route to appropriate dispatcher
```

### 5.6 Dispatcher Templates (Deferred)

**Status:** Future enhancement, create templates as usage patterns emerge

Potential pre-built dispatcher invocations for common tasks:
```bash
templates/dispatchers/
├── blog-post-from-idea.sh
├── debug-script.sh
├── story-outline.sh
├── weekly-reflection.sh
└── meal-plan.sh
```

**See CHANGELOG.md for Phase 5 implementation details.**

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

**Phases 1-3 Complete ✅** - Moving to intelligence and analytics

**Recommended Next Steps:**

1. **Try the System (Recommended First)**
   - Use dispatchers in real workflows for 1-2 weeks
   - Note which dispatchers get used most
   - Identify pain points or missing features
   - Gather feedback before building analytics

2. **Phase 4: Start with Usage Tracking (Optional)**
   - Implement basic dispatcher logging (low overhead)
   - Track: dispatcher used, timestamp, success/failure
   - Build simple analytics after gathering real usage data

3. **On-Demand Expansion (As Needed)**
   - Add kitchen dispatchers if meal planning becomes priority
   - Create additional specialists based on actual need
   - Don't over-engineer before usage patterns emerge

---

## 🔄 Iteration Plan

**✅ November 7, 2025: Foundation Complete**
- ✅ Phase 1: Infrastructure (complete)
- ✅ Phase 2: Workflow Integration (complete)
- ✅ Phase 3: Dispatcher Expansion (complete)
- ✅ 10 active dispatchers, full workflow integration, comprehensive documentation

**November-December 2025: Real-World Usage**
- Use dispatchers in daily workflows
- Gather usage patterns organically
- Note friction points and opportunities
- Let needs drive Phase 4 priorities

**Q1 2026: Intelligence & Analytics (If Needed)**
- Implement usage tracking based on real pain points
- Add cost management if spending becomes concern
- Build analytics only if usage patterns warrant it

**Q2 2026+: Advanced Features (On-Demand)**
- Multi-specialist orchestration (if complex projects emerge)
- Context-aware suggestions (if context switching is frequent)
- Additional dispatchers (as specific needs arise)

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
**Next Review:** Monthly, or as new needs emerge
**Status:** Phases 1-3 complete, 10 dispatchers operational, ready for real-world usage
