# Obsidian Observer Boundary

The Obsidian observer implementation has moved out of root dotfiles.

- Sibling repo: `~/Projects/obsidian-observer`
- Dotfiles wrapper: `scripts/observer.sh`
- Alias preserved: `observer`
- Full operator guide: `~/Projects/obsidian-observer/README.md`

Root dotfiles keeps only the compatibility wrapper so daily commands can run
without requiring the optional Observer product to be installed. Direct
`observer` commands print a setup message when the sibling repo is missing.
Daily-loop hooks degrade quietly by default and can be made verbose with
`OBSERVER_WRAPPER_VERBOSE=true`.
