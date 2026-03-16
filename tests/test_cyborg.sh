#!/usr/bin/env bats

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    setup_test_environment

    export DOTFILES_DIR="$TEST_DIR/dotfiles"
    export BLOG_DIR="$TEST_DIR/my-ms-ai-blog"
    export SOURCE_REPO="$TEST_DIR/source-repo"
    export SPECIAL_REPO="$TEST_DIR/rockit++[1]"

    mkdir -p "$DOTFILES_DIR/bin" "$DOTFILES_DIR/scripts" "$DOTFILES_DIR/scripts/lib" "$DOTFILES_DIR/zsh"
    mkdir -p "$BLOG_DIR/content/log" "$BLOG_DIR/content/projects" "$BLOG_DIR/content/workflows" "$BLOG_DIR/content/artifacts" "$BLOG_DIR/content/reference" "$BLOG_DIR/drafts/ingest"
    mkdir -p "$SOURCE_REPO" "$SPECIAL_REPO"

    cp "$BATS_TEST_DIRNAME/../bin/cyborg" "$DOTFILES_DIR/bin/cyborg"
    cp "$BATS_TEST_DIRNAME/../scripts/cyborg_agent.py" "$DOTFILES_DIR/scripts/cyborg_agent.py"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/config.sh" "$DOTFILES_DIR/scripts/lib/config.sh"
    chmod +x "$DOTFILES_DIR/bin/cyborg" "$DOTFILES_DIR/scripts/cyborg_agent.py"

    cat > "$SOURCE_REPO/README.md" <<'EOF'
# Rockit Helper

Automates command preparation for a local rhythm-game pipeline.

## Quick Start

1. Install Python.
2. Run the CLI.
3. Verify the generated files.
EOF

    cat > "$SOURCE_REPO/tool.py" <<'EOF'
print("hello")
EOF

    cat > "$SPECIAL_REPO/README.md" <<'EOF'
# rockit++[1]

Special-character repo name for duplicate-search regression coverage.
EOF

    cat > "$SPECIAL_REPO/tool.py" <<'EOF'
print("special")
EOF

    mkdir -p "$SOURCE_REPO/tests"
    cat > "$SOURCE_REPO/tests/test_tool.py" <<'EOF'
def test_placeholder():
    assert True
EOF

    cat > "$BLOG_DIR/content/log/existing-rockit-note.md" <<'EOF'
---
title: "Existing Rockit Note"
description: "A short existing note that already mentions Rockit so duplicate detection has a live candidate to surface in the ingest session."
date: 2026-03-01
lastmod: 2026-03-01
draft: false
tags:
  - log
---

Rockit already appears here as a previous field report.
EOF

    cat > "$BLOG_DIR/content/log/existing-special-rockit-note.md" <<'EOF'
---
title: "Existing rockit++[1] Note"
description: "A note that already references rockit++[1] so the ingest agent has a live duplicate candidate for fixed-string matching."
date: 2026-03-02
lastmod: 2026-03-02
draft: false
tags:
  - log
---

rockit++[1] already appears here as a previous field report.
EOF
}

teardown() {
    teardown_test_environment
}

@test "cyborg ingest scans current repo and builds map plus plan in deterministic mode" {
    run bash -lc "cd '$SOURCE_REPO' && printf '/map\n/plan\n/quit\n' | env DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' ingest 'focus on reusable commands'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Repo scan complete."* ]]
    [[ "$output" == *"## Proposed Pages"* ]]
    [[ "$output" == *"## Phases"* ]]

    session_count=$(find "$BLOG_DIR/drafts/ingest" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
    [ "$session_count" -eq 1 ]
}

@test "cyborg ingest can generate drafts and apply them to the blog repo" {
    run bash -lc "cd '$SOURCE_REPO' && printf '/map\n/plan\n/draft workflow-main\n/apply drafts --yes\n/quit\n' | env DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' ingest 'focus on the repeatable path'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Generated pending drafts for: workflow-main"* ]]
    [[ "$output" == *"Applied the selected pending changes into the Cyborg Lab repo."* ]]

    run bash -lc "find '$BLOG_DIR/content/workflows' -type f -name '*.md' | head -n 1"
    [ "$status" -eq 0 ]
    workflow_path="$output"
    [ -n "$workflow_path" ]

    run grep -n 'draft: true' "$workflow_path"
    [ "$status" -eq 0 ]
}

@test "cyborg resume reopens a saved session by explicit id" {
    run bash -lc "cd '$SOURCE_REPO' && printf '/quit\n' | env DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' ingest 'resume me later'"
    [ "$status" -eq 0 ]

    session_id=$(basename "$(find "$BLOG_DIR/drafts/ingest" -mindepth 1 -maxdepth 1 -type d | head -n 1)")
    [ -n "$session_id" ]

    run bash -lc "printf '/status\n/quit\n' | env DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' resume '$session_id'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Session: $session_id"* ]]
}

@test "cyborg ingest applies link edits with /apply all even when no drafts are pending" {
    run bash -lc "printf '/map\n/links\n/patch-links 1\n/apply all --yes\n/quit\n' | env DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' ingest --repo '$SPECIAL_REPO' 'focus on cross linking'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Prepared pending edits for 1 existing page(s)."* ]]
    [[ "$output" == *"Applied the selected pending changes into the Cyborg Lab repo."* ]]

    run grep -n '## Related' "$BLOG_DIR/content/log/existing-special-rockit-note.md"
    [ "$status" -eq 0 ]
}

@test "cyborg ingest reports a friendly error for a missing markdown file" {
    run bash -lc "env DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' ingest --file '$SOURCE_REPO/missing.md'"

    [ "$status" -eq 2 ]
    [[ "$output" == *"Error: Unable to read source file"* ]]
    [[ "$output" != *"FileNotFoundError"* ]]
}

@test "cyborg launcher fails fast when config.sh is missing" {
    broken_dotfiles="$TEST_DIR/broken-dotfiles"
    mkdir -p "$broken_dotfiles/bin" "$broken_dotfiles/scripts"
    cp "$BATS_TEST_DIRNAME/../bin/cyborg" "$broken_dotfiles/bin/cyborg"
    cp "$BATS_TEST_DIRNAME/../scripts/cyborg_agent.py" "$broken_dotfiles/scripts/cyborg_agent.py"
    chmod +x "$broken_dotfiles/bin/cyborg" "$broken_dotfiles/scripts/cyborg_agent.py"

    run env DOTFILES_DIR="$broken_dotfiles" "$broken_dotfiles/bin/cyborg" ingest

    [ "$status" -eq 1 ]
    [[ "$output" == *"required config library is missing"* ]]
}
