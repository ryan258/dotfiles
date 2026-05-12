#!/usr/bin/env bats

# test_observer_v3.sh - Bats coverage for V3 web clips, sources, and concept tags.

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment
    OBSERVER_SCRIPT="$BATS_TEST_DIRNAME/../scripts/observer.sh"
    export OBSIDIAN_VAULT="$TEST_DIR/vault"
}

teardown() {
    teardown_test_environment
}

write_clip() {
    local path="$1"
    local clipped="$2"
    local tags="${3:-source}"
    mkdir -p "$(dirname "$path")"
    cat > "$path" <<MD
---
type: web-clip
status: raw
title: Context Recovery
url: https://example.com/context
site: example.com
author:
published:
clipped: $clipped
clip_type: article
tags:
  - $tags
---

# Context Recovery

## Source
- URL: https://example.com/context
- Site: example.com
- Author:
- Published:
- Clipped: $clipped

## Highlights
- Good systems make reentry cheap.

## Raw Content
Long clipped article body.

## Processing Notes
<!-- codex:start notes -->
<!-- codex:end notes -->
MD
}

@test "observer init-vault creates V3 source structure" {
    run "$OBSERVER_SCRIPT" init-vault
    [ "$status" -eq 0 ]
    [ -d "$OBSIDIAN_VAULT/raw/web-clips/articles" ]
    [ -d "$OBSIDIAN_VAULT/raw/web-clips/archive" ]
    [ -d "$OBSIDIAN_VAULT/wiki/sources" ]
    assert_file_exists "$OBSIDIAN_VAULT/maps/source-index.md"
    assert_file_contains "$OBSIDIAN_VAULT/AGENTS.md" "## Web Clips"
    assert_file_contains "$OBSIDIAN_VAULT/AGENTS.md" "## Markers And Tags"
}

@test "source-index finds promote tags and incoming raw clip links" {
    write_clip "$OBSIDIAN_VAULT/raw/web-clips/articles/2026-05-11-example-com-context-recovery.md" 2026-05-11 promote/source
    run "$OBSERVER_SCRIPT" ensure-daily 2026-05-11
    [ "$status" -eq 0 ]
    python3 - "$OBSIDIAN_VAULT/daily/2026-05-11.md" <<'PY'
from pathlib import Path
path = Path(__import__("sys").argv[1])
text = path.read_text()
text = text.replace(
    "<!-- user:start notes -->\n<!-- user:end notes -->",
    "<!-- user:start notes -->\nSee [[raw/web-clips/articles/2026-05-11-example-com-context-recovery]].\n<!-- user:end notes -->",
)
path.write_text(text)
PY

    run "$OBSERVER_SCRIPT" source-index 2026-05-11
    [ "$status" -eq 0 ]
    assert_file_contains "$OBSIDIAN_VAULT/maps/source-index.md" "[candidate]"
    assert_file_contains "$OBSIDIAN_VAULT/maps/source-index.md" "#promote/source"
    assert_file_contains "$OBSIDIAN_VAULT/maps/source-index.md" "incoming raw link"
}

@test "source-index surfaces stale raw clips" {
    write_clip "$OBSIDIAN_VAULT/raw/web-clips/articles/2026-03-01-example-com-old.md" 2026-03-01 source

    run "$OBSERVER_SCRIPT" source-index 2026-05-11
    [ "$status" -eq 0 ]
    assert_file_contains "$OBSIDIAN_VAULT/maps/source-index.md" "[stale]"
    assert_file_contains "$OBSIDIAN_VAULT/maps/source-index.md" "2026-03-01"
}

