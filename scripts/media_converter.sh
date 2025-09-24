#!/bin/bash
# media_converter.sh - Media file conversion utilities for macOS

format_bytes() {
    local bytes="$1"
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec -- "$bytes"
    else
        python3 <<'PY' "$bytes"
import sys
bytes_value = float(sys.argv[1]) if sys.argv[1] else 0.0
units = ["B", "KiB", "MiB", "GiB", "TiB"]
index = 0
while bytes_value >= 1024 and index < len(units) - 1:
    bytes_value /= 1024
    index += 1
print(f"{bytes_value:.1f} {units[index]}")
PY
    fi
}

case "$1" in
    video2audio)
        if [ -z "$2" ]; then
            echo "Usage: $0 video2audio <video_file>"
            echo "Requires: ffmpeg (install with: brew install ffmpeg)"
            exit 1
        fi
        
        VIDEO_FILE="$2"
        AUDIO_FILE="${VIDEO_FILE%.*}.mp3"
        
        if [ ! -f "$VIDEO_FILE" ]; then
            echo "Video file not found: $VIDEO_FILE"
            exit 1
        fi
        
        if ! command -v ffmpeg &> /dev/null; then
            echo "ffmpeg not found. Install with: brew install ffmpeg"
            exit 1
        fi
        
        echo "Converting $VIDEO_FILE to $AUDIO_FILE..."
        ffmpeg -i "$VIDEO_FILE" -q:a 0 -map a "$AUDIO_FILE"
        echo "Conversion complete: $AUDIO_FILE"
        ;;
    
    resize_image)
        if [ $# -lt 3 ]; then
            echo "Usage: $0 resize_image <image_file> <width>"
            echo "Example: $0 resize_image photo.jpg 800"
            echo "Requires: ImageMagick (install with: brew install imagemagick)"
            exit 1
        fi
        
        IMAGE_FILE="$2"
        WIDTH="$3"
        OUTPUT_FILE="${IMAGE_FILE%.*}_${WIDTH}px.${IMAGE_FILE##*.}"
        
        if [ ! -f "$IMAGE_FILE" ]; then
            echo "Image file not found: $IMAGE_FILE"
            exit 1
        fi
        
        if ! command -v convert &> /dev/null; then
            echo "ImageMagick not found. Install with: brew install imagemagick"
            exit 1
        fi
        
        echo "Resizing $IMAGE_FILE to ${WIDTH}px width..."
        convert "$IMAGE_FILE" -resize "${WIDTH}x" "$OUTPUT_FILE"
        echo "Resized image saved as: $OUTPUT_FILE"
        ;;
    
    pdf_compress)
        if [ -z "$2" ]; then
            echo "Usage: $0 pdf_compress <pdf_file>"
            echo "Requires: Ghostscript (install with: brew install ghostscript)"
            exit 1
        fi
        
        PDF_FILE="$2"
        COMPRESSED_FILE="${PDF_FILE%.*}_compressed.pdf"
        
        if [ ! -f "$PDF_FILE" ]; then
            echo "PDF file not found: $PDF_FILE"
            exit 1
        fi
        
        if ! command -v gs &> /dev/null; then
            echo "Ghostscript not found. Install with: brew install ghostscript"
            exit 1
        fi
        
        echo "Compressing $PDF_FILE..."
        gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/screen \
           -dNOPAUSE -dQUIET -dBATCH -sOutputFile="$COMPRESSED_FILE" "$PDF_FILE"
        echo "Compressed PDF saved as: $COMPRESSED_FILE"
        
        # Show size comparison
        ORIGINAL_SIZE=$(stat -f%z "$PDF_FILE")
        COMPRESSED_SIZE=$(stat -f%z "$COMPRESSED_FILE")
        echo "Original size: $(format_bytes "$ORIGINAL_SIZE")"
        echo "Compressed size: $(format_bytes "$COMPRESSED_SIZE")"
        ;;
    
    *)
        echo "Usage: $0 {video2audio|resize_image|pdf_compress}"
        echo "  video2audio <file>      : Extract audio from video"
        echo "  resize_image <file> <w> : Resize image to specified width"
        echo "  pdf_compress <file>     : Compress PDF file"
        ;;
esac

# ---
