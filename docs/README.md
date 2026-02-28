# Documentation Index

Welcome to your dotfiles documentation! Start with one of the comprehensive handbooks below based on your needs.

---

## 🚀 Welcome: 5-Minute Orientation

1. **Validate your environment:**

```bash
dotfiles-check
```

2. **Run your morning briefing:**

```bash
startday
```

3. **Work from your top queue:**

```bash
todo top
status
```

4. **Close the day with reflection + backup:**

```bash
goodevening
```

---

## 📚 The Three Core Handbooks

We've consolidated our documentation into three primary handbooks so you never have to guess where to look.

### 1. [🤖 The AI Handbook](ai-handbook.md)

**Your single source of truth for all AI features.**

- How to use the OpenRouter dispatchers (`tech`, `content`, `strategy`, etc.).
- Commands, flags, and workflow patterns (piping, chaining, specs).
- Blog publishing persona playbooks (Brenda, Mark, Sarah).
- Coach config (`startday` & `goodevening` AI logic).

### 2. [🌅 The Daily Loop Handbook](daily-loop-handbook.md)

**Your guide to the daily operational cadence.**

- The Happy Path: Step-by-step from morning to evening.
- How to use `startday`, `status`, `todo`, `focus`, and `goodevening`.
- Emergency resets for when you feel lost or overwhelmed.

### 3. [🗂️ The General Reference Handbook](general-reference-handbook.md)

**Everything else you need to know about the system.**

- MS-Friendly features (brain fog protection, energy/spoon tracking, circuit breakers).
- The Insight module and falsification-first workflows.
- Clipboard management (`clipsave`, `clipload`), Media Converter, aliases, and system data contracts.

---

## 📖 Additional Reference Documentation

If you need to dig deeper into the actual codebase architectures, policies, or troubleshooting steps, see the root-level reference docs:

### Architecture & Scripts

- **[📘 Main README](../README.md)** - Complete system documentation (27KB)
- **[⚙️ Scripts README](../scripts/README.md)** - All 66 scripts explained (14KB)
- **[🔤 Aliases README](../scripts/README_aliases.md)** - 200+ alias reference (10KB)
- **[🤖 AI Dispatchers README](../bin/README.md)** - Complete dispatcher documentation (21KB)

### Version History & Planning

- **[📝 Changelog](../CHANGELOG.md)** - Complete version history (34KB)
- **[🗺 Roadmap](../ROADMAP.md)** - Future features and priorities
- **[🔒 Security Policy](../SECURITY.md)** - Security practices and reporting
- **[🔧 Troubleshooting Guide](../TROUBLESHOOTING.md)** - Common issues and solutions

### Capabilities & R&D

- **[🔋 Energy-Contingent Roadmap](ROADMAP-ENERGY.md)** - Strategic roadmap aligned with bio-rhythms.
- **[🏥 Health System Product Brief](products/health_brief.md)** - Bio-rhythm intelligence tool.
- **[My MS Site Integration](my-ms-site-integration.md)** - Blog integration specifics

---

## 📱 Command-Line Help

### In-Terminal Documentation

```bash
# Validate system
dotfiles-check

# Get help on any command
whatis todo
whatis g
whatis health

# Get AI suggestions for what to do next
ai-suggest

# See all your active aliases
alias

# See all scripts available
ls ~/dotfiles/scripts/
```

---

## 🆘 Need Help?

1. **Check the three handbooks above.**
2. **Use in-terminal help:**
   ```bash
   dotfiles-check    # System validation
   whatis <command>  # Command help
   ai-suggest        # AI recommendations
   ```
3. **Read the [Troubleshooting Guide](../TROUBLESHOOTING.md).**
4. **Ask the AI:**
   ```bash
   tech "How do I fix this dotfiles error..."
   stoic "I'm stuck and frustrated today..."
   ```
