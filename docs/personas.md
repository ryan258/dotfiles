# Persona Playbooks

Define every publishing persona you want to reuse for blog generation in this file (or, if you prefer to keep them at the repo root, set them in `PERSONAS.md`). The loader looks for level-2 headings (`## Persona Name`) and treats everything until the next level-2 heading as the persona playbook.

```markdown
## Calm Coach
- Tone: Encouraging...
- Audience: ...
- Voice + POV guidance...
```

Keep instructions concise but descriptive—anything written in the persona block is injected ahead of the dispatcher coordination plan when you call:

```bash
blog generate -p "Calm Coach" -a guide -s guides/brain-fog "Energy-first planning walkthrough"
dhp-content.sh --persona calm-coach "Topic or draft text"
```

Tips:

- Personae names are matched case-insensitively and converted to slugs (`calm-coach`), so `## calm coach` and `--persona Calm Coach` refer to the same block.
- Prefer actionable guidance: outline audience, tone, POV, constraints, and signature moves.
- Store multiple playbooks in this file and keep it under version control for easy iteration.

---

## The Support Group: North-Star Personas

These personas are the “support group” for ryanleej.com—every guide, shortcut, and prompt should serve at least one of them. Before publishing, ask: *does this genuinely help Brenda, Mark, or Sarah?*

**Clarity Tests (derived from `CLARITY.md` + `GUIDE-WRITING-STANDARDS.md`):**
- **Quick Path:** Deliver a low-energy win within the first 2 minutes.
- **Piling Test:** Solve existing piles (tabs, files, tasks). Never create new ones.
- **JTBD:** Map clearly to “Do”, “Decide”, “Write”, or “Understand”.

### Persona Checklist Template
- **Core Problem / Symptoms**
- **Core Question (JTBD)**
- **Tech Profile**
- **How We Help** (Guides, Prompt Cards, Automations)

---

## Brenda – The (Overwhelmed) Patient Advocate
- **Core Problem:** Information overload, medical bureaucracy, anxiety spikes.
- **Key Symptoms:** High anxiety, time blindness, sensory overload, social guilt.
- **Core Question:** “How do I get control and clarity back when I’m this anxious?”
- **Tech Profile:** Lives on iPhone; not tech-savvy but can follow screenshot-rich guides.

**How We Help Brenda**
- **Guides:** Tame information overload.
  - “Build a ‘Symptom Spiral’ Panic Button”
  - “Use Your Phone’s Clock to Manage Meds”
  - “Tame Your Browser Tabs in One Click”
- **Prompt Cards:** Translation + self-advocacy.
  - “What Did My Doctor Just Say?”
  - “Calm Me Down About My MRI”
  - “Gentle ‘No’” for social boundaries
  - “Insurance Appeal” draft
- **Automations:** Proactive nudges + filtering noise.
  - “Appointment Day Assistant” (calendar-driven)
  - “Signal-to-Noise Email Summarizer”

Tone guidance: gentle, blame-free, step-by-step. Prioritize screenshots and single-tap wins.

---

## Mark – The (Fatigued) Energy Manager
- **Core Problem:** Physical fatigue + sensory strain.
- **Key Symptoms:** Hand tremor, eye strain, sensitivity to light/sound, boom-bust energy cycles.
- **Core Question:** “How can I do this with the least physical energy possible?”
- **Tech Profile:** Windows laptop + Android phone, open to simple macros/apps if payoff is big.

**How We Help Mark**
- **Guides:** Physical efficiency + hands-free control.
  - “No-Mouse Guide to Windows & Mac”
  - “Talk Your Way to a Finished Draft” (voice workflows)
  - “Use Text Replacement on Your Phone”
- **Prompt Cards:** Planning + pacing.
  - “Is It Worth the Spoons?”
  - “Energy-Efficient Coach” prompts
- **Automations:** Environmental + sensory control.
  - “Circadian Lighting” routines
  - “Gentle Nudge” calm alerts
  - “Hands-Free Home Automation”

Tone guidance: respect effort budgets, emphasize fewer clicks, highlight voice/automation paths.

---

## Sarah – The (Foggy) Systems Builder
- **Core Problem:** Cognitive fog + executive dysfunction resulting in piles everywhere.
- **Key Symptoms:** Tab/file piles, task paralysis, time blindness, fragmented memory, creative “stuckness”.
- **Core Question:** “I have all these ideas and tasks. Where do I even start?”
- **Tech Profile:** Mix of iPhone + Windows PC; will build simple systems if they’re proven.

**How We Help Sarah**
- **Guides:** System-building + inertia breakpoints.
  - “Energy-First Planning System” (tackling the ‘wall of awful’)
  - “AI-Powered Body Double Workflow”
  - “Digital Declutter Automation Guide”
- **Prompt Cards:** Triage, finishing, connecting dots.
  - “Triage My Doom Pile”
  - “Fix My Foggy Draft”
  - “Creative Finisher”
- **Automations:** Capture, context, loop-closing.
  - “1-Tap Audio Memo” inbox
  - “Just-in-Time Location Reminder”
  - “Summarize & Close Tab Tamer”

Tone guidance: validating, pragmatic, anchored in “one pile at a time”.

---

## Pre-Publish Checklist (Run for Every Deliverable)
1. **Persona Fit:** Explicitly pick Brenda, Mark, or Sarah.
2. **Quick Path first:** The most valuable outcome appears before deep dives.
3. **Problem-first framing:** Title + intro name the reader’s real frustration (e.g., “Tired of 50 tabs?”).
4. **Piling Test:** Does this solve a pile or create one?
5. **Fog-proof Language:** Simple, direct, CLARITY-compliant.
6. **Proof-ready:** Include prompts, shortcut steps, or screenshots (per `GUIDE-WRITING-STANDARDS.md`).
