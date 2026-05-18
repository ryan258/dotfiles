#!/usr/bin/env bash
set -euo pipefail

# inventory.sh - Generate Phase 0 dotfiles inventory docs.

INVENTORY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$INVENTORY_SCRIPT_DIR/.." && pwd)}"

if [ -f "$INVENTORY_SCRIPT_DIR/lib/config.sh" ]; then
    # shellcheck disable=SC1090
    source "$INVENTORY_SCRIPT_DIR/lib/config.sh"
fi

if [ -f "$INVENTORY_SCRIPT_DIR/lib/common.sh" ]; then
    # shellcheck disable=SC1090
    source "$INVENTORY_SCRIPT_DIR/lib/common.sh"
fi

usage() {
    cat <<'EOF'
Usage: inventory.sh <summary|generate> [output_dir]

Commands:
  summary              Print current Phase 0 inventory metrics.
  generate [out_dir]   Write generated inventory docs.
  help                 Show this help text.

Options:
  -h, --help           Show this help text.

Default output directory: docs/generated
EOF
}

count_find() {
    find "$@" -type f 2>/dev/null | wc -l | tr -d ' '
}

loc_from_find() {
    local total=0
    local file=""
    local lines=0

    while IFS= read -r -d '' file; do
        lines=$(wc -l < "$file" | tr -d ' ')
        total=$((total + lines))
    done

    printf '%s' "$total"
}

code_loc_scripts_bin() {
    find "$DOTFILES_DIR/scripts" "$DOTFILES_DIR/bin" \
        -type f \( -name '*.sh' -o -name '*.py' -o -name 'cyborg' -o -name 'cyborg-sync' \) \
        -print0 | loc_from_find
}

loc_for_files() {
    local total=0
    local file=""
    local lines=0

    for file in "$@"; do
        if [ -f "$DOTFILES_DIR/$file" ]; then
            lines=$(wc -l < "$DOTFILES_DIR/$file" | tr -d ' ')
            total=$((total + lines))
        fi
    done

    printf '%s' "$total"
}

line_count() {
    local file="$1"
    if [ -f "$DOTFILES_DIR/$file" ]; then
        wc -l < "$DOTFILES_DIR/$file" | tr -d ' '
    else
        printf '0'
    fi
}

alias_name_from_line() {
    local line="$1"
    local name=""

    if [[ "$line" == alias\ -g\ * ]]; then
        name="${line#alias -g }"
    else
        name="${line#alias }"
    fi

    name="${name%%=*}"
    printf '%s' "$name"
}

alias_class() {
    local name="$1"

    case "$name" in
        startday|status|goodevening|todo|todolist|tododone|todoadd|t|ta|journal|j|ja|health|meds|spoons|s-check|s-spend|focus|schedule|remind|gcal|drive|did|done)
            printf 'daily-core'
            ;;
        cyborg|cyborg-sync|observer|ap|apy|apb|apby|apbp|apbpy|apc|morphling|dhp|dhp-*|tech|creative|content|strategy|brand|market|stoic|research|narrative|aicopy|finance|memory|memory-search|dispatch|ai-*|swipe)
            printf 'compatibility'
            ;;
        rm|cp|mv|python|pip|du|df|ping|calendar|doneit|gwip|gitquick|quickbackup|copyfolder|update|reload)
            printf 'risky'
            ;;
        *)
            printf 'convenience'
            ;;
    esac
}

script_inventory_paths() {
    {
        find "$DOTFILES_DIR/scripts" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' \) -print 2>/dev/null
        find "$DOTFILES_DIR/scripts/lib" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' \) -print 2>/dev/null
        find "$DOTFILES_DIR/bin" -maxdepth 1 -type f ! -name '*.md' -print 2>/dev/null
    } | sort
}

