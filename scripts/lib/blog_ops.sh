#!/usr/bin/env bash
# scripts/lib/blog_ops.sh
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_BLOG_OPS_LOADED:-}" ]]; then
    return 0
fi
readonly _BLOG_OPS_LOADED=true

# --- Subcommand: status ---
status() {
    echo "📝 BLOG STATUS (ryanleej.com):"

    TOTAL_POSTS=$(find "$POSTS_DIR" -name "*.md" | wc -l | tr -d ' ')
    STUB_FILES=$(grep -l -i "content stub" "$POSTS_DIR"/*.md 2>/dev/null || true)
    if [ -n "$STUB_FILES" ]; then
        STUB_COUNT=$(printf "%s\n" "$STUB_FILES" | grep -c . || true)
    else
        STUB_COUNT=0
    fi

    echo "  • Total posts: $TOTAL_POSTS"
    echo "  • Posts needing content: $STUB_COUNT"

    if [ -d "$DRAFTS_DIR" ]; then
        draft_count=0
        drafts_list=""
        while IFS= read -r draft; do
            drafts_list="${drafts_list}${draft}"$'\n'
            draft_count=$((draft_count + 1))
        done < <(find "$DRAFTS_DIR" -type f -name "*.md" 2>/dev/null | sort)

        if [ "$draft_count" -gt 0 ]; then
            echo "  • Drafts awaiting review ($draft_count):"
            while IFS= read -r draft; do
                [ -z "$draft" ] && continue
                rel=${draft#"$DRAFTS_DIR"/}
                echo "    - $rel"
            done <<< "$drafts_list"
        else
            echo "  • Drafts awaiting review: 0"
        fi
    fi

    if [ -d "$BLOG_DIR/.git" ]; then
        LAST_UPDATE=$(cd "$BLOG_DIR" && git log -1 --format="%ad" --date=short)
        echo "  • Last update: $LAST_UPDATE"

        # Calculate days since last update
        LAST_UPDATE_EPOCH=$(cd "$BLOG_DIR" && git log -1 --format="%ct")
        DAYS_SINCE=$(( ( $(date +%s) - LAST_UPDATE_EPOCH ) / 86400 ))

        if [ "$DAYS_SINCE" -gt 14 ]; then
            echo "  ⏰ It's been $DAYS_SINCE days since your last update"
        fi
    fi

    echo "  • Site: https://ryanleej.com"
}

# --- Subcommand: stubs ---
stubs() {
    echo "📄 CONTENT STUBS:"

    STUB_FILES=$(grep -l -i "content stub" "$POSTS_DIR"/*.md 2>/dev/null || true)

    if [ -n "$STUB_FILES" ]; then
        SEVEN_DAYS_AGO=$(date_shift_days -7 "%s")
        THIRTY_DAYS_AGO=$(date_shift_days -30 "%s")

        echo "$STUB_FILES" | while read -r file; do
            filename=$(basename "$file")

            # Get last modified timestamp
            if [ -d "$BLOG_DIR/.git" ]; then
                # Try to get last git commit date for this file
                last_commit=$(cd "$BLOG_DIR" && git log -1 --format="%ct" -- "$file" 2>/dev/null)
                if [ -n "$last_commit" ]; then
                    mod_time=$last_commit
                else
                    # Fall back to file system modification time
                    mod_time=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null)
                fi
            else
                mod_time=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null)
            fi

            # Calculate age and add warning if old
            if [ "$mod_time" -lt "$THIRTY_DAYS_AGO" ]; then
                days_old=$(( ( $(date +%s) - mod_time ) / 86400 ))
                echo "  ⚠️  $filename (stale: ${days_old} days old)"
            elif [ "$mod_time" -lt "$SEVEN_DAYS_AGO" ]; then
                days_old=$(( ( $(date +%s) - mod_time ) / 86400 ))
                echo "  ⏰ $filename (${days_old} days old)"
            else
                echo "  • $filename"
            fi
        done
    else
        echo "  (No content stubs found)"
    fi
}

# --- Subcommand: random ---
random_stub() {
    echo "🎲 Opening a random stub..."
    
    mapfile -t STUB_FILES < <(grep -l -i "content stub" "$POSTS_DIR"/*.md 2>/dev/null || true)
    
    if [ ${#STUB_FILES[@]} -eq 0 ]; then
        echo "  (No content stubs to choose from)"
        return
    fi
    
    RANDOM_INDEX=$(( RANDOM % ${#STUB_FILES[@]} ))
    RANDOM_FILE=${STUB_FILES[$RANDOM_INDEX]}
    
    echo "  Opening: $(basename "$RANDOM_FILE")"
    
    if command -v code &> /dev/null; then
        code "$RANDOM_FILE"
    else
        open "$RANDOM_FILE"
    fi
}

# --- Subcommand: recent ---
recent() {
    echo "⏳ RECENTLY MODIFIED POSTS:"

    recent_files=()
    while IFS= read -r -d '' file; do
        recent_files+=("$file")
    done < <(find "$POSTS_DIR" -name "*.md" -mtime -14 -print0 2>/dev/null)

    if [ ${#recent_files[@]} -eq 0 ]; then
        echo "  (No posts updated in the last 14 days)"
        return
    fi

    printf '%s\0' "${recent_files[@]}" | xargs -0 ls -t | head -n 5 | while read -r file; do
        if [ -f "$file" ]; then
            echo "  • $(basename "$file")"
        fi
    done
}

publish_site() {
    echo "Running blog validation..."
    if ! validate_site; then
        echo "Publish aborted: validation failed." >&2
        return 1
    fi

    if ! command -v hugo >/dev/null 2>&1; then
        echo "Error: hugo CLI not found. Install Hugo to build the site." >&2
        return 1
    fi

    echo ""
    echo "Building site with Hugo (hugo --gc --minify)..."
    if ! (cd "$BLOG_DIR" && hugo --gc --minify); then
        echo "Hugo build failed; see errors above." >&2
        return 1
    fi

    echo ""
    echo "Build complete. Output directory: $BLOG_DIR/public"
    echo ""
    echo "Git status for $BLOG_DIR:"
    git -C "$BLOG_DIR" status -sb || echo "  (Unable to read git status)"

    echo ""
    echo "Next steps:"
    echo "  1. Review the changes above."
    echo "  2. Commit in $BLOG_DIR (examples: git add . && git commit -m \"Publish\")"
    echo "  3. Push when ready (DigitalOcean will build on push)."
}

validate_site() {
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Error: python3 is required for blog validate." >&2
        return 1
    fi

    POSTS_DIR="$POSTS_DIR" DRAFTS_DIR="$DRAFTS_DIR" BLOG_DIR="$BLOG_DIR" python3 <<'PY'
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
    print("❌ Blog validation failed:")
    for item in issues:
        print(f"  - {item}")
if warnings:
    label = "warnings (drafts)" if issues else "warnings"
    print(f"\n⚠️  {label}:")
    for item in warnings:
        print(f"  - {item}")

print(f"\nChecked {len(targets)} markdown files.")
if issues:
    sys.exit(1)

print("✅ Blog validation passed.")
PY
}

install_hooks() {
    if [ ! -d "$BLOG_DIR/.git" ]; then
        echo "Error: $BLOG_DIR is not a git repository."
        return 1
    fi

    local hook_file="$BLOG_DIR/.git/hooks/pre-commit"
    cat <<'HOOK' > "$hook_file"
#!/bin/sh
BLOG_DIR="__BLOG_DIR__"
DOTFILES_DIR="$HOME/dotfiles"
SCRIPT="$DOTFILES_DIR/scripts/blog.sh"

if [ ! -x "$SCRIPT" ]; then
  echo "blog.sh not found at $SCRIPT" >&2
  exit 1
fi

echo "Running blog validate..."
BLOG_DIR="$BLOG_DIR" "$SCRIPT" validate
HOOK
    if [ $? -ne 0 ]; then
        echo "Error: Unable to write to $hook_file (check permissions)." >&2
        return 1
    fi

    # Replace placeholder with actual blog dir path
    if ! sed -i '' "s|__BLOG_DIR__|$BLOG_DIR|g" "$hook_file" 2>/dev/null; then
        if ! perl -0pi -e "s|__BLOG_DIR__|$BLOG_DIR|g" "$hook_file" 2>/dev/null; then
            echo "Warning: Unable to finalize hook template. Please edit $hook_file manually." >&2
        fi
    fi

    chmod +x "$hook_file"
    echo "Installed pre-commit hook at $hook_file"
}
