# AI Quick Reference

Derived usage guide. Canonical dispatcher contract is in `../CLAUDE.md` and `../bin/README.md`.

## Primary Entry Points

```bash
dispatch <squad> "brief"
```

Direct aliases:
- `tech`
- `content`
- `strategy`
- `creative`
- `brand`
- `market`
- `research`
- `stoic`
- `narrative`
- `aicopy`
- `finance`
- `morphling`

## Supported Common Flags

- `--stream`
- `--temperature <float>`
- `--` (stop flag parsing and treat remaining args as prompt text)

Unknown flags fail fast with an error.

## Common Patterns (Copy/Paste)

```bash
# Pipe code or notes into a dispatcher
cat scripts/startday.sh | tech --stream

# Direct prompt to a specialist alias
content "Guide to energy-first planning"
strategy "Prioritize this week with constraints"
research "Compare these two model behaviors with risks"

# Use the generic entrypoint when you want explicit routing
dispatch finance "S-corp bookkeeping checklist"
dispatch creative "Three hooks for a brain-fog-safe post"
```

## Chaining Pattern

Use one dispatcher to draft, another to critique:

```bash
draft="$(content "Draft a short checklist for evening shutdown")"
printf '%s\n' "$draft" | strategy "Tighten this into 3 concrete steps"
```

## Spec Workflow Pattern

```bash
spec "startday coaching schema for anti-tinker enforcement"
tech "Implement the accepted spec in scripts/startday.sh with tests"
```

## Coach-Related Notes (startday/goodevening)

- `startday` and `goodevening` call `dhp-strategy.sh` through a timeout wrapper.
- Timeout/error paths return deterministic structured coaching output.

## Troubleshooting

- Unknown flag errors:
  - remove unsupported flags and keep only documented ones (`--stream`, `--temperature`)
- Empty or weak AI output:
  - lower temperature (`--temperature 0.2`)
  - tighten prompt to one concrete objective
- Dispatcher not found:
  - run `dotfiles-check`
  - confirm `~/dotfiles/bin` is on `PATH`
