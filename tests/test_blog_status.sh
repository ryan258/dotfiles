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
    # Scrub overrides the developer's .env may have exported into the parent
    # shell so they don't leak into the test subshells.
    unset BLOG_CONTENT_DIR BLOG_DRAFTS_DIR BLOG_POSTS_DIR \
        BLOG_DRAFTS_DIR_OVERRIDE BLOG_POSTS_DIR_OVERRIDE
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

@test "blog status does not leak status globals into the caller" {
    run env \
        BLOG_DIR="$BLOG_DIR" \
        DRAFTS_DIR="$DRAFTS_DIR" \
        POSTS_DIR="$POSTS_DIR" \
        bash -c 'source "$1"; blog_status >/dev/null; printf "%s|%s|%s|%s|%s|%s|%s|%s|%s" "${TOTAL_POSTS-unset}" "${STUB_FILES-unset}" "${STUB_COUNT-unset}" "${LAST_UPDATE-unset}" "${LAST_UPDATE_EPOCH-unset}" "${DAYS_SINCE-unset}" "${CONTENT_ROOT-unset}" "${SECTION_TOTAL-unset}" "${SECTION_NAME-unset}"' _ "$BATS_TEST_DIRNAME/../scripts/lib/blog_ops.sh"

    [ "$status" -eq 0 ]
    [ "$output" = "unset|unset|unset|unset|unset|unset|unset|unset|unset" ]
}

@test "blog status reports per-section breakdown across content sections" {
    mkdir -p "$BLOG_DIR/content/artifacts" "$BLOG_DIR/content/workflows" "$BLOG_DIR/content/blog"
    cat > "$BLOG_DIR/content/artifacts/_index.md" <<'EOF'
section index
EOF
    cat > "$BLOG_DIR/content/artifacts/a.md" <<'EOF'
artifact a
EOF
    cat > "$BLOG_DIR/content/artifacts/b.md" <<'EOF'
artifact b
EOF
    cat > "$BLOG_DIR/content/workflows/w1.md" <<'EOF'
workflow 1
EOF
    cat > "$BLOG_DIR/content/blog/_index.md" <<'EOF'
section index only
EOF
    cat > "$BLOG_DIR/content/search.md" <<'EOF'
top-level page should be ignored
EOF

    run env \
        BLOG_DIR="$BLOG_DIR" \
        DRAFTS_DIR="$DRAFTS_DIR" \
        POSTS_DIR="$POSTS_DIR" \
        bash -c 'source "$1"; blog_status' _ "$BATS_TEST_DIRNAME/../scripts/lib/blog_ops.sh"

    [ "$status" -eq 0 ]
    # posts/ has 1 (from setup), artifacts has 2, workflows has 1 = 4 across 3 sections
    grep -qF "Total content: 4 across 3 section" <<<"$output"
    grep -qF "artifacts: 2" <<<"$output"
    grep -qF "workflows: 1" <<<"$output"
    grep -qF "posts: 1" <<<"$output"
    # Empty sections (only _index.md) are excluded from breakdown
    ! grep -qE "^[[:space:]]*-[[:space:]]*blog:" <<<"$output"
    # Top-level content files ignored
    ! grep -qF "search" <<<"$output"
}

@test "blog status reports zero when no sections have markdown" {
    rm -rf "$POSTS_DIR"
    mkdir -p "$BLOG_DIR/content/blog"
    cat > "$BLOG_DIR/content/blog/_index.md" <<'EOF'
section index only
EOF

    run env \
        BLOG_DIR="$BLOG_DIR" \
        DRAFTS_DIR="$DRAFTS_DIR" \
        POSTS_DIR="$POSTS_DIR" \
        bash -c 'source "$1"; blog_status' _ "$BATS_TEST_DIRNAME/../scripts/lib/blog_ops.sh"

    [ "$status" -eq 0 ]
    grep -qF "Total content: 0" <<<"$output"
}

@test "blog status counts content stubs across all sections" {
    mkdir -p "$BLOG_DIR/content/artifacts" "$BLOG_DIR/content/workflows"
    cat > "$BLOG_DIR/content/artifacts/stub-one.md" <<'EOF'
this is a content stub for later expansion
EOF
    cat > "$BLOG_DIR/content/workflows/stub-two.md" <<'EOF'
Content Stub
EOF
    cat > "$BLOG_DIR/content/workflows/real.md" <<'EOF'
real content here
EOF

    run env \
        BLOG_DIR="$BLOG_DIR" \
        DRAFTS_DIR="$DRAFTS_DIR" \
        POSTS_DIR="$POSTS_DIR" \
        bash -c 'source "$1"; blog_status' _ "$BATS_TEST_DIRNAME/../scripts/lib/blog_ops.sh"

    [ "$status" -eq 0 ]
    grep -qF "Posts needing content: 2" <<<"$output"
}

@test "blog status excludes top-level pages from stub count" {
    cat > "$BLOG_DIR/content/search.md" <<'EOF'
this is a content stub at content root
EOF

    run env \
        BLOG_DIR="$BLOG_DIR" \
        DRAFTS_DIR="$DRAFTS_DIR" \
        POSTS_DIR="$POSTS_DIR" \
        bash -c 'source "$1"; blog_status' _ "$BATS_TEST_DIRNAME/../scripts/lib/blog_ops.sh"

    [ "$status" -eq 0 ]
    grep -qF "Posts needing content: 0" <<<"$output"
}

@test "blog status honors BLOG_CONTENT_DIR override" {
    local alt_content="$TEST_ROOT/alt-content"
    mkdir -p "$alt_content/notes"
    cat > "$alt_content/notes/n1.md" <<'EOF'
override note
EOF

    run env \
        BLOG_DIR="$BLOG_DIR" \
        DRAFTS_DIR="$DRAFTS_DIR" \
        POSTS_DIR="$POSTS_DIR" \
        BLOG_CONTENT_DIR="$alt_content" \
        bash -c 'source "$1"; blog_status' _ "$BATS_TEST_DIRNAME/../scripts/lib/blog_ops.sh"

    [ "$status" -eq 0 ]
    # Setup creates posts/post-one.md under default $BLOG_DIR/content,
    # but the override should redirect the walk entirely to $alt_content.
    grep -qF "Total content: 1 across 1 section" <<<"$output"
    grep -qF "notes: 1" <<<"$output"
    ! grep -qF "posts: 1" <<<"$output"
}
