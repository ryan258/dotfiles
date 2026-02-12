#!/usr/bin/env bash
# backup_project.sh - Creates incremental backups using rsync

# Stop the script if any command fails
set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
DHP_UTILS="$DOTFILES_DIR/bin/dhp-utils.sh"
if [ -f "$DHP_UTILS" ]; then
    # shellcheck disable=SC1090
    source "$DHP_UTILS"
else
    echo "Error: Shared utility library dhp-utils.sh not found." >&2
    exit 1
fi

# Validate dependencies
if ! validate_dependencies rsync; then
    exit 1
fi

echo "Starting backup of current project..."

# The source folder you want to back up (current directory)
SOURCE_DIR="$(pwd)"
VALIDATED_SOURCE_DIR=$(validate_path "$SOURCE_DIR") || exit 1
SOURCE_DIR="$VALIDATED_SOURCE_DIR"

# Where the backup should go (change this to your preferred location)
DEST_DIR="$HOME/Backups"
VALIDATED_DEST_DIR=$(validate_path "$DEST_DIR") || exit 1
DEST_DIR="$VALIDATED_DEST_DIR"

# Google Drive Configuration
GDRIVE_REMOTE="gdrive"
GDRIVE_BASE_FOLDER="Backups"

# Create backup directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Create a timestamp for this backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PROJECT_NAME=$(basename "$SOURCE_DIR")
BACKUP_NAME="backup_${PROJECT_NAME}_${TIMESTAMP}"
FULL_BACKUP_PATH="$DEST_DIR/$BACKUP_NAME"

echo "Backing up $SOURCE_DIR to $FULL_BACKUP_PATH"

# Perform local backup
rsync -avh --progress "$SOURCE_DIR/" "$FULL_BACKUP_PATH"

echo ""
echo "✅ Local backup complete! Files are safe at:"
echo "$FULL_BACKUP_PATH"

# Offsite Backup
if command -v rclone >/dev/null 2>&1; then
    if rclone listremotes | grep -q "^$GDRIVE_REMOTE:"; then
        echo ""
        echo "Uploading to Google Drive ($GDRIVE_REMOTE:$GDRIVE_BASE_FOLDER/$BACKUP_NAME)..."
        # We copy the *content* of the backup folder to a matching folder in Drive
        if rclone copy "$FULL_BACKUP_PATH" "$GDRIVE_REMOTE:$GDRIVE_BASE_FOLDER/$BACKUP_NAME"; then
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
