#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# Source shared utilities
if [ -f "$DOTFILES_DIR/bin/dhp-utils.sh" ]; then
    # shellcheck disable=SC1090
    source "$DOTFILES_DIR/bin/dhp-utils.sh"
else
    echo "Error: Shared utility library dhp-utils.sh not found." >&2
    exit 1
fi

if [ -f "$SCRIPT_DIR/lib/config.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/config.sh"
fi

# Validate dependencies
if ! validate_dependencies tar; then
    exit 1
fi

# Configuration
BACKUP_DIR_DEFAULT="$HOME/Backups/dotfiles_data"
BACKUP_DIR="${DOTFILES_BACKUP_DIR:-$BACKUP_DIR_DEFAULT}"
SOURCE_DIR="${DATA_DIR:-$HOME/.config/dotfiles-data}"
GDRIVE_REMOTE="gdrive"
GDRIVE_FOLDER="Backups/dotfiles_data"

# Validate paths
SOURCE_DIR=$(validate_path "$SOURCE_DIR") || exit 1
BACKUP_DIR=$(validate_path "$BACKUP_DIR") || exit 1

# Pre-flight checks
if [ ! -d "$SOURCE_DIR" ] || [ ! -r "$SOURCE_DIR" ]; then
  echo "Error: Source data directory not found or not readable: $SOURCE_DIR" >&2
  exit 1
fi

# Create local backup directory
mkdir -p "$BACKUP_DIR"
if [ ! -w "$BACKUP_DIR" ]; then
  echo "Error: Backup directory is not writable: $BACKUP_DIR" >&2
  exit 1
fi

# Create the timestamped backup file
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILENAME="dotfiles-data-backup-$TIMESTAMP.tar.gz"
BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILENAME"

# Compress the source directory
echo "Creating local backup..."
tar -czf "$BACKUP_FILE" -C "$SOURCE_DIR" .
echo "✅ Local backup created at $BACKUP_FILE"

# Upload to Google Drive if rclone is available and configured
if command -v rclone >/dev/null 2>&1; then
    if rclone listremotes | grep -q "^$GDRIVE_REMOTE:"; then
        echo "Uploading to Google Drive ($GDRIVE_REMOTE:$GDRIVE_FOLDER)..."
        if rclone copy "$BACKUP_FILE" "$GDRIVE_REMOTE:$GDRIVE_FOLDER"; then
            echo "✅ Offsite backup successful."
        else
            echo "⚠️ Offsite backup failed (rclone return code $?)."
        fi
    else
        echo "ℹ️ Remote '$GDRIVE_REMOTE' not found. Skipping offsite backup."
    fi
else
    echo "ℹ️ rclone not installed. Skipping offsite backup."
fi
