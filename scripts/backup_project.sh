#!/bin/bash
# backup_project.sh - Creates incremental backups using rsync

# Stop the script if any command fails
set -e

# Source shared utilities
if [ -f "$HOME/dotfiles/bin/dhp-utils.sh" ]; then
    # shellcheck disable=SC1090
    source "$HOME/dotfiles/bin/dhp-utils.sh"
else
    echo "Error: Shared utility library dhp-utils.sh not found." >&2
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

# Create backup directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Create a timestamp for this backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_$(basename "$SOURCE_DIR")_$TIMESTAMP"

echo "Backing up $SOURCE_DIR to $DEST_DIR/$BACKUP_NAME"

rsync -avh --progress "$SOURCE_DIR" "$DEST_DIR/$BACKUP_NAME"

echo ""
echo "Backup complete! Files are safe at:"
echo "$DEST_DIR/$BACKUP_NAME"