#!/usr/bin/env python3
"""Morphling build pipeline helpers for Cyborg."""

from __future__ import annotations

import json
import os
import pkgutil
import re
import socket
import shlex
import shutil
import tempfile
import textwrap
import importlib.util
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path
from typing import Any, Optional

from cyborg_support import prompt_input, run_command, run_command_result, slugify

# Default directory where `--build` scaffolds new projects.
# Overridable with `--projects-dir`.
DEFAULT_PROJECTS_DIR = Path.home() / "Projects"

# System prompt for the Morphling build step.
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
      "keywords": ["keyword1", "keyword2", "keyword3"],
      "license": "MIT",
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
    - Include "keywords" (3-8 terms for registry discoverability).
    - Include "license" (default to "MIT" unless the idea implies otherwise).
    - Only use real, published dependencies from the default package registry for the chosen ecosystem.
    - Do not invent package names, package versions, or unsupported SDK bindings.
    - Prefer standard-library or mainstream dependencies when they can solve the task cleanly.
    - Only call third-party APIs whose public entry points you can name concretely from the package's documented or inspectable surface.
    - If a third-party integration is uncertain, isolate it behind a small internal adapter so the rest of the app and tests do not depend on guessed SDK symbols.
    - Define option and parameter semantics explicitly, and keep CLI help text, docstrings, implementation, and tests consistent.
    - Prefer tests that exercise your own code seams instead of mocking third-party package internals directly.
    - Tests must be deterministic and offline: mock network, browser, and filesystem side effects instead of depending on live external services.
    - Do not write placeholder tests that merely assert "expected to fail" for unfinished features; either implement the feature or write a focused mocked test for the intended behavior.
    """
).strip()

BUILD_VERIFY_MAX_ROUNDS = 3
BUILD_VERIFY_TIMEOUT_SECONDS = 120
BUILD_SCAFFOLD_MAX_ATTEMPTS = 3


def _quote_python_bin(python_bin: str | Path | None = None) -> str:
    """Return a shell-safe Python executable path."""
    return shlex.quote(str(python_bin or sys.executable or "python3"))


def _python_requirements_install_cmd(python_bin: str | Path | None = None) -> str:
    """Install runtime deps, plus dev deps when a separate file exists."""
    quoted_python = _quote_python_bin(python_bin)
    return (
        f"{quoted_python} -m pip install -q --upgrade pip"
        f" && {quoted_python} -m pip install -q -r requirements.txt"
        f" && if [ -f requirements-dev.txt ]; then {quoted_python} -m pip install -q -r requirements-dev.txt; fi"
    )


def _python_editable_install_cmd(python_bin: str | Path | None = None) -> str:
    """Install editable Python projects and optional dev requirements."""
    quoted_python = _quote_python_bin(python_bin)
    return (
        f"{quoted_python} -m pip install -q --upgrade pip"
        f" && {quoted_python} -m pip install -q -e ."
        f" && if [ -f requirements-dev.txt ]; then {quoted_python} -m pip install -q -r requirements-dev.txt; fi"
    )


def _python_pytest_cmd(python_bin: str | Path | None = None) -> str:
    """Run pytest with the same Python interpreter used for install."""
    return f"{_quote_python_bin(python_bin)} -m pytest -x"

_BUILD_VERIFY_RECIPES: list[tuple[str, str, str | None, str]] = [
    ("package.json", "node", "npm install --ignore-scripts", "npm test"),
    ("manifest.json", "extension", None, "extension verification"),
    ("requirements.txt", "python", _python_requirements_install_cmd(), _python_pytest_cmd()),
    ("setup.py", "python", _python_editable_install_cmd(), _python_pytest_cmd()),
    ("pyproject.toml", "python", _python_editable_install_cmd(), _python_pytest_cmd()),
    ("go.mod", "go", None, "go build ./... && go test ./..."),
    ("Cargo.toml", "cargo", None, "cargo build && cargo test"),
    ("Makefile", "make", None, "make"),
]

PUBLISH_TIMEOUT_SECONDS = 300
FIX_SNAPSHOT_MAX_FILE_CHARS = 6000
FIX_SNAPSHOT_MAX_TOTAL_CHARS = 120000

_FIX_SNAPSHOT_EXCLUDED_DIRS = {
    ".git",
    ".gitnexus",
    ".venv",
    ".venv-codex",
    "__pycache__",
    ".pytest_cache",
    ".mypy_cache",
    "node_modules",
    "dist",
    "build",
    "coverage",
    "target",
}

_FIX_SNAPSHOT_EXCLUDED_FILES = {
    "package-lock.json",
    "pnpm-lock.yaml",
    "yarn.lock",
}

_PUBLISH_RECIPES: list[tuple[str, list[str], list[str], list[str], str]] = [
    (
        "package.json",
        ["npm"],
        ["NPM_TOKEN"],
        [],
        "npm publish --access public 2>&1",
    ),
    (
        "pyproject.toml",
        ["python3", "twine"],
        ["TWINE_USERNAME", "TWINE_PASSWORD"],
        ["python3 -m build 2>&1"],
        "twine upload dist/* 2>&1",
    ),
    (
        "setup.py",
        ["python3", "twine"],
        ["TWINE_USERNAME", "TWINE_PASSWORD"],
        ["python3 -m build 2>&1"],
        "twine upload dist/* 2>&1",
    ),
    (
        "Cargo.toml",
        ["cargo"],
        ["CARGO_REGISTRY_TOKEN"],
        [],
        "cargo publish 2>&1",
    ),
    (
        "go.mod",
        ["gh"],
        [],
        [],
        "",
    ),
]

MORPHLING_METADATA_PROMPT = textwrap.dedent(
    """
    You are the Morphling. Enhance this package's metadata for publishing
    to a package registry.

    Return JSON with exactly this shape:
    {
      "keywords": ["keyword1", "keyword2", "keyword3"],
      "description": "improved one-line description (max 120 chars)"
    }

    Rules:
    - Keywords should help discoverability on npm, PyPI, or crates.io.
    - Keep description concise and specific.
    - Return 5-8 keywords.
    """
).strip()

MORPHLING_INSTALL_FIX_PROMPT = textwrap.dedent(
    """
    You are the Morphling — a shapeshifting universal specialist.

    The project you scaffolded failed during dependency installation or
    build setup. Fix the failing files and return ONLY a JSON object
    with the files that changed:

    {
      "files": {
        "relative/path/file.py": "complete corrected file contents..."
      }
    }

    Rules:
    - Return the FULL contents of each changed file (not a diff).
    - Prioritize dependency manifests and build config first: requirements.txt, requirements-dev.txt, pyproject.toml, setup.py, package.json, Cargo.toml, go.mod, Makefile.
    - Do not invent package names, package versions, or unsupported SDK bindings.
    - Do not change application source files unless the install error explicitly requires it.
    - If a package or version does not exist, replace it with a real published dependency or remove it and simplify the implementation.
    - Do not change files that are unrelated to the install failure.
    - If the fix requires a new file, include it.
    - Every file must contain real, working code — no placeholder comments.
    """
).strip()

MORPHLING_TEST_FIX_PROMPT = textwrap.dedent(
    """
    You are the Morphling — a shapeshifting universal specialist.

    The project you scaffolded failed its verification tests. Fix the
    failing files and return ONLY a JSON object with the files that
    changed:

    {
      "files": {
        "relative/path/file.py": "complete corrected file contents..."
      }
    }

    Rules:
    - Return the FULL contents of each changed file (not a diff).
    - Do not change files that are unrelated to the test failure.
    - If the fix requires a new file, include it.
    - Do not remove test files — fix them instead.
    - Read the failing tests carefully and align the implementation to the contract they describe before guessing.
    - If code and tests disagree on semantics, make the contract explicit and keep CLI help text, docstrings, implementation, and tests consistent.
    - Do not keep tests coupled to guessed third-party symbols. Switch to a verified public API or add a small local adapter/helper seam inside the project and patch that instead.
    - If a dependency exists but the referenced symbol does not, use the verified installed module surface from the project instead of guessing.
    - Replace placeholder "expected to fail" assertions and live-network tests with deterministic mocked tests that verify the intended success or error behavior.
    - Every file must contain real, working code — no placeholder comments.
    """
).strip()

MARKET_SEARCH_TIMEOUT_SECONDS = 10
MARKET_SEARCH_RESULTS_PER_SOURCE = 5
DEFAULT_DATA_DIR = Path.home() / ".config" / "dotfiles-data"
DEFAULT_GITHUB_TOKEN_FILE = Path.home() / ".github_token"

_MARKET_SEARCH_NOTES: dict[str, str] = {}

MARKET_VALIDATION_PROMPT = textwrap.dedent(
    """
    You are a market analyst assessing whether a project idea is worth building.

    You will receive:
    1. The project idea
    2. Search results from GitHub and npm showing existing solutions

    Analyze the competitive landscape and return a JSON object:
    {
      "verdict": "green | yellow | red",
      "summary": "2-3 sentence executive summary",
      "existing_solutions": [
        {
          "name": "project-name",
          "source": "github or npm",
          "stars_or_downloads": "123 stars or 1.2k weekly downloads",
          "description": "what it does",
          "url": "link"
        }
      ],
      "gap_analysis": "What the idea does that existing tools don't, or why it's redundant",
      "differentiation_suggestions": ["suggestion 1", "suggestion 2"]
    }

    Verdicts:
    - "green": Nothing close exists, or existing solutions are weak/abandoned. Build it.
    - "yellow": Similar tools exist but there's a clear gap or angle. Consider refining.
    - "red": Well-maintained, popular tools already do exactly this. Reconsider.

    Be concise and actionable. The user has limited energy.
    """
).strip()


def _search_github(query: str) -> list[dict[str, Any]]:
    """Search GitHub repositories for existing solutions."""
    _MARKET_SEARCH_NOTES.pop("github", None)
    encoded = urllib.parse.quote_plus(query)
    url = (
        f"https://api.github.com/search/repositories"
        f"?q={encoded}&sort=stars&order=desc"
        f"&per_page={MARKET_SEARCH_RESULTS_PER_SOURCE}"
    )
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "Cyborg-Lab-Agent/1.0",
        },
    )
    gh_token = _load_github_token()
    if gh_token.strip():
        req.add_header("Authorization", f"token {gh_token.strip()}")
    try:
        with urllib.request.urlopen(req, timeout=MARKET_SEARCH_TIMEOUT_SECONDS) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception as exc:
        _MARKET_SEARCH_NOTES["github"] = _format_market_search_error("github", exc)
        return []
    results: list[dict[str, Any]] = []
    for item in data.get("items", [])[:MARKET_SEARCH_RESULTS_PER_SOURCE]:
        results.append(
            {
                "name": item.get("name", ""),
                "full_name": item.get("full_name", ""),
                "description": (item.get("description") or "")[:200],
                "stars": item.get("stargazers_count", 0),
                "url": item.get("html_url", ""),
                "updated_at": (item.get("updated_at") or "")[:10],
                "language": item.get("language") or "unknown",
            }
        )
    return results


def _search_npm(query: str) -> list[dict[str, Any]]:
    """Search npm registry for existing packages."""
    _MARKET_SEARCH_NOTES.pop("npm", None)
    encoded = urllib.parse.quote_plus(query)
    url = (
        f"https://registry.npmjs.org/-/v1/search"
        f"?text={encoded}&size={MARKET_SEARCH_RESULTS_PER_SOURCE}"
    )
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=MARKET_SEARCH_TIMEOUT_SECONDS) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception as exc:
        _MARKET_SEARCH_NOTES["npm"] = _format_market_search_error("npm", exc)
        return []
    results: list[dict[str, Any]] = []
    for obj in data.get("objects", [])[:MARKET_SEARCH_RESULTS_PER_SOURCE]:
        pkg = obj.get("package", {})
        results.append(
            {
                "name": pkg.get("name", ""),
                "description": (pkg.get("description") or "")[:200],
                "version": pkg.get("version", ""),
                "date": (pkg.get("date") or "")[:10],
                "url": pkg.get("links", {}).get("npm", ""),
                "keywords": pkg.get("keywords", [])[:5],
            }
        )
    return results


def _github_token_candidate_paths() -> list[Path]:
    """Return the token file paths used by GitHub-related tooling."""
    data_dir = Path(os.environ.get("DATA_DIR", str(DEFAULT_DATA_DIR))).expanduser()
    candidates = [
        os.environ.get("GITHUB_TOKEN_FILE", "").strip(),
        os.environ.get("GITHUB_TOKEN_FALLBACK", "").strip(),
        str(DEFAULT_GITHUB_TOKEN_FILE),
        str(data_dir / "github_token"),
    ]
    seen: set[Path] = set()
    paths: list[Path] = []
    for raw in candidates:
        if not raw:
            continue
        path = Path(raw).expanduser()
        if path in seen:
            continue
        seen.add(path)
        paths.append(path)
    return paths


def _load_github_token() -> str:
    """Load a GitHub token from env vars or the standard token files."""
    for key in ("GITHUB_TOKEN", "GH_TOKEN"):
        value = os.environ.get(key, "").strip()
        if value:
            return value

    for token_path in _github_token_candidate_paths():
        try:
            if not token_path.is_file():
                continue
            token = token_path.read_text(encoding="utf-8").strip()
        except OSError:
            continue
        if token:
            return token
    return ""


def _format_market_search_error(source: str, exc: Exception) -> str:
    """Summarize market-search failures without leaking secrets."""
    label = "GitHub" if source == "github" else "npm"

    if isinstance(exc, urllib.error.HTTPError):
        if source == "github" and exc.code == 401:
            return (
                f"{label} search failed: authentication rejected. "
                "Check GITHUB_TOKEN, GH_TOKEN, or the configured token file."
            )
        if source == "github" and exc.code == 403:
            return f"{label} search failed: rate limited or forbidden."
        return f"{label} search failed: HTTP {exc.code}."

    if isinstance(exc, urllib.error.URLError):
        reason = exc.reason
        if isinstance(reason, socket.timeout):
            return f"{label} search failed: request timed out."
        return f"{label} search failed: network unavailable."

    if isinstance(exc, TimeoutError):
        return f"{label} search failed: request timed out."

    if isinstance(exc, json.JSONDecodeError):
        return f"{label} search failed: invalid API response."

    return f"{label} search failed: {type(exc).__name__}."


def _format_validation_report(report: dict[str, Any]) -> str:
    """Format a market validation report for terminal display."""
    verdict = report.get("verdict", "yellow")
    label_map = {"green": "[OPEN]", "yellow": "[CROWDED]", "red": "[SATURATED]"}
    label = label_map.get(verdict, "[UNKNOWN]")

    lines = [
        "",
        f"  Market Validation: {label}",
        f"  {report.get('summary', 'No summary available.')}",
        "",
    ]

    solutions = report.get("existing_solutions", [])
    if solutions:
        lines.append("  Existing solutions:")
        for sol in solutions[:5]:
            stars_dl = sol.get("stars_or_downloads", "")
            source = sol.get("source", "")
            name = sol.get("name", "unknown")
            desc = sol.get("description", "")[:80]
            lines.append(f"    - {name} ({source}, {stars_dl}): {desc}")
        lines.append("")

    gap = report.get("gap_analysis", "")
    if gap:
        lines.append(f"  Gap analysis: {gap}")
        lines.append("")

    suggestions = report.get("differentiation_suggestions", [])
    if suggestions:
        lines.append("  Differentiation ideas:")
        for suggestion in suggestions:
            lines.append(f"    - {suggestion}")
        lines.append("")

    return "\n".join(lines)


def validate_market(
    idea: str,
    ai_client: "OpenRouterClient",
    *,
    assume_yes: bool = False,
    interactive: bool = True,
) -> bool:
    """Search for existing solutions and present a competitive landscape report."""
    print("  Searching for existing solutions...")
    _MARKET_SEARCH_NOTES.clear()

    github_results = _search_github(idea)
    npm_results = _search_npm(idea)
    search_notes = [
        _MARKET_SEARCH_NOTES[source]
        for source in ("github", "npm")
        if _MARKET_SEARCH_NOTES.get(source)
    ]
    for note in search_notes:
        print(f"  Note: {note}")

    total = len(github_results) + len(npm_results)
    if total == 0:
        if search_notes:
            print("  No search results found from the available sources. Proceeding with build.")
        else:
            print("  No matching GitHub repositories or npm packages found. Proceeding with build.")
        return True

    search_data = json.dumps({"github": github_results, "npm": npm_results}, indent=2)
    user_prompt = f"Project idea: {idea}\n\nSearch results ({total} found):\n{search_data}"

    try:
        report = ai_client.chat_json(
            MARKET_VALIDATION_PROMPT,
            user_prompt,
            temperature=0.3,
        )
    except Exception as exc:
        print(f"  Market analysis failed ({exc}). Proceeding with build.")
        return True

    print(_format_validation_report(report))

    if assume_yes:
        verdict = report.get("verdict", "yellow")
        if verdict == "red":
            print("  Warning: Market looks saturated, but --yes was passed. Proceeding anyway.")
        return True

    if not interactive:
        return True

    print("  A. Proceed with build")
    print("  B. Revise idea (describe what to change)")
    print("  C. Cancel build")
    choice = prompt_input("  Choice [A/B/C]: ").strip().lower()

    if choice in {"a", "y", "yes", ""}:
        return True
    if choice == "c":
        print("  Build cancelled.")
        return False
    if choice == "b":
        revision = prompt_input("  How should the idea change? ").strip()
        if revision:
            print("  Tip: Re-run with your revised idea:")
            print(f'    cyborg auto --build "{revision}"')
        print("  Build cancelled. Re-run with your revised idea.")
        return False
    return True


def build_project_from_idea(
    idea: str,
    ai_client: "OpenRouterClient",
    *,
    projects_dir: Optional[Path] = None,
    publish: bool = False,
    assume_yes: bool = False,
    interactive: bool = True,
) -> Path:
    """Use the Morphling persona to scaffold a new project from an idea."""
    target_root = projects_dir or DEFAULT_PROJECTS_DIR
    target_root.mkdir(parents=True, exist_ok=True)

    print("Morphling is building your project...")
    scaffold: dict[str, Any] = {}
    description = idea
    raw_files: Any = {}
    files: dict[str, str] = {}
    normalized_entries = 0
    malformed_entries = 0
    build_request = f"Build a project from this idea:\n\n{idea}"
    scaffold_issue = "Morphling returned an unusable scaffold."

    for attempt in range(1, BUILD_SCAFFOLD_MAX_ATTEMPTS + 1):
        scaffold = ai_client.chat_json(
            MORPHLING_BUILD_PROMPT,
            build_request,
            temperature=0.5,
            max_tokens=16000,
        )

        description = scaffold.get("description", idea)
        raw_files = scaffold.get("files", {})
        files, normalized_entries, malformed_entries = _normalize_scaffold_files(raw_files)

        if raw_files and files:
            break

        if not raw_files:
            scaffold_issue = "Morphling returned an empty project scaffold (no files)."
        else:
            scaffold_issue = "Morphling returned a scaffold, but none of the file mappings were usable."

        print(
            f"  Scaffold unusable (attempt {attempt}/{BUILD_SCAFFOLD_MAX_ATTEMPTS}): "
            f"{scaffold_issue}"
        )
        if attempt == BUILD_SCAFFOLD_MAX_ATTEMPTS:
            raise RuntimeError(scaffold_issue)
        build_request = (
            f"Build a project from this idea:\n\n{idea}\n\n"
            f"The previous scaffold was unusable: {scaffold_issue}\n"
            "Retry and return a complete JSON object with a non-empty files map "
            "using safe relative file paths."
        )

    name = slugify(scaffold.get("name") or "untitled-project", max_words=6, max_len=40)

    project_dir = target_root / name
    if project_dir.exists():
        suffix = uuid.uuid4().hex[:6]
        project_dir = target_root / f"{name}-{suffix}"

    print(f"  Project: {project_dir}")
    print(f"  Description: {description}")
    print(f"  Files: {len(files)}")
    if normalized_entries:
        print(f"  Warning: normalized {normalized_entries} malformed file mapping(s) from the scaffold response.")
    if malformed_entries:
        print(f"  Warning: skipped {malformed_entries} malformed file mapping(s) from the scaffold response.")

    skipped: list[str] = []
    for rel_path, contents in files.items():
        if not _is_safe_relative_path(rel_path):
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

    run_command(["git", "init", "-q"], cwd=project_dir, allow_failure=True)
    run_command(["git", "add", "."], cwd=project_dir, allow_failure=True)
    run_command(
        ["git", "-c", "user.name=Morphling", "-c", "user.email=morphling@cyborg-lab", "commit", "-qm", f"Initial scaffold: {description}"],
        cwd=project_dir,
        allow_failure=True,
    )

    print("  Project scaffolded and committed.")
    print()

    _verify_and_fix_scaffold(project_dir, idea, ai_client)

    if publish:
        _publish_project(
            project_dir,
            name,
            description,
            idea,
            ai_client,
            assume_yes=assume_yes,
            interactive=interactive,
        )

    return project_dir


def _detect_verify_recipe(project_dir: Path) -> tuple[str, str | None, str] | None:
    """Return (label, install_cmd, test_cmd) for the project, or None."""
    for marker, label, install_cmd, test_cmd in _BUILD_VERIFY_RECIPES:
        if (project_dir / marker).exists():
            return label, install_cmd, test_cmd
    return None


def _is_safe_relative_path(value: str) -> bool:
    """Return True when value looks like a safe, normal relative file path."""
    if not isinstance(value, str):
        return False
    candidate = value.strip()
    if not candidate or candidate.startswith("/") or "\\" in candidate:
        return False
    if any(ch in candidate for ch in ("\n", "\r", "\x00")):
        return False
    if len(candidate) > 240:
        return False
    path = Path(candidate)
    if path.is_absolute():
        return False
    if any(part in {"", ".", ".."} for part in path.parts):
        return False
    return True


def _normalize_scaffold_files(raw_files: Any) -> tuple[dict[str, str], int, int]:
    """Normalize scaffold file mappings and recover simple swapped path/content pairs."""
    if not isinstance(raw_files, dict):
        return {}, 0, 0

    normalized: dict[str, str] = {}
    swapped_entries = 0
    malformed_entries = 0

    for raw_path, raw_contents in raw_files.items():
        if not isinstance(raw_path, str) or not isinstance(raw_contents, str):
            malformed_entries += 1
            continue

        rel_path = raw_path.strip()
        contents = raw_contents
        if not _is_safe_relative_path(rel_path) and _is_safe_relative_path(raw_contents):
            rel_path = raw_contents.strip()
            contents = raw_path
            swapped_entries += 1

        if not _is_safe_relative_path(rel_path):
            malformed_entries += 1
            continue

        normalized[rel_path] = contents

    return normalized, swapped_entries, malformed_entries


def _prepare_python_verify_commands(
    project_dir: Path,
) -> tuple[tempfile.TemporaryDirectory[str], str, str] | None:
    """Create an isolated venv and return install/test commands bound to it."""
    verify_env = tempfile.TemporaryDirectory(prefix="cyborg-verify-")
    venv_dir = Path(verify_env.name)
    exit_code, stdout, stderr = run_command_result(
        [sys.executable, "-m", "venv", str(venv_dir)],
        cwd=project_dir,
        timeout=BUILD_VERIFY_TIMEOUT_SECONDS,
    )
    if exit_code != 0:
        verify_env.cleanup()
        error_output = (stderr or stdout)[:500]
        print(f"  Could not create isolated Python env: {error_output}")
        return None

    venv_python = venv_dir / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
    if not venv_python.exists():
        verify_env.cleanup()
        print("  Could not locate Python inside the isolated verification env.")
        return None

    install_cmd = (
        _python_requirements_install_cmd(venv_python)
        if (project_dir / "requirements.txt").exists()
        else _python_editable_install_cmd(venv_python)
    )
    test_cmd = _python_pytest_cmd(venv_python)
    return verify_env, install_cmd, test_cmd


def _normalize_extension_path(value: str) -> str:
    """Normalize extension-root-relative paths for existence checks."""
    cleaned = value.strip().split("?", 1)[0].split("#", 1)[0].strip()
    return cleaned.lstrip("/")


def _collect_extension_manifest_paths(manifest: dict[str, Any]) -> set[str]:
    """Collect project-relative files referenced from a browser extension manifest."""
    paths: set[str] = set()

    def add_path(raw_value: Any) -> None:
        if not isinstance(raw_value, str):
            return
        normalized = _normalize_extension_path(raw_value)
        if not normalized or normalized.startswith(("http://", "https://", "//", "data:")):
            return
        paths.add(normalized)

    background = manifest.get("background")
    if isinstance(background, dict):
        add_path(background.get("service_worker"))
        for script in background.get("scripts", []) or []:
            add_path(script)

    for script_group in manifest.get("content_scripts", []) or []:
        if not isinstance(script_group, dict):
            continue
        for script in script_group.get("js", []) or []:
            add_path(script)
        for stylesheet in script_group.get("css", []) or []:
            add_path(stylesheet)

    for key in ("action", "browser_action", "page_action"):
        action = manifest.get(key)
        if isinstance(action, dict):
            add_path(action.get("default_popup"))

    add_path(manifest.get("options_page"))
    options_ui = manifest.get("options_ui")
    if isinstance(options_ui, dict):
        add_path(options_ui.get("page"))
    side_panel = manifest.get("side_panel")
    if isinstance(side_panel, dict):
        add_path(side_panel.get("default_path"))
    add_path(manifest.get("devtools_page"))

    icons = manifest.get("icons")
    if isinstance(icons, dict):
        for icon_path in icons.values():
            add_path(icon_path)

    overrides = manifest.get("chrome_url_overrides")
    if isinstance(overrides, dict):
        for override_path in overrides.values():
            add_path(override_path)

    for entry in manifest.get("web_accessible_resources", []) or []:
        if isinstance(entry, dict):
            for resource in entry.get("resources", []) or []:
                add_path(resource)
        else:
            add_path(entry)

    return paths


def _collect_extension_script_files(project_dir: Path) -> list[Path]:
    """Return JavaScript files that should be syntax-checked for an extension repo."""
    script_files: list[Path] = []
    for candidate in sorted(project_dir.rglob("*"), key=lambda path: str(path)):
        if not candidate.is_file():
            continue
        rel_path = candidate.relative_to(project_dir)
        if any(part in _FIX_SNAPSHOT_EXCLUDED_DIRS for part in rel_path.parts):
            continue
        if candidate.suffix.lower() in {".js", ".mjs", ".cjs"}:
            script_files.append(candidate)
    return script_files


def _verify_extension_project(project_dir: Path) -> tuple[int, str, str]:
    """Validate a browser extension manifest and syntax-check its scripts."""
    manifest_path = project_dir / "manifest.json"
    if not manifest_path.exists():
        return 1, "", "manifest.json is missing."

    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return 1, "", f"manifest.json is not valid JSON: {exc}"

    if not isinstance(manifest, dict):
        return 1, "", "manifest.json must contain a JSON object."

    errors: list[str] = []
    for field in ("manifest_version", "name", "version"):
        if manifest.get(field) in (None, ""):
            errors.append(f"manifest.json is missing required field '{field}'.")

    manifest_version = manifest.get("manifest_version")
    if manifest_version not in {2, 3}:
        errors.append("manifest.json manifest_version must be 2 or 3.")

    for rel_path in sorted(_collect_extension_manifest_paths(manifest)):
        if any(char in rel_path for char in "*?["):
            matches = list(project_dir.glob(rel_path))
            if not matches:
                errors.append(f"manifest.json references missing resource pattern '{rel_path}'.")
            continue
        if not (project_dir / rel_path).exists():
            errors.append(f"manifest.json references missing file '{rel_path}'.")

    node_bin = shutil.which("node")
    if node_bin:
        for script_path in _collect_extension_script_files(project_dir):
            exit_code, stdout, stderr = run_command_result(
                [node_bin, "--check", str(script_path)],
                cwd=project_dir,
                timeout=BUILD_VERIFY_TIMEOUT_SECONDS,
            )
            if exit_code != 0:
                output = (stderr or stdout).strip()[:500]
                rel_path = script_path.relative_to(project_dir)
                errors.append(f"JavaScript syntax check failed for {rel_path}: {output}")

    if errors:
        return 1, "", "\n".join(errors)

    summary = "Extension verification checks passed."
    if not node_bin:
        summary += " Node not available; skipped JavaScript syntax checks."
    return 0, summary, ""


def _verify_and_fix_scaffold(
    project_dir: Path,
    idea: str,
    ai_client: "OpenRouterClient",
) -> None:
    """Run install + tests on a scaffolded project; fix failures with AI."""
    recipe = _detect_verify_recipe(project_dir)
    if recipe is None:
        print("  No recognised build system — skipping verification.")
        return

    label, install_cmd, test_cmd = recipe
    verify_env: tempfile.TemporaryDirectory[str] | None = None
    if label == "python":
        prepared = _prepare_python_verify_commands(project_dir)
        if prepared is None:
            return
        verify_env, install_cmd, test_cmd = prepared

    print(f"  Verifying scaffold ({label})...")

    try:
        for attempt in range(1, BUILD_VERIFY_MAX_ROUNDS + 1):
            if install_cmd:
                exit_code, stdout, stderr = run_command_result(
                    ["bash", "-c", install_cmd],
                    cwd=project_dir,
                    timeout=BUILD_VERIFY_TIMEOUT_SECONDS,
                )
                if exit_code != 0:
                    error_output = (stderr or stdout)[:4000]
                    print(f"  Install failed (attempt {attempt}/{BUILD_VERIFY_MAX_ROUNDS})")
                    if attempt == BUILD_VERIFY_MAX_ROUNDS:
                        print("  Max fix attempts reached during install — project may need manual attention.")
                        return
                    fix_applied = _apply_ai_fix(
                        project_dir,
                        idea,
                        "install",
                        install_cmd,
                        error_output,
                        ai_client,
                    )
                    if not fix_applied:
                        print("  Could not get a fix from the AI — stopping verification.")
                        return
                    continue

            if label == "extension":
                exit_code, stdout, stderr = _verify_extension_project(project_dir)
            else:
                exit_code, stdout, stderr = run_command_result(
                    ["bash", "-c", test_cmd],
                    cwd=project_dir,
                    timeout=BUILD_VERIFY_TIMEOUT_SECONDS,
                )

            if exit_code == 0:
                label = "first try" if attempt == 1 else f"attempt {attempt}"
                print(f"  Verification passed ({label}).")
                if attempt > 1:
                    run_command(["git", "add", "."], cwd=project_dir, allow_failure=True)
                    run_command(
                        ["git", "-c", "user.name=Morphling", "-c", "user.email=morphling@cyborg-lab", "commit", "-qm", f"fix: pass verification (attempt {attempt})"],
                        cwd=project_dir,
                        allow_failure=True,
                    )
                return

            error_output = (stderr or stdout)[:4000]
            print(f"  Tests failed (attempt {attempt}/{BUILD_VERIFY_MAX_ROUNDS})")

            if attempt == BUILD_VERIFY_MAX_ROUNDS:
                print("  Max fix attempts reached — project may need manual attention.")
                return

            fix_applied = _apply_ai_fix(
                project_dir,
                idea,
                "test",
                test_cmd,
                error_output,
                ai_client,
            )
            if not fix_applied:
                print("  Could not get a fix from the AI — stopping verification.")
                return
    finally:
        if verify_env is not None:
            verify_env.cleanup()


_MISSING_PYTHON_ATTR_PATTERNS = (
    re.compile(r"<module ['\"]([A-Za-z0-9_\\.]+)['\"][^>]*> does not have the attribute ['\"][A-Za-z0-9_]+['\"]"),
    re.compile(r"module ['\"]([A-Za-z0-9_\\.]+)['\"] has no attribute ['\"][A-Za-z0-9_]+['\"]"),
)


def _extract_python_bin_from_command(command: str) -> str | None:
    """Extract the Python executable from a shell command when possible."""
    try:
        argv = shlex.split(command)
    except ValueError:
        return None

    if not argv:
        return None

    candidate = Path(argv[0]).name.lower()
    if candidate.startswith("python"):
        return argv[0]
    return None


def _extract_missing_python_modules(error_output: str) -> list[str]:
    """Find Python modules mentioned in missing-attribute errors."""
    modules: set[str] = set()
    for pattern in _MISSING_PYTHON_ATTR_PATTERNS:
        for match in pattern.findall(error_output):
            if match:
                modules.add(match)
    return sorted(modules)[:3]


def _collect_python_module_surfaces(
    project_dir: Path,
    command: str,
    error_output: str,
) -> dict[str, Any]:
    """Inspect installed Python modules when a test failure references missing attrs."""
    python_bin = _extract_python_bin_from_command(command)
    if python_bin is None:
        return {}

    module_names = _extract_missing_python_modules(error_output)
    if not module_names:
        return {}

    inspection_script = textwrap.dedent(
        """
        import importlib
        import json
        import pkgutil
        import sys

        module_name = sys.argv[1]
        try:
            module = importlib.import_module(module_name)
        except Exception as exc:
            print(json.dumps({"module": module_name, "error": str(exc)}))
            raise SystemExit(0)

        attrs = [name for name in dir(module) if not name.startswith("_")][:80]
        submodules = []
        module_path = getattr(module, "__path__", None)
        if module_path:
            submodules = sorted(item.name for item in pkgutil.iter_modules(module_path))[:40]

        print(
            json.dumps(
                {
                    "module": module_name,
                    "attrs": attrs,
                    "submodules": submodules,
                }
            )
        )
        """
    ).strip()

    surfaces: dict[str, Any] = {}
    for module_name in module_names:
        exit_code, stdout, stderr = run_command_result(
            [python_bin, "-c", inspection_script, module_name],
            cwd=project_dir,
            timeout=20,
        )
        payload = (stdout or stderr).strip()
        if not payload:
            continue
        try:
            surfaces[module_name] = json.loads(payload)
        except json.JSONDecodeError:
            surfaces[module_name] = {
                "module": module_name,
                "raw": payload[:500],
                "exit_code": exit_code,
            }
    return surfaces


def _apply_ai_fix(
    project_dir: Path,
    idea: str,
    phase: str,
    command: str,
    error_output: str,
    ai_client: "OpenRouterClient",
) -> bool:
    """Send a failure to the AI and apply the returned file fixes."""
    file_snapshot: dict[str, str] = {}
    snapshot_chars = 0
    for file_path in sorted(project_dir.rglob("*"), key=lambda path: str(path)):
        if not file_path.is_file():
            continue
        rel_path = file_path.relative_to(project_dir)
        if any(part in _FIX_SNAPSHOT_EXCLUDED_DIRS for part in rel_path.parts):
            continue
        if rel_path.name in _FIX_SNAPSHOT_EXCLUDED_FILES:
            continue
        try:
            content = file_path.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue

        trimmed = content[:FIX_SNAPSHOT_MAX_FILE_CHARS]
        projected_size = snapshot_chars + len(str(rel_path)) + len(trimmed)
        if projected_size > FIX_SNAPSHOT_MAX_TOTAL_CHARS and file_snapshot:
            break

        file_snapshot[str(rel_path)] = trimmed
        snapshot_chars = projected_size

    user_msg = (
        f"Project idea: {idea}\n\n"
        f"Current files:\n{json.dumps(file_snapshot, indent=2)}\n\n"
        f"The {phase} step failed.\n"
        f"Command: {command}\n"
        f"Error output:\n{error_output}"
    )
    if phase == "install":
        priority_files = [
            rel
            for rel in file_snapshot
            if Path(rel).name
            in {
                "requirements.txt",
                "requirements-dev.txt",
                "pyproject.toml",
                "setup.py",
                "package.json",
                "Cargo.toml",
                "go.mod",
                "Makefile",
                "README.md",
            }
        ]
        if priority_files:
            user_msg += (
                "\n\nPriority files for install fixes:\n"
                f"{json.dumps(priority_files, indent=2)}"
            )
    elif phase == "test":
        module_surfaces = _collect_python_module_surfaces(project_dir, command, error_output)
        if module_surfaces:
            user_msg += (
                "\n\nVerified installed Python module surfaces:\n"
                f"{json.dumps(module_surfaces, indent=2)}"
            )

    try:
        fix = ai_client.chat_json(
            MORPHLING_INSTALL_FIX_PROMPT if phase == "install" else MORPHLING_TEST_FIX_PROMPT,
            user_msg,
            temperature=0.3,
        )
    except Exception as exc:
        print(f"  AI fix request failed: {exc}")
        return False

    files: dict[str, str] = fix.get("files", {})
    if not files:
        return False

    written = 0
    for rel_path, contents in files.items():
        if rel_path.startswith("/") or ".." in rel_path.split("/"):
            continue
        file_path = (project_dir / rel_path).resolve()
        if project_dir.resolve() not in file_path.parents and file_path != project_dir.resolve():
            continue
        file_path.parent.mkdir(parents=True, exist_ok=True)
        file_path.write_text(contents, encoding="utf-8")
        written += 1

    print(f"  Applied AI fix: {written} file(s) updated.")
    return written > 0


def _detect_publish_recipe(
    project_dir: Path,
) -> tuple[str, list[str], list[str], list[str], str] | None:
    """Return the publish recipe for the project, or None."""
    for recipe in _PUBLISH_RECIPES:
        marker = recipe[0]
        if (project_dir / marker).exists():
            return recipe
    return None


def _validate_publish_prereqs(
    recipe: tuple[str, list[str], list[str], list[str], str],
) -> list[str]:
    """Check that required tools and env vars are available."""
    _, tools, env_vars, pre_cmds, _ = recipe
    errors: list[str] = []

    for tool in tools:
        if not shutil.which(tool):
            errors.append(f"Required tool not found: {tool}")

    for var in env_vars:
        if not os.environ.get(var, "").strip():
            errors.append(f"Required environment variable not set: {var}")

    for pre_cmd in pre_cmds:
        if pre_cmd.startswith("python3 -m build") and importlib.util.find_spec("build") is None:
            errors.append("Required Python module not found: build")

    return errors


def _ensure_github_remote(
    project_dir: Path,
    name: str,
    description: str,
) -> bool:
    """Create a GitHub repo and set it as origin if no remote exists."""
    exit_code, stdout, _ = run_command_result(
        ["git", "remote", "get-url", "origin"],
        cwd=project_dir,
        timeout=10,
    )
    if exit_code == 0 and stdout.strip():
        return True

    if not shutil.which("gh"):
        print("  Warning: gh CLI not found — cannot create GitHub repo.")
        return False

    print(f"  Creating GitHub repo: {name}")
    exit_code, stdout, stderr = run_command_result(
        ["gh", "repo", "create", name, "--public", "--description", description[:200], "--source", str(project_dir), "--push"],
        cwd=project_dir,
        timeout=60,
    )
    if exit_code != 0:
        print(f"  Warning: GitHub repo creation failed: {(stderr or stdout)[:500]}")
        return False

    print("  GitHub repo created and pushed.")
    return True


def _publish_go_project(
    project_dir: Path,
    name: str,
    has_remote: bool,
) -> bool:
    """Publish a Go project via GitHub Releases."""
    if not has_remote:
        print("  Go projects require a GitHub remote for publishing. Skipping.")
        return False

    run_command(
        ["git", "-c", "user.name=Morphling", "-c", "user.email=morphling@cyborg-lab", "tag", "v0.1.0", "-m", "Initial release"],
        cwd=project_dir,
        allow_failure=True,
    )
    run_command(["git", "push", "--tags"], cwd=project_dir, allow_failure=True)

    print("  Creating GitHub release for Go module...")
    exit_code, stdout, stderr = run_command_result(
        ["gh", "release", "create", "v0.1.0", "--title", f"{name} v0.1.0", "--notes", "Initial release. Built by Morphling.", "--latest"],
        cwd=project_dir,
        timeout=60,
    )
    if exit_code != 0:
        print(f"  GitHub release failed: {(stderr or stdout)[:500]}")
        return False

    print("  GitHub release created.")
    return True


def _patch_package_json(
    project_dir: Path,
    keywords: list[str],
    description: str,
) -> None:
    """Update package.json with enhanced keywords and description."""
    pkg_path = project_dir / "package.json"
    if not pkg_path.exists():
        return
    try:
        data = json.loads(pkg_path.read_text(encoding="utf-8"))
        if keywords:
            data["keywords"] = keywords
        if description:
            data["description"] = description
        pkg_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    except Exception:
        pass


def _patch_pyproject_toml(
    project_dir: Path,
    keywords: list[str],
    description: str,
) -> None:
    """Update pyproject.toml with enhanced keywords and description."""
    toml_path = project_dir / "pyproject.toml"
    if not toml_path.exists():
        return
    try:
        content = toml_path.read_text(encoding="utf-8")
        if "[project]" not in content:
            return

        if description:
            content = re.sub(
                r'^(description\s*=\s*)"[^"]*"',
                f'\\1"{description}"',
                content,
                count=1,
                flags=re.MULTILINE,
            )

        if keywords and "keywords" not in content:
            kw_line = "keywords = " + json.dumps(keywords)
            content = content.replace("[project]", f"[project]\n{kw_line}", 1)

        toml_path.write_text(content, encoding="utf-8")
    except Exception:
        pass


def _enhance_package_metadata(
    project_dir: Path,
    marker: str,
    name: str,
    description: str,
    idea: str,
    ai_client: "OpenRouterClient",
) -> None:
    """Best-effort AI enhancement of package metadata before publish."""
    if not ai_client.enabled:
        return

    try:
        metadata = ai_client.chat_json(
            MORPHLING_METADATA_PROMPT,
            f"Package: {name}\nDescription: {description}\nIdea: {idea}",
            temperature=0.3,
        )
    except Exception:
        return

    keywords = metadata.get("keywords", [])
    enhanced_desc = metadata.get("description", "")

    if marker == "package.json":
        _patch_package_json(project_dir, keywords, enhanced_desc)
    elif marker in {"pyproject.toml", "setup.py"}:
        _patch_pyproject_toml(project_dir, keywords, enhanced_desc)


def _setup_npm_auth(project_dir: Path) -> Path | None:
    """Write a temporary npm userconfig file that consumes NPM_TOKEN."""
    token = os.environ.get("NPM_TOKEN", "").strip()
    if not token:
        return None
    npmrc = project_dir / f".npmrc.publish-{uuid.uuid4().hex}"
    npmrc.write_text(
        f"//registry.npmjs.org/:_authToken={token}\n",
        encoding="utf-8",
    )
    return npmrc


def _commit_metadata_changes(project_dir: Path) -> bool:
    """Stage and commit any metadata changes made by _enhance_package_metadata."""
    metadata_files = [
        name
        for name in ("package.json", "pyproject.toml", "setup.py")
        if (project_dir / name).exists()
    ]
    if not metadata_files:
        return False

    exit_code, stdout, _ = run_command_result(
        ["git", "diff", "--name-only", "--", *metadata_files],
        cwd=project_dir,
        timeout=10,
    )
    if exit_code != 0 or not stdout.strip():
        return False

    changed_files = [line.strip() for line in stdout.splitlines() if line.strip()]
    if not changed_files:
        return False

    run_command(["git", "add", "--", *changed_files], cwd=project_dir, allow_failure=True)
    run_command(
        ["git", "-c", "user.name=Morphling", "-c", "user.email=morphling@cyborg-lab", "commit", "-qm", "chore: enhance package metadata for publishing"],
        cwd=project_dir,
        allow_failure=True,
    )
    return True


def _publish_project(
    project_dir: Path,
    name: str,
    description: str,
    idea: str,
    ai_client: "OpenRouterClient",
    *,
    assume_yes: bool = False,
    interactive: bool = True,
) -> bool:
    """Detect ecosystem and publish the project to the appropriate registry."""
    recipe = _detect_publish_recipe(project_dir)
    if recipe is None:
        print("  No recognised publish target — skipping publish.")
        return False

    marker, _tools, _env_vars, pre_cmds, pub_cmd = recipe

    errors = _validate_publish_prereqs(recipe)
    if errors:
        print("  Publish prerequisites not met:")
        for err in errors:
            print(f"    - {err}")
        print("  Skipping publish step.")
        return False

    ecosystem = {
        "package.json": "npm",
        "pyproject.toml": "PyPI",
        "setup.py": "PyPI",
        "Cargo.toml": "crates.io",
        "go.mod": "GitHub Releases",
    }.get(marker, "unknown")

    if not assume_yes:
        if not interactive:
            print(f"  Publish to {ecosystem} requires confirmation. Use --yes to auto-confirm.")
            return False
        print()
        print(f"  Ready to publish '{name}' to {ecosystem}.")
        print("  WARNING: Publishing is irreversible.")
        choice = prompt_input("  Proceed? [y/N]: ").strip().lower()
        if choice not in {"y", "yes"}:
            print("  Publish skipped by user.")
            return False

    _enhance_package_metadata(project_dir, marker, name, description, idea, ai_client)
    _commit_metadata_changes(project_dir)

    has_remote = _ensure_github_remote(project_dir, name, description)

    if marker == "go.mod":
        return _publish_go_project(project_dir, name, has_remote)

    if not has_remote:
        print("  Warning: No GitHub remote. Continuing with publish anyway.")

    if has_remote:
        run_command(["git", "push"], cwd=project_dir, allow_failure=True)

    for pre_cmd in pre_cmds:
        label = pre_cmd.split("2>&1")[0].strip()
        print(f"  Running: {label}")
        exit_code, stdout, stderr = run_command_result(
            ["bash", "-c", pre_cmd],
            cwd=project_dir,
            timeout=PUBLISH_TIMEOUT_SECONDS,
        )
        if exit_code != 0:
            print(f"  Pre-publish step failed: {(stderr or stdout)[:1000]}")
            return False

    npmrc_path: Path | None = None
    publish_env: Optional[dict[str, str]] = None
    if marker == "package.json":
        npmrc_path = _setup_npm_auth(project_dir)
        if npmrc_path is not None:
            publish_env = os.environ.copy()
            publish_env["NPM_CONFIG_USERCONFIG"] = str(npmrc_path)

    print(f"  Publishing to {ecosystem}...")
    try:
        exit_code, stdout, stderr = run_command_result(
            ["bash", "-c", pub_cmd],
            cwd=project_dir,
            env=publish_env,
            timeout=PUBLISH_TIMEOUT_SECONDS,
        )
    finally:
        if npmrc_path and npmrc_path.exists():
            npmrc_path.unlink()

    if exit_code != 0:
        print(f"  Publish failed: {(stderr or stdout)[:1000]}")
        return False

    print(f"  Published to {ecosystem} successfully.")
    run_command(
        ["git", "-c", "user.name=Morphling", "-c", "user.email=morphling@cyborg-lab", "tag", "v0.1.0", "-m", "Initial publish"],
        cwd=project_dir,
        allow_failure=True,
    )
    if has_remote:
        run_command(["git", "push", "--tags"], cwd=project_dir, allow_failure=True)

    return True


__all__ = [
    "_commit_metadata_changes",
    "_detect_publish_recipe",
    "_format_validation_report",
    "_publish_project",
    "_setup_npm_auth",
    "_validate_publish_prereqs",
    "build_project_from_idea",
    "validate_market",
]
