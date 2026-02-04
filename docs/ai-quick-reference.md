# AI Quick Reference

**Purpose:** Fast, accurate usage for the AI Staff HQ dispatchers in this dotfiles repo.

**Defaults:** Models are configured via `.env` (`TECH_MODEL`, `CONTENT_MODEL`, `CREATIVE_MODEL`, etc.). Current defaults are documented in `bin/README.md` and `scripts/cheatsheet.sh`.

---

## TL;DR

```bash
# Unified entry point
dispatch tech "Fix my script"

# Direct dispatcher
 cat scripts/todo.sh | tech --stream

# Content generation
 content "Guide to energy-first planning"

# Context-aware suggestion
 ai-suggest
```

---

## Dispatcher Map

| Alias | Script | Purpose | Input |
| --- | --- | --- | --- |
| `tech` | `bin/dhp-tech.sh` | Debugging + technical analysis | stdin |
| `creative` | `bin/dhp-creative.sh` | Story packages | argument |
| `content` | `bin/dhp-content.sh` | Blog + SEO content | argument |
| `strategy` | `bin/dhp-strategy.sh` | Strategic analysis | stdin |
| `brand` | `bin/dhp-brand.sh` | Brand positioning | stdin |
| `market` | `bin/dhp-market.sh` | Market research | stdin |
| `stoic` | `bin/dhp-stoic.sh` | Stoic coaching | stdin |
| `research` | `bin/dhp-research.sh` | Knowledge synthesis | stdin |
| `narrative` | `bin/dhp-narrative.sh` | Story structure | stdin |
| `aicopy` | `bin/dhp-copy.sh` | Marketing copy | stdin |
| `morphling` | `bin/dhp-morphling.sh` | Universal adaptive | argument |
| `dispatch finance` | `bin/dhp-finance.sh` | Financial strategy | stdin/argument |

**Unified Entry:** `bin/dispatch.sh` routes `dispatch <squad>` to the correct dispatcher. It also honors AI Staff HQ `squads.json` when present. Use `dispatch finance` for the finance dispatcher (no alias).

---

## Common Flags

- `--stream` real-time output
- `--temperature <float>` override creativity
- `--max-tokens <int>` override length
- `--context` inject minimal local context (supported by `content` and blog workflows)
- `--full-context` inject full local context (supported by `content` and blog workflows)

---

## Spec Workflow (Structured Prompts)

Use `spec <dispatcher>` to open a structured template, then auto-pipe it to the dispatcher.

```bash
spec tech
spec creative
spec content
spec strategy
```

Specs are archived under `~/.config/dotfiles-data/specs/`.

---

## Advanced Features

- `ai-suggest` context-aware dispatcher recommendations
- `dhp-project "idea"` multi-specialist orchestration
- `dhp-chain creative narrative copy -- "idea"` sequential dispatcher chaining
- `dispatch <squad>` unified entry with aliases or squads

---

## Usage Patterns

**Piped input (stdin dispatchers):**
```bash
cat scripts/todo.sh | tech
cat notes.md | strategy
```

**Argument input (argument dispatchers):**
```bash
creative "A developer learning to pace energy"
content "Guide to brain fog workflows"
```

**Streaming output:**
```bash
cat large-script.sh | tech --stream
creative --stream "Astronaut finds sentient fog"
```

**Temperature control:**
```bash
content --temperature 0.35 "Deterministic guide output"
creative --temperature 0.85 "High-creativity story generation"
```

---

## Workflow Integrations

**Todo delegation:**
```bash
todo debug 1
todo delegate 3 creative
```

**Journal analysis:**
```bash
journal analyze
journal mood
journal themes
```

**Blog workflows:**
```bash
blog generate -p "Calm Coach" -a guide -s guides/brain-fog "Energy-first planning"
blog refine path/to/post.md
```

---

## Troubleshooting

- Ensure `OPENROUTER_API_KEY` is set in `.env`.
- Verify dispatchers with `dotfiles-check`.
- Read full dispatcher docs: `bin/README.md`.

---

## Related Docs

- [Start Here](start-here.md)
- [Best Practices](best-practices.md)
- [Dispatcher Docs](../bin/README.md)
- [Troubleshooting](../TROUBLESHOOTING.md)
