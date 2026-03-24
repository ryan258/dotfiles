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
    cp "$BATS_TEST_DIRNAME/../scripts/cyborg_build.py" "$DOTFILES_DIR/scripts/cyborg_build.py"
    cp "$BATS_TEST_DIRNAME/../scripts/cyborg_support.py" "$DOTFILES_DIR/scripts/cyborg_support.py"
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

# ---- Autopilot mode ----

# Test: 'cyborg auto' runs the full pipeline hands-free and applies
# drafts when --yes is passed, without any interactive prompts.
@test "cyborg auto runs full pipeline and applies with --yes" {
    run bash -lc "env DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' auto --repo '$SOURCE_REPO' --yes 'focus on CLI'"

    [ "$status" -eq 0 ]
    # Should show the autopilot header.
    [[ "$output" == *"Cyborg autopilot session:"* ]]
    # Should run through the pipeline phases.
    [[ "$output" == *"Autopilot: building content map"* ]]
    [[ "$output" == *"Autopilot: building publishing plan"* ]]
    [[ "$output" == *"Autopilot: drafting all pages"* ]]
    # Should show the summary banner.
    [[ "$output" == *"AUTOPILOT COMPLETE"* ]]
    # Should apply changes.
    [[ "$output" == *"Applied the selected pending changes into the Cyborg Lab repo."* ]]
}

# Test: 'cyborg auto' on a git repo auto-skips GitNexus when CLI is
# unavailable and still completes the full pipeline.
@test "cyborg auto skips GitNexus when CLI is unavailable" {
    # Do not put fake-bin on PATH so gitnexus CLI is not found.
    run bash -lc "env DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true CYBORG_DISABLE_GITNEXUS=false '$DOTFILES_DIR/bin/cyborg' auto --repo '$GIT_SOURCE_REPO' --yes"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Cyborg autopilot session:"* ]]
    [[ "$output" == *"AUTOPILOT COMPLETE"* ]]
    [[ "$output" == *"Applied the selected pending changes into the Cyborg Lab repo."* ]]
}

# Test: 'cyborg auto' without --yes in non-interactive mode saves
# the session instead of applying.
@test "cyborg auto without --yes saves session in non-interactive mode" {
    run bash -lc "env DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' auto --repo '$SOURCE_REPO'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"AUTOPILOT COMPLETE"* ]]
    [[ "$output" == *"Non-interactive mode. Resume with: cyborg resume"* ]]
}

# Test: 'cyborg auto --build' without AI mode gives a friendly error.
@test "cyborg auto --build requires AI mode" {
    run bash -lc "env DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' auto --build 'a spoon tracker CLI'"

    [ "$status" -eq 2 ]
    [[ "$output" == *"--build requires AI mode"* ]]
}

# Test: 'cyborg auto --build' without an idea gives a friendly error.
@test "cyborg auto --build requires an idea" {
    run bash -lc "env DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' OPENROUTER_API_KEY=test-key '$DOTFILES_DIR/bin/cyborg' auto --build"

    [ "$status" -eq 2 ]
    [[ "$output" == *"--build requires an idea"* ]]
}

# Test: 'cyborg auto --no-morphling' skips the Morphling pre-analysis
# and still completes the full autopilot pipeline.
@test "cyborg auto --no-morphling skips pre-analysis and completes pipeline" {
    run bash -lc "env DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' auto --no-morphling --repo '$SOURCE_REPO' --yes"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Cyborg autopilot session:"* ]]
    [[ "$output" == *"AUTOPILOT COMPLETE"* ]]
    # Morphling pre-analysis should NOT have been loaded.
    [[ "$output" != *"Morphling pre-analysis loaded"* ]]
    [[ "$output" == *"Applied the selected pending changes into the Cyborg Lab repo."* ]]
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
    cp "$BATS_TEST_DIRNAME/../scripts/cyborg_build.py" "$broken_dotfiles/scripts/cyborg_build.py"
    cp "$BATS_TEST_DIRNAME/../scripts/cyborg_support.py" "$broken_dotfiles/scripts/cyborg_support.py"
    chmod +x "$broken_dotfiles/bin/cyborg" "$broken_dotfiles/scripts/cyborg_agent.py"

    run env DOTFILES_DIR="$broken_dotfiles" "$broken_dotfiles/bin/cyborg" ingest

    [ "$status" -eq 1 ]
    [[ "$output" == *"required config library is missing"* ]]
}

# ---- Publish flag (--publish) ----

