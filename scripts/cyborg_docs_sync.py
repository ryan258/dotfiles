#!/usr/bin/env python3
"""Manifest-driven docs sync worker for Cyborg Lab pages.

This tool is the non-interactive path for keeping project-backed site pages
aligned with real repo changes. It reads a per-repo manifest, gathers git
diff context, asks OpenRouter for page updates, validates the result against
the blog archetypes and configured checks, and can write the updates into a
dedicated site branch.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import textwrap
import unicodedata
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any

try:
    import tomllib
except ImportError:  # pragma: no cover - Python 3.11+ expected, but keep fallback clear.
    tomllib = None


OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
MODEL_FALLBACK = os.environ.get("CYBORG_MODEL") or os.environ.get("CONTENT_MODEL") or os.environ.get("STRATEGY_MODEL") or "nvidia/nemotron-3-super-120b-a12b:free"
DEFAULT_MANIFEST_NAME = ".cyborg-docs.toml"
DEFAULT_BRANCH_PREFIX = "codex/docs-sync"
DESCRIPTION_MIN_CHARS = 140
DESCRIPTION_MAX_CHARS = 160
READABILITY_WARN_GRADE = 6.5
MAX_README_CHARS = 6000
MAX_DIFF_CHARS = 18000
MAX_PAGE_CHARS = 14000
MAX_NOTES_CHARS = 4000
ALLOWED_PAGE_TYPES = frozenset({"project", "workflow", "artifact", "log", "reference", "stack", "protocol"})
LAST_TESTED_TYPES = frozenset({"project", "workflow", "artifact", "stack", "protocol"})
LAST_GENERATED_TYPES = frozenset({"artifact"})
STOP_WORDS = frozenset({
    "a", "an", "the", "and", "or", "but", "for", "nor", "so", "yet",
    "of", "to", "in", "on", "at", "by", "from", "with", "without",
    "as", "is", "are", "was", "were", "be", "been", "being", "this",
    "that", "these", "those", "your", "my", "our", "their", "it", "its",
    "into", "over", "under", "about", "how", "why", "what",
})
_MARKDOWN_LINK = re.compile(r"(?<!\!)\[([^\]]+)\]\(([^)]+)\)")

AI_SYSTEM_PROMPT = textwrap.dedent(
    """
    You are the Cyborg Docs Sync editor for a Hugo site.

    Hard rules:
    - Work only from the provided repo diff, README, notes, existing page, and archetype.
    - Preserve the mapped page path, page type, and title unless the existing page is missing.
    - Write for a smart fifth grader: short sentences, plain words, concrete nouns, quick explanations for jargon.
    - Keep SEO natural. Put the likely search intent into the description, early body copy, and headings without keyword stuffing.
    - Match the provided archetype exactly. Keep the required sections in the same order.
    - If you are unsure, keep the existing claim or remove it. Do not invent facts, commands, outputs, or file paths.
    - Surface the public repo link early in the body when one exists.
    - Do not use H1 headings in the body.
    - Return JSON only.

    Return a JSON object with exactly these keys:
    {
      "markdown": "full markdown file including frontmatter",
      "confidence": 0.0,
      "changed_sections": ["Section Name"],
      "uncertain_points": ["short note"]
    }
    """
).strip()


@dataclass
class PageSpec:
    key: str
    path: str
    page_type: str
    mode: str = "update"
    track: str = ""
    jtbd: str = ""
    notes: str = ""
    draft: bool | None = None


@dataclass
class Manifest:
    path: Path
    repo_root: Path
    blog_root: Path
    base_ref: str
    head_ref: str
    notes_file: str
    test_commands: list[str]
    site_check_commands: list[str]
    site_branch_prefix: str
    pages: list[PageSpec]


@dataclass
class PageUpdate:
    spec: PageSpec
    target_path: Path
    markdown: str
    confidence: float
    changed_sections: list[str]
    uncertain_points: list[str]
    readability_grade: float
    warnings: list[str] = field(default_factory=list)


def die(message: str) -> int:
    print(f"Error: {message}", file=sys.stderr)
    return 1


def _allowed_roots() -> list[Path]:
    return [
        Path.home().resolve(),
        Path("/tmp").resolve(),
        Path("/private/tmp").resolve(),
        Path("/var/folders").resolve(),
        Path("/private/var/folders").resolve(),
    ]


def resolve_safe_path(raw_path: str, *, must_exist: bool = False) -> Path:
    candidate = Path(raw_path).expanduser()
    if not candidate.is_absolute():
        candidate = (Path.cwd() / candidate).resolve()
    else:
        candidate = candidate.resolve()

    if not any(candidate == root or root in candidate.parents for root in _allowed_roots()):
        raise ValueError(f"path outside allowed roots: {candidate}")
    if must_exist and not candidate.exists():
        raise ValueError(f"path does not exist: {candidate}")
    return candidate


def run_command(
    command: list[str],
    *,
    cwd: Path,
    check: bool = True,
    timeout: int = 60,
) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        command,
        cwd=str(cwd),
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
    )
    if check and completed.returncode != 0:
        stderr = completed.stderr.strip() or completed.stdout.strip()
        raise RuntimeError(f"{' '.join(command)} failed: {stderr}")
    return completed


def run_shell(command: str, *, cwd: Path, check: bool = True, timeout: int = 600) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        ["/bin/bash", "-lc", command],
        cwd=str(cwd),
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
    )
    if check and completed.returncode != 0:
        stderr = completed.stderr.strip() or completed.stdout.strip()
        raise RuntimeError(f"{command} failed: {stderr}")
    return completed


def git_stdout(repo_root: Path, *args: str, check: bool = True) -> str:
    completed = run_command(["git", *args], cwd=repo_root, check=check)
    return completed.stdout.strip()


def parse_frontmatter(markdown_text: str) -> tuple[dict[str, Any], str]:
    if not markdown_text.startswith("---"):
        return {}, markdown_text

    match = re.match(r"^---\s*\n(.*?)\n---\s*\n?", markdown_text, re.DOTALL)
    if not match:
        return {}, markdown_text

    frontmatter_text = match.group(1)
    body = markdown_text[match.end() :]
    data: dict[str, Any] = {}
    current_key: str | None = None

    for raw_line in frontmatter_text.splitlines():
        line = raw_line.rstrip("\n")
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if stripped.startswith("- ") and current_key:
            if not isinstance(data.get(current_key), list):
                data[current_key] = []
            data[current_key].append(_parse_scalar(stripped[2:].strip()))
            continue
        if ":" not in line:
            continue
        key, raw_value = line.split(":", 1)
        key = key.strip()
        value = raw_value.strip()
        current_key = key
        if value == "" and key in {"tags", "categories", "aliases", "keywords", "generated_by", "components", "prerequisites", "related_workflows", "related_references", "tools"}:
            data[key] = []
            continue
        data[key] = _parse_scalar(value)

    return data, body


def _parse_scalar(value: str) -> Any:
    raw = value.strip()
    if raw == "":
        return ""
    if raw.startswith('"') and raw.endswith('"'):
        return raw[1:-1].replace('\\"', '"')
    if raw.startswith("'") and raw.endswith("'"):
        return raw[1:-1]
    lowered = raw.lower()
    if lowered == "true":
        return True
    if lowered == "false":
        return False
    if raw.startswith("[") and raw.endswith("]"):
        inner = raw[1:-1].strip()
        if inner == "":
            return []
        return [_parse_scalar(item) for item in inner.split(",") if item.strip()]
    return raw


def normalize_list_field(value: Any, default: Any) -> list[Any]:
    if isinstance(value, list):
        return value
    if value in (None, ""):
        if isinstance(default, list):
            return list(default)
        return []
    return [value]


def parse_manifest_toml(text: str) -> dict[str, Any]:
    if tomllib is not None:
        return tomllib.loads(text)

    result: dict[str, Any] = {}
    pages: list[dict[str, Any]] = []
    current: dict[str, Any] = result
    pending_key = ""
    pending_parts: list[str] = []

    def flush_pending() -> None:
        nonlocal pending_key, pending_parts, current
        if not pending_key:
            return
        current[pending_key] = _parse_toml_value(" ".join(pending_parts))
        pending_key = ""
        pending_parts = []

    for raw_line in text.splitlines():
        stripped = raw_line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if pending_key:
            pending_parts.append(stripped)
            if stripped.endswith("]"):
                flush_pending()
            continue
        if stripped == "[[pages]]":
            current = {}
            pages.append(current)
            result["pages"] = pages
            continue
        if "=" not in stripped:
            continue
        key, raw_value = stripped.split("=", 1)
        key = key.strip()
        raw_value = raw_value.strip()
        if raw_value.startswith("[") and not raw_value.endswith("]"):
            pending_key = key
            pending_parts = [raw_value]
            continue
        current[key] = _parse_toml_value(raw_value)

    flush_pending()
    return result


def _parse_toml_value(raw_value: str) -> Any:
    value = raw_value.strip()
    if value.startswith('"') and value.endswith('"'):
        return value[1:-1]
    if value.startswith("'") and value.endswith("'"):
        return value[1:-1]
    if value.startswith("[") and value.endswith("]"):
        inner = value[1:-1].strip()
        if not inner:
            return []
        items: list[str] = []
        current = []
        in_quote = False
        quote_char = ""
        for char in inner:
            if char in {'"', "'"}:
                if not in_quote:
                    in_quote = True
                    quote_char = char
                elif quote_char == char:
                    in_quote = False
            if char == "," and not in_quote:
                token = "".join(current).strip()
                if token:
                    items.append(token)
                current = []
                continue
            current.append(char)
        token = "".join(current).strip()
        if token:
            items.append(token)
        return [_parse_toml_value(item) for item in items]
    lowered = value.lower()
    if lowered == "true":
        return True
    if lowered == "false":
        return False
    if re.fullmatch(r"-?\d+", value):
        return int(value)
    return value


def _quote_scalar(value: Any) -> str:
    text = str(value)
    if isinstance(value, bool):
        return "true" if value else "false"
    if text == "":
        return '""'
    if any(ch in text for ch in (":", "#", "[", "]", "{", "}", ",", "&", "*", "?", "|", "-", "<", ">", "=", "!", "%", "@", "`")):
        return json.dumps(text, ensure_ascii=False)
    if text.lower() in {"true", "false", "null", "yes", "no", "on", "off"}:
        return json.dumps(text, ensure_ascii=False)
    if text != text.strip():
        return json.dumps(text, ensure_ascii=False)
    return text


def serialize_frontmatter(frontmatter: dict[str, Any], *, ordered_keys: list[str]) -> str:
    lines: list[str] = ["---"]
    for key in ordered_keys:
        if key not in frontmatter:
            continue
        value = frontmatter[key]
        if value is None:
            continue
        if isinstance(value, list):
            if not value:
                lines.append(f"{key}: []")
            else:
                lines.append(f"{key}:")
                for item in value:
                    lines.append(f"  - {_quote_scalar(item)}")
            continue
        lines.append(f"{key}: {_quote_scalar(value)}")
    lines.append("---")
    return "\n".join(lines)


def parse_archetype(text: str) -> dict[str, Any]:
    parts = text.split("---", 2)
    if len(parts) < 3:
        return {"fields": [], "body": text.strip(), "raw_frontmatter": ""}
    raw_frontmatter = parts[1].strip()
    body = parts[2].strip()
    fields: list[dict[str, Any]] = []
    pending_allowed: str | None = None

    for line in raw_frontmatter.splitlines():
        stripped = line.strip()
        if stripped.startswith("#"):
            match = re.match(r"#\s*Allowed\s+(\w+)\s+values?:\s*(.+)", stripped, re.IGNORECASE)
            if match:
                pending_allowed = match.group(2).strip()
            continue
        if not stripped:
            continue
        if stripped.startswith("- ") and fields:
            last = fields[-1]
            if isinstance(last["value"], list):
                last["value"].append(stripped[2:].strip().strip('"').strip("'"))
            continue
        if ":" not in stripped:
            continue
        key, raw_value = stripped.split(":", 1)
        key = key.strip()
        raw_value = raw_value.strip()
        if "{{" in raw_value:
            raw_value = ""
        is_list = raw_value == "" or raw_value.startswith("[")
        raw_value = raw_value.strip('"').strip("'")
        if raw_value.startswith("[") and raw_value.endswith("]"):
            raw_value = [item.strip().strip('"').strip("'") for item in raw_value[1:-1].split(",") if item.strip()]
            is_list = True
        elif is_list and raw_value == "":
            raw_value = []
        entry: dict[str, Any] = {"name": key, "value": raw_value, "is_list": is_list}
        if pending_allowed:
            entry["allowed"] = [part.strip() for part in pending_allowed.split(",")]
            pending_allowed = None
        fields.append(entry)
    return {"fields": fields, "body": body, "raw_frontmatter": raw_frontmatter}


def load_archetype(blog_root: Path, page_type: str) -> dict[str, Any]:
    path = blog_root / "archetypes" / f"{page_type}.md"
    if not path.is_file():
        return {"fields": [], "body": "", "raw_frontmatter": ""}
    return parse_archetype(path.read_text(encoding="utf-8"))


def normalize_description(description: str) -> str:
    text = re.sub(r"\s+", " ", description.replace('"', "")).strip()
    if not text:
        text = "Build a clear next step from this page, with concrete actions, checks, and fallbacks that reduce confusion before execution starts."
    if not re.search(r"[.!?]$", text):
        text += "."
    if DESCRIPTION_MIN_CHARS <= len(text) <= DESCRIPTION_MAX_CHARS:
        return text
    if len(text) < DESCRIPTION_MIN_CHARS:
        filler = " Keep the next step clear, fast to verify, and easy to trust when energy and focus are limited."
        text = f"{text}{filler}"
    if len(text) > DESCRIPTION_MAX_CHARS:
        text = text[: DESCRIPTION_MAX_CHARS - 3].rstrip()
        if " " in text:
            text = text.rsplit(" ", 1)[0]
        text = f"{text}..."
    if len(text) < DESCRIPTION_MIN_CHARS:
        text = text.ljust(DESCRIPTION_MIN_CHARS, ".")
    return text


def count_syllables(word: str) -> int:
    token = re.sub(r"[^a-z]", "", word.lower())
    if not token:
        return 0
    groups = re.findall(r"[aeiouy]+", token)
    count = len(groups)
    if token.endswith("e") and count > 1:
        count -= 1
    return max(count, 1)


def readability_grade(text: str) -> float:
    sentences = re.split(r"[.!?]+", text)
    sentences = [sentence.strip() for sentence in sentences if sentence.strip()]
    words = re.findall(r"\b[\w'-]+\b", text)
    if not sentences or not words:
        return 0.0
    syllables = sum(count_syllables(word) for word in words)
    return round(
        0.39 * (len(words) / max(len(sentences), 1))
        + 11.8 * (syllables / max(len(words), 1))
        - 15.59,
        2,
    )


def extract_h2_headings(text: str) -> list[str]:
    return [match.group(1).strip() for match in re.finditer(r"^##\s+(.+?)\s*$", text, re.MULTILINE)]


def archetype_headings(archetype: dict[str, Any]) -> list[str]:
    return extract_h2_headings(archetype.get("body", ""))


def archetype_defaults(archetype: dict[str, Any]) -> dict[str, Any]:
    defaults: dict[str, Any] = {}
    for field in archetype.get("fields", []):
        name = field["name"]
        value = field.get("value", "")
        if isinstance(value, list):
            defaults[name] = list(value)
        elif isinstance(value, str) and value.lower() in {"true", "false"}:
            defaults[name] = value.lower() == "true"
        else:
            defaults[name] = value
    return defaults


def ordered_frontmatter_keys(archetype: dict[str, Any], existing_frontmatter: dict[str, Any], merged: dict[str, Any]) -> list[str]:
    ordered: list[str] = []
    for field in archetype.get("fields", []):
        name = field["name"]
        if name in merged and name not in ordered:
            ordered.append(name)
    for name in existing_frontmatter:
        if name in merged and name not in ordered:
            ordered.append(name)
    for name in merged:
        if name not in ordered:
            ordered.append(name)
    return ordered


class OpenRouterClient:
    def __init__(self) -> None:
        self.api_key = os.environ.get("OPENROUTER_API_KEY", "").strip()
        self.model = (
            os.environ.get("CYBORG_DOCS_SYNC_MODEL")
            or os.environ.get("CYBORG_MODEL")
            or os.environ.get("CONTENT_MODEL")
            or os.environ.get("STRATEGY_MODEL")
            or MODEL_FALLBACK
        ).strip()

    @property
    def enabled(self) -> bool:
        return bool(self.api_key and self.model)

    def chat_json(self, system_prompt: str, user_prompt: str) -> dict[str, Any]:
        payload = {
            "model": self.model,
            "temperature": 0.25,
            "response_format": {"type": "json_object"},
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
        }
        data = json.dumps(payload).encode("utf-8")
        request = urllib.request.Request(
            OPENROUTER_URL,
            data=data,
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
                "HTTP-Referer": "https://ryanleej.com",
                "X-Title": "Cyborg Docs Sync",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                raw = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            try:
                body = json.loads(exc.read().decode("utf-8"))
                message = body.get("error", {}).get("message", str(body))
            except Exception:
                message = f"HTTP {exc.code}"
            raise RuntimeError(f"AI request failed ({exc.code}): {message}") from exc
        except urllib.error.URLError as exc:
            raise RuntimeError(f"AI request failed: {exc.reason}") from exc

        if "choices" not in raw:
            message = raw.get("error", {}).get("message", json.dumps(raw)[:200])
            raise RuntimeError(f"AI request failed: {message}")
        content = str(raw["choices"][0]["message"]["content"]).strip()
        try:
            return json.loads(content)
        except json.JSONDecodeError as exc:
            raise RuntimeError("AI returned invalid JSON") from exc


def normalize_repo_url(raw_url: str) -> str:
    if raw_url.startswith("git@github.com:"):
        path = raw_url.split(":", 1)[1]
        raw_url = f"https://github.com/{path}"
    if raw_url.endswith(".git"):
        raw_url = raw_url[:-4]
    return raw_url


def coerce_string_list(value: Any, *, field_name: str) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]
    raise ValueError(f"{field_name} must be a TOML list")


def load_manifest(manifest_path: Path, repo_root: Path, blog_root_override: Path | None, base_ref_override: str | None, head_ref_override: str | None) -> Manifest:
    data = parse_manifest_toml(manifest_path.read_text(encoding="utf-8"))
    pages_data = data.get("pages")
    if not isinstance(pages_data, list) or not pages_data:
        raise ValueError("manifest must define at least one [[pages]] entry")

    blog_root_raw = str(blog_root_override or data.get("blog_root") or os.environ.get("CYBORG_LAB_DIR") or "").strip()
    if not blog_root_raw:
        raise ValueError("manifest must define blog_root or pass --blog-root")
    blog_root = resolve_safe_path(blog_root_raw, must_exist=True)

    pages: list[PageSpec] = []
    for index, raw_page in enumerate(pages_data, start=1):
        if not isinstance(raw_page, dict):
            raise ValueError(f"pages[{index}] must be a table")
        path = str(raw_page.get("path", "")).strip()
        page_type = str(raw_page.get("type", "")).strip().lower()
        if not path:
            raise ValueError(f"pages[{index}] is missing path")
        if page_type not in ALLOWED_PAGE_TYPES:
            raise ValueError(f"pages[{index}] has unsupported type: {page_type}")
        key = str(raw_page.get("key", "")).strip() or Path(path).stem.replace("_", "-")
        pages.append(
            PageSpec(
                key=key,
                path=path,
                page_type=page_type,
                mode=str(raw_page.get("mode", "update")).strip() or "update",
                track=str(raw_page.get("track", "")).strip(),
                jtbd=str(raw_page.get("jtbd", "")).strip(),
                notes=str(raw_page.get("notes", "")).strip(),
                draft=raw_page.get("draft") if isinstance(raw_page.get("draft"), bool) else None,
            )
        )

    return Manifest(
        path=manifest_path,
        repo_root=repo_root,
        blog_root=blog_root,
        base_ref=(base_ref_override or str(data.get("base_ref", "")).strip() or "main"),
        head_ref=(head_ref_override or str(data.get("head_ref", "")).strip() or "HEAD"),
        notes_file=str(data.get("notes_file", "")).strip(),
        test_commands=coerce_string_list(data.get("test_commands"), field_name="test_commands"),
        site_check_commands=coerce_string_list(data.get("site_check_commands"), field_name="site_check_commands"),
        site_branch_prefix=str(data.get("site_branch_prefix", DEFAULT_BRANCH_PREFIX)).strip() or DEFAULT_BRANCH_PREFIX,
        pages=pages,
    )


def discover_manifest(repo_root: Path, explicit_path: str | None) -> Path:
    if explicit_path:
        return resolve_safe_path(explicit_path, must_exist=True)
    candidate = repo_root / DEFAULT_MANIFEST_NAME
    if not candidate.is_file():
        raise ValueError(f"manifest not found: {candidate}")
    return candidate


def assert_git_repo(path: Path) -> None:
    if git_stdout(path, "rev-parse", "--is-inside-work-tree", check=False).strip() != "true":
        raise ValueError(f"not a git repository: {path}")


def _existing_ref(repo_root: Path, ref: str) -> bool:
    completed = run_command(["git", "rev-parse", "--verify", f"{ref}^{{commit}}"], cwd=repo_root, check=False)
    return completed.returncode == 0


def resolve_diff_range(repo_root: Path, base_ref: str, head_ref: str) -> tuple[str, str, str]:
    base_candidates = [base_ref, "origin/main", "main", "origin/master", "master", "HEAD~1"]
    resolved_base = next((candidate for candidate in base_candidates if candidate and _existing_ref(repo_root, candidate)), "")
    resolved_head = head_ref if _existing_ref(repo_root, head_ref) else "HEAD"
    if not resolved_base:
        return "", resolved_head, ""
    merge_base = git_stdout(repo_root, "merge-base", resolved_base, resolved_head, check=False).strip()
    if not merge_base:
        merge_base = resolved_base
    return merge_base, resolved_head, f"{merge_base}..{resolved_head}"


def changed_files(repo_root: Path, diff_range: str) -> list[str]:
    if not diff_range:
        return []
    output = git_stdout(repo_root, "diff", "--name-only", diff_range, check=False)
    return [line.strip() for line in output.splitlines() if line.strip()]


def read_text_excerpt(path: Path, limit: int) -> str:
    if not path.is_file():
        return ""
    text = path.read_text(encoding="utf-8", errors="ignore")
    return text[:limit].strip()


def collect_context(manifest: Manifest) -> dict[str, Any]:
    merge_base, resolved_head, diff_range = resolve_diff_range(manifest.repo_root, manifest.base_ref, manifest.head_ref)
    changed = changed_files(manifest.repo_root, diff_range)
    diff_text = ""
    diff_stat = ""
    if diff_range and changed:
        diff_stat = git_stdout(manifest.repo_root, "diff", "--stat", diff_range, check=False)
        limited = changed[:12]
        diff_text = git_stdout(manifest.repo_root, "diff", "--unified=1", "--no-color", diff_range, "--", *limited, check=False)[:MAX_DIFF_CHARS]

    readme_path = manifest.repo_root / "README.md"
    notes_path = manifest.repo_root / manifest.notes_file if manifest.notes_file else None
    repo_remote = normalize_repo_url(git_stdout(manifest.repo_root, "config", "--get", "remote.origin.url", check=False))
    head_sha = git_stdout(manifest.repo_root, "rev-parse", "--short", resolved_head, check=False) if resolved_head else ""
    base_sha = git_stdout(manifest.repo_root, "rev-parse", "--short", merge_base, check=False) if merge_base else ""

    return {
        "repo_remote": repo_remote,
        "head_sha": head_sha,
        "base_sha": base_sha,
        "diff_range": diff_range,
        "diff_stat": diff_stat,
        "changed_files": changed,
        "diff_text": diff_text,
        "readme_text": read_text_excerpt(readme_path, MAX_README_CHARS),
        "notes_text": read_text_excerpt(notes_path, MAX_NOTES_CHARS) if notes_path else "",
    }


def build_plan_text(manifest: Manifest, context: dict[str, Any]) -> str:
    lines = [
        f"Repo: {manifest.repo_root}",
        f"Blog root: {manifest.blog_root}",
        f"Manifest: {manifest.path}",
        f"Diff range: {context.get('diff_range') or '(none)'}",
    ]
    changed = context.get("changed_files", [])
    if changed:
        lines.append(f"Changed files ({len(changed)}):")
        lines.extend(f"- {path}" for path in changed[:20])
    else:
        lines.append("Changed files: none detected")
    lines.append("Mapped pages:")
    for page in manifest.pages:
        suffix = f", track={page.track}" if page.track else ""
        lines.append(f"- {page.key}: {page.page_type} -> {page.path} ({page.mode}{suffix})")
    if manifest.test_commands:
        lines.append("Repo checks:")
        lines.extend(f"- {command}" for command in manifest.test_commands)
    if manifest.site_check_commands:
        lines.append("Site checks:")
        lines.extend(f"- {command}" for command in manifest.site_check_commands)
    return "\n".join(lines)


def _slugify(text: str) -> str:
    normalized = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    words = re.findall(r"[a-z0-9]+", normalized.lower())
    words = [word for word in words if word not in STOP_WORDS] or re.findall(r"[a-z0-9]+", normalized.lower())
    return "-".join(words[:8])[:60].strip("-")


def _fixture_response(fixture_dir: Path | None, page_key: str) -> dict[str, Any] | None:
    if fixture_dir is None:
        return None
    for candidate_name in (f"{page_key}.json", f"{_slugify(page_key)}.json"):
        candidate = fixture_dir / candidate_name
        if candidate.is_file():
            return json.loads(candidate.read_text(encoding="utf-8"))
    return None


def content_path_to_permalink(path: str) -> str:
    normalized = path.strip()
    if normalized.startswith("content/"):
        normalized = normalized[len("content/") :]
    if normalized.endswith("/index.md"):
        normalized = normalized[: -len("/index.md")]
    elif normalized.endswith("/_index.md"):
        normalized = normalized[: -len("/_index.md")]
    elif normalized.endswith(".md"):
        normalized = normalized[:-3]
    return "/" + normalized.strip("/") + "/"


def collect_known_targets(blog_root: Path) -> set[str]:
    content_root = blog_root / "content"
    if not content_root.exists():
        return set()
    targets: set[str] = set()
    for path in content_root.rglob("*.md"):
        rel_path = path.relative_to(blog_root).as_posix()
        targets.add(content_path_to_permalink(rel_path))
    return targets


def _link_tokens(text: str) -> set[str]:
    tokens = set()
    for token in re.findall(r"[a-z0-9]+", text.lower()):
        if token.endswith("s") and len(token) > 3:
            token = token[:-1]
        if token and token not in STOP_WORDS:
            tokens.add(token)
    return tokens


def _split_link_suffix(url: str) -> tuple[str, str]:
    for marker in ("#", "?"):
        if marker in url:
            base, suffix = url.split(marker, 1)
            return base, marker + suffix
    return url, ""


def _best_internal_link_match(url: str, label: str, candidates: set[str]) -> str:
    source_tokens = _link_tokens(url) | _link_tokens(label)
    if not source_tokens:
        return ""

    source_parts = [part for part in url.strip("/").split("/") if part]
    source_prefix = "/".join(source_parts[:2])
    best_target = ""
    best_score = 0
    for candidate in sorted(candidates):
        target_tokens = _link_tokens(candidate)
        overlap = len(source_tokens & target_tokens)
        if overlap == 0:
            continue
        candidate_parts = [part for part in candidate.strip("/").split("/") if part]
        candidate_prefix = "/".join(candidate_parts[:2])
        score = overlap + (1 if source_prefix and source_prefix == candidate_prefix else 0)
        if score > best_score:
            best_score = score
            best_target = candidate

    if best_score < 2:
        return ""
    return best_target


def normalize_internal_links(body: str, *, candidates: set[str], warnings: list[str], page_key: str) -> str:
    def replace(match: re.Match[str]) -> str:
        label = match.group(1)
        url = match.group(2).strip()
        if not url or url.startswith(("http://", "https://", "mailto:", "#", "//")):
            return match.group(0)

        base, suffix = _split_link_suffix(url)
        if not base.startswith("/"):
            return match.group(0)
        normalized = base.rstrip("/") + "/"
        if normalized in candidates:
            return match.group(0)

        replacement = _best_internal_link_match(normalized, label, candidates)
        if not replacement:
            return match.group(0)

        warnings.append(f"{page_key}: normalized internal link {normalized} -> {replacement}")
        return f"[{label}]({replacement}{suffix})"

    return _MARKDOWN_LINK.sub(replace, body)


def build_page_prompt(
    spec: PageSpec,
    context: dict[str, Any],
    existing_markdown: str,
    archetype: dict[str, Any],
    allowed_internal_links: list[dict[str, str]],
) -> str:
    payload = {
        "page": {
            "key": spec.key,
            "path": spec.path,
            "type": spec.page_type,
            "mode": spec.mode,
            "track": spec.track,
            "jtbd": spec.jtbd,
            "notes": spec.notes,
            "draft": spec.draft,
        },
        "repo": {
            "root": str(context["repo_root"]),
            "remote": context.get("repo_remote", ""),
            "base_sha": context.get("base_sha", ""),
            "head_sha": context.get("head_sha", ""),
            "changed_files": context.get("changed_files", []),
            "diff_stat": context.get("diff_stat", ""),
        },
        "readme_excerpt": context.get("readme_text", ""),
        "notes_excerpt": context.get("notes_text", ""),
        "diff_excerpt": context.get("diff_text", ""),
        "existing_page": existing_markdown[:MAX_PAGE_CHARS],
        "allowed_internal_links": allowed_internal_links,
        "archetype": {
            "frontmatter": archetype.get("raw_frontmatter", ""),
            "required_h2": archetype_headings(archetype),
            "body_template": archetype.get("body", ""),
        },
    }
    return (
        "Update the mapped Hugo page from this grounded context. "
        "Only use internal markdown links from allowed_internal_links when you add or change links.\n\n"
        + json.dumps(payload, indent=2)
    )


def merge_page_markdown(
    spec: PageSpec,
    response: dict[str, Any],
    existing_markdown: str,
    archetype: dict[str, Any],
    repo_remote: str,
    internal_link_candidates: set[str],
    fallback_components: list[str],
) -> tuple[str, float, list[str], list[str], float, list[str]]:
    raw_markdown = str(response.get("markdown", "")).strip()
    if not raw_markdown.startswith("---"):
        raise RuntimeError(f"{spec.key} did not return a full markdown file")

    existing_frontmatter, existing_body = parse_frontmatter(existing_markdown)
    new_frontmatter, new_body = parse_frontmatter(raw_markdown)
    if not new_frontmatter:
        raise RuntimeError(f"{spec.key} returned invalid frontmatter")

    today = datetime.now().strftime("%Y-%m-%d")
    defaults = archetype_defaults(archetype)
    merged = {**defaults, **existing_frontmatter, **new_frontmatter}
    merged["type"] = spec.page_type
    if existing_frontmatter.get("title"):
        merged["title"] = existing_frontmatter["title"]
    elif merged.get("title", "") == "":
        merged["title"] = spec.key.replace("-", " ").title()
    merged["description"] = normalize_description(str(merged.get("description", "")))
    if existing_frontmatter.get("date"):
        merged["date"] = existing_frontmatter["date"]
    elif not merged.get("date"):
        merged["date"] = today
    merged["lastmod"] = today
    if spec.page_type in LAST_TESTED_TYPES or "last_tested" in merged:
        merged["last_tested"] = today
    if spec.page_type in LAST_GENERATED_TYPES or "last_generated" in merged:
        merged["last_generated"] = today
    if spec.draft is not None:
        merged["draft"] = spec.draft
    elif "draft" in existing_frontmatter:
        merged["draft"] = existing_frontmatter["draft"]
    elif "draft" not in merged:
        merged["draft"] = True
    if spec.track:
        merged["categories"] = [spec.track]
    if spec.jtbd:
        merged["jtbd"] = spec.jtbd
    for list_key in ("components", "tags", "categories", "prerequisites", "related_workflows", "related_references", "aliases", "keywords", "generated_by", "tools"):
        if list_key in defaults or list_key in merged:
            merged[list_key] = normalize_list_field(merged.get(list_key), defaults.get(list_key, []))
    if spec.page_type == "project" and not merged.get("components"):
        merged["components"] = list(fallback_components)

    warnings: list[str] = []
    if spec.page_type == "workflow" and spec.track and merged.get("categories") != [spec.track]:
        warnings.append(f"{spec.key}: workflow categories were corrected to {spec.track}")
    if repo_remote and repo_remote not in new_body:
        warnings.append(f"{spec.key}: repo link is not visible in the draft body")
    if existing_body and new_body.strip() == existing_body.strip():
        warnings.append(f"{spec.key}: AI returned the same body content")
    new_body = normalize_internal_links(
        new_body,
        candidates=internal_link_candidates,
        warnings=warnings,
        page_key=spec.key,
    )

    required_h2 = archetype_headings(archetype)
    draft_h2 = extract_h2_headings(new_body)
    missing_h2 = [heading for heading in required_h2 if heading not in draft_h2]
    if missing_h2:
        raise RuntimeError(f"{spec.key} is missing required sections: {', '.join(missing_h2)}")

    frontmatter_order = ordered_frontmatter_keys(archetype, existing_frontmatter, merged)
    markdown = serialize_frontmatter(merged, ordered_keys=frontmatter_order) + "\n\n" + new_body.strip() + "\n"
    confidence = float(response.get("confidence", 0.0) or 0.0)
    changed_sections = [str(item).strip() for item in response.get("changed_sections", []) if str(item).strip()]
    uncertain_points = [str(item).strip() for item in response.get("uncertain_points", []) if str(item).strip()]
    grade = readability_grade(new_body)
    if grade > READABILITY_WARN_GRADE:
        warnings.append(f"{spec.key}: readability grade is {grade}, above the target {READABILITY_WARN_GRADE}")
    return markdown, confidence, changed_sections, uncertain_points, grade, warnings


def assert_clean_worktree(repo_root: Path) -> None:
    status = git_stdout(repo_root, "status", "--short", check=False)
    if status.strip():
        raise RuntimeError(f"site repo has uncommitted changes:\n{status}")


def create_site_branch(blog_root: Path, prefix: str, repo_name: str) -> str:
    slug = _slugify(repo_name) or "repo"
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    branch_name = f"{prefix.rstrip('/')}/{slug}-{timestamp}"
    run_command(["git", "checkout", "-b", branch_name], cwd=blog_root, check=True)
    return branch_name


def run_checks(commands: list[str], *, cwd: Path, label: str) -> None:
    for command in commands:
        print(f"{label}: {command}")
        completed = run_shell(command, cwd=cwd, check=False)
        if completed.returncode != 0:
            stderr = completed.stderr.strip()
            stdout = completed.stdout.strip()
            detail = "\n".join(part for part in [stdout, stderr] if part)
            raise RuntimeError(f"{label} failed for `{command}`\n{detail}")


def commit_changes(blog_root: Path, paths: list[Path], repo_name: str, base_sha: str, head_sha: str) -> str:
    rel_paths = [str(path.relative_to(blog_root)) for path in paths]
    run_command(["git", "add", *rel_paths], cwd=blog_root, check=True)
    message = f"docs(sync): refresh {repo_name} from {base_sha or 'base'}..{head_sha or 'head'}"
    run_command(["git", "commit", "-m", message], cwd=blog_root, check=True)
    return message


def sync_pages(
    manifest: Manifest,
    *,
    dry_run: bool,
    create_branch: bool,
    commit: bool,
    confidence_threshold: float,
    fixture_dir: Path | None,
) -> int:
    assert_git_repo(manifest.repo_root)
    assert_git_repo(manifest.blog_root)
    context = collect_context(manifest)
    context["repo_root"] = str(manifest.repo_root)
    print(build_plan_text(manifest, context))
    if not context.get("changed_files"):
        print("No repo changes detected in the selected diff range. Nothing to sync.")
        return 0

    ai_client = OpenRouterClient()
    if fixture_dir is None and not ai_client.enabled:
        return die("sync requires OPENROUTER_API_KEY or --fixture-dir")

    if create_branch or commit:
        assert_clean_worktree(manifest.blog_root)

    updates: list[PageUpdate] = []
    known_targets = collect_known_targets(manifest.blog_root)
    mapped_targets = {
        content_path_to_permalink(page.path)
        for page in manifest.pages
    }
    for page in manifest.pages:
        target_path = manifest.blog_root / page.path
        existing_markdown = ""
        if target_path.is_file():
            existing_markdown = target_path.read_text(encoding="utf-8")
        elif page.mode == "update":
            return die(f"mapped page does not exist for update mode: {target_path}")

        archetype = load_archetype(manifest.blog_root, page.page_type)
        fixture = _fixture_response(fixture_dir, page.key)
        allowed_links = [
            {"path": other.path, "permalink": content_path_to_permalink(other.path), "key": other.key}
            for other in manifest.pages
            if other.key != page.key
        ]
        if fixture is None:
            prompt = build_page_prompt(page, context, existing_markdown, archetype, allowed_links)
            response = ai_client.chat_json(AI_SYSTEM_PROMPT, prompt)
        else:
            response = fixture
        markdown, confidence, changed_sections, uncertain_points, grade, warnings = merge_page_markdown(
            page,
            response,
            existing_markdown,
            archetype,
            context.get("repo_remote", ""),
            known_targets | (mapped_targets - {content_path_to_permalink(page.path)}),
            [
                content_path_to_permalink(other.path)
                for other in manifest.pages
                if other.key != page.key
            ],
        )
        if confidence < confidence_threshold:
            warnings.append(f"{page.key}: confidence {confidence:.2f} is below threshold {confidence_threshold:.2f}")
        updates.append(
            PageUpdate(
                spec=page,
                target_path=target_path,
                markdown=markdown,
                confidence=confidence,
                changed_sections=changed_sections,
                uncertain_points=uncertain_points,
                readability_grade=grade,
                warnings=warnings,
            )
        )

    applicable = [update for update in updates if update.confidence >= confidence_threshold]
    skipped = [update for update in updates if update.confidence < confidence_threshold]

    for update in updates:
        print(f"- {update.spec.key}: confidence={update.confidence:.2f}, readability_grade={update.readability_grade:.2f}, sections={', '.join(update.changed_sections) or '(unspecified)'}")
        for warning in update.warnings:
            print(f"  warning: {warning}")
        for point in update.uncertain_points:
            print(f"  uncertain: {point}")

    if not applicable:
        return die("no page met the confidence threshold; nothing was written")

    if dry_run:
        print(f"Dry run complete. {len(applicable)} page(s) would be updated and {len(skipped)} skipped.")
        return 0

    branch_name = ""
    original_contents: dict[Path, str | None] = {}
    try:
        if create_branch:
            branch_name = create_site_branch(manifest.blog_root, manifest.site_branch_prefix, manifest.repo_root.name)
            print(f"Created site branch: {branch_name}")

        for update in applicable:
            original_contents[update.target_path] = (
                update.target_path.read_text(encoding="utf-8") if update.target_path.exists() else None
            )
            update.target_path.parent.mkdir(parents=True, exist_ok=True)
            update.target_path.write_text(update.markdown, encoding="utf-8")

        if manifest.test_commands:
            run_checks(manifest.test_commands, cwd=manifest.repo_root, label="Repo check")
        if manifest.site_check_commands:
            run_checks(manifest.site_check_commands, cwd=manifest.blog_root, label="Site check")

        if commit:
            message = commit_changes(
                manifest.blog_root,
                [update.target_path for update in applicable],
                manifest.repo_root.name,
                context.get("base_sha", ""),
                context.get("head_sha", ""),
            )
            print(f"Committed site changes: {message}")
        print(f"Updated {len(applicable)} page(s). Skipped {len(skipped)} low-confidence page(s).")
        return 0
    except Exception as exc:
        for path, original in original_contents.items():
            if original is None:
                if path.exists():
                    path.unlink()
            else:
                path.write_text(original, encoding="utf-8")
        return die(str(exc))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Manifest-driven Cyborg docs sync worker.")
    parser.add_argument("--repo", help="Project repo root. Defaults to the current directory.")
    parser.add_argument("--manifest", help=f"Path to manifest file. Defaults to {DEFAULT_MANIFEST_NAME} in the repo root.")
    parser.add_argument("--blog-root", help="Override the blog root declared in the manifest.")
    parser.add_argument("--base-ref", help="Git base ref used to compute the repo diff.")
    parser.add_argument("--head-ref", help="Git head ref used to compute the repo diff.")
    parser.add_argument("--fixture-dir", help=argparse.SUPPRESS)

    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("plan", help="Print the grounded sync plan without calling the AI.")

    sync = subparsers.add_parser("sync", help="Generate page updates, run checks, and optionally write them.")
    sync.add_argument("--dry-run", action="store_true", help="Render the update plan and AI summary without writing files.")
    sync.add_argument("--create-branch", action="store_true", help="Create a dedicated site branch before writing files.")
    sync.add_argument("--commit", action="store_true", help="Commit the site changes after checks pass on the current branch.")
    sync.add_argument("--confidence-threshold", type=float, default=0.72, help="Skip pages below this confidence score.")

    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        repo_root = resolve_safe_path(args.repo or os.getcwd(), must_exist=True)
        manifest_path = discover_manifest(repo_root, args.manifest)
        blog_root_override = resolve_safe_path(args.blog_root, must_exist=True) if args.blog_root else None
        manifest = load_manifest(manifest_path, repo_root, blog_root_override, args.base_ref, args.head_ref)
        fixture_dir = resolve_safe_path(args.fixture_dir, must_exist=True) if args.fixture_dir else None
    except (ValueError, RuntimeError) as exc:
        return die(str(exc))

    try:
        if args.command == "plan":
            context = collect_context(manifest)
            print(build_plan_text(manifest, context))
            return 0
        return sync_pages(
            manifest,
            dry_run=bool(getattr(args, "dry_run", False)),
            create_branch=bool(getattr(args, "create_branch", False)),
            commit=bool(getattr(args, "commit", False)),
            confidence_threshold=float(getattr(args, "confidence_threshold", 0.72)),
            fixture_dir=fixture_dir,
        )
    except (RuntimeError, ValueError) as exc:
        return die(str(exc))


if __name__ == "__main__":
    raise SystemExit(main())
