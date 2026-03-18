#!/usr/bin/env bats
# test_cyborg.sh - Integration tests for the Cyborg Lab ingest agent.
# These tests check the full round-trip: scan, map, plan, draft, apply,
# resume, GitNexus integration, link-only apply, and error handling.

# Pull in shared test helpers (temp dirs, assertions, etc.).
load helpers/test_helpers.sh
load helpers/assertions.sh

# setup() runs before every single test.
# It builds a throwaway sandbox with fake repos, a fake blog,
# and a fake "npx gitnexus" so tests never touch real data.
setup() {
    setup_test_environment

    # Paths to the sandbox copies of the project pieces.
    export DOTFILES_DIR="$TEST_DIR/dotfiles"
    export BLOG_DIR="$TEST_DIR/my-ms-ai-blog"
    export SOURCE_REPO="$TEST_DIR/source-repo"
    # Repo name with special characters to test safe string handling.
    export SPECIAL_REPO="$TEST_DIR/rockit++[1]"
    # A real git repo used by GitNexus-related tests.
    export GIT_SOURCE_REPO="$TEST_DIR/git-source-repo"
    # Folder that holds our fake "npx" script.
    export FAKE_BIN="$TEST_DIR/fake-bin"
    # A log file the fake npx writes to so tests can check what was called.
    export FAKE_GITNEXUS_LOG="$TEST_DIR/gitnexus.log"

    # Create all the folders the agent expects to find.
    mkdir -p "$DOTFILES_DIR/bin" "$DOTFILES_DIR/scripts" "$DOTFILES_DIR/scripts/lib" "$DOTFILES_DIR/zsh" "$FAKE_BIN"
    mkdir -p "$BLOG_DIR/content/log" "$BLOG_DIR/content/projects" "$BLOG_DIR/content/workflows" "$BLOG_DIR/content/artifacts" "$BLOG_DIR/content/reference" "$BLOG_DIR/drafts/ingest"
    mkdir -p "$SOURCE_REPO" "$SPECIAL_REPO" "$GIT_SOURCE_REPO"
    # Start with an empty log file.
    : > "$FAKE_GITNEXUS_LOG"

    # Copy the real agent code into the sandbox so tests run against it.
    cp "$BATS_TEST_DIRNAME/../bin/cyborg" "$DOTFILES_DIR/bin/cyborg"
    cp "$BATS_TEST_DIRNAME/../scripts/cyborg_agent.py" "$DOTFILES_DIR/scripts/cyborg_agent.py"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/config.sh" "$DOTFILES_DIR/scripts/lib/config.sh"
    chmod +x "$DOTFILES_DIR/bin/cyborg" "$DOTFILES_DIR/scripts/cyborg_agent.py"

    # --- Build a simple fake source repo (no git) ---
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

    # --- Build a repo whose name has special characters ---
    cat > "$SPECIAL_REPO/README.md" <<'EOF'
# rockit++[1]

Special-character repo name for duplicate-search regression coverage.
EOF

    cat > "$SPECIAL_REPO/tool.py" <<'EOF'
print("special")
EOF

    # --- Build a real git repo for GitNexus tests ---
    cat > "$GIT_SOURCE_REPO/README.md" <<'EOF'
# Git Source Repo

Repo used to exercise the GitNexus-enhanced cyborg flow.
EOF

    cat > "$GIT_SOURCE_REPO/tool.py" <<'EOF'
print("git source")
EOF

    # Turn the git-source-repo into an actual git repository.
    (
        cd "$GIT_SOURCE_REPO"
        git init -q
        git config user.name "Cyborg Test"
        git config user.email "cyborg@example.com"
        git add README.md tool.py
        git commit -qm "initial"
    )

    # Give the plain source repo a tests/ folder so scans find it.
    mkdir -p "$SOURCE_REPO/tests"
    cat > "$SOURCE_REPO/tests/test_tool.py" <<'EOF'
def test_placeholder():
    assert True
EOF

    # --- Seed the fake blog with existing pages ---
    # The agent's duplicate-detection should find these during scans.
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

    # This page has a tricky name with special regex characters.
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

    # An existing workflow page. The agent should detect it as a
    # "strong match" when the repo changes and offer rewrite choices.
    mkdir -p "$BLOG_DIR/content/workflows/productivity-systems"
    cat > "$BLOG_DIR/content/workflows/productivity-systems/legacy-iteration-workflow.md" <<'EOF'
---
title: "Legacy Iteration Workflow"
description: "Existing workflow page that already documents the git-source-repo thread so resume-time rewrite choices have a strong match."
date: 2026-03-03
lastmod: 2026-03-03
draft: false
tags:
  - workflow
---

git-source-repo already appears here as a maintained workflow page.
EOF

    # --- Fake npx script ---
    # This stands in for the real "npx gitnexus" CLI.
    # It writes to a log so tests can check which commands were called,
    # and it returns canned responses that look like real GitNexus output.
    cat > "$FAKE_BIN/npx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# We only pretend to be gitnexus; reject anything else.
if [[ "${1:-}" != "gitnexus" ]]; then
    echo "fake npx only handles gitnexus in this test harness" >&2
    exit 1
fi
shift  # Remove "gitnexus" so $1 is now the subcommand.

command_name="${1:-}"
shift || true  # Remove the subcommand; the rest are arguments.

# Figure out the git root and current commit for realistic output.
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
repo_name="$(basename "$repo_root")"
current_commit="$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || echo "")"
meta_path="$repo_root/.gitnexus/meta.json"

# Record every call so tests can verify what happened.
if [[ -n "${FAKE_GITNEXUS_LOG:-}" ]]; then
    printf 'gitnexus %s %s\n' "$command_name" "$*" >> "$FAKE_GITNEXUS_LOG"
fi

case "$command_name" in
    status)
        # If there is no git repo, say so.
        if [[ ! -d "$repo_root/.git" ]]; then
            echo "Not a git repository."
            exit 0
        fi
        # If the index file does not exist, the repo is not indexed yet.
        if [[ ! -f "$meta_path" ]]; then
            echo "Repository not indexed."
            echo "Run: gitnexus analyze"
            exit 0
        fi
        # Otherwise, report a healthy, up-to-date index.
        echo "Repository: $repo_root"
        echo "Indexed: 3/16/2026, 9:00:00 AM"
        echo "Indexed commit: ${current_commit:0:7}"
        echo "Current commit: ${current_commit:0:7}"
        echo "Status: ✅ up-to-date"
        ;;
    analyze)
        # Create a fake index with some stats the agent can read.
        mkdir -p "$repo_root/.gitnexus"
        cat > "$meta_path" <<JSON
{
  "repoPath": "$repo_root",
  "lastCommit": "$current_commit",
  "indexedAt": "2026-03-16T15:00:00.000Z",
  "stats": {
    "files": 2,
    "nodes": 9,
    "edges": 18,
    "communities": 2,
    "processes": 1
  }
}
JSON
        echo "Indexed $repo_root"
        ;;
    list)
        # Show one indexed repo if the index exists, zero otherwise.
        if [[ -f "$meta_path" ]]; then
            cat <<LIST

  Indexed Repositories (1)

  $repo_name
    Path:    $repo_root
    Indexed: 3/16/2026, 9:00:00 AM
    Commit:  ${current_commit:0:7}
    Stats:   2 files, 9 symbols, 18 edges
    Clusters:   2
    Processes:  1