# Test: _detect_publish_recipe returns the correct recipe for each marker file.
@test "publish: _detect_publish_recipe matches marker files correctly" {
    run python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
from pathlib import Path
import tempfile, os

with tempfile.TemporaryDirectory() as d:
    p = Path(d)
    # No marker file → None
    from cyborg_agent import _detect_publish_recipe
    assert _detect_publish_recipe(p) is None, 'empty dir should return None'

    # package.json → npm recipe
    (p / 'package.json').write_text('{}')
    recipe = _detect_publish_recipe(p)
    assert recipe is not None
    assert recipe[0] == 'package.json', f'expected package.json, got {recipe[0]}'

    # pyproject.toml wins when package.json is removed
    (p / 'package.json').unlink()
    (p / 'pyproject.toml').write_text('[project]')
    recipe = _detect_publish_recipe(p)
    assert recipe[0] == 'pyproject.toml', f'expected pyproject.toml, got {recipe[0]}'

    # Cargo.toml
    (p / 'pyproject.toml').unlink()
    (p / 'Cargo.toml').write_text('[package]')
    recipe = _detect_publish_recipe(p)
    assert recipe[0] == 'Cargo.toml', f'expected Cargo.toml, got {recipe[0]}'

    # go.mod
    (p / 'Cargo.toml').unlink()
    (p / 'go.mod').write_text('module example')
    recipe = _detect_publish_recipe(p)
    assert recipe[0] == 'go.mod', f'expected go.mod, got {recipe[0]}'

print('all ecosystem detections passed')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"all ecosystem detections passed"* ]]
}

# Test: _validate_publish_prereqs reports missing env vars.
@test "publish: _validate_publish_prereqs catches missing env vars" {
    run python3 -c "
import sys, os; sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
from cyborg_agent import _validate_publish_prereqs

# npm recipe with NPM_TOKEN not set.
os.environ.pop('NPM_TOKEN', None)
recipe = ('package.json', ['npm'], ['NPM_TOKEN'], [], 'npm publish 2>&1')
errors = _validate_publish_prereqs(recipe)
assert any('NPM_TOKEN' in e for e in errors), f'expected NPM_TOKEN error, got {errors}'

# With NPM_TOKEN set, the env var error should disappear.
os.environ['NPM_TOKEN'] = 'test-token'
errors = _validate_publish_prereqs(recipe)
env_errors = [e for e in errors if 'NPM_TOKEN' in e]
assert len(env_errors) == 0, f'unexpected NPM_TOKEN error: {errors}'

print('prereq validation passed')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"prereq validation passed"* ]]
}

# Test: _validate_publish_prereqs reports a missing Python build module.
@test "publish: _validate_publish_prereqs catches missing build module" {
    run python3 -c "
import sys, unittest.mock; sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
import cyborg_build
from cyborg_agent import _validate_publish_prereqs

recipe = ('pyproject.toml', ['python3'], [], ['python3 -m build 2>&1'], 'twine upload dist/* 2>&1')
with unittest.mock.patch.object(cyborg_build.importlib.util, 'find_spec', return_value=None):
    errors = _validate_publish_prereqs(recipe)
    assert any('build' in e for e in errors), f'expected build error, got {errors}'

print('build module validation passed')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"build module validation passed"* ]]
}

# Test: _setup_npm_auth writes a temp config without clobbering project .npmrc.
@test "publish: _setup_npm_auth creates temp auth config and preserves project .npmrc" {
    run python3 -c "
import sys, os; sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
from pathlib import Path
import tempfile
from cyborg_agent import _setup_npm_auth

with tempfile.TemporaryDirectory() as d:
    p = Path(d)
    project_npmrc = p / '.npmrc'
    project_npmrc.write_text('registry=https://registry.npmjs.org/\n', encoding='utf-8')

    # Without NPM_TOKEN, returns None.
    os.environ.pop('NPM_TOKEN', None)
    result = _setup_npm_auth(p)
    assert result is None, 'should return None without token'

    # With NPM_TOKEN, creates a temp auth config instead of overwriting .npmrc.
    os.environ['NPM_TOKEN'] = 'tok_abc123'
    npmrc = _setup_npm_auth(p)
    assert npmrc is not None, 'should return path'
    assert npmrc.exists(), 'temp auth config should exist'
    assert npmrc != project_npmrc, 'should not overwrite project .npmrc'
    content = npmrc.read_text()
    assert '//registry.npmjs.org/:_authToken=tok_abc123' in content, f'wrong content: {content}'
    assert project_npmrc.read_text() == 'registry=https://registry.npmjs.org/\n', 'project .npmrc should be unchanged'

    # Simulate cleanup like _publish_project does.
    npmrc.unlink()
    assert not npmrc.exists(), 'temp auth config should be cleaned up'
    assert project_npmrc.exists(), 'project .npmrc should remain after cleanup'

print('npm auth setup passed')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"npm auth setup passed"* ]]
}

