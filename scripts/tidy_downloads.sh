#!/bin/bash
# tidy_downloads.sh - macOS version with proper directory handling

# This line helps prevent errors if no files of a certain type are found
shopt -s nullglob 2>/dev/null || true

cd ~/Downloads || exit 1

echo "Tidying the Downloads folder..."

# Move images to Pictures
echo "Moving image files..."
for img in *.jpg *.jpeg *.png *.gif *.heic *.HEIC; do
    if [ -f "$img" ]; then
        mv "$img" ~/Pictures/
        echo "Moved: $img"
    fi
done

# Move documents to Documents
echo "Moving document files..."
for doc in *.pdf *.doc *.docx *.txt *.rtf *.pages *.md; do
    if [ -f "$doc" ]; then
        mv "$doc" ~/Documents/
        echo "Moved: $doc"
    fi
done

# Move audio/video to Music (or create a Media folder)
echo "Moving media files..."
for media in *.mp3 *.wav *.mp4 *.mov *.m4a *.aiff; do
    if [ -f "$media" ]; then
        mv "$media" ~/Music/
        echo "Moved: $media"
    fi
done

# Move archives to a specific folder
mkdir -p ~/Documents/Archives
for archive in *.zip *.tar *.gz *.rar *.7z; do
    if [ -f "$archive" ]; then
        mv "$archive" ~/Documents/Archives/
        echo "Moved: $archive"
    fi
done

echo "Downloads folder tidied!"

# ---
