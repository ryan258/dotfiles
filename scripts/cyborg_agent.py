#!/usr/bin/env python3
"""Interactive Cyborg Lab ingest agent.

This is the brain of the `cyborg` command.  It scans a source repo,
builds a content map for a Hugo blog (Cyborg Lab), generates near-
publishable drafts, and lets the user revise them before writing
anything to disk.  Everything is interactive and session-based so
work can be saved and resumed later.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import shlex
import subprocess
import sys
import textwrap
import urllib.error
import urllib.request
import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, List, Optional, Tuple

# readline gives us arrow-key history in the interactive prompt.
# It is optional; some systems do not ship it.
try:
    import readline  # noqa: F401
except ImportError:  # pragma: no cover - readline is optional on some systems
    readline = None  # type: ignore[assignment]


# --- Global constants ---

# Bump this number when the session JSON shape changes.
SESSION_VERSION = 2
# Keep only the last N exchanges in the AI conversation window.
MAX_CHAT_HISTORY = 8
# Where we send AI requests (OpenRouter acts as a model gateway).
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
# How long shell commands are allowed to run before we stop them.
DEFAULT_COMMAND_TIMEOUT_SECONDS = 30
# GitNexus analyze can be slow on big repos, so it gets extra time.
GITNEXUS_ANALYZE_TIMEOUT_SECONDS = 180
# Cyborg uses the same pinned GitNexus package as the shell helper.
GITNEXUS_PACKAGE = os.environ.get("CYBORG_GITNEXUS_PACKAGE", "gitnexus@1.4.7")
GITNEXUS_NPX_COMMAND = ["npx", "--yes", f"--package={GITNEXUS_PACKAGE}", "gitnexus"]
# If the GitNexus index is older than this, we call it "stale."
GITNEXUS_STALE_HOURS = 72
# Repos bigger than 100 MB of source/docs skip auto-enhancement.
GITNEXUS_SIZE_THRESHOLD_BYTES = 100 * 1024 * 1024
# How many execution flows / symbols to ask GitNexus for at once.
GITNEXUS_QUERY_LIMIT = 4
# Common places where the Cyborg Lab blog repo might live on disk.
KNOWN_BLOG_PATHS = (
    Path.home() / "Projects" / "cyborg" / "my-ms-ai-blog",
    Path.home() / "Projects" / "cyborg-lab",
)
# If a folder contains one of these files, it is probably a project.
PROJECT_FILE_MARKERS = {
    "pyproject.toml",
    "package.json",
    "package-lock.json",
    "requirements.txt",
    "Pipfile",
    "setup.py",
    "Cargo.toml",
    "go.mod",
    "Makefile",
    "justfile",
    "Gemfile",
    "composer.json",
    ".gitignore",
}
# If a folder contains one of these sub-folders, it is probably a project.
PROJECT_DIR_MARKERS = {"src", "lib", "app", "tests", "docs", ".github"}
# File endings we treat as "source code or documentation" when scanning.
SOURCE_FILE_SUFFIXES = {
    ".py",
    ".js",
    ".ts",
    ".tsx",
    ".jsx",
    ".go",
    ".rs",
    ".rb",
    ".php",
    ".java",
    ".c",
    ".cc",
    ".cpp",
    ".h",
    ".hpp",
    ".sh",
    ".md",
    ".txt",
    ".rst",
    ".toml",
    ".yaml",
    ".yml",
    ".json",
}
# Files that are plain text even though they have no file extension.
TEXT_FILE_NAMES = {"Makefile", "justfile", "Dockerfile"}
# The blog organizes workflows into named "tracks" (topic buckets).
WORKFLOW_TRACKS = (
    "AI Frameworks",
    "Brain Fog Systems",
    "Decision Systems",
    "Keyboard Efficiency",
    "Productivity Systems",
    "Thinking Frameworks",
)
# Each content type maps to a Hugo directory, a unit description,
# and a tone note so the AI (or heuristic) knows how to write it.
CONTENT_TYPES: dict[str, dict[str, str]] = {
    "project": {
        "dir": "content/projects",
        "unit": "One real-world mission",
        "tone": "mission-level integration page",
    },
    "workflow": {
        "dir": "content/workflows/{track_slug}",
        "unit": "One repeatable process",
        "tone": "execution-first procedural page",
    },
    "artifact": {
        "dir": "content/artifacts",
        "unit": "One reusable deliverable",
        "tone": "copy-ready output page",
    },
    "log": {
        "dir": "content/log",
        "unit": "One tested observation or sourced point of view",
        "tone": "dated field report or narrative article",
    },
    "reference": {
        "dir": "content/reference",
        "unit": "One fast lookup surface",
        "tone": "index or lookup page",
    },
    "protocol": {
        "dir": "content/systems/protocols",
        "unit": "One deterministic prompt contract",
        "tone": "prompt/system instruction page",
    },
    "stack": {
        "dir": "content/stacks",
        "unit": "One friction-removal setup page",
        "tone": "integration/config page",
    },
}
# Default model if none is provided via environment.
MODEL_FALLBACK = "nvidia/nemotron-3-super-120b-a12b:free"
# ---------------------------------------------------------------------------
# Morphling ↔ Cyborg convergence constants
# ---------------------------------------------------------------------------
# Morphling is the dotfiles system's "shapeshifting universal specialist"
# dispatcher (bin/morphling.sh, bin/dhp-morphling.sh).  When Cyborg runs in
# autopilot mode (`cyborg auto`), the two agents converge:
#
#   1. PRE-ANALYSIS (shell-side, bin/cyborg):
#      The shell launcher pipes a structured prompt to morphling.sh, which
#      shapeshifts into a domain expert for the target repo and returns a
#      concise brief.  That brief is exported as CYBORG_MORPHLING_BRIEF so
#      run_autopilot() can inject it into the Cyborg session's article_text.
#
#   2. BUILD MODE (Python-side, build_project_from_idea):
#      When --build is passed, the Python agent calls OpenRouter directly
#      with a Morphling-persona system prompt (MORPHLING_BUILD_PROMPT).
#      The AI returns a JSON scaffold, and we write the files to disk,
#      git-init the result, and hand the freshly-built repo path to the
#      normal Cyborg autopilot pipeline for documentation.
#
# The two paths are mutually exclusive: --build skips pre-analysis (the
# shell launcher checks for --build and sets _skip_morphling=true).
# ---------------------------------------------------------------------------

# Default directory where `--build` scaffolds new projects.
# Overridable with `--projects-dir`.
DEFAULT_PROJECTS_DIR = Path.home() / "Projects"

# System prompt for the Morphling build step (path 2 above).
# Instructs the AI to shapeshift into a senior engineer and return a
# complete project as a single JSON object.  The JSON shape is strict:
# { "name": slug, "description": string, "files": { path: contents } }.
# build_project_from_idea() parses this and writes the files to disk.
MORPHLING_BUILD_PROMPT = textwrap.dedent(
    """
    You are the Morphling — a shapeshifting universal specialist.

    SHAPESHIFT into the ideal senior engineer for this project idea.
    Generate a complete, working project scaffold returned as a single
    JSON object.

    Return JSON with exactly this shape:
    {
      "name": "project-name-slug",
      "description": "One-line description of the project",
      "files": {
        "relative/path/file.py": "full file contents...",
        "README.md": "readme contents..."
      }
    }

    Rules:
    - The "name" must be a lowercase slug (letters, numbers, hyphens only).
    - The project must be functional and runnable.
    - Include a README.md with a summary and basic setup/usage instructions.
    - Include basic tests or a test placeholder when the language supports it.
    - Keep it focused: minimum viable project, not over-engineered.
    - Use the most appropriate language, framework, and tools for the idea.
    - File paths are relative to the project root (no leading slash).
    - Do NOT include binary files, images, or lock files.
    - Every file must contain real, working code — no placeholder comments.
    """
).strip()
# The system prompt sent to the AI model for every request.
# It tells the model what role it plays and what rules to follow.
SYSTEM_CONTRACT = textwrap.dedent(
    """
    You are the Cyborg Lab ingest agent.

    Hard constraints:
    - Target repository is the Cyborg Lab Hugo site.
    - One file = one job. Split pages when needed.
    - Prefer these content types: project, workflow, artifact, log, reference.
    - Only suggest protocol or stack when clearly justified by the source material.
    - Default voice is strict Cyborg Lab documentation voice.
    - Use log/article mode only when the material is better as a narrative field report.
    - Repo is source of truth when both repo and article are supplied.
    - Preserve user claims and source links unless there is a clear conflict.
    - Suggest edits to existing Cyborg Lab pages conservatively. Prefer merge/update/link over duplicates.
    - Output must respect Hugo markdown. No H1 headings in body, visible code blocks only.
    - Drafts must be near publishable and use draft: true.
    - Descriptions should be action-oriented and roughly 140-160 characters.
    - Repo-backed pages should surface the repo link early in the body.
    """
).strip()
# Extra instructions appended when the user sends free-form notes.
INTAKE_GUIDANCE = textwrap.dedent(
    """
    The session is interactive and collaborative.
    When the user gives new notes:
    - acknowledge what changed
    - reflect it into the likely content map or editorial direction
    - ask at most one useful follow-up question when needed
    - when you ask a follow-up question, prefer A/B/C/D choices plus E for custom
    - make the option labels explicit with `A.`, `B.`, `C.`, `D.`, and `E.`
    - when the user replies with only a letter, interpret it against your most recent A-E question
    - recommend the next command only when it is timely
    """
).strip()
CODE_IMPROVEMENT_CONTRACT = textwrap.dedent(
    """
    You are a senior software engineer doing a code-first repo improvement pass.

    Hard constraints:
    - Prioritize real source-repo improvements before documentation polish.
    - Use the repo scan, GitNexus graph signals, and Morphling context when available.
    - Prefer concrete, testable improvements over broad rewrites.
    - Keep scope tight: a few high-signal changes are better than a vague backlog.
    - When staging code edits, only touch the files explicitly allowed in the prompt.
    - Return valid JSON only when asked for JSON.
    """
).strip()
# The text shown when the user types /help.
HELP_TEXT = textwrap.dedent(
    """
    Commands:
      /help                 Show this help
      /status               Show session status
      /gitnexus <subcmd>    Manage GitNexus enhancement state
      /scan                 Scan the source repo or current directory
      /improve              Generate or refresh the source-repo improvement plan
      /patch-code [id]      Stage pending source-repo edits for the top improvement or a chosen ID
      /map                  Generate or refresh the Cyborg Lab content map
      /plan                 Generate or refresh the publishing plan
      /draft [all|key ...]  Generate pending near-publishable drafts
      /links                Recommend existing-page cross-link edits
      /patch-links 1 2      Generate pending edits for selected link recommendations
      /rewrite <id> <mode>  Choose update|iteration-log|merge for a strong match
      /review <key>         Make a draft active for editorial back-and-forth
      /show <key>           Print the current pending draft
      /apply [target]       Write staged source-repo edits or blog edits to disk
      /quit                 Save and exit

    Notes:
      - Any non-command text is treated as intake guidance or editorial feedback.
      - When Cyborg shows A-E choices, you can reply with the letter only.
      - `E` always means "custom" if the listed options do not fit.
      - Draft changes are held until you explicitly run /apply.
      - Use /review <key> before giving revision notes for a specific draft.
    """
).strip()


def utc_now() -> str:
    """Return the current time in UTC as a short ISO string."""
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def load_env_file(dotfiles_dir: Path) -> None:
    """Read the .env file and put its values into the environment.

    Values that already exist in the environment are NOT overwritten,
    so real env vars always win over .env defaults.
    """
    env_file = dotfiles_dir / ".env"
    if not env_file.exists():
        return
    for raw_line in env_file.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        # Skip blank lines, comments, and lines without an = sign.
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        # Remove surrounding quotes from the value.
        value = value.strip().strip("'").strip('"')
        os.environ.setdefault(key, value)


def canonical_home_path(path_value: Any) -> Path:
    """Turn a string into an absolute Path that must be inside the home folder.

    This is a safety check so the agent never reads or writes files
    outside the user's home directory.
    """
    path = Path(path_value).expanduser().resolve()
    home = Path.home().resolve()
    if path == home or home in path.parents:
        return path
    raise ValueError(f"Path outside home directory: {path}")


def slugify(text: str, max_words: int = 8, max_len: int = 60) -> str:
    """Turn any text into a short, URL-safe slug like 'my-cool-project'."""
    normalized = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    words = [word for word in normalized.split("-") if word]
    slug = "-".join(words[:max_words]) if words else "untitled"
    return slug[:max_len].strip("-") or "untitled"


def title_from_slug(slug: str) -> str:
    """Turn a slug back into a nice title: 'my-project' -> 'My Project'."""
    return " ".join(word.capitalize() for word in slug.replace("_", "-").split("-") if word) or "Untitled"


def track_slug(track_name: str) -> str:
    """Make a slug for a workflow track name (shorter than a normal slug)."""
    return slugify(track_name, max_words=6, max_len=40)


def short_preview(text: str, limit: int = 180) -> str:
    """Collapse whitespace and cut text to a short preview string."""
    collapsed = re.sub(r"\s+", " ", text).strip()
    if len(collapsed) <= limit:
        return collapsed
    return f"{collapsed[: limit - 3].rstrip()}..."


def run_command(
    argv: list[str],
    *,
    cwd: Optional[Path] = None,
    allow_failure: bool = False,
    timeout: int = DEFAULT_COMMAND_TIMEOUT_SECONDS,
) -> str:
    """Run a shell command and return its stdout as a string.

    If the command fails and allow_failure is False, raise an error.
    If the command takes too long, treat it the same as a failure.
    """
    try:
        result = subprocess.run(
            argv,
            cwd=str(cwd) if cwd else None,
            capture_output=True,
            text=True,
            check=False,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as exc:
        if allow_failure:
            return ""
        raise RuntimeError(f"Command timed out after {timeout}s: {' '.join(argv)}") from exc
    if result.returncode != 0 and not allow_failure:
        stderr = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(stderr or f"Command failed: {' '.join(argv)}")
    return (result.stdout or "").strip()


def run_command_result(
    argv: list[str],
    *,
    cwd: Optional[Path] = None,
    timeout: int = DEFAULT_COMMAND_TIMEOUT_SECONDS,
) -> tuple[int, str, str]:
    """Run a shell command and return (exit_code, stdout, stderr).

    Unlike run_command(), this never raises on failure -- it just
    returns the exit code so the caller can decide what to do.
    """
    try:
        result = subprocess.run(
            argv,
            cwd=str(cwd) if cwd else None,
            capture_output=True,
            text=True,
            check=False,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        # Exit code 124 is the same code the `timeout` command uses.
        return 124, "", f"Command timed out after {timeout}s: {' '.join(argv)}"
    return result.returncode, (result.stdout or "").strip(), (result.stderr or "").strip()


def format_bytes(num_bytes: int) -> str:
    """Turn a byte count into a human-friendly string like '2.3 MB'."""
    units = ["B", "KB", "MB", "GB"]
    value = float(num_bytes)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            return f"{value:.1f} {unit}" if unit != "B" else f"{int(value)} B"
        value /= 1024.0
    return f"{num_bytes} B"


def parse_iso_datetime(value: str) -> Optional[datetime]:
    """Try to read an ISO date string.  Return None if it is bad."""
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def is_source_or_doc_file(path: Path) -> bool:
    """Return True if this file looks like source code or documentation."""
    name = path.name
    if path.suffix.lower() in SOURCE_FILE_SUFFIXES:
        return True
    if name in PROJECT_FILE_MARKERS or name in TEXT_FILE_NAMES:
        return True
    if name.lower().startswith("readme"):
        return True
    return "docs" in path.parts


def section_type_from_content_path(path_value: str) -> Optional[str]:
    """Given a blog content path like 'content/log/foo.md', return the
    content type ('log').  Returns None if the path does not match any
    known section.
    """
    parts = Path(path_value).parts
    if len(parts) < 2 or parts[0] != "content":
        return None
    if parts[1] == "projects":
        return "project"
    if parts[1] == "workflows":
        return "workflow"
    if parts[1] == "artifacts":
        return "artifact"
    if parts[1] == "log":
        return "log"
    if parts[1] == "reference":
        return "reference"
    if parts[1] == "stacks":
        return "stack"
    if parts[1:3] == ("systems", "protocols"):
        return "protocol"
    return None


def parse_gitnexus_list_output(output: str) -> list[dict[str, str]]:
    """Parse the human-readable output of `gitnexus list` into a list
    of dicts with keys like 'name', 'path', 'commit', etc.

    The output uses indentation to separate repo names from their
    details, so we track which repo block we are inside.
    """
    repos: list[dict[str, str]] = []
    current: Optional[dict[str, str]] = None
    for raw_line in output.splitlines():
        line = raw_line.rstrip()
        stripped = line.strip()
        # A blank line ends the current repo block.
        if not stripped:
            if current:
                repos.append(current)
                current = None
            continue
        # Skip the header line like "Indexed Repositories (3)".
        if stripped.startswith("Indexed Repositories"):
            continue
        # A line indented 2 spaces (but not 4) with no colon is a repo name.
        if line.startswith("  ") and not line.startswith("    ") and ":" not in stripped:
            if current:
                repos.append(current)
            current = {"name": stripped}
            continue
        # A line indented 4 spaces with a colon is a detail field.
        if current and line.startswith("    ") and ":" in stripped:
            key, value = stripped.split(":", 1)
            current[key.lower()] = value.strip()
    # Don't forget the last block if the output didn't end with a blank line.
    if current:
        repos.append(current)
    return repos


def detect_git_root(start_path: Path) -> Optional[Path]:
    """Ask git for the top-level directory.  Return None if this is
    not inside a git repo.
    """
    try:
        output = run_command(["git", "rev-parse", "--show-toplevel"], cwd=start_path, allow_failure=False)
    except RuntimeError:
        return None
    return Path(output).resolve()


def extract_first_heading(markdown: str) -> Optional[str]:
    """Find the first markdown heading (# ...) and return its text."""
    for line in markdown.splitlines():
        stripped = line.strip()
        if stripped.startswith("#"):
            heading = stripped.lstrip("#").strip()
            if heading:
                return heading
    return None


def extract_links(markdown: str) -> list[str]:
    """Pull all unique http/https URLs out of a markdown string."""
    links = []
    seen: set[str] = set()
    for match in re.finditer(r"https?://[^\s)>\]]+", markdown):
        url = match.group(0).rstrip(".,")
        if url not in seen:
            seen.add(url)
            links.append(url)
    return links


def normalize_description(text: str) -> str:
    """Clean up a description so it is between 140 and 160 characters,
    ends with punctuation, and has no stray quotes.  Hugo frontmatter
    descriptions look best at that length.
    """
    cleaned = re.sub(r"\s+", " ", text).strip().replace('"', "")
    if not cleaned:
        cleaned = "Action-oriented summary for immediate execution."
    # Make sure it ends with a sentence-ending mark.
    if cleaned[-1:] not in ".!?":
        cleaned += "."
    # Pad short descriptions so they meet the 140-char minimum.
    if len(cleaned) < 140:
        padding = " Use it to act immediately, reduce friction, and keep momentum."
        cleaned = f"{cleaned}{padding}"
    # Trim long descriptions to 160 characters without cutting a word.
    if len(cleaned) > 160:
        trimmed = cleaned[:157].rstrip()
        if " " in trimmed:
            trimmed = trimmed.rsplit(" ", 1)[0]
        cleaned = f"{trimmed}..."
    return cleaned


def prompt_input(prompt: str) -> str:
    """Show a prompt and read one line.  Return '' on end-of-input."""
    try:
        return input(prompt)
    except EOFError:
        return ""


def extract_letter_choices(text: str) -> dict[str, str]:
    """Parse assistant text like ``A. foo`` into ``{"a": "foo"}``."""
    choices: dict[str, str] = {}
    for raw_line in text.splitlines():
        match = re.match(r"^\s*([A-E])\.\s+(.+?)\s*$", raw_line)
        if match:
            choices[match.group(1).lower()] = match.group(2).strip()
    return choices


def contextualize_choice_reply(reply: str, history: list[dict[str, str]]) -> str:
    """Expand a bare A-E reply into the last matching assistant option."""
    normalized = reply.strip().lower()
    if normalized not in {"a", "b", "c", "d", "e"}:
        return reply
    for entry in reversed(history):
        if entry.get("role") != "assistant":
            continue
        choices = extract_letter_choices(str(entry.get("content", "")))
        if normalized in choices:
            return f"Selected {normalized.upper()}: {choices[normalized]}"
    return reply


def recent_chat_excerpt(history: list[dict[str, str]], *, limit: int = 6) -> str:
    """Return a short chat transcript snippet for AI follow-up calls."""
    if not history:
        return "(none)"
    lines = []
    for entry in history[-limit:]:
        role = str(entry.get("role", "user"))
        content = short_preview(str(entry.get("content", "")), 220)
        lines.append(f"{role}: {content}")
    return "\n".join(lines)


def parse_compact_letter_choice(text: str) -> tuple[Optional[int], Optional[str]]:
    """Parse ``A`` or ``2B`` into ``(None, 'A')`` / ``(2, 'B')``."""
    match = re.match(r"^\s*(?:(\d+)\s*)?([A-E])\s*$", text, flags=re.IGNORECASE)
    if not match:
        return None, None
    choice_id = int(match.group(1)) if match.group(1) else None
    return choice_id, match.group(2).upper()


def resolve_within_root(root: Path, target_path: Path, *, label: str) -> Path:
    """Make sure target_path is inside root.  This stops path-traversal
    attacks like '../../etc/passwd' from escaping the allowed folder.
    """
    resolved_root = root.resolve()
    resolved_target = target_path.resolve()
    if resolved_target != resolved_root and resolved_root not in resolved_target.parents:
        raise ValueError(f"Refusing to write outside {label}: {resolved_target}")
    return resolved_target


def looks_like_project_dir(path: Path) -> bool:
    """Return True if the folder has signs of being a real project
    (like a README plus source files, or a package.json, etc.).
    We use this to avoid treating random folders as repos.
    """
    if not path.exists() or not path.is_dir():
        return False
    # Never treat the home directory itself as a project.
    if path.resolve() == Path.home().resolve():
        return False

    has_readme = False
    has_source = False
    try:
        for child in path.iterdir():
            name = child.name
            # A project-marker file is a strong signal by itself.
            if child.is_file() and name in PROJECT_FILE_MARKERS:
                return True
            # A project-marker folder is also a strong signal.
            if child.is_dir() and name in PROJECT_DIR_MARKERS:
                return True
            if child.is_file() and name.lower().startswith("readme"):
                has_readme = True
            if child.is_file() and child.suffix.lower() in SOURCE_FILE_SUFFIXES:
                has_source = True
    except OSError:
        return False
    # A readme plus at least one source file is good enough.
    return has_readme and has_source


# =====================================================================
# Blog-awareness parsers (archetypes, shortcodes, content strategy)
# =====================================================================


def parse_archetype(text: str) -> dict[str, Any]:
    """Parse a Hugo archetype markdown file into structured data.

    Returns a dict with:
      - fields: list of dicts (name, value, allowed, is_list)
      - body: the markdown body below the frontmatter
      - raw_frontmatter: the raw YAML text
    """
    parts = text.split("---", 2)
    if len(parts) < 3:
        return {"fields": [], "body": text.strip(), "raw_frontmatter": ""}
    raw_fm = parts[1].strip()
    body = parts[2].strip()

    fields: list[dict[str, Any]] = []
    pending_allowed: Optional[str] = None

    for line in raw_fm.splitlines():
        stripped = line.strip()
        # Extract "# Allowed X values: a, b, c" comments.
        if stripped.startswith("#"):
            match = re.match(r"#\s*Allowed\s+(\w+)\s+values?:\s*(.+)", stripped, re.IGNORECASE)
            if match:
                pending_allowed = match.group(2).strip()
            continue
        if not stripped:
            continue
        # List continuation like "  - zsh"
        if stripped.startswith("- ") and fields:
            last = fields[-1]
            if isinstance(last["value"], list):
                last["value"].append(stripped[2:].strip().strip('"').strip("'"))
            continue
        if ":" not in stripped:
            continue
        key, raw_val = stripped.split(":", 1)
        key = key.strip()
        raw_val = raw_val.strip()
        # Skip Hugo template expressions like {{ .Date }}
        if "{{" in raw_val:
            raw_val = ""
        # Detect list start
        if raw_val == "":
            # Could be a list or empty value — peek was a list continuation.
            pass
        raw_val = raw_val.strip('"').strip("'")
        # Check if next lines are list items (we handle that above).
        is_list = raw_val == "" or raw_val.startswith("[")
        if raw_val.startswith("[") and raw_val.endswith("]"):
            raw_val = [item.strip().strip('"').strip("'") for item in raw_val[1:-1].split(",") if item.strip()]
            is_list = True
        elif is_list and raw_val == "":
            raw_val = []
        field_entry: dict[str, Any] = {"name": key, "value": raw_val, "is_list": is_list}
        if pending_allowed:
            field_entry["allowed"] = [v.strip() for v in pending_allowed.split(",")]
            pending_allowed = None
        fields.append(field_entry)

    return {"fields": fields, "body": body, "raw_frontmatter": raw_fm}


def parse_shortcode(name: str, text: str) -> dict[str, Any]:
    """Parse a Hugo shortcode HTML template to extract its parameters.

    Returns a dict with:
      - name: shortcode name (from filename)
      - params: list of dicts (name, default)
      - is_paired: True if the shortcode uses .Inner
      - purpose: first HTML comment or empty string
    """
    params: list[dict[str, str]] = []
    seen: set[str] = set()
    # Match patterns like .Get "title" | default "Quick Path"
    for match in re.finditer(r'\.Get\s+"([^"]+)"(?:\s*\|\s*default\s+"([^"]*)")?', text):
        param_name = match.group(1)
        default_val = match.group(2) or ""
        if param_name not in seen:
            seen.add(param_name)
            params.append({"name": param_name, "default": default_val})

    is_paired = ".Inner" in text
    # Try to extract purpose from the first HTML comment.
    purpose = ""
    comment_match = re.search(r"<!--\s*(.+?)\s*-->", text)
    if comment_match:
        purpose = comment_match.group(1).strip()
        # Clean up the "layouts/shortcodes/X.html" prefix.
        purpose = re.sub(r"^layouts/shortcodes/\S+\s*", "", purpose).strip()

    return {"name": name, "params": params, "is_paired": is_paired, "purpose": purpose}


def load_blog_archetypes(blog_root: Path) -> dict[str, dict[str, Any]]:
    """Read all archetype files from the blog repo.
    Returns a dict keyed by type name (e.g., 'workflow').
    """
    archetypes_dir = blog_root / "archetypes"
    if not archetypes_dir.is_dir():
        return {}
    result: dict[str, dict[str, Any]] = {}
    for path in sorted(archetypes_dir.glob("*.md")):
        type_name = path.stem  # "workflow.md" -> "workflow"
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        result[type_name] = parse_archetype(text)
    return result


def load_blog_shortcodes(blog_root: Path) -> list[dict[str, Any]]:
    """Read all shortcode templates from the blog repo.
    Returns a list of parsed shortcode dicts.
    """
    shortcodes_dir = blog_root / "layouts" / "shortcodes"
    if not shortcodes_dir.is_dir():
        return []
    result: list[dict[str, Any]] = []
    for path in sorted(shortcodes_dir.glob("*.html")):
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        result.append(parse_shortcode(path.stem, text))
    return result


def load_blog_content_strategy(blog_root: Path) -> str:
    """Read the content strategy document from the blog repo.
    Returns the full text, or empty string if not found.
    """
    strategy_path = blog_root / "docs" / "CONTENT-STRATEGY.md"
    if not strategy_path.is_file():
        return ""
    try:
        return strategy_path.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


class GitNexusCli:
    """Wrapper around the pinned npm GitNexus command-line tool.

    GitNexus builds a knowledge graph of a repo's symbols and
    execution flows.  This class runs it, reads its output, and
    checks whether the index is healthy or needs a refresh.
    """

    def __init__(self) -> None:
        # The user can turn off GitNexus entirely with an env var.
        self.disabled = os.environ.get("CYBORG_DISABLE_GITNEXUS", "").lower() in {"1", "true", "yes"}
        # Cache the repo list so we don't call `gitnexus list` twice.
        self._repo_index_cache: Optional[list[dict[str, str]]] = None

    @property
    def available(self) -> bool:
        """True if GitNexus is enabled and `npx` is available."""
        return not self.disabled and shutil.which("npx") is not None

    @staticmethod
    def _status_path(line: str) -> str:
        """Extract the repo-relative path from one `git status --short` line."""
        raw = re.sub(r"^[ MADRCU?!]{1,2}\s+", "", line.rstrip())
        if " -> " in raw:
            raw = raw.split(" -> ", 1)[1].strip()
        return raw

    @classmethod
    def _is_gitnexus_managed_path(cls, line: str) -> bool:
        """True when a git-status line points at GitNexus-managed artifacts."""
        path = cls._status_path(line)
        if not path:
            return False
        return path.startswith(".gitnexus/") or path.startswith(".claude/skills/gitnexus/")

    def _run(self, args: list[str], *, cwd: Path, timeout: int = DEFAULT_COMMAND_TIMEOUT_SECONDS) -> str:
        """Run a gitnexus subcommand and return its text output.
        Raises RuntimeError if the command fails.
        """
        code, stdout, stderr = run_command_result([*GITNEXUS_NPX_COMMAND, *args], cwd=cwd, timeout=timeout)
        if code != 0:
            message = stderr or stdout or f"gitnexus {' '.join(args)} failed"
            raise RuntimeError(message)
        return stdout or stderr

    def _run_json(self, args: list[str], *, cwd: Path, timeout: int = DEFAULT_COMMAND_TIMEOUT_SECONDS) -> dict[str, Any]:
        """Run a gitnexus subcommand and parse its output as JSON."""
        output = self._run(args, cwd=cwd, timeout=timeout)
        try:
            return json.loads(output)
        except json.JSONDecodeError as exc:
            raise RuntimeError(f"GitNexus returned non-JSON output: {short_preview(output, 240)}") from exc

    def _read_meta(self, repo_path: Path) -> dict[str, Any]:
        """Read the local .gitnexus/meta.json file (if it exists).
        Returns an empty dict when the file is missing or broken.
        """
        meta_path = repo_path / ".gitnexus" / "meta.json"
        if not meta_path.exists():
            return {}
        try:
            return json.loads(meta_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return {}

    def _local_db_present(self, repo_path: Path) -> bool:
        """True when the local GitNexus database exists for this repo."""
        return (repo_path / ".gitnexus" / "lbug").exists()

    def repo_entries(self, cwd: Path) -> list[dict[str, str]]:
        """Get the list of repos that GitNexus has already indexed."""
        if self._repo_index_cache is not None:
            return self._repo_index_cache
        try:
            output = self._run(["list"], cwd=cwd)
        except RuntimeError:
            self._repo_index_cache = []
            return self._repo_index_cache
        self._repo_index_cache = parse_gitnexus_list_output(output)
        return self._repo_index_cache

    def repo_name_for_path(self, repo_path: Path) -> Optional[str]:
        """Look up the GitNexus name for a repo by its disk path."""
        for entry in self.repo_entries(repo_path):
            if entry.get("path") == str(repo_path):
                return entry.get("name")
        return None

    def tracked_source_docs_bytes(self, repo_path: Path) -> int:
        """Add up the sizes of all tracked source and doc files.
        We use this to decide if the repo is too large for GitNexus.
        """
        total = 0
        output = run_command(["git", "ls-files"], cwd=repo_path, allow_failure=True)
        for line in output.splitlines():
            rel_path = line.strip()
            if not rel_path:
                continue
            file_path = repo_path / rel_path
            if not file_path.is_file() or not is_source_or_doc_file(file_path):
                continue
            try:
                total += file_path.stat().st_size
            except OSError:
                continue
        return total

    def health_check(self, repo_path: Path, *, previous: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        """Run a read-only check to find out if GitNexus is healthy,
        stale, missing, or broken for this repo.  Returns a dict full
        of flags the agent uses to decide what to show the user.

        If `previous` is given (the status from the last saved session),
        we also detect whether the repo changed since then.
        """
        status: dict[str, Any] = {
            "enabled": not self.disabled,
            "available": self.available,
            "mode": "native",
            "state": "disabled" if self.disabled else "unknown",
            "decision_required": False,
            "repo_path": str(repo_path),
            "repo_name": None,
            "configured": False,
            "indexed": False,
            "healthy": False,
            "stale": False,
            "stale_reasons": [],
            "current_commit": "",
            "indexed_commit": "",
            "indexed_at": "",
            "dirty": False,
            "tracked_bytes": 0,
            "too_large": False,
            "embeddings_present": False,
            "status_output": "",
            "repo_changed_since_session": False,
        }
        git_root = detect_git_root(repo_path)
        if not git_root:
            status["state"] = "not-git"
            status["enabled"] = False
            return status
        status["repo_path"] = str(git_root)
        repo_path = git_root
        status["current_commit"] = run_command(["git", "rev-parse", "HEAD"], cwd=repo_path, allow_failure=True)
        git_status_output = run_command(["git", "status", "--short"], cwd=repo_path, allow_failure=True)
        meaningful_status_lines = [line for line in git_status_output.splitlines() if not self._is_gitnexus_managed_path(line)]
        status["dirty"] = bool(meaningful_status_lines)
        status["tracked_bytes"] = self.tracked_source_docs_bytes(repo_path)
        status["too_large"] = status["tracked_bytes"] > GITNEXUS_SIZE_THRESHOLD_BYTES
        meta = self._read_meta(repo_path)
        local_db_present = self._local_db_present(repo_path)
        status["configured"] = bool(meta)
        status["indexed_commit"] = str(meta.get("lastCommit", ""))
        status["indexed_at"] = str(meta.get("indexedAt", ""))
        stats = meta.get("stats", {}) if isinstance(meta, dict) else {}
        status["embeddings_present"] = bool(stats.get("embeddings", 0))

        if self.disabled:
            status["state"] = "disabled"
            return status
        if not self.available:
            status["state"] = "unavailable"
            status["decision_required"] = True
            status["stale_reasons"].append("GitNexus CLI is unavailable in this shell.")
            return status

        status["status_output"] = "local GitNexus health check (meta.json + .gitnexus/lbug + git state)"
        status["repo_name"] = self.repo_name_for_path(repo_path) or repo_path.name
        status["indexed"] = bool(meta) and local_db_present
        if not status["configured"]:
            status["stale_reasons"].append("GitNexus metadata is not configured in this repo.")
        if status["configured"] and not local_db_present:
            status["stale_reasons"].append("Local GitNexus database (.gitnexus/lbug) is missing.")
        if not status["indexed"]:
            status["stale_reasons"].append("This repo is not indexed yet.")
        if status["indexed"] and status["current_commit"] and status["indexed_commit"] and status["current_commit"] != status["indexed_commit"]:
            status["stale_reasons"].append("Current HEAD differs from the indexed commit.")
        if status["dirty"]:
            status["stale_reasons"].append("Tracked files changed since the last analyze.")
        indexed_at = parse_iso_datetime(status["indexed_at"])
        if indexed_at and indexed_at < datetime.now(timezone.utc) - timedelta(hours=GITNEXUS_STALE_HOURS):
            status["stale_reasons"].append(f"The index is older than {GITNEXUS_STALE_HOURS} hours.")
        if status["too_large"]:
            status["stale_reasons"].append(
                f"Tracked source/docs total {format_bytes(status['tracked_bytes'])}, above the {format_bytes(GITNEXUS_SIZE_THRESHOLD_BYTES)} enhancement threshold."
            )
        status["stale"] = bool(status["stale_reasons"]) and status["indexed"]
        status["healthy"] = status["indexed"] and not status["stale_reasons"] and not status["too_large"]
        status["decision_required"] = not status["healthy"]
        if status["healthy"]:
            status["state"] = "healthy"
        elif status["too_large"]:
            status["state"] = "too-large"
        elif not status["indexed"]:
            status["state"] = "not-indexed"
        else:
            status["state"] = "stale"
        status["mode"] = "graph" if status["healthy"] else "native"

        # Compare with the previous session's status to detect changes.
        if previous:
            prior_commit = str(previous.get("current_commit", ""))
            prior_dirty = bool(previous.get("dirty"))
            prior_indexed = str(previous.get("indexed_commit", ""))
            status["repo_changed_since_session"] = bool(
                prior_commit and (prior_commit != status["current_commit"] or prior_dirty != status["dirty"] or prior_indexed != status["indexed_commit"])
            )
            # If it was already flagged as changed, keep it flagged.
            if previous.get("repo_changed_since_session"):
                status["repo_changed_since_session"] = True
        return status

    def enhance(self, repo_path: Path, *, force: bool = False) -> dict[str, Any]:
        """Run `gitnexus analyze` to build or refresh the repo index.

        When `force` is True, the --force flag is passed so the index
        is rebuilt from scratch even if it already exists.  If the
        repo had embeddings before, we keep them.
        """
        meta_before = self._read_meta(repo_path)
        preserve_embeddings = bool(meta_before.get("stats", {}).get("embeddings", 0))
        args = ["analyze"]
        if force:
            args.append("--force")
        if preserve_embeddings:
            args.append("--embeddings")
        args.append(".")
        try:
            output = self._run(args, cwd=repo_path, timeout=GITNEXUS_ANALYZE_TIMEOUT_SECONDS)
        except RuntimeError as exc:
            # If this was the very first analyze and it failed, clean up
            # the partial .gitnexus folder so we don't leave garbage.
            cleaned = False
            if not meta_before:
                code, _, _ = run_command_result([*GITNEXUS_NPX_COMMAND, "clean", "--force"], cwd=repo_path)
                cleaned = code == 0
            raise RuntimeError(f"{exc}\nCleanup attempted: {'yes' if cleaned else 'no'}") from exc
        # Clear the cache so the next list call picks up fresh data.
        self._repo_index_cache = None
        return {
            "output": output,
            "preserved_embeddings": preserve_embeddings,
        }

    def query_summary(self, repo_path: Path, *, repo_name: Optional[str], search_query: str, goal: str, context: str) -> dict[str, Any]:
        """Ask GitNexus for the repo's top execution flows, symbols,
        and file definitions.  Returns an empty dict on failure so the
        caller can fall back to native scanning.
        """
        if not repo_name:
            return {}
        try:
            payload = self._run_json(
                [
                    "query",
                    "--repo",
                    repo_name,
                    "-l",
                    str(GITNEXUS_QUERY_LIMIT),
                    "-g",
                    goal,
                    "-c",
                    context,
                    search_query,
                ],
                cwd=repo_path,
            )
        except RuntimeError:
            return {}
        return {
            "processes": payload.get("processes", [])[:GITNEXUS_QUERY_LIMIT],
            "process_symbols": payload.get("process_symbols", [])[:8],
            "definitions": payload.get("definitions", [])[:8],
        }


@dataclass
class SessionState:
    """Everything the agent needs to remember between commands.

    This dataclass is saved as JSON inside the session folder so work
    can be paused and resumed later.  Each field maps to one piece of
    the conversation or content pipeline.
    """

    session_id: str              # Unique ID like "20260316-143000-my-repo-abc123"
    version: int                 # Schema version; bump when the shape changes
    created_at: str              # UTC timestamp when the session started
    updated_at: str              # UTC timestamp of the last save
    blog_root: str               # Absolute path to the Hugo blog repo
    session_dir: str             # Folder where this session's files live
    cwd: str                     # The directory the user was in when they started
    repo_path: Optional[str] = None      # Path to the source repo being ingested
    repo_name: Optional[str] = None      # Short name of the repo (folder name)
    repo_remote: Optional[str] = None    # Git remote URL (if available)
    markdown_file: Optional[str] = None  # Path to an optional supporting article
    source_text: str = ""                # Free-text idea the user typed at launch
    article_text: str = ""               # Full text of the supporting article
    phase: str = "intake"                # Current pipeline stage (intake -> applied)
    gitnexus_status: dict[str, Any] = field(default_factory=dict)      # Latest GitNexus health check
    gitnexus_summary: dict[str, Any] = field(default_factory=dict)     # Graph query results
    gitnexus_skip: bool = False          # True if user chose to skip GitNexus
    intake_notes: list[str] = field(default_factory=list)              # Free-form notes from early phase
    planning_notes: list[str] = field(default_factory=list)            # Notes added after the map exists
    editorial_notes: list[str] = field(default_factory=list)           # Feedback on specific drafts
    chat_history: list[dict[str, str]] = field(default_factory=list)   # Rolling AI conversation log
    scan_summary: str = ""               # Markdown summary of the repo scan
    scan_details: dict[str, Any] = field(default_factory=dict)         # Structured scan data
    duplicate_candidates: list[dict[str, str]] = field(default_factory=list)  # Blog pages that might overlap
    code_improvement_plan: dict[str, Any] = field(default_factory=dict)       # Prioritized source-repo improvement plan
    pending_repo_edits: dict[str, dict[str, Any]] = field(default_factory=dict)  # Staged edits for the source repo
    content_map: dict[str, Any] = field(default_factory=dict)          # Proposed set of new pages
    publishing_plan: dict[str, Any] = field(default_factory=dict)      # Ordered plan for drafting
    pending_drafts: dict[str, dict[str, Any]] = field(default_factory=dict)   # Drafts waiting to be applied
    link_recommendations: list[dict[str, Any]] = field(default_factory=list)  # Suggested edits to existing pages
    rewrite_recommendations: list[dict[str, Any]] = field(default_factory=list)  # Strong existing-page matches
    rewrite_choices: dict[str, str] = field(default_factory=dict)      # User's chosen rewrite mode per path
    pending_existing_edits: dict[str, dict[str, Any]] = field(default_factory=dict)  # Edits staged for existing pages
    active_review_key: Optional[str] = None  # Which draft the user is currently editing
    blog_archetypes: dict[str, dict[str, Any]] = field(default_factory=dict)    # Parsed archetype schemas per type
    blog_shortcodes: list[dict[str, Any]] = field(default_factory=list)          # Parsed shortcode inventory
    blog_content_strategy: str = ""                                              # Full text of CONTENT-STRATEGY.md


class OpenRouterClient:
    """Simple HTTP client that talks to the OpenRouter AI gateway.

    Sends a system prompt plus a user prompt and gets back either
    plain text or JSON, depending on which method you call.
    """

    def __init__(self) -> None:
        self.api_key = os.environ.get("OPENROUTER_API_KEY", "").strip()
        self.model = (
            os.environ.get("CYBORG_MODEL")
            or os.environ.get("CONTENT_MODEL")
            or os.environ.get("STRATEGY_MODEL")
            or os.environ.get("DEFAULT_MODEL")
            or MODEL_FALLBACK
        ).strip()
        self.disabled = os.environ.get("CYBORG_DISABLE_AI", "").lower() in {"1", "true", "yes"}

    @property
    def enabled(self) -> bool:
        """True when we have an API key, a model, and AI is not turned off."""
        return bool(self.api_key and self.model and not self.disabled)

    def _request(self, payload: dict[str, Any]) -> dict[str, Any]:
        """Send a raw JSON payload to OpenRouter and return the response.

        Raises ``RuntimeError`` with the provider error message when the
        API returns an error payload (missing ``choices`` key) or an HTTP
        error status.
        """
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            OPENROUTER_URL,
            data=data,
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
                "HTTP-Referer": "https://ryanleej.com",
                "X-Title": "Cyborg Lab Ingest Agent",
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=120) as response:
                result = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            try:
                body = json.loads(exc.read().decode("utf-8"))
                msg = body.get("error", {}).get("message", str(body))
            except Exception:
                msg = f"HTTP {exc.code}"
            raise RuntimeError(f"AI request failed ({exc.code}): {msg}") from exc
        # OpenRouter sometimes returns 200 with an error payload.
        if "choices" not in result:
            error_info = result.get("error", {})
            msg = error_info.get("message", json.dumps(result)[:200])
            raise RuntimeError(f"AI request failed: {msg}")
        return result

    @staticmethod
    def _with_cache_control(message: dict[str, Any]) -> dict[str, Any]:
        """Return a copy of *message* with ``cache_control`` attached."""
        return {**message, "cache_control": {"type": "ephemeral"}}

    def chat_text(
        self,
        system_prompt: str,
        user_prompt: str,
        *,
        temperature: float = 0.35,
        cache_system: bool = False,
        max_tokens: Optional[int] = None,
    ) -> str:
        """Ask the AI a question and get a plain-text answer back."""
        sys_msg: dict[str, Any] = {"role": "system", "content": system_prompt}
        if cache_system:
            sys_msg = self._with_cache_control(sys_msg)
        payload = {
            "model": self.model,
            "temperature": temperature,
            "messages": [
                sys_msg,
                {"role": "user", "content": user_prompt},
            ],
        }
        if max_tokens is not None:
            payload["max_tokens"] = max_tokens
        response = self._request(payload)
        return str(response["choices"][0]["message"]["content"]).strip()

    def chat_json(
        self,
        system_prompt: str,
        user_prompt: str,
        *,
        temperature: float = 0.25,
        cache_system: bool = False,
        max_tokens: Optional[int] = None,
    ) -> dict[str, Any]:
        """Ask the AI a question and get a JSON object back.

        The response_format field tells the model to return valid JSON.
        If it fails, we raise a RuntimeError with details.
        """
        sys_msg: dict[str, Any] = {"role": "system", "content": system_prompt}
        if cache_system:
            sys_msg = self._with_cache_control(sys_msg)
        payload = {
            "model": self.model,
            "temperature": temperature,
            "response_format": {"type": "json_object"},
            "messages": [
                sys_msg,
                {"role": "user", "content": user_prompt},
            ],
        }
        if max_tokens is not None:
            payload["max_tokens"] = max_tokens
        try:
            response = self._request(payload)
        except urllib.error.URLError as exc:
            raise RuntimeError(f"AI request failed: {exc.reason}") from exc
        except TimeoutError as exc:  # pragma: no cover - depends on network
            raise RuntimeError("AI request timed out") from exc
        content = str(response["choices"][0]["message"]["content"]).strip()
        try:
            return json.loads(content)
        except json.JSONDecodeError as exc:
            raise RuntimeError(f"AI returned non-JSON content: {short_preview(content, 240)}") from exc

    def chat_json_messages(
        self,
        messages: list[dict[str, Any]],
        *,
        temperature: float = 0.25,
        max_tokens: Optional[int] = None,
    ) -> dict[str, Any]:
        """Like ``chat_json`` but accepts a pre-built message list.

        This is used by the draft loop to send a multi-message pattern
        (system + shared-context + per-item instruction) where the first
        two messages carry ``cache_control`` for provider-level caching.
        """
        payload = {
            "model": self.model,
            "temperature": temperature,
            "response_format": {"type": "json_object"},
            "messages": messages,
        }
        if max_tokens is not None:
            payload["max_tokens"] = max_tokens
        try:
            response = self._request(payload)
        except urllib.error.URLError as exc:
            raise RuntimeError(f"AI request failed: {exc.reason}") from exc
        except TimeoutError as exc:  # pragma: no cover - depends on network
            raise RuntimeError("AI request timed out") from exc
        content = str(response["choices"][0]["message"]["content"]).strip()
        try:
            return json.loads(content)
        except json.JSONDecodeError as exc:
            raise RuntimeError(f"AI returned non-JSON content: {short_preview(content, 240)}") from exc


class CyborgAgent:
    """The main agent that drives the whole interactive session.

    It holds the session state, talks to the AI when available,
    runs GitNexus commands, scans repos, builds content maps,
    generates drafts, and writes approved changes into the blog.
    """

    def __init__(self, state: SessionState, *, ai_client: OpenRouterClient, interactive: bool) -> None:
        self.state = state
        self.ai_client = ai_client
        # True when the user is typing at a terminal (not piped input).
        self.interactive = interactive
        self.blog_root = Path(state.blog_root)
        self.session_dir = Path(state.session_dir)
        self.gitnexus_cli = GitNexusCli()
        self._cached_system_prompt: Optional[str] = None

    # --- Small helpers ---

    def _repo_path(self) -> Optional[Path]:
        """Return the source repo path as a Path, or None."""
        return Path(self.state.repo_path) if self.state.repo_path else None

    def _normalize_repo_relative_path(self, path_value: Any) -> Optional[str]:
        """Return a safe repo-relative path or None if it escapes the repo."""
        repo_root = self._repo_path()
        if not repo_root:
            return None
        rel = str(path_value or "").strip().lstrip("/")
        if not rel:
            return None
        try:
            resolved = resolve_within_root(repo_root, repo_root / rel, label="source repo")
        except ValueError:
            return None
        return str(resolved.relative_to(repo_root.resolve()))

    def _gitnexus_status(self) -> dict[str, Any]:
        """Shortcut to get the latest GitNexus health-check dict."""
        return self.state.gitnexus_status or {}

    def _gitnexus_decision_pending(self) -> bool:
        """True when GitNexus needs the user to say enhance or skip."""
        status = self._gitnexus_status()
        return bool(self.state.repo_path and not self.state.gitnexus_skip and status.get("decision_required"))

    def _gitnexus_prompt_text(self) -> str:
        """Build the message we show the user when GitNexus needs attention."""
        status = self._gitnexus_status()
        state = status.get("state")
        tracked_size = format_bytes(int(status.get("tracked_bytes", 0)))
        primary_action = "Approve the repo write step and run `gitnexus analyze` in this repo."
        if state == "stale":
            primary_action = "Approve the refresh and run `gitnexus analyze` so the graph matches the current repo state."
        elif state == "too-large":
            primary_action = "Approve the larger-repo analyze anyway and keep the index local to this repo."
        elif state == "error":
            primary_action = "Retry the enhancement flow for this repo."
        base_lines = []
        if state == "not-indexed":
            base_lines.append("GitNexus is not configured here. I can initialize and analyze this repo to improve content mapping, cross-linking, and rewrite quality. Proceed?")
        elif state == "stale":
            base_lines.append("GitNexus is stale for this repo. I can refresh the index so the next content map reflects the current project state. Proceed?")
        elif state == "too-large":
            base_lines.append(
                f"GitNexus enhancement is paused because tracked source/docs total {tracked_size}, above the {format_bytes(GITNEXUS_SIZE_THRESHOLD_BYTES)} threshold. Proceed anyway?"
            )
        elif state == "unavailable":
            base_lines.append("GitNexus is not available in this shell, so I cannot enhance this repo until the CLI is reachable.")
        elif state == "error":
            base_lines.append("GitNexus health check failed. I can retry the enhancement flow, or you can continue with the native scan.")
        else:
            base_lines.append("GitNexus needs attention before I keep using it as the higher-confidence repo map.")
        base_lines.extend(
            [
                "Planned GitNexus step:",
                "- zero-write health check already completed",
                "- run `gitnexus analyze` in this repo only if you approve",
                "- preserve embeddings if they already exist",
                "- keep `.gitnexus` local unless you explicitly decide otherwise",
                "Options:",
                "A. Explain the GitNexus plan in more detail.",
                f"B. {primary_action}",
                "C. Skip GitNexus and continue with native scanning only.",
                "D. Show the current GitNexus status again.",
                "E. Custom command or note.",
                "Reply with A-E, or use `/gitnexus ...` directly.",
            ]
        )
        if status.get("embeddings_present"):
            base_lines.append("- embeddings already exist here, so a refresh will preserve them")
        elif status.get("indexed"):
            base_lines.append("- embeddings are not enabled here; I can recommend them later as an optional upgrade")
        return "\n".join(base_lines)

    def _gitnexus_status_lines(self) -> list[str]:
        """Format the GitNexus status as lines for the /status display."""
        status = self._gitnexus_status()
        if not status:
            return ["GitNexus: not checked yet"]
        lines = [
            f"GitNexus: {status.get('state', 'unknown')} ({status.get('mode', 'native')} mode)",
            f"GitNexus repo: {status.get('repo_name') or '(none)'}",
            f"GitNexus indexed commit: {status.get('indexed_commit') or '(none)'}",
            f"GitNexus current commit: {status.get('current_commit') or '(none)'}",
            f"GitNexus tracked source/docs: {format_bytes(int(status.get('tracked_bytes', 0)))}",
            f"GitNexus embeddings: {'present' if status.get('embeddings_present') else 'not enabled'}",
        ]
        if status.get("stale_reasons"):
            lines.append("GitNexus notes:")
            lines.extend(f"- {reason}" for reason in status["stale_reasons"])
        return lines

    def _gitnexus_explain_text(self) -> str:
        """Build the detailed explanation shown for /gitnexus explain."""
        status = self._gitnexus_status()
        lines = [
            "GitNexus enhancement plan:",
            "- detect repo health without writing anything",
            "- if approved, run `gitnexus analyze` in the repo root",
            "- preserve embeddings if they already exist",
            "- merge GitNexus signals with the native scan, with GitNexus treated as higher confidence",
            "- use the graph to improve execution-flow extraction, draft targeting, and strong-match rewrite prompts",
            "- keep `.gitnexus` local-only unless you explicitly choose a different policy later",
        ]
        if status.get("too_large"):
            lines.append(f"- current tracked source/docs size is {format_bytes(int(status.get('tracked_bytes', 0)))} so this exceeds the auto-enhancement threshold")
        if status.get("stale_reasons"):
            lines.append("Current blockers:")
            lines.extend(f"- {reason}" for reason in status["stale_reasons"])
        return "\n".join(lines)

    def _gitnexus_search_query(self) -> str:
        """Pick the best search string for the GitNexus graph query."""
        candidates = [
            self.state.repo_name or "",
            extract_first_heading(self.state.article_text or "") or "",
            self.state.source_text,
        ]
        for candidate in candidates:
            cleaned = short_preview(candidate, 120).strip()
            if cleaned:
                return cleaned
        return "core workflow execution path reusable artifact"

    def _refresh_gitnexus_summary(self) -> None:
        """Ask GitNexus for fresh execution-flow and symbol data."""
        repo_path = self._repo_path()
        status = self._gitnexus_status()
        if not repo_path or not status.get("healthy"):
            self.state.gitnexus_summary = {}
            return
        summary = self.gitnexus_cli.query_summary(
            repo_path,
            repo_name=status.get("repo_name"),
            search_query=self._gitnexus_search_query(),
            goal="Identify the repo's core execution flows, reusable artifacts, and update candidates for Cyborg Lab content.",
            context="Cyborg Lab ingest session: merge GitNexus graph signals with native repo scanning for content mapping and rewrites.",
        )
        self.state.gitnexus_summary = summary

    def refresh_gitnexus_status(self, *, announce: bool = False) -> dict[str, Any]:
        """Re-run the GitNexus health check and update the session.
        If announce=True and a decision is needed, print the prompt.
        """
        repo_path = self._repo_path()
        if not repo_path:
            self.state.gitnexus_status = {}
            self.state.gitnexus_summary = {}
            return {}
        previous = self.state.gitnexus_status or None
        status = self.gitnexus_cli.health_check(repo_path, previous=previous)
        self.state.gitnexus_status = status
        if status.get("healthy"):
            self._refresh_gitnexus_summary()
        else:
            self.state.gitnexus_summary = {}
        if announce and self._gitnexus_decision_pending():
            self.assistant_say(self._gitnexus_prompt_text())
        return status

    # --- Blog awareness ---

    def _load_blog_awareness(self) -> None:
        """Read archetypes, shortcodes, and content strategy from the
        blog repo so the agent knows the real frontmatter schemas,
        available shortcodes, and editorial rules.  Skips if already
        loaded (e.g., on a resumed session with unchanged blog).
        """
        if self.state.blog_archetypes and self.state.blog_shortcodes:
            return
        self.state.blog_archetypes = load_blog_archetypes(self.blog_root)
        self.state.blog_shortcodes = load_blog_shortcodes(self.blog_root)
        self.state.blog_content_strategy = load_blog_content_strategy(self.blog_root)
        self._cached_system_prompt = None

    def _build_system_prompt(self) -> str:
        """Assemble the full system prompt from the static contract
        plus live blog-awareness data (archetypes, shortcodes, strategy).

        The result is cached on the instance.  Call
        ``self._cached_system_prompt = None`` to force a rebuild (done
        automatically when blog awareness data is reloaded).
        """
        if self._cached_system_prompt is not None:
            return self._cached_system_prompt

        sections = [SYSTEM_CONTRACT]

        # Static content-type and workflow-track rules (previously sent
        # in every user payload — now part of the cached system prompt).
        ct_lines = [
            "",
            "Content type rules (use these when proposing pages):",
        ]
        for ctype, meta in CONTENT_TYPES.items():
            ct_lines.append(f"- {ctype}: dir={meta['dir']}, unit={meta['unit']}, tone={meta['tone']}")
        ct_lines.append("")
        ct_lines.append(f"Workflow tracks: {', '.join(WORKFLOW_TRACKS)}")
        sections.append("\n".join(ct_lines))

        # Archetype contracts
        if self.state.blog_archetypes:
            lines = [
                "",
                "Archetype contracts (every draft MUST match the frontmatter and "
                "section structure of its archetype — do not invent fields):",
            ]
            for type_name, archetype in sorted(self.state.blog_archetypes.items()):
                if type_name == "default":
                    continue
                field_parts: list[str] = []
                for f in archetype.get("fields", []):
                    part = f["name"]
                    if f.get("allowed"):
                        part += f" (allowed: {', '.join(f['allowed'])})"
                    field_parts.append(part)
                body_headings = [
                    line.lstrip("#").strip()
                    for line in archetype.get("body", "").splitlines()
                    if line.strip().startswith("##")
                ]
                lines.append(f"- {type_name}: frontmatter: {', '.join(field_parts)}")
                if body_headings:
                    lines.append(f"  body sections: {' → '.join(body_headings)}")
            sections.append("\n".join(lines))

        # Available shortcodes
        if self.state.blog_shortcodes:
            lines = [
                "",
                "Available Hugo shortcodes (use only these — do not invent shortcodes):",
            ]
            for sc in self.state.blog_shortcodes:
                param_names = [p["name"] for p in sc.get("params", [])]
                paired = "paired" if sc.get("is_paired") else "self-closing"
                params_str = ", ".join(param_names) if param_names else "none"
                purpose = sc.get("purpose", "")
                desc = f"- {sc['name']}: {paired}, params: {params_str}"
                if purpose:
                    desc += f". {purpose}"
                lines.append(desc)
            sections.append("\n".join(lines))

        # Content strategy summary
        if self.state.blog_content_strategy:
            sections.append(
                "\nContent strategy (follow these rules when proposing content types, "
                "prioritizing pages, and checking definition of done):\n"
                + self.state.blog_content_strategy
            )

        self._cached_system_prompt = "\n".join(sections)
        return self._cached_system_prompt

    def auto_prepare_repo_context(self) -> None:
        """Called at session start: check GitNexus health and scan the
        repo if needed.  Pauses if the user needs to make a choice.
        """
        self._load_blog_awareness()
        repo_path = self._repo_path()
        if not repo_path:
            return
        status = self.refresh_gitnexus_status(announce=True)
        if self._gitnexus_decision_pending():
            return
        if not self.state.scan_summary or status.get("repo_changed_since_session"):
            if status.get("repo_changed_since_session") and self.state.scan_summary:
                self.assistant_say(
                    "Repo state changed since the last saved session. I’m refreshing the repo scan now. Rebuild the map with `/map` when you want updated rewrite choices."
                )
            self.scan_repo()

    # --- Persistence ---

    def save(self, *, include_previews: bool = True) -> None:
        """Write the full session state to disk (JSON + markdown files).

        The session folder gets:
        - session.json (the complete state, so we can resume later)
        - transcript.md (human-readable chat log)
        - scan.md, content-map.md/json, publishing-plan.md/json
        - preview/ folder with draft markdown files
        - existing-edits/ folder with patched existing pages
        """
        self.state.updated_at = utc_now()
        self.session_dir.mkdir(parents=True, exist_ok=True)
        (self.session_dir / "session.json").write_text(
            json.dumps(asdict(self.state), indent=2, sort_keys=True),
            encoding="utf-8",
        )

        transcript_lines: list[str] = [
            f"# Cyborg Session {self.state.session_id}",
            "",
            f"- Created: {self.state.created_at}",
            f"- Updated: {self.state.updated_at}",
            f"- Repo: {self.state.repo_path or '(none)'}",
            f"- Blog root: {self.state.blog_root}",
            "",
            "## Conversation",
            "",
        ]
        for entry in self.state.chat_history:
            role = entry.get("role", "assistant").capitalize()
            transcript_lines.append(f"### {role}")
            transcript_lines.append("")
            transcript_lines.append(entry.get("content", "").rstrip())
            transcript_lines.append("")
        (self.session_dir / "transcript.md").write_text("\n".join(transcript_lines).rstrip() + "\n", encoding="utf-8")

        if self.state.scan_summary:
            (self.session_dir / "scan.md").write_text(self.state.scan_summary.rstrip() + "\n", encoding="utf-8")

        if self.state.code_improvement_plan:
            (self.session_dir / "code-improvements.json").write_text(
                json.dumps(self.state.code_improvement_plan, indent=2, sort_keys=True),
                encoding="utf-8",
            )
            (self.session_dir / "code-improvements.md").write_text(self.code_improvement_markdown(), encoding="utf-8")

        if self.state.content_map:
            (self.session_dir / "content-map.json").write_text(
                json.dumps(self.state.content_map, indent=2, sort_keys=True),
                encoding="utf-8",
            )
            (self.session_dir / "content-map.md").write_text(self.content_map_markdown(), encoding="utf-8")

        if self.state.publishing_plan:
            (self.session_dir / "publishing-plan.json").write_text(
                json.dumps(self.state.publishing_plan, indent=2, sort_keys=True),
                encoding="utf-8",
            )
            (self.session_dir / "publishing-plan.md").write_text(self.plan_markdown(), encoding="utf-8")

        if include_previews:
            preview_root = self.session_dir / "preview"
            if self.state.pending_drafts:
                for draft in self.state.pending_drafts.values():
                    self._write_session_artifact(preview_root, draft["path"], draft["markdown"], label="session preview root")

            edit_root = self.session_dir / "existing-edits"
            if self.state.pending_existing_edits:
                for rel_path, edit in self.state.pending_existing_edits.items():
                    self._write_session_artifact(edit_root, rel_path, edit["markdown"], label="session existing-edits root")

            repo_edit_root = self.session_dir / "repo-edits"
            if self.state.pending_repo_edits:
                for rel_path, edit in self.state.pending_repo_edits.items():
                    self._write_session_artifact(repo_edit_root, rel_path, edit["content"], label="session repo-edits root")

    def append_chat(self, role: str, content: str) -> None:
        """Add a message to the rolling chat history and auto-save.
        Old messages are trimmed to keep the window small.
        """
        self.state.chat_history.append({"role": role, "content": content})
        if len(self.state.chat_history) > MAX_CHAT_HISTORY * 2:
            self.state.chat_history = self.state.chat_history[-MAX_CHAT_HISTORY * 2 :]
        self.save(include_previews=False)

    def assistant_say(self, message: str) -> None:
        """Print a message to the user and record it in the chat log."""
        print(message)
        self.append_chat("assistant", message)

    def user_said(self, message: str) -> None:
        """Record something the user typed into the chat log."""
        self.append_chat("user", message)

    def status_lines(self) -> list[str]:
        """Build the lines shown when the user types /status."""
        map_items = self.state.content_map.get("items", [])
        pending_keys = ", ".join(sorted(self.state.pending_drafts)) or "(none)"
        review_target = self.state.active_review_key or "(none)"
        lines = [
            f"Session: {self.state.session_id}",
            f"Phase: {self.state.phase}",
            f"Repo: {self.state.repo_path or '(none)'}",
            f"Blog root: {self.state.blog_root}",
            f"Source notes: {len(self.state.intake_notes)} intake, {len(self.state.planning_notes)} planning, {len(self.state.editorial_notes)} editorial",
            f"Code improvements: {len(self.state.code_improvement_plan.get('items', []))}",
            f"Pending repo edits: {len(self.state.pending_repo_edits)}",
            f"Content map items: {len(map_items)}",
            f"Pending drafts: {pending_keys}",
            f"Pending existing edits: {len(self.state.pending_existing_edits)}",
            f"Rewrite recommendations: {len(self.state.rewrite_recommendations)}",
            f"Active review target: {review_target}",
        ]
        lines.extend(self._gitnexus_status_lines())
        return lines

    def code_improvement_markdown(self) -> str:
        """Render the staged source-repo improvement plan as markdown."""
        lines = [
            f"# Code Improvements: {self.state.session_id}",
            "",
            self.state.code_improvement_plan.get("summary", "No source-repo improvement plan generated."),
            "",
        ]
        items = self.state.code_improvement_plan.get("items", [])
        if items:
            lines.extend(["## Prioritized Improvements", ""])
            for item in items:
                target_files = ", ".join(f"`{path}`" for path in item.get("target_files", [])) or "(none)"
                lines.append(f"- [{item['id']}] {item['title']} [{item['priority']}/{item['kind']}]")
                lines.append(f"  Why: {item['why']}")
                lines.append(f"  Targets: {target_files}")
                acceptance = item.get("acceptance", [])
                if acceptance:
                    lines.append(f"  Acceptance: {'; '.join(acceptance[:3])}")
            lines.append("")
        if self.state.pending_repo_edits:
            lines.extend(["## Pending Repo Edits", ""])
            for rel_path, edit in sorted(self.state.pending_repo_edits.items()):
                reason = edit.get("reason", "Staged source-repo edit.")
                lines.append(f"- `{rel_path}`: {reason}")
            lines.append("")
        return "\n".join(lines).rstrip() + "\n"

    def content_map_markdown(self) -> str:
        """Render the content map as a markdown document."""
        items = self.state.content_map.get("items", [])
        lines = [
            f"# Content Map: {self.state.session_id}",
            "",
            self.state.content_map.get("summary", "No summary generated."),
            "",
        ]
        if self.state.gitnexus_summary:
            lines.extend(["## GitNexus Signals", ""])
            for process in self.state.gitnexus_summary.get("processes", [])[:4]:
                lines.append(f"- Flow: {process.get('summary', 'unknown flow')} ({process.get('step_count', '?')} steps)")
            for definition in self.state.gitnexus_summary.get("definitions", [])[:4]:
                lines.append(f"- Definition: {definition.get('name', 'unknown')} -> `{definition.get('filePath', '')}`")
            lines.append("")
        lines.extend(["## Proposed Pages", ""])
        for item in items:
            lines.append(f"- `{item['key']}` [{item['type']}] -> `{item['path']}`")
            lines.append(f"  {item['title']}: {item['why']}")
        if self.state.link_recommendations:
            lines.extend(["", "## Existing Page Recommendations", ""])
            for rec in self.state.link_recommendations:
                lines.append(f"- [{rec['id']}] `{rec['path']}`: {rec['reason']}")
        if self.state.rewrite_recommendations:
            lines.extend(["", "## Strong Rewrite Candidates", ""])
            for rec in self.state.rewrite_recommendations:
                lines.append(f"- [{rec['id']}] `{rec['path']}` ({rec['match_type']}): {rec['reason']}")
        return "\n".join(lines).rstrip() + "\n"

    def plan_markdown(self) -> str:
        """Render the publishing plan as a markdown document."""
        lines = [
            f"# Publishing Plan: {self.state.session_id}",
            "",
            self.state.publishing_plan.get("summary", "No plan generated."),
            "",
        ]
        if self.state.rewrite_recommendations:
            lines.extend(["## Rewrite Choices", ""])
            for rec in self.state.rewrite_recommendations:
                choice = self.state.rewrite_choices.get(rec["path"], "(pending)")
                lines.append(f"- [{rec['id']}] `{rec['path']}` -> {choice}")
            lines.append("")
        phases = self.state.publishing_plan.get("phases", [])
        if phases:
            lines.append("## Phases")
            lines.append("")
            for phase in phases:
                lines.append(f"### {phase['name']}")
                lines.append("")
                for step in phase.get("steps", []):
                    lines.append(f"- {step}")
                lines.append("")
        sequence = self.state.publishing_plan.get("publish_sequence", [])
        if sequence:
            lines.extend(["## Publish Sequence", ""])
            for item in sequence:
                lines.append(f"- {item}")
            lines.append("")
        questions = self.state.publishing_plan.get("editorial_questions", [])
        if questions:
            lines.extend(["## Editorial Questions", ""])
            for question in questions:
                lines.append(f"- {question}")
            lines.append("")
        return "\n".join(lines).rstrip() + "\n"

    # --- Repo scanning ---

    def scan_repo(self) -> None:
        """Walk the source repo and collect files, languages, readmes,
        docs, tests, git history, and duplicate blog candidates into
        a structured scan summary.
        """
        if not self.state.repo_path:
            self.assistant_say("No repo path is active. Add notes or restart with `cyborg ingest --repo <path>` if you want repo-backed scanning.")
            return

        if self._gitnexus_decision_pending():
            self.assistant_say(self._gitnexus_prompt_text())
            return

        repo_path = Path(self.state.repo_path)
        git_root = detect_git_root(repo_path)
        scan_root = git_root or repo_path
        self.state.repo_path = str(scan_root)
        self.state.repo_name = scan_root.name

        status = self.refresh_gitnexus_status()
        if self._gitnexus_decision_pending():
            self.assistant_say(self._gitnexus_prompt_text())
            return

        files = self._list_files(scan_root, git_root is not None)
        language_counts = self._language_counts(files)
        manifests = [str(path.relative_to(scan_root)) for path in files if path.name in {"pyproject.toml", "package.json", "Cargo.toml", "go.mod", "requirements.txt", "Makefile"}]
        readmes = [path for path in files if path.name.lower().startswith("readme")]
        docs = [path for path in files if "docs" in path.parts and path.suffix.lower() in {".md", ".txt", ".rst"}]
        tests = [path for path in files if any(part in {"tests", "test"} for part in path.parts)]
        code_files = [path for path in files if path.suffix.lower() in {".py", ".sh", ".js", ".ts", ".tsx", ".go", ".rs", ".rb"}]
        remote_url = ""
        if git_root:
            remote_url = run_command(["git", "remote", "get-url", "origin"], cwd=scan_root, allow_failure=True)
            recent_commits = run_command(["git", "log", "--oneline", "-n", "8"], cwd=scan_root, allow_failure=True)
            git_status = run_command(["git", "status", "--short"], cwd=scan_root, allow_failure=True)
        else:
            recent_commits = ""
            git_status = ""
        self.state.repo_remote = remote_url or None

        top_readme = readmes[0] if readmes else None
        readme_excerpt = ""
        if top_readme:
            readme_excerpt = self._read_excerpt(top_readme)

        doc_excerpt = ""
        if docs:
            doc_excerpt = self._read_excerpt(docs[0])

        code_excerpt = ""
        if code_files:
            code_excerpt = self._read_excerpt(code_files[0], max_lines=80)

        duplicate_candidates = self.find_duplicate_candidates()
        self.state.duplicate_candidates = duplicate_candidates
        self.state.scan_details = {
            "root": str(scan_root),
            "file_count": len(files),
            "language_counts": language_counts,
            "manifests": manifests,
            "readme": str(top_readme.relative_to(scan_root)) if top_readme else "",
            "docs_count": len(docs),
            "tests_count": len(tests),
            "sample_docs": [str(path.relative_to(scan_root)) for path in docs[:8]],
            "sample_code": [str(path.relative_to(scan_root)) for path in code_files[:8]],
            "recent_commits": recent_commits.splitlines(),
            "git_status": git_status.splitlines(),
            "duplicate_candidates": duplicate_candidates,
        }

        summary_lines = [
            f"# Repo Scan: {self.state.repo_name or scan_root.name}",
            "",
            f"- Root: `{scan_root}`",
            f"- Files: {len(files)}",
            f"- Docs: {len(docs)}",
            f"- Tests: {len(tests)}",
            f"- Manifests: {', '.join(manifests) if manifests else '(none detected)'}",
            f"- Remote: {remote_url or '(none detected)'}",
            "",
            "## Language Mix",
            "",
        ]
        if status:
            summary_lines.extend(
                [
                    f"- GitNexus: {status.get('state', 'unknown')} ({status.get('mode', 'native')} mode)",
                    f"- GitNexus Repo Name: {status.get('repo_name') or '(none detected)'}",
                    f"- GitNexus Indexed Commit: {status.get('indexed_commit') or '(none)'}",
                    "",
                ]
            )
        for ext, count in sorted(language_counts.items(), key=lambda item: (-item[1], item[0])):
            summary_lines.append(f"- {ext}: {count}")

        if readme_excerpt:
            summary_lines.extend(["", "## README Excerpt", "", readme_excerpt])
        if doc_excerpt:
            summary_lines.extend(["", "## Docs Excerpt", "", doc_excerpt])
        if code_excerpt:
            summary_lines.extend(["", "## Representative Code", "", code_excerpt])
        if recent_commits:
            summary_lines.extend(["", "## Recent Commits", ""])
            summary_lines.extend(f"- {line}" for line in recent_commits.splitlines())
        if self.state.gitnexus_summary:
            summary_lines.extend(["", "## GitNexus Signals", ""])
            for process in self.state.gitnexus_summary.get("processes", [])[:4]:
                summary_lines.append(f"- Flow: {process.get('summary', 'unknown flow')} ({process.get('step_count', '?')} steps)")
            for definition in self.state.gitnexus_summary.get("definitions", [])[:4]:
                summary_lines.append(f"- Definition: {definition.get('name', 'unknown')} -> `{definition.get('filePath', '')}`")
        if duplicate_candidates:
            summary_lines.extend(["", "## Cyborg Lab Candidates", ""])
            for candidate in duplicate_candidates:
                summary_lines.append(f"- `{candidate['path']}`: {candidate['snippet']}")

        self.state.scan_summary = "\n".join(summary_lines).rstrip() + "\n"
        self.state.phase = "mapped" if self.state.content_map else "scanned"
        self.save()
        self.assistant_say(
            "\n".join(
                [
                    "Repo scan complete.",
                    f"- Root: {scan_root}",
                    f"- Files: {len(files)}",
                    f"- Duplicate candidates: {len(duplicate_candidates)}",
                    f"- GitNexus: {status.get('state', 'unknown')} ({status.get('mode', 'native')} mode)",
                    "Run `/map` when you want the first content graph.",
                ]
            )
        )

    def _list_files(self, root: Path, use_git: bool) -> list[Path]:
        """Get a list of files in the repo.  Prefers `git ls-files`,
        falls back to `rg --files`, then to Python's rglob.
        """
        if use_git:
            try:
                output = run_command(["git", "ls-files"], cwd=root, allow_failure=False)
                return [root / line for line in output.splitlines() if line.strip()]
            except RuntimeError:
                pass
        try:
            output = run_command(["rg", "--files", str(root)], allow_failure=False)
            return [Path(line) for line in output.splitlines() if line.strip()]
        except RuntimeError:
            return [path for path in root.rglob("*") if path.is_file()]

    def _language_counts(self, files: list[Path]) -> dict[str, int]:
        """Count how many files exist for each file extension."""
        counts: dict[str, int] = {}
        for path in files:
            ext = path.suffix.lower() or "(no-ext)"
            counts[ext] = counts.get(ext, 0) + 1
        return counts

    def _read_excerpt(self, path: Path, *, max_lines: int = 60) -> str:
        """Read the first N lines of a file for use in the scan summary."""
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            return ""
        excerpt = lines[:max_lines]
        return "\n".join(excerpt).strip()

    def find_duplicate_candidates(self) -> list[dict[str, str]]:
        """Search the blog's content/ folder for existing pages that
        already mention this repo.  Uses `rg -F` (fixed-string) so
        special characters in repo names don't break the search.
        """
        blog_content = self.blog_root / "content"
        if not blog_content.exists():
            return []
        search_terms = [term for term in {self.state.repo_name or "", slugify(self.state.repo_name or ""), extract_first_heading(self.state.article_text or "") or ""} if term]
        if self.state.repo_remote:
            search_terms.append(self.state.repo_remote)
        candidates: list[dict[str, str]] = []
        seen_paths: set[str] = set()
        for term in search_terms:
            pattern = term
            try:
                output = run_command(
                    ["rg", "-F", "-n", "-i", "--glob", "*.md", pattern, str(blog_content)],
                    allow_failure=True,
                )
            except RuntimeError:
                output = ""
            for line in output.splitlines():
                if not line.strip():
                    continue
                path_part, _, snippet = line.partition(":")
                rel_path = str(Path(path_part).resolve().relative_to(self.blog_root))
                if rel_path in seen_paths:
                    continue
                seen_paths.add(rel_path)
                candidates.append({"path": rel_path, "snippet": short_preview(snippet, 160)})
                if len(candidates) >= 8:
                    return candidates
        return candidates

    def _classify_duplicate_match(self, candidate: dict[str, str]) -> str:
        """Decide if a duplicate candidate is a 'strong' or 'medium' match."""
        repo_slug = slugify(self.state.repo_name or "")
        candidate_path = candidate["path"].lower()
        snippet = candidate.get("snippet", "").lower()
        if repo_slug and repo_slug in candidate_path:
            return "strong"
        repo_name = (self.state.repo_name or "").lower()
        if repo_name and repo_name in snippet:
            return "strong"
        return "medium"

    def _build_rewrite_recommendations(self) -> list[dict[str, Any]]:
        """Build the list of existing pages that are strong enough
        matches to offer the user update/iteration-log/merge choices.
        Returns the existing list unchanged when nothing new happened.
        """
        if not self.state.gitnexus_status.get("repo_changed_since_session"):
            return self.state.rewrite_recommendations
        recommendations: list[dict[str, Any]] = []
        for candidate in self.state.duplicate_candidates:
            if self._classify_duplicate_match(candidate) != "strong":
                continue
            path = candidate["path"]
            match_type = section_type_from_content_path(path) or "unknown"
            matched_item = self._matching_item_for_existing_path(path)
            if not matched_item:
                continue
            recommendations.append(
                {
                    "id": len(recommendations) + 1,
                    "path": path,
                    "reason": f"Existing {match_type} page already matches this repo thread closely enough to consider an iteration update.",
                    "match_type": match_type,
                    "content_key": matched_item["key"],
                    "link_id": next((rec["id"] for rec in self.state.link_recommendations if rec["path"] == path), None),
                }
            )
        return recommendations

    def _pending_rewrite_recommendations(self) -> list[dict[str, Any]]:
        """Filter rewrite recommendations to only those the user
        has not made a choice for yet.
        """
        return [rec for rec in self.state.rewrite_recommendations if rec["path"] not in self.state.rewrite_choices]

    def _rewrite_prompt_text(self, recommendations: Optional[list[dict[str, Any]]] = None) -> str:
        """Format the prompt that lists strong matches and asks the
        user to choose update, iteration-log, or merge for each.
        """
        prompt_recommendations = recommendations if recommendations is not None else self._pending_rewrite_recommendations()
        lines = ["Strong existing-page matches detected after the refreshed map:"]
        single_choice_mode = len(prompt_recommendations) == 1
        for rec in prompt_recommendations:
            choice_prefix = "" if single_choice_mode else str(rec["id"])
            lines.append(f"[{rec['id']}] {rec['path']} ({rec['match_type']})")
            lines.append(f"    {rec['reason']}")
            lines.append("    A. Update the existing page in place.")
            lines.append("    B. Keep the page and route the new narrative into an iteration log.")
            lines.append("    C. Merge via related-link updates only.")
            lines.append("    D. Leave this choice pending for now.")
            lines.append("    E. Custom `/rewrite` command or note.")
            lines.append(
                f"    Reply with `{choice_prefix}A`, `{choice_prefix}B`, `{choice_prefix}C`, `{choice_prefix}D`, or `{choice_prefix}E`, or use `/rewrite {rec['id']} update|iteration-log|merge`."
            )
        return "\n".join(lines)

    def _matching_item_for_existing_path(self, path_value: str) -> Optional[dict[str, Any]]:
        """Find the content-map item that best matches an existing
        blog page path (by type and slug similarity).
        """
        match_type = section_type_from_content_path(path_value)
        if not match_type:
            return None
        repo_slug = slugify(self.state.repo_name or "")
        items = self.state.content_map.get("items", [])
        typed_items = [item for item in items if item["type"] == match_type]
        for item in typed_items:
            if repo_slug and repo_slug in item["path"]:
                return item
        return typed_items[0] if typed_items else None

    def _set_iteration_log_target(self) -> dict[str, Any]:
        """Create (or return) a log-iteration content-map item that
        will hold a dated narrative update instead of overwriting
        the original log page.
        """
        repo_slug = slugify(self.state.repo_name or extract_first_heading(self.state.article_text or "") or "cyborg-lab-source")
        today = datetime.now().date().isoformat()
        items = self.state.content_map.get("items", [])
        for item in items:
            if item["key"] == "log-iteration":
                return item
        log_item = {
            "key": "log-iteration",
            "type": "log",
            "title": f"Iteration Log: {title_from_slug(repo_slug)}",
            "path": f"content/log/{repo_slug}-iteration-{today}.md",
            "why": "Narrative iteration log for the latest repo update.",
            "voice_mode": "log",
            "depends_on": ["project"],
            "existing_page_actions": [],
        }
        items.append(log_item)
        return log_item

    def choose_rewrite_mode(self, recommendation_id: int, mode: str) -> None:
        """Handle the /rewrite command.  The user picks one of three
        modes for a strong existing-page match:
        - update: rewrite the existing page in place
        - iteration-log: keep the old page, add a new dated log
        - merge: just add cross-links, no content change
        """
        normalized_mode = mode.strip().lower()
        normalized_mode = {
            "a": "update",
            "b": "iteration-log",
            "c": "merge",
        }.get(normalized_mode, normalized_mode)
        if normalized_mode not in {"update", "iteration-log", "merge"}:
            self.assistant_say("Rewrite mode must be one of: A/update, B/iteration-log, C/merge.")
            return
        recommendation = next((rec for rec in self.state.rewrite_recommendations if rec["id"] == recommendation_id), None)
        if not recommendation:
            self.assistant_say("No rewrite recommendation exists for that ID.")
            return

        target_path = recommendation["path"]
        matched_item = self._matching_item_for_existing_path(target_path)
        if normalized_mode == "update":
            if not matched_item:
                self.assistant_say("No compatible content-map item was found for that existing page.")
                return
            matched_item["path"] = target_path
            matched_item.setdefault("existing_page_actions", []).append(f"Rewrite in place: {target_path}")
            pending = self.state.pending_drafts.get(matched_item["key"])
            if pending:
                pending["path"] = target_path
            self.state.rewrite_choices[target_path] = "update"
            self.save()
            self.assistant_say(
                f"`{matched_item['key']}` will now update `{target_path}` in place. Re-run `/draft {matched_item['key']}` if you want a fresh draft for that target."
            )
            return

        if normalized_mode == "iteration-log":
            log_item = self._set_iteration_log_target()
            self.state.rewrite_choices[target_path] = "iteration-log"
            self.save()
            self.assistant_say(
                f"The refreshed session will preserve `{target_path}` and route the next narrative update into `{log_item['path']}`."
            )
            return

        self.state.rewrite_choices[target_path] = "merge"
        self.save()
        link_id = recommendation.get("link_id")
        if isinstance(link_id, int):
            self.patch_links([link_id])
        else:
            self.assistant_say("Merge mode saved. Use `/links` and `/patch-links` when you want to stage the related-link update.")

    # --- Content map ---

    def build_content_map(self) -> None:
        """Generate or refresh the content map (the set of proposed
        new pages).  Tries AI first; falls back to heuristics.
        """
        if self._gitnexus_decision_pending():
            self.assistant_say(self._gitnexus_prompt_text())
            return
        if not self.state.scan_summary and self.state.repo_path:
            self.scan_repo()
            if self._gitnexus_decision_pending():
                return

        content_map: dict[str, Any]
        if self.ai_client.enabled:
            try:
                content_map = self._ai_content_map()
            except RuntimeError as exc:
                self.assistant_say(f"AI map generation failed, falling back to deterministic mapping.\nReason: {exc}")
                content_map = self._heuristic_content_map()
        else:
            content_map = self._heuristic_content_map()

        self.state.content_map = content_map
        self.state.rewrite_recommendations = self._build_rewrite_recommendations()
        if self.state.gitnexus_status.get("repo_changed_since_session"):
            self.state.gitnexus_status["repo_changed_since_session"] = False
        self.state.phase = "mapped"
        self.save()
        self.assistant_say(self.content_map_markdown().strip())
        pending_rewrites = self._pending_rewrite_recommendations()
        if pending_rewrites:
            self.assistant_say(self._rewrite_prompt_text(pending_rewrites))

    def _ai_content_map(self) -> dict[str, Any]:
        """Ask the AI to generate a content map from the scan data."""
        # Include available archetype types so the AI proposes only
        # content types that the blog actually supports.
        archetype_types = sorted(
            k for k in self.state.blog_archetypes if k != "default"
        ) if self.state.blog_archetypes else []
        prompt = {
            "repo_name": self.state.repo_name,
            "repo_remote": self.state.repo_remote,
            "source_text": self.state.source_text,
            "article_text": self.state.article_text,
            "intake_notes": self.state.intake_notes,
            "scan_summary": self.state.scan_summary,
            "duplicate_candidates": self.state.duplicate_candidates,
            "gitnexus_status": self.state.gitnexus_status,
            "gitnexus_summary": self.state.gitnexus_summary,
            "available_content_types": archetype_types,
        }
        response = self.ai_client.chat_json(
            self._build_system_prompt(),
            textwrap.dedent(
                f"""
                Generate the first Cyborg Lab content map for this source material.
                Return JSON with this shape:
                {{
                  "summary": "short paragraph",
                  "items": [
                    {{
                      "key": "stable-key",
                      "type": "project|workflow|artifact|log|reference|protocol|stack",
                      "title": "page title",
                      "path": "content/.../file.md",
                      "why": "why this page exists",
                      "voice_mode": "documentation|log",
                      "depends_on": ["other-key"],
                      "existing_page_actions": ["optional short notes"]
                    }}
                  ],
                  "existing_page_recommendations": [
                    {{
                      "path": "content/.../page.md",
                      "reason": "why this existing page should link into the set",
                      "action": "recommended change"
                    }}
                  ]
                }}

                Source payload:
                {json.dumps(prompt, indent=2)}
                """
            ).strip(),
            cache_system=True,
            max_tokens=1400,
        )
        normalized = self._normalize_content_map(response)
        if not normalized.get("items"):
            raise RuntimeError("AI returned no usable content-map items.")
        return normalized

    def _heuristic_content_map(self) -> dict[str, Any]:
        """Build a content map without AI using simple rules.

        Always creates project + workflow + artifact + log pages.
        Adds reference, stack, or protocol pages when the scan data
        suggests they are useful.
        """
        repo_slug = slugify(self.state.repo_name or extract_first_heading(self.state.article_text or "") or "cyborg-lab-source")
        repo_title = title_from_slug(repo_slug)
        track_name = self._infer_track()
        track_segment = track_slug(track_name)
        top_flow = next(iter(self.state.gitnexus_summary.get("processes", [])), {})
        flow_hint = top_flow.get("summary", "").strip()
        log_title = extract_first_heading(self.state.article_text or "") or f"Field Report: Building {repo_title}"
        workflow_title = f"{repo_title} Workflow"
        artifact_title = f"{repo_title} Command Sheet"
        project_title = repo_title
        reference_title = f"{repo_title} Reference Index"
        items = [
            {
                "key": "project",
                "type": "project",
                "title": project_title,
                "path": f"content/projects/{repo_slug}.md",
                "why": "Mission-level page that connects the repo, the main workflow, and the reusable outputs into one outcome.",
                "voice_mode": "documentation",
                "depends_on": ["workflow-main", "artifact-main"],
                "existing_page_actions": [],
            },
            {
                "key": "workflow-main",
                "type": "workflow",
                "title": workflow_title,
                "path": f"content/workflows/{track_segment}/{repo_slug}-workflow.md",
                "why": "Execution-first page that teaches the repeatable path through the repo from setup to successful output."
                + (f" GitNexus highlighted `{flow_hint}` as a core execution flow." if flow_hint else ""),
                "voice_mode": "documentation",
                "depends_on": [],
                "existing_page_actions": [],
            },
            {
                "key": "artifact-main",
                "type": "artifact",
                "title": artifact_title,
                "path": f"content/artifacts/{repo_slug}-command-sheet.md",
                "why": "Copy-ready artifact that extracts the commands, scripts, or templates someone needs without rereading the full repo.",
                "voice_mode": "documentation",
                "depends_on": ["workflow-main"],
                "existing_page_actions": [],
            },
            {
                "key": "log-main",
                "type": "log",
                "title": log_title,
                "path": f"content/log/{repo_slug}-field-report.md",
                "why": "Narrative field report that captures why the repo matters, what changed, and how it performed in practice.",
                "voice_mode": "log",
                "depends_on": ["project"],
                "existing_page_actions": [],
            },
        ]
        if self._should_add_reference():
            items.append(
                {
                    "key": "reference-main",
                    "type": "reference",
                    "title": reference_title,
                    "path": f"content/reference/{repo_slug}-index.md",
                    "why": "Lookup page that consolidates commands, files, or related pages for quick re-entry later.",
                    "voice_mode": "documentation",
                    "depends_on": ["workflow-main", "artifact-main"],
                    "existing_page_actions": [],
                }
            )
        if self._should_add_stack():
            items.append(
                {
                    "key": "stack-main",
                    "type": "stack",
                    "title": f"{repo_title} Local Stack",
                    "path": f"content/stacks/{repo_slug}-local-stack.md",
                    "why": "Local setup page for the environment and dependencies that make the repo usable.",
                    "voice_mode": "documentation",
                    "depends_on": [],
                    "existing_page_actions": [],
                }
            )
        if self._should_add_protocol():
            items.append(
                {
                    "key": "protocol-main",
                    "type": "protocol",
                    "title": f"{repo_title} Prompt Contract",
                    "path": f"content/systems/protocols/{repo_slug}-prompt-contract.md",
                    "why": "Prompt/system contract page extracted from prompt-heavy source material.",
                    "voice_mode": "documentation",
                    "depends_on": [],
                    "existing_page_actions": [],
                }
            )
        recommendations = []
        for index, candidate in enumerate(self.state.duplicate_candidates, start=1):
            recommendations.append(
                {
                    "id": index,
                    "path": candidate["path"],
                    "reason": f"Candidate overlap with the repo or article source: {candidate['snippet']}",
                    "action": "Review for update-or-link instead of creating a duplicate angle.",
                }
            )
        summary = (
            f"Start with a four-page core set around {repo_title}: project, workflow, artifact, and log. "
            "Add a reference page only if the repo has enough command density or navigation surface to justify it."
        )
        if flow_hint:
            summary += f" GitNexus surfaced `{flow_hint}` as a likely high-signal flow to anchor the workflow page."
        return self._normalize_content_map(
            {
                "summary": summary,
                "items": items,
                "existing_page_recommendations": recommendations,
            }
        )

    def _normalize_content_map(self, content_map: dict[str, Any]) -> dict[str, Any]:
        """Clean up and standardize a content map (from AI or heuristics).
        Makes sure every item has all required fields and unique keys.
        """
        items = []
        seen_keys: set[str] = set()
        for raw_item in content_map.get("items", []):
            if not isinstance(raw_item, dict):
                continue
            key = raw_item.get("key") or slugify(raw_item.get("title", "item"))
            item_type = str(raw_item.get("type", "project")).strip().lower() or "project"
            if item_type not in CONTENT_TYPES:
                item_type = "project"
            title = str(raw_item.get("title", "")).strip() or title_from_slug(key)
            dir_template = CONTENT_TYPES[item_type]["dir"]
            default_dir = dir_template.format(track_slug=track_slug(self._infer_track()))
            path = str(raw_item.get("path", "")).strip() or f"{default_dir}/{slugify(key or title or item_type)}.md"
            if not path.startswith("content/") or not path.endswith(".md"):
                path = f"{default_dir}/{slugify(key or title or item_type)}.md"
            if key in seen_keys:
                key = f"{key}-{len(seen_keys) + 1}"
            seen_keys.add(key)
            items.append(
                {
                    "key": key,
                    "type": item_type,
                    "title": title,
                    "path": path,
                    "why": raw_item.get("why", ""),
                    "voice_mode": raw_item.get("voice_mode", "documentation"),
                    "depends_on": raw_item.get("depends_on", []),
                    "existing_page_actions": raw_item.get("existing_page_actions", []),
                }
            )

        recommendations = []
        for index, rec in enumerate(content_map.get("existing_page_recommendations", []), start=1):
            if not isinstance(rec, dict):
                continue
            rec_path = str(rec.get("path", "")).strip()
            if not rec_path:
                continue
            recommendations.append(
                {
                    "id": rec.get("id", index),
                    "path": rec_path,
                    "reason": rec.get("reason", "Related existing page worth reviewing."),
                    "action": rec.get("action", "Add related-set links."),
                }
            )
        self.state.link_recommendations = recommendations
        return {
            "summary": content_map.get("summary", ""),
            "items": items,
            "existing_page_recommendations": recommendations,
        }

    def _infer_track(self) -> str:
        """Guess which workflow track this repo belongs to by looking
        for keywords in the repo name, article, and scan summary.
        """
        signal = " ".join(
            filter(
                None,
                [
                    self.state.repo_name or "",
                    self.state.source_text,
                    self.state.article_text,
                    self.state.scan_summary,
                ],
            )
        ).lower()
        if any(term in signal for term in ("shortcut", "keyboard", "hotkey", "talon")):
            return "Keyboard Efficiency"
        if any(term in signal for term in ("prompt", "openrouter", "llm", "agent", "ai", "model")):
            return "AI Frameworks"
        if any(term in signal for term in ("brain fog", "accessibility", "ms", "fatigue", "energy")):
            return "Brain Fog Systems"
        if any(term in signal for term in ("decision", "compare", "choice", "ranking")):
            return "Decision Systems"
        if any(term in signal for term in ("thinking", "analysis", "reasoning", "framework")):
            return "Thinking Frameworks"
        return "Productivity Systems"

    def _should_add_reference(self) -> bool:
        """True if the repo has enough files or docs to justify a
        standalone reference/index page.
        """
        details = self.state.scan_details
        return details.get("file_count", 0) >= 20 or bool(details.get("sample_docs"))

    def _should_add_stack(self) -> bool:
        """True if the repo has package manifests that suggest a
        local-stack setup page would be helpful.
        """
        details = self.state.scan_details
        signal = " ".join(details.get("manifests", [])).lower()
        return any(name in signal for name in ("pyproject", "package", "requirements", "cargo", "go.mod"))

    def _should_add_protocol(self) -> bool:
        """True if the source material mentions prompt contracts or
        system instructions — a sign that a protocol page is useful.
        """
        signal = " ".join([self.state.source_text, self.state.article_text, self.state.scan_summary]).lower()
        return any(term in signal for term in ("system prompt", "prompt contract", "instruction template", "persona"))

    # --- Code improvements ---

    def build_code_improvement_plan(self) -> None:
        """Generate a prioritized, code-first improvement plan for the source repo."""
        if not self.state.repo_path:
            self.assistant_say("No repo path is active. Start with `cyborg ingest --repo <path>` or `/scan` in a project folder.")
            return
        if self._gitnexus_decision_pending():
            self.assistant_say(self._gitnexus_prompt_text())
            return
        if not self.state.scan_summary:
            self.scan_repo()
            if self._gitnexus_decision_pending():
                return

        if self.ai_client.enabled:
            try:
                plan = self._ai_code_improvement_plan()
            except RuntimeError as exc:
                self.assistant_say(f"AI improvement planning failed, using deterministic heuristics.\nReason: {exc}")
                plan = self._heuristic_code_improvement_plan()
        else:
            plan = self._heuristic_code_improvement_plan()

        self.state.code_improvement_plan = plan
        self.state.pending_repo_edits = {}
        self.save()
        self.assistant_say(self.code_improvement_markdown().strip())

    def _ai_code_improvement_plan(self) -> dict[str, Any]:
        """Ask the AI for a small, high-signal source-repo improvement backlog."""
        payload = {
            "repo_name": self.state.repo_name,
            "repo_remote": self.state.repo_remote,
            "repo_scan": self.state.scan_summary,
            "scan_details": self.state.scan_details,
            "gitnexus_status": self.state.gitnexus_status,
            "gitnexus_summary": self.state.gitnexus_summary,
            "morphling_context": self.state.article_text,
        }
        response = self.ai_client.chat_json(
            CODE_IMPROVEMENT_CONTRACT,
            textwrap.dedent(
                f"""
                Build a prioritized code-improvement plan for this repository.
                Return JSON with:
                {{
                  "summary": "short paragraph",
                  "items": [
                    {{
                      "title": "short improvement title",
                      "priority": "high|medium|low",
                      "kind": "bugfix|refactor|test|config|cleanup",
                      "why": "why this matters now",
                      "target_files": ["relative/path.py", "tests/test_x.py"],
                      "acceptance": ["observable outcome 1", "observable outcome 2"]
                    }}
                  ]
                }}

                Rules:
                - Prioritize code changes over documentation changes.
                - Prefer 1-3 high-signal improvements, not a laundry list.
                - Every improvement must name concrete target files.
                - Use GitNexus execution flows when they help identify the core path.

                Source payload:
                {json.dumps(payload, indent=2)}
                """
            ).strip(),
            temperature=0.25,
            cache_system=True,
            max_tokens=1200,
        )
        normalized = self._normalize_code_improvement_plan(response)
        if not normalized.get("items"):
            raise RuntimeError("AI returned no usable source-repo improvements.")
        return normalized

    def _heuristic_code_improvement_plan(self) -> dict[str, Any]:
        """Build a small deterministic improvement plan when AI is unavailable."""
        sample_code = [self._normalize_repo_relative_path(path) for path in self.state.scan_details.get("sample_code", [])]
        sample_code = [path for path in sample_code if path]
        manifest_paths = [self._normalize_repo_relative_path(path) for path in self.state.scan_details.get("manifests", [])]
        manifest_paths = [path for path in manifest_paths if path]
        flow = next(iter(self.state.gitnexus_summary.get("processes", [])), {})
        flow_hint = flow.get("summary", "").strip()
        graph_files: list[str] = []
        for entry in self.state.gitnexus_summary.get("process_symbols", [])[:6]:
            normalized = self._normalize_repo_relative_path(entry.get("filePath"))
            if normalized and normalized not in graph_files:
                graph_files.append(normalized)
        for entry in self.state.gitnexus_summary.get("definitions", [])[:6]:
            normalized = self._normalize_repo_relative_path(entry.get("filePath"))
            if normalized and normalized not in graph_files:
                graph_files.append(normalized)

        items: list[dict[str, Any]] = []
        core_targets = (graph_files or sample_code)[:2]
        if core_targets:
            title = "Harden the core execution flow"
            if flow_hint:
                title = f"Harden core flow: {flow_hint}"
            items.append(
                {
                    "id": 1,
                    "title": title,
                    "priority": "high",
                    "kind": "refactor",
                    "why": "Tighten the highest-signal execution path first so future features land on a more stable base.",
                    "target_files": core_targets,
                    "acceptance": [
                        "The main flow is easier to follow and less error-prone.",
                        "Core control flow has clearer boundaries or validation.",
                    ],
                }
            )

        if self.state.scan_details.get("tests_count", 0) == 0 and sample_code:
            items.append(
                {
                    "id": len(items) + 1,
                    "title": "Add a regression-oriented smoke test",
                    "priority": "medium",
                    "kind": "test",
                    "why": "This repo has code but no visible test surface in the tracked files.",
                    "target_files": [sample_code[0], "tests/test_smoke.py"],
                    "acceptance": [
                        "A basic test path exists for the core module.",
                        "The repo has a repeatable verification entry point.",
                    ],
                }
            )

        config_targets = [path for path in sample_code + manifest_paths if "config" in path.lower() or path.endswith(".toml") or path.endswith(".json")]
        if config_targets:
            items.append(
                {
                    "id": len(items) + 1,
                    "title": "Tighten configuration and runtime validation",
                    "priority": "medium",
                    "kind": "config",
                    "why": "Configuration drift is a common source of avoidable runtime failures.",
                    "target_files": config_targets[:2],
                    "acceptance": [
                        "Invalid configuration fails earlier and more clearly.",
                        "Defaults and overrides are easier to reason about.",
                    ],
                }
            )

        if not items and sample_code:
            items.append(
                {
                    "id": 1,
                    "title": "Tighten the primary source module",
                    "priority": "medium",
                    "kind": "cleanup",
                    "why": "Use the most representative source file as the first improvement surface.",
                    "target_files": [sample_code[0]],
                    "acceptance": [
                        "The module is clearer, safer, or easier to extend.",
                    ],
                }
            )

        summary = "Prioritize a small set of source-repo improvements before drafting documentation."
        if flow_hint:
            summary += f" GitNexus highlighted `{flow_hint}` as the best place to start."
        return {
            "summary": summary,
            "items": items[:3],
        }

    def _normalize_code_improvement_plan(self, plan: dict[str, Any]) -> dict[str, Any]:
        """Validate and normalize a repo-improvement plan payload."""
        normalized_items: list[dict[str, Any]] = []
        for raw_item in plan.get("items", []):
            if not isinstance(raw_item, dict):
                continue
            title = str(raw_item.get("title", "")).strip() or "Untitled source-repo improvement"
            priority = str(raw_item.get("priority", "medium")).strip().lower()
            if priority not in {"high", "medium", "low"}:
                priority = "medium"
            kind = str(raw_item.get("kind", "refactor")).strip().lower()
            if kind not in {"bugfix", "refactor", "test", "config", "cleanup"}:
                kind = "refactor"
            raw_targets = raw_item.get("target_files", [])
            if isinstance(raw_targets, str):
                raw_targets = [raw_targets]
            target_files: list[str] = []
            for raw_target in raw_targets:
                normalized = self._normalize_repo_relative_path(raw_target)
                if normalized and normalized not in target_files:
                    target_files.append(normalized)
            if not target_files:
                fallback_targets = [
                    self._normalize_repo_relative_path(path)
                    for path in self.state.scan_details.get("sample_code", [])[:2]
                ]
                target_files = [path for path in fallback_targets if path]
            if not target_files:
                continue
            acceptance = raw_item.get("acceptance", [])
            if isinstance(acceptance, str):
                acceptance = [acceptance]
            acceptance = [str(item).strip() for item in acceptance if str(item).strip()]
            normalized_items.append(
                {
                    "id": len(normalized_items) + 1,
                    "title": title,
                    "priority": priority,
                    "kind": kind,
                    "why": str(raw_item.get("why", "")).strip() or "High-signal source-repo improvement.",
                    "target_files": target_files[:4],
                    "acceptance": acceptance[:5],
                }
            )
        return {
            "summary": str(plan.get("summary", "")).strip() or "Source-repo improvements prioritized before documentation drafting.",
            "items": normalized_items[:4],
        }

    def _select_code_improvement(self, improvement_id: Optional[int]) -> Optional[dict[str, Any]]:
        """Return a planned improvement by ID, defaulting to the first item."""
        items = self.state.code_improvement_plan.get("items", [])
        if not items:
            return None
        if improvement_id is None:
            return items[0]
        return next((item for item in items if item["id"] == improvement_id), None)

    def stage_code_improvement(self, improvement_id: Optional[int] = None) -> None:
        """Generate staged source-repo edits for the selected improvement."""
        if not self.state.repo_path:
            self.assistant_say("No source repo is active for code improvements.")
            return
        if not self.state.code_improvement_plan:
            self.assistant_say("Generate the code improvement plan first with `/improve`.")
            return
        if not self.ai_client.enabled:
            self.assistant_say("AI is disabled, so I cannot stage source-repo edits right now.")
            return

        item = self._select_code_improvement(improvement_id)
        if not item:
            self.assistant_say("No matching code improvement ID was found.")
            return

        repo_root = self._repo_path()
        if not repo_root:
            self.assistant_say("No source repo is active for code improvements.")
            return

        file_payload: list[dict[str, Any]] = []
        skipped_oversized: list[str] = []
        for rel_path in item.get("target_files", [])[:4]:
            normalized = self._normalize_repo_relative_path(rel_path)
            if not normalized:
                continue
            abs_path = resolve_within_root(repo_root, repo_root / normalized, label="source repo")
            exists = abs_path.exists()
            content = ""
            if exists and abs_path.is_file():
                try:
                    content = abs_path.read_text(encoding="utf-8")
                except OSError:
                    continue
                if len(content) > 24000:
                    skipped_oversized.append(normalized)
                    continue
            file_payload.append(
                {
                    "path": normalized,
                    "exists": exists,
                    "content": content,
                }
            )

        if not file_payload:
            note = ""
            if skipped_oversized:
                note = f" Oversized files: {', '.join(skipped_oversized)}."
            self.assistant_say(f"I could not safely stage repo edits for `{item['title']}` from the current target file set.{note}")
            return

        response = self.ai_client.chat_json(
            CODE_IMPROVEMENT_CONTRACT,
            textwrap.dedent(
                f"""
                Stage a concrete source-repo improvement.
                Return JSON with:
                {{
                  "summary": "short summary of the staged improvement",
                  "edits": [
                    {{
                      "path": "relative/path.py",
                      "reason": "why this file changes",
                      "content": "full file contents"
                    }}
                  ],
                  "tests_to_run": ["optional verification command"]
                }}

                Rules:
                - Only edit paths from the allowed target file list below.
                - Keep changes surgical and focused on the chosen improvement.
                - Return complete file contents for each edited file.
                - If no safe edit is justified, return an empty edits list and explain why in summary.

                Chosen improvement:
                {json.dumps(item, indent=2)}

                Allowed target files with current contents:
                {json.dumps(file_payload, indent=2)}
                """
            ).strip(),
            temperature=0.2,
            cache_system=True,
            max_tokens=3200,
        )

        allowed_paths = {entry["path"] for entry in file_payload}
        pending: dict[str, dict[str, Any]] = {}
        for raw_edit in response.get("edits", []):
            if not isinstance(raw_edit, dict):
                continue
            rel_path = self._normalize_repo_relative_path(raw_edit.get("path"))
            if not rel_path or rel_path not in allowed_paths:
                continue
            content = str(raw_edit.get("content", ""))
            if not content.strip():
                continue
            pending[rel_path] = {
                "reason": str(raw_edit.get("reason", "")).strip() or item["why"],
                "content": content,
                "improvement_id": item["id"],
                "title": item["title"],
            }

        if not pending:
            summary = str(response.get("summary", "")).strip() or "No safe source-repo edits were staged."
            self.assistant_say(summary)
            return

        self.state.pending_repo_edits = pending
        self.save()
        lines = [
            str(response.get("summary", "")).strip() or f"Staged source-repo edits for improvement [{item['id']}] {item['title']}.",
            "Pending source-repo edits:",
        ]
        for rel_path, edit in sorted(pending.items()):
            lines.append(f"- `{rel_path}`: {edit['reason']}")
        if skipped_oversized:
            lines.append(f"Skipped oversized targets: {', '.join(skipped_oversized)}")
        tests_to_run = response.get("tests_to_run", [])
        if isinstance(tests_to_run, list) and tests_to_run:
            lines.append("Suggested verification:")
            lines.extend(f"- {str(cmd).strip()}" for cmd in tests_to_run[:4] if str(cmd).strip())
        lines.append("Use `/apply code --yes` when you want to write these source-repo edits.")
        self.assistant_say("\n".join(lines))

    # --- Publishing plan ---

    def build_publishing_plan(self) -> None:
        """Create a phased plan that tells the user what order to
        draft and publish pages.  Tries AI first; falls back.
        """
        if self._gitnexus_decision_pending():
            self.assistant_say(self._gitnexus_prompt_text())
            return
        if not self.state.content_map:
            self.assistant_say("Generate the content map first with `/map`.")
            return

        if self.ai_client.enabled:
            try:
                plan = self._ai_plan()
            except RuntimeError as exc:
                self.assistant_say(f"AI plan generation failed, using deterministic plan.\nReason: {exc}")
                plan = self._heuristic_plan()
        else:
            plan = self._heuristic_plan()

        self.state.publishing_plan = plan
        self.state.phase = "planned"
        self.save()
        self.assistant_say(self.plan_markdown().strip())

    def _ai_plan(self) -> dict[str, Any]:
        """Ask the AI to turn the content map into a publishing plan."""
        payload = {
            "content_map": self.state.content_map,
            "planning_notes": self.state.planning_notes,
            "duplicate_candidates": self.state.duplicate_candidates,
            "repo_scan": self.state.scan_summary,
            "gitnexus_status": self.state.gitnexus_status,
            "gitnexus_summary": self.state.gitnexus_summary,
            "rewrite_recommendations": self.state.rewrite_recommendations,
        }
        response = self.ai_client.chat_json(
            self._build_system_prompt(),
            textwrap.dedent(
                f"""
                Turn this approved content map into a concrete publishing plan.
                Return JSON with:
                {{
                  "summary": "short paragraph",
                  "phases": [{{"name": "phase name", "steps": ["step 1", "step 2"]}}],
                  "publish_sequence": ["key1", "key2"],
                  "editorial_questions": ["question 1", "question 2"]
                }}

                Source payload:
                {json.dumps(payload, indent=2)}
                """
            ).strip(),
            cache_system=True,
            max_tokens=1000,
        )
        return {
            "summary": response.get("summary", ""),
            "phases": response.get("phases", []),
            "publish_sequence": response.get("publish_sequence", []),
            "editorial_questions": response.get("editorial_questions", []),
        }

    def _heuristic_plan(self) -> dict[str, Any]:
        """Build a three-phase plan without AI: lock scope, draft
        core pages, then do narrative and cross-links.
        """
        items = self.state.content_map.get("items", [])
        ordered = [item["key"] for item in items if item["type"] in {"workflow", "artifact", "project", "log", "reference", "stack", "protocol"}]
        gitnexus_hint = next(iter(self.state.gitnexus_summary.get("processes", [])), {}).get("summary", "")
        return {
            "summary": "Lock the graph first, then draft the highest-signal reusable pages before the narrative log. Keep duplicate risk low by reviewing existing-page recommendations before writing anything into the live repo."
            + (f" GitNexus highlighted `{gitnexus_hint}` as a strong execution-flow anchor." if gitnexus_hint else ""),
            "phases": [
                {
                    "name": "Lock Scope",
                    "steps": [
                        "Review duplicate candidates and decide which existing pages should absorb links instead of spawning duplicates.",
                        "Confirm the workflow track and whether protocol/stack pages are truly justified.",
                    ],
                },
                {
                    "name": "Draft Core Pages",
                    "steps": [
                        "Draft the primary workflow and artifact first so the execution surface is stable.",
                        "Draft the project page after the workflow/artifact pair so the orchestration language is grounded in real sibling pages.",
                    ],
                },
                {
                    "name": "Narrative and Cross-links",
                    "steps": [
                        "Draft the log page once the documentation pages exist so the narrative can point into the reusable set.",
                        "Generate patch-ready edits for selected existing pages only after you approve the recommendation list.",
                        "If strong rewrite matches exist, pick update-in-place vs iteration-log before drafting the final log or workflow refresh.",
                    ],
                },
            ],
            "publish_sequence": ordered,
            "editorial_questions": [
                "Which page should carry the primary repo walkthrough without duplicating the project page?",
                "Is the log page a field report, a build retrospective, or a launch article?",
                "Which existing Cyborg Lab pages should link into this new set instead of getting new sibling pages?",
            ],
        }

    # --- Draft generation ---

    def build_drafts(self, targets: list[str]) -> None:
        """Generate near-publishable markdown drafts for the given
        content-map keys (or all keys if 'all' is passed).
        """
        if self._gitnexus_decision_pending():
            self.assistant_say(self._gitnexus_prompt_text())
            return
        if not self.state.publishing_plan:
            self.assistant_say("Generate the publishing plan first with `/plan`.")
            return

        items = self.state.content_map.get("items", [])
        requested = {target for target in targets if target != "all"}
        selected_items = items if not requested else [item for item in items if item["key"] in requested]
        if not selected_items:
            self.assistant_say("No matching content-map keys were found for draft generation.")
            return

        # Compute shared context once for the whole batch so the draft
        # loop can send it as a single cacheable message.
        shared_context = self._build_draft_shared_context() if self.ai_client.enabled else None

        total = len(selected_items)
        for index, item in enumerate(selected_items, start=1):
            self.assistant_say(f"Drafting [{index}/{total}] `{item['key']}`...")
            if self.ai_client.enabled:
                try:
                    draft = self._ai_draft(item, shared_context=shared_context)
                except RuntimeError as exc:
                    self.assistant_say(f"AI draft generation failed for `{item['key']}`, using deterministic draft.\nReason: {exc}")
                    draft = self._heuristic_draft(item)
            else:
                draft = self._heuristic_draft(item)
            self.state.pending_drafts[item["key"]] = draft
            self.save()
            self.assistant_say(f"Draft ready [{index}/{total}] `{item['key']}` -> `{draft['path']}`")

        self.state.phase = "drafted"
        self.save()
        draft_keys = ", ".join(item["key"] for item in selected_items)
        self.assistant_say(
            "\n".join(
                [
                    f"Generated pending drafts for: {draft_keys}",
                    "Use `/review <key>` to start editorial revisions.",
                    "Use `/show <key>` to inspect the current draft body.",
                    "Use `/apply drafts --yes` when you want to write them into the blog repo.",
                ]
            )
        )

    def _build_draft_shared_context(self) -> str:
        """Assemble the large, item-independent payload that every draft
        call needs.  Computed once in ``build_drafts`` and sent as a
        cacheable user message so OpenRouter can reuse the KV cache
        across the whole batch.
        """
        sibling_index = [
            {"key": s["key"], "title": s["title"], "type": s["type"], "path": s["path"]}
            for s in self.state.content_map.get("items", [])
        ]
        shared = {
            "siblings": sibling_index,
            "repo_name": self.state.repo_name,
            "repo_remote": self.state.repo_remote,
            "repo_scan": self.state.scan_summary,
            "gitnexus_status": self.state.gitnexus_status,
            "gitnexus_summary": self.state.gitnexus_summary,
            "article_text": self.state.article_text,
            "source_text": self.state.source_text,
            "planning_notes": self.state.planning_notes,
            "rewrite_choices": self.state.rewrite_choices,
        }
        return f"Shared draft context (applies to every item in this batch):\n{json.dumps(shared, indent=2)}"

    def _ai_draft(self, item: dict[str, Any], *, shared_context: Optional[str] = None) -> dict[str, Any]:
        """Ask the AI to write a full Hugo markdown draft for one item.

        When *shared_context* is provided (the normal path from
        ``build_drafts``), a 3-message pattern is used so OpenRouter can
        cache the system prompt and shared context across the batch:

        1. System message  (``cache_control``)
        2. Shared context  (``cache_control``)
        3. Per-item instruction  (unique per draft)

        Calls 2-N in a batch only pay for message 3.
        """
        per_item = {
            "target_item": item,
            "editorial_notes": self.state.editorial_notes[-6:],
        }
        instruction = textwrap.dedent(
            f"""
            Write a near-publishable Cyborg Lab draft for the target item.
            Return JSON with:
            {{
              "title": "page title",
              "path": "content/.../page.md",
              "markdown": "full markdown file including frontmatter"
            }}

            Requirements:
            - Frontmatter must match the target content type.
            - Use draft: true.
            - No H1 headings in the body.
            - Link to sibling pages with real paths from the sibling index.
            - If a repo URL exists, surface it early in the body.
            - Preserve supplied source links from the article when relevant.

            Per-item payload:
            {json.dumps(per_item, indent=2)}
            """
        ).strip()

        if shared_context is not None:
            messages = [
                OpenRouterClient._with_cache_control(
                    {"role": "system", "content": self._build_system_prompt()}
                ),
                OpenRouterClient._with_cache_control(
                    {"role": "user", "content": shared_context}
                ),
                {"role": "user", "content": instruction},
            ]
            response = self.ai_client.chat_json_messages(messages, temperature=0.35, max_tokens=2600)
        else:
            # Fallback: single-call path (e.g. individual re-draft).
            sibling_index = [
                {"key": s["key"], "title": s["title"], "type": s["type"], "path": s["path"]}
                for s in self.state.content_map.get("items", [])
            ]
            payload = {
                "target_item": item,
                "siblings": sibling_index,
                "repo_name": self.state.repo_name,
                "repo_remote": self.state.repo_remote,
                "repo_scan": self.state.scan_summary,
                "gitnexus_status": self.state.gitnexus_status,
                "gitnexus_summary": self.state.gitnexus_summary,
                "article_text": self.state.article_text,
                "source_text": self.state.source_text,
                "planning_notes": self.state.planning_notes,
                "rewrite_choices": self.state.rewrite_choices,
                "editorial_notes": self.state.editorial_notes[-6:],
            }
            response = self.ai_client.chat_json(
                self._build_system_prompt(),
                f"{instruction}\n\nSource payload:\n{json.dumps(payload, indent=2)}",
                temperature=0.35,
                cache_system=True,
                max_tokens=2600,
            )

        return {
            "key": item["key"],
            "type": item["type"],
            "title": response.get("title", item["title"]),
            "path": response.get("path", item["path"]),
            "markdown": response["markdown"],
        }

    def _heuristic_draft(self, item: dict[str, Any]) -> dict[str, Any]:
        """Build a draft from templates when AI is not available."""
        repo_title = item["title"]
        repo_url = self.state.repo_remote or ""
        sibling_links = self._sibling_links(item["key"])
        markdown = self._draft_template(item, repo_title, repo_url, sibling_links)
        return {
            "key": item["key"],
            "type": item["type"],
            "title": item["title"],
            "path": item["path"],
            "markdown": markdown,
        }

    def _sibling_links(self, current_key: str) -> list[tuple[str, str]]:
        """Get a list of (title, web_path) pairs for sibling pages
        so drafts can link to each other.
        """
        links = []
        for sibling in self.state.content_map.get("items", []):
            if sibling["key"] == current_key:
                continue
            web_path = "/" + "/".join(Path(sibling["path"]).with_suffix("").parts[1:]) + "/"
            links.append((sibling["title"], web_path))
        return links[:5]

    def _draft_template(self, item: dict[str, Any], title: str, repo_url: str, sibling_links: list[tuple[str, str]]) -> str:
        """Assemble a full Hugo markdown file (frontmatter + body)
        for one content-map item using the deterministic template.
        """
        description = normalize_description(
            {
                "project": f"Integrated project page for {title} that connects setup, execution, and reusable outputs so readers can move from repo context to measurable results fast.",
                "workflow": f"End-to-end workflow for {title} with setup, execution, verification, and fallback steps so readers can run the repo without rebuilding the path from scratch.",
                "artifact": f"Copy-ready artifact for {title} that extracts the critical commands, templates, or snippets so operators can deploy immediately and verify behavior quickly.",
                "log": f"Field report for {title} documenting what changed, what worked, and what still needs tightening so the repo's lessons stay actionable instead of fading into archive noise.",
                "reference": f"Lookup-first reference for {title} that consolidates the key files, commands, and related links so readers can re-enter the project without a full reread.",
                "stack": f"Reusable local stack for {title} that maps setup friction into a stable environment so execution starts faster and stays repeatable under variable energy.",
                "protocol": f"Deterministic prompt contract for {title} that reduces ambiguity and returns consistent, action-ready output with a documented structure and fallback behavior.",
            }[item["type"]]
        )
        frontmatter = self._frontmatter_for_item(item, description)
        body = self._body_for_item(item, title, repo_url, sibling_links)
        return f"---\n{frontmatter}---\n\n{body}".rstrip() + "\n"

    def _frontmatter_for_item(self, item: dict[str, Any], description: str) -> str:
        """Generate the YAML frontmatter block for a Hugo page.

        If blog archetypes were loaded, the frontmatter is driven by the
        archetype's parsed field list so it always matches the real Hugo
        schema.  Falls back to a hardcoded mapping when archetypes are
        not available (e.g., blog repo missing or offline work).
        """
        today = datetime.now().date().isoformat()
        type_name = item["type"]
        archetype = self.state.blog_archetypes.get(type_name)

        if archetype:
            return self._frontmatter_from_archetype(
                archetype, item, description, today
            )
        return self._frontmatter_hardcoded(item, description, today)

    def _frontmatter_from_archetype(
        self,
        archetype: dict[str, Any],
        item: dict[str, Any],
        description: str,
        today: str,
    ) -> str:
        """Build frontmatter by walking the archetype's field list.

        Each field gets its default value from the archetype, with
        overrides for title, description, date, and categories.
        """
        # Fields we emit manually (title, description already handled).
        skip_fields = {"title", "description"}
        type_name = item["type"]
        lines = [
            f'type: "{type_name}"',
            f'title: "{item["title"]}"',
            f'description: "{description}"',
        ]
        for fld in archetype.get("fields", []):
            name = fld["name"]
            if name in skip_fields or name == "type":
                continue
            value = fld.get("value", "")
            # Replace Hugo template date placeholders with today.
            if name in {"date", "lastmod", "last_tested", "last_generated"}:
                lines.append(f"{name}: {today}")
            elif name == "categories" and type_name == "workflow":
                lines.append(f'categories: ["{self._infer_track()}"]')
            elif fld.get("is_list"):
                # Lists like tags, tools, prerequisites — emit YAML list.
                if isinstance(value, list) and value:
                    lines.append(f"{name}:")
                    for v in value:
                        lines.append(f"  - {v}")
                else:
                    lines.append(f"{name}: []")
            elif value == "":
                # Empty string placeholder — keep the field present.
                lines.append(f'{name}: ""')
            elif isinstance(value, bool) or str(value).lower() in {"true", "false"}:
                # Booleans must be bare YAML (draft: true, not "true").
                lines.append(f"{name}: {str(value).lower()}")
            else:
                # Scalar with a default (may be quoted or bare).
                cleaned = re.sub(r"\{\{.*?\}\}", "", str(value)).strip()
                if cleaned:
                    lines.append(f'{name}: "{cleaned}"')
                else:
                    lines.append(f'{name}: ""')
        return "\n".join(lines) + "\n"

    def _frontmatter_hardcoded(
        self, item: dict[str, Any], description: str, today: str
    ) -> str:
        """Legacy hardcoded frontmatter when archetypes are unavailable."""
        type_name = item["type"]
        lines = [
            f'type: "{type_name}"',
            f'title: "{item["title"]}"',
            f'description: "{description}"',
        ]
        if type_name == "workflow":
            lines.extend(
                [
                    'jtbd: "Do"',
                    "prerequisites: []",
                    "related_workflows: []",
                    "related_references: []",
                    'categories: ["%s"]' % self._infer_track(),
                ]
            )
        elif type_name == "project":
            lines.extend(
                [
                    'status: "beta"',
                    "components: []",
                ]
            )
        elif type_name == "artifact":
            lines.extend(
                [
                    'artifact_type: "config"',
                    'format: "markdown"',
                    "generated_by: []",
                    'source_workflow: "/workflows/example-workflow/"',
                ]
            )
        elif type_name == "log":
            lines.append('log_kind: "field-report"')
        elif type_name == "stack":
            lines.extend(
                [
                    "tools:",
                    "  - zsh",
                    'os: "macOS"',
                ]
            )
        elif type_name == "protocol":
            lines.extend(
                [
                    'agent: "OpenRouter-Compatible"',
                    'status: "beta"',
                ]
            )
        lines.extend(
            [
                f"date: {today}",
                f"lastmod: {today}",
            ]
        )
        if type_name in {"workflow", "project", "artifact", "stack", "protocol"}:
            lines.append(f"last_tested: {today}")
        if type_name == "artifact":
            lines.append(f"last_generated: {today}")
        lines.append("draft: true")
        tags = {
            "project": ["project", "pipeline"],
            "workflow": ["workflow", "manual"],
            "artifact": ["artifact", "output", "proof-of-work"],
            "log": ["log", "update"],
            "reference": ["reference"],
            "stack": ["stack", "automation", "accessibility"],
            "protocol": ["protocol", "agent-config"],
        }.get(type_name, [type_name])
        lines.append("tags:")
        lines.extend(f"  - {tag}" for tag in tags)
        return "\n".join(lines) + "\n"

    def _body_for_item(self, item: dict[str, Any], title: str, repo_url: str, sibling_links: list[tuple[str, str]]) -> str:
        """Generate the markdown body for a draft.  Each content type
        has its own template with placeholder sections the user fills in.
        """
        repo_line = f"Repository: [{repo_url}]({repo_url})" if repo_url else "Repository: add the canonical repo URL here before publishing."
        article_links = extract_links(self.state.article_text)
        source_lines = "\n".join(f"- {url}" for url in article_links[:8]) if article_links else "- Add source links from the fact-checked draft before publishing."

        if item["type"] == "project":
            body = f"""
            ## Outcome

            {title} should exist as the mission-level page for this repo-backed set. It anchors the why, the working shape of the system, and the practical outputs readers can reuse without reverse engineering the repo from scratch.

            {repo_line}

            ## Components

            - Workflow: connect the main setup-and-use path here.
            - Artifact: link the command sheet, template, or reusable output here.
            - Log: link the field report when the narrative angle matters.

            ## Pipeline

            ### Phase 1: Setup

            Summarize the environment, dependencies, and assumptions surfaced by the repo scan. Keep it concrete enough that a reader can tell whether the project matches their constraints before they commit time.

            ### Phase 2: Execution

            Walk through the highest-value path through the repo. Call out what the reader actually runs, which files matter, and what output proves they are on track.

            ### Phase 3: Delivery

            End with the result that makes this project worth documenting in Cyborg Lab: the generated output, the saved time, the reduced friction, or the new capability unlocked.

            ## Artifacts

            - Link the reusable outputs generated by this project.

            ## Verification

            - Last successful run: add the latest tested date and environment.
            - Known failure mode: note the first thing that tends to break.

            ## Related

            {self._related_block(sibling_links)}
            """
        elif item["type"] == "workflow":
            body = f"""
            {{< quick title="Quick Path" >}}
            1. Trigger: identify when the repo should be reached for.
            2. Action: run the shortest high-value path through the repo.
            3. Verify: confirm the expected output exists before moving on.
            {{< /quick >}}

            ## Need

            This workflow should remove the need to rediscover the repo's setup and execution path under pressure. Use the scan summary to keep the route concrete and low-friction.

            {repo_line}

            ## Walkthrough

            ### Step 1: Trigger

            Describe the exact situation that should make the reader reach for this repo. Tie it to the job the repo actually does well.

            ### Step 2: Setup

            Document the environment checks, dependency steps, and local assumptions that repeatedly matter. If the repo only works after one hidden prerequisite, surface it here instead of burying it.

            ### Step 3: Run

            Show the core command or process path. Explain the expected intermediate outputs, not just the final success state, so the reader can recover quickly when reality diverges.

            ### Step 4: Verify

            Spell out what success looks like in observable terms: generated files, terminal output, or a visible UI state.

            ## Verification

            - Observable completion signal:
            - Expected output:
            - Time to completion:

            ## Failure Mode

            Note the most common breakage point and the fastest recovery path.

            ## Related

            {self._related_block(sibling_links)}
            """
        elif item["type"] == "artifact":
            body = f"""
            ## What This Is

            This artifact page should extract the piece of the repo that a reader wants to copy, keep, or rerun without rereading the entire implementation.

            {repo_line}

            ## Quick Use

            ```text
            Add the final copy-ready commands, template, or snippet here.
            ```

            ## Provenance

            - Source repo:
            - Source workflow:
            - Last generated:

            ## Verification

            - Expected behavior:
            - Known limitations:

            ## Failure Mode

            - What breaks:
            - Recovery path:

            ## Related

            {self._related_block(sibling_links)}
            """
        elif item["type"] == "log":
            body = f"""
            ## Signal

            Frame the repo-backed story in dated terms: what changed, what pressure created the need, and what made this worth documenting now instead of later.

            {repo_line}

            ## Intervention

            Explain the actual move: what you built, changed, or tested in the repo. Keep the technical explanation honest, but written as a field report rather than a dry changelog.

            ## Result

            Describe what held up in practice, what still felt rough, and what this repo now makes easier than it used to.

            ## Next Move

            Capture the next tightening pass, follow-up workflow page, or artifact extraction that should happen while the context is still warm.

            ## Sources

            {source_lines}

            ## Related

            {self._related_block(sibling_links)}
            """
        elif item["type"] == "reference":
            body = f"""
            ## Purpose

            This reference page should give fast re-entry into the repo without forcing a full reread of the README, article draft, or sibling pages.

            {repo_line}

            ## Index

            | Resource | Type | When to Use |
            | :-- | :-- | :-- |
            | Add key command or file | Workflow / Artifact | Add a fast retrieval cue |
            | Add high-signal page | Project / Log | Explain why it matters |

            ## Sources

            {source_lines}

            ## Related

            {self._related_block(sibling_links)}
            """
        elif item["type"] == "stack":
            body = f"""
            ## Bottleneck

            Identify the environment or setup friction that keeps readers from getting value from the repo quickly.

            {repo_line}

            ## Patch

            Explain the local configuration or integration layer that makes the repo reliable to run.

            ## Config / Script

            ```bash
            # Add the final configuration or commands here.
            ```

            ## Verification

            - Tested on:
            - Expected output:
            - Known failure mode:

            ## Rollback

            - Add the revert steps here.

            ## Related

            {self._related_block(sibling_links)}
            """
        else:
            body = f"""
            ## Prompt Contract

            ```markdown
            Role:

            Task:

            Inputs:
            - input

            Output Contract:
            - structured result
            ```

            {repo_line}

            ## Logic

            Explain why this prompt contract belongs in the Cyborg Lab set and how it supports the repo-backed workflow.

            ## Verification

            - Input sample:
            - Expected output shape:
            - Failure mode + fallback:

            ## Related

            {self._related_block(sibling_links)}
            """
        return textwrap.dedent(body).strip()

    def _related_block(self, sibling_links: list[tuple[str, str]]) -> str:
        """Format sibling links as a markdown bullet list for the
        '## Related' section at the bottom of each draft.
        """
        if not sibling_links:
            return "- Add sibling links after the first draft pass."
        return "\n".join(f"- [{title}]({path})" for title, path in sibling_links)

    # --- GitNexus commands ---

    def handle_gitnexus_command(self, args: list[str]) -> None:
        """Route /gitnexus subcommands: status, explain, skip,
        enhance, and refresh.
        """
        subcommand = args[0] if args else "status"
        repo_path = self._repo_path()
        if not repo_path:
            self.assistant_say("No repo is active in this session, so GitNexus is not relevant here.")
            return
        if subcommand == "status":
            self.refresh_gitnexus_status()
            self.assistant_say("\n".join(self._gitnexus_status_lines()))
            return
        if subcommand == "explain":
            self.refresh_gitnexus_status()
            self.assistant_say(self._gitnexus_explain_text())
            return
        if subcommand == "skip":
            self.state.gitnexus_skip = True
            self.save()
            self.assistant_say("GitNexus is skipped for this session. I’ll continue with native repo scanning.")
            if not self.state.scan_summary:
                self.scan_repo()
            return
        if subcommand in {"enhance", "refresh"}:
            status = self.refresh_gitnexus_status()
            if status.get("state") == "not-git":
                self.assistant_say("This source is not a git repo, so GitNexus enhancement does not apply.")
                return
            if not self.gitnexus_cli.available:
                self.assistant_say("GitNexus CLI is unavailable here. Use `/gitnexus skip` to continue natively or make the CLI available first.")
                return
            try:
                result = self.gitnexus_cli.enhance(repo_path, force=subcommand == "refresh" or bool(status.get("stale")))
            except RuntimeError as exc:
                self.assistant_say(
                    "\n".join(
                        [
                            "GitNexus enhancement failed.",
                            str(exc),
                            "Options:",
                            "A. Explain the GitNexus plan again.",
                            "B. Retry the enhancement flow.",
                            "C. Skip GitNexus and continue with native scanning.",
                            "D. Show the current GitNexus status again.",
                            "E. Custom command or note (`/quit` is also available).",
                        ]
                    )
                )
                return
            self.state.gitnexus_skip = False
            refreshed = self.refresh_gitnexus_status()
            self.save()
            self.assistant_say(
                "\n".join(
                    [
                        "GitNexus enhancement completed.",
                        f"- Repo: {refreshed.get('repo_name') or repo_path.name}",
                        f"- State: {refreshed.get('state')}",
                        f"- Embeddings preserved: {'yes' if result.get('preserved_embeddings') else 'no'}",
                        "I’ll use graph-enhanced scanning from here.",
                    ]
                )
            )
            self.scan_repo()
            return
        self.assistant_say("Usage: /gitnexus status|enhance|refresh|skip|explain")

    # --- Link and review commands ---

    def recommend_links(self) -> None:
        """Show existing-page link recommendations and rewrite candidates."""
        if self.state.link_recommendations or self.state.rewrite_recommendations:
            lines = ["Existing-page recommendations:"]
            for recommendation in self.state.link_recommendations:
                lines.append(
                    f"[{recommendation['id']}] {recommendation['path']} - {recommendation['reason']} ({recommendation['action']})"
                )
            lines.append("Use `/patch-links 1 2` to generate pending edits for selected recommendations.")
            if self.state.rewrite_recommendations:
                lines.extend(["", "Strong rewrite candidates:"])
                single_rewrite_choice = len(self._pending_rewrite_recommendations()) == 1
                for recommendation in self.state.rewrite_recommendations:
                    reply_hint = "A/B/C" if single_rewrite_choice else f"{recommendation['id']}A/{recommendation['id']}B/{recommendation['id']}C"
                    lines.append(
                        f"[{recommendation['id']}] {recommendation['path']} - choose `/rewrite {recommendation['id']} update|iteration-log|merge` or reply `{reply_hint}`"
                    )
            self.assistant_say("\n".join(lines))
            return
        self.assistant_say("No existing-page recommendations are available yet. Generate `/map` first.")

    def patch_links(self, ids: list[int]) -> None:
        """Generate pending edits for selected link recommendations.
        Reads the existing blog page and appends a Related section.
        """
        if not self.state.link_recommendations:
            self.assistant_say("No link recommendations are available yet. Run `/links` after `/map`.")
            return
        chosen = [rec for rec in self.state.link_recommendations if rec["id"] in ids]
        if not chosen:
            self.assistant_say("No matching recommendation IDs were found.")
            return

        for rec in chosen:
            target_path = self.blog_root / rec["path"]
            if not target_path.exists():
                self.assistant_say(f"Skipping `{rec['path']}` because the file does not exist.")
                continue
            original = target_path.read_text(encoding="utf-8")
            updated = self._patch_existing_page(original)
            self.state.pending_existing_edits[rec["path"]] = {
                "reason": rec["reason"],
                "markdown": updated,
            }

        self.save()
        self.assistant_say(
            "\n".join(
                [
                    f"Prepared pending edits for {len(chosen)} existing page(s).",
                    "Use `/apply links --yes` when you want to write them into the blog repo.",
                ]
            )
        )

    def _patch_existing_page(self, original: str) -> str:
        """Add sibling links to an existing page's Related section.
        Creates the section if it does not exist yet.
        """
        new_links = self._related_block(self._sibling_links(""))
        related_heading = "\n## Related\n"
        if related_heading in original:
            head, tail = original.split(related_heading, 1)
            updated_tail = tail.rstrip()
            addition = "\n" + new_links
            if addition.strip() not in updated_tail:
                updated_tail = updated_tail + "\n" + new_links + "\n"
            return head + related_heading + updated_tail.rstrip() + "\n"
        return original.rstrip() + f"\n\n## Related\n\n{new_links}\n"

    def set_review_target(self, key: str) -> None:
        """Set a pending draft as the active review target so the
        user's next free-text messages are treated as editorial notes.
        """
        if key not in self.state.pending_drafts:
            self.assistant_say(f"No pending draft exists for `{key}`.")
            return
        self.state.active_review_key = key
        self.state.phase = "review"
        self.save()
        preview = short_preview(self.state.pending_drafts[key]["markdown"], 220)
        self.assistant_say(
            "\n".join(
                [
                    f"Review target set to `{key}`.",
                    f"Preview: {preview}",
                    "Send editorial notes as plain text and I will revise the pending draft in place.",
                ]
            )
        )

    def show_draft(self, key: str) -> None:
        """Print the full markdown of a pending draft."""
        draft = self.state.pending_drafts.get(key)
        if not draft:
            self.assistant_say(f"No pending draft exists for `{key}`.")
            return
        self.assistant_say(draft["markdown"])

    def revise_active_draft(self, feedback: str) -> None:
        """Apply editorial feedback to the active review draft.
        If AI is on, it rewrites the draft automatically.
        If AI is off, it just saves the note for manual follow-up.
        """
        target_key = self.state.active_review_key
        if not target_key or target_key not in self.state.pending_drafts:
            self.assistant_say("No active review target is set. Use `/review <key>` first.")
            return

        expanded_feedback = contextualize_choice_reply(feedback, self.state.chat_history)
        self.state.editorial_notes.append(expanded_feedback)
        draft = self.state.pending_drafts[target_key]
        if self.ai_client.enabled:
            try:
                response = self.ai_client.chat_json(
                    self._build_system_prompt(),
                    textwrap.dedent(
                        f"""
                        Revise the current Cyborg Lab draft based on the user's editorial feedback.
                        Return JSON with:
                        {{
                          "markdown": "full revised markdown including frontmatter",
                          "summary": "short summary of what changed"
                        }}

                        Draft key: {target_key}
                        Current markdown:
                        {draft['markdown']}

                        Editorial feedback:
                        {expanded_feedback}
                        """
                    ).strip(),
                    temperature=0.3,
                    cache_system=True,
                )
                revised_markdown = str(response.get("markdown", "")).strip()
                if not revised_markdown:
                    raise RuntimeError("AI revision returned an empty draft.")
                draft["previous_markdown"] = draft.get("markdown", "")
                draft["markdown"] = revised_markdown
                summary = response.get("summary", "Revised the pending draft.")
            except RuntimeError as exc:
                summary = f"AI revision failed, so the draft was not auto-rewritten.\nReason: {exc}\nYour note was saved for manual follow-up."
        else:
            summary = "Saved the editorial note. AI is disabled, so no automatic rewrite was applied."

        self.state.pending_drafts[target_key] = draft
        self.save()
        self.assistant_say(summary)

    # --- Apply (write to disk) ---

    def _pending_apply_lines(self, target: str) -> list[str]:
        """Build a compact summary of what /apply would write."""
        lines = [f"Pending apply target: {target}"]
        if target in {"code", "all"}:
            repo_edit_paths = sorted(self.state.pending_repo_edits.keys())
            if repo_edit_paths:
                lines.append("Source-repo edits:")
                for path_value in repo_edit_paths[:6]:
                    lines.append(f"- {path_value}")
                if len(repo_edit_paths) > 6:
                    lines.append(f"- ...and {len(repo_edit_paths) - 6} more")
        if target in {"drafts", "docs", "all"}:
            draft_paths = sorted(draft["path"] for draft in self.state.pending_drafts.values())
            if draft_paths:
                lines.append("Draft files:")
                for path_value in draft_paths[:6]:
                    lines.append(f"- {path_value}")
                if len(draft_paths) > 6:
                    lines.append(f"- ...and {len(draft_paths) - 6} more")
        if target in {"links", "docs", "all"}:
            edit_paths = sorted(self.state.pending_existing_edits.keys())
            if edit_paths:
                lines.append("Existing-page edits:")
                for path_value in edit_paths[:6]:
                    lines.append(f"- {path_value}")
                if len(edit_paths) > 6:
                    lines.append(f"- ...and {len(edit_paths) - 6} more")
        return lines

    def _confirm_apply_interactively(self, target: str) -> bool:
        """Ask for an accessible A-E confirmation before /apply."""
        prompt = textwrap.dedent(
            f"""
            Apply pending changes for `{target}`?
            A. Apply now.
            B. Cancel.
            C. Show /status first.
            D. Show the pending file list first.
            E. Custom answer.
            Reply with A-E: """
        )
        while True:
            answer = prompt_input(prompt).strip().lower()
            if answer in {"a", "yes"}:
                return True
            if answer in {"", "b", "no", "n"}:
                self.assistant_say("Apply cancelled.")
                return False
            if answer == "c":
                self.assistant_say("\n".join(self.status_lines()))
                continue
            if answer == "d":
                self.assistant_say("\n".join(self._pending_apply_lines(target)))
                continue
            if answer == "e":
                self.assistant_say("Custom apply choice: run `/status`, `/show <key>`, or reply with `A` to apply and `B` to cancel.")
                continue
            self.assistant_say("Reply with A, B, C, D, or E.")

    def apply_changes(self, target: str, *, assume_yes: bool) -> None:
        """Write staged source-repo edits and/or blog edits to disk.
        Backs up any existing files first. Requires confirmation
        unless --yes was passed.
        """
        target = target.lower()
        if target == "all" and self.state.pending_repo_edits:
            self.assistant_say("Pending source-repo edits exist. Apply `code` or `docs` explicitly so you do not mix code and documentation writes accidentally.")
            return
        if target == "code" and not self.state.pending_repo_edits:
            self.assistant_say("There are no pending source-repo edits to apply.")
            return
        if target == "docs":
            target = "all"
        if target == "drafts" and not self.state.pending_drafts:
            self.assistant_say("There are no pending drafts to apply.")
            return
        if target == "links" and not self.state.pending_existing_edits:
            self.assistant_say("There are no pending existing-page edits to apply.")
            return
        if target == "all" and not self.state.pending_drafts and not self.state.pending_existing_edits:
            self.assistant_say("Nothing pending to apply.")
            return

        if not assume_yes and self.interactive:
            if not self._confirm_apply_interactively(target):
                return
        elif not assume_yes and not self.interactive:
            self.assistant_say("Non-interactive apply requires `--yes`.")
            return

        backup_root = self.session_dir / "backups"
        backup_root.mkdir(parents=True, exist_ok=True)

        if target == "code":
            repo_root = self._repo_path()
            if not repo_root:
                self.assistant_say("No source repo is active, so there is nowhere to apply code edits.")
                return
            repo_backup_root = backup_root / "source-repo"
            repo_backup_root.mkdir(parents=True, exist_ok=True)
            for rel_path, edit in self.state.pending_repo_edits.items():
                target_path = repo_root / rel_path
                self._safe_write_within_root(repo_root, target_path, edit["content"], repo_backup_root, label="source repo")
            self.state.pending_repo_edits = {}
            # Code changes invalidate the derived documentation state.
            self.state.scan_summary = ""
            self.state.scan_details = {}
            self.state.duplicate_candidates = []
            self.state.code_improvement_plan = {}
            self.state.content_map = {}
            self.state.publishing_plan = {}
            self.state.pending_drafts = {}
            self.state.link_recommendations = []
            self.state.rewrite_recommendations = []
            self.state.rewrite_choices = {}
            self.state.pending_existing_edits = {}
            self.state.phase = "intake"
            self.save()
            self.assistant_say("Applied the selected source-repo edits. Re-run `/scan`, then `/improve` or `/map`, because the repo state changed.")
            return

        if target in {"drafts", "all"}:
            for draft in self.state.pending_drafts.values():
                target_path = self.blog_root / draft["path"]
                self._safe_write(target_path, draft["markdown"], backup_root)

        if target in {"links", "all"}:
            for rel_path, edit in self.state.pending_existing_edits.items():
                target_path = self.blog_root / rel_path
                self._safe_write(target_path, edit["markdown"], backup_root)

        self.state.phase = "applied"
        self.save()
        self.assistant_say("Applied the selected pending changes into the Cyborg Lab repo.")

    def _safe_write(self, target_path: Path, content: str, backup_root: Path) -> None:
        """Write a file into the blog repo after checking it stays
        inside the blog root.  Backs up the old version if it exists.
        """
        self._safe_write_within_root(self.blog_root, target_path, content, backup_root, label="blog root")

    @staticmethod
    def _safe_write_within_root(root: Path, target_path: Path, content: str, backup_root: Path, *, label: str) -> None:
        """Write a file under an approved root and back up the prior version first."""
        resolved_target = resolve_within_root(root, target_path, label=label)
        resolved_root = root.resolve()
        if resolved_target.exists():
            backup_path = backup_root / resolved_target.relative_to(resolved_root)
            backup_path.parent.mkdir(parents=True, exist_ok=True)
            backup_path.write_text(resolved_target.read_text(encoding="utf-8"), encoding="utf-8")
        resolved_target.parent.mkdir(parents=True, exist_ok=True)
        resolved_target.write_text(content, encoding="utf-8")

    def _write_session_artifact(self, base_root: Path, relative_path: str, content: str, *, label: str) -> None:
        """Write a preview or edit file inside the session folder.
        Also checks that the path stays inside the allowed root.
        """
        preview_path = resolve_within_root(base_root, base_root / relative_path, label=label)
        preview_path.parent.mkdir(parents=True, exist_ok=True)
        preview_path.write_text(content, encoding="utf-8")

    # --- Free-text note handling ---

    def _handle_gitnexus_letter_choice(self, normalized: str) -> bool:
        """Accept short A-E answers when a GitNexus decision is pending."""
        if normalized in {"a"}:
            self.handle_gitnexus_command(["explain"])
            return True
        if normalized in {"b", "yes", "y", "proceed", "approve"}:
            self.handle_gitnexus_command(["enhance"])
            return True
        if normalized in {"c", "skip", "no", "n"}:
            self.handle_gitnexus_command(["skip"])
            return True
        if normalized in {"d", "status"}:
            self.handle_gitnexus_command(["status"])
            return True
        if normalized in {"e"}:
            self.assistant_say("Custom GitNexus choice: use `/gitnexus explain`, `/gitnexus enhance`, `/gitnexus skip`, `/gitnexus status`, or type the extra detail you want.")
            return True
        return False

    def _handle_rewrite_letter_choice(self, note: str) -> bool:
        """Accept ``A`` / ``1B`` style rewrite choices after /map."""
        pending = self._pending_rewrite_recommendations()
        if not pending:
            return False
        recommendation_id, letter = parse_compact_letter_choice(note)
        if not letter:
            return False
        if recommendation_id is None:
            if len(pending) != 1:
                return False
            recommendation_id = pending[0]["id"]
        recommendation = next((rec for rec in pending if rec["id"] == recommendation_id), None)
        if not recommendation:
            self.assistant_say("No pending rewrite recommendation exists for that ID.")
            return True
        if letter in {"A", "B", "C"}:
            self.choose_rewrite_mode(recommendation_id, letter)
            return True
        if letter == "D":
            if len(pending) == 1:
                self.assistant_say("Kept the rewrite choice pending. Reply with `A`, `B`, or `C` when you are ready.")
            else:
                self.assistant_say(
                    f"Kept rewrite recommendation [{recommendation_id}] pending. Reply with `{recommendation_id}A`, `{recommendation_id}B`, or `{recommendation_id}C` when you are ready."
                )
            return True
        if len(pending) == 1:
            self.assistant_say(
                f"Custom rewrite choice: use `/rewrite {recommendation_id} update|iteration-log|merge`, or add the detail you want in plain text."
            )
        else:
            self.assistant_say(
                f"Custom rewrite choice: use `/rewrite {recommendation_id} update|iteration-log|merge`, or add the detail you want in plain text."
            )
        return True

    def handle_note(self, note: str) -> None:
        """Process a line that is NOT a slash-command.

        If a GitNexus decision is pending and the user typed a short
        choice like A-E, yes, or skip, route it there.  If a review
        target is active, treat the text as editorial feedback.
        Otherwise save it as an intake or planning note and optionally
        ask the AI for guidance.
        """
        self.user_said(note)
        normalized = note.strip().lower()
        if self._gitnexus_decision_pending():
            if self._handle_gitnexus_letter_choice(normalized):
                return
        if self.state.active_review_key:
            self.revise_active_draft(note)
            return
        if self._handle_rewrite_letter_choice(note):
            return

        expanded_note = contextualize_choice_reply(note, self.state.chat_history)
        if self.state.phase in {"intake", "scanned"}:
            self.state.intake_notes.append(expanded_note)
        else:
            self.state.planning_notes.append(expanded_note)
        self.save()

        if self.ai_client.enabled and not self._gitnexus_decision_pending():
            try:
                response = self.ai_client.chat_text(
                    f"{self._build_system_prompt()}\n\n{INTAKE_GUIDANCE}",
                    textwrap.dedent(
                        f"""
                        Current phase: {self.state.phase}
                        Repo path: {self.state.repo_path}
                        Last user note: {expanded_note}
                        Recent chat context:
                        {recent_chat_excerpt(self.state.chat_history, limit=6)}
                        Intake notes: {json.dumps(self.state.intake_notes[-6:], indent=2)}
                        Planning notes: {json.dumps(self.state.planning_notes[-6:], indent=2)}
                        Content map summary: {short_preview(self.state.content_map.get('summary', ''), 320)}
                        Publishing plan summary: {short_preview(self.state.publishing_plan.get('summary', ''), 320)}

                        Respond like a focused collaborator in 2-4 short paragraphs or 3-5 flat bullets.
                        """
                    ).strip(),
                    temperature=0.35,
                    cache_system=True,
                )
                self.assistant_say(response)
                return
            except RuntimeError as exc:
                self.assistant_say(f"Saved the note. AI guidance is unavailable right now.\nReason: {exc}")
                return

        if self._gitnexus_decision_pending():
            self.assistant_say(f"Saved the note. {self._gitnexus_prompt_text()}")
            return

        if self.state.pending_repo_edits:
            next_step = "Use `/apply code --yes` to write the staged source-repo edits, or `/patch-code <id>` to replace them with a different improvement."
        elif self.state.code_improvement_plan.get("items") and self.state.phase in {"intake", "scanned"}:
            next_step = "Run `/patch-code` to stage the top source-repo improvement, or `/map` if you want to skip straight to documentation."
        else:
            next_step = {
                "intake": "Run `/scan` if you want repo-grounded context, then `/improve` or `/map` when the intake notes feel complete.",
                "scanned": "Run `/improve` for a code-first pass, or `/map` for the first content graph.",
                "mapped": "Run `/plan` when the content map looks right, or add planning notes if you want to reshape the publishing order.",
                "planned": "Run `/draft all` when you want near-publishable drafts held in preview.",
                "drafted": "Use `/review <key>` for editorial feedback, or `/links` to start the existing-page cross-link pass.",
                "review": "Keep sending editorial notes, or `/apply drafts --yes` when a draft is ready to write into the repo.",
                "applied": "The repo has been updated. Keep reviewing with `/review <key>` if you want another pass before publish.",
            }.get(self.state.phase, "Use `/status` if you want a quick state snapshot.")
        self.assistant_say(f"Saved the note. {next_step}")


# =====================================================================
# Session setup helpers (called before the REPL starts)
# =====================================================================


def resolve_blog_root(explicit: Optional[str], *, interactive: bool) -> Path:
    """Figure out where the Cyborg Lab Hugo blog lives on disk.

    Checks (in order): the --blog-root flag, CYBORG_LAB_DIR env var,
    known default paths, and finally asks the user interactively.
    """
    candidates: list[Path] = []
    if explicit:
        candidates.append(canonical_home_path(explicit))
    env_value = os.environ.get("CYBORG_LAB_DIR", "").strip()
    if env_value:
        candidates.append(canonical_home_path(env_value))
    for path in KNOWN_BLOG_PATHS:
        if path.exists():
            candidates.append(path.resolve())

    for candidate in candidates:
        if (candidate / "content").exists():
            return candidate

    if interactive:
        while True:
            answer = prompt_input("Path to my-ms-ai-blog: ").strip()
            if not answer:
                raise ValueError("Blog root selection cancelled.")
            candidate = canonical_home_path(answer)
            if (candidate / "content").exists():
                return candidate
            print(f"That path does not look like a Hugo content repo: {candidate}")

    raise ValueError("Unable to resolve Cyborg Lab root. Set CYBORG_LAB_DIR or pass --blog-root.")


def resolve_repo_path(explicit: Optional[str], cwd: Path) -> Optional[Path]:
    """Figure out which source repo the user wants to ingest.

    If --repo was passed, use that.  Otherwise look for a git root
    or project folder in the current directory.  Returns None when
    no project is detected (the user can still add notes manually).
    """
    if explicit:
        candidate = canonical_home_path(explicit)
        if not candidate.exists():
            raise ValueError(f"Repo path not found: {candidate}")
        if not candidate.is_dir():
            raise ValueError(f"Repo path is not a directory: {candidate}")
        git_root = detect_git_root(candidate)
        return git_root or candidate
    git_root = detect_git_root(cwd)
    if git_root:
        return git_root
    if looks_like_project_dir(cwd):
        return cwd
    return None


def read_file_text(file_path: Optional[str]) -> Tuple[Optional[str], str]:
    """Read a markdown file from disk.  Returns (path, contents).
    Raises a friendly ValueError if the file cannot be read.
    """
    if not file_path:
        return None, ""
    path = canonical_home_path(file_path)
    try:
        return str(path), path.read_text(encoding="utf-8")
    except OSError as exc:
        raise ValueError(f"Unable to read source file {path}: {exc.strerror or exc}") from exc


def read_stdin_text() -> str:
    """Read piped input from stdin.  Returns '' if nothing was piped."""
    if sys.stdin.isatty():
        return ""
    return sys.stdin.read()


def make_session_id(seed: str) -> str:
    """Create a unique session ID like '20260316-143000-my-repo-abc123'."""
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    return f"{timestamp}-{slugify(seed, max_words=4, max_len=24)}-{uuid.uuid4().hex[:6]}"


def create_session(
    *,
    blog_root: Path,
    cwd: Path,
    repo_path: Optional[Path],
    markdown_file: Optional[str],
    source_text: str,
    article_text: str,
) -> SessionState:
    """Build a fresh SessionState for a new ingest session."""
    seed = repo_path.name if repo_path else extract_first_heading(article_text or source_text) or "cyborg-session"
    session_id = make_session_id(seed)
    session_dir = blog_root / "drafts" / "ingest" / session_id
    repo_remote = ""
    if repo_path:
        repo_remote = run_command(["git", "remote", "get-url", "origin"], cwd=repo_path, allow_failure=True)
    return SessionState(
        session_id=session_id,
        version=SESSION_VERSION,
        created_at=utc_now(),
        updated_at=utc_now(),
        blog_root=str(blog_root),
        session_dir=str(session_dir),
        cwd=str(cwd),
        repo_path=str(repo_path) if repo_path else None,
        repo_name=repo_path.name if repo_path else None,
        repo_remote=repo_remote or None,
        markdown_file=markdown_file,
        source_text=source_text,
        article_text=article_text,
    )


def list_sessions(blog_root: Path) -> list[Path]:
    """Return saved session folders sorted newest-first."""
    session_root = blog_root / "drafts" / "ingest"
    if not session_root.exists():
        return []
    return sorted((path for path in session_root.iterdir() if path.is_dir()), key=lambda path: path.name, reverse=True)


def load_session(blog_root: Path, session_id: Optional[str], *, interactive: bool) -> SessionState:
    """Load a previously saved session from its JSON file.

    If session_id is given, load that one directly.  If interactive,
    show a list and let the user pick.  Otherwise load the newest.
    """
    sessions = list_sessions(blog_root)
    if not sessions:
        raise ValueError("No saved Cyborg sessions were found.")
    if session_id:
        session_dir = blog_root / "drafts" / "ingest" / session_id
    elif interactive:
        print("Saved sessions:")
        preview_sessions = sessions[:4]
        for index, preview_dir in enumerate(preview_sessions):
            print(f"  {chr(ord('A') + index)}. {preview_dir.name}")
        if len(sessions) > 4:
            print("  E. Another session number or exact session ID")
        else:
            print("  E. Enter an exact session ID")
        answer = prompt_input("Resume which session? ").strip()
        normalized = answer.lower()
        if normalized in {"a", "b", "c", "d"}:
            choice_index = ord(normalized) - ord("a")
            if choice_index >= len(preview_sessions):
                raise ValueError("That letter is not available for the current session list.")
            session_dir = preview_sessions[choice_index]
        elif normalized == "e":
            custom = prompt_input("Enter a session number or exact session ID: ").strip()
            if not custom:
                raise ValueError("Resume selection cancelled.")
            if custom.isdigit():
                choice = int(custom)
                if choice < 1 or choice > len(sessions):
                    raise ValueError(f"Resume choice must be between 1 and {len(sessions)}.")
                session_dir = sessions[choice - 1]
            else:
                session_dir = blog_root / "drafts" / "ingest" / custom
        elif answer.isdigit():
            choice = int(answer)
            if choice < 1 or choice > len(sessions):
                raise ValueError(f"Resume choice must be between 1 and {len(sessions)}.")
            session_dir = sessions[choice - 1]
        elif answer:
            session_dir = blog_root / "drafts" / "ingest" / answer
        else:
            raise ValueError("Resume selection cancelled.")
    else:
        session_dir = sessions[0]
    session_file = session_dir / "session.json"
    if not session_file.exists():
        raise ValueError(f"Session file not found: {session_file}")
    data = json.loads(session_file.read_text(encoding="utf-8"))
    return SessionState(**data)


def parse_command(raw: str) -> tuple[str, list[str]]:
    """Split '/map foo bar' into ('map', ['foo', 'bar'])."""
    text = raw[1:] if raw.startswith("/") else raw
    parts = shlex.split(text)
    if not parts:
        return "", []
    return parts[0], parts[1:]


# =====================================================================
# Project scaffolding (Morphling build step)
# =====================================================================
# This is convergence path 2: the Python-side Morphling build.
# Called when the user runs `cyborg auto --build "idea"`.
#
# Flow:
#   main() validates flags → build_project_from_idea() →
#     AI returns JSON scaffold → write files → git init + commit →
#     return project path → main() feeds it to run_autopilot()
#
# The resulting directory becomes the --repo for the Cyborg session,
# so the normal scan → map → plan → draft pipeline documents the
# freshly-built project as if it were any other repo.
# =====================================================================


def build_project_from_idea(
    idea: str,
    ai_client: OpenRouterClient,
    *,
    projects_dir: Optional[Path] = None,
) -> Path:
    """Use the Morphling persona to scaffold a new project from an idea.

    Calls the AI with ``MORPHLING_BUILD_PROMPT`` to generate a project
    structure as JSON, writes the files into ``~/Projects/<name>/``,
    initialises a git repo, and returns the project path.

    Args:
        idea:         Plain-text project description from the user.
        ai_client:    Configured OpenRouter client (must be enabled).
        projects_dir: Override for the parent directory.  Defaults to
                      ``DEFAULT_PROJECTS_DIR`` (~/Projects).

    Returns:
        Path to the newly-created and git-committed project directory.

    Raises:
        RuntimeError: If the AI returns an empty scaffold or the API
                      call itself fails (handled by ``_request``).
    """
    # Resolve the target parent directory, creating it if needed.
    target_root = projects_dir or DEFAULT_PROJECTS_DIR
    target_root.mkdir(parents=True, exist_ok=True)

    print("Morphling is building your project...")

    # Temperature 0.5 gives the model room to make creative tech-stack
    # choices while still producing coherent, structured JSON output.
    scaffold = ai_client.chat_json(
        MORPHLING_BUILD_PROMPT,
        f"Build a project from this idea:\n\n{idea}",
        temperature=0.5,
    )

    # Extract the three required fields from the AI's JSON response.
    # "name" is slugified to produce a safe directory name; "files" is
    # the dict of { relative_path: file_contents } that we write to disk.
    name = slugify(scaffold.get("name") or "untitled-project", max_words=6, max_len=40)
    description = scaffold.get("description", idea)
    files: dict[str, str] = scaffold.get("files", {})

    if not files:
        raise RuntimeError("Morphling returned an empty project scaffold (no files).")

    # Pick the project directory.  If a directory with this name already
    # exists (e.g. from a previous build), append a random suffix so we
    # never clobber the user's existing work.
    project_dir = target_root / name
    if project_dir.exists():
        suffix = uuid.uuid4().hex[:6]
        project_dir = target_root / f"{name}-{suffix}"

    print(f"  Project: {project_dir}")
    print(f"  Description: {description}")
    print(f"  Files: {len(files)}")

    # --- Write scaffold files with path-safety validation ---
    # The AI controls the file paths in the "files" dict, so we must
    # guard against path traversal.  Two checks:
    #   1. Reject obviously bad patterns (absolute paths, ".." segments).
    #   2. Resolve the final path and confirm it's still under project_dir.
    # Skipped files are logged as a warning rather than silently dropped.
    skipped: list[str] = []
    for rel_path, contents in files.items():
        if rel_path.startswith("/") or ".." in rel_path.split("/"):
            skipped.append(rel_path)
            continue
        file_path = (project_dir / rel_path).resolve()
        if project_dir.resolve() not in file_path.parents and file_path != project_dir.resolve():
            skipped.append(rel_path)
            continue
        file_path.parent.mkdir(parents=True, exist_ok=True)
        file_path.write_text(contents, encoding="utf-8")

    if skipped:
        print(f"  Warning: skipped {len(skipped)} file(s) with unsafe paths: {', '.join(skipped)}")

    # --- Git init ---
    # Cyborg's scan_repo() expects a git repo to extract commit history,
    # file lists, and diff context.  We create a minimal repo with a
    # single commit attributed to "Morphling" so it's clearly machine-
    # generated.  allow_failure=True on each step so a git problem
    # doesn't block the entire autopilot pipeline — Cyborg can still
    # scan a non-git directory, just with less context.
    run_command(["git", "init", "-q"], cwd=project_dir, allow_failure=True)
    run_command(["git", "add", "."], cwd=project_dir, allow_failure=True)
    run_command(
        ["git", "-c", "user.name=Morphling", "-c", "user.email=morphling@cyborg-lab",
         "commit", "-qm", f"Initial scaffold: {description}"],
        cwd=project_dir,
        allow_failure=True,
    )

    print("  Project scaffolded and committed.")
    print()
    return project_dir


# =====================================================================
# Interactive command loop (REPL)
# =====================================================================


def run_autopilot(agent: CyborgAgent, *, assume_yes: bool = False, docs_after_code: bool = False) -> int:
    """Run the full Cyborg pipeline hands-free.

    Default behavior is code-first: scan → improve → patch-code, then
    stop so source-repo changes can be reviewed or applied before any
    documentation pass. When ``docs_after_code`` is True, the normal
    docs pipeline continues after the code phase.
    """
    docs_after_code = docs_after_code or os.environ.get("CYBORG_DOCS_AFTER_CODE", "").lower() in {"1", "true", "yes"}
    print(f"Cyborg autopilot session: {agent.state.session_id}")
    print(f"Repo: {agent.state.repo_path or '(none)'}")
    print(f"Blog root: {agent.state.blog_root}")
    print()

    # --- Morphling pre-analysis injection (convergence path 1) ---
    # The shell launcher (bin/cyborg) runs morphling.sh *before* exec'ing
    # the Python agent and exports the result as CYBORG_MORPHLING_BRIEF.
    # Here we pull that brief into the session's article_text, which is
    # included in every AI prompt as source context.  This means the
    # Morphling domain-expert analysis enriches Cyborg's content map,
    # publishing plan, and drafts — all without the user doing anything.
    #
    # This env var is only set when:
    #   - The subcommand is "auto" (not "ingest" or "resume")
    #   - --no-morphling was NOT passed
    #   - --build was NOT passed (build mode uses path 2 instead)
    #   - uv and ai-staff-hq/ are available on the system
    morphling_brief = os.environ.get("CYBORG_MORPHLING_BRIEF", "").strip()
    if morphling_brief:
        agent.assistant_say("Morphling pre-analysis loaded. This enriches the documentation pass; it does not modify repo code.")
        # Append to existing article text (which may contain --file or
        # --stdin-source material) rather than replacing it.
        if agent.state.article_text:
            agent.state.article_text += "\n\n--- MORPHLING ANALYSIS ---\n" + morphling_brief
        else:
            agent.state.article_text = "--- MORPHLING ANALYSIS ---\n" + morphling_brief
        agent.save()

    # Each phase is wrapped so a mid-pipeline failure saves the session
    # and tells the user how to resume instead of losing all work.
    def _phase(label: str, fn: Any) -> bool:
        """Run *fn*; on failure save and print recovery info.  Returns True on success."""
        try:
            fn()
            agent.save()
            return True
        except Exception as exc:
            agent.assistant_say(f"Autopilot error during {label}: {exc}")
            agent.save()
            print(f"\nSession saved. Resume with: cyborg resume {agent.state.session_id}", file=sys.stderr)
            return False

    # --- Phase 1: Repo context ---
    def _phase_repo_context() -> None:
        agent.auto_prepare_repo_context()

        # In autopilot, auto-resolve GitNexus decisions instead of waiting.
        if agent._gitnexus_decision_pending():
            status = agent._gitnexus_status()
            gn_state = status.get("state")
            if gn_state in {"not-indexed", "stale"} and agent.gitnexus_cli.available:
                tracked = int(status.get("tracked_bytes", 0))
                if tracked <= GITNEXUS_SIZE_THRESHOLD_BYTES:
                    agent.assistant_say("Autopilot: auto-enhancing GitNexus (repo is small enough).")
                    agent.handle_gitnexus_command(["enhance"])
                else:
                    agent.assistant_say("Autopilot: skipping GitNexus (repo is large).")
                    agent.handle_gitnexus_command(["skip"])
            else:
                agent.assistant_say("Autopilot: skipping GitNexus.")
                agent.handle_gitnexus_command(["skip"])

        # If GitNexus is still pending after our best attempt (e.g. the
        # enhance succeeded but the status flipped to "stale" immediately),
        # force-skip so downstream phases don't keep bailing out.
        if agent._gitnexus_decision_pending():
            agent.assistant_say("Autopilot: forcing GitNexus skip to avoid stale loop.")
            agent.state.gitnexus_skip = True
            agent.save()

        # auto_prepare_repo_context returns early when a GitNexus
        # decision was pending, so the scan may not have happened yet.
        if not agent.state.scan_summary and agent.state.repo_path:
            agent.scan_repo()

    if not _phase("repo context", _phase_repo_context):
        return 1

    # --- Phase 2: Code-first repo improvements ---
    def _phase_code_improvements() -> None:
        if not agent.state.repo_path:
            return
        agent.assistant_say("Autopilot: planning source-repo improvements...")
        agent.build_code_improvement_plan()
        if agent.state.code_improvement_plan.get("items"):
            agent.assistant_say("Autopilot: staging the top source-repo improvement...")
            agent.stage_code_improvement()
            if os.environ.get("CYBORG_AUTO_APPLY_CODE", "").lower() in {"1", "true", "yes"} and agent.state.pending_repo_edits:
                agent.assistant_say("Autopilot: applying staged source-repo edits before documentation...")
                agent.apply_changes("code", assume_yes=True)
                if agent.state.repo_path:
                    agent.state.gitnexus_skip = True
                    agent.assistant_say("Autopilot: rescanning repo after code changes (native scan until the next GitNexus refresh)...")
                    agent.scan_repo()

    if not _phase("code improvements", _phase_code_improvements):
        return 1

    code_edit_count = len(agent.state.pending_repo_edits)
    if code_edit_count and not docs_after_code:
        print()
        print("=" * 60)
        print("  CODE-FIRST STAGE COMPLETE")
        print("=" * 60)
        print()
        for line in agent.status_lines():
            print(f"  {line}")
        print()

        if assume_yes:
            agent.apply_changes("code", assume_yes=True)
            agent.assistant_say("Source-repo edits applied. Re-run `cyborg auto --docs-after-code ...` after the new scan if you want documentation.")
            return 0

        if not agent.interactive:
            agent.assistant_say(
                "Code-first stage complete. Review the staged source-repo edits, or resume later with "
                f"`cyborg resume {agent.state.session_id}`. Use `/apply code --yes` when you want to write them."
            )
            return 0

        print(f"  {code_edit_count} source-repo edit(s) ready.")
        print()
        print("  A. Apply source-repo edits only")
        print("  B. Save for later (don't apply yet)")
        print("  C. Show /status first")
        print("  D. Drop into interactive mode to review first")
        print("  E. Continue into documentation anyway")
        print()
        choice = prompt_input("  Choice [A-E]: ").strip().lower()

        if choice in {"a", "yes", "y"}:
            agent.apply_changes("code", assume_yes=True)
        elif choice == "c":
            agent.assistant_say("\n".join(agent.status_lines()))
            agent.assistant_say(f"Session saved. Resume with: cyborg resume {agent.state.session_id}")
        elif choice == "d":
            agent.assistant_say("Switching to interactive mode. Type /help for commands.")
            return run_repl(agent)
        elif choice == "e":
            agent.assistant_say("Continuing into documentation after the code-first stage.")
        else:
            agent.assistant_say(f"Session saved. Resume with: cyborg resume {agent.state.session_id}")
            return 0

    # --- Phase 3: Content map ---
    def _phase_map() -> None:
        agent.assistant_say("Autopilot: building content map...")
        agent.build_content_map()
        pending_rewrites = agent._pending_rewrite_recommendations()
        if pending_rewrites:
            agent.assistant_say("Autopilot: auto-selecting 'update' for rewrite candidates.")
            for rec in pending_rewrites:
                agent.choose_rewrite_mode(rec["id"], "update")

    if not _phase("content map", _phase_map):
        return 1

    # --- Phase 4: Publishing plan ---
    def _phase_plan() -> None:
        agent.assistant_say("Autopilot: building publishing plan...")
        agent.build_publishing_plan()

    if not _phase("publishing plan", _phase_plan):
        return 1

    # --- Phase 5: Draft all pages ---
    def _phase_drafts() -> None:
        agent.assistant_say("Autopilot: drafting all pages...")
        agent.build_drafts(["all"])

    if not _phase("drafting", _phase_drafts):
        return 1

    # --- Phase 6: Link recommendations ---
    def _phase_links() -> None:
        if agent.state.link_recommendations:
            agent.assistant_say("Autopilot: patching all link recommendations...")
            all_ids = [rec["id"] for rec in agent.state.link_recommendations]
            agent.patch_links(all_ids)

    if not _phase("link patches", _phase_links):
        return 1

    # --- Final: Summary + single confirmation ---
    print()
    print("=" * 60)
    print("  AUTOPILOT COMPLETE")
    print("=" * 60)
    print()
    for line in agent.status_lines():
        print(f"  {line}")
    print()

    code_edit_count = len(agent.state.pending_repo_edits)
    draft_count = len(agent.state.pending_drafts)
    edit_count = len(agent.state.pending_existing_edits)
    if code_edit_count == 0 and draft_count == 0 and edit_count == 0:
        agent.assistant_say("Nothing to apply. Session saved.")
        return 0

    if assume_yes:
        if code_edit_count:
            agent.apply_changes("code", assume_yes=True)
            agent.assistant_say("Source-repo edits applied. Re-run the docs pass after the new scan if you want fresh documentation.")
        else:
            agent.apply_changes("all", assume_yes=True)
            agent.assistant_say("All changes applied.")
        return 0

    if not agent.interactive:
        agent.assistant_say(f"Non-interactive mode. Resume with: cyborg resume {agent.state.session_id}")
        return 0

    if code_edit_count:
        print(f"  {code_edit_count} source-repo edit(s), {draft_count} draft(s), and {edit_count} existing-page edit(s) ready.")
        print()
        print("  A. Apply source-repo edits only")
        print("  B. Apply documentation edits only")
        print("  C. Save for later (don't apply yet)")
        print("  D. Show /status first")
        print("  E. Drop into interactive mode to review first")
        print()
        choice = prompt_input("  Choice [A-E]: ").strip().lower()

        if choice in {"a", "yes", "y"}:
            agent.apply_changes("code", assume_yes=True)
        elif choice == "b":
            agent.apply_changes("docs", assume_yes=True)
        elif choice == "d":
            agent.assistant_say("\n".join(agent.status_lines()))
            agent.assistant_say(f"Session saved. Resume with: cyborg resume {agent.state.session_id}")
        elif choice == "e":
            agent.assistant_say("Switching to interactive mode. Type /help for commands.")
            return run_repl(agent)
        else:
            agent.assistant_say(f"Session saved. Resume with: cyborg resume {agent.state.session_id}")
    else:
        print(f"  {draft_count} draft(s) and {edit_count} existing-page edit(s) ready.")
        print()
        print("  A. Apply everything to the blog repo")
        print("  B. Apply drafts only")
        print("  C. Apply link edits only")
        print("  D. Save for later (don't apply yet)")
        print("  E. Drop into interactive mode to review first")
        print()
        choice = prompt_input("  Choice [A-E]: ").strip().lower()

        if choice in {"a", "yes", "y"}:
            agent.apply_changes("all", assume_yes=True)
        elif choice == "b":
            agent.apply_changes("drafts", assume_yes=True)
        elif choice == "c":
            agent.apply_changes("links", assume_yes=True)
        elif choice == "e":
            agent.assistant_say("Switching to interactive mode. Type /help for commands.")
            return run_repl(agent)
        else:
            agent.assistant_say(f"Session saved. Resume with: cyborg resume {agent.state.session_id}")

    return 0


def run_repl(agent: CyborgAgent) -> int:
    """Run the interactive read-eval-print loop.

    Shows the welcome message, auto-scans the repo if needed, then
    loops forever reading user input.  Lines starting with '/' are
    commands; everything else is treated as a free-text note.
    Returns 0 on clean exit.
    """
    intro_lines = [
        f"Cyborg session: {agent.state.session_id}",
        f"Repo: {agent.state.repo_path or '(none)'}",
        f"Blog root: {agent.state.blog_root}",
        "",
        HELP_TEXT,
    ]
    intro = "\n".join(intro_lines)
    print(intro)
    agent.append_chat("assistant", intro)

    agent.auto_prepare_repo_context()

    while True:
        prompt = "cyborg> " if sys.stdin.isatty() else ""
        line = prompt_input(prompt)
        line = line.strip()
        if not line:
            if not sys.stdin.isatty():
                return 0
            continue

        if line.startswith("/") or line in {"help", "status", "gitnexus", "scan", "improve", "patch-code", "map", "plan", "draft", "links", "review", "rewrite", "show", "apply", "quit", "exit"}:
            command, args = parse_command(line)
            if command in {"quit", "exit"}:
                agent.assistant_say("Session saved. Use `cyborg resume %s` to reopen it later." % agent.state.session_id)
                return 0
            if command == "help":
                agent.assistant_say(HELP_TEXT)
            elif command == "status":
                agent.assistant_say("\n".join(agent.status_lines()))
            elif command == "gitnexus":
                agent.handle_gitnexus_command(args)
            elif command == "scan":
                agent.scan_repo()
            elif command == "improve":
                agent.build_code_improvement_plan()
            elif command == "patch-code":
                improvement_id = None
                if args:
                    if not args[0].isdigit():
                        agent.assistant_say("Usage: /patch-code [improvement-id]")
                        continue
                    improvement_id = int(args[0])
                agent.stage_code_improvement(improvement_id)
            elif command == "map":
                agent.build_content_map()
            elif command == "plan":
                agent.build_publishing_plan()
            elif command == "draft":
                agent.build_drafts(args or ["all"])
            elif command == "links":
                agent.recommend_links()
            elif command == "patch-links":
                try:
                    ids = [int(value) for value in args]
                except ValueError:
                    agent.assistant_say("`/patch-links` expects numeric recommendation IDs.")
                    continue
                agent.patch_links(ids)
            elif command == "rewrite":
                if len(args) != 2 or not args[0].isdigit():
                    agent.assistant_say("Usage: /rewrite <id> update|iteration-log|merge")
                else:
                    agent.choose_rewrite_mode(int(args[0]), args[1])
            elif command == "review":
                if not args:
                    agent.assistant_say("Usage: /review <draft-key>")
                else:
                    agent.set_review_target(args[0])
            elif command == "show":
                if not args:
                    agent.assistant_say("Usage: /show <draft-key>")
                else:
                    agent.show_draft(args[0])
            elif command == "apply":
                assume_yes = "--yes" in args
                target_args = [arg for arg in args if arg != "--yes"]
                target = target_args[0] if target_args else "all"
                agent.apply_changes(target, assume_yes=assume_yes)
            else:
                agent.assistant_say(f"Unknown command: {command}")
            continue

        agent.handle_note(line)


# =====================================================================
# CLI argument parsing and entry point
# =====================================================================


def build_parser() -> argparse.ArgumentParser:
    """Set up the argument parser with 'ingest' and 'resume' subcommands."""
    parser = argparse.ArgumentParser(description="Cyborg Lab ingest agent")
    subparsers = parser.add_subparsers(dest="command", required=True)

    ingest = subparsers.add_parser("ingest", help="Start a new Cyborg ingest session")
    ingest.add_argument("--repo", help="Repo or directory to scan")
    ingest.add_argument("--file", help="Markdown file to use as supporting material")
    ingest.add_argument("--blog-root", help="Path to my-ms-ai-blog")
    ingest.add_argument("--stdin-source", action="store_true", help="Treat stdin as supporting source material before starting the session")
    ingest.add_argument("idea", nargs="*", help="Plain-text idea or focus notes")

    auto = subparsers.add_parser("auto", help="Run the code-first autopilot (scan, improve, patch-code, then optionally docs)")
    auto.add_argument("--repo", help="Repo or directory to scan")
    auto.add_argument("--file", help="Markdown file to use as supporting material")
    auto.add_argument("--blog-root", help="Path to my-ms-ai-blog")
    auto.add_argument("--stdin-source", action="store_true", help="Treat stdin as supporting source material")
    auto.add_argument("--yes", action="store_true", help="Apply changes without final confirmation")
    auto.add_argument("--docs-after-code", action="store_true", help="Continue into the documentation pipeline after the code-first stage")
    auto.add_argument("--no-morphling", action="store_true", help="Skip Morphling pre-analysis even if available")
    auto.add_argument("--build", action="store_true", help="Morphling builds the project from your idea first, then Cyborg runs the code-first pass")
    auto.add_argument("--projects-dir", help="Where to create the project (default: ~/Projects)")
    auto.add_argument("idea", nargs="*", help="Plain-text idea or focus notes")

    resume = subparsers.add_parser("resume", help="Resume a saved Cyborg ingest session")
    resume.add_argument("session_id", nargs="?", help="Saved session ID")
    resume.add_argument("--blog-root", help="Path to my-ms-ai-blog")

    return parser


def main(argv: Optional[List[str]] = None) -> int:
    """Entry point.  Parses arguments, loads config, and starts either
    a new ingest session or resumes an existing one.
    """
    # Use the provided argv, or fall back to the real command line.
    argv = argv if argv is not None else sys.argv[1:]
    parser = build_parser()
    try:
        args = parser.parse_args(argv)
        # Find the dotfiles root so we can load .env.
        dotfiles_dir = canonical_home_path(os.environ.get("DOTFILES_DIR", str(Path(__file__).resolve().parents[1])))
        load_env_file(dotfiles_dir)
        # Are we talking to a real human at a terminal?
        interactive = sys.stdin.isatty() and sys.stdout.isatty()
        # The shell launcher exports USER_CWD so we know where the
        # user was standing when they ran the command.
        cwd = canonical_home_path(os.environ.get("USER_CWD", os.getcwd()))
    except ValueError:
        cwd = Path.home().resolve()
    try:
        blog_root = resolve_blog_root(getattr(args, "blog_root", None), interactive=interactive)
        ai_client = OpenRouterClient()

        if args.command in {"ingest", "auto"}:
            # Starting a brand-new session (interactive or autopilot).
            source_text = " ".join(args.idea).strip()

            # --- Morphling build step (convergence path 2) ---
            # When --build is used, Morphling scaffolds a new project
            # *before* the Cyborg session is created.  The resulting
            # directory is then injected as args.repo so the downstream
            # session-creation and autopilot code treats it like any
            # existing repo the user pointed us at.
            #
            # Preconditions enforced here:
            #   - An idea string or --repo must be provided (so the AI
            #     knows what to build).
            #   - AI mode must be enabled (OPENROUTER_API_KEY set),
            #     because the build step calls OpenRouter directly.
            #
            # After build_project_from_idea() returns, args.repo is
            # overwritten with the scaffold path.  The shell launcher
            # already skipped Morphling pre-analysis for --build (the
            # two paths are mutually exclusive), so CYBORG_MORPHLING_BRIEF
            # will be empty and the injection block in run_autopilot()
            # is a no-op.
            if args.command == "auto" and getattr(args, "build", False):
                if not source_text and not args.repo:
                    raise ValueError("--build requires an idea (positional text) or --repo.")
                if not ai_client.enabled:
                    raise ValueError("--build requires AI mode (set OPENROUTER_API_KEY).")
                projects_dir = Path(args.projects_dir) if getattr(args, "projects_dir", None) else None
                built_path = build_project_from_idea(
                    source_text or "project from repo context",
                    ai_client,
                    projects_dir=projects_dir,
                )
                # Overwrite the repo arg so the session targets the
                # freshly scaffolded directory instead of cwd.
                args.repo = str(built_path)

            repo_path = resolve_repo_path(args.repo, cwd)
            markdown_file, article_text = read_file_text(args.file)
            stdin_text = read_stdin_text() if args.stdin_source else ""
            if stdin_text:
                article_text = "\n\n".join(part for part in [article_text, stdin_text] if part.strip())
            state = create_session(
                blog_root=blog_root,
                cwd=cwd,
                repo_path=repo_path,
                markdown_file=markdown_file,
                source_text=source_text,
                article_text=article_text,
            )
            agent = CyborgAgent(state, ai_client=ai_client, interactive=interactive)
            agent.save()
            if args.command == "auto":
                return run_autopilot(
                    agent,
                    assume_yes=getattr(args, "yes", False),
                    docs_after_code=getattr(args, "docs_after_code", False),
                )
            return run_repl(agent)

        # Resuming a previously saved session.
        state = load_session(blog_root, args.session_id, interactive=interactive)
        agent = CyborgAgent(state, ai_client=ai_client, interactive=interactive)
        return run_repl(agent)
    except (ValueError, RuntimeError) as exc:
        # Show a friendly error instead of a Python traceback.
        print(f"Error: {exc}", file=sys.stderr)
        return 2


# When this file is run directly: python3 cyborg_agent.py ...
if __name__ == "__main__":
    raise SystemExit(main())