LIST
        else
            echo
            echo "  Indexed Repositories (0)"
        fi
        ;;
    query)
        # Return a canned graph query result with one execution flow.
        cat <<JSON
{
  "processes": [
    {
      "id": "proc_demo",
      "summary": "CLI Main -> Output Artifact",
      "priority": 0.91,
      "symbol_count": 2,
      "process_type": "cross_community",
      "step_count": 4
    }
  ],
  "process_symbols": [
    {
      "id": "Function:tool.py:main",
      "name": "main",
      "filePath": "tool.py",
      "startLine": 1,
      "endLine": 1,
      "module": "Scripts",
      "process_id": "proc_demo",
      "step_index": 1
    }
  ],
  "definitions": [
    {
      "id": "File:tool.py",
      "name": "tool.py",
      "filePath": "tool.py"
    }
  ]
}
JSON
        ;;
    clean)
        # Delete the local index folder.
        rm -rf "$repo_root/.gitnexus"
        ;;
    *)
        echo "Unsupported fake gitnexus command: $command_name" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$FAKE_BIN/npx"
}

# teardown() runs after every test to clean up the sandbox.
teardown() {
    teardown_test_environment
}

# ---- Basic ingest flow ----

# Test: scan a repo, build a content map, and create a publishing plan.
# Uses deterministic mode (no AI calls) so the test is repeatable.
@test "cyborg ingest scans current repo and builds map plus plan in deterministic mode" {
    run bash -lc "cd '$SOURCE_REPO' && printf '/map\n/plan\n/quit\n' | env DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' ingest 'focus on reusable commands'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Repo scan complete."* ]]
    [[ "$output" == *"## Proposed Pages"* ]]
    [[ "$output" == *"## Phases"* ]]

    # Exactly one session folder should have been created.
    session_count=$(find "$BLOG_DIR/drafts/ingest" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
    [ "$session_count" -eq 1 ]
}

