#!/usr/bin/env bash
# start_project.sh - Creates a standard project directory structure
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/common.sh"
fi

is_sourced() {
    if [ -n "$ZSH_VERSION" ]; then
        case $ZSH_EVAL_CONTEXT in
            *:file) return 0 ;;
        esac
        return 1
    elif [ -n "$BASH_VERSION" ]; then
        [[ ${BASH_SOURCE[0]} != "$0" ]]
        return
    fi
    return 1
}

IFS= read -r -p "What is the name of your new project? " project_name
project_name=$(sanitize_input "$project_name")
project_name=${project_name//$'\n'/ }

# If the user just hits enter, exit gracefully.
if [ -z "$project_name" ]; then
    echo "No project name given. Exiting."
    exit 1
fi

if ! [[ "$project_name" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Error: Project name can only contain letters, numbers, '.', '_' and '-'." >&2
    exit 1
fi

echo "Creating project: $project_name"
project_path="$(pwd)/$project_name"
project_path=$(validate_path "$project_path") || exit 1

mkdir -p "$project_path"/{src,docs,assets}
touch "$project_path"/README.md

# Optional: Add the project title to the README file
echo "# $project_name" > "$project_path"/README.md

PROJECT_DIR=$(cd "$project_path" && pwd)

if is_sourced; then
    if ! builtin cd "$PROJECT_DIR"; then
        echo "Failed to change directory to $PROJECT_DIR"
        return 1
    fi
    echo "Project created and you are now inside the '$project_name' directory."
else
    echo "Project created at: $PROJECT_DIR"
    printf "Tip: run 'cd \"%s\"' or source this script to jump inside automatically.\n" "$PROJECT_DIR" >&2
fi

# ---
