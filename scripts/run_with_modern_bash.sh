#!/bin/sh
set -eu

# Bootstrap exception: this wrapper intentionally uses POSIX sh so launchd/cron
# can find and exec a modern Bash before any Bash-dependent script starts.

usage() {
  echo "Usage: $(basename "$0") <script> [args...]" >&2
}

find_modern_bash() {
  PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

  for candidate in \
    "${DOTFILES_BASH_BIN:-}" \
    "/opt/homebrew/bin/bash" \
    "/usr/local/bin/bash" \
    "$(command -v bash 2>/dev/null || true)"
  do
    [ -n "$candidate" ] || continue
    [ -x "$candidate" ] || continue

    # shellcheck disable=SC2016
    major=$("$candidate" -c 'printf "%s" "${BASH_VERSINFO[0]:-0}"' 2>/dev/null || printf '0')
    if [ "$major" -ge 4 ] 2>/dev/null; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

if [ "$#" -lt 1 ]; then
  usage
  exit 2
fi

script_path="$1"
shift

bash_bin="$(find_modern_bash || true)"
if [ -z "$bash_bin" ]; then
  echo "Error: Modern Bash 4+ not found. Install Homebrew bash and set DOTFILES_BASH_BIN if needed." >&2
  exit 5
fi

exec "$bash_bin" "$script_path" "$@"
