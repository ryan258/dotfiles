# Autopilot Happy Path

Brain fog? Can't type much? This page is your cheat sheet.

One command. AI does the rest. You say yes or no at the end.

---

## Pick Your Lane

### I have a repo I want to document

```bash
ap
```

Run this inside the repo. Done.

### I have a repo somewhere else

```bash
ap --repo ~/Projects/my-thing
```

### I just have an idea

```bash
apb "what the project does, in plain english"
```

Morphling builds it. Cyborg documents it. You confirm once.

### I don't even want to confirm

```bash
apby "your idea here"
```

---

## What Happens

You don't need to remember this. Just know it's working.

```
your idea
   |
   v
Morphling builds the project    (--build only)
   |
   v
Morphling analyzes the repo     (automatic)
   |
   v
Cyborg scans it
   |
   v
Cyborg maps out blog pages
   |
   v
Cyborg drafts everything
   |
   v
You see a summary
   |
   v
A. Apply everything             <-- pick a letter
B. Drafts only
C. Links only
D. Save for later
E. Review interactively
```

---

## Real Examples

Copy-paste any of these.

**Document the repo you're standing in:**

```bash
ap
```

**Document a specific project:**

```bash
ap --repo ~/Projects/rockit
```

**Turn an idea into a project + blog content:**

```bash
apb "CLI that picks recipes based on energy level"
```

**Fully hands-off, no confirmation:**

```bash
apy
```

**Idea, build, document, apply, no stops:**

```bash
apby "terminal habit tracker with weekly review"
```

**Add focus notes to guide the content:**

```bash
ap --repo ~/Projects/foo "focus on the setup path and CLI usage"
```

**Include a draft you already wrote:**

```bash
ap --repo ~/Projects/foo --file notes/draft.md
```

---

## If Something Goes Wrong

Session is always saved. Pick up where you left off:

```bash
apc
```

That's it. It reopens your most recent session so you can review or continue.

---

## Low-Energy Day Checklist

1. Open terminal
2. `ap` or `apb "your idea"`
3. Wait
4. Press A, B, C, D, or E
5. Close terminal

---

## Quick Reference Card

| What you want | Short | Full |
|--------------|-------|------|
| Document current repo | `ap` | `cyborg auto` |
| Document + auto-apply | `apy` | `cyborg auto --yes` |
| Document another repo | `ap --repo PATH` | `cyborg auto --repo PATH` |
| Build from idea | `apb "idea"` | `cyborg auto --build "idea"` |
| Build + auto-apply | `apby "idea"` | `cyborg auto --build --yes "idea"` |
| Resume a session | `apc` | `cyborg resume` |
| Skip Morphling analysis | `ap --no-morphling` | |
| Build into custom folder | `apb --projects-dir ~/Labs "idea"` | |
| Add focus notes | `ap "your notes"` | |
| Include a draft file | `ap --file path/to/draft.md` | |

---

## Deeper Docs (When You Have Energy)

- [Autopilot full guide](../bin/autopilot-readme.md) — all flags, flow diagrams, env vars
- [Cyborg full guide](../bin/cyborg-readme.md) — interactive commands, session lifecycle
- [Dispatchers overview](../bin/README.md) — all AI tools including Morphling
