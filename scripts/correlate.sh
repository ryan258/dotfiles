#!/bin/bash

# scripts/correlate.sh
# CLI Wrapper for Correlation Engine

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/lib/common.sh"

# Source the correlation engine library
source "$SCRIPT_DIR/lib/correlation_engine.sh"

DATA_DIR="${DATA_DIR:-$HOME/.config/dotfiles-data}"

# Resolve to an absolute path with best-effort portability (macOS/Linux)
resolve_path() {
    local path="$1"
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$path" <<'PY'
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
    else
        if [[ "$path" = /* ]]; then
            echo "$path"
        else
            echo "$(pwd -P)/$path"
        fi
    fi
}

# Wrapper for path validation that allows multiple safe directories
validate_correlate_path() {
    local file="$1"

    # Check file exists
    if [[ ! -f "$file" ]]; then
        echo "Error: File not found: $file" >&2
        return 1
    fi

    # Get real path
    local real_file
    real_file=$(resolve_path "$file")

    # Get real DATA_DIR path
    local data_real
    data_real=$(resolve_path "$DATA_DIR")

    # Allow files in DATA_DIR, /tmp, /var/tmp, or current working directory
    local pwd_real
    pwd_real=$(pwd -P)

    if [[ "$real_file" == "$data_real"* ]] || \
       [[ "$real_file" == "/tmp"* ]] || \
       [[ "$real_file" == "/var/tmp"* ]] || \
       [[ "$real_file" == "$pwd_real"* ]]; then
        return 0
    fi

    echo "Error: File must be in DATA_DIR ($DATA_DIR), /tmp, or current directory" >&2
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
        if [[ -z "${2:-}" ]] || [[ -z "${3:-}" ]]; then
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

        # Validate safe paths
        validate_correlate_path "$file1" || exit 1
        validate_correlate_path "$file2" || exit 1

        # Validate indices are numeric using common library
        validate_numeric "$d1" "date column 1" || exit 1
        validate_numeric "$v1" "value column 1" || exit 1
        validate_numeric "$d2" "date column 2" || exit 1
        validate_numeric "$v2" "value column 2" || exit 1

        correlate_two_datasets "$file1" "$file2" "$d1" "$v1" "$d2" "$v2"
        ;;

    find-patterns)
        if [[ -z "${2:-}" ]]; then
            echo "Error: File required" >&2
            exit 1
        fi
        echo "Pattern detection is not yet implemented."
        echo "This feature will analyze data for recurring patterns."
        ;;

    explain)
        echo "Correlation explanation is not yet implemented."
        echo "This feature will provide insights on correlation results."
        ;;
        
    *)
        show_help
        exit 1
        ;;
esac
