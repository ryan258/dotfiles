#!/bin/bash

# scripts/lib/correlation_engine.sh
# Shared library for data correlation

set -euo pipefail

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")"
CORRELATE_PY="$LIB_DIR/correlate.py"

# Correlate two datasets (date-based CSV/pipe-delimited)
# Usage: correlate_two_datasets <file1> <file2> [date_col1] [val_col1] [date_col2] [val_col2]
# Column indices are 0-based
correlate_two_datasets() {
    # Check dependencies
    if ! command -v python3 &> /dev/null; then
        echo "Error: python3 is required but not installed" >&2
        return 1
    fi
    
    if [ ! -f "$CORRELATE_PY" ]; then
        echo "Error: correlate.py not found at $CORRELATE_PY" >&2
        return 1
    fi

    local file1="$1"
    local file2="$2"
    local d1="${3:-1}"
    local v1="${4:-2}"
    local d2="${5:-1}"
    local v2="${6:-2}"
    
    if [ ! -f "$file1" ]; then
        echo "Error: File $file1 not found" >&2
        return 1
    fi
    if [ ! -f "$file2" ]; then
        echo "Error: File $file2 not found" >&2
        return 1
    fi
    
    python3 "$CORRELATE_PY" correlate "$file1" "$file2" --d1 "$d1" --v1 "$v1" --d2 "$d2" --v2 "$v2"
}

# Find recurring patterns in a single dataset
# Usage: find_patterns <data_file> <pattern_type>
find_patterns() {
    local file="$1"
    local type="$2"
    # TODO: Implement pattern recognition logic
    echo "Pattern finding not implemented yet"
}

# Predict value based on historical correlations
# Usage: predict_value <historical_data> <current_inputs>
predict_value() {
    # TODO: Implement predictive modeling
    echo "Prediction not implemented yet"
}

# Generate text insight from correlation coefficient
# Usage: generate_insight_text <correlation_coefficient>
generate_insight_text() {
    local r="$1"
    
    # Check if string is a valid number
    if ! [[ "$r" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
       echo "Invalid coefficient"
       return
    fi

    # Use python for float comparison
    local strength=$(python3 -c "
r = float($r)
abs_r = abs(r)
if abs_r > 0.7: print('strong')
elif abs_r > 0.4: print('moderate')
elif abs_r > 0.2: print('weak')
else: print('negligible')
")

    local direction=$(python3 -c "print('positive' if float($r) > 0 else 'negative')")
    
    echo "Found a $strength $direction correlation (r=$r)"
}
