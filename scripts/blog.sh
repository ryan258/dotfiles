#!/bin/bash
# blog.sh - Tools for managing the blog content workflow.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATE_UTILS="$SCRIPT_DIR/lib/date_utils.sh"
if [ -f "$DATE_UTILS" ]; then
    # shellcheck disable=SC1090
    source "$DATE_UTILS"
else
    echo "Error: date utilities not found at $DATE_UTILS" >&2
    exit 1
fi

SYSTEM_LOG_FILE="$HOME/.config/dotfiles-data/system.log"

# Source shared utilities
if [ -f "$HOME/dotfiles/bin/dhp-utils.sh" ]; then
    # shellcheck disable=SC1090
    source "$HOME/dotfiles/bin/dhp-utils.sh"
else
    echo "Error: Shared utility library dhp-utils.sh not found." >&2
    exit 1
fi

# Allow per-user overrides via .env without leaking secrets broadly.
if [ -f "$HOME/dotfiles/.env" ]; then
    # shellcheck disable=SC1090
    source "$HOME/dotfiles/.env"
fi

# Check that BLOG_DIR is configured
BLOG_DIR="${BLOG_DIR:-}"
if [ -z "$BLOG_DIR" ]; then
    echo "Blog workflows are disabled. Set BLOG_DIR in dotfiles/.env to use blog.sh."
    exit 1
fi

# Determine directory paths
DRAFTS_DIR="${BLOG_DRAFTS_DIR_OVERRIDE:-${CONTENT_OUTPUT_DIR:-$BLOG_DIR/drafts}}"
POSTS_DIR="${BLOG_POSTS_DIR_OVERRIDE:-$BLOG_DIR/content/posts}"

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

# Create directories if they don't exist (mkdir -p is safe to run multiple times)
mkdir -p "$BLOG_DIR"
mkdir -p "$DRAFTS_DIR"
mkdir -p "$POSTS_DIR"

# Validate paths ONLY if they're under $HOME (security check for default configs)
# Skip validation for explicit external paths (e.g., /var/www/blog)
if [[ "$BLOG_DIR" == "$HOME"* ]]; then
    VALIDATED_BLOG_DIR=$(validate_path "$BLOG_DIR") || exit 1
    BLOG_DIR="$VALIDATED_BLOG_DIR"
fi

if [[ "$DRAFTS_DIR" == "$HOME"* ]]; then
    VALIDATED_DRAFTS_DIR=$(validate_path "$DRAFTS_DIR") || exit 1
    DRAFTS_DIR="$VALIDATED_DRAFTS_DIR"
fi

if [[ "$POSTS_DIR" == "$HOME"* ]]; then
    VALIDATED_POSTS_DIR=$(validate_path "$POSTS_DIR") || exit 1
    POSTS_DIR="$VALIDATED_POSTS_DIR"
fi

# Final check that posts directory exists (should always pass after mkdir -p)
if [ ! -d "$POSTS_DIR" ]; then
    echo "Error: Failed to create or access blog directory at $POSTS_DIR"
    exit 1
fi

