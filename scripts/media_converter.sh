#!/bin/bash
# media_converter.sh - Media file conversion utilities for macOS
set -euo pipefail

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

    audio_stitch)
        # Default values
        TARGET_DIR="."
        OUTPUT_FILE=""
        INPUT_FILES=()
        
        # Check if we are in "auto mode" (directory or no args) or "manual mode" (output file + input files)
        # If $2 is empty or a directory, we are in auto mode.
        if [ -z "${2:-}" ] || [ -d "${2:-}" ]; then
            if [ -n "${2:-}" ]; then
                TARGET_DIR="$2"
            fi
            
            # Get directory name for filename
            DIR_NAME=$(basename "$(cd "$TARGET_DIR" && pwd)")
            
            # Find audio files in the target directory
            # We use find to handle spaces correctly and sort by name
            while IFS= read -r -d '' file; do
                INPUT_FILES+=("$file")
            done < <(find "$TARGET_DIR" -maxdepth 1 -type f \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.m4a" -o -iname "*.aac" -o -iname "*.flac" -o -iname "*.ogg" \) -not -name "stitched_output.*" -print0 | sort -z)
            
            if [ ${#INPUT_FILES[@]} -eq 0 ]; then
                echo "No audio files found in $TARGET_DIR"
                exit 1
            fi
            
            # Determine output format
            FIRST_EXT="${INPUT_FILES[0]##*.}"
            FIRST_EXT=$(echo "$FIRST_EXT" | tr '[:upper:]' '[:lower:]')
            MIXED_FORMATS=false
            
            for file in "${INPUT_FILES[@]}"; do
                EXT="${file##*.}"
                EXT=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')
                if [ "$EXT" != "$FIRST_EXT" ]; then
                    MIXED_FORMATS=true
                    break
                fi
            done
            
            if [ "$MIXED_FORMATS" = true ]; then
                OUTPUT_FORMAT="mp3"
            else
                OUTPUT_FORMAT="$FIRST_EXT"
            fi
            
            OUTPUT_FILE="$TARGET_DIR/${DIR_NAME}.${OUTPUT_FORMAT}"
            
        else
            # Manual mode: <output_file> <input_file1> ...
            if [ $# -lt 3 ]; then
                echo "Usage: $0 audio_stitch [directory]"
                echo "       $0 audio_stitch <output_file> <input_file1> <input_file2> ..."
                echo "Requires: ffmpeg (install with: brew install ffmpeg)"
                exit 1
            fi
            
            OUTPUT_FILE="$2"
            shift 2
            INPUT_FILES=("$@")
        fi

        if ! command -v ffmpeg &> /dev/null; then
            echo "ffmpeg not found. Install with: brew install ffmpeg"
            exit 1
        fi

        # Check if all input files exist (already checked in auto mode, but good for manual)
        for file in "${INPUT_FILES[@]}"; do
            if [ ! -f "$file" ]; then
                echo "Input file not found: $file"
                exit 1
            fi
        done

        echo "Stitching ${#INPUT_FILES[@]} files into $OUTPUT_FILE..."
        
        # Construct ffmpeg input args and filter complex
        INPUT_ARGS=()
        FILTER_COMPLEX=""
        for i in "${!INPUT_FILES[@]}"; do
            INPUT_ARGS+=("-i" "${INPUT_FILES[$i]}")
            FILTER_COMPLEX+="[$i:a]"
        done
        
        FILTER_COMPLEX+="concat=n=${#INPUT_FILES[@]}:v=0:a=1[out]"

        ffmpeg -y "${INPUT_ARGS[@]}" -filter_complex "$FILTER_COMPLEX" -map "[out]" "$OUTPUT_FILE"
        
        echo "Stitching complete: $OUTPUT_FILE"
        ;;
    
    *)
        echo "Usage: $0 {video2audio|resize_image|pdf_compress|audio_stitch}"
        echo "  video2audio <file>      : Extract audio from video"
        echo "  resize_image <file> <w> : Resize image to specified width"
        echo "  pdf_compress <file>     : Compress PDF file"
        echo "  audio_stitch [dir]      : Stitch audio files in dir (default: current)"
        echo "  audio_stitch <out> <in...>: Stitch specific files"
        ;;
esac

# ---
