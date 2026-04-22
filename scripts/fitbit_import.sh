#!/usr/bin/env bash
set -euo pipefail

# fitbit_import.sh - Normalize Fitbit CSV exports into daily metric files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_lib "config.sh"

require_cmd "python3" "Install Python 3"

ensure_data_dirs

FITBIT_DATA_DIR="${DATA_DIR}/fitbit"
mkdir -p "$FITBIT_DATA_DIR"
chmod 700 "$FITBIT_DATA_DIR" 2>/dev/null || true

show_help() {
    cat <<EOF
Usage: $(basename "$0") {import|auto|latest|paths|help}

Commands:
  import <metric> <csv_file> [--date-column <name>] [--value-column <name>]
      Import one Fitbit CSV export into a normalized daily metric file.

  auto <path>
      Recursively scan a directory of Fitbit CSV exports and import files whose
      names match supported metrics.

  latest
      Show the most recent imported value for each Fitbit metric.

  paths
      Show the normalized Fitbit metric file paths.

Metrics:
  steps
  sleep_minutes
  sleep_score
  resting_heart_rate
  hrv

Examples:
  $(basename "$0") import steps "\$HOME/Downloads/steps.csv"
  $(basename "$0") import sleep_score "\$HOME/Downloads/sleep_score.csv"
  $(basename "$0") auto "\$HOME/Downloads/Fitbit Export"
EOF
}

is_known_metric() {
    case "${1:-}" in
        steps|sleep_minutes|sleep_score|resting_heart_rate|hrv)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

metric_output_path() {
    local metric="${1:-}"

    case "$metric" in
        steps) echo "$FITBIT_DATA_DIR/steps.txt" ;;
        sleep_minutes) echo "$FITBIT_DATA_DIR/sleep_minutes.txt" ;;
        sleep_score) echo "$FITBIT_DATA_DIR/sleep_score.txt" ;;
        resting_heart_rate) echo "$FITBIT_DATA_DIR/resting_heart_rate.txt" ;;
        hrv) echo "$FITBIT_DATA_DIR/hrv.txt" ;;
        *)
            echo "Error: Unsupported Fitbit metric '$metric'" >&2
            return 1
            ;;
    esac
}

# Auto mode guesses the metric from the export file name.
infer_metric_from_name() {
    local input_name="${1:-}"
    local lowered

    lowered=$(printf '%s' "$input_name" | tr '[:upper:]' '[:lower:]')

    case "$lowered" in
        *sleep*score*)
            echo "sleep_score"
            ;;
        *resting*heart*rate*|*resting_heart_rate*|*rhr*)
            echo "resting_heart_rate"
            ;;
        *heart*rate*variability*|*heart_rate_variability*|*hrv*)
            echo "hrv"
            ;;
        *steps*|*step_count*)
            echo "steps"
            ;;
        *sleep*)
            echo "sleep_minutes"
            ;;
        *)
            return 1
            ;;
    esac
}