# --- Subcommand: status ---
function status() {
    echo "📝 BLOG STATUS (ryanleej.com):"

    TOTAL_POSTS=$(find "$POSTS_DIR" -name "*.md" | wc -l | tr -d ' ')
    STUB_FILES=$(grep -l -i "content stub" "$POSTS_DIR"/*.md 2>/dev/null || true)
    if [ -n "$STUB_FILES" ]; then
        STUB_COUNT=$(printf "%s\n" "$STUB_FILES" | grep -c . || true)
    else
        STUB_COUNT=0
    fi

    echo "  • Total posts: $TOTAL_POSTS"
    echo "  • Posts needing content: $STUB_COUNT"

    if [ -d "$DRAFTS_DIR" ]; then
        draft_count=0
        drafts_list=""
        while IFS= read -r draft; do
            drafts_list="${drafts_list}${draft}"$'\n'
            draft_count=$((draft_count + 1))
        done < <(find "$DRAFTS_DIR" -type f -name "*.md" 2>/dev/null | sort)

        if [ "$draft_count" -gt 0 ]; then
            echo "  • Drafts awaiting review ($draft_count):"
            while IFS= read -r draft; do
                [ -z "$draft" ] && continue
                rel=${draft#"$DRAFTS_DIR"/}
                echo "    - $rel"
            done <<< "$drafts_list"
        else
            echo "  • Drafts awaiting review: 0"
        fi
    fi

    if [ -d "$BLOG_DIR/.git" ]; then
        LAST_UPDATE=$(cd "$BLOG_DIR" && git log -1 --format="%ad" --date=short)
        echo "  • Last update: $LAST_UPDATE"

        # Calculate days since last update
        LAST_UPDATE_EPOCH=$(cd "$BLOG_DIR" && git log -1 --format="%ct")
        DAYS_SINCE=$(( ( $(date +%s) - LAST_UPDATE_EPOCH ) / 86400 ))

        if [ "$DAYS_SINCE" -gt 14 ]; then
            echo "  ⏰ It's been $DAYS_SINCE days since your last update"
        fi
    fi

    echo "  • Site: https://ryanleej.com"
}

# --- Subcommand: stubs ---
function stubs() {
    echo "📄 CONTENT STUBS:"

    STUB_FILES=$(grep -l -i "content stub" "$POSTS_DIR"/*.md 2>/dev/null)

    if [ -n "$STUB_FILES" ]; then
        SEVEN_DAYS_AGO=$(date_shift_days -7 "%s")
        THIRTY_DAYS_AGO=$(date_shift_days -30 "%s")

        echo "$STUB_FILES" | while read -r file; do
            filename=$(basename "$file")

            # Get last modified timestamp
            if [ -d "$BLOG_DIR/.git" ]; then
                # Try to get last git commit date for this file
                last_commit=$(cd "$BLOG_DIR" && git log -1 --format="%ct" -- "$file" 2>/dev/null)
                if [ -n "$last_commit" ]; then
                    mod_time=$last_commit
                else
                    # Fall back to file system modification time
                    mod_time=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null)
                fi
            else
                mod_time=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null)
            fi

            # Calculate age and add warning if old
            if [ "$mod_time" -lt "$THIRTY_DAYS_AGO" ]; then
                days_old=$(( ( $(date +%s) - mod_time ) / 86400 ))
                echo "  ⚠️  $filename (stale: ${days_old} days old)"
            elif [ "$mod_time" -lt "$SEVEN_DAYS_AGO" ]; then
                days_old=$(( ( $(date +%s) - mod_time ) / 86400 ))
                echo "  ⏰ $filename (${days_old} days old)"
            else
                echo "  • $filename"
            fi
        done
    else
        echo "  (No content stubs found)"
    fi
}

# --- Subcommand: random ---
function random_stub() {
    echo "🎲 Opening a random stub..."
    
    mapfile -t STUB_FILES < <(grep -l -i "content stub" "$POSTS_DIR"/*.md 2>/dev/null)
    
    if [ ${#STUB_FILES[@]} -eq 0 ]; then
        echo "  (No content stubs to choose from)"
        return
    fi
    
    RANDOM_INDEX=$(( RANDOM % ${#STUB_FILES[@]} ))
    RANDOM_FILE=${STUB_FILES[$RANDOM_INDEX]}
    
    echo "  Opening: $(basename "$RANDOM_FILE")"
    
    if command -v code &> /dev/null; then
        code "$RANDOM_FILE"
    else
        open "$RANDOM_FILE"
    fi
}

# --- Subcommand: recent ---
function recent() {
    echo "⏳ RECENTLY MODIFIED POSTS:"

    recent_files=()
    while IFS= read -r -d '' file; do
        recent_files+=("$file")
    done < <(find "$POSTS_DIR" -name "*.md" -mtime -14 -print0 2>/dev/null)

    if [ ${#recent_files[@]} -eq 0 ]; then
        echo "  (No posts updated in the last 14 days)"
        return
    fi

    printf '%s\0' "${recent_files[@]}" | xargs -0 ls -t | head -n 5 | while read -r file; do
        if [ -f "$file" ]; then
            echo "  • $(basename "$file")"
        fi
    done
}

function ideas() {
    echo "💡 Searching for blog ideas in journal..."
    /Users/ryanjohnson/dotfiles/scripts/journal.sh search "blog idea"
}

function generate() {
    shift # remove subcommand label
    local persona=""
    local input_file=""
    local use_context=""
    local input_text=""
    local archetype=""
    local section=""

    while [ $# -gt 0 ]; do
        case "$1" in
            -p|--persona)
                if [ -z "${2:-}" ]; then
                    echo "Error: --persona requires a name" >&2
                    return 1
                fi
                persona="$2"
                shift 2
                ;;
            -f|--file|--input-file)
                if [ -z "${2:-}" ]; then
                    echo "Error: --file requires a path" >&2
                    return 1
                fi
                input_file="$2"
                shift 2
                ;;
            -c|--context)
                use_context="--context"
                shift
                ;;
            -C|--full-context)
                use_context="--full-context"
                shift
                ;;
            -a|--archetype|--type)
                if [ -z "${2:-}" ]; then
                    echo "Error: --archetype requires a name (guide, blog, prompt-card, etc.)." >&2
                    return 1
                fi
                archetype="$2"
                shift 2
                ;;
            -s|--section)
                if [ -z "${2:-}" ]; then
                    echo "Error: --section requires a name (e.g., brain-fog, shortcuts)." >&2
                    return 1
                fi
                section="$2"
                shift 2
                ;;
            --help|-h)
                cat <<'USAGE'
Usage: blog generate [OPTIONS] "topic or draft text"
       blog generate [OPTIONS] --file path/to/input.md

Options:
  -p, --persona NAME  Apply a persona playbook from docs/personas.md
  -a, --archetype NAME Load a Hugo archetype template (guide, blog, prompt-card, etc.)
  -s, --section NAME   Target site section/subfolder (e.g., guides/brain-fog or guide:brain-fog)
  -f, --file PATH     Provide a file whose contents become the brief/input
  -c, --context       Inject minimal local context into the dispatcher
  -C, --full-context  Inject full local context (journal, todos, git, README)
  --help              Show this message

Provide the content brief directly as arguments, pipe it via stdin, or use --file.
USAGE
                return 0
                ;;
            *)
                input_text+="${input_text:+ }$1"
                shift
                ;;
        esac
    done

    # Pull input from file if provided
    if [ -n "$input_file" ]; then
        if [ ! -f "$input_file" ]; then
            echo "Error: Input file not found: $input_file" >&2
            return 1
        fi
        local file_content
        file_content=$(cat "$input_file")
        if [ -n "$input_text" ]; then
            input_text="$input_text

$file_content"
        else
            input_text="$file_content"
        fi
    fi

    # Allow stdin when no args were provided
    if [ -z "$input_text" ] && [ ! -t 0 ]; then
        input_text=$(cat)
    fi

    if [ -z "$input_text" ]; then
        echo "Error: Provide a topic, idea, or draft text (arguments, --file, or stdin)." >&2
        return 1
    fi

    local brief_preview
    brief_preview=$(echo "$input_text" | head -n 1 | cut -c1-80)

    local section_key=""
    local section_path_override=""

    if [ -n "$section" ]; then
        local normalized_section="${section#/}"
        normalized_section="${normalized_section%/}"
        if [[ "$section" == *:* ]]; then
            local base="${section%%:*}"
            local child="${section#*:}"
            child="${child#/}"
            child="${child%/}"
            section_key="$base"
            local base_path
            base_path=$(get_section_config_field "$base" "path")
            if [ -z "$base_path" ]; then
                echo "Error: Unknown section base '$base'. Expected one of: $(list_known_sections)" >&2
                return 1
            fi
            section_path_override="$base_path"
            if [ -n "$child" ]; then
                section_path_override="$section_path_override/$child"
            fi
        elif [[ "$section" == */* ]]; then
            section_path_override="$normalized_section"
            local first_segment="${normalized_section%%/*}"
            if known_section_defaults "$first_segment" >/dev/null 2>&1; then
                section_key="$first_segment"
            fi
        elif known_section_defaults "$section" >/dev/null 2>&1; then
            section_key="$section"
            section_path_override=$(get_section_config_field "$section" "path")
        else
            echo "Error: Unknown section '$section'. Use keys ($(list_known_sections)) or paths like guides/brain-fog or guide:brain-fog." >&2
            return 1
        fi
    fi

    if [ -z "$section_key" ] && [ -n "$archetype" ] && known_section_defaults "$archetype" >/dev/null 2>&1; then
        section_key="$archetype"
    fi

    if [ -z "$archetype" ] && [ -n "$section_key" ]; then
        local default_arch
        default_arch=$(get_section_config_field "$section_key" "archetype")
        [ -n "$default_arch" ] && archetype="$default_arch"
    fi

    if [ -z "$section_path_override" ] && [ -n "$section_key" ]; then
        section_path_override=$(get_section_config_field "$section_key" "path")
    fi

    local section_path="${section_path_override:-posts}"
    section_path="${section_path#/}"
    section_path="${section_path%/}"
    [ -z "$section_path" ] && section_path="posts"
    if [[ "$section_path" == *".."* ]]; then
        echo "Error: Section path cannot include '..' segments." >&2
        return 1
    fi

    local target_dir="$BLOG_DIR/content/$section_path"
    mkdir -p "$target_dir"
    echo "Target section: $section_path"
    echo "Saving drafts to: $target_dir"
    local exemplar_snippet=""
    local exemplar_rel=""
    if exemplar_rel=$(find_exemplar_for_section "$section_path"); then
        local exemplar_file="$BLOG_DIR/$exemplar_rel"
        if [ -f "$exemplar_file" ]; then
            exemplar_snippet=$(cat "$exemplar_file")
            echo "Using exemplar: $exemplar_rel"
        else
            echo "Warning: Exemplar file not found at $exemplar_rel" >&2
        fi
    fi

    if [ -n "$archetype" ]; then
        local archetype_dir="${BLOG_ARCHETYPES_DIR:-${BLOG_DIR:-}/archetypes}"
        local type_file=""
        if [ -n "$archetype_dir" ] && [ -d "$archetype_dir" ]; then
            if [ -f "$archetype_dir/$archetype.md" ]; then
                type_file="$archetype_dir/$archetype.md"
            elif [ -f "$archetype_dir/$archetype" ]; then
                type_file="$archetype_dir/$archetype"
            fi
        fi
        if [ -z "$type_file" ]; then
            echo "Error: Archetype '$archetype' not found in $archetype_dir" >&2
            if [ -d "$archetype_dir" ]; then
                echo "Available archetypes:" >&2
                ls "$archetype_dir" >&2
            else
                echo "Set BLOG_ARCHETYPES_DIR or BLOG_DIR to point to your Hugo archetypes." >&2
            fi
            return 1
        fi
        local archetype_content
        archetype_content=$(cat "$type_file")
        input_text="HUGO ARCHETYPE TEMPLATE (${archetype}):\n${archetype_content}\n$( [ -n "$exemplar_snippet" ] && printf '\nEXEMPLAR (%s):\n%s\n' "$section_path" "$exemplar_snippet" )\n--- USER BRIEF ---\n${input_text}"
    elif [ -n "$exemplar_snippet" ]; then
        input_text="EXEMPLAR (${section_path}):\n${exemplar_snippet}\n\n--- USER BRIEF ---\n${input_text}"
    fi

    if [ -n "$persona" ]; then
        echo "AI Staff: Content Specialist is creating a draft as persona '$persona'..."
    else
        echo "AI Staff: Content Specialist is creating a draft..."
    fi
    [ -n "$brief_preview" ] && echo "Brief: $brief_preview"
    echo "---"

    if command -v dhp-content.sh &> /dev/null; then
        local cmd=(dhp-content.sh)
        [ -n "$persona" ] && cmd+=(--persona "$persona")
        [ -n "$use_context" ] && cmd+=("$use_context")
        cmd+=("$input_text")
        DHP_CONTENT_OUTPUT_DIR="$target_dir" "${cmd[@]}"
    else
        echo "Error: dhp-content.sh dispatcher not found"
        echo "Make sure bin/ is in your PATH"
        return 1
    fi

    echo ""
    echo "✅ Content generation complete"
    echo "Review and edit the generated output in: $target_dir"
}

