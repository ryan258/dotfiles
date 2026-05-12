#!/usr/bin/env python3
"""Obsidian observer for command, memory, open-loop, and exploration capture."""

from __future__ import annotations

import argparse
import functools
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path


DENYLIST = {
    "awk",
    "cat",
    "cd",
    "clear",
    "exit",
    "grep",
    "history",
    "ls",
    "open",
    "pbcopy",
    "pwd",
    "rg",
    "sed",
}
SENSITIVE_RE = re.compile(
    r"(?i)(api[_-]?key|authorization:|bearer\s+|password|passwd|secret|token|pwd=)"
)
ASSIGNMENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.*$")
COMMAND_LINK_RE = re.compile(r"\[\[wiki/commands/([^|\]]+)(?:\|[^\]]+)?\]\]")
OBSIDIAN_LINK_RE = re.compile(r"\[\[([^\]|#]+)(?:#[^\]|]+)?(?:\|[^\]]+)?\]\]")
OBSERVER_BLOCK_RE_TEMPLATE = (
    r"(?ms)^<!-- {owner}:start {name} -->\n?.*?^<!-- {owner}:end {name} -->"
)
USER_LOOP_RE = re.compile(r"(?mi)^\s*-\s*\[loop\]\s+(.+?)\s*$")
USER_EXPLORE_RE = re.compile(r"(?mi)^\s*-\s*\[explore\]\s+(.+?)\s*$")
REPO_MARKER_RE = re.compile(r"(?m)^-\s+Repo:\s+`([^`]+)`\s*$")
INLINE_CONCEPT_TAG_RE = re.compile(r"(?<![\w/-])#concept/([A-Za-z0-9][A-Za-z0-9_-]*)")
PROMOTE_SOURCE_RE = re.compile(r"(?<![\w/-])#promote/source\b")
TODO_RE = re.compile(r"\b(?:TODO|FIXME)\b", re.IGNORECASE)
TODO_COMMENT_RE = re.compile(r"(#|//|/\*|<!--|--)\s*(TODO|FIXME)\b", re.IGNORECASE)
PATH_EXTENSIONS = (
    ".bats",
    ".cjs",
    ".go",
    ".js",
    ".jsx",
    ".mjs",
    ".php",
    ".pl",
    ".py",
    ".rb",
    ".rs",
    ".sh",
    ".ts",
    ".tsx",
)
GENERIC_INTERPRETERS = {
    "bash",
    "node",
    "npm",
    "npx",
    "pnpm",
    "python",
    "python3",
    "sh",
    "uv",
    "yarn",
    "zsh",
}
# Single-token interpreters and multi-token launcher chains are split on purpose:
# `uv` alone needs script-path context, while `uv run pytest` is already specific.
INTERPRETER_CHAINS = {
    "bash",
    "node",
    "npm-run",
    "npx",
    "pnpm-run",
    "python",
    "python3",
    "sh",
    "uv-run",
    "yarn-run",
    "zsh",
}


DAILY_TEMPLATE = """---
type: daily
date: {day}
status: active
---

# {day}

## Focus
<!-- user:start focus -->
<!-- user:end focus -->

## Commands
<!-- observer:start commands -->
<!-- observer:end commands -->

## Significant Events
<!-- observer:start significant-events -->
<!-- observer:end significant-events -->

## Repo Activity
<!-- observer:start repos -->
<!-- observer:end repos -->

## Open Loops
<!-- observer:start open-loops -->
<!-- observer:end open-loops -->

## Explorations
<!-- observer:start explorations -->
<!-- observer:end explorations -->

## Promotion Candidates
<!-- observer:start promotion-candidates -->
<!-- observer:end promotion-candidates -->

## Memory
<!-- codex:start memory -->
<!-- codex:end memory -->

## Notes
<!-- user:start notes -->
<!-- user:end notes -->
"""

AGENTS_TEMPLATE = """# Vault Operating Contract

## Ownership

Observer owns raw/events, raw/observer-digests, and observer fenced blocks in daily notes.
Codex owns inbox drafts and wiki promotion edits when explicitly asked.
User owns maps and user fenced blocks.

## Promotion Rule

Only Command notes are promoted in V0.
A command becomes a candidate after appearing as a command link in 3 distinct daily notes within 14 days, appearing as a burst candidate, or when explicitly requested by the user.
Only links inside daily observer Commands blocks count for recurring-use promotion.

## Denylist

Never promote: cd, ls, pwd, clear, cat, sed, awk, grep, rg, open, pbcopy, history, exit.
Never capture or promote secrets, tokens, .env values, ssh keys, passwords, or private credentials.

## Daily Notes

startday creates daily notes.
Observer fills only observer fenced blocks.
Codex must not rewrite observer blocks unless explicitly asked.

## Command Notes

Command notes live in wiki/commands.
Keep them short: what it does, why it matters, source path, usage, related commands.

## Memory Notes

Raw memory captures live in raw/memory.
Durable memory notes live in wiki/memory.
Memory notes preserve Ryan's understanding, decisions, and explanations.

Codex may create or update memory notes only after explicit user signal or memory review request.
Codex owns codex fenced blocks in memory notes.
User owns user fenced blocks.
Codex must not rewrite user-owned prose.

Users can mark memory candidates in daily Notes with `- [memory] ...`.
Memory notes are not the source of truth for open-loop state, project status, or external citations.

## Open Loops

Open-loop raw state lives in raw/open-loops and is canonical.
Open-loop wiki notes live in wiki/open-loops and are Codex-synced views.

Observer may create candidates and resolution evidence in raw state and daily observer blocks.
Codex creates, updates, resolves, and archives wiki/open-loops notes only after user approval.

Deduplication uses loop_key.
Filenames use filename_key.

Statuses are candidate, accepted, surfaced, resolved, archived.
Surfaced means the user has seen the loop at least once; surfaced loops can still appear in startday.

Resolved loops archive after 14 days.
Archiving sets `status: archived` in place in V1; files are not moved automatically.
Stale loops are accepted or surfaced loops whose updated date is older than 7 days.

## Explorations

Exploration raw state lives in raw/explorations and is canonical.
Explorations are temporary side quests, not durable wiki nodes in V1.
Users can create exploration candidates with `- [explore] ...`.
Observer may propose an exploration when a session has 5 or more meaningful commands outside the current daily focus text.
If no current daily focus text exists, observer must not use the off-focus heuristic.
Explorations have a default 24-hour TTL.
Codex reviews expired explorations and can archive, extend, convert to open loop, or keep as raw material for V2 review.

## Projects And Workflows

Daily repo activity is written only inside the observer repos block as `- Repo: <absolute-repo-path>`.
Project notes live in wiki/projects and are created only after user approval.
Workflow notes live in wiki/workflows and represent exact repeated command-session sequences only.
Concept notes live in wiki/concepts and are user-explicit only.
Observer may update observer fenced blocks and map indexes for Projects and Workflows.
Project archiving sets `status: archived` in place; files are not deleted automatically.

## Web Clips

Web Clipper writes only to raw/web-clips.
Web Clipper must not write directly to wiki.
Raw web clip filenames must include date, domain, and title.

## Sources

Source notes live in wiki/sources.
Codex promotes selected raw clips into Source notes only after user approval.
Source notes must preserve source_url and source_clip.
Source notes summarize; they do not copy entire articles.

## Source Candidates

Raw clips become candidates by #promote/source, explicit review request, or incoming links from daily/project/workflow/concept notes.
Raw clips older than 30 days with no promote tag and no incoming links are stale.
Stale clips are reviewed before archive.

## Concepts And Sources

Concept creation from source tags requires the same literal #concept/<slug> tag in 3 or more notes, no existing Concept note, and user approval.
Concept tag detection counts YAML tags arrays and inline body tags.
Codex must not rewrite user-owned Concept prose.
Existing Concept updates may only touch the codex-owned sourced-claims block.

## Markers And Tags

| Marker | Meaning | Owner |
| --- | --- | --- |
| `type: web-clip` | Raw Web Clipper capture | Web Clipper |
| `type: source` | Durable promoted source note | Codex |
| `#promote/source` | User wants a raw clip reviewed for source promotion | User |
| `#concept/<slug>` | Literal Concept tag counted for Concept creation candidates | User/Codex |
| `- [loop] ...` | User-written open-loop candidate | User |
| `- Repo: <path>` | Observer-written repo activity marker | Observer |
"""

MEMORY_INDEX_TEMPLATE = """# Memory Index

## Recent Memory Notes
<!-- codex:start recent-memory -->
<!-- codex:end recent-memory -->

## Reentry Notes
<!-- codex:start reentry-notes -->
<!-- codex:end reentry-notes -->

## Open Questions
<!-- codex:start open-questions -->
<!-- codex:end open-questions -->

## Notes
<!-- user:start notes -->
<!-- user:end notes -->
"""

PROJECT_INDEX_TEMPLATE = """# Project Index

## Active Projects
<!-- observer:start active-projects -->
<!-- observer:end active-projects -->

## Dormant Projects
<!-- observer:start dormant-projects -->
<!-- observer:end dormant-projects -->

## Archived Projects
<!-- observer:start archived-projects -->
<!-- observer:end archived-projects -->

## Project Candidates
<!-- observer:start project-candidates -->
<!-- observer:end project-candidates -->

## Notes
<!-- user:start notes -->
<!-- user:end notes -->
"""

WORKFLOW_INDEX_TEMPLATE = """# Workflow Index

## Active Workflows
<!-- observer:start active-workflows -->
<!-- observer:end active-workflows -->

## Candidate Workflows
<!-- observer:start candidate-workflows -->
<!-- observer:end candidate-workflows -->

## Notes
<!-- user:start notes -->
<!-- user:end notes -->
"""

SOURCE_INDEX_TEMPLATE = """# Source Index

## Recent Sources
<!-- observer:start recent-sources -->
<!-- observer:end recent-sources -->

## Source Candidates
<!-- observer:start source-candidates -->
<!-- observer:end source-candidates -->

## Stale Clips
<!-- observer:start stale-clips -->
<!-- observer:end stale-clips -->

## Concept Tag Candidates
<!-- observer:start concept-tag-candidates -->
<!-- observer:end concept-tag-candidates -->

## Notes
<!-- user:start notes -->
<!-- user:end notes -->
"""


@dataclass
class CommandSummary:
    key: str
    count: int
    first_ts: str
    last_ts: str
    last_command: str
    last_cwd: str


def vault_root() -> Path:
    return Path(os.environ.get("OBSIDIAN_VAULT", "~/Documents/Obsidian/ryan-vault")).expanduser()


def today_local() -> str:
    return date.today().isoformat()


def parse_day(value: str | None) -> str:
    if not value or value == "today":
        return today_local()
    if not re.match(r"^\d{4}-\d{2}-\d{2}$", value):
        raise SystemExit(f"Invalid date '{value}'. Expected YYYY-MM-DD.")
    return value


def slugify(value: str) -> str:
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    return value.strip("-") or "unknown"


def command_key(command: str) -> str:
    try:
        parts = shlex.split(command)
    except ValueError:
        parts = command.split()

    while parts and ASSIGNMENT_RE.match(parts[0]):
        parts.pop(0)

    if not parts:
        return "unknown"

    first = Path(parts[0]).name
    if first.endswith(".sh"):
        first = first[:-3]
    return slugify(first)


def shell_tokens(command: str) -> list[str]:
    try:
        return shlex.split(command)
    except ValueError:
        return command.split()


def is_path_like_token(token: str) -> bool:
    return "/" in token or token.endswith(PATH_EXTENSIONS)


def normalize_path_subject(value: str) -> str:
    return slugify(value.strip().strip("'\""))


def is_interpreter_subject_chain(tokens: list[str]) -> bool:
    chain = "-".join(tokens)
    if chain in INTERPRETER_CHAINS:
        return True
    if len(tokens) == 1 and tokens[0] in GENERIC_INTERPRETERS:
        return True
    return False


def normalized_command_subject(command: str) -> str:
    parts = shell_tokens(command)
    while parts and ASSIGNMENT_RE.match(parts[0]):
        parts.pop(0)

    verbs: list[str] = []
    path_args: list[str] = []
    drop_next_value = False
    for token in parts:
        if token == "--":
            drop_next_value = False
            continue
        if drop_next_value and not token.startswith("-"):
            drop_next_value = False
            continue
        drop_next_value = False
        if token.startswith("-") and token != "-":
            if re.match(r"^-[A-Za-z]$", token):
                drop_next_value = True
            continue
        if not verbs and "/" in token:
            verbs.append(slugify(Path(token).name))
            continue
        if is_path_like_token(token):
            path_args.append(token)
            continue
        verbs.append(slugify(Path(token).name))

    verbs = [item for item in verbs if item]
    if not verbs:
        return normalize_path_subject(path_args[0]) if path_args else "unknown"

    if path_args and is_interpreter_subject_chain(verbs):
        return slugify("-".join([*verbs, path_args[0]]))
    return slugify("-".join(verbs))


def should_skip_command(command: str) -> bool:
    if not command.strip():
        return True
    if command[:1].isspace():
        return True
    return False


def redact_command(command: str) -> tuple[str, str, bool]:
    if SENSITIVE_RE.search(command):
        return "[REDACTED]", "redacted", True
    return command, command_key(command), False


def ensure_vault(root: Path) -> None:
    for rel in [
        "raw/events",
        "raw/explorations",
        "raw/memory",
        "raw/open-loops",
        "raw/observer-digests",
        "raw/web-clips",
        "raw/web-clips/archive",
        "raw/web-clips/articles",
        "raw/web-clips/docs",
        "raw/web-clips/references",
        "raw/web-clips/videos",
        "daily",
        "wiki/concepts",
        "wiki/commands",
        "wiki/memory",
        "wiki/open-loops",
        "wiki/open-loops/archive",
        "wiki/projects",
        "wiki/sources",
        "wiki/workflows",
        "maps",
    ]:
        (root / rel).mkdir(parents=True, exist_ok=True)

    write_if_missing(root / "AGENTS.md", AGENTS_TEMPLATE)
    ensure_agents_v1_section(root / "AGENTS.md")
    ensure_agents_v2_v3_sections(root / "AGENTS.md")
    write_if_missing(root / "inbox.md", "# Inbox\n")
    write_if_missing(root / "sources.md", "# Sources\n")
    write_if_missing(root / "maps" / "home.md", "# Home\n\n- [[daily]]\n- [[wiki/commands]]\n")
    write_if_missing(root / "maps" / "memory-index.md", MEMORY_INDEX_TEMPLATE)
    write_if_missing(root / "maps" / "project-index.md", PROJECT_INDEX_TEMPLATE)
    write_if_missing(root / "maps" / "workflow-index.md", WORKFLOW_INDEX_TEMPLATE)
    write_if_missing(root / "maps" / "source-index.md", SOURCE_INDEX_TEMPLATE)


