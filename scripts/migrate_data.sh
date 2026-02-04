#!/usr/bin/env bash
set -euo pipefail

# migrate_data.sh - Migrate dotfiles data files to pipe-delimited canonical formats

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_lib "config.sh"

usage() {
  cat <<'USAGE'
Usage: migrate_data.sh [--dry-run] [--no-backup] [--backup-dir PATH]

Options:
  --dry-run      Show planned changes without writing files
  --no-backup    Skip backup creation (not recommended)
  --backup-dir   Custom backup directory (default: ~/Backups/dotfiles-data-pre-migration-YYYYMMDDHHMMSS)
USAGE
}

DRY_RUN=false
NO_BACKUP=false
BACKUP_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --no-backup)
      NO_BACKUP=true
      shift
      ;;
    --backup-dir)
      BACKUP_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: Unknown option '$1'" >&2
      usage
      exit 2
      ;;
  esac
done

DATA_DIR_VALIDATED=$(validate_path "$DATA_DIR") || exit 1

log_info "Starting data migration${DRY_RUN:+ (dry run)}"
log_info "Data directory: $DATA_DIR_VALIDATED"

if [[ "$NO_BACKUP" = false ]]; then
  if [[ -z "$BACKUP_DIR" ]]; then
    BACKUP_DIR="$HOME/Backups/dotfiles-data-pre-migration-$(date +%Y%m%d%H%M%S)"
  fi
  BACKUP_DIR=$(validate_path "$BACKUP_DIR") || exit 1

  if [[ "$DRY_RUN" = false ]]; then
    mkdir -p "$(dirname "$BACKUP_DIR")"
    if [[ -e "$BACKUP_DIR" ]]; then
      die "Backup directory already exists: $BACKUP_DIR" "$EXIT_INVALID_ARGS"
    fi
    cp -a "$DATA_DIR_VALIDATED" "$BACKUP_DIR"
    log_info "Backup created: $BACKUP_DIR"
  else
    log_info "Dry run: would create backup at $BACKUP_DIR"
  fi
else
  log_warn "Skipping backup (--no-backup)"
fi

finalize_migration() {
  local temp_file="$1"
  local target_file="$2"
  local label="$3"
  local total="$4"
  local invalid="$5"

  if [[ "$DRY_RUN" = true ]]; then
    log_info "Dry run: would update $label (total lines: $total, unparsed: $invalid)"
    rm -f "$temp_file"
    return 0
  fi

  mv "$temp_file" "$target_file"
  chmod 600 "$target_file" || true
  log_info "Updated $label (total lines: $total, unparsed: $invalid)"
}

migrate_todo() {
  local src="$TODO_FILE"
  [[ -f "$src" ]] || return 0

  local tmp
  tmp=$(create_temp_file "todo")
  local total=0
  local invalid=0
  local today
  today=$(date +%Y-%m-%d)

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    total=$((total + 1))

    if [[ "$line" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\| ]]; then
      echo "$line" >> "$tmp"
    elif [[ "$line" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})[[:space:]]+(.*)$ ]]; then
      local date="${BASH_REMATCH[1]}"
      local text="${BASH_REMATCH[2]}"
      text=$(sanitize_input "$text")
      echo "$date|$text" >> "$tmp"
    else
      invalid=$((invalid + 1))
      local text
      text=$(sanitize_input "$line")
      echo "$today|UNPARSED: $text" >> "$tmp"
    fi
  done < "$src"

  finalize_migration "$tmp" "$src" "todo.txt" "$total" "$invalid"
}