import_metric_csv() {
    local metric="$1"
    local source_file="$2"
    local date_column="${3:-}"
    local value_column="${4:-}"

    is_known_metric "$metric" || die "Unsupported Fitbit metric '$metric'" "$EXIT_INVALID_ARGS"

    local safe_source
    safe_source=$(validate_path "$source_file") || die "Unsafe Fitbit CSV path: $source_file" "$EXIT_INVALID_ARGS"
    require_file "$safe_source" "Fitbit CSV export"

    local target_file
    target_file=$(metric_output_path "$metric") || exit "$EXIT_INVALID_ARGS"

    # Accept many Fitbit CSV shapes, then rewrite them into one daily format.
    local normalized
    normalized="$(python3 - "$metric" "$safe_source" "${date_column:-__AUTO__}" "${value_column:-__AUTO__}" "$target_file" <<'PY'
import csv
import os
import re
import sys
from datetime import datetime

metric, csv_path, date_hint, value_hint, existing_path = sys.argv[1:6]

DATE_CANDIDATES = [
    "date",
    "timestamp",
    "datetime",
    "date of sleep",
    "sleep log entry date",
    "sleep start time",
    "start time",
    "calendar date",
]

VALUE_CANDIDATES = {
    "steps": ["steps", "step count", "number of steps", "value"],
    "sleep_minutes": ["minutes asleep", "minutesasleep", "sleep minutes", "duration", "value"],
    "sleep_score": ["overall sleep score", "sleep score", "overall score", "score", "value"],
    "resting_heart_rate": ["resting heart rate", "resting heart rate bpm", "rhr", "value"],
    "hrv": ["heart rate variability", "hrv", "rmssd", "value"],
}

SUM_METRICS = {"steps", "sleep_minutes"}


def norm(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", text.lower()).strip()


def parse_date(raw: str):
    if raw is None:
        return None
    text = raw.strip()
    if not text:
        return None

    iso_match = re.search(r"(\d{4}-\d{2}-\d{2})", text)
    if iso_match:
        return iso_match.group(1)

    for pattern in (
        "%m/%d/%Y",
        "%m/%d/%y",
        "%Y/%m/%d",
        "%m-%d-%Y",
        "%m-%d-%y",
        "%b %d, %Y",
        "%B %d, %Y",
        "%Y%m%d",
    ):
        try:
            return datetime.strptime(text, pattern).strftime("%Y-%m-%d")
        except ValueError:
            continue

    try:
        cleaned = text.replace("Z", "+00:00")
        return datetime.fromisoformat(cleaned).strftime("%Y-%m-%d")
    except ValueError:
        return None


def parse_value(metric_name: str, raw: str):
    if raw is None:
        return None
    text = raw.strip()
    if not text:
        return None

    cleaned = text.replace(",", "").strip()

    if metric_name == "sleep_minutes":
        hhmmss = re.fullmatch(r"(\d{1,2}):(\d{2})(?::(\d{2}))?", cleaned)
        if hhmmss:
            hours = int(hhmmss.group(1))
            minutes = int(hhmmss.group(2))
            return float((hours * 60) + minutes)

        hr_min = re.search(r"(?:(\d+(?:\.\d+)?)\s*h(?:r|rs|ours?)?)?\s*(?:(\d+(?:\.\d+)?)\s*m(?:in|ins|inutes?)?)?", cleaned.lower())
        if hr_min and (hr_min.group(1) or hr_min.group(2)):
            hours = float(hr_min.group(1) or 0)
            minutes = float(hr_min.group(2) or 0)
            return (hours * 60.0) + minutes

    numeric = re.search(r"-?\d+(?:\.\d+)?", cleaned)
    if numeric:
        return float(numeric.group(0))
    return None


def resolve_column(headers, hint, candidates, fallback_keywords):
    header_map = {norm(header): header for header in headers}

    if hint and hint != "__AUTO__":
        normalized_hint = norm(hint)
        if normalized_hint in header_map:
            return header_map[normalized_hint]
        raise SystemExit(f"Error: Column '{hint}' not found in {csv_path}")

    for candidate in candidates:
        if candidate in header_map:
            return header_map[candidate]

    for header in headers:
        normalized_header = norm(header)
        if any(keyword in normalized_header for keyword in fallback_keywords):
            return header

    return None


def format_value(value: float) -> str:
    rounded = round(value)
    if abs(value - rounded) < 1e-9:
        return str(int(rounded))
    return f"{value:.2f}".rstrip("0").rstrip(".")


with open(csv_path, "r", encoding="utf-8-sig", newline="") as handle:
    reader = csv.DictReader(handle)
    headers = reader.fieldnames or []
    if not headers:
        raise SystemExit(f"Error: {csv_path} does not contain a CSV header row")

    date_column = resolve_column(headers, date_hint, DATE_CANDIDATES, ("date", "time"))
    value_column = resolve_column(
        headers,
        value_hint,
        VALUE_CANDIDATES.get(metric, []),
        tuple(norm(candidate) for candidate in VALUE_CANDIDATES.get(metric, [])),
    )

    if not date_column:
        raise SystemExit(f"Error: Could not infer a date column for {csv_path}")
    if not value_column:
        raise SystemExit(f"Error: Could not infer a value column for {csv_path}")

    imported = {}
    counts = {}
    for row in reader:
        date_key = parse_date(row.get(date_column, ""))
        value = parse_value(metric, row.get(value_column, ""))
        if date_key is None or value is None:
            continue

        if metric in SUM_METRICS:
            imported[date_key] = imported.get(date_key, 0.0) + value
        else:
            imported[date_key] = imported.get(date_key, 0.0) + value
            counts[date_key] = counts.get(date_key, 0) + 1

    if not imported:
        raise SystemExit(
            f"Error: No usable {metric} rows found in {csv_path} "
            f"(date column: {date_column}, value column: {value_column})"
        )

    if metric not in SUM_METRICS:
        for date_key, total in list(imported.items()):
            imported[date_key] = total / counts[date_key]


merged = {}
if os.path.exists(existing_path):
    with open(existing_path, "r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue
            parts = line.split("|", 1)
            if len(parts) != 2:
                continue
            merged[parts[0]] = parts[1]

for date_key, value in imported.items():
    merged[date_key] = format_value(value)

for date_key in sorted(merged):
    print(f"{date_key}|{merged[date_key]}")
PY
)"

    atomic_write "$normalized" "$target_file" || die "Failed to write Fitbit data to $target_file" "$EXIT_ERROR"
    chmod 600 "$target_file" 2>/dev/null || true

    local imported_days
    imported_days=$(printf '%s\n' "$normalized" | awk 'NF {count++} END {print count+0}')

    echo "Imported $metric into $target_file ($imported_days day(s) available)"
}

cmd_import() {
    local metric="${1:-}"
    local source_file="${2:-}"
    shift 2 || true

    [[ -n "$metric" && -n "$source_file" ]] || {
        echo "Usage: $(basename "$0") import <metric> <csv_file> [--date-column <name>] [--value-column <name>]" >&2
        exit "$EXIT_INVALID_ARGS"
    }

    local date_column=""
    local value_column=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --date-column)
                date_column="${2:-}"
                [[ -n "$date_column" ]] || die "--date-column requires a value" "$EXIT_INVALID_ARGS"
                shift 2
                ;;
            --value-column)
                value_column="${2:-}"
                [[ -n "$value_column" ]] || die "--value-column requires a value" "$EXIT_INVALID_ARGS"
                shift 2
                ;;
            *)
                die "Unknown option for import: $1" "$EXIT_INVALID_ARGS"
                ;;
        esac
    done

    import_metric_csv "$metric" "$source_file" "$date_column" "$value_column"
}

