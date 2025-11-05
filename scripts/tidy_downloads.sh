#!/bin/bash
# tidy_downloads.sh - macOS version with proper directory handling

DRY_RUN=false
if [ "${1:-}" == "--dry-run" ] || [ "${1:-}" == "-n" ]; then
  DRY_RUN=true
  echo "Performing a dry run. No files will be moved."
fi

# This line helps prevent errors if no files of a certain type are found
shopt -s nullglob 2>/dev/null || true

cd ~/Downloads || exit 1

echo "Tidying the Downloads folder..."

# Move images to Pictures
echo "Moving image files..."
for img in *.jpg *.jpeg *.png *.gif *.heic *.HEIC; do
    if [ -f "$img" ]; then
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
        if [ "$DRY_RUN" = true ]; then
            echo "  Would move $archive to ~/Documents/Archives/"
        else
            mv "$archive" ~/Documents/Archives/
            echo "  Moved: $archive"
        fi
    fi
done

echo "Downloads folder tidied!"
