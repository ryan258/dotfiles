# DHP Dispatcher Demos

Live demo commands that showcase the full power of the AI dispatcher system. Each command is designed to run as-is and produce impressive, real-world results.

> **Prerequisite:** `OPENROUTER_API_KEY` set in `.env`. Add `--stream` to any command to watch output generate in real time.

---

## `tech` -- The Code Surgeon

```bash
# 1. Feed it a live script and get a full bug + optimization audit
cat scripts/health.sh | tech "Find every bug, race condition, and edge case. Prioritize by severity."

# 2. Pipe a stack trace straight from a failed command into root-cause analysis
npm test 2>&1 | tech "Diagnose this failure. Show me the root cause, not the symptoms."

# 3. Diff-driven code review -- hand it only what changed
git diff HEAD~3 | tech "Review this diff for security vulnerabilities, performance regressions, and missed edge cases."

# 4. Architecture audit from a directory listing
find ~/Projects/my-app/src -name '*.ts' | head -40 | tech "Infer the architecture from these file paths. Identify coupling hotspots and suggest how to decouple."

# 5. Reverse-engineer an opaque one-liner
echo 'awk "NR==FNR{a[\$1];next} !(\$2 in a)" blocklist.txt access.log | sort -t" " -k4 -rn | head -20' | tech "Explain this command step by step, then rewrite it to be readable and safe for production."
```

## `creative` -- The Story Engine

```bash
# 1. A single sentence becomes a full 3,000-word short story
creative "A deep-sea welder discovers that the structure she's repairing is alive."

# 2. Genre collision -- force two worlds together
creative --stream "Write a noir detective story set inside a medieval fantasy MMO where the NPCs have become self-aware."

# 3. Constrained writing challenge
echo "Write a complete story using only dialogue. No narration, no tags. Two astronauts. One of them isn't human." | creative

# 4. Rewrite a classic from an unexpected perspective
creative "Retell the myth of Icarus from the sun's point of view. Make the sun a reluctant, grieving character."

# 5. Chain world-building into prose -- feed it lore and get a finished chapter
echo "World: A city built on the back of a migrating colossus. Economy runs on harvested dreams. Currency is memory." | creative "Write the opening chapter where a dream-thief takes one last job."
```

## `content` -- The Blog Architect

```bash
# 1. Full Hugo blog post skeleton with SEO front matter
content "The complete guide to building a personal AI lab on a $0 budget"

# 2. Inject your real project context so the draft references your actual work
content --full-context "How I automated my entire morning routine with shell scripts and AI"

# 3. Write in a specific persona voice pulled from your persona playbook
content --persona "cyborg-researcher" "Why every developer should treat their dotfiles as a product"

# 4. Pipe research notes and get a structured longform outline
cat ~/notes/ai-agents-research.md | content "Turn these raw notes into a 2,500-word technical guide with code examples"

# 5. SEO-optimized listicle from a single keyword
echo "spoon theory software engineering" | content "Write a deeply personal guide targeting this exact keyword. Include real examples a developer with chronic illness would recognize."
```

## `strategy` -- The War Room

```bash
# 1. Feed it your journal and get a strategic pattern analysis
tail -50 ~/.config/dotfiles-data/journal.txt | strategy "What patterns do you see? Where am I wasting energy vs. building leverage?"

# 2. Competitive positioning from a product description
echo "I'm building CLI tools for developers with disabilities. My competitors are generic productivity apps." | strategy "Map my unfair advantages and find the positioning gap no one is filling."

# 3. Quarterly planning from raw signals
echo "Published 3 npm packages. 47 GitHub stars total. 2 blog posts got 500+ views. Energy averages 5/10." | strategy "Design my next 90-day sprint. Maximize impact per unit of energy."

# 4. Decision framework for a fork-in-the-road moment
strategy "I can either mass-produce small open-source tools or go deep on one flagship product. I have limited energy. Build me a decision matrix with clear criteria."

# 5. Turn a vague ambition into an execution plan
strategy --stream "I want to become a recognized voice in the AI-accessibility space within 12 months. I have a blog, GitHub repos, and a CLI toolkit. What's the highest-leverage path?"
```

## `brand` -- The Identity Forge

