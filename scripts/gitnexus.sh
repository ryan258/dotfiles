#!/usr/bin/env bash
set -euo pipefail

# gitnexus.sh - Stable repo-local GitNexus entrypoint.
#
# Prefer an explicitly configured or installed GitNexus binary. Fall back to the
# npm npx cache before invoking npx, because some Node/npm combinations can fail
# after installing GitNexus even though the cached binary itself works.

find_gitnexus_bin() {
    local candidate legacy_candidate candidate_version

    if [[ -n "${GITNEXUS_BIN:-}" && -x "$GITNEXUS_BIN" ]]; then
        printf '%s\n' "$GITNEXUS_BIN"
        return 0
    fi

    if command -v gitnexus >/dev/null 2>&1; then
        command -v gitnexus
        return 0
    fi

    for candidate in "$HOME"/.npm/_npx/*/node_modules/.bin/gitnexus; do
        [[ -x "$candidate" ]] || continue
        candidate_version="$("$candidate" --version 2>/dev/null || true)"
        case "$candidate_version" in
            ""|1.4.*)
                legacy_candidate="${legacy_candidate:-$candidate}"
                ;;
            *)
                printf '%s\n' "$candidate"
                return 0
                ;;
        esac
    done

    if [[ -n "${legacy_candidate:-}" ]]; then
        printf '%s\n' "$legacy_candidate"
        return 0
    fi

    return 1
}

main() {
    local gitnexus_bin

    if gitnexus_bin="$(find_gitnexus_bin)"; then
        exec "$gitnexus_bin" "$@"
    fi

    if command -v npx >/dev/null 2>&1; then
        exec npx gitnexus "$@"
    fi

    cat >&2 <<'EOF'
Error: GitNexus CLI not found.

Install it with npm, or set GITNEXUS_BIN to a working gitnexus executable.
EOF
    return 127
}

main "$@"
