#!/usr/bin/env bats
# test_cyborg_docs_sync.sh - Integration tests for the manifest-driven docs sync worker.

load helpers/test_helpers.sh
load helpers/assertions.sh

setup() {
    setup_test_environment

    export DOTFILES_DIR="$TEST_DIR/dotfiles"
    export SOURCE_REPO="$TEST_DIR/source-repo"
    export BLOG_DIR="$TEST_DIR/my-ms-ai-blog"
    export FIXTURE_DIR="$TEST_DIR/fixtures"

    mkdir -p "$DOTFILES_DIR/bin" "$DOTFILES_DIR/scripts" "$DOTFILES_DIR/scripts/lib"
    mkdir -p "$SOURCE_REPO" "$BLOG_DIR/archetypes" "$BLOG_DIR/content/projects" "$BLOG_DIR/content/workflows/productivity-systems" "$FIXTURE_DIR"

    cp "$BATS_TEST_DIRNAME/../bin/cyborg-sync" "$DOTFILES_DIR/bin/cyborg-sync"
    cp "$BATS_TEST_DIRNAME/../scripts/cyborg_docs_sync.py" "$DOTFILES_DIR/scripts/cyborg_docs_sync.py"
    cp "$BATS_TEST_DIRNAME/../scripts/lib/config.sh" "$DOTFILES_DIR/scripts/lib/config.sh"
    chmod +x "$DOTFILES_DIR/bin/cyborg-sync" "$DOTFILES_DIR/scripts/cyborg_docs_sync.py"

    cat > "$BLOG_DIR/archetypes/project.md" <<'EOF'
---
type: "project"
title: "{{ replace .Name "-" " " | title }}"
description: "Integrated project page with clear setup, execution, and verification."
status: "beta"
components: []
date: {{ .Date }}
lastmod: {{ .Date }}
last_tested: {{ .Date }}
draft: true
tags:
  - project
  - pipeline
---

## Outcome

## Components

## Pipeline

## Artifacts

## Verification

## Related
EOF

    cat > "$BLOG_DIR/archetypes/workflow.md" <<'EOF'
---
type: "workflow"
title: "{{ replace .Name "-" " " | title }}"
description: "Repeatable workflow with quick start, verification, and fallback."
jtbd: "Do"
prerequisites: []
related_workflows: []
related_references: []
date: {{ .Date }}
lastmod: {{ .Date }}
last_tested: {{ .Date }}
draft: true
tags:
  - workflow
categories:
  - Productivity Systems
---

## Need

## Walkthrough

## Verification

## Failure Mode

## Related
EOF

    cat > "$BLOG_DIR/content/projects/alias-scanner.md" <<'EOF'
---
type: project
title: Alias Scanner
description: "Old project page that needs a repo-grounded refresh while keeping the same title, page path, and published state for search continuity."
status: beta
components: []
date: 2026-03-01
lastmod: 2026-03-01
last_tested: 2026-03-01
draft: false
tags:
  - project
  - cli
---

## Outcome

Old project body.

## Components

- Old component.

## Pipeline

Old pipeline.

## Artifacts

- Old artifact.

## Verification

- Old verification.

## Related

- Old related link.
EOF

    cat > "$BLOG_DIR/content/workflows/productivity-systems/shell-alias-hygiene-audit.md" <<'EOF'
---
type: workflow
title: Shell Alias Hygiene Audit
description: "Old workflow page that needs a grounded refresh so the path, title, and publication state stay stable while the repo details change."
jtbd: Do
prerequisites: []
related_workflows: []
related_references: []
date: 2026-03-01
lastmod: 2026-03-01
last_tested: 2026-03-01
draft: false
tags:
  - workflow
categories:
  - Productivity Systems
---

## Need

Old workflow body.

## Walkthrough

Old walkthrough.

## Verification

- Old verification.

## Failure Mode

Old failure mode.

## Related

- Old related link.
EOF

    (
        cd "$BLOG_DIR"
        git init -q
        git config user.name "Docs Sync Test"
        git config user.email "docs-sync@example.com"
        git add .
        git commit -qm "initial blog"
    )

    cat > "$SOURCE_REPO/README.md" <<'EOF'
# Alias Scanner

Alias Scanner finds shadowed commands and duplicate aliases before shell config drift becomes a debugging session.
EOF

    cat > "$SOURCE_REPO/tool.py" <<'EOF'
print("initial")
EOF

    (
        cd "$SOURCE_REPO"
        git init -q
        git config user.name "Docs Sync Test"
        git config user.email "docs-sync@example.com"
        git add README.md tool.py
        git commit -qm "initial repo"
    )

    cat > "$SOURCE_REPO/README.md" <<'EOF'
# Alias Scanner

Alias Scanner finds shadowed commands, duplicate aliases, and the next cleanup step before shell config drift becomes a debugging session.
EOF

    cat > "$SOURCE_REPO/tool.py" <<'EOF'
print("shadowed commands")
EOF

    (
        cd "$SOURCE_REPO"
        git add README.md tool.py
        git commit -qm "refresh scanner behavior"
    )

    cat > "$SOURCE_REPO/.cyborg-docs.toml" <<EOF
version = 1
blog_root = "$BLOG_DIR"
base_ref = "HEAD~1"
head_ref = "HEAD"
site_branch_prefix = "codex/docs-sync"
test_commands = ["test -f README.md", "grep -q 'shadowed commands' README.md"]
site_check_commands = ["grep -q '^## Outcome' content/projects/alias-scanner.md", "grep -q '^## Verification' content/workflows/productivity-systems/shell-alias-hygiene-audit.md"]

[[pages]]
key = "alias-project"
path = "content/projects/alias-scanner.md"
type = "project"
mode = "update"

[[pages]]
key = "alias-workflow"
path = "content/workflows/productivity-systems/shell-alias-hygiene-audit.md"
type = "workflow"
mode = "update"
track = "Productivity Systems"
jtbd = "Do"
EOF

    cat > "$FIXTURE_DIR/alias-project.json" <<'EOF'
{
  "markdown": "---\ntype: project\ntitle: Alias Scanner\ndescription: \"Audit shell alias files for shadowed commands and duplicate definitions, so cleanup starts faster and shell behavior stays easier to trust under load.\"\nstatus: beta\ncomponents:\n  - scanner cli\n  - audit workflow\ndate: 2026-03-23\nlastmod: 2026-03-23\nlast_tested: 2026-03-23\ndraft: false\ntags:\n  - project\n  - shell\n---\n\n## Outcome\n\n[Alias Scanner](https://github.com/ryan258/alias-scanner) turns shell alias cleanup into a quick audit instead of a guessing game.\n\n## Components\n\n- Workflow: run the repeatable alias audit.\n- Repo: review the scanner and its README.\n\n## Pipeline\n\nStart with the repo, run the scan, fix the findings, and rerun until the report is clean.\n\n## Artifacts\n\n- The audit report in your terminal.\n\n## Verification\n\n- Run the scan and confirm the expected findings appear.\n\n## Related\n\n- [Shell Alias Hygiene Audit](/workflows/productivity-systems/shell-alias-cleanup/)\n",
  "confidence": 0.91,
  "changed_sections": ["Outcome", "Pipeline", "Verification"],
  "uncertain_points": []
}
EOF

    cat > "$FIXTURE_DIR/alias-workflow.json" <<'EOF'
{
  "markdown": "---\ntype: workflow\ntitle: Shell Alias Hygiene Audit\ndescription: \"Run a repeatable alias audit against shell config files, fix shadowing and duplicate definitions, and rerun until the report is clean under low cognitive load.\"\njtbd: Do\nprerequisites:\n  - alias-scanner installed\nrelated_workflows: []\nrelated_references: []\ndate: 2026-03-23\nlastmod: 2026-03-23\nlast_tested: 2026-03-23\ndraft: false\ntags:\n  - workflow\n  - shell\ncategories:\n  - Productivity Systems\n---\n\n## Need\n\nUse the [alias-scanner repository](https://github.com/ryan258/alias-scanner) when shell aliases have drifted and command behavior no longer feels safe.\n\n## Walkthrough\n\nRun the scanner, inspect the findings, fix the alias file, and rerun the same command.\n\n## Verification\n\n- The rerun no longer shows unexpected shadow or duplicate findings.\n\n## Failure Mode\n\nComplex shell syntax may still need manual review.\n\n## Related\n\n- [Alias Scanner](/projects/alias-scanner/)\n",
  "confidence": 0.89,
  "changed_sections": ["Need", "Walkthrough", "Verification"],
  "uncertain_points": []
}
EOF
}

