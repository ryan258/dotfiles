#!/bin/bash
set -euo pipefail

# Default backup directory
BACKUP_DIR_DEFAULT="$HOME/Backups/dotfiles_data"

# User-configurable backup directory
BACKUP_DIR="${DOTFILES_BACKUP_DIR:-$BACKUP_DIR_DEFAULT}"

# Source directory
SOURCE_DIR="$HOME/.config/dotfiles-data"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Create the timestamped backup file
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$BACKUP_DIR/dotfiles-data-backup-$TIMESTAMP.tar.gz"

# Compress the source directory
tar -czf "$BACKUP_FILE" -C "$SOURCE_DIR" .

# Print a confirmation message (can be silenced by redirecting stdout)
echo "Backup of $SOURCE_DIR created at $BACKUP_FILE"
