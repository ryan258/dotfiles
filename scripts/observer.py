#!/usr/bin/env python3
"""V0/V0.5 Obsidian observer for command and memory capture."""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
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
OBSERVER_BLOCK_RE_TEMPLATE = (
    r"(?ms)^<!-- {owner}:start {name} -->\n?.*?^<!-- {owner}:end {name} -->"
)


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
        "raw/memory",
        "raw/observer-digests",
        "daily",
        "wiki/commands",
        "wiki/memory",
        "maps",
    ]:
        (root / rel).mkdir(parents=True, exist_ok=True)

    write_if_missing(root / "AGENTS.md", AGENTS_TEMPLATE)
    write_if_missing(root / "inbox.md", "# Inbox\n")
    write_if_missing(root / "sources.md", "# Sources\n")
    write_if_missing(root / "maps" / "home.md", "# Home\n\n- [[daily]]\n- [[wiki/commands]]\n")
    write_if_missing(root / "maps" / "memory-index.md", MEMORY_INDEX_TEMPLATE)


def write_if_missing(path: Path, content: str) -> None:
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")


def ensure_daily(root: Path, day: str) -> Path:
    ensure_vault(root)
    path = root / "daily" / f"{day}.md"
    write_if_missing(path, DAILY_TEMPLATE.format(day=day))
    ensure_daily_memory_section(path)
    return path


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
    path = event_path(root, day)
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
    print(daily)
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
