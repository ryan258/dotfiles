#!/usr/bin/env bash
set -euo pipefail

# repair_todo_done.sh - Merge legacy todo_done logs into canonical todo_done.txt

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_lib "config.sh"

usage() {
    cat <<'USAGE'
Usage: repair_todo_done.sh [--dry-run] [--allow-shrink] [--source PATH ...]

Merges known legacy/bak copies of todo_done into the canonical file:
  ~/.config/dotfiles-data/todo_done.txt

Options:
  --dry-run        Show what would happen without writing
  --allow-shrink   Allow overwriting canonical file with fewer lines (not recommended)
  --source PATH    Additional source file(s) to merge
USAGE
}

DRY_RUN=false
ALLOW_SHRINK=false
EXTRA_SOURCES=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --allow-shrink)
            ALLOW_SHRINK=true
            shift
            ;;
        --source)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --source requires a path" >&2
                usage
                exit "$EXIT_INVALID_ARGS"
            fi
            EXTRA_SOURCES+=("$2")
            shift 2
            ;;
        -h|--help)
            usage
            exit "$EXIT_SUCCESS"
            ;;
        *)
            echo "Error: Unknown argument: $1" >&2
            usage
            exit "$EXIT_INVALID_ARGS"
            ;;
    esac
done

_add_source() {
    local candidate="$1"
    [[ -f "$candidate" ]] || return 0

    local validated
    validated=$(validate_path "$candidate") || {
        log_warn "Skipping unsafe path: $candidate"
        return 0
    }

    local existing
    for existing in "${SOURCES[@]:-}"; do
        [[ "$existing" == "$validated" ]] && return 0
    done

    SOURCES+=("$validated")
}

ensure_data_dirs

TARGET_FILE="${DONE_FILE:?DONE_FILE is not set by config.sh}"
TARGET_FILE=$(validate_path "$TARGET_FILE") || die "Invalid DONE_FILE path: $DONE_FILE" "$EXIT_ERROR"

SOURCES=()
_add_source "$TARGET_FILE"
_add_source "$HOME/.todo_done.txt"
_add_source "$HOME/dotfiles-data-bak/todo_done.txt"

# Backups from migrate_data.sh (directory name varies in case)
for backups_root in "$HOME/backups" "$HOME/Backups"; do
    if [[ -d "$backups_root" ]]; then
        while IFS= read -r backup_file; do
            [[ -n "$backup_file" ]] || continue
            _add_source "$backup_file"
        done < <(find "$backups_root" -maxdepth 2 -type f -path "*/dotfiles-data-pre-migration-*/todo_done.txt" 2>/dev/null | sort)
    fi
done

for extra in "${EXTRA_SOURCES[@]:-}"; do
    _add_source "$extra"
done

if [[ "${#SOURCES[@]}" -eq 0 ]]; then
    die "No todo_done sources found to merge." "$EXIT_FILE_NOT_FOUND"
fi

tmp_raw=$(create_temp_file "todo_done_merge")
tmp_sorted=$(create_temp_file "todo_done_merge_sorted")

now_ts=$(date '+%Y-%m-%d %H:%M:%S')
total_in=0
unparsed=0

for src in "${SOURCES[@]}"; do
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=${line%$'\r'}
        [[ -z "$line" ]] && continue
        total_in=$((total_in + 1))

        ts=""
        text=""

        if [[ "$line" =~ ^\[([0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2})\][[:space:]]*(.*)$ ]]; then
            ts="${BASH_REMATCH[1]}"
            text="${BASH_REMATCH[2]}"
        elif [[ "$line" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2})\|(.*)$ ]]; then
            ts="${BASH_REMATCH[1]}"
            text="${BASH_REMATCH[2]}"
        elif [[ "$line" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2})[[:space:]]+(.*)$ ]]; then
            ts="${BASH_REMATCH[1]}"
            text="${BASH_REMATCH[2]}"
        else
            ts="$now_ts"
            text="UNPARSED: $line"
            unparsed=$((unparsed + 1))
        fi

        text=$(sanitize_for_storage "$text")
        printf '%s|%s\n' "$ts" "$text" >> "$tmp_raw"
    done < "$src"
done

LC_ALL=C sort -u "$tmp_raw" > "$tmp_sorted"

existing_lines=0
if [[ -f "$TARGET_FILE" ]] && [[ -s "$TARGET_FILE" ]]; then
    existing_lines=$(wc -l < "$TARGET_FILE" | tr -d ' ')
fi

merged_lines=$(wc -l < "$tmp_sorted" | tr -d ' ')

if [[ "$ALLOW_SHRINK" = false ]] && [[ "$merged_lines" -lt "$existing_lines" ]]; then
    die "Refusing to overwrite $TARGET_FILE with fewer lines ($merged_lines < $existing_lines). Use --allow-shrink to override." "$EXIT_ERROR"
fi

if [[ "$DRY_RUN" = true ]]; then
    echo "Dry run: would write $merged_lines line(s) to $TARGET_FILE"
    echo "Sources:"
    for src in "${SOURCES[@]}"; do
        echo "  - $src"
    done
    echo "Unparsed legacy line(s): $unparsed"
    exit "$EXIT_SUCCESS"
fi

backup_path="${TARGET_FILE}.bak.$(date +%Y%m%d%H%M%S)"
if [[ -f "$TARGET_FILE" ]]; then
    cp "$TARGET_FILE" "$backup_path" || die "Failed to create backup: $backup_path" "$EXIT_ERROR"
    chmod 600 "$backup_path" || true
fi

temp_target=$(mktemp "${TARGET_FILE}.XXXXXX") || die "Failed to create temp file next to $TARGET_FILE" "$EXIT_ERROR"
chmod 600 "$temp_target" || true
cat "$tmp_sorted" > "$temp_target"
mv "$temp_target" "$TARGET_FILE"
chmod 600 "$TARGET_FILE" || true

echo "Merged $total_in line(s) from ${#SOURCES[@]} source file(s) into $TARGET_FILE"
echo "Canonical entries: $merged_lines"
echo "Backup: $backup_path"
echo "Unparsed legacy line(s): $unparsed"