script_class() {
    local rel_path="$1"

    case "$rel_path" in
        scripts/lib/*)
            printf 'support-library'
            ;;
        scripts/startday.sh|scripts/status.sh|scripts/goodevening.sh|scripts/todo.sh|scripts/journal.sh|scripts/health.sh|scripts/meds.sh|scripts/spoon_manager.sh|scripts/focus.sh|scripts/schedule.sh|scripts/remind_me.sh|scripts/gcal.sh|scripts/drive.sh|scripts/done.sh|scripts/idea.sh|scripts/time_tracker.sh|scripts/take_a_break.sh|scripts/week_in_review.sh|scripts/generate_report.sh|scripts/fitbit_import.sh|scripts/fitbit_sync.sh|scripts/correlate.sh|scripts/insight.sh|scripts/repo_tracker.sh|scripts/my_progress.sh|scripts/gh-projects.sh)
            printf 'daily-core'
            ;;
        bin/coach-chat.py|bin/dhp-context.sh|bin/dhp-lib.sh|bin/dhp-shared.sh|bin/dhp-swarm.py|bin/dhp-utils.sh)
            printf 'support-library'
            ;;
        scripts/observer.sh|scripts/gitnexus.sh|bin/cyborg|bin/cyborg-sync|bin/dispatch.sh|bin/dhp-*.sh|bin/morphling.sh)
            printf 'compatibility-wrapper'
            ;;
        scripts/observer.py|scripts/cyborg_agent.py|scripts/cyborg_build.py|scripts/cyborg_docs_sync.py|scripts/cyborg_support.py|scripts/cyborg_scoped_site_check.sh|scripts/blog.sh|scripts/blog_recent_content.sh)
            printf 'sibling-product-candidate'
            ;;
        *)
            printf 'support-utility'
            ;;
    esac
}

script_note() {
    local class="$1"

    case "$class" in
        daily-core)
            printf 'Directly supports daily loop, data, health, focus, or context routines.'
            ;;
        support-library)
            printf 'Sourced or imported helper code used by runnable commands.'
            ;;
        compatibility-wrapper)
            printf 'Preserve command surface while implementation may move or consolidate.'
            ;;
        sibling-product-candidate)
            printf 'Candidate for Cyborg, observer, blog, or other product boundary extraction.'
            ;;
        *)
            printf 'General maintenance or convenience command retained in root dotfiles.'
            ;;
    esac
}

markdown_paths() {
    local path=""
    while IFS= read -r path; do
        path="${path#"$DOTFILES_DIR/"}"
        printf -- '- `%s`\n' "$path"
    done
}

markdown_table_cell() {
    local value="$1"
    value=$(printf '%s' "$value" | LC_ALL=C tr -cd '\11\12\15\40-\176' | tr -d '\140')
    value="${value//\\/\\\\}"
    value="${value//|/\\|}"
    printf '%s' "$value"
}

collect_metrics() {
    scripts_shell_total=$(count_find "$DOTFILES_DIR/scripts" -name '*.sh')
    scripts_shell_top=$(count_find "$DOTFILES_DIR/scripts" -maxdepth 1 -name '*.sh')
    scripts_py_top=$(count_find "$DOTFILES_DIR/scripts" -maxdepth 1 -name '*.py')
    lib_shell=$(count_find "$DOTFILES_DIR/scripts/lib" -maxdepth 1 -name '*.sh')
    lib_py=$(count_find "$DOTFILES_DIR/scripts/lib" -maxdepth 1 -name '*.py')
    bin_entrypoints=$(find "$DOTFILES_DIR/bin" -maxdepth 1 -type f ! -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    dhp_wrappers=$(count_find "$DOTFILES_DIR/bin" -maxdepth 1 -name 'dhp-*.sh')
    aliases=$(grep -E '^alias ' "$DOTFILES_DIR/zsh/aliases.zsh" 2>/dev/null | wc -l | tr -d ' ')
    alias_functions=$(grep -E '^[[:alnum:]_:-]+\(\) \{' "$DOTFILES_DIR/zsh/aliases.zsh" 2>/dev/null | wc -l | tr -d ' ')
    tests_shell=$(find "$DOTFILES_DIR/tests" -type f -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
    if [ -d "$DOTFILES_DIR/logs" ]; then
        logs_files=$(find "$DOTFILES_DIR/logs" -type f 2>/dev/null | wc -l | tr -d ' ')
    else
        logs_files=0
    fi
    source_loc=$(code_loc_scripts_bin)
    coach_loc=$(loc_for_files \
        "scripts/lib/coach_prompts.sh" \
        "scripts/lib/coach_metrics.sh" \
        "scripts/lib/coach_chat.sh" \
        "scripts/lib/coach_scoring.sh")
    coach_prompts_loc=$(line_count "scripts/lib/coach_prompts.sh")
    coach_metrics_loc=$(line_count "scripts/lib/coach_metrics.sh")
    coach_chat_loc=$(line_count "scripts/lib/coach_chat.sh")
    coach_scoring_loc=$(line_count "scripts/lib/coach_scoring.sh")
    product_loc=$(loc_for_files \
        "scripts/cyborg_agent.py" \
        "scripts/observer.py" \
        "scripts/cyborg_build.py" \
        "scripts/cyborg_docs_sync.py")
}

collect_alias_classes() {
    alias_daily=0
    alias_compat=0
    alias_convenience=0
    alias_risky=0

    local line=""
    local name=""
    local class=""

    while IFS= read -r line; do
        name=$(alias_name_from_line "$line")
        class=$(alias_class "$name")
        case "$class" in
            daily-core) alias_daily=$((alias_daily + 1)) ;;
            compatibility) alias_compat=$((alias_compat + 1)) ;;
            risky) alias_risky=$((alias_risky + 1)) ;;
            *) alias_convenience=$((alias_convenience + 1)) ;;
        esac
    done < <(grep -E '^alias ' "$DOTFILES_DIR/zsh/aliases.zsh" 2>/dev/null || true)
}

collect_script_classes() {
    script_daily=0
    script_support_library=0
    script_compat=0
    script_sibling=0
    script_support_utility=0

    local path=""
    local rel_path=""
    local class=""

    while IFS= read -r path; do
        rel_path="${path#"$DOTFILES_DIR/"}"
        class=$(script_class "$rel_path")
        case "$class" in
            daily-core) script_daily=$((script_daily + 1)) ;;
            support-library) script_support_library=$((script_support_library + 1)) ;;
            compatibility-wrapper) script_compat=$((script_compat + 1)) ;;
            sibling-product-candidate) script_sibling=$((script_sibling + 1)) ;;
            *) script_support_utility=$((script_support_utility + 1)) ;;
        esac
    done < <(script_inventory_paths)
}

collect_dispatcher_registry_metrics() {
    dispatcher_registry_file="$DOTFILES_DIR/config/dhp-dispatchers.tsv"
    dispatcher_registry_entries=0
    dispatcher_registry_backed=0
    dispatcher_registry_custom=0
    dispatcher_prompt_files=$(count_find "$DOTFILES_DIR/bin/prompts" -maxdepth 1 -name '*.md')
    dispatcher_tiny_shims=0

    if [ -f "$dispatcher_registry_file" ]; then
        dispatcher_registry_entries=$(awk -F '\t' 'NF && $1 !~ /^#/ { count++ } END { print count+0 }' "$dispatcher_registry_file")
        dispatcher_registry_backed=$(awk -F '\t' 'NF && $1 !~ /^#/ && $3 == "registry" { count++ } END { print count+0 }' "$dispatcher_registry_file")
        dispatcher_registry_custom=$(awk -F '\t' 'NF && $1 !~ /^#/ && $3 != "registry" { count++ } END { print count+0 }' "$dispatcher_registry_file")

        local shim_script=""
        local shim=""
        while IFS=$'\t' read -r _id shim_script _mode _rest; do
            [ "${_id:-}" ] || continue
            [[ "$_id" == \#* ]] && continue
            [ "${_mode:-}" = "registry" ] || continue
            shim="$DOTFILES_DIR/bin/$shim_script"
            if [ -f "$shim" ] && grep -q 'dhp_dispatch_from_script' "$shim" 2>/dev/null; then
                dispatcher_tiny_shims=$((dispatcher_tiny_shims + 1))
            fi
        done < "$dispatcher_registry_file"
    fi
}

print_summary() {
    collect_metrics
    collect_alias_classes
    collect_script_classes
    collect_dispatcher_registry_metrics

    cat <<EOF
Dotfiles Inventory Summary

- source LOC under scripts/ + bin/: $source_loc
- shell files under scripts/: $scripts_shell_total
- top-level scripts/*.sh: $scripts_shell_top
- top-level scripts/*.py: $scripts_py_top
- scripts/lib/*.sh: $lib_shell
- scripts/lib/*.py: $lib_py
- bin entrypoints: $bin_entrypoints
- dhp wrapper files: $dhp_wrappers
- aliases: $aliases
- shell functions in aliases file: $alias_functions
- alias classes: daily=$alias_daily compatibility=$alias_compat convenience=$alias_convenience risky=$alias_risky
- script classes: daily=$script_daily support_library=$script_support_library compatibility=$script_compat sibling_candidate=$script_sibling support_utility=$script_support_utility
- dispatcher registry: entries=$dispatcher_registry_entries registry_backed=$dispatcher_registry_backed custom=$dispatcher_registry_custom prompt_files=$dispatcher_prompt_files tiny_shims=$dispatcher_tiny_shims
- coach core LOC: $coach_loc
- product implementation LOC: $product_loc
- shell tests: $tests_shell
- repo-local log files: $logs_files
EOF
}

write_baseline_metrics() {
    local output_dir="$1"
    local baseline_file="$output_dir/baseline-metrics.md"

    if [ -f "$baseline_file" ] \
        && grep -q "Frozen Phase 0 Baseline" "$baseline_file" \
        && [ "${INVENTORY_FORCE_FREEZE:-0}" != "1" ]; then
        echo "baseline-metrics.md is frozen; set INVENTORY_FORCE_FREEZE=1 to override" >&2
        return 0
    fi

    collect_metrics
    collect_alias_classes

    cat > "$baseline_file" <<EOF
# Frozen Phase 0 Baseline

Generated: May 18, 2026

Do not refresh these values after Phase 0 is accepted. Later phases compare against this file and should record before/after movement separately.

## Source Shape

| Metric | Value |
| --- | ---: |
| Source LOC under \`scripts/\` + \`bin/\` | $source_loc |
| Shell files under \`scripts/\` | $scripts_shell_total |
| Top-level \`scripts/*.sh\` | $scripts_shell_top |
| Top-level \`scripts/*.py\` | $scripts_py_top |
| \`scripts/lib/*.sh\` | $lib_shell |
| \`scripts/lib/*.py\` | $lib_py |
| \`bin/\` non-markdown entrypoints | $bin_entrypoints |
| \`bin/dhp-*.sh\` dispatcher wrappers | $dhp_wrappers |
| Shell test files | $tests_shell |
| Repo-local \`logs/\` files | $logs_files |

## Alias Shape

| Metric | Value |
| --- | ---: |
| Aliases in \`zsh/aliases.zsh\` | $aliases |
| Shell functions in \`zsh/aliases.zsh\` | $alias_functions |
| Daily-core aliases | $alias_daily |
| Compatibility aliases | $alias_compat |
| Convenience aliases | $alias_convenience |
| Risky/surprising aliases | $alias_risky |

## Coach Baseline

| File | LOC |
| --- | ---: |
| \`scripts/lib/coach_prompts.sh\` | $coach_prompts_loc |
| \`scripts/lib/coach_metrics.sh\` | $coach_metrics_loc |
| \`scripts/lib/coach_chat.sh\` | $coach_chat_loc |
| \`scripts/lib/coach_scoring.sh\` | $coach_scoring_loc |
| Total | $coach_loc |

## Product Implementation Baseline

| File | LOC |
| --- | ---: |
| \`scripts/cyborg_agent.py\` | $(line_count "scripts/cyborg_agent.py") |
| \`scripts/observer.py\` | $(line_count "scripts/observer.py") |
| \`scripts/cyborg_build.py\` | $(line_count "scripts/cyborg_build.py") |
| \`scripts/cyborg_docs_sync.py\` | $(line_count "scripts/cyborg_docs_sync.py") |
| Total | $product_loc |

## Numeric Exit Gates

- Phase 3: reduce hand-maintained dispatcher wrappers from $dhp_wrappers to one registry-driven entrypoint plus registry data, prompt files, and generated/tiny compatibility shims.
- Phase 4: reduce \`coach_prompts.sh\` from $coach_prompts_loc LOC to 300 LOC or less; keep \`coach_metrics.sh\` stable or smaller than $coach_metrics_loc LOC unless an exception is recorded.
- Phase 8: reduce non-wrapper product implementation LOC under root dotfiles from $product_loc to approximately 0 after Observer and Cyborg extraction.
EOF
}

write_script_inventory() {
    local output_dir="$1"
    collect_metrics
    collect_script_classes
    collect_dispatcher_registry_metrics

    {
        cat <<EOF
# Script Inventory

Generated: May 18, 2026

## Summary

- Shell files under \`scripts/\`: $scripts_shell_total
- Top-level \`scripts/*.sh\`: $scripts_shell_top
- Top-level \`scripts/*.py\`: $scripts_py_top
- Sourced shell libraries under \`scripts/lib/\`: $lib_shell
- Python modules under \`scripts/lib/\`: $lib_py
- \`bin/\` non-markdown entrypoints: $bin_entrypoints

## Classification Summary

- Daily-core scripts: $script_daily
- Support libraries: $script_support_library
- Compatibility wrappers: $script_compat
- Sibling-product candidates: $script_sibling
- Support utilities: $script_support_utility

## Dispatcher Registry

- Registry file: \`config/dhp-dispatchers.tsv\`
- Registry entries: $dispatcher_registry_entries
- Registry-backed swarm dispatchers: $dispatcher_registry_backed
- Custom/specialized dispatcher entries: $dispatcher_registry_custom
- Prompt files under \`bin/prompts/\`: $dispatcher_prompt_files
- Tiny registry shims under \`bin/\`: $dispatcher_tiny_shims

## Class Definitions

- **daily-core**: $(script_note "daily-core")
- **support-library**: $(script_note "support-library")
- **compatibility-wrapper**: $(script_note "compatibility-wrapper")
- **sibling-product-candidate**: $(script_note "sibling-product-candidate")
- **support-utility**: $(script_note "support-utility")

Daily-core includes commands that directly or indirectly support the daily loop. Phase 8 extraction should preserve the narrower daily command surface from the roadmap even when broader helper commands are classified here.

## Script Classification

| Path | Class |
| --- | --- |
EOF
        local path=""
        local rel_path=""
        local class=""
        while IFS= read -r path; do
            rel_path="${path#"$DOTFILES_DIR/"}"
            class=$(script_class "$rel_path")
            printf '| `%s` | %s |\n' "$rel_path" "$class"
        done < <(script_inventory_paths)

        cat <<EOF

## Bin Entrypoints

EOF
        find "$DOTFILES_DIR/bin" -maxdepth 1 -type f ! -name '*.md' -print | sort | markdown_paths

        cat <<EOF

## Dispatcher Wrappers

- \`bin/dhp-*.sh\` files: $dhp_wrappers

EOF
        find "$DOTFILES_DIR/bin" -maxdepth 1 -type f -name 'dhp-*.sh' -print | sort | markdown_paths

        cat <<'EOF'

## Top-Level Shell Scripts

EOF
        find "$DOTFILES_DIR/scripts" -maxdepth 1 -type f -name '*.sh' -print | sort | markdown_paths

        cat <<'EOF'

## Sourced Shell Libraries

EOF
        find "$DOTFILES_DIR/scripts/lib" -maxdepth 1 -type f -name '*.sh' -print | sort | markdown_paths
    } > "$output_dir/script-inventory.md"
}

write_alias_inventory() {
    local output_dir="$1"
    collect_metrics
    collect_alias_classes

    {
        cat <<EOF
# Alias Inventory

Generated: May 18, 2026

## Summary

- Aliases: $aliases
- Shell functions: $alias_functions
- Daily-core aliases: $alias_daily
- Compatibility aliases: $alias_compat
- Convenience aliases: $alias_convenience
- Risky/surprising aliases: $alias_risky

## Aliases

| Class | Name | Definition |
| --- | --- | --- |
EOF

        local line=""
        local name=""
        local class=""
        local safe_line=""
        while IFS= read -r line; do
            name=$(alias_name_from_line "$line")
            class=$(alias_class "$name")
            safe_line=$(markdown_table_cell "$line")
            printf '| %s | `%s` | `%s` |\n' "$class" "$name" "$safe_line"
        done < <(grep -E '^alias ' "$DOTFILES_DIR/zsh/aliases.zsh" 2>/dev/null || true)

        cat <<'EOF'

## Shell Functions

EOF
        grep -E '^[[:alnum:]_:-]+\(\) \{' "$DOTFILES_DIR/zsh/aliases.zsh" 2>/dev/null | sed 's/().*/`/; s/^/- `/' || true
    } > "$output_dir/alias-inventory.md"
}