# Test: go all the way from map to draft to apply, then check that
# the blog repo actually received a new markdown file marked draft.
@test "cyborg ingest can generate drafts and apply them to the blog repo" {
    run bash -lc "cd '$SOURCE_REPO' && printf '/map\n/plan\n/draft workflow-main\n/apply drafts --yes\n/quit\n' | env DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' ingest 'focus on the repeatable path'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Generated pending drafts for: workflow-main"* ]]
    [[ "$output" == *"Applied the selected pending changes into the Cyborg Lab repo."* ]]

    # Make sure a .md file landed in the workflows folder.
    run bash -lc "find '$BLOG_DIR/content/workflows' -type f -name '*.md' | head -n 1"
    [ "$status" -eq 0 ]
    workflow_path="$output"
    [ -n "$workflow_path" ]

    # The applied file should still be marked as a draft.
    run grep -n 'draft: true' "$workflow_path"
    [ "$status" -eq 0 ]
}

# ---- Session resume ----

# Test: create a session, quit, then resume it by its ID.
@test "cyborg resume reopens a saved session by explicit id" {
    # Start a session and immediately quit so it gets saved.
    run bash -lc "cd '$SOURCE_REPO' && printf '/quit\n' | env DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' ingest 'resume me later'"
    [ "$status" -eq 0 ]

    # Find the session ID that was just created.
    session_id=$(basename "$(find "$BLOG_DIR/drafts/ingest" -mindepth 1 -maxdepth 1 -type d | head -n 1)")
    [ -n "$session_id" ]

    # Resume that session and check that /status shows the right ID.
    run bash -lc "printf '/status\n/quit\n' | env DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' resume '$session_id'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Session: $session_id"* ]]
}

# ---- GitNexus approval gate ----

# Test: on a git repo the agent should pause for GitNexus approval.
# Choosing "skip" should let the native scan proceed normally.
@test "cyborg ingest pauses for GitNexus approval on git repos and can skip to native scan" {
    run bash -lc "cd '$GIT_SOURCE_REPO' && printf '/gitnexus skip\n/map\n/quit\n' | env PATH='$FAKE_BIN:$PATH' DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' ingest 'focus on the repeatable path'"

    [ "$status" -eq 0 ]
    # The agent should have asked for permission first.
    [[ "$output" == *"GitNexus is not configured here. I can initialize and analyze this repo to improve content mapping, cross-linking, and rewrite quality. Proceed?"* ]]
    # After skipping, native scanning should still work.
    [[ "$output" == *"GitNexus is skipped for this session."* ]]
    [[ "$output" == *"Repo scan complete."* ]]
}

