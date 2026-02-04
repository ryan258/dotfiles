# Clipboard Power Moves on macOS

macOS ships with `pbcopy` and `pbpaste`, two tiny commands that turn the system clipboard into a first-class shell tool. Combined with pipes and redirects, they let you capture command output, pre-process snippets, and paste them back anywhere without touching the mouse.

## TL;DR

- Use `pbcopy` and `pbpaste` to move data through pipelines.
- Use `clip save` / `clip load` for reusable snippets.
- Snippets live in `~/.config/dotfiles-data/clipboard_history.txt`.

## Essentials

- **Copy anything:** `echo "Hello" | pbcopy` or `pbcopy < path/to/file`
- **Paste in scripts:** `pbpaste` prints the clipboard to stdout, so you can redirect or pipe it (`pbpaste > notes.txt`, `pbpaste | jq '.'`).
- **Stay in the shell:** Every example below avoids manual copy/paste steps—perfect for low-energy days.

## Capture Output Fast

| Goal | Command |
| ---- | ------- |
| Copy command output | `ls -al | pbcopy`
| Copy the last command’s output | `!! | pbcopy` (requires the output to still be in history, use with care)
| Copy a JSON response | `curl https://api.example.com | pbcopy`
| Copy git diff for review | `git diff | pbcopy`
| Copy formatted date | `date '+%Y-%m-%d' | pbcopy`

Tip: pair with aliases like `copy` or `copyfile` that already wrap `pbcopy`.

## Transform Before Copying

Pipes let you massage output *before* it hits the clipboard:

```bash
rg "TODO" -n src | sort | pbcopy
ps aux | sort -rk 3 | head -n 5 | pbcopy
jq '.items[] | {name, url}' bookmarks.json | pbcopy
```

## Use Clipboard Content in Pipelines

Once the clipboard holds data, `pbpaste` drops it into any pipeline:

```bash
pbpaste | sed 's/http/https/g' | pbcopy        # replace and put back
pbpaste | code -                               # open in VS Code without a temp file
pbpaste | tee backup.txt | less                # view while saving to a file
pbpaste | sh                                   # run a copied shell snippet (only if you trust it!)
pbpaste | jq '.summary'                        # inspect a copied JSON blob
```

## Saved Snippet Toolbox (`clip`)

The repo ships with a `clip` helper that stores clipboard snippets in `~/.config/dotfiles-data/clipboard_history.txt`:

```bash
clip save standup    # Save the current clipboard as "standup"
clip list            # Preview the first part of each saved clip
clip load standup    # Restore the snippet to your clipboard
```

- Entries are stored as pipe-delimited lines: `YYYY-MM-DD HH:MM:SS|name|content`.
- Multi-line content is stored with `\n` escapes.
- `clip peek` gives you a quick look at whatever is currently sitting in the clipboard.

## Real-World Workflows

### Save a Command’s Output and Share It

```bash
rg "search term" src | pbcopy          # copy the interesting lines
pbpaste > findings.txt                 # drop them into a file
mail -s "FYI" teammate@example.com < findings.txt
```

### Capture Logs, Clean Them, and Paste into Slack

```bash
tail -n 200 logs/app.log \
  | rg -v "DEBUG" \
  | sed 's/[0-9]\{4\}-[0-9\-: ]\+/<timestamp>/g' \
  | pbcopy
# ⌘+V in Slack (already formatted)
```

### Turn Clipboard HTML into Plain Text Notes

```bash
pbpaste | textutil -stdin -convert txt -stdout | pbcopy
pbpaste >> notes/inbox.md
```

### Quick JSON Pretty-Print for API Responses

```bash
curl -s https://api.example.com/things | pbcopy
pbpaste | jq '.' | pbcopy
pbpaste > responses/pretty.json
```

### Edit Copied Text in Vim Without Temporary Files

```bash
pbpaste > /tmp/clipboard.$$
vim /tmp/clipboard.$$
pbcopy < /tmp/clipboard.$$
rm /tmp/clipboard.$$
```

## Round-Trip Macros

Create reusable helpers to round-trip clipboard content through a formatter or sanitizer:

```bash
function clipfmt() {
    pbpaste | "$@" | pbcopy
}
clipfmt jq '.'             # pretty-print JSON in place
clipfmt prettier --parser markdown
```

## Integrations in This Repo

- `copy`, `paste`, `copyfile`, and `copyfolder` aliases (`zsh/aliases.zsh`).
- `clip`, `clip save`, `clip load`, `clip list`, and `clip peek` wrap `clipboard_manager.sh` (supports executable snippets for dynamic output).
- `graballtext` pairs well with `pbcopy` for quick sharing: `graballtext && pbcopy < all_text_contents.txt`.

## Troubleshooting

- `pbcopy` reads until EOF—remember to press `Ctrl+D` when typing interactively.
- Large blobs (> few MB) can bloat the clipboard; clear with `pbcopy < /dev/null`.
- Remote shells (e.g., SSH) do not have access to your local clipboard; use tools like `pbcopy` via `ssh -t` or rely on `tmux` copy modes instead.

---

## Related Docs

- [Start Here](start-here.md)
- [Daily Cheat Sheet](daily-cheatsheet.md)
- [Best Practices](best-practices.md)
- [Troubleshooting](../TROUBLESHOOTING.md)

---

Stay in flow by letting the clipboard handle the shuffling—your hands stay on the keyboard, and your brain stays focused.