# Test: _commit_metadata_changes only commits publish metadata files.
@test "publish: _commit_metadata_changes is a no-op when nothing changed" {
    run python3 -c "
import sys, os; sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
from pathlib import Path
import tempfile, subprocess
from cyborg_agent import _commit_metadata_changes

with tempfile.TemporaryDirectory() as d:
    p = Path(d)
    # Initialize a git repo with one metadata file.
    subprocess.run(['git', 'init', '-q'], cwd=p, check=True)
    subprocess.run(['git', 'config', 'user.name', 'Test'], cwd=p, check=True)
    subprocess.run(['git', 'config', 'user.email', 'test@test'], cwd=p, check=True)
    (p / 'package.json').write_text('{}\\n')
    subprocess.run(['git', 'add', 'package.json'], cwd=p, check=True)
    subprocess.run(['git', 'commit', '-qm', 'init'], cwd=p, check=True)

    # No changes → should return False and not create a new commit.
    initial_log = subprocess.run(['git', 'log', '--oneline'], cwd=p, capture_output=True, text=True).stdout
    result = _commit_metadata_changes(p)
    assert result == False, f'expected False, got {result}'
    final_log = subprocess.run(['git', 'log', '--oneline'], cwd=p, capture_output=True, text=True).stdout
    assert initial_log == final_log, 'no extra commit should exist'

    # Metadata change plus generated artifacts → only metadata should be committed.
    (p / 'package.json').write_text('{\"name\":\"demo\",\"description\":\"updated\"}\\n')
    (p / 'node_modules' / 'leftpad').mkdir(parents=True)
    (p / 'node_modules' / 'leftpad' / 'index.js').write_text('module.exports = 1\\n')
    result = _commit_metadata_changes(p)
    assert result == True, f'expected True, got {result}'
    final_log = subprocess.run(['git', 'log', '--oneline'], cwd=p, capture_output=True, text=True).stdout
    assert len(final_log.strip().split(chr(10))) == 2, f'expected 2 commits: {final_log}'
    show = subprocess.run(['git', 'show', '--name-only', '--pretty=format:', 'HEAD'], cwd=p, capture_output=True, text=True, check=True).stdout
    assert 'package.json' in show, f'package.json should be committed: {show}'
    assert 'node_modules' not in show, f'build artifacts should stay out of the commit: {show}'
    status = subprocess.run(['git', 'status', '--short'], cwd=p, capture_output=True, text=True, check=True).stdout
    assert 'node_modules' in status, f'artifacts should remain untracked: {status}'

print('commit metadata changes passed')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"commit metadata changes passed"* ]]
}

# Test: --publish without --build gives a friendly error.
@test "publish: --publish requires --build" {
    run bash -lc "env DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' '$DOTFILES_DIR/bin/cyborg' auto --publish 'a test project'"

    [ "$status" -eq 2 ]
    [[ "$output" == *"--publish requires --build."* ]]
}

# Test: --publish with --build still requires AI mode.
@test "publish: --publish with --build requires AI mode" {
    run bash -lc "env DOTFILES_DIR='$DOTFILES_DIR' CYBORG_LAB_DIR='$BLOG_DIR' CYBORG_DISABLE_AI=true '$DOTFILES_DIR/bin/cyborg' auto --build --publish 'a test project'"

    [ "$status" -eq 2 ]
    [[ "$output" == *"--build requires AI mode"* ]]
}

# Test: _publish_project returns False for unrecognised ecosystem.
@test "publish: _publish_project returns False when no marker file exists" {
    run python3 -c "
import sys, os; sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
from pathlib import Path
import tempfile

# Provide a stub ai_client so we can call the function.
class FakeAI:
    enabled = False
    def chat_json(self, *a, **kw):
        return {}

from cyborg_agent import _publish_project

with tempfile.TemporaryDirectory() as d:
    p = Path(d)
    result = _publish_project(p, 'test', 'A test', 'idea', FakeAI(), assume_yes=True)
    assert result == False, f'expected False for empty dir, got {result}'

print('no marker returns False')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no marker returns False"* ]]
}

# ---- Market validation (--no-validate) ----

