# Morphling -- Shapeshifting Universal Agent

Morphling is the only AI-Staff-HQ specialist with tool access. It operates as a LangChain ReAct agent that can read files, write files, list directories, and execute shell commands -- giving it closed-loop lead-developer capabilities. It analyzes the problem, shapeshifts into the ideal persona (Senior Rust Engineer, Data Scientist, Direct Response Copywriter, etc.), and executes.

## Modes

### Direct Mode (default)

Runs the full ReAct agent through `ai-staff-hq/tools/activate.py` with four tools enabled. The agent reasons step-by-step, calling tools as needed, reading output, and iterating until the task is complete.

**Tools:**

| Tool | Description |
|------|-------------|
| `read_file` | Read a file from the local filesystem |
| `write_file` | Write content to a file (creates parent directories) |
| `list_directory` | List files and directories at a given path |
| `run_command` | Execute a shell command with 60-second timeout, output truncated to 10k chars |

All paths resolve relative to `USER_CWD` when that environment variable is set.

**Session persistence:** Conversations are saved to `~/.ai-staff-hq/sessions/morphling/<session_id>.json` and can be resumed.

### Swarm Mode (`--swarm`)

Delegates to `bin/dhp-morphling.sh`, the standard dispatcher. This mode gathers local context (git branch, status, directory tree, working directory) and sends a single prompt through OpenRouter. It produces one-shot, context-rich analysis without tool access.

Used by `cyborg auto` for pre-analysis briefs before the main autopilot pipeline.

## CLI Usage

```bash
# Interactive session (direct mode — tool-capable ReAct agent)
bin/morphling.sh

# One-shot query (direct mode)
bin/morphling.sh "refactor this module to use dependency injection"

# Pipe input
echo "explain this error" | bin/morphling.sh

# Query flag
bin/morphling.sh -q "optimize the hot loop in parser.rs"

# Resume last session
bin/morphling.sh --resume last

# Resume specific session
bin/morphling.sh --resume 20260301_143022_a1b2c3d4

# Override model (direct mode only — CLI flag)
bin/morphling.sh --model "anthropic/claude-sonnet-4"

# Set temperature
bin/morphling.sh --temperature 0.3

# Initial prompt then stay interactive
bin/morphling.sh --initial-prompt "you are working on a Go CLI project"

# Swarm mode via alias (one-shot context-rich analysis, no tool access)
morphling "what patterns does this codebase use?"

# Swarm mode with streaming
morphling --stream "analyze the error handling strategy"

# Swarm mode explicitly from direct launcher
bin/morphling.sh --swarm "analyze the error handling strategy"
```

## Configuration

| Variable | Purpose | Default |
|----------|---------|---------|
| `MORPHLING_MODEL` | Model for swarm mode (`dhp-morphling.sh`) | Falls back to `DEFAULT_MODEL` |
| `DHP_MORPHLING_OUTPUT_DIR` | Output directory for swarm mode logs | `~/Documents/AI_Staff_HQ_Outputs/Morphling` |

Set these in your `.env` file. See `.env.example` for the template.

**Note:** Direct mode (`bin/morphling.sh`) does not read `MORPHLING_MODEL` from the environment. Use the `--model` CLI flag to override the model in direct mode.

## How `cyborg auto --build` Uses Morphling

When you run `cyborg auto --build "your idea"`, the build pipeline in `scripts/cyborg_build.py` uses the Morphling persona (via direct OpenRouter calls, not the ReAct agent) to:

1. **Scaffold** -- Morphling picks the best language, framework, and tooling, then returns a complete project as structured JSON (files map, name, description). The scaffold is written to `~/Projects/<name>/`, git-initialized, and committed.

2. **Verify and fix** -- The pipeline runs install and test commands against the scaffold. If they fail, error output is sent back to the Morphling persona for correction. This build-verify-fix loop runs up to 3 rounds.

3. **Enhance metadata** -- Before publishing, Morphling generates improved package metadata (description, keywords, homepage URL) for the target registry.

4. **Publish** (with `--publish`) -- After verification passes, the pipeline publishes to the appropriate ecosystem registry (npm, PyPI, crates.io, or GitHub Releases for Go).

All git commits during the build pipeline are authored as `Morphling <morphling@cyborg-lab>`.

## Architecture

```
bin/morphling.sh          Shell launcher, routes between modes
  |
  +-- direct mode         ai-staff-hq/tools/activate.py morphling
  |     |
  |     +-- core.py       Loads morphling.yaml, attaches 4 tools
  |     |
  |     +-- ReAct agent   LangChain create_react_agent with tool loop
  |
  +-- --swarm mode        bin/dhp-morphling.sh
        |
        +-- dhp-shared.sh Standard dispatcher framework
```

The specialist definition lives at `ai-staff-hq/staff/meta/morphling.yaml`.

## Shell Alias

The `morphling` alias in `zsh/aliases.zsh` points to `bin/dhp-morphling.sh` (swarm mode -- no tool access). For direct mode with full ReAct tool capabilities, invoke `bin/morphling.sh` explicitly.

## Related Files

- [`bin/morphling.sh`](bin/morphling.sh) -- Direct mode launcher
- [`bin/dhp-morphling.sh`](bin/dhp-morphling.sh) -- Swarm mode dispatcher
- [`ai-staff-hq/tools/engine/capabilities.py`](ai-staff-hq/tools/engine/capabilities.py) -- Tool implementations
- [`ai-staff-hq/staff/meta/morphling.yaml`](ai-staff-hq/staff/meta/morphling.yaml) -- Specialist definition
- [`scripts/cyborg_build.py`](scripts/cyborg_build.py) -- Build pipeline using Morphling persona
- [`bin/autopilot-readme.md`](bin/autopilot-readme.md) -- Autopilot convergence architecture
