#!/usr/bin/env python3
"""Blog site validation: front matter, accessibility, and link checks.

Reads POSTS_DIR, DRAFTS_DIR, and BLOG_DIR from environment variables.
Exit code 1 if published posts have validation errors; 0 otherwise.
"""

import os
import re
import sys
from pathlib import Path

content_dir = Path(os.environ.get("POSTS_DIR", ""))
drafts_dir = Path(os.environ.get("DRAFTS_DIR", ""))
blog_dir_env = os.environ.get("BLOG_DIR")
blog_dir = Path(blog_dir_env) if blog_dir_env else None
content_root = (blog_dir / "content") if blog_dir else content_dir
if not content_root.exists():
    content_root = content_dir

targets = []
for base in (content_dir, drafts_dir):
    if base and base.exists():
        targets.extend(sorted(base.rglob("*.md")))

if not targets:
    print("No markdown files found under content/ or drafts/.")
    sys.exit(0)

key_pattern = lambda key: re.compile(rf"^\s*{re.escape(key)}\s*[:=]", re.MULTILINE)
value_pattern = lambda key: re.compile(rf"^\s*{re.escape(key)}\s*[:=]\s*['\"]?([^\"'\n#]+)", re.MULTILINE)

base_required = ["title", "datePublished", "last_updated", "draft"]
type_specific = {
    "guide": ["guide_category", "energy_required", "time_estimate"],
    "blog": ["tags"],
    "reference": ["tags"],
    "shortcut-spotlight": ["tags"],
}

issues = []
warnings = []


def parse_front_matter(text):
    lines = text.splitlines()
    if not lines:
        return "", text
    delimiter = lines[0].strip()
    if delimiter not in ("---", "+++"):
        return "", text
    body = []
    closing_index = None
    for idx, line in enumerate(lines[1:], start=1):
        if line.strip() == delimiter:
            closing_index = idx
            break
        body.append(line)
    if closing_index is None:
        return "", text
    remainder = "\n".join(lines[closing_index + 1 :])
    return "\n".join(body), remainder


def find_type(front_matter):
    match = re.search(r'^\s*type\s*[:=]\s*["\']?([A-Za-z0-9_-]+)', front_matter, re.MULTILINE)
    if match:
        return match.group(1).strip().lower()
    return ""


def has_key(front_matter, key):
    return bool(key_pattern(key).search(front_matter))


def extract_value(front_matter, key):
    match = value_pattern(key).search(front_matter)
    if match:
        return match.group(1).strip().strip("'").strip('"')
    return ""


markdown_link_pattern = re.compile(r"(?<!\!)\[([^\]]+)\]\(([^)]+)\)")
markdown_image_pattern = re.compile(r"!\[([^\]]*)\]\(([^)]+)\)")
html_img_pattern = re.compile(r"<img[^>]*>", re.IGNORECASE)


def check_accessibility(front_matter, body_text):
    problems = []

    for alt, src in markdown_image_pattern.findall(body_text):
        if not alt.strip():
            problems.append(f"image '{src}' is missing alt text")

    for tag in html_img_pattern.findall(body_text):
        if "alt=" not in tag.lower():
            problems.append("HTML <img> missing alt attribute")

    prev_level = None
    for match in re.finditer(r"^(#{2,6})\s", body_text, re.MULTILINE):
        level = len(match.group(1))
        if prev_level and level > prev_level + 1:
            problems.append(f"heading jumps from H{prev_level} to H{level}")
        prev_level = level

    return problems


def check_links(body_text):
    problems = []
    for text, url in markdown_link_pattern.findall(body_text):
        url = url.strip()
        if not url or url.startswith("http://") or url.startswith("https://") or url.startswith("mailto:") or url.startswith("#"):
            continue
        clean = url.split("#")[0].split("?")[0].strip()
        if not clean:
            continue
        if clean.startswith("//"):
            continue

        rel_target = clean.lstrip("/").rstrip("/")
        candidates = []
        for base in (content_root, drafts_dir):
            if not base:
                continue
            candidates.append(base / f"{rel_target}.md")
            candidates.append(base / rel_target / "index.md")
            candidates.append(base / rel_target / "_index.md")

        if not any(candidate.exists() for candidate in candidates):
            problems.append(f"link '{url}' does not match a local file")

    return problems


for path in targets:
    if blog_dir:
        try:
            rel_path = path.relative_to(blog_dir)
        except ValueError:
            rel_path = path
    else:
        rel_path = path

    parts = rel_path.parts
    is_draft = bool(parts and parts[0] == "drafts")
    if path.name == "_index.md":
        continue

    text = path.read_text(encoding="utf-8", errors="ignore")
    front_matter, body_text = parse_front_matter(text)
    target_list = warnings if is_draft else issues

    if not front_matter:
        target_list.append(f"{rel_path}: missing or invalid front matter delimiter")
        continue

    missing = [key for key in base_required if not has_key(front_matter, key)]
    content_type = find_type(front_matter)
    for extra_key in type_specific.get(content_type, []):
        if not has_key(front_matter, extra_key):
            missing.append(extra_key)

    if missing:
        target_list.append(f"{rel_path}: missing keys -> {', '.join(missing)}")

    if not is_draft and content_type == "guide":
        parts = rel_path.parts
        if "guides" in parts:
            idx = parts.index("guides")
            if len(parts) > idx + 1:
                category = parts[idx + 1]
                if not category.startswith("_"):
                    expected = category
                    guide_category = extract_value(front_matter, "guide_category")
                    if guide_category and guide_category.strip().lower() != expected.lower():
                        issues.append(f"{rel_path}: guide_category '{guide_category}' should match folder '{expected}'")

    if front_matter:
        acc_problems = check_accessibility(front_matter, body_text)
        for problem in acc_problems:
            target_list.append(f"{rel_path}: {problem}")

        link_problems = check_links(body_text)
        for problem in link_problems:
            target = warnings if is_draft else issues
            target.append(f"{rel_path}: {problem}")

if issues:
    print("Blog validation failed:")
    for item in issues:
        print(f"  - {item}")
if warnings:
    label = "warnings (drafts)" if issues else "warnings"
    print(f"\n{label}:")
    for item in warnings:
        print(f"  - {item}")

print(f"\nChecked {len(targets)} markdown files.")
if issues:
    sys.exit(1)

print("Blog validation passed.")
