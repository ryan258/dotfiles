#!/usr/bin/env python3
"""Build a conservative shell dependency graph for the dotfiles repo."""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import sys
from pathlib import Path


SKIP_DIRS = {
    ".git",
    ".gitnexus",
    ".claude",
    ".venv",
    "__pycache__",
    "node_modules",
    "ai-staff-hq",
}
SHELL_EXTENSIONS = {".sh", ".bash", ".zsh"}
FUNCTION_RE = re.compile(
    r"^[\t ]*(?:function[\t ]+)?([A-Za-z_][A-Za-z0-9_:-]*)[\t ]*(?:\(\))?[\t ]*\{"
)
CALL_TOKEN_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_:-]*)\b")
ALIAS_RE = re.compile(r"^[\t ]*alias[\t ]+([A-Za-z0-9_-]+)=(.+)$")
SKIP_CALL_WORDS = {
    "alias",
    "case",
    "do",
    "done",
    "elif",
    "else",
    "esac",
    "fi",
    "for",
    "function",
    "if",
    "in",
    "local",
    "readonly",
    "return",
    "select",
    "then",
    "while",
}


def rel(root: Path, path: Path) -> str:
    return path.resolve().relative_to(root).as_posix()


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8", errors="replace")


def is_shell_file(path: Path) -> bool:
    if path.suffix in SHELL_EXTENSIONS:
        return True
    try:
        first_line = path.open(encoding="utf-8", errors="ignore").readline()
    except OSError:
        return False
    return bool(re.match(r"^#!.*(?:ba|z|k)?sh\b|^#!.*shell", first_line))


def discover_shell_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for current_root, dirnames, filenames in os.walk(root):
        dirnames[:] = [name for name in dirnames if name not in SKIP_DIRS]
        current = Path(current_root)
        for filename in filenames:
            path = current / filename
            if is_shell_file(path):
                files.append(path.resolve())
    return sorted(files, key=lambda path: rel(root, path))


def parse_source_token(line: str) -> str | None:
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        return None
    if not re.match(r"^(source|\.)\s+", stripped):
        return None
    try:
        parts = shlex.split(stripped, comments=True)
    except ValueError:
        return None
    if len(parts) < 2 or parts[0] not in {"source", "."}:
        return None
    return parts[1]


def resolve_source(root: Path, file_path: Path, token: str) -> str | None:
    file_dir = file_path.parent
    value = token
    replacements = {
        '$(dirname "$0")': str(file_dir),
        "$(dirname '$0')": str(file_dir),
        "$(dirname $0)": str(file_dir),
        '$(dirname "${BASH_SOURCE[0]}")': str(file_dir),
        "$(dirname '${BASH_SOURCE[0]}')": str(file_dir),
        "$(dirname ${BASH_SOURCE[0]})": str(file_dir),
        "${SCRIPT_DIR}": str(file_dir),
        "$SCRIPT_DIR": str(file_dir),
        "${DOTFILES_DIR}": str(root),
        "$DOTFILES_DIR": str(root),
        "${REPO_ROOT}": str(root),
        "$REPO_ROOT": str(root),
        "${HOME}": str(Path.home()),
        "$HOME": str(Path.home()),
    }
    for key, replacement in replacements.items():
        value = value.replace(key, replacement)
    if value.startswith("~/"):
        value = str(Path.home() / value[2:])

    candidate = Path(value)
    if not candidate.is_absolute():
        candidate = file_dir / candidate
    try:
        resolved = candidate.resolve()
        resolved.relative_to(root)
    except (OSError, ValueError):
        return None
    return rel(root, resolved)


def parse_alias(line: str, file_rel: str, line_number: int) -> dict[str, object] | None:
    match = ALIAS_RE.match(line)
    if not match:
        return None
    alias_name = match.group(1)
    raw_value = match.group(2).strip()
    try:
        value_parts = shlex.split(raw_value)
    except ValueError:
        value_parts = [raw_value.strip("'\"")]
    command = value_parts[0] if value_parts else ""
    return {"alias": alias_name, "command": command, "file": file_rel, "line": line_number}


def strip_assignment_prefix(line: str) -> str:
    stripped = line.strip()
    while True:
        match = re.match(r"^[A-Za-z_][A-Za-z0-9_]*=(?:'[^']*'|\"[^\"]*\"|[^\s]+)\s+(.*)$", stripped)
        if not match:
            return stripped
        stripped = match.group(1).strip()


def first_call_symbol(line: str) -> str | None:
    raw_stripped = line.strip()
    command_substitution = re.search(r"\$\([\t ]*([A-Za-z_][A-Za-z0-9_:-]*)\b", raw_stripped)
    if command_substitution:
        symbol = command_substitution.group(1)
        if symbol not in SKIP_CALL_WORDS:
            return symbol

    stripped = strip_assignment_prefix(line)
    if not stripped or stripped.startswith("#"):
        return None
    if parse_source_token(stripped):
        return None
    for prefix in ("if ", "then ", "elif ", "while ", "do ", "time ", "command "):
        if stripped.startswith(prefix):
            stripped = stripped[len(prefix) :].strip()
    match = CALL_TOKEN_RE.search(stripped)
    if not match:
        return None
    symbol = match.group(1)
    if symbol in SKIP_CALL_WORDS:
        return None
    return symbol