# Auto mode scans a folder and only imports files we know how to map.
cmd_auto() {
    local input_path="${1:-}"
    [[ -n "$input_path" ]] || {
        echo "Usage: $(basename "$0") auto <path>" >&2
        exit "$EXIT_INVALID_ARGS"
    }

    local safe_input
    safe_input=$(validate_path "$input_path") || die "Unsafe Fitbit import path: $input_path" "$EXIT_INVALID_ARGS"

    local imported=0
    local skipped=0

    if [[ -f "$safe_input" ]]; then
        local metric
        metric=$(infer_metric_from_name "$(basename "$safe_input")") || die "Could not infer Fitbit metric from file name: $safe_input" "$EXIT_INVALID_ARGS"
        import_metric_csv "$metric" "$safe_input"
        echo "Imported 1 Fitbit file(s); skipped 0"
        return 0
    fi

    require_dir "$safe_input" "Fitbit export directory"

    while IFS= read -r candidate; do
        [[ -n "$candidate" ]] || continue

        local metric=""
        if metric=$(infer_metric_from_name "$(basename "$candidate")"); then
            if import_metric_csv "$metric" "$candidate"; then
                imported=$((imported + 1))
            else
                skipped=$((skipped + 1))
                log_warn "Skipped unreadable Fitbit export: $candidate"
            fi
        else
            skipped=$((skipped + 1))
        fi
    done < <(find "$safe_input" -type f \( -name "*.csv" -o -name "*.CSV" \) | sort)

    if [[ "$imported" -eq 0 ]]; then
        die "No supported Fitbit CSV exports found in $safe_input" "$EXIT_FILE_NOT_FOUND"
    fi

    echo "Imported $imported Fitbit file(s); skipped $skipped"
}

cmd_latest() {
    local has_data=false
    local metric

    echo "Fitbit metrics:"
    for metric in steps sleep_minutes sleep_score resting_heart_rate hrv; do
        local target_file
        target_file=$(metric_output_path "$metric")

        if [[ -s "$target_file" ]]; then
            has_data=true
            local last_line
            last_line=$(tail -n 1 "$target_file")
            local date_part
            local value_part
            date_part=$(printf '%s' "$last_line" | cut -d'|' -f1)
            value_part=$(printf '%s' "$last_line" | cut -d'|' -f2)
            printf '  - %-18s %s (%s)\n' "$metric:" "$value_part" "$date_part"
        else
            printf '  - %-18s not imported yet\n' "$metric:"
        fi
    done

    if [[ "$has_data" = "false" ]]; then
        echo "  (no Fitbit data imported yet)"
    fi
}

cmd_paths() {
    local metric

    for metric in steps sleep_minutes sleep_score resting_heart_rate hrv; do
        printf '%s|%s\n' "$metric" "$(metric_output_path "$metric")"
    done
}

main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        import) cmd_import "$@" ;;
        auto) cmd_auto "$@" ;;
        latest) cmd_latest ;;
        paths) cmd_paths ;;
        help|-h|--help) show_help ;;
        *)
            echo "Error: Unknown command '$cmd'" >&2
            show_help >&2
            exit "$EXIT_INVALID_ARGS"
            ;;
    esac
}

main "$@"
