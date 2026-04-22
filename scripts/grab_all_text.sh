#!/usr/bin/env bash
set -euo pipefail

# grab_all_text.sh - Copy readable text files into one clipboard bundle.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Use git ignore rules when we can, but still work in plain folders.
is_git_worktree() {
    command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

should_skip_file() {
    local file_path="$1"

    case "$file_path" in
        "./all_text_contents.txt")
            return 0
            ;;
    esac

    if is_git_worktree && git check-ignore --quiet --no-index -- "$file_path"; then
        return 0
    fi

    return 1
}

# Build the bundle in a temp file so failed runs do not leave junk behind.
main() {
    require_cmd "pbcopy"

    local temp_output
    temp_output="$(mktemp "${TMPDIR:-/tmp}/graballtext.XXXXXX")"
    trap "rm -f '$temp_output'" EXIT

    local copied_count=0
    local file_path

    # Keep generated, ignored, and binary files out of the clipboard bundle.
    while IFS= read -r -d '' file_path; do
        if should_skip_file "$file_path"; then
            continue
        fi

        if grep -Iq . "$file_path"; then
            cat "$file_path" >> "$temp_output"
            copied_count=$((copied_count + 1))
        fi
    done < <(
        # Skip git internals and old zsh session logs.
        find . \
            \( -path "./.git" -o -path "./zsh/.zsh_sessions" \) -prune \
            -o -type f -print0
    )

    if [[ "$copied_count" -eq 0 ]]; then
        die "No readable non-ignored text files found to copy" "$EXIT_FILE_NOT_FOUND"
    fi

    pbcopy < "$temp_output" || die "Failed to copy text bundle to clipboard" "$EXIT_SERVICE_ERROR"
    echo "Copied readable non-ignored text from $copied_count file(s) to the clipboard."
}

main "$@"