function refine() {
    local file_path="$2"

    if [ -z "$file_path" ]; then
        echo "Usage: blog refine <file-path>"
        echo "Example: blog refine $POSTS_DIR/my-post.md"
        return 1
    fi

    # Handle relative paths
    if [ ! -f "$file_path" ]; then
        # Try adding POSTS_DIR prefix
        file_path="$POSTS_DIR/$file_path"
        if [ ! -f "$file_path" ]; then
            file_path="$POSTS_DIR/${file_path}.md"
        fi
    fi

    if [ ! -f "$file_path" ]; then
        echo "Error: File not found: $file_path"
        return 1
    fi

    echo "✨ Refining content: $(basename "$file_path")"
    echo "Reading from: $file_path"
    echo ""
    echo "AI Staff: Content Specialist is polishing your draft..."
    echo "---"

    # Read the file content and pipe to content dispatcher with refine instruction
    if command -v dhp-content.sh &> /dev/null; then
        {
            echo "Please refine and improve the following blog post content. Focus on:"
            echo "- Clarity and readability"
            echo "- SEO optimization"
            echo "- Engaging headlines and structure"
            echo "- Adding relevant examples if needed"
            echo ""
            echo "Original content:"
            echo "---"
            cat "$file_path"
        } | dhp-content.sh "refine blog post"
    else
        echo "Error: dhp-content.sh dispatcher not found"
        echo "Make sure bin/ is in your PATH"
        return 1
    fi

    echo ""
    echo "✅ Content refinement complete"
    echo "Review the suggestions above and update: $file_path"
}