```bash
# 1. Build a complete brand identity from a mission statement
brand "I help developers with chronic illness build sustainable careers using AI tools and automation."

# 2. Voice and tone guide for a specific project
echo "Project: Cyborg Lab -- a blog that documents building AI tools while living with MS. Audience: developers, disability advocates, AI enthusiasts." | brand "Create a complete voice and tone guide with do/don't examples for every content type."

# 3. Tagline workshop -- generate and rank options
brand "Generate 20 taglines for an AI-powered dotfiles system. Rank them by memorability, clarity, and emotional punch."

# 4. Brand audit from existing content
cat ~/Projects/my-ms-ai-blog/content/about.md | brand "Audit this about page. Does the voice match a credible AI researcher who also writes with vulnerability? Give me a rewrite."

# 5. Competitive differentiation map
echo "Competitors: Raycast AI, Warp terminal, Fig autocomplete. My product: an open-source AI dispatcher system that chains specialized models from the command line." | brand "Map where I'm differentiated, where I overlap, and where my brand story is stronger than theirs."
```

## `market` -- The Intelligence Analyst

```bash
# 1. Full market landscape for a niche
market "Map the market for AI-powered developer tools targeting accessibility and chronic illness. Who are the players, what's missing, and where's the whitespace?"

# 2. SEO keyword opportunity analysis
echo "I write about: AI productivity, spoon theory, developer tools, MS and tech careers" | market "Find 15 high-volume, low-competition keyword opportunities I should target in the next quarter."

# 3. Audience persona deep dive
market "Build three detailed audience personas for a blog about building AI tools while managing a disability. Include psychographics, pain points, and content preferences."

# 4. Trend analysis with strategic implications
market --stream "What are the emerging trends in AI-assisted development tools for 2025-2026? Which ones create opportunities for solo developers with deep domain expertise?"

# 5. Validate a product idea before building it
echo "Product idea: A CLI tool that tracks developer energy levels using spoon theory and auto-adjusts task priorities." | market "Is there a market for this? Who would pay, how much, and what's the go-to-market path?"
```

## `stoic` -- The Philosopher

```bash
# 1. Reframe an overwhelming day through Stoic principles
echo "I have 47 open tasks, my energy is at 3/10, and I feel like I'm falling behind on everything." | stoic

# 2. Process a specific frustration with philosophical depth
stoic "I spent three days debugging something that turned out to be a one-character typo. I feel like I wasted my life."

# 3. Pre-mortem for an important decision
echo "I'm about to mass-delete 6 months of unfinished side projects to focus on one thing." | stoic "Walk me through this decision using the View from Above and premeditatio malorum."

# 4. Evening reflection with Stoic journaling prompts
echo "Today I mass-shipped features but skipped lunch, ignored my body, and feel hollow." | stoic "Give me Marcus Aurelius's honest assessment of my day and three journaling prompts."

# 5. Transform imposter syndrome into fuel
stoic --stream "I just got invited to speak at a conference about AI tools and I'm terrified because I feel like a fraud with a disability pretending to be a researcher."
```

## `research` -- The Deep Diver

```bash
# 1. Academic-grade synthesis of a complex topic
research "Synthesize the current state of AI agent architectures: ReAct, tool-use, multi-agent swarms, and chain-of-thought. Compare tradeoffs for solo developers."

# 2. Structured literature review from a question
research "What does the research say about cognitive load management for software engineers with neurological conditions? Organize by intervention type."

# 3. Technology comparison framework
echo "I need to choose between LangChain, CrewAI, AutoGen, and raw OpenAI function calling for my agent system." | research "Build a comparison matrix weighted for: solo developer, low energy budget, shell-script integration, and long-term maintainability."

# 4. Explore contradictions in a field
research --stream "Map the contradictions in current AI safety discourse. Where do leading researchers disagree, and what assumptions drive each camp?"

# 5. Turn a hunch into a research brief
echo "Hunch: developers with ADHD and chronic illness might be disproportionately good at building AI agent systems because of pattern-matching adaptations." | research "Steelman this hypothesis. Find supporting evidence, counterarguments, and design a study that could test it."
```

## `narrative` -- The Story Architect