def build_graph(root: Path) -> dict[str, object]:
    root = root.resolve()
    files: list[dict[str, object]] = []
    functions: list[dict[str, object]] = []
    sources: list[dict[str, object]] = []
    references: list[dict[str, object]] = []
    aliases: list[dict[str, object]] = []

    shell_files = discover_shell_files(root)
    for file_path in shell_files:
        file_rel = rel(root, file_path)
        text = read_text(file_path)
        lines = text.splitlines()
        files.append({"path": file_rel, "lineCount": len(lines)})

        heredoc_end: str | None = None
        for index, line in enumerate(lines, start=1):
            if heredoc_end:
                if line.strip() == heredoc_end:
                    heredoc_end = None
                continue

            heredoc_match = re.search(r"<<-?['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?", line)
            if heredoc_match:
                heredoc_end = heredoc_match.group(1)
                continue

            function_match = FUNCTION_RE.match(line)
            if function_match:
                functions.append({"name": function_match.group(1), "file": file_rel, "line": index})
                continue

            source_token = parse_source_token(line)
            if source_token:
                sources.append(
                    {
                        "source": file_rel,
                        "target": resolve_source(root, file_path, source_token),
                        "raw": source_token,
                        "line": index,
                    }
                )
                continue

            alias = parse_alias(line, file_rel, index)
            if alias:
                aliases.append(alias)
                continue

            call = first_call_symbol(line)
            if call:
                references.append({"symbol": call, "file": file_rel, "line": index})

    defined = {entry["name"] for entry in functions}
    references = [entry for entry in references if entry["symbol"] in defined]

    return {
        "root": str(root),
        "files": files,
        "functions": sorted(functions, key=lambda item: (str(item["name"]), str(item["file"]), int(item["line"]))),
        "sources": sorted(sources, key=lambda item: (str(item["source"]), int(item["line"]))),
        "references": sorted(references, key=lambda item: (str(item["symbol"]), str(item["file"]), int(item["line"]))),
        "aliases": sorted(aliases, key=lambda item: (str(item["alias"]), str(item["file"]), int(item["line"]))),
    }


def normalize_query(root: Path, query: str) -> str:
    path = Path(query)
    if path.is_absolute():
        try:
            return rel(root, path.resolve())
        except ValueError:
            return query
    return query.strip("./")


def command_sources(graph: dict[str, object], target_file: str) -> dict[str, object]:
    sources = [entry for entry in graph["sources"] if entry["source"] == target_file]
    return {"command": "sources", "file": target_file, "sources": sources}


def command_dependents(graph: dict[str, object], target_file: str) -> dict[str, object]:
    dependents = [entry for entry in graph["sources"] if entry["target"] == target_file]
    return {"command": "dependents", "file": target_file, "dependents": dependents}


def command_functions(graph: dict[str, object], symbol: str) -> dict[str, object]:
    definitions = [entry for entry in graph["functions"] if entry["name"] == symbol]
    return {"command": "functions", "symbol": symbol, "definitions": definitions}


def command_impact(graph: dict[str, object], root: Path, query: str) -> dict[str, object]:
    normalized = normalize_query(root, query)
    file_paths = {entry["path"] for entry in graph["files"]}
    if normalized in file_paths:
        definitions = [entry for entry in graph["functions"] if entry["file"] == normalized]
        return {
            "command": "impact",
            "kind": "file",
            "file": normalized,
            "sources": [entry for entry in graph["sources"] if entry["source"] == normalized],
            "dependents": [entry for entry in graph["sources"] if entry["target"] == normalized],
            "definitions": definitions,
            "references": [
                entry
                for entry in graph["references"]
                if entry["symbol"] in {definition["name"] for definition in definitions}
            ],
        }

    return {
        "command": "impact",
        "kind": "symbol",
        "symbol": query,
        "definitions": [entry for entry in graph["functions"] if entry["name"] == query],
        "references": [entry for entry in graph["references"] if entry["symbol"] == query],
    }


def dump(payload: dict[str, object]) -> None:
    print(json.dumps(payload, indent=2, sort_keys=True))


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, help="Repository root to scan")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("scan")
    for command in ("sources", "dependents", "functions", "impact"):
        subparser = subparsers.add_parser(command)
        subparser.add_argument("query")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = Path(args.root).resolve()
    if not root.is_dir():
        print(f"Error: root not found: {root}", file=sys.stderr)
        return 3

    graph = build_graph(root)
    if args.command == "scan":
        dump({"command": "scan", "graph": graph})
    elif args.command == "sources":
        dump(command_sources(graph, normalize_query(root, args.query)))
    elif args.command == "dependents":
        dump(command_dependents(graph, normalize_query(root, args.query)))
    elif args.command == "functions":
        dump(command_functions(graph, args.query))
    elif args.command == "impact":
        dump(command_impact(graph, root, args.query))
    else:
        print(f"Error: unknown command: {args.command}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
