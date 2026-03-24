#!/usr/bin/env python3
"""Morphling build pipeline helpers for Cyborg."""

from __future__ import annotations

import json
import os
import re
import shutil
import textwrap
import importlib.util
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
    """
).strip()

BUILD_VERIFY_MAX_ROUNDS = 3
BUILD_VERIFY_TIMEOUT_SECONDS = 120

_BUILD_VERIFY_RECIPES: list[tuple[str, str | None, str]] = [
    ("package.json", "npm install --ignore-scripts 2>&1", "npm test 2>&1"),
    ("requirements.txt", "pip install -q -r requirements.txt 2>&1", "python -m pytest -x 2>&1"),
    ("setup.py", "pip install -q -e . 2>&1", "python -m pytest -x 2>&1"),
    ("pyproject.toml", "pip install -q -e . 2>&1", "python -m pytest -x 2>&1"),
    ("go.mod", None, "go build ./... 2>&1 && go test ./... 2>&1"),
    ("Cargo.toml", None, "cargo build 2>&1 && cargo test 2>&1"),
    ("Makefile", None, "make 2>&1"),
]

PUBLISH_TIMEOUT_SECONDS = 300

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

MORPHLING_FIX_PROMPT = textwrap.dedent(
    """
    You are the Morphling — a shapeshifting universal specialist.

    The project you scaffolded failed its verification step.  Fix the
    failing files and return ONLY a JSON object with the files that
    changed:

    {
      "files": {
        "relative/path/file.py": "complete corrected file contents..."
      }
    }

    Rules:
    - Return the FULL contents of each changed file (not a diff).
    - Do not change files that are unrelated to the error.
    - If the fix requires a new file, include it.
    - Do not remove test files — fix them instead.
    - Every file must contain real, working code — no placeholder comments.
    """
).strip()

MARKET_SEARCH_TIMEOUT_SECONDS = 10
MARKET_SEARCH_RESULTS_PER_SOURCE = 5

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
    gh_token = os.environ.get("GITHUB_TOKEN", "") or os.environ.get("GH_TOKEN", "")
    if gh_token.strip():
        req.add_header("Authorization", f"token {gh_token.strip()}")
    try:
        with urllib.request.urlopen(req, timeout=MARKET_SEARCH_TIMEOUT_SECONDS) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception:
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
    encoded = urllib.parse.quote_plus(query)
    url = (
        f"https://registry.npmjs.org/-/v1/search"
        f"?text={encoded}&size={MARKET_SEARCH_RESULTS_PER_SOURCE}"
    )
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=MARKET_SEARCH_TIMEOUT_SECONDS) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception:
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

    github_results = _search_github(idea)
    npm_results = _search_npm(idea)

    total = len(github_results) + len(npm_results)
    if total == 0:
        print("  No search results found (APIs may be unreachable). Proceeding with build.")
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
    scaffold = ai_client.chat_json(
        MORPHLING_BUILD_PROMPT,
        f"Build a project from this idea:\n\n{idea}",
        temperature=0.5,
    )

    name = slugify(scaffold.get("name") or "untitled-project", max_words=6, max_len=40)
    description = scaffold.get("description", idea)
    files: dict[str, str] = scaffold.get("files", {})

    if not files:
        raise RuntimeError("Morphling returned an empty project scaffold (no files).")

    project_dir = target_root / name
    if project_dir.exists():
        suffix = uuid.uuid4().hex[:6]
        project_dir = target_root / f"{name}-{suffix}"

    print(f"  Project: {project_dir}")
    print(f"  Description: {description}")
    print(f"  Files: {len(files)}")

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


def _detect_verify_recipe(project_dir: Path) -> tuple[str | None, str] | None:
    """Return (install_cmd, test_cmd) for the project, or None."""
    for marker, install_cmd, test_cmd in _BUILD_VERIFY_RECIPES:
        if (project_dir / marker).exists():
            return install_cmd, test_cmd
    return None


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

    install_cmd, test_cmd = recipe
    print(f"  Verifying scaffold ({test_cmd.split()[0]})...")

    for attempt in range(1, BUILD_VERIFY_MAX_ROUNDS + 1):
        if install_cmd and attempt == 1:
            exit_code, stdout, stderr = run_command_result(
                ["bash", "-c", install_cmd],
                cwd=project_dir,
                timeout=BUILD_VERIFY_TIMEOUT_SECONDS,
            )
            if exit_code != 0:
                error_output = (stderr or stdout)[:4000]
                print(f"  Install failed (attempt {attempt}/{BUILD_VERIFY_MAX_ROUNDS})")
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
                exit_code, stdout, stderr = run_command_result(
                    ["bash", "-c", install_cmd],
                    cwd=project_dir,
                    timeout=BUILD_VERIFY_TIMEOUT_SECONDS,
                )
                if exit_code != 0:
                    print("  Install still failing after fix — stopping verification.")
                    return

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
    for file_path in sorted(project_dir.rglob("*")):
        if file_path.is_file() and ".git" not in file_path.parts:
            rel = str(file_path.relative_to(project_dir))
            try:
                content = file_path.read_text(encoding="utf-8", errors="replace")
                file_snapshot[rel] = content[:6000]
            except Exception:
                continue

    user_msg = (
        f"Project idea: {idea}\n\n"
        f"Current files:\n{json.dumps(file_snapshot, indent=2)}\n\n"
        f"The {phase} step failed.\n"
        f"Command: {command}\n"
        f"Error output:\n{error_output}"
    )

    try:
        fix = ai_client.chat_json(
            MORPHLING_FIX_PROMPT,
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
