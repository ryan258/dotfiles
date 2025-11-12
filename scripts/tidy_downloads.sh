#!/bin/bash
# tidy_downloads.sh - macOS version with proper directory handling
set -euo pipefail

DRY_RUN=false
FORCE_MODE=false
IGNORE_FILE="$HOME/.config/dotfiles-data/tidy_ignore.txt"

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --dry-run|-n)
      DRY_RUN=true
      echo "Performing a dry run. No files will be moved."
      ;;
    --force)
      FORCE_MODE=true
      echo "Force mode enabled. Safety checks will be bypassed."
      ;;
  esac
done

# This line helps prevent errors if no files of a certain type are found
shopt -s nullglob 2>/dev/null || true

cd ~/Downloads || exit 1

# Load ignore patterns
declare -a IGNORE_PATTERNS
if [ -f "$IGNORE_FILE" ]; then
  while IFS= read -r pattern; do
    # Skip empty lines and comments
    [[ -z "$pattern" || "$pattern" =~ ^# ]] && continue
    IGNORE_PATTERNS+=("$pattern")
  done < "$IGNORE_FILE"
fi

# Function to check if file should be ignored
should_ignore() {
  local file="$1"

  # Check if file was modified in the last 60 seconds (actively being downloaded)
  if [ "$FORCE_MODE" = false ]; then
    local mod_time; mod_time=$(stat -f %m "$file" 2>/dev/null || echo 0)
    local now; now=$(date +%s)
    local age=$((now - mod_time))
    if [ "$age" -lt 60 ]; then
      return 0  # Ignore (true)
    fi
  fi

  # Check against ignore patterns
  for pattern in "${IGNORE_PATTERNS[@]}"; do
    if [[ $file == $pattern ]]; then
      return 0  # Ignore (true)
    fi
  done

  return 1  # Don't ignore (false)
}

echo "Tidying the Downloads folder..."

# Move images to Pictures
echo "Moving image files..."
for img in *.jpg *.jpeg *.png *.gif *.heic *.HEIC; do
    if [ -f "$img" ]; then
        if should_ignore "$img"; then
            echo "  Skipped: $img (recently modified or in ignore list)"
            continue
        fi
        if [ "$DRY_RUN" = true ]; then
            echo "  Would move $img to ~/Pictures/"
        else
            mv "$img" ~/Pictures/
            echo "  Moved: $img"
        fi
    fi
done

# Move documents to Documents
echo "Moving document files..."
for doc in *.pdf *.doc *.docx *.txt *.rtf *.pages *.md; do
    if [ -f "$doc" ]; then
        if should_ignore "$doc"; then
            echo "  Skipped: $doc (recently modified or in ignore list)"
            continue
        fi
        if [ "$DRY_RUN" = true ]; then
            echo "  Would move $doc to ~/Documents/"
        else
            mv "$doc" ~/Documents/
            echo "  Moved: $doc"
        fi
    fi
done

# Move audio/video to Music (or create a Media folder)
echo "Moving media files..."
for media in *.mp3 *.wav *.mp4 *.mov *.m4a *.aiff; do
    if [ -f "$media" ]; then
        if should_ignore "$media"; then
            echo "  Skipped: $media (recently modified or in ignore list)"
            continue
        fi
        if [ "$DRY_RUN" = true ]; then
            echo "  Would move $media to ~/Music/"
        else
            mv "$media" ~/Music/
            echo "  Moved: $media"
        fi
    fi
done

# Move archives to a specific folder
if [ "$DRY_RUN" = false ]; then
    mkdir -p ~/Documents/Archives
fi
for archive in *.zip *.tar *.gz *.rar *.7z; do
    if [ -f "$archive" ]; then
        if should_ignore "$archive"; then
            echo "  Skipped: $archive (recently modified or in ignore list)"
            continue
        fi
        if [ "$DRY_RUN" = true ]; then
            echo "  Would move $archive to ~/Documents/Archives/"
        else
            mv "$archive" ~/Documents/Archives/
            echo "  Moved: $archive"
        fi
    fi
done

echo "Downloads folder tidied!"