```bash
# 1. Full narrative design document from a premise
narrative "A disabled astronaut is the only one who can communicate with an alien species because her neural implant speaks their frequency."

# 2. Fix a broken plot structure
cat ~/writing/draft-chapter-7.md | narrative "This chapter feels flat. Diagnose the structural problem, fix the pacing, and show me the revised scene beats."

# 3. Character arc workshop
echo "Character: A burnt-out engineer who discovers she can code reality. Flaw: she automates her relationships. Need: to learn that some things must be done by hand." | narrative "Design her full character arc across a 3-act structure with specific turning points."

# 4. Reverse-engineer why a story works
echo "Story: 'The Last Question' by Isaac Asimov" | narrative "Break down exactly why this story is structurally perfect. Map every narrative device, tonal shift, and payoff."

# 5. Multi-threaded plot weaving
narrative --stream "I have three plotlines: a heist, a love story, and a philosophical debate about AI consciousness. Show me how to weave them into a single novel structure where each thread's climax triggers the next."
```

## `aicopy` -- The Persuasion Engine

```bash
# 1. Full landing page copy from a product description
echo "Product: An open-source CLI that chains AI models like Unix pipes. For developers who live in the terminal." | aicopy "Write complete landing page copy: hero, features, social proof section, and two CTAs."

# 2. Email sequence for a launch
aicopy "Write a 3-email launch sequence for a free AI productivity toolkit aimed at developers with chronic illness. Tone: warm, credible, zero hype."

# 3. Transform technical docs into marketing copy
cat README.md | aicopy "Rewrite this README as compelling marketing copy. Keep the technical accuracy but make a developer excited to try it in 30 seconds."

# 4. Social media blitz from a single announcement
echo "I just published an npm package that tracks developer energy using spoon theory." | aicopy "Generate: 1 tweet thread (5 tweets), 1 LinkedIn post, 1 HackerNews Show HN post, and 1 Reddit r/programming post. Each optimized for its platform."

# 5. A/B test headline generation
aicopy "Generate 10 headline variants for this value prop: 'Chain AI models from your terminal like Unix pipes.' Rank by clarity, curiosity, and click-through potential."
```

## `morphling` -- The Shapeshifter

```bash
# 1. Drop into any project and get an expert-level assessment
cd ~/Projects/my-app && morphling "What's the single highest-impact improvement I could make to this codebase right now?"

# 2. Auto-detect the right expertise for a cross-domain problem
echo "My Bash script calls a Python API that writes to PostgreSQL and the timestamps are wrong in UTC+5 only." | morphling "Fix this."

# 3. Context-aware code generation -- it reads your repo structure automatically
cd ~/Projects/my-cli-tool && morphling --stream "Add a --dry-run flag to every command. Show me the implementation for the three most critical files."

# 4. Crisis mode -- throw everything at it
echo "Production is down. Error: ENOMEM in Node.js worker threads. 64GB RAM server. Load avg: 47. Started 20 min ago after deploy abc123." | morphling "Triage this. Give me the most likely cause and the exact commands to run right now."

# 5. Let it become whatever the moment demands
morphling "I need to write a grant proposal for NSF about AI-assisted accessibility tools. I've never written a grant before. Make this competitive."
```

## `finance` -- The Tax Strategist

```bash
# 1. Full tax optimization analysis for a disability-based R&D lab
finance "I earned $18,000 this year from npm packages and consulting. I'm on Medicare disability. Maximize my deductions without triggering SGA."

# 2. Entity structure decision matrix
finance "Compare: staying sole proprietor vs. forming an LLC vs. S-Corp election for a single-person AI research lab earning under $30K. Factor in Medicare SGA limits."

# 3. R&D tax credit qualification check
echo "Activities: built 5 open-source CLI tools, wrote 20 blog posts documenting AI research, ran 100+ AI model experiments, gave 2 conference talks." | finance "Which of these qualify for Section 174 R&D credits? How do I document them?"

# 4. Quarterly tax planning checkpoint
echo "Q1: $4,200 revenue. Expenses: $800 hosting, $200 API keys, $150 domain renewals. Home office: 120 sq ft of 1,100 sq ft apartment." | finance "Calculate my estimated quarterly tax, optimal deductions, and whether I need to adjust anything before Q2."

# 5. Year-end tax strategy session
finance --stream "It's December. I have $22K gross revenue, $6K in documented expenses, and room to make strategic purchases before year-end. What should I buy, donate, or prepay to minimize my tax burden legally?"
```

