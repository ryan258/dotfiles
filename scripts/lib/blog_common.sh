#!/bin/bash
# scripts/lib/blog_common.sh

# Cleanup
cleanup() {
    :
}
trap cleanup EXIT

# Section mapping helper: returns "content_subdir|archetype|default_subsection"
known_section_defaults() {
    local key="$1"
    case "$key" in
        guide|guides) echo "guides|guide.md|general" ;;
        blog|blogs) echo "blog|blog.md|general" ;;
        prompt|prompts) echo "prompts|prompt-card.md|general" ;;
        prompt-card) echo "prompts|prompt-card.md|general" ;;
        shortcut|shortcuts) echo "shortcuts|shortcut-spotlight.md|general" ;;
        shortcut-spotlight) echo "shortcuts|shortcut-spotlight.md|general" ;;
        system-instruction) echo "shortcuts/system-instructions|system-instruction.md|general" ;;
        *) return 1 ;;
    esac
}

list_known_sections() {
    echo "guide guides blog blogs prompt prompts prompt-card shortcut shortcuts shortcut-spotlight system-instruction"
}

DEFAULT_SECTION_EXEMPLARS=$(cat <<'EOF'
guides/ai-frameworks|content/guides/ai-frameworks/advanced-prompting.md
guides/brain-fog|content/guides/brain-fog/daily-briefing.md
guides/keyboard-efficiency|content/guides/keyboard-efficiency/core-5-shortcuts.md
guides/productivity-systems|content/guides/productivity-systems/prompt-versioning.md
blog|content/blog/automation-and-disability.md
prompts|content/prompts/bluf-decision-prompt.md
shortcuts/automations|content/shortcuts/automations/ai-summary-spotlight.md
shortcuts/keyboard-shortcuts|content/shortcuts/keyboard-shortcuts/core-5-spotlight.md
shortcuts/system-instructions|content/shortcuts/system-instructions/brain-fog-assistant-persona.md
EOF
)

SECTION_EXEMPLARS="${BLOG_SECTION_EXEMPLARS:-$DEFAULT_SECTION_EXEMPLARS}"

find_exemplar_for_section() {
    local section_path="$1"
    local best_match=""
    local best_file=""
    while IFS='|' read -r prefix relpath; do
        [ -z "$prefix" ] && continue
        if [[ "$section_path" == "$prefix"* ]]; then
            # Prefer longest prefix
            if [ "${#prefix}" -gt "${#best_match}" ]; then
                best_match="$prefix"
                best_file="$relpath"
            fi
        fi
    done <<< "$SECTION_EXEMPLARS"
    if [ -n "$best_file" ]; then
        echo "$best_file"
        return 0
    fi
    return 1
}

get_section_config_field() {
    local key="$1"
    local field="$2"
    local config
    config=$(known_section_defaults "$key") || { echo ""; return 1; }
    local IFS='|'
    read -r path archetype subsection <<< "$config"
    case "$field" in
        path) echo "$path" ;;
        archetype) echo "$archetype" ;;
        subsection) echo "$subsection" ;;
    esac
}

normalize_slug() {
    local input="$1"
    input="${input// /-}"
    input="${input#./}"
    input="${input%/}"
    input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    echo "$input"
}
