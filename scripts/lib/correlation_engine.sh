#!/usr/bin/env bash
# scripts/lib/correlation_engine.sh
# Shared library for data correlation
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_CORRELATION_ENGINE_LOADED:-}" ]]; then
    return 0
fi
readonly _CORRELATION_ENGINE_LOADED=true

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")"
CORRELATE_PY="$LIB_DIR/correlate.py"
readonly CORRELATION_MIN_OVERLAP_WARN=5
readonly CORRELATION_PREDICT_WINDOW=3

_correlation_require_python() {
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Error: python3 is required but not installed" >&2
        return 1
    fi
}

_correlation_has_python_engine() {
    [[ -f "$CORRELATE_PY" ]]
}

_correlation_inline_correlate() {
    local file1="$1"
    local file2="$2"
    local d1="$3"
    local v1="$4"
    local d2="$5"
    local v2="$6"
    local min_overlap="${7:-$CORRELATION_MIN_OVERLAP_WARN}"

    python3 - "$file1" "$file2" "$d1" "$v1" "$d2" "$v2" "$min_overlap" <<'PY'
import math
import sys

file1, file2 = sys.argv[1], sys.argv[2]
d1, v1, d2, v2 = map(int, sys.argv[3:7])
min_overlap = int(sys.argv[7])

def split_row(line: str):
    if "|" in line:
        return line.split("|")
    if "," in line:
        return line.split(",")
    return line.split()

def load(path: str, date_idx: int, value_idx: int):
    data = {}
    with open(path, "r", encoding="utf-8", errors="ignore") as handle:
        for raw in handle:
            row = raw.strip()
            if not row:
                continue
            parts = split_row(row)
            if len(parts) <= max(date_idx, value_idx):
                continue
            date_key = parts[date_idx].split(" ")[0]
            try:
                value = float(parts[value_idx])
            except ValueError:
                continue
            data.setdefault(date_key, []).append(value)
    return {day: (sum(vals) / len(vals)) for day, vals in data.items()}

def pearson(xs, ys):
    n = len(xs)
    if n < 2:
        return 0.0
    sum_x = sum(xs)
    sum_y = sum(ys)
    sum_x_sq = sum(x * x for x in xs)
    sum_y_sq = sum(y * y for y in ys)
    sum_xy = sum(x * y for x, y in zip(xs, ys))
    numerator = sum_xy - (sum_x * sum_y / n)
    denominator = math.sqrt((sum_x_sq - sum_x**2 / n) * (sum_y_sq - sum_y**2 / n))
    if denominator == 0:
        return 0.0
    return numerator / denominator

dataset1 = load(file1, d1, v1)
dataset2 = load(file2, d2, v2)
overlap = sorted(set(dataset1.keys()) & set(dataset2.keys()))

if len(overlap) == 0:
    print(f"Error: No overlapping dates between {file1} and {file2}", file=sys.stderr)
    sys.exit(1)
if len(overlap) < min_overlap:
    print(
        f"Warning: Only {len(overlap)} overlapping data points (recommended minimum: {min_overlap})",
        file=sys.stderr,
    )

xs = [dataset1[d] for d in overlap]
ys = [dataset2[d] for d in overlap]
print(f"{pearson(xs, ys):.4f}")
PY
}

