#!/usr/bin/env bats

# test_pdf_to_markdown.sh - Bats coverage for pdf to markdown.

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"

setup() {
    setup_test_environment
    PDF_TO_MARKDOWN_SCRIPT="$BATS_TEST_DIRNAME/../scripts/pdf_to_markdown.sh"
}

teardown() {
    teardown_test_environment
}

create_sample_pdf() {
    command -v cupsfilter >/dev/null 2>&1 || skip "cupsfilter is required for PDF fixture generation"

    printf 'Hello PDF\n\nThis is a test document.\n' > "$TEST_DIR/source.txt"
    cupsfilter -m application/pdf "$TEST_DIR/source.txt" > "$TEST_DIR/source.pdf" 2>/dev/null
}

@test "pdf_to_markdown fails on missing file" {
    run bash -c "cd \"$TEST_DIR\" && \"$PDF_TO_MARKDOWN_SCRIPT\" missing.pdf 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "PDF file not found" ]]
}

@test "pdf_to_markdown converts a sample PDF into markdown" {
    create_sample_pdf

    run bash -c "cd \"$TEST_DIR\" && \"$PDF_TO_MARKDOWN_SCRIPT\" source.pdf 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Saved Markdown to" ]]

    [ -f "$TEST_DIR/source.md" ]

    run cat "$TEST_DIR/source.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"# source"* ]]
    [[ "$output" == *"## Page 1"* ]]
    [[ "$output" == *"Hello PDF"* ]]
    [[ "$output" == *"This is a test document."* ]]
}

@test "pdf_to_markdown supports stdout mode" {
    create_sample_pdf

    run bash -c "cd \"$TEST_DIR\" && \"$PDF_TO_MARKDOWN_SCRIPT\" source.pdf --stdout"
    [ "$status" -eq 0 ]
    [[ "$output" == *"# source"* ]]
    [[ "$output" == *"## Page 1"* ]]
    [[ "$output" == *"Hello PDF"* ]]
}
