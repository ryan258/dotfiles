# bash_intel — Shell Code Intelligence for Dotfiles

`scripts/bash_intel.sh` is the canonical code-intelligence tool for this repo. It wraps the [bash-language-server](https://github.com/bash-lsp/bash-language-server) over the LSP protocol and surfaces symbols, definitions, references, and workspace searches across every `.sh`, `.bash`, and `.zsh` file in the project.

`scripts/bash_graph.sh` is the companion dependency graph for the same shell surface. Use it when you need topology that bash-language-server does not model: `source`/`.` edges, file dependents, aliases, conservative call references, and impact summaries.

> **Why bash_intel and not GitNexus?** GitNexus is a Python-first symbol indexer. It does not parse bash/zsh function definitions, so on a codebase that is ~95% shell it returned nothing useful. GitNexus is no longer run against this repo and no `.gitnexus/` index is kept here. (The `scripts/gitnexus.sh` wrapper is retained as a portable shortcut for use against other Python-heavy projects — it is intentionally not used against dotfiles.) For shell symbol work in this repo, `bash_intel.sh` is the only tool you need at the language-server level.

---

## 1. Architecture

```
scripts/bash_intel.sh         # bash entrypoint (validates args, dispatches)
        │
        ▼
scripts/bash_intel_client.mjs # Node LSP client (spawns server, JSON output)
        │
        ▼
bash-language-server          # LSP server (resolved via env, PATH, or npx)
```

- **Entrypoint** (`bash_intel.sh`) — validates the command and target file, then forks the Node client. Strict-mode bash, sources `lib/common.sh`, returns `EXIT_INVALID_ARGS` (2) for usage errors and `EXIT_FILE_NOT_FOUND` (4) for missing files.
- **LSP client** (`bash_intel_client.mjs`) — speaks JSON-RPC to bash-language-server, opens documents with `languageId: "shellscript"`, walks the project to gather `.sh|.bash|.zsh` files for fallback definition lookups, and prints results as JSON.
- **Symbol kinds** — the client maps LSP `SymbolKind` integers to human-readable strings (`Function`, `Variable`, `Constant`, …) before printing.
- **Server resolution order** — `BASH_LANGUAGE_SERVER_BIN` → `bash-language-server` on `PATH` → `npx --yes bash-language-server start`.

---

## 2. Installation & First-Run Setup

The repo does not commit a copy of bash-language-server. Pick one of:

```bash
# Recommended: install once, fast cold start
npm install -g bash-language-server

# Or pin a project-local copy and point bash_intel at it
npm install --prefix ~/.local/bls bash-language-server
export BASH_LANGUAGE_SERVER_BIN="$HOME/.local/bls/node_modules/.bin/bash-language-server"
```

Verify the wiring in two steps. `check` only prints the *configured* server command — it does not start the server, so it cannot catch a stale `BASH_LANGUAGE_SERVER_BIN` or a broken npm install:

```bash
# 1. Config probe — confirms which binary will be used
scripts/bash_intel.sh check
# Expected JSON: { "command": "check", "root": "...dotfiles", "timeoutMs": 30000,
#                  "server": { "command": "...", "args": ["start"], "source": "PATH" } }

# 2. Real smoke test — actually starts the LSP and parses a file
scripts/bash_intel.sh symbols scripts/lib/common.sh | jq '.symbols | length'
# Expected: a positive integer (number of top-level symbols)
```

If `source` is `npx`, the first call will pay a cold-start penalty (10–30 s on a fresh machine). Bump the timeout for the first symbols call: `BASH_INTEL_TIMEOUT_MS=60000 scripts/bash_intel.sh symbols scripts/lib/common.sh`.

---

## 3. Commands

All commands print JSON on stdout. Pipe to `jq` for ergonomic queries.

| Command | Args | Purpose |
| --- | --- | --- |
| `check` | — | Print the resolved server command, root, and timeout. **Config probe only** — it does not launch the server, so a wrong `BASH_LANGUAGE_SERVER_BIN` still prints "OK". For a real smoke test, run a `symbols` call against a known file (see §2). |
| `symbols <file>` | one shell file | Document outline (functions, vars, kinds, line ranges). |
| `outline <file>` | alias for `symbols` | Same as above. |
| `workspace-symbols <query>` | free text | Substring search across the project's symbol index. |
| `definition <symbol>` | exact name | Jump to the file/line where the symbol is defined. |
| `references <symbol>` | exact name | List call sites and re-uses (includes the declaration). |
| `bash_graph.sh scan` | — | Print the shell dependency graph: files, functions, sources, references, aliases. |
| `bash_graph.sh impact <symbol-or-file>` | exact name or path | Summarize definitions, references, sources, and dependents. |
| `bash_graph.sh sources <file>` / `dependents <file>` | one shell file | Inspect source edges in either direction. |

### Output shape (stable contract)

```json
{
  "command": "symbols",
  "file": "/abs/path/scripts/lib/common.sh",
  "symbols": [
    { "name": "validate_path", "kind": "Function",
      "range": { "startLine": 142, "startColumn": 1, "endLine": 168, "endColumn": 2 },
      "children": [] }
  ]
}
```

`workspace-symbols`, `definition`, and `references` follow the same envelope (`command`, plus `symbols` / `definitions` / `references` arrays). Lines and columns are **1-indexed** for direct use with `code:line` jumps.

### File acceptance

`bash_intel.sh symbols` accepts:
- Any file with extension `.sh`, `.bash`, or `.zsh`
- Any file whose first line shebang matches `(ba|z|k)?sh|shell`

Anything else is rejected with `EXIT_INVALID_ARGS`. This guards against accidentally pointing the LSP at Python or Markdown.

---

## 4. Optimal Workflows for This Project

The dotfiles repo has three shell tiers — each tier benefits from a different bash_intel pattern.

### 4.1 Sourced libraries (`scripts/lib/*.sh`, `zsh/aliases.zsh`)

Goal: understand the public surface before editing.

```bash
# 1. List everything the library exports
scripts/bash_intel.sh symbols scripts/lib/common.sh | jq '.symbols[].name'

# 2. Find every caller of a helper before you rename it
scripts/bash_intel.sh references validate_path | jq '.references[].file' | sort -u

# 3. Confirm a helper isn't already defined elsewhere
scripts/bash_intel.sh workspace-symbols sanitize_input
```

When the rule "libraries must not self-source siblings" comes up, use `references` to confirm a helper has callers in `scripts/` rather than only inside `scripts/lib/` — that tells you whether to expose it from `common.sh` or keep it local.

### 4.2 Executed scripts (`scripts/*.sh`, `bin/dhp-*.sh`)

Goal: trace a workflow end-to-end without losing the sourced/executed boundary.

```bash
# Outline an executed script to see its main + helpers
scripts/bash_intel.sh symbols scripts/startday.sh

# Find where a coach helper is called from across both tiers
scripts/bash_intel.sh references coaching_run_briefing
```

Pair with `rg --type sh "source .*coaching\.sh"` to confirm which scripts pull in the facade — bash-language-server doesn't model `source` edges, so you still need `rg` for sourcing topology. This is the LSP's main blind spot in this repo.

For a generated topology pass, use `scripts/bash_graph.sh dependents scripts/lib/coaching.sh` or `scripts/bash_graph.sh impact coaching_run_briefing`, then use `rg` to cross-check dynamic or unusual shell patterns.

### 4.6 Dependency graph (`scripts/bash_graph.sh`)

Goal: answer source/dependency questions that the LSP cannot answer.

```bash
# Before deleting or renaming a helper
scripts/bash_graph.sh impact validate_path

# What does this script source, and which helpers does it define/use?
scripts/bash_graph.sh impact scripts/startday.sh

# Canonical source graph answer: who pulls in this library?
scripts/bash_graph.sh dependents scripts/lib/common.sh

# Which libraries does this script source?
scripts/bash_graph.sh sources scripts/startday.sh

# Where is this function defined according to the graph parser?
scripts/bash_graph.sh functions validate_path
```

Reach for `bash_intel.sh` when you need language-server symbol data. Reach for `bash_graph.sh` when the question is dependency topology: sourced files, dependents, aliases, and a quick impact summary. For deletion work, use both: `bash_graph.sh impact <name>` first, then `bash_intel.sh references <name>` and `rg -nF '<name>'` to catch dynamic or unusual shell patterns.

### 4.3 Coach stack (`scripts/lib/coach_*.sh` + `coaching.sh` facade)

Goal: keep the facade thin, push logic into `coach_*` files.

```bash
# Confirm a new function exists in coach_ops but not yet in the facade
scripts/bash_intel.sh workspace-symbols coach_metrics_

# Compare facade exports vs underlying ops
diff \
  <(scripts/bash_intel.sh symbols scripts/lib/coaching.sh   | jq -r '.symbols[].name' | sort) \
  <(scripts/bash_intel.sh symbols scripts/lib/coach_ops.sh  | jq -r '.symbols[].name' | sort)
```

### 4.4 Pre-flight before refactors

The repo's pre-flight rule (`CLAUDE.md` §"Agent Pre-Flight") demands you classify a file as sourced vs executed before editing. bash_intel does not classify the file, but the `symbols` output makes the intent obvious: a sourced library exposes named functions and uses `return`; an executed script usually has a `main` and uses `exit`. Use it as a sanity check, not a replacement for the header inspection.

### 4.5 Pre-flight before deletions

```bash
# Will deleting this break anyone?
scripts/bash_intel.sh references _legacy_helper
# If references == [declaration only], you can probably delete it.
# Cross-check with rg -nF and remember the §7 blind spots.
```

---

## 5. Performance Tuning

| Setting | Default | When to change |
| --- | --- | --- |
| `BASH_INTEL_TIMEOUT_MS` | `30000` | Raise to `60000` on first cold `npx` boot or under heavy load. |
| `BASH_LANGUAGE_SERVER_BIN` | unset | Set to a globally installed binary to skip `npx` startup entirely (saves ~10 s/call). |
| `BASH_INTEL_CLIENT` | repo client | Override only for tests or to swap in a debug build of the Node client. |

Tips:
- A globally installed `bash-language-server` is the single biggest win for repeated calls — go from ~10–30 s cold start down to ~1–3 s warm.
- Each invocation spins up its own LSP process (no daemon). For batch operations, prefer `workspace-symbols` over many `symbols` calls — the client opens the server once per command.
- `references` runs a regex-based fallback to locate the declaration before asking the server for references. This means symbols that appear only in comments will not produce false-positive declaration hits, but symbols defined inside string heredocs will be missed.

---

## 6. Recipes

### "Where is this function defined?"

```bash
scripts/bash_intel.sh definition coaching_run_briefing | jq '.definitions[0]'
```

### "What does a sourced library expose publicly?"

```bash
scripts/bash_intel.sh symbols scripts/lib/oauth.sh \
  | jq -r '.symbols[] | select(.kind == "Function") | .name' \
  | grep -v '^_'   # drop conventional private helpers
```

### "Which scripts call this helper?"

```bash
scripts/bash_intel.sh references log_warn \
  | jq -r '.references[] | "\(.file):\(.range.startLine)"'
```

### "Find every coach_* function across the workspace"

```bash
scripts/bash_intel.sh workspace-symbols coach_ \
  | jq -r '.symbols[] | "\(.location.file):\(.location.range.startLine)\t\(.name)"'
```

### "Diff the public surface before and after a refactor"

```bash
git show HEAD:scripts/lib/coaching.sh > /tmp/coaching.before.sh
scripts/bash_intel.sh symbols /tmp/coaching.before.sh | jq -r '.symbols[].name' | sort > /tmp/before.txt
scripts/bash_intel.sh symbols scripts/lib/coaching.sh | jq -r '.symbols[].name' | sort > /tmp/after.txt
diff -u /tmp/before.txt /tmp/after.txt
```

---

## 7. Limitations & Known Blind Spots

bash-language-server is a static analyzer for bash; it is not omniscient. Plan around these gaps:

1. **No `source`/`.` graph.** It opens one document at a time. For "what files does this script source?" use `rg "^\s*(source|\.)\s+" path/to/script.sh`.
2. **Dynamic dispatch is opaque.** Function calls built via `eval`, `${var}`, or indirect arrays are invisible. Audit those by inspection — and remember the project's no-`eval`-with-user-input rule.
3. **Zsh-specific syntax** (e.g., `${(s::)var}`, glob qualifiers) may parse imperfectly. `zsh/aliases.zsh` works for symbols and definitions but expect occasional missed references.
4. **Heredoc-defined symbols** are not extracted. Any function "defined" inside a here-string for templating is invisible.
5. **No type info.** It is a symbol indexer, not a type checker. Use `shellcheck` for lint, `bats` for behavior.

`bash_graph.sh` is intentionally conservative too: it uses static shell regexes, resolves common `$SCRIPT_DIR`/`$DOTFILES_DIR` source paths, and only reports function references it can see directly. Graph references are first-call-per-line and can miss chained helpers such as `foo=$(a); b; c`. Treat it as a blast-radius reducer, not proof that no dynamic caller exists.

---

## 8. Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `bash-language-server is not installed and npx is unavailable` | No npm at all | `brew install node` then re-run `check`. |
| `Timed out waiting for initialize` | Cold `npx` cache | Re-run with a longer timeout against a real command (`check` does not start the server): `BASH_INTEL_TIMEOUT_MS=60000 scripts/bash_intel.sh symbols scripts/lib/common.sh`. Or install bls globally to avoid the cold start entirely. |
| `Error: Not a recognized shell file` | Missing extension and shebang | Add a shebang or rename to `.sh`/`.bash`/`.zsh`. |
| Empty `references` array | Symbol used dynamically, or only declared | Cross-check with `rg -nF '<symbol>'`. |
| Stale results after editing a file | LSP opened a snapshot at request time, not yours | Re-run the command — each invocation re-reads the file from disk. |
| `Error: bash intelligence client is not executable` | `bash_intel_client.mjs` lost its execute bit | `chmod +x scripts/bash_intel_client.mjs`. |

---

## 9. Testing

`tests/test_bash_intel.sh` runs against a stub LSP via `BASH_INTEL_CLIENT`. Set the env var to a fake client when writing new bats tests so you don't need a real `bash-language-server` in CI:

```bash
BASH_INTEL_CLIENT="$TEST_DIR/fake_client.sh" \
  run "$TEST_DIR/scripts/bash_intel.sh" symbols "$TEST_DIR/scripts/lib/common.sh"
```

Follow the standard test-first workflow from `CLAUDE.md` §Testing for any change to `bash_intel.sh` or `bash_intel_client.mjs`.

---

## 10. Quick Reference Card

```bash
# Health
scripts/bash_intel.sh check

# One file
scripts/bash_intel.sh symbols scripts/lib/coaching.sh

# Across the repo
scripts/bash_intel.sh workspace-symbols coach_

# Find / trace
scripts/bash_intel.sh definition log_error
scripts/bash_intel.sh references  log_error

# Speed up
export BASH_LANGUAGE_SERVER_BIN="$(which bash-language-server)"
export BASH_INTEL_TIMEOUT_MS=60000
```

Add as needed to `zsh/aliases.zsh`:

```bash
alias bi='scripts/bash_intel.sh'
alias bisym='scripts/bash_intel.sh symbols'
alias biws='scripts/bash_intel.sh workspace-symbols'
alias bidef='scripts/bash_intel.sh definition'
alias biref='scripts/bash_intel.sh references'
```
