#!/bin/bash
# file_organizer.sh - Organize files by type, date, or size

case "$1" in
    bytype)
        echo "Organizing files by type..."
        
        # Create directories for different file types
        mkdir -p Documents Images Audio Video Archives Code
        
        # Move files based on extension
        for file in *; do
            if [ -f "$file" ]; then
                case "${file##*.}" in
                    txt|doc|docx|pdf|rtf|pages)
                        mv "$file" Documents/
                        echo "Moved $file to Documents/"
                        ;;
                    jpg|jpeg|png|gif|bmp|tiff|heic)
                        mv "$file" Images/
                        echo "Moved $file to Images/"
                        ;;
                    mp3|wav|aiff|m4a|flac)
                        mv "$file" Audio/
                        echo "Moved $file to Audio/"
                        ;;
                    mp4|mov|avi|mkv|wmv)
                        mv "$file" Video/
                        echo "Moved $file to Video/"
                        ;;
                    zip|tar|gz|rar|7z)
                        mv "$file" Archives/
                        echo "Moved $file to Archives/"
                        ;;
                    js|py|sh|php|html|css|swift|c|cpp)
                        mv "$file" Code/
                        echo "Moved $file to Code/"
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
                mkdir -p "$YEAR/$MONTH"
                
                mv "$file" "$YEAR/$MONTH/"
                echo "Moved $file to $YEAR/$MONTH/"
            fi
        done
        ;;
    
    bysize)
        echo "Organizing files by size..."
        
        mkdir -p "Small (< 1MB)" "Medium (1-10MB)" "Large (10-100MB)" "XLarge (> 100MB)"
        
        for file in *; do
            if [ -f "$file" ]; then
                SIZE=$(stat -f%z "$file")
                
                if [ "$SIZE" -lt 1048576 ]; then
                    mv "$file" "Small (< 1MB)/"
                    echo "Moved $file to Small/"
                elif [ "$SIZE" -lt 10485760 ]; then
                    mv "$file" "Medium (1-10MB)/"
                    echo "Moved $file to Medium/"
                elif [ "$SIZE" -lt 104857600 ]; then
                    mv "$file" "Large (10-100MB)/"
                    echo "Moved $file to Large/"
                else
                    mv "$file" "XLarge (> 100MB)/"
                    echo "Moved $file to XLarge/"
                fi
            fi
        done
        ;;
    
    *)
        echo "Usage: $0 {bytype|bydate|bysize}"
        echo "  bytype  : Organize files by file type"
        echo "  bydate  : Organize files by creation date"
        echo "  bysize  : Organize files by size"
        ;;
esac

# ---