migrate_todo_done() {
  local src="$DONE_FILE"
  [[ -f "$src" ]] || return 0

  local tmp
  tmp=$(create_temp_file "todo_done")
  local total=0
  local invalid=0
  local now
  now=$(date '+%Y-%m-%d %H:%M:%S')

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    total=$((total + 1))

    if [[ "$line" =~ ^\[([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2})\]\ (.*)$ ]]; then
      local ts="${BASH_REMATCH[1]}"
      local text="${BASH_REMATCH[2]}"
      text=$(sanitize_input "$text")
      echo "$ts|$text" >> "$tmp"
    elif [[ "$line" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2})\|(.*)$ ]]; then
      echo "$line" >> "$tmp"
    elif [[ "$line" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2})[[:space:]]+(.*)$ ]]; then
      local ts="${BASH_REMATCH[1]}"
      local text="${BASH_REMATCH[2]}"
      text=$(sanitize_input "$text")
      echo "$ts|$text" >> "$tmp"
    else
      invalid=$((invalid + 1))
      local text
      text=$(sanitize_input "$line")
      echo "$now|UNPARSED: $text" >> "$tmp"
    fi
  done < "$src"

  finalize_migration "$tmp" "$src" "todo_done.txt" "$total" "$invalid"
}

migrate_journal() {
  local src="$JOURNAL_FILE"
  [[ -f "$src" ]] || return 0

  local tmp
  tmp=$(create_temp_file "journal")
  local total=0
  local invalid=0
  local now
  now=$(date '+%Y-%m-%d %H:%M:%S')

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    total=$((total + 1))

    if [[ "$line" =~ ^\[([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2})\]\ (.*)$ ]]; then
      local ts="${BASH_REMATCH[1]}"
      local text="${BASH_REMATCH[2]}"
      text=$(sanitize_input "$text")
      echo "$ts|$text" >> "$tmp"
    elif [[ "$line" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2})\|(.*)$ ]]; then
      echo "$line" >> "$tmp"
    elif [[ "$line" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2})[[:space:]]+(.*)$ ]]; then
      local ts="${BASH_REMATCH[1]}"
      local text="${BASH_REMATCH[2]}"
      text=$(sanitize_input "$text")
      echo "$ts|$text" >> "$tmp"
    else
      invalid=$((invalid + 1))
      local text
      text=$(sanitize_input "$line")
      echo "$now|UNPARSED: $text" >> "$tmp"
    fi
  done < "$src"

  finalize_migration "$tmp" "$src" "journal.txt" "$total" "$invalid"
}