_correlation_inline_patterns() {
    local file="$1"
    local date_col="$2"
    local value_col="$3"

    python3 - "$file" "$date_col" "$value_col" <<'PY'
import math
import sys
from datetime import datetime

path = sys.argv[1]
date_col = int(sys.argv[2])
value_col = int(sys.argv[3])

def split_row(line: str):
    if "|" in line:
        return line.split("|")
    if "," in line:
        return line.split(",")
    return line.split()

data = {}
with open(path, "r", encoding="utf-8", errors="ignore") as handle:
    for raw in handle:
        row = raw.strip()
        if not row:
            continue
        parts = split_row(row)
        if len(parts) <= max(date_col, value_col):
            continue
        date_key = parts[date_col].split(" ")[0]
        try:
            value = float(parts[value_col])
        except ValueError:
            continue
        data.setdefault(date_key, []).append(value)

if not data:
    print("No usable data found.")
    sys.exit(0)

daily = {k: (sum(v) / len(v)) for k, v in data.items()}
dates = sorted(daily.keys())
values = [daily[d] for d in dates]

n = len(values)
mean_val = sum(values) / n
min_val = min(values)
max_val = max(values)

if n < 2:
    slope = 0.0
else:
    xs = list(range(n))
    x_mean = sum(xs) / n
    y_mean = sum(values) / n
    num = sum((x - x_mean) * (y - y_mean) for x, y in zip(xs, values))
    den = sum((x - x_mean) ** 2 for x in xs)
    slope = 0.0 if den == 0 else num / den

threshold = max(0.01 * abs(mean_val), 0.01)
if abs(slope) < threshold:
    trend = "flat"
elif slope > 0:
    trend = "increasing"
else:
    trend = "decreasing"

weekday_values = {i: [] for i in range(7)}
for d, value in daily.items():
    try:
        weekday_values[datetime.strptime(d, "%Y-%m-%d").weekday()].append(value)
    except ValueError:
        continue

labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
print(f"Patterns for {path}")
print(f"Days: {n}")
print(f"Mean: {mean_val:.2f}  Min: {min_val:.2f}  Max: {max_val:.2f}")
print(f"Trend: {trend} (slope {slope:+.4f} per day)")
print("")
print("By weekday:")
for idx in range(7):
    vals = weekday_values[idx]
    if vals:
        avg = sum(vals) / len(vals)
        print(f"  {labels[idx]}: {avg:.2f} (n={len(vals)})")
    else:
        print(f"  {labels[idx]}: N/A")
PY
}

# Correlate two datasets (date-based CSV/pipe-delimited)
# Usage: correlate_two_datasets <file1> <file2> [date_col1] [val_col1] [date_col2] [val_col2]
# Column indices are 0-based
correlate_two_datasets() {
    _correlation_require_python || return 1

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

    if _correlation_has_python_engine; then
        python3 "$CORRELATE_PY" correlate "$file1" "$file2" --d1 "$d1" --v1 "$v1" --d2 "$d2" --v2 "$v2"
        return
    fi

    echo "Warning: correlate.py not found at $CORRELATE_PY. Using inline fallback." >&2
    _correlation_inline_correlate "$file1" "$file2" "$d1" "$v1" "$d2" "$v2"
}

# Find recurring patterns in a single dataset
# Usage: find_patterns <data_file> [date_col] [value_col]
find_patterns() {
    local file="$1"
    local date_col="${2:-1}"
    local value_col="${3:-2}"

    _correlation_require_python || return 1

    if [ ! -f "$file" ]; then
        echo "Error: File $file not found" >&2
        return 1
    fi

    if _correlation_has_python_engine; then
        python3 "$CORRELATE_PY" patterns "$file" --d "$date_col" --v "$value_col"
        return
    fi

    echo "Warning: correlate.py not found at $CORRELATE_PY. Using inline fallback." >&2
    _correlation_inline_patterns "$file" "$date_col" "$value_col"
}

# Predict value based on historical correlations
# Usage: predict_value <historical_data> <current_inputs>
predict_value() {
    local historical_data="${1:-}"
    local current_input="${2:-}"

    if [[ -z "$historical_data" ]]; then
        echo "Usage: predict_value <historical_data_file> [current_input]" >&2
        return 1
    fi
    if [[ ! -f "$historical_data" ]]; then
        echo "Error: File $historical_data not found" >&2
        return 1
    fi
    _correlation_require_python || return 1

    python3 - "$historical_data" "$current_input" "$CORRELATION_PREDICT_WINDOW" <<'PY'
import sys

path = sys.argv[1]
current_raw = sys.argv[2]
window = int(sys.argv[3])

def split_row(line: str):
    if "|" in line:
        return line.split("|")
    if "," in line:
        return line.split(",")
    return line.split()

values = []
with open(path, "r", encoding="utf-8", errors="ignore") as handle:
    for raw in handle:
        row = raw.strip()
        if not row:
            continue
        parts = split_row(row)
        if not parts:
            continue
        try:
            values.append(float(parts[-1]))
        except ValueError:
            continue

if not values:
    print("Prediction unavailable: no usable numeric history.", file=sys.stderr)
    sys.exit(1)

window_values = values[-window:]
moving_average = sum(window_values) / len(window_values)

if current_raw:
    try:
        current = float(current_raw)
    except ValueError:
        print("Error: current_input must be numeric when provided.", file=sys.stderr)
        sys.exit(1)
    predicted = (moving_average + current) / 2.0
else:
    predicted = moving_average

print(f"{predicted:.4f}")
PY
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
