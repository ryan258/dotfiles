#!/bin/bash
# start_project.sh - Creates a standard project directory structure
set -euo pipefail

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

# If the user just hits enter, exit gracefully.
if [ -z "$project_name" ]; then
    echo "No project name given. Exiting."
    exit 1
fi

echo "Creating project: $project_name"
mkdir -p "$project_name"/{src,docs,assets}
touch "$project_name"/README.md

# Optional: Add the project title to the README file
echo "# $project_name" > "$project_name"/README.md

PROJECT_DIR=$(cd "$project_name" && pwd)

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
