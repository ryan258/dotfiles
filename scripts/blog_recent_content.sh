#!/bin/bash
set -euo pipefail

# blog_recent_content.sh - show latest Hugo content activity

# Source .env if present to get BLOG_CONTENT_DIR
ENV_FILE="$HOME/dotfiles/.env"
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

CONTENT_DIR="${BLOG_CONTENT_DIR:-}"
if [ -z "$CONTENT_DIR" ]; then
  echo "BLOG_CONTENT_DIR is not set. Add it to ~/.env." >&2
  exit 1
fi

if [ ! -d "$CONTENT_DIR" ]; then
  echo "Content directory not found: $CONTENT_DIR" >&2
  exit 1
fi

LIMIT=${1:-10}

BLOG_CONTENT_DIR="$CONTENT_DIR" LIMIT="$LIMIT" python3 <<'PY'
import os
from pathlib import Path
from datetime import datetime
import sys

content_dir = Path(os.environ.get("BLOG_CONTENT_DIR"))
limit = int(os.environ.get("LIMIT", "10"))

keys = ["last_updated", "lastUpdated", "datePublished", "date", "publishDate"]

def parse_front_matter(path: Path):
    try:
        text = path.read_text(encoding="utf-8")
    except Exception:
        return {}
    if not text.startswith("---"):
        return {}
    parts = text.split("---", 2)
    if len(parts) < 3:
        return {}
    front = parts[1].strip().splitlines()
    data = {}
    for line in front:
        if not line.strip() or line.strip().startswith(('#', '//')):
            continue
        if ':' not in line:
            continue
        key, value = line.split(':', 1)
        data[key.strip()] = value.strip().strip('"').strip("'")
    return data

def parse_date(raw):
    if not raw:
        return None
    raw = raw.strip()
    if raw.endswith('Z'):
        raw = raw[:-1] + '+00:00'
    for fmt in ("%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d"):
        try:
            dt = datetime.strptime(raw, fmt)
            # Remove timezone info for consistency
            return dt.replace(tzinfo=None) if dt.tzinfo else dt
        except ValueError:
            continue
    try:
        dt = datetime.fromisoformat(raw)
        # Remove timezone info for consistency
        return dt.replace(tzinfo=None) if dt.tzinfo else dt
    except Exception:
        return None

entries = []
for path in content_dir.rglob('*.md'):
    try:
        path.relative_to(content_dir)
    except ValueError:
        continue
    if path.parent == content_dir:
        continue
    if path.name == "_index.md":
        continue
    fm = parse_front_matter(path)
    dt = None
    for key in keys:
        if key in fm:
            dt = parse_date(fm[key])
            if dt:
                break
    if dt is None:
        dt = datetime.fromtimestamp(path.stat().st_mtime)
    entries.append((dt, path))

entries.sort(key=lambda item: item[0], reverse=True)
print(f"Showing {min(limit, len(entries))} latest files from {content_dir} (sorted by front matter date if available):")
for dt, path in entries[:limit]:
    print(f"{dt:%Y-%m-%d}  {path.relative_to(content_dir)}")
PY
