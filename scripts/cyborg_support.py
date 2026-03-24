#!/usr/bin/env python3
"""Shared utility helpers for Cyborg script modules."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path
from typing import Optional

# How long shell commands are allowed to run before we stop them.
DEFAULT_COMMAND_TIMEOUT_SECONDS = 30


def slugify(text: str, max_words: int = 8, max_len: int = 60) -> str:
    """Turn any text into a short, URL-safe slug like 'my-cool-project'."""
    normalized = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    words = [word for word in normalized.split("-") if word]
    slug = "-".join(words[:max_words]) if words else "untitled"
    return slug[:max_len].strip("-") or "untitled"


def run_command(
    argv: list[str],
    *,
    cwd: Optional[Path] = None,
    allow_failure: bool = False,
    timeout: int = DEFAULT_COMMAND_TIMEOUT_SECONDS,
) -> str:
    """Run a shell command and return its stdout as a string."""
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
    env: Optional[dict[str, str]] = None,
    timeout: int = DEFAULT_COMMAND_TIMEOUT_SECONDS,
) -> tuple[int, str, str]:
    """Run a shell command and return (exit_code, stdout, stderr)."""
    try:
        result = subprocess.run(
            argv,
            cwd=str(cwd) if cwd else None,
            capture_output=True,
            text=True,
            check=False,
            env=env,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return 124, "", f"Command timed out after {timeout}s: {' '.join(argv)}"
    return result.returncode, (result.stdout or "").strip(), (result.stderr or "").strip()


def prompt_input(prompt: str) -> str:
    """Show a prompt and read one line. Return '' on end-of-input."""
    try:
        return input(prompt)
    except EOFError:
        return ""


__all__ = [
    "DEFAULT_COMMAND_TIMEOUT_SECONDS",
    "prompt_input",
    "run_command",
    "run_command_result",
    "slugify",
]
