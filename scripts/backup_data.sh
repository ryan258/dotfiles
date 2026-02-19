#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
COMMON_LIB="$SCRIPT_DIR/lib/common.sh"

if [ -f "$COMMON_LIB" ]; then
    # shellcheck disable=SC1090
    source "$COMMON_LIB"
else
    echo "Error: common utilities not found at $COMMON_LIB" >&2
    exit 1
fi

# Source shared utilities
if [ -f "$DOTFILES_DIR/bin/dhp-utils.sh" ]; then
    # shellcheck disable=SC1090
    source "$DOTFILES_DIR/bin/dhp-utils.sh"
else
    die "Shared utility library dhp-utils.sh not found." "$EXIT_FILE_NOT_FOUND"
fi

if [ -f "$SCRIPT_DIR/lib/config.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/config.sh"
else
    die "configuration library not found at $SCRIPT_DIR/lib/config.sh" "$EXIT_FILE_NOT_FOUND"
fi
if [ -f "$SCRIPT_DIR/lib/date_utils.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/date_utils.sh"
else
    die "date utilities not found at $SCRIPT_DIR/lib/date_utils.sh" "$EXIT_FILE_NOT_FOUND"
fi

# Validate dependencies
validate_dependencies tar || die "Required dependency validation failed (tar)." "$EXIT_FILE_NOT_FOUND"

# Configuration
BACKUP_DIR_DEFAULT="$HOME/Backups/dotfiles_data"
BACKUP_DIR="${DOTFILES_BACKUP_DIR:-$BACKUP_DIR_DEFAULT}"
SOURCE_DIR="$DATA_DIR"
GDRIVE_REMOTE="gdrive"
GDRIVE_FOLDER="Backups/dotfiles_data"

# Validate paths
SOURCE_DIR=$(validate_path "$SOURCE_DIR") || die "Invalid source directory path: $SOURCE_DIR" "$EXIT_INVALID_ARGS"
BACKUP_DIR=$(validate_path "$BACKUP_DIR") || die "Invalid backup directory path: $BACKUP_DIR" "$EXIT_INVALID_ARGS"

# Pre-flight checks
if [ ! -d "$SOURCE_DIR" ] || [ ! -r "$SOURCE_DIR" ]; then
  die "Source data directory not found or not readable: $SOURCE_DIR" "$EXIT_FILE_NOT_FOUND"
fi

# Create local backup directory
mkdir -p "$BACKUP_DIR"
if [ ! -w "$BACKUP_DIR" ]; then
  die "Backup directory is not writable: $BACKUP_DIR" "$EXIT_PERMISSION"
fi

# Create the timestamped backup file
TIMESTAMP=$(date_now "%Y-%m-%d_%H-%M-%S")
BACKUP_FILENAME="dotfiles-data-backup-$TIMESTAMP.tar.gz"
BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILENAME"

# Compress the source directory
echo "Creating local backup..."
tar -czf "$BACKUP_FILE" -C "$SOURCE_DIR" .
chmod 600 "$BACKUP_FILE"
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