def write_if_missing(path: Path, content: str) -> None:
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")


def ensure_agents_v1_section(path: Path) -> None:
    text = path.read_text(encoding="utf-8") if path.exists() else ""
    marker = "## Open Loops"
    if marker in text and "## Explorations" in text:
        if "Archiving sets `status: archived` in place in V1" not in text:
            text = text.replace(
                "Resolved loops archive after 14 days.\n",
                "Resolved loops archive after 14 days.\n"
                "Archiving sets `status: archived` in place in V1; files are not moved automatically.\n",
                1,
            )
            path.write_text(text, encoding="utf-8")
        return
    additions = []
    if marker not in text:
        additions.append(
            """## Open Loops

Open-loop raw state lives in raw/open-loops and is canonical.
Open-loop wiki notes live in wiki/open-loops and are Codex-synced views.

Observer may create candidates and resolution evidence in raw state and daily observer blocks.
Codex creates, updates, resolves, and archives wiki/open-loops notes only after user approval.

Deduplication uses loop_key.
Filenames use filename_key.

Statuses are candidate, accepted, surfaced, resolved, archived.
Surfaced means the user has seen the loop at least once; surfaced loops can still appear in startday.

Resolved loops archive after 14 days.
Archiving sets `status: archived` in place in V1; files are not moved automatically.
Stale loops are accepted or surfaced loops whose updated date is older than 7 days.
"""
        )
    if "## Explorations" not in text:
        additions.append(
            """## Explorations

Exploration raw state lives in raw/explorations and is canonical.
Explorations are temporary side quests, not durable wiki nodes in V1.
Users can create exploration candidates with `- [explore] ...`.
Observer may propose an exploration when a session has 5 or more meaningful commands outside the current daily focus text.
If no current daily focus text exists, observer must not use the off-focus heuristic.
Explorations have a default 24-hour TTL.
Codex reviews expired explorations and can archive, extend, convert to open loop, or keep as raw material for V2 review.
"""
        )
    if additions:
        path.write_text(text.rstrip() + "\n\n" + "\n\n".join(additions) + "\n", encoding="utf-8")


def ensure_agents_v2_v3_sections(path: Path) -> None:
    text = path.read_text(encoding="utf-8") if path.exists() else ""
    original_text = text
    text = text.replace(
        "Daily repo activity is written only inside the observer repos block as `- Repo: `/absolute/path``.",
        "Daily repo activity is written only inside the observer repos block as `- Repo: <absolute-repo-path>`.",
    )
    text = text.replace(
        "| `- Repo: `/path`` | Observer-written repo activity marker | Observer |",
        "| `- Repo: <path>` | Observer-written repo activity marker | Observer |",
    )
    additions = []
    if "## Projects And Workflows" not in text:
        additions.append(
            """## Projects And Workflows

Daily repo activity is written only inside the observer repos block as `- Repo: <absolute-repo-path>`.
Project notes live in wiki/projects and are created only after user approval.
Workflow notes live in wiki/workflows and represent exact repeated command-session sequences only.
Concept notes live in wiki/concepts and are user-explicit only.
Observer may update observer fenced blocks and map indexes for Projects and Workflows.
Project archiving sets `status: archived` in place; files are not deleted automatically.
"""
        )
    if "## Web Clips" not in text:
        additions.append(
            """## Web Clips

Web Clipper writes only to raw/web-clips.
Web Clipper must not write directly to wiki.
Raw web clip filenames must include date, domain, and title.
"""
        )
    if "## Sources" not in text:
        additions.append(
            """## Sources

Source notes live in wiki/sources.
Codex promotes selected raw clips into Source notes only after user approval.
Source notes must preserve source_url and source_clip.
Source notes summarize; they do not copy entire articles.
"""
        )
    if "## Source Candidates" not in text:
        additions.append(
            """## Source Candidates

Raw clips become candidates by #promote/source, explicit review request, or incoming links from daily/project/workflow/concept notes.
Raw clips older than 30 days with no promote tag and no incoming links are stale.
Stale clips are reviewed before archive.
"""
        )
    if "## Concepts And Sources" not in text:
        additions.append(
            """## Concepts And Sources

Concept creation from source tags requires the same literal #concept/<slug> tag in 3 or more notes, no existing Concept note, and user approval.
Concept tag detection counts YAML tags arrays and inline body tags.
Codex must not rewrite user-owned Concept prose.
Existing Concept updates may only touch the codex-owned sourced-claims block.
"""
        )
    if "## Markers And Tags" not in text:
        additions.append(
            """## Markers And Tags

| Marker | Meaning | Owner |
| --- | --- | --- |
| `type: web-clip` | Raw Web Clipper capture | Web Clipper |
| `type: source` | Durable promoted source note | Codex |
| `#promote/source` | User wants a raw clip reviewed for source promotion | User |
| `#concept/<slug>` | Literal Concept tag counted for Concept creation candidates | User/Codex |
| `- [loop] ...` | User-written open-loop candidate | User |
| `- Repo: <path>` | Observer-written repo activity marker | Observer |
"""
        )
    if additions:
        path.write_text(text.rstrip() + "\n\n" + "\n\n".join(additions) + "\n", encoding="utf-8")
    elif path.exists() and text != original_text:
        path.write_text(text, encoding="utf-8")


def ensure_daily(root: Path, day: str) -> Path:
    ensure_vault(root)
    path = root / "daily" / f"{day}.md"
    write_if_missing(path, DAILY_TEMPLATE.format(day=day))
    ensure_daily_v1_sections(path)
    ensure_daily_memory_section(path)
    return path


def ensure_daily_section(
    path: Path, *, heading: str, owner: str, name: str, before_heading: str
) -> None:
    text = path.read_text(encoding="utf-8")
    if f"<!-- {owner}:start {name} -->" in text:
        return

    section = (
        f"\n## {heading}\n"
        f"<!-- {owner}:start {name} -->\n"
        f"<!-- {owner}:end {name} -->\n"
    )
    marker = f"\n## {before_heading}\n"
    if marker in text:
        text = text.replace(marker, section + marker, 1)
    else:
        text = text.rstrip() + section
    path.write_text(text, encoding="utf-8")


def ensure_daily_v1_sections(path: Path) -> None:
    ensure_daily_section(
        path,
        heading="Repo Activity",
        owner="observer",
        name="repos",
        before_heading="Open Loops",
    )
    ensure_daily_section(
        path,
        heading="Open Loops",
        owner="observer",
        name="open-loops",
        before_heading="Promotion Candidates",
    )
    ensure_daily_section(
        path,
        heading="Explorations",
        owner="observer",
        name="explorations",
        before_heading="Promotion Candidates",
    )


def ensure_daily_memory_section(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    if "<!-- codex:start memory -->" in text:
        return

    section = (
        "\n## Memory\n"
        "<!-- codex:start memory -->\n"
        "<!-- codex:end memory -->\n"
    )
    marker = "\n## Notes\n"
    if marker in text:
        text = text.replace(marker, section + marker, 1)
    else:
        text = text.rstrip() + section
    path.write_text(text, encoding="utf-8")


def event_path(root: Path, day: str) -> Path:
    return root / "raw" / "events" / f"{day}.jsonl"


def append_jsonl(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, sort_keys=True, ensure_ascii=False) + "\n")


