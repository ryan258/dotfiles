#!/usr/bin/env bash
# archive_manager.sh - Archive management utilities
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/common.sh"
fi

sanitize_arg() {
    local value
    value=$(sanitize_input "$1")
    value=${value//$'\n'/ }
    printf '%s' "$value"
}

MODE="${1:-}"

case "$MODE" in
    create)
        if [ $# -lt 3 ]; then
            echo "Usage: $0 create <archive_name> <files/folders...>"
            echo "Supported formats: .zip, .tar.gz"
            exit 1
        fi
        
        ARCHIVE_NAME=$(sanitize_arg "$2")
        if [ -z "$ARCHIVE_NAME" ]; then
            echo "Error: Archive name is required." >&2
            exit 1
        fi
        if [[ "$ARCHIVE_NAME" == -* ]]; then
            echo "Error: Archive name cannot start with '-'." >&2
            exit 1
        fi

        ARCHIVE_DIR=$(dirname "$ARCHIVE_NAME")
        ARCHIVE_DIR=$(validate_path "$ARCHIVE_DIR") || exit 1
        ARCHIVE_BASE=$(basename "$ARCHIVE_NAME")
        ARCHIVE_NAME="$ARCHIVE_DIR/$ARCHIVE_BASE"

        shift 2
        FILES=()
        for f in "$@"; do
            f=$(sanitize_arg "$f")
            f=$(validate_path "$f") || exit 1
            if [ ! -e "$f" ]; then
                echo "File not found: $f" >&2
                exit 1
            fi
            FILES+=("$f")
        done

        case "$ARCHIVE_NAME" in
            *.zip)
                echo "Creating ZIP archive: $ARCHIVE_NAME"
                zip -r -- "$ARCHIVE_NAME" "${FILES[@]}"
                ;;
            *.tar.gz)
                echo "Creating TAR.GZ archive: $ARCHIVE_NAME"
                tar -czf "$ARCHIVE_NAME" -- "${FILES[@]}"
                ;;
            *)
                echo "Unsupported format. Use .zip or .tar.gz extension"
                exit 1
                ;;
        esac
        
        echo "Archive created: $ARCHIVE_NAME"
        ;;
    
    extract)
        if [ -z "${2:-}" ]; then
            echo "Usage: $0 extract <archive_file>"
            exit 1
        fi
        
        ARCHIVE_FILE=$(sanitize_arg "$2")
        ARCHIVE_FILE=$(validate_path "$ARCHIVE_FILE") || exit 1
        
        if [ ! -f "$ARCHIVE_FILE" ]; then
            echo "Archive file not found: $ARCHIVE_FILE"
            exit 1
        fi
        
        echo "Extracting: $ARCHIVE_FILE"
        
        case "$ARCHIVE_FILE" in
            *.zip)
                unzip "$ARCHIVE_FILE"
                ;;
            *.tar.gz|*.tgz)
                tar -xzf "$ARCHIVE_FILE"
                ;;
            *.tar)
                tar -xf "$ARCHIVE_FILE"
                ;;
            *.rar)
                if command -v unrar &> /dev/null; then
                    unrar x "$ARCHIVE_FILE"
                else
                    echo "unrar not found. Install with: brew install unrar"
                fi
                ;;
            *)
                echo "Unsupported archive format"
                exit 1
                ;;
        esac
        
        echo "Extraction complete"
        ;;
    
    list)
        if [ -z "${2:-}" ]; then
            echo "Usage: $0 list <archive_file>"
            exit 1
        fi
        
        ARCHIVE_FILE=$(sanitize_arg "$2")
        ARCHIVE_FILE=$(validate_path "$ARCHIVE_FILE") || exit 1
        
        if [ ! -f "$ARCHIVE_FILE" ]; then
            echo "Archive file not found: $ARCHIVE_FILE"
            exit 1
        fi
        
        echo "Contents of: $ARCHIVE_FILE"
        
        case "$ARCHIVE_FILE" in
            *.zip)
                unzip -l "$ARCHIVE_FILE"
                ;;
            *.tar.gz|*.tgz)
                tar -tzf "$ARCHIVE_FILE"
                ;;
            *.tar)
                tar -tf "$ARCHIVE_FILE"
                ;;
            *)
                echo "Listing not supported for this format"
                ;;
        esac
        ;;
    
    ""|*)
        echo "Usage: $0 {create|extract|list}"
        echo "  create <archive> <files>  : Create new archive"
        echo "  extract <archive>         : Extract archive"
        echo "  list <archive>           : List archive contents"
        exit 1
        ;;
esac
