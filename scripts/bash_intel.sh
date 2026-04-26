#!/usr/bin/env bash
set -euo pipefail

# bash_intel.sh - Shell intelligence wrapper for bash-language-server.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1090
source "$SCRIPT_DIR/lib/common.sh"

BASH_INTEL_CLIENT="${BASH_INTEL_CLIENT:-$SCRIPT_DIR/bash_intel_client.mjs}"

usage() {
    cat <<'EOF'
Usage: bash_intel.sh <command> [args]

Commands:
  check                         Show the configured language-server backend
  symbols <file>                List symbols in a shell file
  outline <file>                Alias for symbols
  workspace-symbols <query>     Search workspace symbols
  definition <symbol>           Find a symbol definition
  references <symbol>           Find symbol references

Environment:
  BASH_LANGUAGE_SERVER_BIN      Path to bash-language-server binary
  BASH_INTEL_CLIENT             Override LSP client executable for tests
  BASH_INTEL_TIMEOUT_MS         LSP request timeout in milliseconds
EOF
}

fail_usage() {
    usage >&2
    exit "$EXIT_INVALID_ARGS"
}

require_client() {
    if [[ ! -x "$BASH_INTEL_CLIENT" ]]; then
        echo "Error: bash intelligence client is not executable: $BASH_INTEL_CLIENT" >&2
        exit "$EXIT_FILE_NOT_FOUND"
    fi
}

validate_shell_file() {
    local raw_path="$1"
    local safe_path

    safe_path=$(validate_path "$raw_path") || {
        echo "Error: Invalid shell file path: $raw_path" >&2
        exit "$EXIT_INVALID_ARGS"
    }

    if [[ ! -f "$safe_path" ]]; then
        echo "Error: Shell file not found: $safe_path" >&2
        exit "$EXIT_FILE_NOT_FOUND"
    fi

    case "$safe_path" in
        *.sh|*.bash|*.zsh)
            printf '%s\n' "$safe_path"
            return 0
            ;;
    esac

    if head -n 1 "$safe_path" | grep -Eq '(^#!.*(ba|z|k)?sh|shell)'; then
        printf '%s\n' "$safe_path"
        return 0
    fi

    echo "Error: Not a recognized shell file: $safe_path" >&2
    exit "$EXIT_INVALID_ARGS"
}

main() {
    local command="${1:-}"
    local target

    [[ -n "$command" ]] || fail_usage
    shift || true

    case "$command" in
        -h|--help|help)
            usage
            ;;
        check)
            require_client
            [[ "$#" -eq 0 ]] || fail_usage
            "$BASH_INTEL_CLIENT" check
            ;;
        symbols|outline)
            require_client
            [[ "$#" -eq 1 ]] || fail_usage
            target=$(validate_shell_file "$1")
            "$BASH_INTEL_CLIENT" symbols "$target"
            ;;
        workspace-symbols)
            require_client
            [[ "$#" -ge 1 ]] || fail_usage
            "$BASH_INTEL_CLIENT" workspace-symbols "$*"
            ;;
        definition|references)
            require_client
            [[ "$#" -ge 1 ]] || fail_usage
            "$BASH_INTEL_CLIENT" "$command" "$*"
            ;;
        *)
            echo "Error: Unknown command: $command" >&2
            fail_usage
            ;;
    esac
}

main "$@"
