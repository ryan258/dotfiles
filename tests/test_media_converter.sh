#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"

setup() {
    setup_test_environment
    MEDIA_SCRIPT="$BATS_TEST_DIRNAME/../scripts/media_converter.sh"
    touch "$TEST_DIR/sample.mp4"
    touch "$TEST_DIR/sample.jpg"
    touch "$TEST_DIR/sample.pdf"
}

teardown() {
    teardown_test_environment
}

@test "media_converter video2audio fails on missing file" {
    run bash -c "cd \"$TEST_DIR\" && \"$MEDIA_SCRIPT\" video2audio missing.mp4 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Video file not found" ]]
}

@test "media_converter resize_image rejects invalid width" {
    run bash -c "cd \"$TEST_DIR\" && \"$MEDIA_SCRIPT\" resize_image sample.jpg notanumber 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "width" ]]
}

@test "media_converter pdf_compress fails on missing file" {
    run bash -c "cd \"$TEST_DIR\" && \"$MEDIA_SCRIPT\" pdf_compress missing.pdf 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "PDF file not found" ]]
}

@test "media_converter audio_stitch handles empty directory" {
    run bash -c "cd \"$TEST_DIR\" && \"$MEDIA_SCRIPT\" audio_stitch 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "No audio files found" ]]
}