@test "cyborg-sync plan prints mapped pages and repo diff context" {
    run bash -lc "env DOTFILES_DIR='$DOTFILES_DIR' '$DOTFILES_DIR/bin/cyborg-sync' --repo '$SOURCE_REPO' plan"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Diff range:"* ]]
    [[ "$output" == *"Mapped pages:"* ]]
    [[ "$output" == *"alias-project: project -> content/projects/alias-scanner.md"* ]]
    [[ "$output" == *"alias-workflow: workflow -> content/workflows/productivity-systems/shell-alias-hygiene-audit.md"* ]]
}

@test "cyborg-sync sync writes mapped pages, creates a site branch, and commits after checks" {
    run bash -lc "env DOTFILES_DIR='$DOTFILES_DIR' '$DOTFILES_DIR/bin/cyborg-sync' --repo '$SOURCE_REPO' --fixture-dir '$FIXTURE_DIR' sync --create-branch --commit"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Created site branch:"* ]]
    [[ "$output" == *"Committed site changes:"* ]]
    [[ "$output" == *"Updated 2 page(s). Skipped 0 low-confidence page(s)."* ]]

    run bash -lc "git -C '$BLOG_DIR' branch --show-current"
    [ "$status" -eq 0 ]
    [[ "$output" == codex/docs-sync/* ]]

    run bash -lc "git -C '$BLOG_DIR' log -1 --pretty=%s"
    [ "$status" -eq 0 ]
    [[ "$output" == "docs(sync): refresh source-repo from "* ]]

    run bash -lc "grep -q 'https://github.com/ryan258/alias-scanner' '$BLOG_DIR/content/projects/alias-scanner.md'"
    [ "$status" -eq 0 ]

    run bash -lc "grep -q '/workflows/productivity-systems/shell-alias-hygiene-audit/' '$BLOG_DIR/content/projects/alias-scanner.md'"
    [ "$status" -eq 0 ]

    run bash -lc "! grep -q '/workflows/productivity-systems/shell-alias-cleanup/' '$BLOG_DIR/content/projects/alias-scanner.md'"
    [ "$status" -eq 0 ]

    run bash -lc "grep -q '^categories:' '$BLOG_DIR/content/workflows/productivity-systems/shell-alias-hygiene-audit.md'"
    [ "$status" -eq 0 ]
}

@test "cyborg-sync sync --commit stays on the current branch when create-branch is omitted" {
    run bash -lc "git -C '$BLOG_DIR' branch --show-current"
    [ "$status" -eq 0 ]
    starting_branch="$output"

    run bash -lc "env DOTFILES_DIR='$DOTFILES_DIR' '$DOTFILES_DIR/bin/cyborg-sync' --repo '$SOURCE_REPO' --fixture-dir '$FIXTURE_DIR' sync --commit"

    [ "$status" -eq 0 ]
    [[ "$output" != *"Created site branch:"* ]]
    [[ "$output" == *"Committed site changes:"* ]]

    run bash -lc "git -C '$BLOG_DIR' branch --show-current"
    [ "$status" -eq 0 ]
    [ "$output" = "$starting_branch" ]
}
