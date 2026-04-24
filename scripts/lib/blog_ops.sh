#!/usr/bin/env bash
# scripts/lib/blog_ops.sh
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_BLOG_OPS_LOADED:-}" ]]; then
    return 0
fi
readonly _BLOG_OPS_LOADED=true

blog_print_review_summary() {
    local detail_limit="${BLOG_STATUS_REVIEW_DETAIL_LIMIT:-5}"
    local review_item_count=0
    local artifact_count=0
    local shown_count=0
    local hidden_count=0
    local review_items=""

    if ! [[ "$detail_limit" =~ ^[0-9]+$ ]] || [ "$detail_limit" -lt 1 ]; then
        detail_limit=5
    fi

    if [ ! -d "$DRAFTS_DIR" ]; then
        echo "  • Drafts awaiting review: 0"
        return 0
    fi

    artifact_count=$(find "$DRAFTS_DIR" -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

    if [ -d "$DRAFTS_DIR/ingest" ]; then
        while IFS= read -r session_dir; do
            local artifact_label
            local session_artifact_count
            local rel

            [ -z "$session_dir" ] && continue
            session_artifact_count=$(find "$session_dir" -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
            if [ "$session_artifact_count" -lt 1 ]; then
                continue
            fi

            rel=${session_dir#"$DRAFTS_DIR"/}
            artifact_label="artifacts"
            if [ "$session_artifact_count" -eq 1 ]; then
                artifact_label="artifact"
            fi
            review_items="${review_items}${rel} (${session_artifact_count} ${artifact_label})"$'\n'
            review_item_count=$((review_item_count + 1))
        done < <(find "$DRAFTS_DIR/ingest" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r)
    fi

    while IFS= read -r draft; do
        local rel

        [ -z "$draft" ] && continue
        rel=${draft#"$DRAFTS_DIR"/}
        review_items="${review_items}${rel}"$'\n'
        review_item_count=$((review_item_count + 1))
    done < <(find "$DRAFTS_DIR" -type f -name "*.md" ! -path "$DRAFTS_DIR/ingest/*" 2>/dev/null | sort -r)

    if [ "$review_item_count" -eq 0 ]; then
        echo "  • Drafts awaiting review: 0"
        return 0
    fi

    echo "  • Drafts awaiting review: $review_item_count item(s) across $artifact_count markdown artifact(s)"

    while IFS= read -r item; do
        [ -z "$item" ] && continue
        if [ "$shown_count" -lt "$detail_limit" ]; then
            echo "    - $item"
        fi
        shown_count=$((shown_count + 1))
    done <<< "$review_items"

    hidden_count=$((review_item_count - detail_limit))
    if [ "$hidden_count" -gt 0 ]; then
        echo "    - $hidden_count more review item(s) not shown"
    fi
}

# --- Subcommand: status ---
blog_status() {
    local total_posts
    local stub_files
    local stub_count
    local last_update
    local last_update_epoch
    local days_since

    echo "📝 BLOG STATUS (ryanleej.com):"

    total_posts=$(find "$POSTS_DIR" -name "*.md" | wc -l | tr -d ' ')
    stub_files=$(grep -l -i "content stub" "$POSTS_DIR"/*.md 2>/dev/null || true)
    if [ -n "$stub_files" ]; then
        stub_count=$(printf "%s\n" "$stub_files" | grep -c . || true)
    else
        stub_count=0
    fi

    echo "  • Total posts: $total_posts"
    echo "  • Posts needing content: $stub_count"

    blog_print_review_summary

    if [ -d "$BLOG_DIR/.git" ]; then
        last_update=$(cd "$BLOG_DIR" && git log -1 --format="%ad" --date=short)
        echo "  • Last update: $last_update"

        # Calculate days since last update
        last_update_epoch=$(cd "$BLOG_DIR" && git log -1 --format="%ct")
        days_since=$(( ( $(date +%s) - last_update_epoch ) / 86400 ))

        if [ "$days_since" -gt 14 ]; then
            echo "  ⏰ It's been $days_since days since your last update"
        fi
    fi

    echo "  • Site: https://ryanleej.com"
}

# --- Subcommand: stubs ---
blog_stubs() {
    local stub_files
    local seven_days_ago
    local thirty_days_ago

    echo "📄 CONTENT STUBS:"

    stub_files=$(grep -l -i "content stub" "$POSTS_DIR"/*.md 2>/dev/null || true)

    if [ -n "$stub_files" ]; then
        seven_days_ago=$(date_shift_days -7 "%s")
        thirty_days_ago=$(date_shift_days -30 "%s")

        while IFS= read -r file; do
            local filename
            local last_commit=""
            local mod_time
            local days_old

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
            if [ "$mod_time" -lt "$thirty_days_ago" ]; then
                days_old=$(( ( $(date +%s) - mod_time ) / 86400 ))
                echo "  ⚠️  $filename (stale: ${days_old} days old)"
            elif [ "$mod_time" -lt "$seven_days_ago" ]; then
                days_old=$(( ( $(date +%s) - mod_time ) / 86400 ))
                echo "  ⏰ $filename (${days_old} days old)"
            else
                echo "  • $filename"
            fi
        done <<< "$stub_files"
    else
        echo "  (No content stubs found)"
    fi
}

# --- Subcommand: random ---
blog_random_stub() {
    local -a stub_files=()
    local stub_file
    local random_index
    local random_file

    echo "🎲 Opening a random stub..."

    while IFS= read -r stub_file; do
        [ -z "$stub_file" ] && continue
        stub_files+=("$stub_file")
    done < <(grep -l -i "content stub" "$POSTS_DIR"/*.md 2>/dev/null || true)

    if [ ${#stub_files[@]} -eq 0 ]; then
        echo "  (No content stubs to choose from)"
        return
    fi

    random_index=$(( RANDOM % ${#stub_files[@]} ))
    random_file=${stub_files[$random_index]}

    echo "  Opening: $(basename "$random_file")"

    if command -v code &> /dev/null; then
        code "$random_file"
    else
        open "$random_file"
    fi
}

# --- Subcommand: recent ---
blog_recent() {
    local -a recent_files=()

    echo "⏳ RECENTLY MODIFIED POSTS:"

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

blog_publish_site() {
    echo "Running blog validation..."
    if ! blog_validate_site; then
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

blog_validate_site() {
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Error: python3 is required for blog validate." >&2
        return 1
    fi

    local _blog_ops_lib_dir
    _blog_ops_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    POSTS_DIR="$POSTS_DIR" DRAFTS_DIR="$DRAFTS_DIR" BLOG_DIR="$BLOG_DIR" \
        python3 "$_blog_ops_lib_dir/blog_validate.py"
}

blog_install_hooks() {
    if [ ! -d "$BLOG_DIR/.git" ]; then
        echo "Error: $BLOG_DIR is not a git repository."
        return 1
    fi

    local hook_file="$BLOG_DIR/.git/hooks/pre-commit"
    local dotfiles_root="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    # This heredoc writes a standalone hook script. Any `exit` inside it belongs
    # to the generated hook, not to this sourced library.
    cat <<'HOOK' > "$hook_file"
#!/bin/sh
BLOG_DIR="__BLOG_DIR__"
DOTFILES_DIR="__DOTFILES_DIR__"
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

    if ! python3 - "$hook_file" "$BLOG_DIR" "$dotfiles_root" <<'PY'
from pathlib import Path
import sys

hook_path = Path(sys.argv[1])
blog_dir = sys.argv[2]
dotfiles_dir = sys.argv[3]
content = hook_path.read_text(encoding="utf-8")
content = content.replace("__BLOG_DIR__", blog_dir)
content = content.replace("__DOTFILES_DIR__", dotfiles_dir)
hook_path.write_text(content, encoding="utf-8")
PY
    then
        echo "Warning: Unable to finalize hook template. Please edit $hook_file manually." >&2
    fi

    chmod +x "$hook_file"
    echo "Installed pre-commit hook at $hook_file"
}
