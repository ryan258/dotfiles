#!/usr/bin/env bash
set -euo pipefail

# pdf_to_markdown.sh - Convert a text PDF into Markdown.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/common.sh"

usage() {
    cat <<'EOF'
Usage: pdf_to_markdown.sh <pdf_file> [output.md]
       pdf_to_markdown.sh <pdf_file> --stdout
       pdf_to_markdown.sh <pdf_file> --output output.md [--force]

Convert a text-based PDF into Markdown for cheaper AI ingestion.

Options:
  -o, --output <path>  Write Markdown to this file
      --stdout         Print Markdown to stdout instead of writing a file
  -f, --force          Overwrite an existing output file
  -h, --help           Show this help

Notes:
  - Uses macOS PDFKit through swift, so it does not need extra PDF packages.
  - This extracts embedded text only. Scanned or image-only PDFs may need OCR.
  - Default output path is the input filename with a .md extension.
EOF
}

sanitize_arg() {
    sanitize_single_line "$1"
}

validate_output_path() {
    local output_path="$1"
    local output_dir

    output_dir=$(dirname "$output_path")
    output_dir=$(validate_path "$output_dir") || return 1
    printf '%s/%s' "$output_dir" "$(basename "$output_path")"
}

# Swift and PDFKit pull out embedded text without extra PDF packages.
render_markdown() {
    local pdf_file="$1"
    local title="$2"
    local module_cache_dir="${TMPDIR:-/tmp}/dotfiles-swift-module-cache"

    mkdir -p "$module_cache_dir"

    swift -module-cache-path "$module_cache_dir" - "$pdf_file" "$title" <<'SWIFT'
import Foundation
import PDFKit

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    fputs("Error: Missing PDF conversion arguments.\n", stderr)
    exit(1)
}

let pdfPath = arguments[1]
let title = arguments[2]

func normalizePageText(_ text: String) -> String {
    let normalizedNewlines = text
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")

    let lines = normalizedNewlines.components(separatedBy: "\n")
    var cleaned: [String] = []
    var previousWasBlank = false

    for rawLine in lines {
        var line = rawLine.trimmingCharacters(in: .whitespaces)
        if line.hasPrefix("• ") {
            line = "- " + line.dropFirst(2)
        }

        if line.isEmpty {
            if !previousWasBlank {
                cleaned.append("")
            }
            previousWasBlank = true
            continue
        }

        cleaned.append(line)
        previousWasBlank = false
    }

    while cleaned.last == "" {
        cleaned.removeLast()
    }

    return cleaned.joined(separator: "\n")
}

let pdfURL = URL(fileURLWithPath: pdfPath)
guard let document = PDFDocument(url: pdfURL) else {
    fputs("Error: Failed to open PDF: \(pdfPath)\n", stderr)
    exit(1)
}

var markdownLines: [String] = ["# \(title)", ""]
var extractedPages = 0

for pageIndex in 0..<document.pageCount {
    guard let page = document.page(at: pageIndex) else {
        continue
    }

    let text = normalizePageText(page.string ?? "")
    guard !text.isEmpty else {
        continue
    }

    extractedPages += 1
    markdownLines.append("## Page \(pageIndex + 1)")
    markdownLines.append("")
    markdownLines.append(text)
    markdownLines.append("")
}

guard extractedPages > 0 else {
    fputs("Error: No extractable text found. The PDF may be scanned or image-only.\n", stderr)
    exit(2)
}

while markdownLines.last == "" {
    markdownLines.removeLast()
}

print(markdownLines.joined(separator: "\n"))
SWIFT
}

OUTPUT_FILE=""
INPUT_FILE=""
FORCE_MODE=false
STDOUT_MODE=false

# Parse flags first so we can reject bad input before touching files.
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit "$EXIT_SUCCESS"
            ;;
        -f|--force)
            FORCE_MODE=true
            ;;
        --stdout)
            STDOUT_MODE=true
            ;;
        -o|--output)
            shift
            [[ $# -gt 0 ]] || die "--output requires a file path" "$EXIT_INVALID_ARGS"
            OUTPUT_FILE=$(sanitize_arg "$1")
            ;;
        --)
            shift
            break
            ;;
        -*)
            die "Unknown option: $1" "$EXIT_INVALID_ARGS"
            ;;
        *)
            if [[ -z "$INPUT_FILE" ]]; then
                INPUT_FILE=$(sanitize_arg "$1")
            elif [[ -z "$OUTPUT_FILE" && "$STDOUT_MODE" == "false" ]]; then
                OUTPUT_FILE=$(sanitize_arg "$1")
            else
                die "Unexpected argument: $1" "$EXIT_INVALID_ARGS"
            fi
            ;;
    esac
    shift
done

[[ -n "$INPUT_FILE" ]] || {
    usage
    exit "$EXIT_INVALID_ARGS"
}

require_cmd "swift" "xcode-select --install"

INPUT_FILE=$(validate_path "$INPUT_FILE") || exit "$EXIT_INVALID_ARGS"
validate_file_exists "$INPUT_FILE" "PDF file" || exit "$EXIT_FILE_NOT_FOUND"

if ! [[ "$INPUT_FILE" =~ \.[Pp][Dd][Ff]$ ]]; then
    die "Input file must end in .pdf" "$EXIT_INVALID_ARGS"
fi

if [[ "$STDOUT_MODE" == "true" && -n "$OUTPUT_FILE" ]]; then
    die "Use either --stdout or an output file, not both" "$EXIT_INVALID_ARGS"
fi

if [[ "$STDOUT_MODE" == "false" ]]; then
    if [[ -z "$OUTPUT_FILE" ]]; then
        OUTPUT_FILE="${INPUT_FILE%.*}.md"
    fi

    OUTPUT_FILE=$(validate_output_path "$OUTPUT_FILE") || exit "$EXIT_INVALID_ARGS"

    if [[ "$OUTPUT_FILE" == "$INPUT_FILE" ]]; then
        die "Output path must be different from the input PDF" "$EXIT_INVALID_ARGS"
    fi

    if [[ -e "$OUTPUT_FILE" && "$FORCE_MODE" == "false" ]]; then
        die "Output file already exists: $OUTPUT_FILE (use --force to overwrite)" "$EXIT_ERROR"
    fi
fi

TITLE=$(basename "${INPUT_FILE%.*}")

if [[ "$STDOUT_MODE" == "true" ]]; then
    render_markdown "$INPUT_FILE" "$TITLE"
    exit "$EXIT_SUCCESS"
fi

# Write to a temp file first so a failed conversion never leaves a half file.
TEMP_OUTPUT=$(mktemp "${OUTPUT_FILE}.XXXXXX") || die "Failed to create temp output file"

if ! render_markdown "$INPUT_FILE" "$TITLE" > "$TEMP_OUTPUT"; then
    rm -f "$TEMP_OUTPUT"
    exit "$EXIT_SERVICE_ERROR"
fi

mv "$TEMP_OUTPUT" "$OUTPUT_FILE"
echo "Saved Markdown to $OUTPUT_FILE"