# Test: approve GitNexus enhancement and verify graph signals show up.
@test "cyborg ingest can enhance a git repo and surface GitNexus graph signals" {
    run bash -lc "cd '$GIT_SOURCE_REPO' && printf '/gitnexus enhance\n/map\n/status\n/quit\n' | env PATH='$FAKE_BIN:$PATH' DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' ingest 'focus on graph signals'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"GitNexus enhancement completed."* ]]
    # The fake query result should appear in the content map.
    [[ "$output" == *"Flow: CLI Main -> Output Artifact"* ]]
    [[ "$output" == *"GitNexus: healthy (graph mode)"* ]]
}

# Test: a first-time enhance should NOT use --force (only refresh does).
@test "cyborg first-time gitnexus enhance does not pass --force" {
    run bash -lc "cd '$GIT_SOURCE_REPO' && printf '/gitnexus enhance\n/quit\n' | env PATH='$FAKE_BIN:$PATH' DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' ingest 'focus on the graph bootstrap'"

    [ "$status" -eq 0 ]
    # The log should NOT contain --force.
    run grep -n 'gitnexus analyze --force' "$FAKE_GITNEXUS_LOG"
    [ "$status" -eq 1 ]

    # But it should contain a plain "analyze ." call.
    run grep -n 'gitnexus analyze \.' "$FAKE_GITNEXUS_LOG"
    [ "$status" -eq 0 ]
}

@test "cyborg ingest accepts letter choices for pending GitNexus approval" {
    run bash -lc "cd '$GIT_SOURCE_REPO' && printf 'B\n/quit\n' | env PATH='$FAKE_BIN:$PATH' DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' ingest 'focus on graph signals'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"A. Explain the GitNexus plan in more detail."* ]]
    [[ "$output" == *"B. Approve the repo write step and run \`gitnexus analyze\` in this repo."* ]]
    [[ "$output" == *"GitNexus enhancement completed."* ]]

    run grep -n 'gitnexus analyze \.' "$FAKE_GITNEXUS_LOG"
    [ "$status" -eq 0 ]
}

# ---- Rewrite modes on resume ----

# Test: after the repo gets new commits, resuming a session should
# detect the change and offer "update", "iteration-log", or "merge".
@test "cyborg resume after repo changes offers rewrite modes for strong matches" {
    # Create the first session and immediately quit.
    run bash -lc "cd '$GIT_SOURCE_REPO' && printf '/gitnexus enhance\n/quit\n' | env PATH='$FAKE_BIN:$PATH' DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' ingest 'capture the initial workflow'"
    [ "$status" -eq 0 ]

    session_id=$(basename "$(find "$BLOG_DIR/drafts/ingest" -mindepth 1 -maxdepth 1 -type d | head -n 1)")
    [ -n "$session_id" ]

    # Make a real git commit so the agent sees the repo has changed.
    (
        cd "$GIT_SOURCE_REPO"
        printf '\nprint(\"iteration\")\n' >> tool.py
        git add tool.py
        git commit -qm "iteration"
    )

    # Resume the session. The agent should detect staleness, rebuild,
    # and offer a rewrite choice for the existing workflow page.
    run bash -lc "printf '/gitnexus refresh\n/map\n/rewrite 1 update\n/quit\n' | env PATH='$FAKE_BIN:$PATH' DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' resume '$session_id'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"GitNexus is stale for this repo. I can refresh the index so the next content map reflects the current project state. Proceed?"* ]]
    [[ "$output" == *"GitNexus enhancement completed."* ]]
    [[ "$output" == *"Strong existing-page matches detected after the refreshed map:"* ]]
    [[ "$output" == *"legacy-iteration-workflow.md"* ]]
    [[ "$output" == *"will now update"* ]]
}

