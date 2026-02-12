#!/usr/bin/env bash
# scripts/lib/blog_gen.sh
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_BLOG_GEN_LOADED:-}" ]]; then
    return 0
fi
readonly _BLOG_GEN_LOADED=true

generate() {
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

refine() {
    local file_path="${2:-}"

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

draft_from_archetype() {
    local type="$1"
    local slug="$2"
    shift 2

    local title=""
    local open_editor=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --title)
                if [ -z "${2:-}" ] || [[ "${2:-}" == --* ]]; then
                    echo "Error: --title requires a value." >&2
                    return 1
                fi
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
                if [ -z "${2:-}" ] || [[ "${2:-}" == --* ]]; then
                    echo "Error: --title requires a value." >&2
                    return 1
                fi
                title="$2"
                shift 2
                ;;
            --topic)
                if [ -z "${2:-}" ] || [[ "${2:-}" == --* ]]; then
                    echo "Error: --topic requires a value." >&2
                    return 1
                fi
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
