#!/usr/bin/env bash
set -euo pipefail

# repo_tracker.sh - Mark GitHub repos as active or inactive.

REPO_TRACKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_TRACKER_DIR/lib/common.sh"
source "$REPO_TRACKER_DIR/lib/config.sh"
source "$REPO_TRACKER_DIR/lib/date_utils.sh"
source "$REPO_TRACKER_DIR/lib/github_ops.sh"

usage() {
    cat <<'EOF'
Usage:
  repo_tracker.sh deactivate <repo> [note...]
  repo_tracker.sh reactivate <repo>
  repo_tracker.sh list
  repo_tracker.sh names

Aliases:
  deactivate: park, pause
  reactivate: activate, unpark
EOF
}

# Keep this CLI thin on purpose. github_ops.sh owns the storage rules.
repo_tracker_deactivate() {
    local repo_name="${1:-}"
    shift || true
    local inactive_note=""

    repo_name=$(sanitize_single_line "$repo_name")
    inactive_note=$(sanitize_for_storage "$*")

    if [[ -z "$repo_name" ]]; then
        die "Repo name is required for deactivate." "$EXIT_INVALID_ARGS"
    fi

    # Save the note with the repo so future-you knows why it was parked.
    deactivate_github_repo "$repo_name" "$inactive_note" || die "Failed to deactivate repo: $repo_name" "$EXIT_ERROR"

    if [[ -n "$inactive_note" ]]; then
        printf 'Deactivated repo: %s\nNote: %s\n' "$repo_name" "$inactive_note"
    else
        printf 'Deactivated repo: %s\n' "$repo_name"
    fi
}

repo_tracker_reactivate() {
    local repo_name="${1:-}"

    repo_name=$(sanitize_single_line "$repo_name")
    if [[ -z "$repo_name" ]]; then
        die "Repo name is required for reactivate." "$EXIT_INVALID_ARGS"
    fi

    if ! is_github_repo_inactive "$repo_name"; then
        printf 'Repo already active: %s\n' "$repo_name"
        return 0
    fi

    reactivate_github_repo "$repo_name" || die "Failed to reactivate repo: $repo_name" "$EXIT_ERROR"
    printf 'Reactivated repo: %s\n' "$repo_name"
}

repo_tracker_list() {
    local inactive_repos=""

    inactive_repos=$(get_inactive_github_repos || true)
    if [[ -z "$inactive_repos" ]]; then
        echo "(No inactive repos)"
        return 0
    fi

    echo "Inactive repos:"
    printf '%s\n' "$inactive_repos"
}

repo_tracker_names() {
    local inactive_names=""

    inactive_names=$(get_inactive_github_repo_names || true)
    if [[ -z "$inactive_names" ]]; then
        echo "(No inactive repos)"
        return 0
    fi

    printf '%s\n' "$inactive_names"
}

# Main just routes to the small helper commands above.
main() {
    local command="${1:-list}"
    shift || true

    case "$command" in
        deactivate|park|pause)
            repo_tracker_deactivate "$@"
            ;;
        reactivate|activate|unpark)
            repo_tracker_reactivate "$@"
            ;;
        list)
            repo_tracker_list
            ;;
        names)
            repo_tracker_names
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            usage >&2
            die "Unknown repo_tracker command: $command" "$EXIT_INVALID_ARGS"
            ;;
    esac
}

main "$@"