migrate_health() {
  local src="$HEALTH_FILE"
  [[ -f "$src" ]] || return 0

  local tmp
  tmp=$(create_temp_file "health")
  local total=0
  local invalid=0
  local today
  today=$(date +%Y-%m-%d)

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    total=$((total + 1))

    if [[ "$line" =~ ^UNPARSED\| ]]; then
      # Attempt to recover entries that were escaped into UNPARSED lines.
      # Expected pattern: UNPARSED|<migration_date>|TYPE\|YYYY-MM-DD HH:MM\|payload
      local payload
      payload="${line#UNPARSED|}"
      payload="${payload#*|}"
      payload="${payload//\\|/|}"

      local maybe_type maybe_date rest
      IFS='|' read -r maybe_type maybe_date rest <<< "$payload"
      if [[ "$maybe_type" =~ ^(APPT|ENERGY|SYMPTOM|FOG)$ ]] && [[ "$maybe_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}([[:space:]]+[0-9]{2}:[0-9]{2}(:[0-9]{2})?)?$ ]]; then
        if [[ -n "$rest" ]]; then
          echo "$maybe_type|$maybe_date|$rest" >> "$tmp"
        else
          echo "$maybe_type|$maybe_date" >> "$tmp"
        fi
        continue
      fi

      IFS='|' read -r -a parts <<< "$line"
      if [[ ${#parts[@]} -ge 4 ]]; then
        local fallback_type="${parts[2]}"
        local fallback_date="${parts[3]}"
        if [[ "$fallback_type" =~ ^(APPT|ENERGY|SYMPTOM|FOG)$ ]] && [[ "$fallback_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}([[:space:]]+[0-9]{2}:[0-9]{2}(:[0-9]{2})?)?$ ]]; then
          local fallback_rest=""
          if [[ ${#parts[@]} -gt 4 ]]; then
            fallback_rest=$(printf "|%s" "${parts[@]:4}")
            fallback_rest="${fallback_rest#|}"
          fi
          if [[ -n "$fallback_rest" ]]; then
            echo "$fallback_type|$fallback_date|$fallback_rest" >> "$tmp"
          else
            echo "$fallback_type|$fallback_date" >> "$tmp"
          fi
          continue
        fi
      fi
    fi

    if [[ "$line" =~ ^[^|]+\|[0-9]{4}-[0-9]{2}-[0-9]{2}([[:space:]]+[0-9]{2}:[0-9]{2}(:[0-9]{2})?)?\| ]]; then
      echo "$line" >> "$tmp"
    else
      invalid=$((invalid + 1))
      local text
      text=$(sanitize_input "$line")
      echo "UNPARSED|$today|$text" >> "$tmp"
    fi
  done < "$src"

  finalize_migration "$tmp" "$src" "health.txt" "$total" "$invalid"
}

migrate_spoons() {
  local src="$SPOON_LOG"
  [[ -f "$src" ]] || return 0

  local tmp
  tmp=$(create_temp_file "spoons")
  local total=0
  local invalid=0
  local today
  today=$(date +%Y-%m-%d)

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    total=$((total + 1))

    if [[ "$line" =~ ^BUDGET\|[0-9]{4}-[0-9]{2}-[0-9]{2}\|[0-9]+$ ]]; then
      echo "$line" >> "$tmp"
    elif [[ "$line" =~ ^SPEND\|[0-9]{4}-[0-9]{2}-[0-9]{2}\|[0-9]{2}:[0-9]{2}\|[0-9]+\| ]]; then
      echo "$line" >> "$tmp"
    else
      invalid=$((invalid + 1))
      local text
      text=$(sanitize_input "$line")
      echo "UNPARSED|$today|$text" >> "$tmp"
    fi
  done < "$src"

  finalize_migration "$tmp" "$src" "spoons.txt" "$total" "$invalid"
}

migrate_dir_bookmarks() {
  local src="$DATA_DIR/dir_bookmarks"
  [[ -f "$src" ]] || return 0

  local tmp
  tmp=$(create_temp_file "dir_bookmarks")
  local total=0
  local invalid=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    total=$((total + 1))

    if [[ "$line" =~ \| ]]; then
      echo "$line" >> "$tmp"
      continue
    fi

    local name dir on_enter venv apps
    IFS=':' read -r name dir on_enter venv apps <<< "$line"

    if [[ -z "$name" || -z "$dir" ]]; then
      invalid=$((invalid + 1))
      local text
      text=$(sanitize_input "$line")
      echo "UNPARSED|$text" >> "$tmp"
      continue
    fi

    name=$(sanitize_input "$name")
    dir=$(sanitize_input "$dir")
    on_enter=$(sanitize_input "${on_enter:-}")
    venv=$(sanitize_input "${venv:-}")
    apps=$(sanitize_input "${apps:-}")

    echo "$name|$dir|$on_enter|$venv|$apps" >> "$tmp"
  done < "$src"

  finalize_migration "$tmp" "$src" "dir_bookmarks" "$total" "$invalid"
}

migrate_favorite_apps() {
  local src="$DATA_DIR/favorite_apps"
  [[ -f "$src" ]] || return 0

  local tmp
  tmp=$(create_temp_file "favorite_apps")
  local total=0
  local invalid=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    total=$((total + 1))

    if [[ "$line" =~ \| ]]; then
      echo "$line" >> "$tmp"
      continue
    fi

    local short app
    IFS=':' read -r short app <<< "$line"

    if [[ -z "$short" || -z "$app" ]]; then
      invalid=$((invalid + 1))
      local text
      text=$(sanitize_input "$line")
      echo "UNPARSED|$text" >> "$tmp"
      continue
    fi

    short=$(sanitize_input "$short")
    app=$(sanitize_input "$app")

    echo "$short|$app" >> "$tmp"
  done < "$src"

  finalize_migration "$tmp" "$src" "favorite_apps" "$total" "$invalid"
}

normalize_history_file() {
  local src="$1"
  local label="$2"
  [[ -f "$src" ]] || return 0

  local tmp
  tmp=$(create_temp_file "$label")
  local total=0
  local invalid=0

  mapfile -t lines < "$src" || true
  local count=${#lines[@]}
  [[ $count -eq 0 ]] && finalize_migration "$tmp" "$src" "$label" 0 0 && return 0

  local base_ts
  if stat -f %m "$src" >/dev/null 2>&1; then
    base_ts=$(stat -f %m "$src")
  elif stat -c %Y "$src" >/dev/null 2>&1; then
    base_ts=$(stat -c %Y "$src")
  else
    base_ts=$(date +%s)
  fi

  local idx=0
  for line in "${lines[@]}"; do
    [[ -z "$line" ]] && continue
    total=$((total + 1))

    if [[ "$line" =~ ^([0-9]{9,})([:|])(.*)$ ]]; then
      local ts="${BASH_REMATCH[1]}"
      local path="${BASH_REMATCH[3]}"
      path=$(sanitize_input "$path")
      echo "$ts|$path" >> "$tmp"
    else
      invalid=$((invalid + 1))
      local ts=$((base_ts - (count - idx - 1)))
      local path
      path=$(sanitize_input "$line")
      echo "$ts|$path" >> "$tmp"
    fi
    idx=$((idx + 1))
  done

  finalize_migration "$tmp" "$src" "$label" "$total" "$invalid"
}

normalize_history_file "$DATA_DIR/dir_history" "dir_history"
normalize_history_file "$DATA_DIR/dir_usage.log" "dir_usage.log"

migrate_todo
migrate_todo_done
migrate_journal
migrate_health
migrate_spoons
migrate_dir_bookmarks
migrate_favorite_apps

migrate_clipboard_history() {
  local src_dir="$DATA_DIR/clipboard_history"
  local dest="$CLIPBOARD_FILE"
  local tmp
  tmp=$(create_temp_file "clipboard_history")

  local total=0
  local invalid=0

  if [[ -f "$dest" ]]; then
    cat "$dest" >> "$tmp"
  fi

  if [[ ! -d "$src_dir" ]]; then
    finalize_migration "$tmp" "$dest" "clipboard_history.txt" "$total" "$invalid"
    return 0
  fi

  encode_clipboard_content() {
    python3 - <<'PY'
import sys, codecs
data = sys.stdin.read()
encoded = codecs.encode(data, "unicode_escape").decode("ascii")
encoded = encoded.replace("|", r"\|")
sys.stdout.write(encoded)
PY
  }

  epoch_to_timestamp() {
    python3 - "$1" <<'PY'
import sys
from datetime import datetime
value = int(sys.argv[1])
print(datetime.fromtimestamp(value).strftime("%Y-%m-%d %H:%M:%S"))
PY
  }

  local file
  for file in "$src_dir"/*; do
    [[ -f "$file" ]] || continue
    local name
    name=$(basename "$file")
    local mtime
    if stat -f %m "$file" >/dev/null 2>&1; then
      mtime=$(stat -f %m "$file")
    elif stat -c %Y "$file" >/dev/null 2>&1; then
      mtime=$(stat -c %Y "$file")
    else
      mtime=$(date +%s)
    fi
    local ts
    ts=$(epoch_to_timestamp "$mtime")
    local content
    content=$(encode_clipboard_content < "$file")
    name=$(sanitize_input "$name")
    echo "$ts|$name|$content" >> "$tmp"
    total=$((total + 1))
  done

  finalize_migration "$tmp" "$dest" "clipboard_history.txt" "$total" "$invalid"
}

migrate_clipboard_history

log_info "Migration complete${DRY_RUN:+ (dry run)}"
