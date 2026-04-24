#!/usr/bin/env bats

# test_blog_status.sh - Bats coverage for blog status.

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    export TEST_ROOT
    TEST_ROOT="$(mktemp -d)"
    export BLOG_DIR="$TEST_ROOT/blog"
    export DRAFTS_DIR="$BLOG_DIR/drafts"
    export POSTS_DIR="$BLOG_DIR/content/posts"
    mkdir -p "$DRAFTS_DIR/ingest/20260323-session-a/preview/content/projects"
    mkdir -p "$DRAFTS_DIR/ingest/20260322-session-b"
    mkdir -p "$POSTS_DIR"

    cat > "$POSTS_DIR/post-one.md" <<'EOF'
---
title: Post One
---
EOF

    cat > "$DRAFTS_DIR/idea.md" <<'EOF'
draft
EOF
    cat > "$DRAFTS_DIR/ingest/20260323-session-a/scan.md" <<'EOF'
scan
EOF
    cat > "$DRAFTS_DIR/ingest/20260323-session-a/transcript.md" <<'EOF'
transcript
EOF
    cat > "$DRAFTS_DIR/ingest/20260323-session-a/preview/content/projects/example.md" <<'EOF'
example
EOF
    cat > "$DRAFTS_DIR/ingest/20260322-session-b/scan.md" <<'EOF'
scan
EOF
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "blog status groups ingest artifacts into review sessions" {
    run env \
        BLOG_DIR="$BLOG_DIR" \
        DRAFTS_DIR="$DRAFTS_DIR" \
        POSTS_DIR="$POSTS_DIR" \
        BLOG_STATUS_REVIEW_DETAIL_LIMIT=10 \
        bash -c 'source "$1"; blog_status' _ "$BATS_TEST_DIRNAME/../scripts/lib/blog_ops.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Drafts awaiting review: 3 item(s) across 5 markdown artifact(s)"* ]]
    [[ "$output" == *"ingest/20260323-session-a (3 artifacts)"* ]]
    [[ "$output" == *"ingest/20260322-session-b (1 artifact)"* ]]
    [[ "$output" == *"idea.md"* ]]
    [[ "$output" != *"preview/content/projects/example.md"* ]]
}

@test "blog status caps review detail lines" {
    cat > "$DRAFTS_DIR/another.md" <<'EOF'
draft
EOF

    run env \
        BLOG_DIR="$BLOG_DIR" \
        DRAFTS_DIR="$DRAFTS_DIR" \
        POSTS_DIR="$POSTS_DIR" \
        BLOG_STATUS_REVIEW_DETAIL_LIMIT=2 \
        bash -c 'source "$1"; blog_status' _ "$BATS_TEST_DIRNAME/../scripts/lib/blog_ops.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"2 more review item(s) not shown"* ]]
}