# Test: _format_validation_report produces correct labels for each verdict.
@test "market: _format_validation_report labels green/yellow/red correctly" {
    run python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
from cyborg_agent import _format_validation_report

green = _format_validation_report({'verdict': 'green', 'summary': 'Wide open.'})
assert '[OPEN]' in green, f'green should show [OPEN]: {green}'

yellow = _format_validation_report({
    'verdict': 'yellow',
    'summary': 'Some options exist.',
    'existing_solutions': [{'name': 'foo', 'source': 'github', 'stars_or_downloads': '1k', 'description': 'A foo tool'}],
    'gap_analysis': 'There is a gap in accessibility.',
    'differentiation_suggestions': ['Add screen reader support'],
})
assert '[CROWDED]' in yellow, f'yellow should show [CROWDED]: {yellow}'
assert 'foo' in yellow, 'should list existing solutions'
assert 'gap in accessibility' in yellow
assert 'screen reader' in yellow

red = _format_validation_report({'verdict': 'red', 'summary': 'Saturated.'})
assert '[SATURATED]' in red, f'red should show [SATURATED]: {red}'

print('all format labels passed')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"all format labels passed"* ]]
}

# Test: validate_market returns True when search results are empty (graceful).
@test "market: validate_market proceeds when no search results found" {
    run python3 -c "
import sys, os, unittest.mock; sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
import cyborg_build

class FakeAI:
    enabled = True
    def chat_json(self, *a, **kw):
        return {'verdict': 'green', 'summary': 'Nothing found.'}

# Patch in cyborg_build where validate_market actually resolves the names.
with unittest.mock.patch.object(cyborg_build, '_search_github', return_value=[]), \
     unittest.mock.patch.object(cyborg_build, '_search_npm', return_value=[]):
    result = cyborg_build.validate_market('test idea', FakeAI(), assume_yes=True, interactive=False)
    assert result == True, f'expected True when no results, got {result}'

print('empty results proceeds')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"empty results proceeds"* ]]
}

# Test: validate_market proceeds even when AI synthesis fails (graceful degradation).
@test "market: validate_market proceeds when AI synthesis raises an exception" {
    run python3 -c "
import sys, os, unittest.mock; sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
import cyborg_build

class FailingAI:
    enabled = True
    def chat_json(self, *a, **kw):
        raise RuntimeError('API down')

# Return some search results so we actually reach the AI call.
fake_results = [{'name': 'test', 'full_name': 'x/test', 'description': 'desc', 'stars': 10, 'url': '', 'updated_at': '', 'language': 'Python'}]
with unittest.mock.patch.object(cyborg_build, '_search_github', return_value=fake_results), \
     unittest.mock.patch.object(cyborg_build, '_search_npm', return_value=[]):
    result = cyborg_build.validate_market('test idea', FailingAI(), assume_yes=True, interactive=False)
    assert result == True, f'expected True on AI failure, got {result}'

print('ai failure graceful')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ai failure graceful"* ]]
}

# Test: validate_market shows red warning but proceeds with --yes.
@test "market: validate_market warns on red verdict but proceeds with assume_yes" {
    run python3 -c "
import sys, os, unittest.mock; sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
import cyborg_build

class RedAI:
    enabled = True
    def chat_json(self, *a, **kw):
        return {'verdict': 'red', 'summary': 'Market is saturated.', 'existing_solutions': [], 'gap_analysis': '', 'differentiation_suggestions': []}

fake_results = [{'name': 'existing', 'full_name': 'x/existing', 'description': 'Already exists', 'stars': 5000, 'url': '', 'updated_at': '', 'language': 'JS'}]
with unittest.mock.patch.object(cyborg_build, '_search_github', return_value=fake_results), \
     unittest.mock.patch.object(cyborg_build, '_search_npm', return_value=[]):
    result = cyborg_build.validate_market('clipboard manager', RedAI(), assume_yes=True, interactive=False)
    assert result == True, f'expected True with assume_yes even on red, got {result}'

print('red with yes proceeds')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"red with yes proceeds"* ]]
}

# Test: --no-validate flag is accepted by the argument parser.
@test "market: --no-validate flag is accepted by argparser" {
    run python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
from cyborg_agent import build_parser
parser = build_parser()
args = parser.parse_args(['auto', '--build', '--no-validate', 'test idea'])
assert args.no_validate == True, f'expected no_validate=True, got {args.no_validate}'
args2 = parser.parse_args(['auto', '--build', 'test idea'])
assert args2.no_validate == False, f'expected no_validate=False by default, got {args2.no_validate}'
print('no-validate flag accepted')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no-validate flag accepted"* ]]
}

# Test: --publish flag is accepted by the argument parser.
@test "market: --publish flag is accepted by argparser" {
    run python3 -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
from cyborg_agent import build_parser
parser = build_parser()
args = parser.parse_args(['auto', '--build', '--publish', 'test idea'])
assert args.publish == True, f'expected publish=True, got {args.publish}'
args2 = parser.parse_args(['auto', '--build', 'test idea'])
assert args2.publish == False, f'expected publish=False by default, got {args2.publish}'
print('publish flag accepted')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"publish flag accepted"* ]]
}