normalize_slug() {
    local input="$1"
    input="${input// /-}"
    input="${input#./}"
    input="${input%/}"
    input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    echo "$input"
}

draft_from_archetype() {
    local type="$1"
    local slug="$2"
    shift 2

    local title=""
    local open_editor=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --title)
                title="$2"
                shift 2
                ;;
            --open)
                open_editor=true
                shift
                ;;
            *)
                echo "Unknown draft option: $1" >&2
                return 1
                ;;
        esac
    done

    local archetype=""
    local subdir=""
    local slug_path
    slug_path=$(normalize_slug "$slug")

    case "$type" in
        blog)
            archetype="blog.md"
            subdir="blog"
            ;;
        guide)
            archetype="guide.md"
            subdir="guides"
            if [[ "$slug_path" != */* ]]; then
                echo "Guide drafts must include the category subdirectory (e.g., brain-fog/my-guide)." >&2
                return 1
            fi
            ;;
        prompt|prompt-card)
            archetype="prompt-card.md"
            subdir="prompts"
            ;;
        shortcut-spotlight)
            archetype="shortcut-spotlight.md"
            subdir="shortcuts"
            ;;
        system-instruction)
            archetype="system-instruction.md"
            subdir="shortcuts/system-instructions"
            ;;
        *)
            archetype="default.md"
            ;;
    esac

    local target="$DRAFTS_DIR"
    if [ -n "$subdir" ]; then
        target="$target/$subdir"
    fi

    if [[ "$slug_path" != *.md ]]; then
        slug_path="${slug_path}.md"
    fi
    local draft_path="$target/$slug_path"
    local archetype_path="$BLOG_DIR/archetypes/$archetype"
    if [ ! -f "$archetype_path" ]; then
        archetype_path="$BLOG_DIR/archetypes/default.md"
    fi

    mkdir -p "$(dirname "$draft_path")"

    if [ -f "$draft_path" ]; then
        echo "Draft already exists: $draft_path" >&2
        echo "$draft_path"
        return 0
    fi

    cat "$archetype_path" > "$draft_path"

    if [ -n "$title" ]; then
        python3 <<PY || true
from pathlib import Path
path = Path("$draft_path")
lines = path.read_text().splitlines()
for idx, line in enumerate(lines):
    if line.strip().startswith("title"):
        indent, rest = line.split(":", 1)
        lines[idx] = f"{indent}: \"$title\""
        break
path.write_text("\n".join(lines) + "\n")
PY
    fi

    echo "Created draft at $draft_path" >&2

    if [ "$open_editor" = true ]; then
        "${EDITOR:-vim}" "$draft_path"
    fi

    echo "$draft_path"
}

draft_command() {
    shift # remove subcommand name
    local draft_type="${1:-}"
    local slug="${2:-}"
    shift 2 || true

    if [ -z "$draft_type" ] || [ -z "$slug" ]; then
        echo "Usage: blog draft <type> <slug> [--title \"Title\"] [--open]" >&2
        return 1
    fi

    draft_from_archetype "$draft_type" "$slug" "$@"
}

run_workflow() {
    local type="$1"
    local slug="$2"
    shift 2

    local title=""
    local topic=""
    local skip_ai=false
    local open_editor=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --title)
                title="$2"
                shift 2
                ;;
            --topic)
                topic="$2"
                shift 2
                ;;
            --no-ai)
                skip_ai=true
                shift
                ;;
            --open)
                open_editor=true
                shift
                ;;
            *)
                echo "Unknown workflow option: $1" >&2
                return 1
                ;;
        esac
    done

    if [ -z "$slug" ]; then
        echo "Usage: blog workflow <type> <slug> [--title \"Title\"] [--topic \"Topic\"] [--open] [--no-ai]" >&2
        return 1
    fi

    local draft_args=()
    if [ -n "$title" ]; then
        draft_args+=(--title "$title")
    fi
    local draft_path
    draft_path=$(draft_from_archetype "$type" "$slug" "${draft_args[@]}") || return 1
    title=${title:-$(basename "$draft_path" .md | tr '-' ' ' | sed 's/.*/\u&/')}
    topic=${topic:-$title}

    if [ "$skip_ai" = true ] || ! command -v dhp-content.sh >/dev/null 2>&1; then
        echo "Draft scaffolded at $draft_path."
        echo "AI generation skipped. Use 'dhp-content.sh' manually if desired."
        [ "$open_editor" = true ] && "${EDITOR:-vim}" "$draft_path"
        return 0
    fi

    echo "Generating AI-assisted outline..."
    local outline
    if ! outline=$(cat <<PROMPT | dhp-content.sh "outline for $title"
You are the editorial lead for the My MS & AI Journey site.
Create a structured outline for a $type post.

Title: $title
Topic: $topic
Audience: Readers managing MS-related brain fog who rely on accessible workflows.

Include clear section headings and 1-2 bullet notes per section.
PROMPT
); then
        echo "Warning: Unable to generate outline via dhp-content.sh" >&2
        return 1
    fi

    {
        echo ""
        echo "## AI Outline (generated $(date '+%Y-%m-%d %H:%M'))"
        echo ""
        echo "$outline"
        echo ""
    } >> "$draft_path"

    echo "Generating AI-assisted draft..."
    local draft_text
    if ! draft_text=$(cat <<PROMPT | dhp-content.sh "draft for $title"
You are the editorial lead for My MS & AI Journey.
Write the full $type content using the outline below.
Focus on clarity, accessibility, and concrete steps that help readers manage MS brain fog.

Title: $title
Topic: $topic

Outline:
$outline
PROMPT
); then
        echo "Warning: Unable to generate draft via dhp-content.sh" >&2
        return 1
    fi

    {
        echo "## AI Draft (generated $(date '+%Y-%m-%d %H:%M'))"
        echo ""
        echo "$draft_text"
        echo ""
    } >> "$draft_path"

    echo "Generating reviewer checklist..."
    local reviewer_notes
    if reviewer_notes=$(cat <<PROMPT | dhp-content.sh "review for $title"
You are the accessibility reviewer for My MS & AI Journey.
Review the following $type draft and provide 4-5 bullet recommendations covering clarity, accessibility, and MS-friendly tone.

$draft_text
PROMPT
); then
        {
            echo "## Reviewer Notes"
            echo ""
            echo "$reviewer_notes"
            echo ""
        } >> "$draft_path"
    fi

    echo "Workflow complete. Draft updated at $draft_path"

    if [ "$open_editor" = true ]; then
        "${EDITOR:-vim}" "$draft_path"
    fi
}

workflow_command() {
    shift
    local workflow_type="${1:-}"
    local slug="${2:-}"
    shift 2 || true

    if [ -z "$workflow_type" ] || [ -z "$slug" ]; then
        echo "Usage: blog workflow <type> <slug> [options]" >&2
        return 1
    fi

    run_workflow "$workflow_type" "$slug" "$@"
}

publish_site() {
    echo "Running blog validation..."
    if ! validate_site; then
        echo "Publish aborted: validation failed." >&2
        return 1
    fi

    if ! command -v hugo >/dev/null 2>&1; then
        echo "Error: hugo CLI not found. Install Hugo to build the site." >&2
        return 1
    fi

    echo ""
    echo "Building site with Hugo (hugo --gc --minify)..."
    if ! (cd "$BLOG_DIR" && hugo --gc --minify); then
        echo "Hugo build failed; see errors above." >&2
        return 1
    fi

    echo ""
    echo "Build complete. Output directory: $BLOG_DIR/public"
    echo ""
    echo "Git status for $BLOG_DIR:"
    git -C "$BLOG_DIR" status -sb || echo "  (Unable to read git status)"

    echo ""
    echo "Next steps:"
    echo "  1. Review the changes above."
    echo "  2. Commit in $BLOG_DIR (examples: git add . && git commit -m \"Publish\")"
    echo "  3. Push when ready (DigitalOcean will build on push)."
}

validate_site() {
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Error: python3 is required for blog validate." >&2
        return 1
    fi

    POSTS_DIR="$POSTS_DIR" DRAFTS_DIR="$DRAFTS_DIR" BLOG_DIR="$BLOG_DIR" python3 <<'PY'
import os
import re
import sys
from pathlib import Path

content_dir = Path(os.environ.get("POSTS_DIR", ""))
drafts_dir = Path(os.environ.get("DRAFTS_DIR", ""))
blog_dir_env = os.environ.get("BLOG_DIR")
blog_dir = Path(blog_dir_env) if blog_dir_env else None
content_root = (blog_dir / "content") if blog_dir else content_dir
if not content_root.exists():
    content_root = content_dir

targets = []
for base in (content_dir, drafts_dir):
    if base and base.exists():
        targets.extend(sorted(base.rglob("*.md")))

if not targets:
    print("No markdown files found under content/ or drafts/.")
    sys.exit(0)

key_pattern = lambda key: re.compile(rf"^\s*{re.escape(key)}\s*[:=]", re.MULTILINE)
value_pattern = lambda key: re.compile(rf"^\s*{re.escape(key)}\s*[:=]\s*['\"]?([^\"'\n#]+)", re.MULTILINE)

base_required = ["title", "datePublished", "last_updated", "draft"]
type_specific = {
    "guide": ["guide_category", "energy_required", "time_estimate"],
    "blog": ["tags"],
    "reference": ["tags"],
    "shortcut-spotlight": ["tags"],
}

issues = []
warnings = []

def parse_front_matter(text):
    lines = text.splitlines()
    if not lines:
        return "", text
    delimiter = lines[0].strip()
    if delimiter not in ("---", "+++"):
        return "", text
    body = []
    closing_index = None
    for idx, line in enumerate(lines[1:], start=1):
        if line.strip() == delimiter:
            closing_index = idx
            break
        body.append(line)
    if closing_index is None:
        return "", text
    remainder = "\n".join(lines[closing_index + 1 :])
    return "\n".join(body), remainder

def find_type(front_matter):
    match = re.search(r'^\s*type\s*[:=]\s*["\']?([A-Za-z0-9_-]+)', front_matter, re.MULTILINE)
    if match:
        return match.group(1).strip().lower()
    return ""

def has_key(front_matter, key):
    return bool(key_pattern(key).search(front_matter))

def extract_value(front_matter, key):
    match = value_pattern(key).search(front_matter)
    if match:
        return match.group(1).strip().strip("'").strip('"')
    return ""

markdown_link_pattern = re.compile(r"(?<!\!)\[([^\]]+)\]\(([^)]+)\)")
markdown_image_pattern = re.compile(r"!\[([^\]]*)\]\(([^)]+)\)")
html_img_pattern = re.compile(r"<img[^>]*>", re.IGNORECASE)

def check_accessibility(front_matter, body_text):
    problems = []

    for alt, src in markdown_image_pattern.findall(body_text):
        if not alt.strip():
            problems.append(f"image '{src}' is missing alt text")

    for tag in html_img_pattern.findall(body_text):
        if "alt=" not in tag.lower():
            problems.append("HTML <img> missing alt attribute")

    prev_level = None
    for match in re.finditer(r"^(#{2,6})\s", body_text, re.MULTILINE):
        level = len(match.group(1))
        if prev_level and level > prev_level + 1:
            problems.append(f"heading jumps from H{prev_level} to H{level}")
        prev_level = level

    return problems

def check_links(body_text):
    problems = []
    for text, url in markdown_link_pattern.findall(body_text):
        url = url.strip()
        if not url or url.startswith("http://") or url.startswith("https://") or url.startswith("mailto:") or url.startswith("#"):
            continue
        clean = url.split("#")[0].split("?")[0].strip()
        if not clean:
            continue
        if clean.startswith("//"):
            continue

        rel_target = clean.lstrip("/").rstrip("/")
        candidates = []
        for base in (content_root, drafts_dir):
            if not base:
                continue
            candidates.append(base / f"{rel_target}.md")
            candidates.append(base / rel_target / "index.md")
            candidates.append(base / rel_target / "_index.md")

        if not any(candidate.exists() for candidate in candidates):
            problems.append(f"link '{url}' does not match a local file")

    return problems

for path in targets:
    if blog_dir:
        try:
            rel_path = path.relative_to(blog_dir)
        except ValueError:
            rel_path = path
    else:
        rel_path = path

    parts = rel_path.parts
    is_draft = bool(parts and parts[0] == "drafts")
    if path.name == "_index.md":
        continue

    text = path.read_text(encoding="utf-8", errors="ignore")
    front_matter, body_text = parse_front_matter(text)
    target_list = warnings if is_draft else issues

    if not front_matter:
        target_list.append(f"{rel_path}: missing or invalid front matter delimiter")
        continue

    missing = [key for key in base_required if not has_key(front_matter, key)]
    content_type = find_type(front_matter)
    for extra_key in type_specific.get(content_type, []):
        if not has_key(front_matter, extra_key):
            missing.append(extra_key)

    if missing:
        target_list.append(f"{rel_path}: missing keys -> {', '.join(missing)}")

    if not is_draft and content_type == "guide":
        parts = rel_path.parts
        if "guides" in parts:
            idx = parts.index("guides")
            if len(parts) > idx + 1:
                category = parts[idx + 1]
                if not category.startswith("_"):
                    expected = category
                    guide_category = extract_value(front_matter, "guide_category")
                    if guide_category and guide_category.strip().lower() != expected.lower():
                        issues.append(f"{rel_path}: guide_category '{guide_category}' should match folder '{expected}'")

    if front_matter:
        acc_problems = check_accessibility(front_matter, body_text)
        for problem in acc_problems:
            target_list.append(f"{rel_path}: {problem}")

        link_problems = check_links(body_text)
        for problem in link_problems:
            target = warnings if is_draft else issues
            target.append(f"{rel_path}: {problem}")

if issues:
    print("❌ Blog validation failed:")
    for item in issues:
        print(f"  - {item}")
if warnings:
    label = "warnings (drafts)" if issues else "warnings"
    print(f"\n⚠️  {label}:")
    for item in warnings:
        print(f"  - {item}")

print(f"\nChecked {len(targets)} markdown files.")
if issues:
    sys.exit(1)

print("✅ Blog validation passed.")
PY
}

install_hooks() {
    if [ ! -d "$BLOG_DIR/.git" ]; then
        echo "Error: $BLOG_DIR is not a git repository."
        return 1
    fi

    local hook_file="$BLOG_DIR/.git/hooks/pre-commit"
    cat <<'HOOK' > "$hook_file"
#!/bin/sh
BLOG_DIR="__BLOG_DIR__"
DOTFILES_DIR="$HOME/dotfiles"
SCRIPT="$DOTFILES_DIR/scripts/blog.sh"

if [ ! -x "$SCRIPT" ]; then
  echo "blog.sh not found at $SCRIPT" >&2
  exit 1
fi

echo "Running blog validate..."
BLOG_DIR="$BLOG_DIR" "$SCRIPT" validate
HOOK
    if [ $? -ne 0 ]; then
        echo "Error: Unable to write to $hook_file (check permissions)." >&2
        return 1
    fi

    # Replace placeholder with actual blog dir path
    if ! sed -i '' "s|__BLOG_DIR__|$BLOG_DIR|g" "$hook_file" 2>/dev/null; then
        if ! perl -0pi -e "s|__BLOG_DIR__|$BLOG_DIR|g" "$hook_file" 2>/dev/null; then
            echo "Warning: Unable to finalize hook template. Please edit $hook_file manually." >&2
        fi
    fi

    chmod +x "$hook_file"
    echo "Installed pre-commit hook at $hook_file"
}
# --- Main Logic ---
case "$1" in
    status|stat|s)
        status
        ;;
    stubs|stub|ls-stubs)
        stubs
        ;;
    random|rand|R)
        random_stub
        ;;
    recent|rec)
        recent
        ;;
    ideas|idea|i)
        ideas
        ;;
    generate|gen|g)
        generate "$@"
        ;;
    refine|polish|r)
        refine "$@"
        ;;
    draft|d)
        draft_command "$@"
        ;;
    workflow|w)
        workflow_command "$@"
        ;;
    publish|p)
        publish_site
        ;;
    validate|check|v)
        validate_site
        ;;
    hooks|hook)
        if [ "${2:-}" = "install" ]; then
            install_hooks
        else
            echo "Usage: blog hooks install"
            exit 1
        fi
        ;;
    *)
        echo "Usage: blog {status|stubs|random|recent|ideas|generate|refine|draft|workflow|publish|validate|hooks install}"
        echo ""
        echo "AI-powered commands:"
        echo "  blog g / blog generate [options] \"topic\"  - Generate content (supports -p persona, -a archetype, -s section, -f file)"
        echo "  blog r / blog refine <file-path>          - Polish and improve existing content"
        echo "  blog d / blog draft <type> <slug>         - Scaffold a new draft from archetypes"
        echo "  blog w / blog workflow <type> <slug> [--title --topic]"
        echo "  blog p / blog publish                    - Validate, build, and summarize site status"
        ;;
esac