@test "cyborg resume accepts compact letter choices for rewrite decisions" {
    run bash -lc "cd '$GIT_SOURCE_REPO' && printf '/gitnexus enhance\n/quit\n' | env PATH='$FAKE_BIN:$PATH' DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' ingest 'capture the initial workflow'"
    [ "$status" -eq 0 ]

    session_id=$(basename "$(find "$BLOG_DIR/drafts/ingest" -mindepth 1 -maxdepth 1 -type d | head -n 1)")
    [ -n "$session_id" ]

    (
        cd "$GIT_SOURCE_REPO"
        printf '\nprint("letter-choice")\n' >> tool.py
        git add tool.py
        git commit -qm "letter-choice"
    )

    run bash -lc "printf 'B\n/map\nA\n/quit\n' | env PATH='$FAKE_BIN:$PATH' DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' resume '$session_id'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Reply with \`A\`, \`B\`, \`C\`, \`D\`, or \`E\`"* ]]
    [[ "$output" == *"will now update"* ]]
}

# Test: even while a GitNexus decision is pending, /show should still
# work so the user can inspect a previously-generated draft.
@test "cyborg resume keeps /show available while a GitNexus decision is pending" {
    # Create a session that already has a draft.
    run bash -lc "cd '$GIT_SOURCE_REPO' && printf '/gitnexus enhance\n/map\n/plan\n/draft workflow-main\n/quit\n' | env PATH='$FAKE_BIN:$PATH' DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' ingest 'capture a draft before resume'"
    [ "$status" -eq 0 ]

    session_id=$(basename "$(find "$BLOG_DIR/drafts/ingest" -mindepth 1 -maxdepth 1 -type d | head -n 1)")
    [ -n "$session_id" ]

    # Push a new commit so the index goes stale.
    (
        cd "$GIT_SOURCE_REPO"
        printf '\nprint(\"pending\")\n' >> tool.py
        git add tool.py
        git commit -qm "pending"
    )

    # Resume and ask to show the draft without resolving GitNexus first.
    run bash -lc "printf '/show workflow-main\n/quit\n' | env PATH='$FAKE_BIN:$PATH' DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' resume '$session_id'"

    [ "$status" -eq 0 ]
    # The stale warning should appear, but the draft still prints.
    [[ "$output" == *"GitNexus is stale for this repo."* ]]
    [[ "$output" == *'type: "workflow"'* ]]
    [[ "$output" == *'title: "Git Source Repo Workflow"'* ]]
}

# Test: after choosing a rewrite mode and then rebuilding the map,
# the rewrite prompt should NOT appear a second time.
@test "cyborg rewrite prompt does not repeat after a choice and a fresh map rebuild" {
    run bash -lc "cd '$GIT_SOURCE_REPO' && printf '/gitnexus enhance\n/quit\n' | env PATH='$FAKE_BIN:$PATH' DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' ingest 'capture the initial workflow'"
    [ "$status" -eq 0 ]

    session_id=$(basename "$(find "$BLOG_DIR/drafts/ingest" -mindepth 1 -maxdepth 1 -type d | head -n 1)")
    [ -n "$session_id" ]

    (
        cd "$GIT_SOURCE_REPO"
        printf '\nprint(\"rewrite\")\n' >> tool.py
        git add tool.py
        git commit -qm "rewrite"
    )

    # Choose "update" for recommendation #1, then rebuild the map again.
    run bash -lc "printf '/gitnexus refresh\n/map\n/rewrite 1 update\n/map\n/quit\n' | env PATH='$FAKE_BIN:$PATH' DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' resume '$session_id'"

    [ "$status" -eq 0 ]
    # The "Strong existing-page matches" message should appear only once.
    prompt_count=$(printf '%s' "$output" | grep -o 'Strong existing-page matches detected after the refreshed map:' | wc -l | tr -d ' ')
    [ "$prompt_count" -eq 1 ]
}

