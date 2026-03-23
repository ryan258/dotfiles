#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [[ "$#" -lt 1 ]]; then
    die "Usage: cyborg_scoped_site_check.sh content/path-one.md [content/path-two.md ...]" "$EXIT_INVALID_ARGS"
fi

require_cmd "uv" "Install with: brew install uv"

REPO_ROOT="$(pwd)"
TMP_LAB="$(mktemp -d /tmp/cyborg-sync-lab-XXXXXX)"

cleanup() {
    rm -rf "$TMP_LAB"
}
trap cleanup EXIT

copy_target() {
    local rel_path="$1"
    local sanitized
    local source_path
    local target_path

    sanitized="$(sanitize_input "$rel_path")"
    if [[ -z "$sanitized" ]]; then
        die "Scoped site check received an empty path." "$EXIT_INVALID_ARGS"
    fi
    if [[ "$sanitized" != content/* ]]; then
        die "Scoped site check only accepts content/ paths: $sanitized" "$EXIT_INVALID_ARGS"
    fi
    if [[ "$sanitized" == *".."* ]]; then
        die "Scoped site check path must not contain '..': $sanitized" "$EXIT_INVALID_ARGS"
    fi

    source_path="$REPO_ROOT/$sanitized"
    if [[ ! -f "$source_path" ]]; then
        die "Scoped site check target not found: $sanitized" "$EXIT_FILE_NOT_FOUND"
    fi

    target_path="$TMP_LAB/$sanitized"
    mkdir -p "$(dirname "$target_path")"
    cp "$source_path" "$target_path"
}

for rel_path in "$@"; do
    copy_target "$rel_path"
done

PYTHONPATH=. uv run python lib/content_governance.py \
    --repo-root "$TMP_LAB" \
    --min-nav-published 0 \
    --stale-draft-days 10000 \
    --fail-on warn

PYTHONPATH=. uv run python lib/site_validator.py --content-dir "$TMP_LAB/content" --lab-dir .