## `ai-project` -- The Full Orchestra

```bash
# 1. Launch a complete product strategy from a single idea
ai-project "Launch an AI-powered accessibility toolkit for terminal-first developers"

# 2. Full go-to-market plan with all five specialists
ai-project --stream "Create a developer community around open-source AI dotfiles tools"

# 3. Content empire blueprint
ai-project "Build a content strategy for a blog that documents building AI tools while living with MS -- from SEO to brand voice to launch copy"

# 4. Product-market fit exploration
ai-project "Validate and position a CLI tool that chains AI models like Unix pipes -- market research through launch copy"

# 5. Personal brand buildout with full strategic depth
ai-project --stream "Establish me as the go-to voice for AI-assisted development with disability -- from market analysis to brand identity to content calendar to launch emails"
```

## `ai-chain` -- The Pipeline

```bash
# 1. Research flows into strategy -- two minds, one pipeline
ai-chain research strategy -- "The future of AI agents for solo developers with limited energy budgets"

# 2. Market intelligence feeds brand positioning
ai-chain market brand -- "AI productivity tools for developers with chronic illness"

# 3. Three-stage content pipeline: research, write, then sell it
ai-chain research content aicopy -- "Building a personal AI lab with open-source tools"

# 4. Creative writing through the editorial pipeline
ai-chain narrative creative -- "A programmer who discovers her shell scripts are casting actual spells"

# 5. Full product thinking: market analysis, strategy, then marketing copy
ai-chain market strategy aicopy -- "Open-source CLI framework that lets developers chain AI models like Unix pipes from the terminal"
```

## `memory` / `memory-search` -- The Hive Mind

```bash
# 1. Save a breakthrough insight for future sessions
echo "Insight: chaining small specialized models outperforms one large model for my workflow because each dispatcher prompt is tightly scoped." | memory

# 2. Capture a decision and its reasoning
echo "Decision: chose SQLite over PostgreSQL for local data. Reason: zero-config, single file, survives laptop moves. Revisit if multi-device sync needed." | memory

# 3. Store a research finding for later recall
echo "Finding: Section 174 R&D credits apply to experimental software development even for sole proprietors. Source: IRS Publication 535, Chapter 9." | memory

# 4. Search the knowledge base for past context
memory-search "What did I decide about database choices?"

# 5. Recall across domains -- the hive mind connects the dots
memory-search "What are my key insights about AI model chaining and energy management?"
```

## `swipe` -- The Archivist

```bash
# 1. Run any dispatcher and auto-save the output
swipe tech "Audit my dotfiles system for security vulnerabilities"

# 2. Save a strategy session for later reference
swipe strategy "What should my next 90-day sprint look like based on current momentum?"

# 3. Archive a market analysis you'll reference in meetings
swipe market "Complete competitive landscape for AI developer tools in 2025"

# 4. Build a swipe file of copywriting variations
swipe aicopy "Write 5 different elevator pitches for my AI dotfiles system, each targeting a different audience"

# 5. Save a Morphling assessment of a new project
cd ~/Projects/new-idea && swipe morphling "Full assessment: is this project worth pursuing? Architecture review, market viability, and effort estimate."
```

---

## Combo Moves -- When One Dispatcher Isn't Enough

These chain multiple dispatchers for results no single AI call could produce.

```bash
# The Full Product Launch (5 specialists, one command)
ai-project --stream "Launch a freemium SaaS that helps developers with disabilities track energy and auto-prioritize tasks"

# The Research-to-Publish Pipeline
ai-chain research content -- "How shell scripting became the backbone of my AI research lab" && echo "Draft ready for editing."

# The Crisis-to-Postmortem Arc
echo "Server crashed at 3am, root cause was memory leak in worker pool" | tech && echo "---" && echo "We need a postmortem and prevention plan" | strategy

# The Insight Capture Loop (generate, then remember)
stoic "I keep starting projects and abandoning them" | tee /dev/stderr | memory

# The Brand-Aware Blog Post
ai-chain brand content -- "Writing my first conference talk about AI and disability"
```