# Test: choosing "iteration-log" should keep the original log item
# and add a brand-new "log-iteration" entry in the session JSON.
@test "cyborg iteration-log rewrite keeps the original log item and adds a separate iteration target" {
    run bash -lc "cd '$GIT_SOURCE_REPO' && printf '/gitnexus enhance\n/map\n/plan\n/draft log-main\n/quit\n' | env PATH='$FAKE_BIN:$PATH' DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' ingest 'capture the original narrative log'"
    [ "$status" -eq 0 ]

    session_id=$(basename "$(find "$BLOG_DIR/drafts/ingest" -mindepth 1 -maxdepth 1 -type d | head -n 1)")
    [ -n "$session_id" ]

    (
        cd "$GIT_SOURCE_REPO"
        printf '\nprint(\"iteration-log\")\n' >> tool.py
        git add tool.py
        git commit -qm "iteration-log"
    )

    run bash -lc "printf '/gitnexus refresh\n/map\n/rewrite 1 iteration-log\n/quit\n' | env PATH='$FAKE_BIN:$PATH' DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' resume '$session_id'"

    [ "$status" -eq 0 ]
    session_json="$BLOG_DIR/drafts/ingest/$session_id/session.json"
    # The original log item should still be in the JSON.
    run grep -n '"key": "log-main"' "$session_json"
    [ "$status" -eq 0 ]
    run grep -n '"path": "content/log/git-source-repo-field-report.md"' "$session_json"
    [ "$status" -eq 0 ]
    # A new iteration-log item should have been added.
    run grep -n '"key": "log-iteration"' "$session_json"
    [ "$status" -eq 0 ]
    run grep -n '"path": "content/log/git-source-repo-iteration-' "$session_json"
    [ "$status" -eq 0 ]
}

# ---- Link-only apply ----

# Test: /apply all should work even when there are only link edits
# and no new drafts pending. The special-character repo name also
# exercises the fixed-string search (rg -F) path.
@test "cyborg ingest applies link edits with /apply all even when no drafts are pending" {
    run bash -lc "printf '/map\n/links\n/patch-links 1\n/apply all --yes\n/quit\n' | env DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' ingest --repo '$SPECIAL_REPO' 'focus on cross linking'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Prepared pending edits for 1 existing page(s)."* ]]
    [[ "$output" == *"Applied the selected pending changes into the Cyborg Lab repo."* ]]

    # The existing blog page should now have a "## Related" section.
    run grep -n '## Related' "$BLOG_DIR/content/log/existing-special-rockit-note.md"
    [ "$status" -eq 0 ]
}

# ---- Error handling ----

# Test: passing a file that does not exist should print a friendly
# error message, not a raw Python traceback.
@test "cyborg ingest reports a friendly error for a missing markdown file" {
    run bash -lc "env DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' ingest --file '$SOURCE_REPO/missing.md'"

    [ "$status" -eq 2 ]
    [[ "$output" == *"Error: Unable to read source file"* ]]
    # No raw Python exception should leak to the user.
    [[ "$output" != *"FileNotFoundError"* ]]
}

# Test: if config.sh is missing, the shell launcher should stop
# immediately with a clear message instead of crashing later.
@test "cyborg launcher fails fast when config.sh is missing" {
    # Build a broken dotfiles tree that has the launcher but no config.sh.
    broken_dotfiles="$TEST_DIR/broken-dotfiles"
    mkdir -p "$broken_dotfiles/bin" "$broken_dotfiles/scripts"
    cp "$BATS_TEST_DIRNAME/../bin/cyborg" "$broken_dotfiles/bin/cyborg"
    cp "$BATS_TEST_DIRNAME/../scripts/cyborg_agent.py" "$broken_dotfiles/scripts/cyborg_agent.py"
    chmod +x "$broken_dotfiles/bin/cyborg" "$broken_dotfiles/scripts/cyborg_agent.py"

    run env DOTFILES_DIR="$broken_dotfiles" "$broken_dotfiles/bin/cyborg" ingest

    [ "$status" -eq 1 ]
    [[ "$output" == *"required config library is missing"* ]]
}
