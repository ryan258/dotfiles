# Karpathy Protocol for Dotfiles

## BLUF

You are not lowering your ambition. You are lowering the amount of manual code generation your nervous system has to carry.

For this dotfiles system, the job is to move from code generator to code discriminator. AI agents should handle most execution: reading files, drafting changes, writing tests, running loops, and summarizing diffs. Your scarce cognitive bandwidth goes to the work only you can do well: architecture, taste, priority, and blast-radius judgment.

The operating rule is simple: prompt, review, decide. Type code only for small surgical fixes or when the agent path is clearly more expensive than doing it directly.

---

## 1. Energy Allocation: The 80/20 Shift

MS makes stamina a hard constraint. Agents have far more loop stamina than you do, so spend your energy on direction instead of keystrokes.

- Stop typing first drafts. Treat manual code generation as an emergency fallback, not the default mode.
- Give outcomes and constraints, not implementation trivia. Point the agent at `CLAUDE.md`, `AGENTS.md`, and the relevant existing files.
- Require a test-first loop for behavioral changes. The agent should write the bats test first, confirm it fails, implement, then rerun it.
- Keep prompts declarative. Tell the agent what must be true when it is done, what rules it must obey, and what it must not touch.

Example:

```text
Create scripts/new_tool.sh following the EXECUTED script rules in CLAUDE.md.
It must process X and output Y. Write the bats test first, confirm it fails,
then implement and loop until the targeted test passes.
```

Avoid prompts that spend your energy writing the script through the agent one line at a time. If you are describing boilerplate that already exists in the repo rules, cite the rule instead.

---

## 2. Quality Control: The Bash-Intel Shield

Agents rarely fail by making obvious syntax errors now. They fail by widening scope, adding bloat, missing sourced-vs-executed boundaries, or misunderstanding how a shell helper is used.

Before non-trivial dotfiles shell changes, require a short blast-radius report built from bash-intel, bash-graph, `rg`, and git diffs:

```bash
scripts/bash_graph.sh impact validate_path
scripts/bash_graph.sh dependents scripts/lib/common.sh
scripts/bash_intel.sh symbols scripts/lib/common.sh
scripts/bash_intel.sh definition validate_path
scripts/bash_intel.sh references validate_path
scripts/bash_intel.sh workspace-symbols coach_
rg -n "source .*common\.sh|validate_path" scripts bin zsh
git status --short
git diff
git diff --cached
```

Use `scripts/bash_intel.sh` for LSP-backed symbol shape, definitions, references, and workspace search. Use `scripts/bash_graph.sh` for shell dependency topology: function definitions, conservative references, sourced files, dependents, aliases, and impact summaries. Use `rg` for manual cross-checks and git diffs to verify what changed, what is staged, and whether unrelated files were touched.

Your review job:

- Reject inexplicably large blast radius for a small request.
- Challenge new abstractions unless they clearly reduce real complexity.
- Ask whether the change could be smaller by reusing `scripts/lib/common.sh`, `config.sh`, `date_utils.sh`, or another existing helper.
- Confirm executed scripts still use strict mode and sourced files still avoid `set -euo pipefail`.
- Confirm data still flows through `$DATA_DIR` from `config.sh`, with sanitized input and validated paths.

When an agent returns a large refactor, use the shrink prompt:

```text
Can this be achieved with a smaller patch using existing functions in scripts/lib?
Keep the behavior, reduce the abstraction, and explain the remaining blast radius.
```

---

## 3. Agent Looping Strategy

Let the agent struggle with syntax, plumbing, and test loops. Intervene only when the logic, scope, or repo contract is wrong.

Use this pattern:

1. Define the goal in normal English.
2. Name the governing rules: `CLAUDE.md`, `AGENTS.md`, and any specific handbook such as `docs/products/bash-intel.md`.
3. Require the pre-flight classification: sourced file or executed script.
4. Require the bash-intel, bash-graph, and `rg` impact pass before edits when shell behavior is involved.
5. Require a focused bats test for changed behavior.
6. Review only the decision points: architecture, scope, data safety, and user impact.

Immediate intervention triggers:

- The agent adds `set -euo pipefail` to a sourced file.
- The agent removes strict mode from an executed script.
- The agent bypasses `scripts/lib/config.sh` for `.env` loading or redefines `DATA_DIR`.
- The agent writes unsanitized user input or unvalidated paths.
- The agent edits unrelated files or broadens the task without explaining why.
- The agent creates a new framework for a problem that existing shell helpers already solve.

The goal is not to supervise every line. The goal is to catch the few mistakes that can actually break the system.

---

## 4. Fog/Fatigue Protocol

When brain fog is high, do not debug an agent spiral manually. Stop the loop before it spends your remaining spoons.

Halt if any of these happen:

- The agent fails the same targeted test three times.
- The diff grows faster than the explanation.
- The agent starts deleting or rewriting unrelated files.
- The agent cannot explain the sourced-vs-executed boundary.
- You are rereading the same diff without understanding it.

Recovery sequence:

```bash
git status --short
git diff
git diff --cached
```

Then decide:

- If the changes are agent-owned and bad, revert only those specific files or hunks.
- If user changes are mixed in, stop and separate the work before reverting anything.
- If the request still matters, rest first, then restart with a narrower prompt and a smaller acceptance test.

Do not burn energy untangling a confused agent in real time. The code will still be there after rest.

---

## Daily Checklist

- [ ] Am I writing this, or orchestrating it? Default to orchestrating.
- [ ] Did I give the agent explicit success criteria and relevant repo rules?
- [ ] For shell changes, did the agent use `scripts/bash_intel.sh`, `scripts/bash_graph.sh`, and `rg` for impact?
- [ ] Did the agent classify every touched shell file as sourced or executed before editing?
- [ ] Did behavioral work start with a focused bats test?
- [ ] Did I review the abstraction for avoidable bloat?
- [ ] Did `git status --short`, `git diff`, and `git diff --cached` show only expected changes?
- [ ] Is the final state compliant with `CLAUDE.md` and `AGENTS.md`?
