#!/bin/bash
# file_organizer.sh - Organize files by type, date, or size

DRY_RUN=false
if [ "${2:-}" == "--dry-run" ] || [ "${2:-}" == "-n" ]; then
  DRY_RUN=true
  echo "Performing a dry run. No files will be moved."
fi

case "$1" in
    bytype)
        echo "Organizing files by type..."
        
        # Create directories for different file types
        if [ "$DRY_RUN" = false ]; then
            mkdir -p Documents Images Audio Video Archives Code
        fi
        
        # Move files based on extension
        for file in *; do
            if [ -f "$file" ]; then
                case "${file##*.}" in
                    txt|doc|docx|pdf|rtf|pages)
                        if [ "$DRY_RUN" = true ]; then echo "  Would move $file to Documents/"; else mv "$file" Documents/; echo "  Moved $file to Documents/"; fi
                        ;;
                    jpg|jpeg|png|gif|bmp|tiff|heic)
                        if [ "$DRY_RUN" = true ]; then echo "  Would move $file to Images/"; else mv "$file" Images/; echo "  Moved $file to Images/"; fi
                        ;;
                    mp3|wav|aiff|m4a|flac)
                        if [ "$DRY_RUN" = true ]; then echo "  Would move $file to Audio/"; else mv "$file" Audio/; echo "  Moved $file to Audio/"; fi
                        ;;
                    mp4|mov|avi|mkv|wmv)
                        if [ "$DRY_RUN" = true ]; then echo "  Would move $file to Video/"; else mv "$file" Video/; echo "  Moved $file to Video/"; fi
                        ;;
                    zip|tar|gz|rar|7z)
                        if [ "$DRY_RUN" = true ]; then echo "  Would move $file to Archives/"; else mv "$file" Archives/; echo "  Moved $file to Archives/"; fi
                        ;;
                    js|py|sh|php|html|css|swift|c|cpp)
                        if [ "$DRY_RUN" = true ]; then echo "  Would move $file to Code/"; else mv "$file" Code/; echo "  Moved $file to Code/"; fi
                        ;;
                esac
            fi
        done
        ;;
    
    bydate)
        echo "Organizing files by date..."
        
        for file in *; do
            if [ -f "$file" ]; then
                # Get file creation date
                YEAR=$(stat -f "%SB" -t "%Y" "$file")
                MONTH=$(stat -f "%SB" -t "%m" "$file")
                
                # Create directory structure
                if [ "$DRY_RUN" = false ]; then mkdir -p "$YEAR/$MONTH"; fi
                
                if [ "$DRY_RUN" = true ]; then echo "  Would move $file to $YEAR/$MONTH/"; else mv "$file" "$YEAR/$MONTH/"; echo "  Moved $file to $YEAR/$MONTH/"; fi
            fi
        done
        ;;
    
    bysize)
        echo "Organizing files by size..."
        
        if [ "$DRY_RUN" = false ]; then mkdir -p "Small (< 1MB)" "Medium (1-10MB)" "Large (10-100MB)" "XLarge (> 100MB)"; fi
        
        for file in *; do
            if [ -f "$file" ]; then
                SIZE=$(stat -f%z "$file")
                
                if [ "$SIZE" -lt 1048576 ]; then
                    if [ "$DRY_RUN" = true ]; then echo "  Would move $file to Small (< 1MB)/"; else mv "$file" "Small (< 1MB)/"; echo "  Moved $file to Small/"; fi
                elif [ "$SIZE" -lt 10485760 ]; then
                    if [ "$DRY_RUN" = true ]; then echo "  Would move $file to Medium (1-10MB)/"; else mv "$file" "Medium (1-10MB)/"; echo "  Moved $file to Medium/"; fi
                elif [ "$SIZE" -lt 104857600 ]; then
                    if [ "$DRY_RUN" = true ]; then echo "  Would move $file to Large (10-100MB)/"; else mv "$file" "Large (10-100MB)/"; echo "  Moved $file to Large/"; fi
                else
                    if [ "$DRY_RUN" = true ]; then echo "  Would move $file to XLarge (> 100MB)/"; else mv "$file" "XLarge (> 100MB)/"; echo "  Moved $file to XLarge/"; fi
                fi
            fi
        done
        ;;
    
    *)
        echo "Usage: $0 {bytype|bydate|bysize} [--dry-run|-n]"
        echo "  bytype  : Organize files by file type"
        echo "  bydate  : Organize files by creation date"
        echo "  bysize  : Organize files by size"
        ;;
esac