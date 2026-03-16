#!/usr/bin/env python3
"""Interactive Cyborg Lab ingest agent."""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import subprocess
import sys
import textwrap
import urllib.error
import urllib.request
import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, List, Optional, Tuple

try:
    import readline  # noqa: F401
except ImportError:  # pragma: no cover - readline is optional on some systems
    readline = None  # type: ignore[assignment]


SESSION_VERSION = 1
MAX_CHAT_HISTORY = 8
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
DEFAULT_COMMAND_TIMEOUT_SECONDS = 30
KNOWN_BLOG_PATHS = (
    Path.home() / "Projects" / "cyborg" / "my-ms-ai-blog",
    Path.home() / "Projects" / "cyborg-lab",
)
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
PROJECT_DIR_MARKERS = {"src", "lib", "app", "tests", "docs", ".github"}
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
}
WORKFLOW_TRACKS = (
    "AI Frameworks",
    "Brain Fog Systems",
    "Decision Systems",
    "Keyboard Efficiency",
    "Productivity Systems",
    "Thinking Frameworks",
)
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
    - Output must respect Hugo markdown. No H1 headings in body, no accordion shortcodes, visible code blocks only.
    - Drafts must be near publishable and use draft: true.
    - Descriptions should be action-oriented and roughly 140-160 characters.
    - Repo-backed pages should surface the repo link early in the body.
    """
).strip()
INTAKE_GUIDANCE = textwrap.dedent(
    """
    The session is interactive and collaborative.
    When the user gives new notes:
    - acknowledge what changed
    - reflect it into the likely content map or editorial direction
    - ask at most one useful follow-up question when needed
    - recommend the next command only when it is timely
    """
).strip()
HELP_TEXT = textwrap.dedent(
    """
    Commands:
      /help                 Show this help
      /status               Show session status
      /scan                 Scan the source repo or current directory
      /map                  Generate or refresh the Cyborg Lab content map
      /plan                 Generate or refresh the publishing plan
      /draft [all|key ...]  Generate pending near-publishable drafts
      /links                Recommend existing-page cross-link edits
      /patch-links 1 2      Generate pending edits for selected link recommendations
      /review <key>         Make a draft active for editorial back-and-forth
      /show <key>           Print the current pending draft
      /apply [target]       Write pending drafts or link edits into the blog repo
      /quit                 Save and exit

    Notes:
      - Any non-command text is treated as intake guidance or editorial feedback.
      - Draft changes are held until you explicitly run /apply.
      - Use /review <key> before giving revision notes for a specific draft.
    """
).strip()


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def load_env_file(dotfiles_dir: Path) -> None:
    env_file = dotfiles_dir / ".env"
    if not env_file.exists():
        return
    for raw_line in env_file.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip("'").strip('"')
        os.environ.setdefault(key, value)


def canonical_home_path(path_value: Any) -> Path:
    path = Path(path_value).expanduser().resolve()
    home = Path.home().resolve()
    if path == home or home in path.parents:
        return path
    raise ValueError(f"Path outside home directory: {path}")


def slugify(text: str, max_words: int = 8, max_len: int = 60) -> str:
    normalized = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    words = [word for word in normalized.split("-") if word]
    slug = "-".join(words[:max_words]) if words else "untitled"
    return slug[:max_len].strip("-") or "untitled"


def title_from_slug(slug: str) -> str:
    return " ".join(word.capitalize() for word in slug.replace("_", "-").split("-") if word) or "Untitled"


def track_slug(track_name: str) -> str:
    return slugify(track_name, max_words=6, max_len=40)


def short_preview(text: str, limit: int = 180) -> str:
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


def detect_git_root(start_path: Path) -> Optional[Path]:
    try:
        output = run_command(["git", "rev-parse", "--show-toplevel"], cwd=start_path, allow_failure=False)
    except RuntimeError:
        return None
    return Path(output).resolve()


def extract_first_heading(markdown: str) -> Optional[str]:
    for line in markdown.splitlines():
        stripped = line.strip()
        if stripped.startswith("#"):
            heading = stripped.lstrip("#").strip()
            if heading:
                return heading
    return None


def extract_links(markdown: str) -> list[str]:
    links = []
    seen: set[str] = set()
    for match in re.finditer(r"https?://[^\s)>\]]+", markdown):
        url = match.group(0).rstrip(".,")
        if url not in seen:
            seen.add(url)
            links.append(url)
    return links


def normalize_description(text: str) -> str:
    cleaned = re.sub(r"\s+", " ", text).strip().replace('"', "")
    if not cleaned:
        cleaned = "Action-oriented summary for immediate execution."
    if cleaned[-1:] not in ".!?":
        cleaned += "."
    if len(cleaned) < 140:
        padding = " Use it to act immediately, reduce friction, and keep momentum."
        cleaned = f"{cleaned}{padding}"
    if len(cleaned) > 160:
        trimmed = cleaned[:157].rstrip()
        if " " in trimmed:
            trimmed = trimmed.rsplit(" ", 1)[0]
        cleaned = f"{trimmed}..."
    return cleaned


def prompt_input(prompt: str) -> str:
    try:
        return input(prompt)
    except EOFError:
        return ""


def resolve_within_root(root: Path, target_path: Path, *, label: str) -> Path:
    resolved_root = root.resolve()
    resolved_target = target_path.resolve()
    if resolved_target != resolved_root and resolved_root not in resolved_target.parents:
        raise ValueError(f"Refusing to write outside {label}: {resolved_target}")
    return resolved_target


def looks_like_project_dir(path: Path) -> bool:
    if not path.exists() or not path.is_dir():
        return False
    if path.resolve() == Path.home().resolve():
        return False

    has_readme = False
    has_source = False
    try:
        for child in path.iterdir():
            name = child.name
            if child.is_file() and name in PROJECT_FILE_MARKERS:
                return True
            if child.is_dir() and name in PROJECT_DIR_MARKERS:
                return True
            if child.is_file() and name.lower().startswith("readme"):
                has_readme = True
            if child.is_file() and child.suffix.lower() in SOURCE_FILE_SUFFIXES:
                has_source = True
    except OSError:
        return False
    return has_readme and has_source


@dataclass
class SessionState:
    session_id: str
    version: int
    created_at: str
    updated_at: str
    blog_root: str
    session_dir: str
    cwd: str
    repo_path: Optional[str] = None
    repo_name: Optional[str] = None
    repo_remote: Optional[str] = None
    markdown_file: Optional[str] = None
    source_text: str = ""
    article_text: str = ""
    phase: str = "intake"
    intake_notes: list[str] = field(default_factory=list)
    planning_notes: list[str] = field(default_factory=list)
    editorial_notes: list[str] = field(default_factory=list)
    chat_history: list[dict[str, str]] = field(default_factory=list)
    scan_summary: str = ""
    scan_details: dict[str, Any] = field(default_factory=dict)
    duplicate_candidates: list[dict[str, str]] = field(default_factory=list)
    content_map: dict[str, Any] = field(default_factory=dict)
    publishing_plan: dict[str, Any] = field(default_factory=dict)
    pending_drafts: dict[str, dict[str, Any]] = field(default_factory=dict)
    link_recommendations: list[dict[str, Any]] = field(default_factory=list)
    pending_existing_edits: dict[str, dict[str, Any]] = field(default_factory=dict)
    active_review_key: Optional[str] = None


class OpenRouterClient:
    def __init__(self) -> None:
        self.api_key = os.environ.get("OPENROUTER_API_KEY", "").strip()
        self.model = os.environ.get("CYBORG_MODEL", "moonshotai/kimi-k2:free").strip()
        self.disabled = os.environ.get("CYBORG_DISABLE_AI", "").lower() in {"1", "true", "yes"}

    @property
    def enabled(self) -> bool:
        return bool(self.api_key and self.model and not self.disabled)

    def _request(self, payload: dict[str, Any]) -> dict[str, Any]:
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
        with urllib.request.urlopen(req, timeout=120) as response:
            return json.loads(response.read().decode("utf-8"))

    def chat_text(self, system_prompt: str, user_prompt: str, *, temperature: float = 0.35) -> str:
        payload = {
            "model": self.model,
            "temperature": temperature,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
        }
        response = self._request(payload)
        return str(response["choices"][0]["message"]["content"]).strip()

    def chat_json(self, system_prompt: str, user_prompt: str, *, temperature: float = 0.25) -> dict[str, Any]:
        payload = {
            "model": self.model,
            "temperature": temperature,
            "response_format": {"type": "json_object"},
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
        }
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
    def __init__(self, state: SessionState, *, ai_client: OpenRouterClient, interactive: bool) -> None:
        self.state = state
        self.ai_client = ai_client
        self.interactive = interactive
        self.blog_root = Path(state.blog_root)
        self.session_dir = Path(state.session_dir)

    def save(self, *, include_previews: bool = True) -> None:
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

    def append_chat(self, role: str, content: str) -> None:
        self.state.chat_history.append({"role": role, "content": content})
        if len(self.state.chat_history) > MAX_CHAT_HISTORY * 2:
            self.state.chat_history = self.state.chat_history[-MAX_CHAT_HISTORY * 2 :]
        self.save(include_previews=False)

    def assistant_say(self, message: str) -> None:
        print(message)
        self.append_chat("assistant", message)

    def user_said(self, message: str) -> None:
        self.append_chat("user", message)

    def status_lines(self) -> list[str]:
        map_items = self.state.content_map.get("items", [])
        pending_keys = ", ".join(sorted(self.state.pending_drafts)) or "(none)"
        review_target = self.state.active_review_key or "(none)"
        return [
            f"Session: {self.state.session_id}",
            f"Phase: {self.state.phase}",
            f"Repo: {self.state.repo_path or '(none)'}",
            f"Blog root: {self.state.blog_root}",
            f"Source notes: {len(self.state.intake_notes)} intake, {len(self.state.planning_notes)} planning, {len(self.state.editorial_notes)} editorial",
            f"Content map items: {len(map_items)}",
            f"Pending drafts: {pending_keys}",
            f"Pending existing edits: {len(self.state.pending_existing_edits)}",
            f"Active review target: {review_target}",
        ]

    def content_map_markdown(self) -> str:
        items = self.state.content_map.get("items", [])
        lines = [
            f"# Content Map: {self.state.session_id}",
            "",
            self.state.content_map.get("summary", "No summary generated."),
            "",
            "## Proposed Pages",
            "",
        ]
        for item in items:
            lines.append(f"- `{item['key']}` [{item['type']}] -> `{item['path']}`")
            lines.append(f"  {item['title']}: {item['why']}")
        if self.state.link_recommendations:
            lines.extend(["", "## Existing Page Recommendations", ""])
            for rec in self.state.link_recommendations:
                lines.append(f"- [{rec['id']}] `{rec['path']}`: {rec['reason']}")
        return "\n".join(lines).rstrip() + "\n"

    def plan_markdown(self) -> str:
        lines = [
            f"# Publishing Plan: {self.state.session_id}",
            "",
            self.state.publishing_plan.get("summary", "No plan generated."),
            "",
        ]
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

    def scan_repo(self) -> None:
        if not self.state.repo_path:
            self.assistant_say("No repo path is active. Add notes or restart with `cyborg ingest --repo <path>` if you want repo-backed scanning.")
            return

        repo_path = Path(self.state.repo_path)
        git_root = detect_git_root(repo_path)
        scan_root = git_root or repo_path
        self.state.repo_path = str(scan_root)
        self.state.repo_name = scan_root.name

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
                    "Run `/map` when you want the first content graph.",
                ]
            )
        )

    def _list_files(self, root: Path, use_git: bool) -> list[Path]:
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
        counts: dict[str, int] = {}
        for path in files:
            ext = path.suffix.lower() or "(no-ext)"
            counts[ext] = counts.get(ext, 0) + 1
        return counts

    def _read_excerpt(self, path: Path, *, max_lines: int = 60) -> str:
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            return ""
        excerpt = lines[:max_lines]
        return "\n".join(excerpt).strip()

    def find_duplicate_candidates(self) -> list[dict[str, str]]:
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

    def build_content_map(self) -> None:
        if not self.state.scan_summary and self.state.repo_path:
            self.scan_repo()

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
        self.state.phase = "mapped"
        self.save()
        self.assistant_say(self.content_map_markdown().strip())

    def _ai_content_map(self) -> dict[str, Any]:
        prompt = {
            "repo_name": self.state.repo_name,
            "repo_remote": self.state.repo_remote,
            "source_text": self.state.source_text,
            "article_text": self.state.article_text,
            "intake_notes": self.state.intake_notes,
            "scan_summary": self.state.scan_summary,
            "duplicate_candidates": self.state.duplicate_candidates,
            "content_type_rules": CONTENT_TYPES,
            "workflow_tracks": WORKFLOW_TRACKS,
        }
        response = self.ai_client.chat_json(
            SYSTEM_CONTRACT,
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
        )
        return self._normalize_content_map(response)

    def _heuristic_content_map(self) -> dict[str, Any]:
        repo_slug = slugify(self.state.repo_name or extract_first_heading(self.state.article_text or "") or "cyborg-lab-source")
        repo_title = title_from_slug(repo_slug)
        track_name = self._infer_track()
        track_segment = track_slug(track_name)
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
                "why": "Execution-first page that teaches the repeatable path through the repo from setup to successful output.",
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
        return self._normalize_content_map(
            {
                "summary": summary,
                "items": items,
                "existing_page_recommendations": recommendations,
            }
        )

    def _normalize_content_map(self, content_map: dict[str, Any]) -> dict[str, Any]:
        items = []
        seen_keys: set[str] = set()
        for raw_item in content_map.get("items", []):
            key = raw_item.get("key") or slugify(raw_item.get("title", "item"))
            if key in seen_keys:
                key = f"{key}-{len(seen_keys) + 1}"
            seen_keys.add(key)
            items.append(
                {
                    "key": key,
                    "type": raw_item["type"],
                    "title": raw_item["title"],
                    "path": raw_item["path"],
                    "why": raw_item.get("why", ""),
                    "voice_mode": raw_item.get("voice_mode", "documentation"),
                    "depends_on": raw_item.get("depends_on", []),
                    "existing_page_actions": raw_item.get("existing_page_actions", []),
                }
            )

        recommendations = []
        for index, rec in enumerate(content_map.get("existing_page_recommendations", []), start=1):
            recommendations.append(
                {
                    "id": rec.get("id", index),
                    "path": rec["path"],
                    "reason": rec["reason"],
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
        details = self.state.scan_details
        return details.get("file_count", 0) >= 20 or bool(details.get("sample_docs"))

    def _should_add_stack(self) -> bool:
        details = self.state.scan_details
        signal = " ".join(details.get("manifests", [])).lower()
        return any(name in signal for name in ("pyproject", "package", "requirements", "cargo", "go.mod"))

    def _should_add_protocol(self) -> bool:
        signal = " ".join([self.state.source_text, self.state.article_text, self.state.scan_summary]).lower()
        return any(term in signal for term in ("system prompt", "prompt contract", "instruction template", "persona"))

    def build_publishing_plan(self) -> None:
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
        payload = {
            "content_map": self.state.content_map,
            "planning_notes": self.state.planning_notes,
            "duplicate_candidates": self.state.duplicate_candidates,
            "repo_scan": self.state.scan_summary,
        }
        response = self.ai_client.chat_json(
            SYSTEM_CONTRACT,
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
        )
        return {
            "summary": response.get("summary", ""),
            "phases": response.get("phases", []),
            "publish_sequence": response.get("publish_sequence", []),
            "editorial_questions": response.get("editorial_questions", []),
        }

    def _heuristic_plan(self) -> dict[str, Any]:
        items = self.state.content_map.get("items", [])
        ordered = [item["key"] for item in items if item["type"] in {"workflow", "artifact", "project", "log", "reference", "stack", "protocol"}]
        return {
            "summary": "Lock the graph first, then draft the highest-signal reusable pages before the narrative log. Keep duplicate risk low by reviewing existing-page recommendations before writing anything into the live repo.",
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

    def build_drafts(self, targets: list[str]) -> None:
        if not self.state.publishing_plan:
            self.assistant_say("Generate the publishing plan first with `/plan`.")
            return

        items = self.state.content_map.get("items", [])
        requested = {target for target in targets if target != "all"}
        selected_items = items if not requested else [item for item in items if item["key"] in requested]
        if not selected_items:
            self.assistant_say("No matching content-map keys were found for draft generation.")
            return

        for item in selected_items:
            if self.ai_client.enabled:
                try:
                    draft = self._ai_draft(item)
                except RuntimeError as exc:
                    self.assistant_say(f"AI draft generation failed for `{item['key']}`, using deterministic draft.\nReason: {exc}")
                    draft = self._heuristic_draft(item)
            else:
                draft = self._heuristic_draft(item)
            self.state.pending_drafts[item["key"]] = draft

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

    def _ai_draft(self, item: dict[str, Any]) -> dict[str, Any]:
        sibling_index = [
            {"key": sibling["key"], "title": sibling["title"], "type": sibling["type"], "path": sibling["path"]}
            for sibling in self.state.content_map.get("items", [])
        ]
        payload = {
            "target_item": item,
            "siblings": sibling_index,
            "repo_name": self.state.repo_name,
            "repo_remote": self.state.repo_remote,
            "repo_scan": self.state.scan_summary,
            "article_text": self.state.article_text,
            "source_text": self.state.source_text,
            "planning_notes": self.state.planning_notes,
            "editorial_notes": self.state.editorial_notes[-6:],
        }
        response = self.ai_client.chat_json(
            SYSTEM_CONTRACT,
            textwrap.dedent(
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

                Source payload:
                {json.dumps(payload, indent=2)}
                """
            ).strip(),
            temperature=0.35,
        )
        return {
            "key": item["key"],
            "type": item["type"],
            "title": response.get("title", item["title"]),
            "path": response.get("path", item["path"]),
            "markdown": response["markdown"],
        }

    def _heuristic_draft(self, item: dict[str, Any]) -> dict[str, Any]:
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
        links = []
        for sibling in self.state.content_map.get("items", []):
            if sibling["key"] == current_key:
                continue
            web_path = "/" + "/".join(Path(sibling["path"]).with_suffix("").parts[1:]) + "/"
            links.append((sibling["title"], web_path))
        return links[:5]

    def _draft_template(self, item: dict[str, Any], title: str, repo_url: str, sibling_links: list[tuple[str, str]]) -> str:
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
        today = datetime.now().date().isoformat()
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
        }[type_name]
        lines.append("tags:")
        lines.extend(f"  - {tag}" for tag in tags)
        return "\n".join(lines) + "\n"

    def _body_for_item(self, item: dict[str, Any], title: str, repo_url: str, sibling_links: list[tuple[str, str]]) -> str:
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
        if not sibling_links:
            return "- Add sibling links after the first draft pass."
        return "\n".join(f"- [{title}]({path})" for title, path in sibling_links)

    def recommend_links(self) -> None:
        if self.state.link_recommendations:
            lines = ["Existing-page recommendations:"]
            for recommendation in self.state.link_recommendations:
                lines.append(
                    f"[{recommendation['id']}] {recommendation['path']} - {recommendation['reason']} ({recommendation['action']})"
                )
            lines.append("Use `/patch-links 1 2` to generate pending edits for selected recommendations.")
            self.assistant_say("\n".join(lines))
            return
        self.assistant_say("No existing-page recommendations are available yet. Generate `/map` first.")

    def patch_links(self, ids: list[int]) -> None:
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
        draft = self.state.pending_drafts.get(key)
        if not draft:
            self.assistant_say(f"No pending draft exists for `{key}`.")
            return
        self.assistant_say(draft["markdown"])

    def revise_active_draft(self, feedback: str) -> None:
        target_key = self.state.active_review_key
        if not target_key or target_key not in self.state.pending_drafts:
            self.assistant_say("No active review target is set. Use `/review <key>` first.")
            return

        self.state.editorial_notes.append(feedback)
        draft = self.state.pending_drafts[target_key]
        if self.ai_client.enabled:
            try:
                response = self.ai_client.chat_json(
                    SYSTEM_CONTRACT,
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
                        {feedback}
                        """
                    ).strip(),
                    temperature=0.3,
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

    def apply_changes(self, target: str, *, assume_yes: bool) -> None:
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
            answer = prompt_input("Type 'yes' to apply pending changes: ").strip().lower()
            if answer != "yes":
                self.assistant_say("Apply cancelled.")
                return
        elif not assume_yes and not self.interactive:
            self.assistant_say("Non-interactive apply requires `--yes`.")
            return

        backup_root = self.session_dir / "backups"
        backup_root.mkdir(parents=True, exist_ok=True)

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
        resolved_target = resolve_within_root(self.blog_root, target_path, label="blog root")
        blog_root = self.blog_root.resolve()
        if resolved_target.exists():
            backup_path = backup_root / resolved_target.relative_to(blog_root)
            backup_path.parent.mkdir(parents=True, exist_ok=True)
            backup_path.write_text(resolved_target.read_text(encoding="utf-8"), encoding="utf-8")
        resolved_target.parent.mkdir(parents=True, exist_ok=True)
        resolved_target.write_text(content, encoding="utf-8")

    def _write_session_artifact(self, base_root: Path, relative_path: str, content: str, *, label: str) -> None:
        preview_path = resolve_within_root(base_root, base_root / relative_path, label=label)
        preview_path.parent.mkdir(parents=True, exist_ok=True)
        preview_path.write_text(content, encoding="utf-8")

    def handle_note(self, note: str) -> None:
        self.user_said(note)
        if self.state.active_review_key:
            self.revise_active_draft(note)
            return

        if self.state.phase in {"intake", "scanned"}:
            self.state.intake_notes.append(note)
        else:
            self.state.planning_notes.append(note)
        self.save()

        if self.ai_client.enabled:
            try:
                response = self.ai_client.chat_text(
                    f"{SYSTEM_CONTRACT}\n\n{INTAKE_GUIDANCE}",
                    textwrap.dedent(
                        f"""
                        Current phase: {self.state.phase}
                        Repo path: {self.state.repo_path}
                        Last user note: {note}
                        Intake notes: {json.dumps(self.state.intake_notes[-6:], indent=2)}
                        Planning notes: {json.dumps(self.state.planning_notes[-6:], indent=2)}
                        Content map summary: {short_preview(self.state.content_map.get('summary', ''), 320)}
                        Publishing plan summary: {short_preview(self.state.publishing_plan.get('summary', ''), 320)}

                        Respond like a focused collaborator in 2-4 short paragraphs or 3-5 flat bullets.
                        """
                    ).strip(),
                    temperature=0.35,
                )
                self.assistant_say(response)
                return
            except RuntimeError as exc:
                self.assistant_say(f"Saved the note. AI guidance is unavailable right now.\nReason: {exc}")
                return

        next_step = {
            "intake": "Run `/scan` if you want repo-grounded context, then `/map` when the intake notes feel complete.",
            "scanned": "Run `/map` for the first content graph, or add more notes if the angle still feels fuzzy.",
            "mapped": "Run `/plan` when the content map looks right, or add planning notes if you want to reshape the publishing order.",
            "planned": "Run `/draft all` when you want near-publishable drafts held in preview.",
            "drafted": "Use `/review <key>` for editorial feedback, or `/links` to start the existing-page cross-link pass.",
            "review": "Keep sending editorial notes, or `/apply drafts --yes` when a draft is ready to write into the repo.",
            "applied": "The repo has been updated. Keep reviewing with `/review <key>` if you want another pass before publish.",
        }.get(self.state.phase, "Use `/status` if you want a quick state snapshot.")
        self.assistant_say(f"Saved the note. {next_step}")


def resolve_blog_root(explicit: Optional[str], *, interactive: bool) -> Path:
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
    if not file_path:
        return None, ""
    path = canonical_home_path(file_path)
    try:
        return str(path), path.read_text(encoding="utf-8")
    except OSError as exc:
        raise ValueError(f"Unable to read source file {path}: {exc.strerror or exc}") from exc


def read_stdin_text() -> str:
    if sys.stdin.isatty():
        return ""
    return sys.stdin.read()


def make_session_id(seed: str) -> str:
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
    session_root = blog_root / "drafts" / "ingest"
    if not session_root.exists():
        return []
    return sorted((path for path in session_root.iterdir() if path.is_dir()), key=lambda path: path.name, reverse=True)


def load_session(blog_root: Path, session_id: Optional[str], *, interactive: bool) -> SessionState:
    sessions = list_sessions(blog_root)
    if not sessions:
        raise ValueError("No saved Cyborg sessions were found.")
    if session_id:
        session_dir = blog_root / "drafts" / "ingest" / session_id
    elif interactive:
        print("Saved sessions:")
        for index, session_dir in enumerate(sessions, start=1):
            print(f"  [{index}] {session_dir.name}")
        answer = prompt_input("Resume which session number? ").strip()
        if not answer.isdigit():
            raise ValueError("Resume requires a numeric choice.")
        choice = int(answer)
        if choice < 1 or choice > len(sessions):
            raise ValueError(f"Resume choice must be between 1 and {len(sessions)}.")
        session_dir = sessions[choice - 1]
    else:
        session_dir = sessions[0]
    session_file = session_dir / "session.json"
    if not session_file.exists():
        raise ValueError(f"Session file not found: {session_file}")
    data = json.loads(session_file.read_text(encoding="utf-8"))
    return SessionState(**data)


def parse_command(raw: str) -> tuple[str, list[str]]:
    text = raw[1:] if raw.startswith("/") else raw
    parts = shlex.split(text)
    if not parts:
        return "", []
    return parts[0], parts[1:]


def run_repl(agent: CyborgAgent) -> int:
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

    if agent.state.repo_path and not agent.state.scan_summary:
        agent.scan_repo()

    while True:
        prompt = "cyborg> " if sys.stdin.isatty() else ""
        line = prompt_input(prompt)
        line = line.strip()
        if not line:
            if not sys.stdin.isatty():
                return 0
            continue

        if line.startswith("/") or line in {"help", "status", "scan", "map", "plan", "draft", "links", "review", "show", "apply", "quit", "exit"}:
            command, args = parse_command(line)
            if command in {"quit", "exit"}:
                agent.assistant_say("Session saved. Use `cyborg resume %s` to reopen it later." % agent.state.session_id)
                return 0
            if command == "help":
                agent.assistant_say(HELP_TEXT)
            elif command == "status":
                agent.assistant_say("\n".join(agent.status_lines()))
            elif command == "scan":
                agent.scan_repo()
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


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Cyborg Lab ingest agent")
    subparsers = parser.add_subparsers(dest="command", required=True)

    ingest = subparsers.add_parser("ingest", help="Start a new Cyborg ingest session")
    ingest.add_argument("--repo", help="Repo or directory to scan")
    ingest.add_argument("--file", help="Markdown file to use as supporting material")
    ingest.add_argument("--blog-root", help="Path to my-ms-ai-blog")
    ingest.add_argument("--stdin-source", action="store_true", help="Treat stdin as supporting source material before starting the session")
    ingest.add_argument("idea", nargs="*", help="Plain-text idea or focus notes")

    resume = subparsers.add_parser("resume", help="Resume a saved Cyborg ingest session")
    resume.add_argument("session_id", nargs="?", help="Saved session ID")
    resume.add_argument("--blog-root", help="Path to my-ms-ai-blog")

    return parser


def main(argv: Optional[List[str]] = None) -> int:
    argv = argv if argv is not None else sys.argv[1:]
    parser = build_parser()
    try:
        args = parser.parse_args(argv)
        dotfiles_dir = canonical_home_path(os.environ.get("DOTFILES_DIR", str(Path(__file__).resolve().parents[1])))
        load_env_file(dotfiles_dir)
        interactive = sys.stdin.isatty() and sys.stdout.isatty()
        cwd = canonical_home_path(os.environ.get("USER_CWD", os.getcwd()))
    except ValueError:
        cwd = Path.home().resolve()
    try:
        blog_root = resolve_blog_root(getattr(args, "blog_root", None), interactive=interactive)
        ai_client = OpenRouterClient()

        if args.command == "ingest":
            repo_path = resolve_repo_path(args.repo, cwd)
            markdown_file, article_text = read_file_text(args.file)
            stdin_text = read_stdin_text() if args.stdin_source else ""
            if stdin_text:
                article_text = "\n\n".join(part for part in [article_text, stdin_text] if part.strip())
            source_text = " ".join(args.idea).strip()
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
            return run_repl(agent)

        state = load_session(blog_root, args.session_id, interactive=interactive)
        agent = CyborgAgent(state, ai_client=ai_client, interactive=interactive)
        return run_repl(agent)
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