def load_jsonl(path: Path) -> list[dict[str, object]]:
    if not path.exists():
        return []

    events: list[dict[str, object]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return events


def append_jsonl_once(
    path: Path, payload: dict[str, object], identity_keys: tuple[str, ...]
) -> bool:
    identity = tuple(str(payload.get(key, "")) for key in identity_keys)
    for event in load_jsonl(path):
        existing = tuple(str(event.get(key, "")) for key in identity_keys)
        if existing == identity:
            return False
    append_jsonl(path, payload)
    return True


def cmd_init_vault(_args: argparse.Namespace) -> int:
    root = vault_root()
    ensure_vault(root)
    print(root)
    return 0


def cmd_ensure_daily(args: argparse.Namespace) -> int:
    root = vault_root()
    day = parse_day(args.date)
    print(ensure_daily(root, day))
    return 0


def cmd_record_command(args: argparse.Namespace) -> int:
    if os.environ.get("OBSERVER_ENABLED", "true").lower() == "false":
        return 0
    if os.environ.get("OBSERVER_CAPTURE_COMMANDS", "true").lower() == "false":
        return 0
    raw_command = args.command.rstrip("\r\n")
    if should_skip_command(raw_command):
        return 0

    root = vault_root()
    ensure_vault(root)

    end_epoch = float(args.end_epoch) if args.end_epoch else datetime.now().timestamp()
    start_epoch = float(args.start_epoch) if args.start_epoch else end_epoch
    timestamp = datetime.fromtimestamp(end_epoch).astimezone()
    day = timestamp.date().isoformat()
    command, key, redacted = redact_command(raw_command)

    payload: dict[str, object] = {
        "schema": 1,
        "ts": timestamp.isoformat(timespec="seconds"),
        "event": "command",
        "command": command,
        "command_key": key,
        "exit_code": int(args.exit_code),
        "cwd": args.cwd,
        "duration_ms": max(0, int((end_epoch - start_epoch) * 1000)),
    }
    if redacted:
        payload["redacted"] = True

    append_jsonl(event_path(root, day), payload)
    return 0


def load_events(root: Path, day: str) -> list[dict[str, object]]:
    return load_jsonl(event_path(root, day))


def is_meaningful_event(event: dict[str, object]) -> bool:
    key = str(event.get("command_key", ""))
    if event.get("event") != "command":
        return False
    if key in DENYLIST or key == "redacted":
        return False
    return bool(key)


def summarize_commands(events: list[dict[str, object]]) -> list[CommandSummary]:
    grouped: dict[str, list[dict[str, object]]] = defaultdict(list)
    for event in events:
        if is_meaningful_event(event):
            grouped[str(event["command_key"])].append(event)

    summaries: list[CommandSummary] = []
    for key, group in grouped.items():
        group = sorted(group, key=lambda item: str(item.get("ts", "")))
        last = group[-1]
        summaries.append(
            CommandSummary(
                key=key,
                count=len(group),
                first_ts=str(group[0].get("ts", "")),
                last_ts=str(last.get("ts", "")),
                last_command=str(last.get("command", "")),
                last_cwd=str(last.get("cwd", "")),
            )
        )
    return sorted(summaries, key=lambda item: (-item.count, item.key))


def command_link(key: str) -> str:
    return f"[[wiki/commands/{key}|{key}]]"


def render_commands_block(summaries: list[CommandSummary]) -> str:
    if not summaries:
        return "- No meaningful commands recorded yet."

    lines = []
    for summary in summaries:
        label = "run" if summary.count == 1 else "runs"
        last_command = summary.last_command.rstrip("\r\n")
        lines.append(
            f"- {command_link(summary.key)} - {summary.count} {label}; last: `{last_command}`"
        )
    return "\n".join(lines)


def render_significant_events(events: list[dict[str, object]]) -> str:
    failures = [
        event
        for event in events
        if is_meaningful_event(event) and int(event.get("exit_code", 0)) != 0
    ]
    if not failures:
        return "- No command failures recorded."

    lines = []
    for event in failures[-5:]:
        lines.append(
            "- `{cmd}` exited {code} in `{cwd}`".format(
                cmd=event.get("command", ""),
                code=event.get("exit_code", ""),
                cwd=event.get("cwd", ""),
            )
        )
    return "\n".join(lines)


def replace_block(text: str, owner: str, name: str, body: str) -> str:
    start = f"<!-- {owner}:start {name} -->"
    end = f"<!-- {owner}:end {name} -->"
    replacement = f"{start}\n{body.rstrip()}\n{end}"
    pattern = OBSERVER_BLOCK_RE_TEMPLATE.format(owner=re.escape(owner), name=re.escape(name))
    if re.search(pattern, text):
        return re.sub(pattern, lambda _match: replacement, text)
    return text.rstrip() + f"\n\n{replacement}\n"


def fenced_block(text: str, owner: str, name: str) -> str:
    pattern = OBSERVER_BLOCK_RE_TEMPLATE.format(owner=re.escape(owner), name=re.escape(name))
    match = re.search(pattern, text)
    return match.group(0) if match else ""


def parse_frontmatter_value(text: str, key: str) -> str:
    if not text.startswith("---\n"):
        return ""
    end = text.find("\n---", 4)
    if end == -1:
        return ""
    frontmatter = text[4:end]
    for line in frontmatter.splitlines():
        if line.startswith(f"{key}:"):
            return line.split(":", 1)[1].strip().strip('"')
    return ""


def parse_yaml_list_value(text: str, key: str) -> list[str]:
    if not text.startswith("---\n"):
        return []
    end = text.find("\n---", 4)
    if end == -1:
        return []
    frontmatter = text[4:end]
    lines = frontmatter.splitlines()
    values: list[str] = []
    in_list = False
    for line in lines:
        if line.startswith(f"{key}:"):
            in_list = True
            remainder = line.split(":", 1)[1].strip()
            if remainder and remainder not in {"[]", ""}:
                values.append(remainder.strip('"'))
            continue
        if in_list:
            if line.startswith("  - "):
                values.append(line[4:].strip().strip('"'))
                continue
            if line and not line.startswith(" "):
                break
    return values


def set_frontmatter_value(text: str, key: str, value: str) -> str:
    if not text.startswith("---\n"):
        return f"---\n{key}: {value}\n---\n\n{text.lstrip()}"
    end = text.find("\n---", 4)
    if end == -1:
        return text
    frontmatter = text[:end]
    body = text[end:]
    if re.search(rf"(?m)^{re.escape(key)}:", frontmatter):
        frontmatter = re.sub(rf"(?m)^{re.escape(key)}:.*$", f"{key}: {value}", frontmatter)
    else:
        frontmatter += f"\n{key}: {value}"
    return frontmatter + body


def fenced_block_body(text: str, owner: str, name: str) -> str:
    block = fenced_block(text, owner, name)
    if not block:
        return ""
    return re.sub(
        rf"(?ms)^<!-- {re.escape(owner)}:start {re.escape(name)} -->\n?|\n?<!-- {re.escape(owner)}:end {re.escape(name)} -->$",
        "",
        block,
    ).strip()


@functools.lru_cache(maxsize=256)
def repo_root_for_cwd(cwd: str) -> Path:
    path = Path(cwd).expanduser()
    if not path.exists():
        return path
    try:
        result = subprocess.run(
            ["git", "-C", str(path), "rev-parse", "--show-toplevel"],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=2,
        )
    except (OSError, subprocess.SubprocessError):
        return path
    if result.returncode == 0 and result.stdout.strip():
        return Path(result.stdout.strip())
    return path


def repo_slug_for_cwd(cwd: str) -> str:
    root = repo_root_for_cwd(cwd)
    return slugify(root.name or "workspace")


def loop_filename_key(repo_slug: str, trigger_type: str, subject: str) -> str:
    return "--".join([slugify(repo_slug), slugify(trigger_type), slugify(subject)])


def loop_key(repo_slug: str, trigger_type: str, subject: str) -> str:
    return "::".join([slugify(repo_slug), slugify(trigger_type), slugify(subject)])


def loop_key_to_filename_key(value: str) -> str:
    if "::" in value:
        return "--".join(slugify(part) for part in value.split("::"))
    return value.removesuffix(".jsonl").removesuffix(".md")


def open_loop_raw_path(root: Path, filename_key: str) -> Path:
    return root / "raw" / "open-loops" / f"{filename_key}.jsonl"


def open_loop_note_path(root: Path, filename_key: str) -> Path:
    return root / "wiki" / "open-loops" / f"{filename_key}.md"


def exploration_raw_path(root: Path, filename_key: str) -> Path:
    return root / "raw" / "explorations" / f"{filename_key}.jsonl"


def all_open_loop_raw_events(root: Path) -> list[dict[str, object]]:
    events: list[dict[str, object]] = []
    for path in sorted((root / "raw" / "open-loops").glob("*.jsonl")):
        events.extend(load_jsonl(path))
    return events


def raw_events_for_loop(root: Path, key_or_filename: str) -> tuple[str, list[dict[str, object]]]:
    filename_key = loop_key_to_filename_key(key_or_filename)
    path = open_loop_raw_path(root, filename_key)
    if path.exists():
        return filename_key, load_jsonl(path)
    for candidate in sorted((root / "raw" / "open-loops").glob("*.jsonl")):
        events = load_jsonl(candidate)
        if any(str(event.get("loop_key", "")) == key_or_filename for event in events):
            return candidate.stem, events
    return filename_key, []


def append_open_loop_event(root: Path, payload: dict[str, object]) -> bool:
    path = open_loop_raw_path(root, str(payload["filename_key"]))
    has_existing = bool(load_jsonl(path))
    if payload.get("event") == "candidate" and has_existing:
        payload = {**payload, "event": "recurrence"}
    return append_jsonl_once(
        path,
        payload,
        ("source_ts", "trigger_type", "evidence"),
    )


def append_exploration_event(root: Path, payload: dict[str, object]) -> bool:
    path = exploration_raw_path(root, str(payload["filename_key"]))
    return append_jsonl_once(
        path,
        payload,
        ("ts", "event", "trigger_type", "evidence"),
    )


def command_loop_payload(event: dict[str, object]) -> dict[str, object] | None:
    if not is_meaningful_event(event):
        return None
    if int(event.get("exit_code", 0)) == 0:
        return None
    command = str(event.get("command", ""))
    cwd = str(event.get("cwd", ""))
    subject = normalized_command_subject(command)
    repo_slug = repo_slug_for_cwd(cwd)
    key = loop_key(repo_slug, "command-failure", subject)
    filename_key = loop_filename_key(repo_slug, "command-failure", subject)
    ts = str(event.get("ts", datetime.now().astimezone().isoformat(timespec="seconds")))
    return {
        "schema": 1,
        "ts": ts,
        "source_ts": ts,
        "loop_key": key,
        "filename_key": filename_key,
        "event": "candidate",
        "trigger_type": "command-failure",
        "subject": subject,
        "cwd": cwd,
        "evidence": command,
        "exit_code": int(event.get("exit_code", 1)),
    }


def candidate_repo_roots(events: list[dict[str, object]]) -> list[Path]:
    roots: dict[str, Path] = {}
    for event in events:
        if event.get("event") != "command":
            continue
        cwd = str(event.get("cwd", ""))
        if not cwd:
            continue
        root = repo_root_for_cwd(cwd)
        if (root / ".git").exists():
            roots[str(root)] = root
    return sorted(roots.values(), key=lambda item: item.as_posix())


def modified_files_for_repo(repo: Path) -> list[Path]:
    try:
        result = subprocess.run(
            ["git", "-C", str(repo), "status", "--porcelain", "--untracked-files=no"],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=3,
        )
    except (OSError, subprocess.SubprocessError):
        return []
    if result.returncode != 0:
        return []
    files: list[Path] = []
    for line in result.stdout.splitlines():
        if len(line) < 4:
            continue
        rel = line[3:].strip()
        if " -> " in rel:
            rel = rel.split(" -> ", 1)[1].strip()
        path = repo / rel
        if path.is_file():
            files.append(path)
    return files


def file_has_todo(path: Path) -> bool:
    try:
        if path.stat().st_size > 512_000:
            return False
        for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            stripped = line.strip()
            if not TODO_RE.search(stripped):
                continue
            if TODO_COMMENT_RE.search(stripped):
                return True
            if stripped.startswith(("*", ";")):
                return True
        return False
    except OSError:
        return False


def todo_loop_payload(day: str, repo: Path, path: Path) -> dict[str, object]:
    try:
        rel_path = path.relative_to(repo).as_posix()
    except ValueError:
        rel_path = path.name
    subject = normalize_path_subject(rel_path)
    repo_slug = slugify(repo.name)
    key = loop_key(repo_slug, "todo-fixme", subject)
    filename_key = loop_filename_key(repo_slug, "todo-fixme", subject)
    return {
        "schema": 1,
        "ts": f"{day}T00:00:00",
        "source_ts": f"{day}:todo-fixme:{repo}:{rel_path}",
        "loop_key": key,
        "filename_key": filename_key,
        "event": "candidate",
        "trigger_type": "todo-fixme",
        "subject": subject,
        "cwd": str(repo),
        "file_path": rel_path,
        "evidence": f"TODO/FIXME in {rel_path}",
    }


def detect_todo_open_loop_events(root: Path, day: str, events: list[dict[str, object]]) -> None:
    for repo in candidate_repo_roots(events):
        for path in modified_files_for_repo(repo):
            if file_has_todo(path):
                append_open_loop_event(root, todo_loop_payload(day, repo, path))


def user_loop_payload(day: str, text: str, evidence: str) -> dict[str, object]:
    subject = slugify(text)
    key = loop_key("daily", "user-loop", subject)
    filename_key = loop_filename_key("daily", "user-loop", subject)
    ts = f"{day}T00:00:00"
    return {
        "schema": 1,
        "ts": ts,
        "source_ts": f"{day}:{evidence}",
        "loop_key": key,
        "filename_key": filename_key,
        "event": "candidate",
        "trigger_type": "user-loop",
        "subject": subject,
        "cwd": "",
        "evidence": evidence,
    }


def exploration_payload(
    *, day: str, trigger_type: str, subject: str, cwd: str, evidence: str
) -> dict[str, object]:
    context = repo_slug_for_cwd(cwd) if cwd else "daily"
    subject_slug = slugify(subject)
    key = "::".join([day, context, subject_slug])
    filename_key = "--".join([day, context, subject_slug])
    return {
        "schema": 1,
        "ts": f"{day}T00:00:00",
        "exploration_key": key,
        "filename_key": filename_key,
        "event": "candidate",
        "trigger_type": trigger_type,
        "subject": subject_slug,
        "cwd": cwd,
        "ttl_hours": 24,
        "evidence": evidence,
    }


def detect_open_loop_events(
    root: Path, day: str, events: list[dict[str, object]], daily_text: str
) -> None:
    for event in events:
        payload = command_loop_payload(event)
        if payload:
            append_open_loop_event(root, payload)

    detect_todo_open_loop_events(root, day, events)

    notes_body = fenced_block_body(daily_text, "user", "notes")
    for match in USER_LOOP_RE.finditer(notes_body):
        evidence = match.group(0).strip()
        payload = user_loop_payload(day, match.group(1).strip(), evidence)
        append_open_loop_event(root, payload)

    detect_resolution_candidates(root, events)
    detect_todo_resolution_candidates(root, day, events)


def detect_exploration_events(
    root: Path, day: str, events: list[dict[str, object]], daily_text: str
) -> None:
    notes_body = fenced_block_body(daily_text, "user", "notes")
    for match in USER_EXPLORE_RE.finditer(notes_body):
        evidence = match.group(0).strip()
        payload = exploration_payload(
            day=day,
            trigger_type="user-explore",
            subject=match.group(1).strip(),
            cwd="",
            evidence=evidence,
        )
        append_exploration_event(root, payload)

    focus_text = fenced_block_body(daily_text, "user", "focus")
    if not focus_text:
        return
    focus_slug = slugify(focus_text)
    grouped: dict[str, list[dict[str, object]]] = defaultdict(list)
    for event in events:
        if not is_meaningful_event(event):
            continue
        cwd = str(event.get("cwd", ""))
        grouped[repo_slug_for_cwd(cwd)].append(event)

    for repo_slug, group in grouped.items():
        if len(group) < 5 or repo_slug in focus_slug:
            continue
        last = sorted(group, key=lambda item: str(item.get("ts", "")))[-1]
        payload = exploration_payload(
            day=day,
            trigger_type="off-focus-commands",
            subject=f"{repo_slug} activity",
            cwd=str(last.get("cwd", "")),
            evidence=f"{len(group)} meaningful commands outside the daily focus.",
        )
        append_exploration_event(root, payload)


def open_loop_note_index(root: Path) -> dict[str, Path]:
    index: dict[str, Path] = {}
    for path in sorted((root / "wiki" / "open-loops").glob("*.md")):
        text = path.read_text(encoding="utf-8")
        key = parse_frontmatter_value(text, "loop_key")
        if key:
            index[key] = path
    return index


def open_loop_statuses(root: Path) -> dict[str, str]:
    statuses: dict[str, str] = {}
    for key, path in open_loop_note_index(root).items():
        statuses[key] = parse_frontmatter_value(path.read_text(encoding="utf-8"), "status")
    return statuses


def last_failure_ts(raw_events: list[dict[str, object]]) -> str:
    failures = [
        str(event.get("source_ts") or event.get("ts", ""))
        for event in raw_events
        if event.get("trigger_type") == "command-failure"
        and event.get("event") in {"candidate", "recurrence"}
    ]
    return max(failures) if failures else ""


def detect_resolution_candidates(root: Path, events: list[dict[str, object]]) -> None:
    note_statuses = open_loop_statuses(root)
    if not note_statuses:
        return
    for event in events:
        if not is_meaningful_event(event) or int(event.get("exit_code", 1)) != 0:
            continue
        cwd = str(event.get("cwd", ""))
        subject = normalized_command_subject(str(event.get("command", "")))
        repo_slug = repo_slug_for_cwd(cwd)
        key = loop_key(repo_slug, "command-failure", subject)
        if note_statuses.get(key) not in {"accepted", "surfaced"}:
            continue
        filename_key, raw_events = raw_events_for_loop(root, key)
        source_ts = str(event.get("ts", ""))
        if source_ts <= last_failure_ts(raw_events):
            continue
        payload = {
            "schema": 1,
            "ts": source_ts,
            "source_ts": source_ts,
            "loop_key": key,
            "filename_key": filename_key,
            "event": "resolution-candidate",
            "trigger_type": "command-failure",
            "subject": subject,
            "cwd": cwd,
            "evidence": f"{event.get('command', '')} exited 0",
            "exit_code": 0,
        }
        append_open_loop_event(root, payload)


def detect_todo_resolution_candidates(
    root: Path, day: str, events: list[dict[str, object]]
) -> None:
    note_statuses = open_loop_statuses(root)
    if not note_statuses:
        return
    touched_roots = {str(repo) for repo in candidate_repo_roots(events)}
    if not touched_roots:
        return

    for filename_key, raw_events in group_open_loop_events_by_file(root).items():
        todo_events = [event for event in raw_events if event.get("trigger_type") == "todo-fixme"]
        if not todo_events:
            continue
        latest = latest_event(todo_events)
        key = str(latest.get("loop_key", ""))
        if note_statuses.get(key) not in {"accepted", "surfaced"}:
            continue
        repo = Path(str(latest.get("cwd", "")))
        if str(repo) not in touched_roots:
            continue
        rel_path = str(latest.get("file_path", ""))
        if not rel_path:
            continue
        path = repo / rel_path
        if path.exists() and file_has_todo(path):
            continue
        payload = {
            "schema": 1,
            "ts": f"{day}T00:00:00",
            "source_ts": f"{day}:todo-resolved:{key}",
            "loop_key": key,
            "filename_key": filename_key,
            "event": "resolution-candidate",
            "trigger_type": "todo-fixme",
            "subject": str(latest.get("subject", "")),
            "cwd": str(repo),
            "file_path": rel_path,
            "evidence": f"TODO/FIXME no longer found in {rel_path}",
        }
        append_open_loop_event(root, payload)


def event_day(event: dict[str, object]) -> str:
    ts = str(event.get("source_ts") or event.get("ts", ""))
    return ts[:10]


def latest_event(events: list[dict[str, object]]) -> dict[str, object]:
    if not events:
        return {}
    return sorted(events, key=lambda item: str(item.get("source_ts") or item.get("ts", "")))[-1]


def humanize_subject(subject: str) -> str:
    return subject.replace("-", " ").strip().capitalize() or "Open loop"


def humanize_open_loop_title(event: dict[str, object]) -> str:
    trigger_type = str(event.get("trigger_type", ""))
    subject = str(event.get("subject", "open-loop"))
    cwd = str(event.get("cwd", ""))
    repo = repo_slug_for_cwd(cwd) if cwd else "daily"
    if trigger_type == "command-failure":
        return f"{humanize_subject(subject)} failing in {repo}"
    if trigger_type == "user-loop":
        return humanize_subject(subject)
    return f"{humanize_subject(subject)} in {repo}"


def recurrence_log_lines(events: list[dict[str, object]]) -> list[str]:
    entries = [
        event
        for event in events
        if event.get("event") in {"candidate", "recurrence", "resolution-candidate", "surfaced"}
    ]
    entries = sorted(entries, key=lambda item: str(item.get("source_ts") or item.get("ts", "")))
    hidden_count = max(0, len(entries) - 10)
    visible = entries[-10:]
    lines = []
    for event in visible:
        day = event_day(event)
        event_type = str(event.get("event", "event"))
        evidence = str(event.get("evidence", "")).strip()
        cwd = str(event.get("cwd", "")).strip()
        if event_type == "resolution-candidate":
            lines.append(f"- {day}: resolution candidate, `{evidence}`")
        elif event_type == "surfaced":
            lines.append(f"- {day}: surfaced in startday")
        elif cwd:
            lines.append(f"- {day}: {event_type} in `{cwd}`: `{evidence}`")
        else:
            lines.append(f"- {day}: {event_type}: {evidence}")
    if hidden_count:
        lines.append(f"- +{hidden_count} earlier occurrences")
    return lines or ["- No recurrence events yet."]


def open_loop_note_template(
    root: Path, *, day: str, filename_key: str, events: list[dict[str, object]]
) -> str:
    first = events[0]
    latest = latest_event(events)
    title = humanize_open_loop_title(latest)
    key = str(latest.get("loop_key", ""))
    related = f'  - "[[daily/{day}]]"'
    trigger = str(first.get("evidence", "")).strip()
    cwd = str(latest.get("cwd", "")).strip()
    current_state = f"`{trigger}`"
    if cwd:
        current_state += f" in `{cwd}`"
    return f"""---
type: open-loop
status: accepted
created: {day}
updated: {day}
last_surfaced:
loop_key: {key}
related:
{related}
---

# {title}

## Trigger
Detected from {obsidian_link(root, root / "daily" / f"{day}.md")}.

## Current State
{current_state}

## Next Action
Inspect the evidence and decide whether this still needs action.

## Recurrence Log
<!-- codex:start recurrence-log -->
{chr(10).join(recurrence_log_lines(events))}
<!-- codex:end recurrence-log -->

## Resolution
<!-- codex:start resolution -->
<!-- codex:end resolution -->

## Notes
<!-- user:start notes -->
<!-- user:end notes -->
"""


def sync_open_loop_note(root: Path, path: Path, day: str, events: list[dict[str, object]]) -> None:
    text = path.read_text(encoding="utf-8")
    text = set_frontmatter_value(text, "updated", day)
    text = replace_block(text, "codex", "recurrence-log", "\n".join(recurrence_log_lines(events)))
    path.write_text(text, encoding="utf-8")


def render_candidate_line(root: Path, event: dict[str, object]) -> str:
    trigger_type = str(event.get("trigger_type", ""))
    key = str(event.get("loop_key", ""))
    evidence = str(event.get("evidence", "")).strip()
    cwd = str(event.get("cwd", "")).strip()
    if trigger_type == "command-failure":
        location = f" in `{cwd}`" if cwd else ""
        return (
            f"- [candidate] `{evidence}` failed{location}.\n"
            f"  Key: `{key}`\n"
            "  Next action: inspect the failure and rerun the narrow command."
        )
    return (
        f"- [candidate] {evidence}\n"
        f"  Key: `{key}`\n"
        "  Next action: decide whether to accept, defer, or skip this loop."
    )


def render_resolution_line(root: Path, event: dict[str, object]) -> str:
    key = str(event.get("loop_key", ""))
    filename_key = str(event.get("filename_key", loop_key_to_filename_key(key)))
    path = open_loop_note_path(root, filename_key)
    label = humanize_open_loop_title(event)
    link = obsidian_link(root, path, label)
    return (
        f"- [resolve?] {link}\n"
        f"  Evidence: `{event.get('evidence', '')}` on {event_day(event)}."
    )


def accepted_open_loop_notes(root: Path) -> list[dict[str, object]]:
    notes: list[dict[str, object]] = []
    for path in sorted((root / "wiki" / "open-loops").glob("*.md")):
        text = path.read_text(encoding="utf-8")
        status = parse_frontmatter_value(text, "status")
        if status not in {"accepted", "surfaced"}:
            continue
        updated = parse_frontmatter_value(text, "updated")
        title_match = re.search(r"(?m)^# (.+)$", text)
        title = title_match.group(1).strip() if title_match else path.stem
        notes.append(
            {
                "path": path,
                "status": status,
                "updated": updated,
                "loop_key": parse_frontmatter_value(text, "loop_key"),
                "title": title,
            }
        )
    return notes


def selected_surface_loops(root: Path, day: str) -> list[dict[str, object]]:
    anchor = date.fromisoformat(day)
    stale: list[dict[str, object]] = []
    fresh: list[dict[str, object]] = []
    for note in accepted_open_loop_notes(root):
        updated = str(note.get("updated", ""))
        try:
            updated_day = date.fromisoformat(updated)
        except ValueError:
            updated_day = anchor
        if updated_day < anchor - timedelta(days=7):
            stale.append(note)
        else:
            fresh.append(note)

    stale = sorted(stale, key=lambda item: str(item.get("updated", "")))
    fresh = sorted(fresh, key=lambda item: str(item.get("updated", "")), reverse=True)
    selected = stale[:1] + fresh[:2]
    if not stale:
        selected = fresh[:3]
    if not fresh and stale:
        selected = stale[:3]
    return selected[:3]


def render_surface_lines(root: Path, day: str) -> list[str]:
    lines = []
    anchor = date.fromisoformat(day)
    for note in selected_surface_loops(root, day):
        path = note["path"]
        updated = str(note.get("updated", ""))
        label = str(note.get("title", Path(path).stem))
        try:
            updated_day = date.fromisoformat(updated)
        except ValueError:
            updated_day = anchor
        stale_label = " stale" if updated_day < anchor - timedelta(days=7) else ""
        lines.append(
            f"- [surface{stale_label}] {obsidian_link(root, Path(path), label)}\n"
            f"  Updated: {updated or 'unknown'}"
        )
    return lines


def render_open_loops_block(root: Path, day: str) -> str:
    statuses = open_loop_statuses(root)
    lines: list[str] = []
    lines.extend(render_surface_lines(root, day))

    candidates: list[dict[str, object]] = []
    resolutions: list[dict[str, object]] = []
    for filename_key, group in group_open_loop_events_by_file(root).items():
        if not group:
            continue
        latest_status = statuses.get(str(group[-1].get("loop_key", "")), "")
        for event in group:
            if event_day(event) != day:
                continue
            if event.get("event") == "resolution-candidate":
                resolutions.append(event)
            elif event.get("event") in {"candidate", "recurrence"} and latest_status not in {
                "accepted",
                "surfaced",
                "resolved",
                "archived",
            }:
                candidates.append(event)
                break

    lines.extend(render_candidate_line(root, event) for event in candidates[:5])
    lines.extend(render_resolution_line(root, event) for event in resolutions[:3])
    return "\n".join(lines) if lines else "- No open-loop candidates or surfaced loops."


def group_open_loop_events_by_file(root: Path) -> dict[str, list[dict[str, object]]]:
    grouped: dict[str, list[dict[str, object]]] = {}
    for path in sorted((root / "raw" / "open-loops").glob("*.jsonl")):
        grouped[path.stem] = sorted(
            load_jsonl(path), key=lambda item: str(item.get("source_ts") or item.get("ts", ""))
        )
    return grouped


def render_explorations_block(root: Path, day: str) -> str:
    lines = []
    anchor = datetime.fromisoformat(f"{day}T00:00:00")
    for path in sorted((root / "raw" / "explorations").glob("*.jsonl")):
        events = sorted(load_jsonl(path), key=lambda item: str(item.get("ts", "")))
        if not events:
            continue
        latest = events[-1]
        if latest.get("event") in {"archive", "convert", "hold"}:
            continue
        candidate = next((event for event in events if event.get("event") == "candidate"), latest)
        created_day = str(candidate.get("ts", ""))[:10]
        is_today = created_day == day
        extended_ttl = max(
            (
                int(event.get("ttl_hours", 24))
                for event in events
                if event.get("event") in {"candidate", "extend"}
            ),
            default=24,
        )
        try:
            created = datetime.fromisoformat(str(candidate.get("ts", f"{day}T00:00:00")))
        except ValueError:
            created = anchor
        expired = anchor - created >= timedelta(hours=extended_ttl)
        if not is_today and not expired:
            continue
        marker = "expired" if expired else "candidate"
        lines.append(
            f"- [{marker}] {humanize_subject(str(candidate.get('subject', 'exploration')))}.\n"
            f"  Key: `{candidate.get('exploration_key', '')}`\n"
            f"  TTL: review within {extended_ttl} hours."
        )
    return "\n".join(lines) if lines else "- No exploration candidates."


def repo_paths_from_events(events: list[dict[str, object]]) -> list[Path]:
    repos: dict[str, Path] = {}
    for repo in candidate_repo_roots(events):
        repos[str(repo)] = repo
    return sorted(repos.values(), key=lambda item: item.as_posix())


def render_repos_block(events: list[dict[str, object]]) -> str:
    repos = repo_paths_from_events(events)
    if not repos:
        return "- No git repos recorded."
    return "\n".join(f"- Repo: `{repo}`" for repo in repos)


def repos_block(text: str) -> str:
    return fenced_block(text, "observer", "repos")


def scan_recent_repo_markers(root: Path, day: str, days: int = 14) -> Counter[str]:
    anchor = date.fromisoformat(day)
    counts: Counter[str] = Counter()
    for offset in range(days):
        current = anchor - timedelta(days=offset)
        path = root / "daily" / f"{current.isoformat()}.md"
        if not path.exists():
            continue
        block = repos_block(path.read_text(encoding="utf-8"))
        for repo in set(REPO_MARKER_RE.findall(block)):
            counts[repo] += 1
    return counts


def recent_daily_repo_days(root: Path, repo: str, day: str, days: int = 14) -> list[str]:
    anchor = date.fromisoformat(day)
    found = []
    marker = f"- Repo: `{repo}`"
    for offset in range(days):
        current = anchor - timedelta(days=offset)
        path = root / "daily" / f"{current.isoformat()}.md"
        if not path.exists():
            continue
        if marker in repos_block(path.read_text(encoding="utf-8")):
            found.append(current.isoformat())
    return sorted(found, reverse=True)


def project_slug_for_repo(root: Path, repo: Path) -> str:
    base = slugify(repo.name)
    path = root / "wiki" / "projects" / f"{base}.md"
    if not path.exists():
        return base
    existing_repo = parse_frontmatter_value(path.read_text(encoding="utf-8"), "repo")
    if not existing_repo or existing_repo == repo.as_posix():
        return base
    digest = hashlib.sha1(repo.as_posix().encode("utf-8")).hexdigest()[:8]
    return f"{base}-{digest}"


def project_note_path_for_repo(root: Path, repo: Path) -> Path:
    return root / "wiki" / "projects" / f"{project_slug_for_repo(root, repo)}.md"


def project_notes(root: Path) -> list[dict[str, object]]:
    notes = []
    for path in sorted((root / "wiki" / "projects").glob("*.md")):
        text = path.read_text(encoding="utf-8")
        title_match = re.search(r"(?m)^# (.+)$", text)
        notes.append(
            {
                "path": path,
                "title": title_match.group(1).strip() if title_match else path.stem,
                "status": parse_frontmatter_value(text, "status") or "active",
                "repo": parse_frontmatter_value(text, "repo"),
                "updated": parse_frontmatter_value(text, "updated"),
            }
        )
    return notes


def project_note_for_repo(root: Path, repo: str) -> Path | None:
    for note in project_notes(root):
        if str(note.get("repo", "")) == repo:
            return Path(note["path"])
    return None


def project_burst_candidates(events: list[dict[str, object]]) -> set[str]:
    by_repo: dict[str, list[datetime]] = defaultdict(list)
    for event in events:
        if not is_meaningful_event(event):
            continue
        cwd = str(event.get("cwd", ""))
        repo = repo_root_for_cwd(cwd)
        if not (repo / ".git").exists():
            continue
        try:
            ts = datetime.fromisoformat(str(event.get("ts", "")))
        except ValueError:
            continue
        by_repo[repo.as_posix()].append(ts)

    burst_repos = set()
    window = timedelta(hours=4)
    for repo, timestamps in by_repo.items():
        timestamps = sorted(timestamps)
        start = 0
        for end, value in enumerate(timestamps):
            while value - timestamps[start] > window:
                start += 1
            if end - start + 1 >= 20:
                burst_repos.add(repo)
                break
    return burst_repos


def repos_with_active_open_loops(root: Path) -> set[str]:
    active_keys = {
        key
        for key, status in open_loop_statuses(root).items()
        if status in {"accepted", "surfaced"}
    }
    repos = set()
    for group in group_open_loop_events_by_file(root).values():
        for event in reversed(group):
            key = str(event.get("loop_key", ""))
            cwd = str(event.get("cwd", ""))
            if key in active_keys and cwd:
                repo = repo_root_for_cwd(cwd)
                if (repo / ".git").exists():
                    repos.add(repo.as_posix())
                break
    return repos


def project_candidates(root: Path, day: str, events: list[dict[str, object]]) -> list[dict[str, object]]:
    candidates: dict[str, set[str]] = defaultdict(set)
    existing = {str(note.get("repo", "")) for note in project_notes(root)}
    for repo, count in scan_recent_repo_markers(root, day).items():
        if repo not in existing and count >= 3:
            candidates[repo].add(f"appeared in {count} daily repo blocks within 14 days")
    for repo in repos_with_active_open_loops(root):
        if repo not in existing:
            candidates[repo].add("has accepted or surfaced open loops")
    for repo in project_burst_candidates(events):
        if repo not in existing:
            candidates[repo].add("has 20+ meaningful commands in a 4-hour window")
    return [
        {"repo": repo, "reasons": sorted(reasons)}
        for repo, reasons in sorted(candidates.items(), key=lambda item: item[0])
    ]


def render_project_candidates(root: Path, day: str, events: list[dict[str, object]]) -> str:
    candidates = project_candidates(root, day, events)
    if not candidates:
        return "- No project candidates."
    lines = []
    for candidate in candidates[:10]:
        repo = str(candidate["repo"])
        reasons = "; ".join(candidate["reasons"])
        lines.append(f"- [candidate] `{repo}` - {reasons}.")
    return "\n".join(lines)


def project_command_lines(root: Path, repo: str, day: str) -> list[str]:
    anchor = date.fromisoformat(day)
    grouped: dict[str, dict[str, object]] = {}
    for offset in range(14):
        current = anchor - timedelta(days=offset)
        for event in load_events(root, current.isoformat()):
            if not is_meaningful_event(event):
                continue
            cwd = str(event.get("cwd", ""))
            if repo_root_for_cwd(cwd).as_posix() != repo:
                continue
            key = str(event.get("command_key", ""))
            state = grouped.setdefault(key, {"count": 0, "last": ""})
            state["count"] = state["count"] + 1
            state["last"] = max(str(state["last"]), str(event.get("ts", "")))
    ordered = sorted(grouped.items(), key=lambda item: (int(item[1]["count"]), str(item[1]["last"])), reverse=True)
    lines = []
    for key, state in ordered[:10]:
        lines.append(f"- {command_link(key)} - {state['count']} runs; last: `{state['last']}`")
    return lines


def project_open_loop_lines(root: Path, repo: str) -> list[str]:
    lines = []
    statuses = open_loop_statuses(root)
    note_index = open_loop_note_index(root)
    for filename_key, events in group_open_loop_events_by_file(root).items():
        if not events:
            continue
        latest = latest_event(events)
        key = str(latest.get("loop_key", ""))
        if statuses.get(key) not in {"accepted", "surfaced"}:
            continue
        cwd = str(latest.get("cwd", ""))
        if not cwd or repo_root_for_cwd(cwd).as_posix() != repo:
            continue
        note_path = note_index.get(key, open_loop_note_path(root, filename_key))
        title = humanize_open_loop_title(latest)
        lines.append(f"- {obsidian_link(root, note_path, title)}")
    return lines[:10]


def workflow_notes(root: Path) -> list[dict[str, object]]:
    notes = []
    for path in sorted((root / "wiki" / "workflows").glob("*.md")):
        text = path.read_text(encoding="utf-8")
        title_match = re.search(r"(?m)^# (.+)$", text)
        notes.append(
            {
                "path": path,
                "title": title_match.group(1).strip() if title_match else path.stem,
                "status": parse_frontmatter_value(text, "status") or "draft",
                "updated": parse_frontmatter_value(text, "updated"),
                "sequence": parse_yaml_list_value(text, "sequence"),
            }
        )
    return notes


def project_workflow_lines(root: Path, repo: str) -> list[str]:
    lines = []
    project_path = project_note_for_repo(root, repo)
    if not project_path:
        return []
    needle = obsidian_link(root, project_path)
    for workflow in workflow_notes(root):
        text = Path(workflow["path"]).read_text(encoding="utf-8")
        if needle in text or obsidian_link(root, project_path, str(workflow.get("title", ""))) in text:
            lines.append(f"- {obsidian_link(root, Path(workflow['path']), str(workflow['title']))}")
    return lines[:10]


def render_project_blocks(root: Path, path: Path, day: str) -> None:
    text = path.read_text(encoding="utf-8")
    repo = parse_frontmatter_value(text, "repo")
    if not repo:
        return
    daily_days = recent_daily_repo_days(root, repo, day, days=14)
    active_work = [
        f"- Seen in {len(daily_days)} daily repo blocks in the last 14 days."
        if daily_days
        else "- No daily repo appearances in the last 14 days."
    ]
    commands = project_command_lines(root, repo, day)
    loops = project_open_loop_lines(root, repo)
    workflows = project_workflow_lines(root, repo)
    text = replace_block(text, "observer", "active-work", "\n".join(active_work))
    text = replace_block(text, "observer", "commands", "\n".join(commands) or "- No recent commands.")
    text = replace_block(text, "observer", "open-loops", "\n".join(loops) or "- No accepted or surfaced open loops.")
    text = replace_block(text, "observer", "workflows", "\n".join(workflows) or "- No related workflows.")
    path.write_text(text, encoding="utf-8")


def update_project_statuses(root: Path, day: str) -> None:
    anchor = date.fromisoformat(day)
    for note in project_notes(root):
        path = Path(note["path"])
        repo = str(note.get("repo", ""))
        if not repo:
            continue
        text = path.read_text(encoding="utf-8")
        if parse_frontmatter_value(text, "status") == "archived":
            continue
        seen_days = recent_daily_repo_days(root, repo, day, days=120)
        latest_seen = date.fromisoformat(seen_days[0]) if seen_days else None
        status = "active"
        if latest_seen is None or latest_seen < anchor - timedelta(days=30):
            status = "dormant"
        text = set_frontmatter_value(text, "status", status)
        path.write_text(text, encoding="utf-8")


def render_project_index(root: Path, day: str, events: list[dict[str, object]]) -> None:
    index = root / "maps" / "project-index.md"
    write_if_missing(index, PROJECT_INDEX_TEMPLATE)
    update_project_statuses(root, day)
    groups = {"active": [], "dormant": [], "archived": []}
    for note in project_notes(root):
        status = str(note.get("status", "active"))
        line = f"- {obsidian_link(root, Path(note['path']), str(note['title']))}"
        groups.setdefault(status, []).append(line)
    text = index.read_text(encoding="utf-8")
    text = replace_block(text, "observer", "active-projects", "\n".join(groups.get("active", [])) or "- No active projects.")
    text = replace_block(text, "observer", "dormant-projects", "\n".join(groups.get("dormant", [])) or "- No dormant projects.")
    text = replace_block(text, "observer", "archived-projects", "\n".join(groups.get("archived", [])) or "- No archived projects.")
    text = replace_block(text, "observer", "project-candidates", render_project_candidates(root, day, events))
    index.write_text(text, encoding="utf-8")


def command_pattern_part(root: Path, key: str) -> str:
    path = root / "wiki" / "commands" / f"{key}.md"
    if path.exists():
        return command_link(key)
    return f"`{key}`"


def parse_event_ts(event: dict[str, object]) -> datetime | None:
    try:
        return datetime.fromisoformat(str(event.get("ts", "")))
    except ValueError:
        return None


def event_repo_path(event: dict[str, object]) -> str:
    cwd = str(event.get("cwd", ""))
    repo = repo_root_for_cwd(cwd)
    return repo.as_posix() if (repo / ".git").exists() else ""


def daily_session_sequences(root: Path, day: str) -> list[dict[str, object]]:
    events = [
        (event, event_repo_path(event))
        for event in load_events(root, day)
        if is_meaningful_event(event) and parse_event_ts(event) is not None and event_repo_path(event)
    ]
    by_repo: dict[str, list[dict[str, object]]] = defaultdict(list)
    for event, repo in events:
        by_repo[repo].append(event)
    sessions = []
    for repo, group in by_repo.items():
        group = sorted(group, key=lambda item: str(item.get("ts", "")))
        current: list[dict[str, object]] = []
        previous_ts: datetime | None = None
        for event in group:
            ts = parse_event_ts(event)
            if previous_ts and ts and ts - previous_ts > timedelta(minutes=30):
                if len(current) >= 3:
                    sessions.append({"repo": repo, "day": day, "sequence": [str(item.get("command_key", "")) for item in current]})
                current = []
            current.append(event)
            previous_ts = ts
        if len(current) >= 3:
            sessions.append({"repo": repo, "day": day, "sequence": [str(item.get("command_key", "")) for item in current]})
    return sessions


def workflow_slug(sequence: list[str]) -> str:
    base = slugify("-".join(sequence))
    if len(base) <= 80:
        return base
    digest = hashlib.sha1("-".join(sequence).encode("utf-8")).hexdigest()[:8]
    return f"{'-'.join(base.split('-')[:6])}-{digest}"


def workflow_candidates(root: Path, day: str, days: int = 30) -> list[dict[str, object]]:
    anchor = date.fromisoformat(day)
    seen: dict[tuple[str, tuple[str, ...]], set[str]] = defaultdict(set)
    for offset in range(days):
        current = anchor - timedelta(days=offset)
        for session in daily_session_sequences(root, current.isoformat()):
            sequence = tuple(str(item) for item in session["sequence"])
            seen[(str(session["repo"]), sequence)].add(current.isoformat())
    existing = {tuple(note.get("sequence", [])) for note in workflow_notes(root)}
    candidates = []
    for (repo, sequence), day_set in seen.items():
        if len(day_set) >= 3 and sequence not in existing:
            candidates.append(
                {
                    "repo": repo,
                    "sequence": list(sequence),
                    "days": sorted(day_set, reverse=True),
                    "slug": workflow_slug(list(sequence)),
                }
            )
    return sorted(candidates, key=lambda item: (-len(item["days"]), item["slug"]))


def render_workflow_candidates(root: Path, day: str) -> str:
    candidates = workflow_candidates(root, day)
    if not candidates:
        return "- No workflow candidates."
    lines = []
    for candidate in candidates[:10]:
        pattern = " -> ".join(str(item) for item in candidate["sequence"])
        lines.append(
            f"- [candidate] `{pattern}` in `{candidate['repo']}` - {len(candidate['days'])} days."
        )
    return "\n".join(lines)


def render_workflow_index(root: Path, day: str) -> None:
    index = root / "maps" / "workflow-index.md"
    write_if_missing(index, WORKFLOW_INDEX_TEMPLATE)
    active = []
    for workflow in workflow_notes(root):
        active.append(f"- {obsidian_link(root, Path(workflow['path']), str(workflow['title']))}")
    text = index.read_text(encoding="utf-8")
    text = replace_block(text, "observer", "active-workflows", "\n".join(active) or "- No workflow notes.")
    text = replace_block(text, "observer", "candidate-workflows", render_workflow_candidates(root, day))
    index.write_text(text, encoding="utf-8")


def observed_days_for_sequence(root: Path, repo: str, sequence: list[str], day: str, days: int = 60) -> list[str]:
    anchor = date.fromisoformat(day)
    found = []
    target = tuple(sequence)
    for offset in range(days):
        current = anchor - timedelta(days=offset)
        for session in daily_session_sequences(root, current.isoformat()):
            if str(session["repo"]) == repo and tuple(session["sequence"]) == target:
                found.append(current.isoformat())
                break
    return sorted(found, reverse=True)


def workflow_note_template(
    root: Path, *, day: str, sequence: list[str], repo: str, title: str
) -> str:
    repo_link = ""
    project = project_note_for_repo(root, repo)
    if project:
        repo_link = f'  - "{obsidian_link(root, project, project.stem)}"'
    else:
        repo_link = f'  - "{obsidian_link(root, root / "daily" / f"{day}.md")}"'
    sequence_lines = "\n".join(f"  - {item}" for item in sequence)
    pattern = " -> ".join(command_pattern_part(root, item) for item in sequence)
    return f"""---
type: workflow
status: draft
created: {day}
updated: {day}
repo: {repo}
sequence:
{sequence_lines}
related:
{repo_link}
---

# {title}

## Pattern
{pattern}

## Why It Matters
This repeated command sequence is worth naming so it can be reused deliberately.

## Observed In
<!-- observer:start observed-in -->
<!-- observer:end observed-in -->

## Related Commands
<!-- observer:start commands -->
<!-- observer:end commands -->

## Notes
<!-- user:start notes -->
<!-- user:end notes -->
"""


def sync_workflow_note(root: Path, path: Path, day: str) -> None:
    text = path.read_text(encoding="utf-8")
    repo = parse_frontmatter_value(text, "repo")
    sequence = parse_yaml_list_value(text, "sequence")
    observed = observed_days_for_sequence(root, repo, sequence, day) if repo and sequence else []
    observed_lines = [f"- [[daily/{item}|{item}]]" for item in observed[:10]]
    command_lines = [f"- {command_pattern_part(root, item)}" for item in sequence[:10]]
    text = replace_block(text, "observer", "observed-in", "\n".join(observed_lines) or "- No matching daily sessions found.")
    text = replace_block(text, "observer", "commands", "\n".join(command_lines) or "- No related commands.")
    path.write_text(text, encoding="utf-8")


def markdown_title(path: Path) -> str:
    text = path.read_text(encoding="utf-8", errors="ignore")
    title_match = re.search(r"(?m)^# (.+)$", text)
    if title_match:
        return title_match.group(1).strip()
    fm_title = parse_frontmatter_value(text, "title")
    return fm_title or path.stem.replace("-", " ").title()


def markdown_notes(root: Path, rels: list[str]) -> list[Path]:
    notes: list[Path] = []
    for rel in rels:
        base = root / rel
        if base.is_file() and base.suffix == ".md":
            notes.append(base)
        elif base.exists():
            notes.extend(sorted(base.rglob("*.md")))
    return notes


def raw_web_clip_paths(root: Path, include_archive: bool = False) -> list[Path]:
    clips = []
    for path in sorted((root / "raw" / "web-clips").rglob("*.md")):
        try:
            rel = path.relative_to(root / "raw" / "web-clips")
        except ValueError:
            continue
        if not include_archive and rel.parts and rel.parts[0] == "archive":
            continue
        clips.append(path)
    return clips


def note_links(text: str) -> list[str]:
    return [match.strip().removesuffix(".md") for match in OBSIDIAN_LINK_RE.findall(text)]


def incoming_raw_clip_links(root: Path) -> dict[str, list[Path]]:
    incoming: dict[str, list[Path]] = defaultdict(list)
    scan_paths = markdown_notes(root, ["daily", "wiki/projects", "wiki/workflows", "wiki/concepts"])
    for note in scan_paths:
        text = note.read_text(encoding="utf-8", errors="ignore")
        for target in note_links(text):
            if target.startswith("raw/web-clips/"):
                incoming[target].append(note)
    return incoming


def clip_rel_no_ext(root: Path, path: Path) -> str:
    rel = obsidian_path(root, path)
    return rel[:-3] if rel.endswith(".md") else rel


def has_promote_source(text: str) -> bool:
    if PROMOTE_SOURCE_RE.search(text):
        return True
    return "promote/source" in parse_yaml_list_value(text, "tags")


def inline_concept_tags(text: str) -> list[str]:
    return [f"concept/{slugify(match)}" for match in INLINE_CONCEPT_TAG_RE.findall(text)]


def concept_tags_in_note(text: str) -> set[str]:
    tags = {item for item in parse_yaml_list_value(text, "tags") if item.startswith("concept/")}
    tags.update(inline_concept_tags(text))
    return tags


def clip_day(path: Path, text: str) -> str:
    clipped = parse_frontmatter_value(text, "clipped")
    if re.match(r"^\d{4}-\d{2}-\d{2}$", clipped):
        return clipped
    match = re.search(r"(\d{4}-\d{2}-\d{2})", path.name)
    if match:
        return match.group(1)
    return datetime.fromtimestamp(path.stat().st_mtime).date().isoformat()


def source_url_from_clip(text: str) -> str:
    url = parse_frontmatter_value(text, "url")
    if url:
        return url
    match = re.search(r"(?mi)^-\s*URL:\s*(\S+)", text)
    return match.group(1).strip() if match else ""


def web_clip_candidates(root: Path, review_recent: bool = False) -> list[dict[str, object]]:
    incoming = incoming_raw_clip_links(root)
    candidates = []
    for path in raw_web_clip_paths(root):
        text = path.read_text(encoding="utf-8", errors="ignore")
        rel = clip_rel_no_ext(root, path)
        reasons = []
        if has_promote_source(text):
            reasons.append("#promote/source")
        if rel in incoming:
            reasons.append("incoming raw link")
        if review_recent:
            reasons.append("recent review request")
        if reasons:
            candidates.append(
                {
                    "path": path,
                    "title": markdown_title(path),
                    "url": source_url_from_clip(text),
                    "day": clip_day(path, text),
                    "reasons": reasons,
                    "incoming": incoming.get(rel, []),
                }
            )
    return sorted(candidates, key=lambda item: str(item["day"]), reverse=True)


def stale_web_clips(root: Path, day: str) -> list[dict[str, object]]:
    anchor = date.fromisoformat(day)
    incoming = incoming_raw_clip_links(root)
    stale = []
    for path in raw_web_clip_paths(root):
        text = path.read_text(encoding="utf-8", errors="ignore")
        rel = clip_rel_no_ext(root, path)
        try:
            clipped = date.fromisoformat(clip_day(path, text))
        except ValueError:
            continue
        if clipped > anchor - timedelta(days=30):
            continue
        if has_promote_source(text) or rel in incoming:
            continue
        stale.append({"path": path, "title": markdown_title(path), "day": clipped.isoformat()})
    return sorted(stale, key=lambda item: str(item["day"]))


def source_notes(root: Path) -> list[dict[str, object]]:
    notes = []
    for path in sorted((root / "wiki" / "sources").glob("*.md")):
        text = path.read_text(encoding="utf-8", errors="ignore")
        notes.append(
            {
                "path": path,
                "title": markdown_title(path),
                "updated": parse_frontmatter_value(text, "updated"),
                "source_url": parse_frontmatter_value(text, "source_url"),
                "source_clip": parse_frontmatter_value(text, "source_clip"),
            }
        )
    return sorted(notes, key=lambda item: str(item.get("updated", "")), reverse=True)


def source_note_for_clip(root: Path, clip_path: Path) -> Path | None:
    clip_link = obsidian_link(root, clip_path)
    for note in source_notes(root):
        if str(note.get("source_clip", "")) == clip_link:
            return Path(note["path"])
    return None


def concept_tag_counts(root: Path) -> Counter[str]:
    counts: Counter[str] = Counter()
    for path in markdown_notes(root, ["daily", "wiki/projects", "wiki/workflows", "wiki/concepts", "wiki/sources", "raw/web-clips"]):
        text = path.read_text(encoding="utf-8", errors="ignore")
        for tag in concept_tags_in_note(text):
            counts[tag] += 1
    return counts


def concept_note_exists(root: Path, tag: str) -> bool:
    slug = tag.split("/", 1)[1] if "/" in tag else tag
    return (root / "wiki" / "concepts" / f"{slugify(slug)}.md").exists()


def render_concept_tag_candidates(root: Path) -> str:
    lines = []
    for tag, count in sorted(concept_tag_counts(root).items()):
        if count >= 3 and not concept_note_exists(root, tag):
            lines.append(f"- [candidate] `#{tag}` appears in {count} notes.")
    return "\n".join(lines[:10]) if lines else "- No concept tag candidates."


def render_source_index(root: Path, day: str) -> None:
    index = root / "maps" / "source-index.md"
    write_if_missing(index, SOURCE_INDEX_TEMPLATE)
    recent = [
        f"- {obsidian_link(root, Path(note['path']), str(note['title']))}"
        for note in source_notes(root)[:10]
    ]
    candidates = []
    for candidate in web_clip_candidates(root)[:10]:
        reasons = ", ".join(str(item) for item in candidate["reasons"])
        candidates.append(
            f"- [candidate] {obsidian_link(root, Path(candidate['path']), str(candidate['title']))} - {reasons}."
        )
    stale = [
        f"- [stale] {obsidian_link(root, Path(item['path']), str(item['title']))} - clipped {item['day']}."
        for item in stale_web_clips(root, day)[:10]
    ]
    text = index.read_text(encoding="utf-8")
    text = replace_block(text, "observer", "recent-sources", "\n".join(recent) or "- No promoted sources.")
    text = replace_block(text, "observer", "source-candidates", "\n".join(candidates) or "- No source candidates.")
    text = replace_block(text, "observer", "stale-clips", "\n".join(stale) or "- No stale clips.")
    text = replace_block(text, "observer", "concept-tag-candidates", render_concept_tag_candidates(root))
    index.write_text(text, encoding="utf-8")


def source_note_template(
    root: Path,
    *,
    day: str,
    clip_path: Path,
    title: str,
    claims: list[str],
    details: str,
    supports: list[str],
    caveats: str,
) -> str:
    clip_text = clip_path.read_text(encoding="utf-8", errors="ignore")
    source_url = source_url_from_clip(clip_text)
    source_clip = obsidian_link(root, clip_path)
    related_lines = "\n".join(f'  - "{item}"' for item in supports) or f'  - "{source_clip}"'
    claim_lines = "\n".join(f"- {item}" for item in claims[:7]) or "- Claim summary pending."
    support_lines = "\n".join(f"- {item}" for item in supports) or f"- {source_clip}"
    return f"""---
type: source
status: draft
created: {day}
updated: {day}
source_url: {source_url}
source_clip: "{source_clip}"
related:
{related_lines}
---

# {title}

## Claim Summary
{claim_lines}

## Useful Details
{details or "Useful details pending."}

## Supports
{support_lines}

## Caveats
{caveats or "Caveats pending."}

## Citation
- Source: {source_url or source_clip}

## Notes
<!-- user:start notes -->
<!-- user:end notes -->
"""


def concept_note_template(day: str, title: str, related: list[str]) -> str:
    related_lines = "\n".join(f'  - "{item}"' for item in related) or '  - "[[maps/home|home]]"'
    shows = "\n".join(f"- {item}" for item in related) or "- [[maps/home|home]]"
    return f"""---
type: concept
status: draft
created: {day}
updated: {day}
related:
{related_lines}
---

# {title}

## Meaning
User-owned explanation.

## Sourced Claims
<!-- codex:start sourced-claims -->
<!-- codex:end sourced-claims -->

## Where It Shows Up
{shows}

## Notes
<!-- user:start notes -->
<!-- user:end notes -->
"""


def render_all_indexes(root: Path, day: str, events: list[dict[str, object]]) -> None:
    for path in sorted((root / "wiki" / "projects").glob("*.md")):
        render_project_blocks(root, path, day)
    for path in sorted((root / "wiki" / "workflows").glob("*.md")):
        sync_workflow_note(root, path, day)
    render_project_index(root, day, events)
    render_workflow_index(root, day)
    render_source_index(root, day)


def obsidian_path(root: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def obsidian_link(root: Path, path: Path, label: str | None = None) -> str:
    rel = obsidian_path(root, path)
    if rel.endswith(".md"):
        rel = rel[:-3]
    if label:
        return f"[[{rel}|{label}]]"
    return f"[[{rel}]]"


def normalize_input_path(root: Path, value: str) -> Path:
    raw = value.strip()
    if raw.startswith("[[") and raw.endswith("]]"):
        raw = raw[2:-2]
        raw = raw.split("|", 1)[0]
    if raw.endswith(".md"):
        candidate = Path(raw)
    else:
        candidate = Path(raw + ".md")
    if candidate.is_absolute():
        return candidate
    return root / candidate


def unique_path(path: Path) -> Path:
    if not path.exists():
        return path
    stem = path.stem
    suffix = path.suffix
    for index in range(2, 1000):
        candidate = path.with_name(f"{stem}-{index}{suffix}")
        if not candidate.exists():
            return candidate
    raise RuntimeError(f"Unable to find unique path for {path}")


def read_content(args: argparse.Namespace) -> str:
    if getattr(args, "content", None):
        return str(args.content)
    if not sys.stdin.isatty():
        return sys.stdin.read().rstrip("\n")
    return ""


def commands_block(text: str) -> str:
    return fenced_block(text, "observer", "commands")


def scan_recent_command_links(root: Path, day: str) -> Counter[str]:
    anchor = date.fromisoformat(day)
    counts: Counter[str] = Counter()
    for offset in range(14):
        current = anchor - timedelta(days=offset)
        path = root / "daily" / f"{current.isoformat()}.md"
        if not path.exists():
            continue
        block = commands_block(path.read_text(encoding="utf-8"))
        for key in set(COMMAND_LINK_RE.findall(block)):
            counts[key] += 1
    return counts


def detect_burst_candidates(events: list[dict[str, object]]) -> set[str]:
    by_key: dict[str, list[datetime]] = defaultdict(list)
    for event in events:
        if not is_meaningful_event(event):
            continue
        key = str(event.get("command_key", ""))
        try:
            ts = datetime.fromisoformat(str(event.get("ts", "")))
        except ValueError:
            continue
        by_key[key].append(ts)

    bursts: set[str] = set()
    window = timedelta(hours=4)
    for key, timestamps in by_key.items():
        timestamps = sorted(timestamps)
        start = 0
        for end, value in enumerate(timestamps):
            while value - timestamps[start] > window:
                start += 1
            if end - start + 1 >= 5:
                bursts.add(key)
                break
    return bursts


def render_promotion_candidates(
    root: Path, day: str, summaries: list[CommandSummary], events: list[dict[str, object]]
) -> str:
    existing_commands = {path.stem for path in (root / "wiki" / "commands").glob("*.md")}
    recent_counts = scan_recent_command_links(root, day)
    burst_keys = detect_burst_candidates(events)
    current_keys = [summary.key for summary in summaries]

    candidates: list[str] = []
    for key in current_keys:
        if key in existing_commands:
            continue
        if recent_counts[key] >= 3:
            candidates.append(
                f"- [candidate] {command_link(key)} appeared in {recent_counts[key]} daily notes within 14 days."
            )
        elif key in burst_keys:
            candidates.append(
                f"- [candidate] {command_link(key)} appeared 5+ times in a 4-hour window today."
            )
        if len(candidates) >= 3:
            break

    if not candidates:
        return "- No command promotion candidates."
    return "\n".join(candidates)


def cmd_digest(args: argparse.Namespace) -> int:
    root = vault_root()
    day = parse_day(args.date)
    ensure_vault(root)
    daily = ensure_daily(root, day)
    events = load_events(root, day)
    summaries = summarize_commands(events)

    text = daily.read_text(encoding="utf-8")
    text = replace_block(text, "observer", "commands", render_commands_block(summaries))
    text = replace_block(
        text, "observer", "significant-events", render_significant_events(events)
    )
    text = replace_block(text, "observer", "repos", render_repos_block(events))
    daily.write_text(text, encoding="utf-8")

    text = daily.read_text(encoding="utf-8")
    detect_open_loop_events(root, day, events, text)
    detect_exploration_events(root, day, events, text)
    text = replace_block(text, "observer", "open-loops", render_open_loops_block(root, day))
    text = replace_block(text, "observer", "explorations", render_explorations_block(root, day))
    daily.write_text(text, encoding="utf-8")

    # Promotion candidates are counted after the command block has been written.
    text = daily.read_text(encoding="utf-8")
    text = replace_block(
        text,
        "observer",
        "promotion-candidates",
        render_promotion_candidates(root, day, summaries, events),
    )
    daily.write_text(text, encoding="utf-8")
    render_all_indexes(root, day, events)
    print(daily)
    return 0


def cmd_startday(args: argparse.Namespace) -> int:
    root = vault_root()
    day = parse_day(args.date)
    ensure_vault(root)
    daily = ensure_daily(root, day)
    for note in selected_surface_loops(root, day):
        key = str(note.get("loop_key", ""))
        if not key:
            continue
        filename_key, _events = raw_events_for_loop(root, key)
        append_open_loop_event(
            root,
            {
                "schema": 1,
                "ts": f"{day}T00:00:00",
                "source_ts": f"{day}:surfaced:{key}",
                "loop_key": key,
                "filename_key": filename_key,
                "event": "surfaced",
                "trigger_type": "startday-surface",
                "subject": Path(filename_key).stem,
                "cwd": "",
                "evidence": "surfaced in startday",
            },
        )

    text = daily.read_text(encoding="utf-8")
    text = replace_block(text, "observer", "open-loops", render_open_loops_block(root, day))
    text = replace_block(text, "observer", "explorations", render_explorations_block(root, day))
    daily.write_text(text, encoding="utf-8")
    render_all_indexes(root, day, load_events(root, day))
    print(daily)
    return 0


def cmd_open_loop_accept(args: argparse.Namespace) -> int:
    root = vault_root()
    day = parse_day(args.date)
    ensure_vault(root)
    filename_key, events = raw_events_for_loop(root, args.key)
    if not events:
        raise SystemExit(f"No raw open-loop events found for {args.key}")
    path = open_loop_note_path(root, filename_key)
    if path.exists():
        text = path.read_text(encoding="utf-8")
        text = set_frontmatter_value(text, "status", "accepted")
        path.write_text(text, encoding="utf-8")
        sync_open_loop_note(root, path, day, events)
    else:
        path.write_text(
            open_loop_note_template(root, day=day, filename_key=filename_key, events=events),
            encoding="utf-8",
        )
    print(path)
    return 0


def cmd_open_loop_resolve(args: argparse.Namespace) -> int:
    root = vault_root()
    day = parse_day(args.date)
    ensure_vault(root)
    filename_key = loop_key_to_filename_key(args.key)
    path = open_loop_note_path(root, filename_key)
    if not path.exists():
        filename_key, events = raw_events_for_loop(root, args.key)
        path = open_loop_note_path(root, filename_key)
        if not path.exists() and events:
            path.write_text(
                open_loop_note_template(root, day=day, filename_key=filename_key, events=events),
                encoding="utf-8",
            )
    if not path.exists():
        raise SystemExit(f"Open-loop note not found: {args.key}")
    text = path.read_text(encoding="utf-8")
    text = set_frontmatter_value(text, "status", "resolved")
    text = set_frontmatter_value(text, "updated", day)
    evidence = args.evidence or f"Resolved on {day}."
    text = replace_block(text, "codex", "resolution", evidence)
    path.write_text(text, encoding="utf-8")
    print(path)
    return 0


def cmd_open_loop_archive(args: argparse.Namespace) -> int:
    root = vault_root()
    day = parse_day(args.date)
    ensure_vault(root)
    filename_key = loop_key_to_filename_key(args.key)
    path = open_loop_note_path(root, filename_key)
    if not path.exists():
        filename_key, _events = raw_events_for_loop(root, args.key)
        path = open_loop_note_path(root, filename_key)
    if not path.exists():
        raise SystemExit(f"Open-loop note not found: {args.key}")
    text = path.read_text(encoding="utf-8")
    text = set_frontmatter_value(text, "status", "archived")
    text = set_frontmatter_value(text, "updated", day)
    path.write_text(text, encoding="utf-8")
    print(path)
    return 0


def cmd_exploration_action(args: argparse.Namespace) -> int:
    root = vault_root()
    day = parse_day(args.date)
    ensure_vault(root)
    key = args.key
    filename_key = key.replace("::", "--")
    path = exploration_raw_path(root, filename_key)
    if not path.exists():
        for candidate in sorted((root / "raw" / "explorations").glob("*.jsonl")):
            events = load_jsonl(candidate)
            if any(str(event.get("exploration_key", "")) == key for event in events):
                path = candidate
                break
    events = load_jsonl(path)
    if not events:
        raise SystemExit(f"Exploration not found: {args.key}")
    latest = latest_event(events)
    payload = {
        "schema": 1,
        "ts": f"{day}T00:00:00",
        "exploration_key": str(latest.get("exploration_key", key)),
        "filename_key": path.stem,
        "event": args.action,
        "trigger_type": "codex-review",
        "subject": str(latest.get("subject", "")),
        "cwd": str(latest.get("cwd", "")),
        "ttl_hours": 24,
        "evidence": args.evidence or args.action,
    }
    if args.action == "extend":
        payload["ttl_hours"] = 48
    append_exploration_event(root, payload)
    if args.action == "convert":
        subject = str(latest.get("subject", "exploration"))
        converted = {
            "schema": 1,
            "ts": f"{day}T00:00:00",
            "source_ts": f"{day}:exploration-conversion:{path.stem}",
            "loop_key": loop_key("daily", "exploration-conversion", subject),
            "filename_key": loop_filename_key("daily", "exploration-conversion", subject),
            "event": "candidate",
            "trigger_type": "exploration-conversion",
            "subject": slugify(subject),
            "cwd": str(latest.get("cwd", "")),
            "evidence": args.evidence or str(latest.get("evidence", "")),
        }
        append_open_loop_event(root, converted)
    print(path)
    return 0


def project_note_template(
    root: Path, *, day: str, repo: Path, title: str, description: str
) -> str:
    command_lines = "- No recent commands."
    return f"""---
type: project
status: active
created: {day}
updated: {day}
repo: {repo.as_posix()}
related:
  - "[[daily/{day}]]"
---

# {title}

## What It Is
{description or "Short description pending."}

## Active Work
<!-- observer:start active-work -->
<!-- observer:end active-work -->

## Commands
<!-- observer:start commands -->
{command_lines}
<!-- observer:end commands -->

## Open Loops
<!-- observer:start open-loops -->
<!-- observer:end open-loops -->

## Workflows
<!-- observer:start workflows -->
<!-- observer:end workflows -->

## Notes
<!-- user:start notes -->
<!-- user:end notes -->
"""


def cmd_project_note(args: argparse.Namespace) -> int:
    root = vault_root()
    day = parse_day(args.date)
    ensure_vault(root)
    repo = repo_root_for_cwd(args.repo).resolve()
    path = project_note_path_for_repo(root, repo)
    title = args.title or repo.name
    if path.exists() and not args.update:
        raise SystemExit(f"Project note already exists: {path}. Use --update to refresh observer blocks.")
    if not path.exists():
        path.write_text(
            project_note_template(
                root,
                day=day,
                repo=repo,
                title=title,
                description=args.description or "",
            ),
            encoding="utf-8",
        )
    else:
        text = path.read_text(encoding="utf-8")
        text = set_frontmatter_value(text, "updated", day)
        text = set_frontmatter_value(text, "status", "active")
        path.write_text(text, encoding="utf-8")
    render_project_blocks(root, path, day)
    render_project_index(root, day, load_events(root, day))
    print(path)
    return 0


def split_sequence(value: str) -> list[str]:
    parts = [slugify(item.strip()) for item in re.split(r"\s*(?:,|->)\s*", value) if item.strip()]
    if len(parts) < 3:
        raise SystemExit("Workflow sequence must contain at least 3 command keys.")
    return parts


def cmd_workflow_note(args: argparse.Namespace) -> int:
    root = vault_root()
    day = parse_day(args.date)
    ensure_vault(root)
    sequence = split_sequence(args.sequence)
    repo = repo_root_for_cwd(args.repo).resolve().as_posix() if args.repo else ""
    slug = args.slug or workflow_slug(sequence)
    path = root / "wiki" / "workflows" / f"{slug}.md"
    title = args.title or " -> ".join(sequence)
    if path.exists() and not args.update:
        raise SystemExit(f"Workflow note already exists: {path}. Use --update to refresh observer blocks.")
    if not path.exists():
        path.write_text(
            workflow_note_template(root, day=day, sequence=sequence, repo=repo, title=title),
            encoding="utf-8",
        )
    else:
        text = path.read_text(encoding="utf-8")
        text = set_frontmatter_value(text, "updated", day)
        path.write_text(text, encoding="utf-8")
    sync_workflow_note(root, path, day)
    render_workflow_index(root, day)
    print(path)
    return 0


def cmd_concept_note(args: argparse.Namespace) -> int:
    root = vault_root()
    day = parse_day(args.date)
    ensure_vault(root)
    title = args.title.strip()
    slug = slugify(args.slug or title)
    path = root / "wiki" / "concepts" / f"{slug}.md"
    related = args.related or []
    if not related:
        raise SystemExit("Concept notes require at least one --related link in V2/V3.")
    if path.exists() and not args.update:
        raise SystemExit(f"Concept note already exists: {path}. Use --update to modify codex blocks.")
    if not path.exists():
        path.write_text(concept_note_template(day, title, related), encoding="utf-8")
    else:
        text = path.read_text(encoding="utf-8")
        text = set_frontmatter_value(text, "updated", day)
        if args.sourced_claim:
            existing = fenced_block_body(text, "codex", "sourced-claims")
            lines = [line for line in existing.splitlines() if line.strip()]
            for claim in args.sourced_claim:
                line = f"- {claim}"
                if line not in lines:
                    lines.append(line)
            if len(lines) > 5:
                print(f"[observer] sourced-claims capped at 5; {len(lines) - 5} older claim(s) dropped.", file=sys.stderr)
            text = replace_block(text, "codex", "sourced-claims", "\n".join(lines[-5:]))
        path.write_text(text, encoding="utf-8")
    render_source_index(root, day)
    print(path)
    return 0


def cmd_source_note(args: argparse.Namespace) -> int:
    root = vault_root()
    day = parse_day(args.date)
    ensure_vault(root)
    clip_path = normalize_input_path(root, args.clip)
    if not clip_path.exists():
        raise SystemExit(f"Raw clip not found: {clip_path}")
    existing_source = source_note_for_clip(root, clip_path)
    if existing_source:
        raise SystemExit(f"Source note already exists for clip: {existing_source}")
    clip_title = markdown_title(clip_path)
    clip_text = clip_path.read_text(encoding="utf-8", errors="ignore")
    slug_base = slugify(args.slug or clip_path.stem)
    path = unique_path(root / "wiki" / "sources" / f"{slug_base}.md")
    title = args.title or clip_title
    claims = args.claim or []
    if not claims:
        raw_match = re.search(r"(?ms)^## Highlights\n(.+?)(?:\n^## |\Z)", clip_text)
        if raw_match:
            claims = [line.lstrip("- ").strip() for line in raw_match.group(1).splitlines() if line.strip()][:7]
    path.write_text(
        source_note_template(
            root,
            day=day,
            clip_path=clip_path,
            title=title,
            claims=claims,
            details=args.details or "",
            supports=args.supports or [],
            caveats=args.caveats or "",
        ),
        encoding="utf-8",
    )
    render_source_index(root, day)
    print(path)
    return 0


def cmd_source_archive(args: argparse.Namespace) -> int:
    root = vault_root()
    day = parse_day(args.date)
    ensure_vault(root)
    clip_path = normalize_input_path(root, args.clip)
    if not clip_path.exists():
        raise SystemExit(f"Raw clip not found: {clip_path}")
    archive_root = root / "raw" / "web-clips" / "archive"
    archive_root.mkdir(parents=True, exist_ok=True)
    target = unique_path(archive_root / clip_path.name)
    clip_path.rename(target)
    render_source_index(root, day)
    print(target)
    return 0


def cmd_source_index(args: argparse.Namespace) -> int:
    root = vault_root()
    day = parse_day(args.date)
    ensure_vault(root)
    render_source_index(root, day)
    print(root / "maps" / "source-index.md")
    return 0


def graph_broken_links(root: Path) -> list[str]:
    notes = markdown_notes(root, ["daily", "maps", "wiki", "raw/web-clips"])
    existing = {obsidian_path(root, path).removesuffix(".md") for path in notes}
    issues = []
    for note in notes:
        text = note.read_text(encoding="utf-8", errors="ignore")
        for target in note_links(text):
            if target in existing:
                continue
            if (root / f"{target}.md").exists():
                continue
            issues.append(f"- {obsidian_link(root, note)} links to missing `[[{target}]]`")
    return issues


def graph_orphans(root: Path, day: str) -> list[str]:
    notes = markdown_notes(root, ["wiki"])
    incoming: Counter[str] = Counter()
    for note in markdown_notes(root, ["daily", "maps", "wiki"]):
        text = note.read_text(encoding="utf-8", errors="ignore")
        for target in note_links(text):
            incoming[target] += 1
    anchor = date.fromisoformat(day)
    issues = []
    for note in notes:
        rel = obsidian_path(root, note).removesuffix(".md")
        if incoming[rel] > 0:
            continue
        text = note.read_text(encoding="utf-8", errors="ignore")
        created = parse_frontmatter_value(text, "created")
        try:
            if date.fromisoformat(created) >= anchor - timedelta(days=7):
                continue
        except ValueError:
            pass
        issues.append(f"- {obsidian_link(root, note)} has no incoming links.")
    return issues


def graph_stale_projects(root: Path, day: str) -> list[str]:
    update_project_statuses(root, day)
    issues = []
    anchor = date.fromisoformat(day)
    for note in project_notes(root):
        status = str(note.get("status", ""))
        updated = str(note.get("updated", ""))
        stale = status == "dormant"
        try:
            stale = stale or date.fromisoformat(updated) < anchor - timedelta(days=30)
        except ValueError:
            pass
        if stale:
            issues.append(f"- {obsidian_link(root, Path(note['path']), str(note['title']))} is stale or dormant.")
    return issues


def graph_source_orphans(root: Path) -> list[str]:
    issues = []
    for note in source_notes(root):
        path = Path(note["path"])
        text = path.read_text(encoding="utf-8", errors="ignore")
        supports = re.search(r"(?ms)^## Supports\n(.+?)(?:\n^## |\Z)", text)
        rel = obsidian_path(root, path).removesuffix(".md")
        has_incoming = any(rel in note_links(item.read_text(encoding="utf-8", errors="ignore")) for item in markdown_notes(root, ["daily", "wiki", "maps"]))
        if not supports or not supports.group(1).strip() or not has_incoming:
            issues.append(f"- {obsidian_link(root, path, str(note['title']))} has weak source graph links.")
    return issues


def render_project_graph_report(root: Path, name: str, day: str) -> str:
    target = slugify(name)
    for note in project_notes(root):
        path = Path(note["path"])
        if path.stem != target and slugify(str(note.get("title", ""))) != target:
            continue
        render_project_blocks(root, path, day)
        text = path.read_text(encoding="utf-8")
        return "\n".join(
            [
                f"# {note['title']}",
                f"- Note: {obsidian_link(root, path, str(note['title']))}",
                f"- Repo: `{note.get('repo', '')}`",
                "",
                "## Active Work",
                fenced_block_body(text, "observer", "active-work") or "- None",
                "",
                "## Commands",
                fenced_block_body(text, "observer", "commands") or "- None",
                "",
                "## Open Loops",
                fenced_block_body(text, "observer", "open-loops") or "- None",
                "",
                "## Workflows",
                fenced_block_body(text, "observer", "workflows") or "- None",
            ]
        )
    return f"- No project note found for `{name}`."


def render_workflow_graph_report(root: Path, name: str, day: str) -> str:
    target = slugify(name)
    for workflow in workflow_notes(root):
        path = Path(workflow["path"])
        if path.stem != target and slugify(str(workflow.get("title", ""))) != target:
            continue
        sync_workflow_note(root, path, day)
        text = path.read_text(encoding="utf-8")
        return "\n".join(
            [
                f"# {workflow['title']}",
                f"- Note: {obsidian_link(root, path, str(workflow['title']))}",
                f"- Sequence: `{', '.join(workflow.get('sequence', []))}`",
                "",
                "## Observed In",
                fenced_block_body(text, "observer", "observed-in") or "- None",
                "",
                "## Related Commands",
                fenced_block_body(text, "observer", "commands") or "- None",
            ]
        )
    return f"- No workflow note found for `{name}`."


def render_graph_report(root: Path, kind: str, day: str, name: str = "") -> str:
    events = load_events(root, day)
    if kind == "project":
        return render_project_graph_report(root, name, day)
    if kind == "workflow":
        return render_workflow_graph_report(root, name, day)
    if kind == "candidates":
        parts = [render_project_candidates(root, day, events), render_workflow_candidates(root, day)]
        return "\n".join(parts)
    if kind == "orphans":
        return "\n".join(graph_orphans(root, day)) or "- No orphan wiki notes."
    if kind == "broken-links":
        return "\n".join(graph_broken_links(root)) or "- No broken links."
    if kind == "stale":
        return "\n".join(graph_stale_projects(root, day)) or "- No stale projects."
    if kind == "sources":
        lines = [f"- {obsidian_link(root, Path(note['path']), str(note['title']))}" for note in source_notes(root)[:20]]
        return "\n".join(lines) or "- No source notes."
    if kind == "source-candidates":
        candidates = web_clip_candidates(root, review_recent=True)
        lines = [
            f"- {obsidian_link(root, Path(item['path']), str(item['title']))} - {', '.join(item['reasons'])}."
            for item in candidates[:20]
        ]
        return "\n".join(lines) or "- No source candidates."
    if kind == "stale-clips":
        lines = [
            f"- {obsidian_link(root, Path(item['path']), str(item['title']))} - clipped {item['day']}."
            for item in stale_web_clips(root, day)[:20]
        ]
        return "\n".join(lines) or "- No stale clips."
    if kind == "concept-tags":
        lines = [f"- `#{tag}` - {count} notes" for tag, count in sorted(concept_tag_counts(root).items())]
        return "\n".join(lines) or "- No concept tags."
    if kind == "source-orphans":
        return "\n".join(graph_source_orphans(root)) or "- No source orphans."
    raise SystemExit(f"Unknown graph report: {kind}")


def cmd_graph(args: argparse.Namespace) -> int:
    root = vault_root()
    day = parse_day(args.date)
    ensure_vault(root)
    if args.report in {"project", "workflow"} and not args.name:
        raise SystemExit(f"observer graph {args.report} requires --name")
    print(render_graph_report(root, args.report, day, args.name or ""))
    return 0


def raw_memory_template(
    *,
    day: str,
    title: str,
    source_kind: str,
    source_ref: str,
    related: list[str],
    trigger: str,
    content: str,
    candidate: str,
) -> str:
    related_lines = "\n".join(f'  - "{item}"' for item in related) or '  - "[[daily/{day}]]"'.format(day=day)
    candidate_line = f"- {candidate}" if candidate else f"- {slugify(title)}"
    return f"""---
type: memory-raw
status: raw
created: {day}
source_kind: {source_kind}
source_ref: {source_ref}
related:
{related_lines}
---

# Raw Memory: {title}

## Trigger
{trigger}

## Source Material
{content}

## Candidate Memory Notes
{candidate_line}

## Processing Notes
<!-- codex:start notes -->
<!-- codex:end notes -->
"""


def cmd_memory_capture(args: argparse.Namespace) -> int:
    root = vault_root()
    ensure_vault(root)
    day = parse_day(args.date)
    title = args.title.strip()
    slug = slugify(args.slug or title)
    content = read_content(args)
    if not content:
        raise SystemExit("memory-capture requires --content or stdin content.")

    related = args.related or [f"[[daily/{day}]]"]
    path = unique_path(root / "raw" / "memory" / f"{day}--{slug}.md")
    text = raw_memory_template(
        day=day,
        title=title,
        source_kind=args.source_kind,
        source_ref=args.source_ref or "",
        related=related,
        trigger=args.trigger or "Explicit memory capture.",
        content=content,
        candidate=args.candidate or slug,
    )
    path.write_text(text, encoding="utf-8")
    print(path)
    return 0


def memory_note_template(
    *,
    day: str,
    title: str,
    memory_type: str,
    raw_link: str,
    related: list[str],
    plain_english: str,
    why: str,
    understanding: str,
    links: list[str],
    open_questions: list[str],
) -> str:
    related_lines = "\n".join(f'  - "{item}"' for item in related) or f'  - "[[daily/{day}]]"'
    links_body = "\n".join(f"- {item}" for item in links) or f"- [[daily/{day}]]"
    questions_body = "\n".join(f"- {item}" for item in open_questions)
    return f"""---
type: memory
status: draft
memory_type: {memory_type}
created: {day}
updated: {day}
source_raw: "{raw_link}"
related:
{related_lines}
---

# {title}

## Plain English
<!-- codex:start plain-english -->
{plain_english}
<!-- codex:end plain-english -->

## Why Ryan Cares
<!-- codex:start why-ryan-cares -->
{why}
<!-- codex:end why-ryan-cares -->

## Current Understanding
<!-- codex:start current-understanding -->
{understanding}
<!-- codex:end current-understanding -->

## Links
<!-- codex:start links -->
{links_body}
<!-- codex:end links -->

## Open Questions
<!-- codex:start open-questions -->
{questions_body}
<!-- codex:end open-questions -->

## Notes
<!-- user:start notes -->
<!-- user:end notes -->
"""


def update_frontmatter_updated(text: str, day: str) -> str:
    if not text.startswith("---\n"):
        return text
    end = text.find("\n---", 4)
    if end == -1:
        return text
    frontmatter = text[:end]
    body = text[end:]
    if re.search(r"(?m)^updated:", frontmatter):
        frontmatter = re.sub(r"(?m)^updated:.*$", f"updated: {day}", frontmatter)
    else:
        frontmatter += f"\nupdated: {day}"
    return frontmatter + body


def update_memory_note(
    path: Path,
    *,
    day: str,
    plain_english: str,
    why: str,
    understanding: str,
    links: list[str],
    open_questions: list[str],
) -> None:
    text = path.read_text(encoding="utf-8")
    text = update_frontmatter_updated(text, day)
    if plain_english:
        text = replace_block(text, "codex", "plain-english", plain_english)
    if why:
        text = replace_block(text, "codex", "why-ryan-cares", why)
    if understanding:
        text = replace_block(text, "codex", "current-understanding", understanding)
    if links:
        text = replace_block(text, "codex", "links", "\n".join(f"- {item}" for item in links))
    if open_questions:
        text = replace_block(
            text, "codex", "open-questions", "\n".join(f"- {item}" for item in open_questions)
        )
    path.write_text(text, encoding="utf-8")


def load_raw_memory(path: Path) -> str:
    if not path.exists():
        raise SystemExit(f"Raw memory file not found: {path}")
    text = path.read_text(encoding="utf-8")
    match = re.search(r"(?ms)^## Source Material\n(.*?)(?:\n^## |\Z)", text)
    if match:
        return match.group(1).strip()
    return text.strip()


def update_daily_memory(root: Path, day: str, action: str, note_path: Path, title: str) -> None:
    daily = ensure_daily(root, day)
    text = daily.read_text(encoding="utf-8")
    block = fenced_block(text, "codex", "memory")
    existing_body = ""
    if block:
        existing_body = re.sub(
            r"(?ms)^<!-- codex:start memory -->\n?|\n?<!-- codex:end memory -->$",
            "",
            block,
        ).strip()
    line = f"- {action} {obsidian_link(root, note_path, title)}"
    if line in existing_body.splitlines():
        body = existing_body
    else:
        body = "\n".join(part for part in [existing_body, line] if part)
    text = replace_block(text, "codex", "memory", body)
    daily.write_text(text, encoding="utf-8")


def render_memory_index(root: Path) -> None:
    index = root / "maps" / "memory-index.md"
    write_if_missing(index, MEMORY_INDEX_TEMPLATE)
    notes = sorted(
        (root / "wiki" / "memory").glob("*.md"),
        key=lambda item: item.stat().st_mtime,
        reverse=True,
    )
    recent_lines = []
    reentry_lines = []
    questions: list[str] = []
    for note in notes[:10]:
        text = note.read_text(encoding="utf-8")
        title = text.splitlines()[0].lstrip("# ").strip() if text.startswith("# ") else note.stem
        title_match = re.search(r"(?m)^# (.+)$", text)
        if title_match:
            title = title_match.group(1).strip()
        recent_lines.append(f"- {obsidian_link(root, note, title)}")
        memory_type = parse_frontmatter_value(text, "memory_type")
        if memory_type in {"mental-model", "explanation", "operating-rule"}:
            reentry_lines.append(f"- {obsidian_link(root, note, title)}")
        question_block = fenced_block(text, "codex", "open-questions")
        for line in question_block.splitlines():
            stripped = line.strip()
            if stripped.startswith("- "):
                questions.append(f"- {obsidian_link(root, note, title)}: {stripped[2:]}")

    index_text = index.read_text(encoding="utf-8")
    index_text = replace_block(
        index_text,
        "codex",
        "recent-memory",
        "\n".join(recent_lines[:10]) or "- No memory notes yet.",
    )
    index_text = replace_block(
        index_text,
        "codex",
        "reentry-notes",
        "\n".join(reentry_lines[:10]) or "- No reentry notes yet.",
    )
    index_text = replace_block(
        index_text,
        "codex",
        "open-questions",
        "\n".join(questions[:10]) or "- No open memory questions.",
    )
    index.write_text(index_text, encoding="utf-8")


def cmd_memory_note(args: argparse.Namespace) -> int:
    root = vault_root()
    ensure_vault(root)
    day = parse_day(args.date)
    title = args.title.strip()
    slug = slugify(args.slug or title)
    path = root / "wiki" / "memory" / f"{slug}.md"
    raw_path = normalize_input_path(root, args.raw) if args.raw else None
    raw_link = obsidian_link(root, raw_path) if raw_path else ""
    raw_content = load_raw_memory(raw_path) if raw_path else ""
    related = args.related or [f"[[daily/{day}]]"]
    links = args.link or []
    plain_english = args.plain_english or ""
    why = args.why or ""
    understanding = args.understanding or raw_content
    open_questions = args.open_question or []

    if path.exists():
        if not args.update:
            raise SystemExit(f"Memory note already exists: {path}. Use --update to modify codex blocks.")
        update_memory_note(
            path,
            day=day,
            plain_english=plain_english,
            why=why,
            understanding=understanding,
            links=links,
            open_questions=open_questions,
        )
        action = "Updated"
    else:
        text = memory_note_template(
            day=day,
            title=title,
            memory_type=args.memory_type,
            raw_link=raw_link,
            related=related,
            plain_english=plain_english or "Draft explanation pending.",
            why=why or "This should help Ryan recover context later.",
            understanding=understanding or "Draft understanding pending.",
            links=links or [f"[[daily/{day}]]"],
            open_questions=open_questions,
        )
        path.write_text(text, encoding="utf-8")
        action = "Created"

    update_daily_memory(root, day, action, path, title)
    render_memory_index(root)
    print(path)
    return 0


def cmd_memory_index(_args: argparse.Namespace) -> int:
    root = vault_root()
    ensure_vault(root)
    render_memory_index(root)
    print(root / "maps" / "memory-index.md")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Dotfiles Obsidian observer")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("init-vault").set_defaults(func=cmd_init_vault)

    ensure_daily_parser = sub.add_parser("ensure-daily")
    ensure_daily_parser.add_argument("date", nargs="?")
    ensure_daily_parser.set_defaults(func=cmd_ensure_daily)

    digest_parser = sub.add_parser("digest")
    digest_parser.add_argument("date", nargs="?")
    digest_parser.set_defaults(func=cmd_digest)

    daily_parser = sub.add_parser("daily")
    daily_parser.add_argument("date", nargs="?")
    daily_parser.set_defaults(func=cmd_digest)

    startday_parser = sub.add_parser("startday")
    startday_parser.add_argument("date", nargs="?")
    startday_parser.set_defaults(func=cmd_startday)

    open_loop_accept_parser = sub.add_parser("open-loop-accept")
    open_loop_accept_parser.add_argument("key")
    open_loop_accept_parser.add_argument("--date")
    open_loop_accept_parser.set_defaults(func=cmd_open_loop_accept)

    open_loop_resolve_parser = sub.add_parser("open-loop-resolve")
    open_loop_resolve_parser.add_argument("key")
    open_loop_resolve_parser.add_argument("--date")
    open_loop_resolve_parser.add_argument("--evidence", default="")
    open_loop_resolve_parser.set_defaults(func=cmd_open_loop_resolve)

    open_loop_archive_parser = sub.add_parser("open-loop-archive")
    open_loop_archive_parser.add_argument("key")
    open_loop_archive_parser.add_argument("--date")
    open_loop_archive_parser.set_defaults(func=cmd_open_loop_archive)

    exploration_action_parser = sub.add_parser("exploration-action")
    exploration_action_parser.add_argument("key")
    exploration_action_parser.add_argument(
        "--action", required=True, choices=["archive", "extend", "convert", "hold"]
    )
    exploration_action_parser.add_argument("--date")
    exploration_action_parser.add_argument("--evidence", default="")
    exploration_action_parser.set_defaults(func=cmd_exploration_action)

    project_parser = sub.add_parser("project-note")
    project_parser.add_argument("repo")
    project_parser.add_argument("--date")
    project_parser.add_argument("--title")
    project_parser.add_argument("--description", default="")
    project_parser.add_argument("--update", action="store_true")
    project_parser.set_defaults(func=cmd_project_note)

    workflow_parser = sub.add_parser("workflow-note")
    workflow_parser.add_argument("--sequence", required=True)
    workflow_parser.add_argument("--repo", default="")
    workflow_parser.add_argument("--date")
    workflow_parser.add_argument("--title")
    workflow_parser.add_argument("--slug")
    workflow_parser.add_argument("--update", action="store_true")
    workflow_parser.set_defaults(func=cmd_workflow_note)

    concept_parser = sub.add_parser("concept-note")
    concept_parser.add_argument("--title", required=True)
    concept_parser.add_argument("--slug")
    concept_parser.add_argument("--date")
    concept_parser.add_argument("--related", action="append")
    concept_parser.add_argument("--sourced-claim", action="append")
    concept_parser.add_argument("--update", action="store_true")
    concept_parser.set_defaults(func=cmd_concept_note)

    source_parser = sub.add_parser("source-note")
    source_parser.add_argument("--clip", required=True)
    source_parser.add_argument("--date")
    source_parser.add_argument("--title")
    source_parser.add_argument("--slug")
    source_parser.add_argument("--claim", action="append")
    source_parser.add_argument("--details", default="")
    source_parser.add_argument("--supports", action="append")
    source_parser.add_argument("--caveats", default="")
    source_parser.set_defaults(func=cmd_source_note)

    source_archive_parser = sub.add_parser("source-archive")
    source_archive_parser.add_argument("--clip", required=True)
    source_archive_parser.add_argument("--date")
    source_archive_parser.set_defaults(func=cmd_source_archive)

    source_index_parser = sub.add_parser("source-index")
    source_index_parser.add_argument("date", nargs="?")
    source_index_parser.set_defaults(func=cmd_source_index)

    graph_parser = sub.add_parser("graph")
    graph_parser.add_argument(
        "report",
        choices=[
            "broken-links",
            "candidates",
            "concept-tags",
            "orphans",
            "project",
            "source-candidates",
            "source-orphans",
            "sources",
            "stale",
            "stale-clips",
            "workflow",
        ],
    )
    graph_parser.add_argument("--date")
    graph_parser.add_argument("--name")
    graph_parser.set_defaults(func=cmd_graph)

    memory_capture_parser = sub.add_parser("memory-capture")
    memory_capture_parser.add_argument("--title", required=True)
    memory_capture_parser.add_argument("--slug")
    memory_capture_parser.add_argument("--date")
    memory_capture_parser.add_argument("--source-kind", default="manual")
    memory_capture_parser.add_argument("--source-ref", default="")
    memory_capture_parser.add_argument("--trigger", default="")
    memory_capture_parser.add_argument("--candidate", default="")
    memory_capture_parser.add_argument("--related", action="append")
    memory_capture_parser.add_argument("--content")
    memory_capture_parser.set_defaults(func=cmd_memory_capture)

    memory_note_parser = sub.add_parser("memory-note")
    memory_note_parser.add_argument("--title", required=True)
    memory_note_parser.add_argument("--slug")
    memory_note_parser.add_argument("--date")
    memory_note_parser.add_argument("--raw")
    memory_note_parser.add_argument("--memory-type", default="explanation")
    memory_note_parser.add_argument("--plain-english", default="")
    memory_note_parser.add_argument("--why", default="")
    memory_note_parser.add_argument("--understanding", default="")
    memory_note_parser.add_argument("--related", action="append")
    memory_note_parser.add_argument("--link", action="append")
    memory_note_parser.add_argument("--open-question", action="append")
    memory_note_parser.add_argument("--update", action="store_true")
    memory_note_parser.set_defaults(func=cmd_memory_note)

    sub.add_parser("memory-index").set_defaults(func=cmd_memory_index)

    record_parser = sub.add_parser("record-command")
    record_parser.add_argument("--command", required=True)
    record_parser.add_argument("--exit-code", required=True)
    record_parser.add_argument("--cwd", required=True)
    record_parser.add_argument("--start-epoch")
    record_parser.add_argument("--end-epoch")
    record_parser.set_defaults(func=cmd_record_command)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    sys.exit(main())
