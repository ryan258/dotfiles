# Documentation Index

Welcome to your dotfiles documentation! Start with one of the guides below based on your needs.

---

## TL;DR

- Start with [Start Here](start-here.md).
- Keep [Daily Cheat Sheet](daily-cheatsheet.md) open while learning.
- Use [AI Quick Reference](ai-quick-reference.md) for dispatcher help.

## Docs Owner

- **Owner:** Ryan Johnson
- **Purpose:** Keep docs accurate, low-noise, and aligned with current scripts.

## Maintenance Rule

- Update `docs/README.md` whenever docs change.

## 🚀 **New? Start Here**

**[📍 Start Here (5-Minute Orientation)](start-here.md)**

- Quick validation check
- Your first 5 minutes
- Choose your learning path
- Get oriented fast

---

## 📚 Essential Guides

### For Daily Use

- **[📋 Daily Cheat Sheet](daily-cheatsheet.md)** - One-page reference of all your commands
  - Keep this open while you learn
  - Perfect for brain-fog days
  - Organized by category

### Discover Features

- **[📍 Start Here](start-here.md)** - Use-case index and quick paths
  - Daily essentials (morning/evening routines)
  - When you're overwhelmed
  - Managing health
  - Getting things done
  - AI assistants
  - And much more

### Accessibility & MS-Friendly

- **[🧠 MS-Friendly Features](ms-friendly-features.md)** - How the system supports you
  - Brain fog protection
  - Energy management
  - Pattern recognition
  - Mental health support
  - Real-world scenarios
  - Low-friction workflows

### AI Assistance

- **[🤖 AI Quick Reference](ai-quick-reference.md)** - Dispatcher map, flags, workflows, and examples
  - Technical help (`tech`)
  - Content creation (`content`)
  - Creative writing (`creative`)
  - Strategic thinking (`strategy`)
  - Stoic coaching (`stoic`)
  - Advanced features (chaining, context injection)

---

## 🏗 Understanding the System

### Architecture & Design

- **[📊 System Overview](system-overview.md)** - Visual guide to architecture
  - System architecture diagrams
  - Daily workflow loop
  - Data flow maps
  - Command categories
  - Learning path

### Daily Workflows

- **[🛤 Happy Path](happy-path.md)** - Daily workflow walkthrough
  - Morning routine
  - Throughout the day
  - Evening wrap-up
  - Brain-fog-friendly explanations

---

## 🎯 Specialized Guides

### Clipboard Workflows

- **[📋 Clipboard Guide](clipboard.md)** - macOS clipboard workflows
  - Practical pbcopy/pbpaste examples
  - Clipboard manager usage
  - Dynamic snippets

### Blog Integration

- **[My MS Site Integration](my-ms-site-integration.md)** - Blog integration specifics
  - Hugo setup
  - Content workflow
  - Publishing pipeline

### Personas & Content

- **[🎭 Personas](personas.md)** - Blog persona playbooks
  - Thoughtful guide
  - Practical tip
  - Technical deep-dive
  - Personal story

### Best Practices

- **[✅ Best Practices](best-practices.md)** - Usage best practices
  - Recommended workflows
  - Tips and tricks
  - Common patterns

### Customization

- **[✅ Best Practices](best-practices.md)** - Usage best practices
  - Recommended workflows
  - Tips and tricks
  - Common patterns

---

## 📖 Reference Documentation

### Main Documentation

- **[📘 Main README](../README.md)** - Complete system documentation (27KB)
  - Installation
  - Features overview
  - All scripts and commands
  - AI Staff HQ integration

### Script References

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

---

## 🎯 Quick Navigation by Need

### "I forgot what I have"

→ [Start Here](start-here.md) (Feature Discovery section)

### "I need a quick reference"

→ [Daily Cheat Sheet](daily-cheatsheet.md)

### "I'm having a brain fog day"

→ [MS-Friendly Features](ms-friendly-features.md)
→ [Daily Cheat Sheet](daily-cheatsheet.md)

### "I want to use AI"

→ [AI Quick Reference](ai-quick-reference.md)

### "I need to understand the architecture"

→ [System Overview](system-overview.md)

### "How do I do X?"

→ [Start Here](start-here.md) (Feature Discovery section)

### "Something isn't working"

→ [Troubleshooting Guide](../TROUBLESHOOTING.md)
→ Run `dotfiles-check`

### "I want to customize"

→ [Best Practices](best-practices.md)
→ Edit `~/.env`

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

# Get AI suggestions
ai-suggest

# See all aliases
alias

# See all scripts
ls ~/dotfiles/scripts/
```

---

## 🗂 Documentation Organization

```
docs/
├── README.md                   ⭐ This index
├── start-here.md              ⭐ 5-minute orientation
├── daily-cheatsheet.md        ⭐ One-page reference
├── ms-friendly-features.md    ⭐ Accessibility guide
├── ai-quick-reference.md      ⭐ AI usage + examples
├── system-overview.md         ⭐ Architecture diagrams
├── happy-path.md              Daily workflow
├── best-practices.md          Best practices
├── clipboard.md               Clipboard workflows
├── personas.md                Blog personas
├── products/health_brief.md   Health product brief
└── my-ms-site-integration.md  Blog integration
```

---

## 🎓 Recommended Reading Order

### First Time Here?

1. [Start Here (5 minutes)](start-here.md)
2. [Daily Cheat Sheet](daily-cheatsheet.md)
3. Review the Feature Discovery section in Start Here

### After First Week?

1. [MS-Friendly Features](ms-friendly-features.md) - Understand the design
2. [AI Quick Reference](ai-quick-reference.md) - Explore AI helpers
3. [System Overview](system-overview.md) - See the big picture

### Ready to Customize?

1. [Best Practices](best-practices.md)
2. Edit `.env` file

---

## 💡 Pro Tips

### Keep These Handy

- **[Daily Cheat Sheet](daily-cheatsheet.md)** - Print or keep open
- **[Start Here](start-here.md)** - Feature Discovery section

### Brain-Fog-Friendly Reading

- All docs use clear headers
- Scannable tables
- Concrete examples
- No jargon

### Search Docs

```bash
# Search all docs
grep -r "keyword" ~/dotfiles/docs/

# Search main docs
grep "keyword" ~/dotfiles/*.md
```

---

## 🆘 Need Help?

1. **Check the docs:**
   - Start with [Daily Cheat Sheet](daily-cheatsheet.md)
   - Then [Start Here](start-here.md)

2. **Use in-terminal help:**

   ```bash
   dotfiles-check    # System validation
   whatis <command>  # Command help
   ai-suggest        # AI recommendations
   ```

3. **Read troubleshooting:**
   - [Troubleshooting Guide](../TROUBLESHOOTING.md)

4. **Ask AI:**
   ```bash
   tech "How do I..."
   stoic "I'm stuck on..."
   ```

---

## Related Docs

- [Main README](../README.md)
- [Start Here](start-here.md)
- [Daily Cheat Sheet](daily-cheatsheet.md)
- [Troubleshooting](../TROUBLESHOOTING.md)

---

**Start with [📍 Start Here](start-here.md) and choose your path!** 🚀
