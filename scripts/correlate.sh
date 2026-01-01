#!/bin/bash

# scripts/correlate.sh
# CLI Wrapper for Correlation Engine

set -euo pipefail

# Source the shared library
source "$(dirname "${BASH_SOURCE[0]}")/lib/correlation_engine.sh"

DATA_DIR="${DATA_DIR:-$HOME/.config/dotfiles-data}"

validate_safe_path() {
    local file="$1"

    # Check file exists
    if [ ! -f "$file" ]; then
        echo "Error: File not found: $file" >&2
        return 1
    fi

    # Get real path (cross-platform)
    local real_file
    if command -v realpath &>/dev/null; then
        real_file=$(realpath "$file" 2>/dev/null || echo "$file")
    elif command -v python3 &>/dev/null; then
        # Fallback for macOS without realpath
        real_file=$(python3 -c "import os; print(os.path.realpath('$file'))" 2>/dev/null || echo "$file")
    else
        # Last resort: use the file as-is
        real_file="$file"
    fi

    # Get real DATA_DIR path
    local data_real
    if command -v realpath &>/dev/null; then
        data_real=$(realpath "$DATA_DIR" 2>/dev/null || echo "$DATA_DIR")
    else
        data_real="$DATA_DIR"
    fi

    # Allow files in DATA_DIR, /tmp, /var/tmp, or current working directory
    local pwd_real=$(pwd)

    if [[ "$real_file" == "$data_real"* ]] || \
       [[ "$real_file" == "/tmp"* ]] || \
       [[ "$real_file" == "/var/tmp"* ]] || \
       [[ "$real_file" == "$pwd_real"* ]]; then
        return 0
    fi

    # Reject system directories
    echo "Error: File must be in DATA_DIR ($DATA_DIR), /tmp, or current directory" >&2
    echo "Attempted: $real_file" >&2
    return 1
}

show_help() {
    echo "Usage: $(basename "$0") {run|find-patterns|explain}"
    echo ""
    echo "Commands:"
    echo "  run <file1> <file2> [d1] [v1] [d2] [v2]"
    echo "       Calculate correlation between two datasets."
    echo "       d1/v1: Date/Value column index for file 1 (0-based)"
    echo "       d2/v2: Date/Value column index for file 2 (0-based)"
    echo ""
    echo "  find-patterns <file>"
    echo "       Find recurring patterns in a single dataset (Not Implemented)"
    echo ""
    echo "  explain <correlation_id>"
    echo "       Explain a correlation insight (Not Implemented)"
}

case "${1:-}" in
    run)
        if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
            echo "Error: Datasets required" >&2
            echo "Usage: $(basename "$0") run <file1> <file2>" >&2
            exit 1
        fi
        
        file1="$2"
        file2="$3"
        d1="${4:-1}"
        v1="${5:-2}"
        d2="${6:-1}"
        v2="${7:-2}"
        
        # Validate safe paths (basic check against system dirs)
        validate_safe_path "$file1" || exit 1
        validate_safe_path "$file2" || exit 1
        
        # Validate indices are numeric
        if ! [[ "$d1" =~ ^[0-9]+$ ]] || ! [[ "$v1" =~ ^[0-9]+$ ]] || \
           ! [[ "$d2" =~ ^[0-9]+$ ]] || ! [[ "$v2" =~ ^[0-9]+$ ]]; then
            echo "Error: Column indices must be numbers" >&2
            exit 1
        fi
        
        correlate_two_datasets "$file1" "$file2" "$d1" "$v1" "$d2" "$v2"
        ;;
        
    find-patterns)
        if [ -z "${2:-}" ]; then
            echo "Error: File required" >&2
            exit 1
        fi
        find_patterns "$2" "general"
        ;;
        
    explain)
        echo "Correlation explanation features Coming Soon (tm)"
        ;;
        
    *)
        show_help
        exit 1
        ;;
esac