@test "source-note promotes a clip into a citation-backed source note" {
    clip="$OBSIDIAN_VAULT/raw/web-clips/articles/2026-05-11-example-com-context-recovery.md"
    write_clip "$clip" 2026-05-11 promote/source

    run "$OBSERVER_SCRIPT" source-note \
        --clip "$clip" \
        --date 2026-05-11 \
        --claim "Reentry should be cheap." \
        --supports "[[wiki/concepts/context-recovery|context recovery]]" \
        --caveats "Single article source."
    [ "$status" -eq 0 ]
    source_path="$output"
    assert_file_exists "$source_path"
    assert_file_contains "$source_path" "type: source"
    assert_file_contains "$source_path" "source_url: https://example.com/context"
    grep -Fq -- "[[raw/web-clips/articles/2026-05-11-example-com-context-recovery]]" "$source_path"
    assert_file_contains "$source_path" "Reentry should be cheap."
    grep -Fq -- "[[wiki/sources/2026-05-11-example-com-context-recovery|Context Recovery]]" "$OBSIDIAN_VAULT/maps/source-index.md"
}

@test "source-note refuses duplicate promotion for the same raw clip" {
    clip="$OBSIDIAN_VAULT/raw/web-clips/articles/2026-05-11-example-com-context-recovery.md"
    write_clip "$clip" 2026-05-11 promote/source

    run "$OBSERVER_SCRIPT" source-note --clip "$clip" --date 2026-05-11 --claim "One source."
    [ "$status" -eq 0 ]
    run "$OBSERVER_SCRIPT" source-note --clip "$clip" --date 2026-05-11 --claim "Duplicate source."
    [ "$status" -ne 0 ]
    [[ "$output" == *"Source note already exists for clip"* ]]
}

@test "concept tag candidates count YAML and inline tags" {
    mkdir -p "$OBSIDIAN_VAULT/wiki/sources" "$OBSIDIAN_VAULT/daily"
    cat > "$OBSIDIAN_VAULT/wiki/sources/a.md" <<'MD'
---
type: source
tags:
  - concept/context-recovery
---
# A
MD
    cat > "$OBSIDIAN_VAULT/wiki/sources/b.md" <<'MD'
---
type: source
tags:
  - concept/context-recovery
---
# B
MD
    cat > "$OBSIDIAN_VAULT/daily/2026-05-11.md" <<'MD'
# 2026-05-11
This relates to #concept/context-recovery.
MD

    run "$OBSERVER_SCRIPT" source-index 2026-05-11
    [ "$status" -eq 0 ]
    assert_file_contains "$OBSIDIAN_VAULT/maps/source-index.md" "#concept/context-recovery"
    run "$OBSERVER_SCRIPT" graph concept-tags --date 2026-05-11
    [ "$status" -eq 0 ]
    [[ "$output" == *"\`#concept/context-recovery\` - 3 notes"* ]]
}

@test "concept-note update touches only sourced-claims block" {
    run "$OBSERVER_SCRIPT" concept-note \
        --title "Context Recovery" \
        --date 2026-05-11 \
        --related "[[daily/2026-05-11|2026-05-11]]"
    [ "$status" -eq 0 ]
    concept_path="$output"
    python3 - "$concept_path" <<'PY'
from pathlib import Path
path = Path(__import__("sys").argv[1])
text = path.read_text().replace("User-owned explanation.", "Do not overwrite this prose.")
path.write_text(text)
PY

    run "$OBSERVER_SCRIPT" concept-note \
        --title "Context Recovery" \
        --slug context-recovery \
        --date 2026-05-12 \
        --related "[[daily/2026-05-11|2026-05-11]]" \
        --sourced-claim "Reentry should be cheap from [[wiki/sources/a|A]]." \
        --update
    [ "$status" -eq 0 ]
    assert_file_contains "$concept_path" "Do not overwrite this prose."
    assert_file_contains "$concept_path" "Reentry should be cheap"
}

@test "source-archive moves reviewed stale clips to archive" {
    clip="$OBSIDIAN_VAULT/raw/web-clips/articles/2026-03-01-example-com-old.md"
    write_clip "$clip" 2026-03-01 source

    run "$OBSERVER_SCRIPT" source-archive --clip "$clip" --date 2026-05-11
    [ "$status" -eq 0 ]
    [ ! -f "$clip" ]
    assert_file_exists "$OBSIDIAN_VAULT/raw/web-clips/archive/2026-03-01-example-com-old.md"
}
