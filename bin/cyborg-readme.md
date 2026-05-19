# Cyborg Agent Boundary

The Cyborg implementation and full operator guide have moved out of root
dotfiles.

- Sibling repo: `~/Projects/cyborg-agent`
- Dotfiles wrapper: `bin/cyborg`
- Aliases preserved: `cyborg`, `ap`, `apy`, `apb`, `apby`, `apbp`, `apbpy`, `apc`
- Full guide: `~/Projects/cyborg-agent/README.md`

Root dotfiles keeps the wrapper so existing commands continue to resolve.
If the sibling repo is missing, direct `cyborg` commands print a short setup
message instead of a Python stack trace.