write_test_coverage_map() {
    local output_dir="$1"

    {
        cat <<'EOF'
# Test Coverage Map

Generated: May 18, 2026

## Daily Loop Coverage

- `tests/test_startday_coach.sh`
- `tests/test_status.sh`
- `tests/test_goodevening_coach.sh`
- `tests/test_coach_ops.sh`
- `tests/test_coach_prompts.sh`
- `tests/test_coach_metric_branches.sh`

## Compatibility Wrapper Degradation Coverage

- `tests/test_optional_product_degradation.sh`

## Inventory Coverage

- `tests/test_inventory.sh`

## All Shell Test Files

EOF
        find "$DOTFILES_DIR/tests" -type f -name '*.sh' -print | sort | markdown_paths
    } > "$output_dir/test-coverage-map.md"
}

write_external_dependencies() {
    local output_dir="$1"

    {
        cat <<'EOF'
# External Dependencies

Generated: May 18, 2026

## Credential-Like Configuration Keys

These keys were detected from `.env.example` and should stay out of generated logs.

EOF
        grep -E '^[A-Z0-9_]*(KEY|TOKEN|SECRET|PASSWORD)[A-Z0-9_]*=' "$DOTFILES_DIR/.env.example" 2>/dev/null | sed 's/=.*//' | sort -u | sed 's/^/- `/' | sed 's/$/`/' || true

        cat <<'EOF'

## Configuration Identifiers Not Flagged As Secrets

Client IDs and usernames may also appear in `.env.example`. They identify configured integrations, but this inventory keeps them out of the credential-like list unless the key name contains `KEY`, `TOKEN`, `SECRET`, or `PASSWORD`.

## Optional External Services

- OpenRouter for AI dispatchers and coach framing.
- GitHub for repo activity summaries.
- Fitbit for wearable health context.
- Google Drive for focus-related document evidence.
- Google Calendar for schedule context.
- Obsidian observer as an optional product boundary candidate.
- Cyborg/blog automation as an optional product boundary candidate.

## Phase 0 Note

This file records integration surface only. It does not validate credentials or call external services.
EOF
    } > "$output_dir/external-dependencies.md"
}

generate_docs() {
    local output_dir="${1:-$DOTFILES_DIR/docs/generated}"
    local validated_output=""

    mkdir -p "$output_dir"
    validated_output=$(validate_path "$output_dir") || exit "$EXIT_INVALID_ARGS"

    write_baseline_metrics "$validated_output"
    write_script_inventory "$validated_output"
    write_alias_inventory "$validated_output"
    write_test_coverage_map "$validated_output"
    write_external_dependencies "$validated_output"

    echo "Generated inventory docs in $validated_output"
}

main() {
    local command="${1:-}"
    case "$command" in
        summary)
            print_summary
            ;;
        generate)
            shift
            generate_docs "${1:-}"
            ;;
        -h|--help|help|"")
            usage
            ;;
        *)
            echo "Error: unknown command: $command" >&2
            usage >&2
            exit "$EXIT_INVALID_ARGS"
            ;;
    esac
}

main "$@"
