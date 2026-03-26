#!/usr/bin/env bash
# Spec helper for structured dispatcher inputs
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_SPEC_HELPER_LOADED:-}" ]]; then
  return 0
fi
readonly _SPEC_HELPER_LOADED=true

if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  _spec_helper_source="${BASH_SOURCE[0]}"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
  _spec_helper_source="${(%):-%N}"
else
  _spec_helper_source="$0"
fi
SPEC_HELPER_DIR="$(cd "$(dirname "$_spec_helper_source")" && pwd)"
unset _spec_helper_source
if [ -f "$SPEC_HELPER_DIR/lib/config.sh" ]; then
  # shellcheck disable=SC1090
  source "$SPEC_HELPER_DIR/lib/config.sh"
else
  echo "Error: configuration library not found at $SPEC_HELPER_DIR/lib/config.sh" >&2
  return 1
fi
if [ -f "$SPEC_HELPER_DIR/lib/common.sh" ]; then
  # shellcheck disable=SC1090
  source "$SPEC_HELPER_DIR/lib/common.sh"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  echo "Error: DATA_DIR is not set. Source config.sh before spec_helper.sh." >&2
  return 1
fi

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SPEC_HELPER_DIR/.." && pwd)}"

_spec_helper_cleanup_tmpfile() {
  local tmp_path="${1:-}"
  if [[ -n "$tmp_path" ]]; then
    rm -f "$tmp_path" 2>/dev/null || true
  fi
}

# _spec_helper_restore_trap: delegates to common.sh restore_trap
_spec_helper_restore_trap() { restore_trap "$@"; }

spec_dispatch() {
  local dispatcher="${1}"
  local interrupted=false
  local saved_int_trap=""
  local saved_term_trap=""

  # Validate dispatcher
  if [[ -z "$dispatcher" ]]; then
    echo "Usage: spec <dispatcher>"
    echo "Available: tech, creative, content, strategy, brand, market, research, stoic, narrative, copy, finance, morphling"
    return 1
  fi

  # Check if dispatcher exists
  if ! command -v "$dispatcher" &> /dev/null; then
    echo "❌ Dispatcher '$dispatcher' not found"
    return 1
  fi

  # Path to dispatcher-specific template
  local template_file="$DOTFILES_DIR/templates/${dispatcher}-spec.txt"

  # Fallback to generic template if specific one doesn't exist
  if [[ ! -f "$template_file" ]]; then
    template_file="$DOTFILES_DIR/templates/dispatcher-spec-template.txt"
  fi

  # Create temp file from template (macOS compatible)
  local tmpfile
  if type create_temp_file &>/dev/null; then
    tmpfile=$(create_temp_file "spec")
  else
    tmpfile=$(mktemp -t "spec.XXXXXX")
    chmod 600 "$tmpfile"
  fi
  mv "$tmpfile" "${tmpfile}.${dispatcher}-spec.txt"
  tmpfile="${tmpfile}.${dispatcher}-spec.txt"
  cat "$template_file" > "$tmpfile"
  saved_int_trap=$(trap -p INT || true)
  saved_term_trap=$(trap -p TERM || true)
  trap '_spec_helper_cleanup_tmpfile "$tmpfile"; interrupted=true' INT TERM

  # Open in user's preferred editor
  if command -v code &> /dev/null && [[ "$EDITOR" == "code" || "$EDITOR" == "code --wait" ]]; then
    code --wait "$tmpfile"
  else
    "${EDITOR:-vim}" "$tmpfile"
  fi

  _spec_helper_restore_trap INT "$saved_int_trap"
  _spec_helper_restore_trap TERM "$saved_term_trap"
  if [[ "$interrupted" == "true" ]]; then
    return 130
  fi

  # Check if user actually wrote something
  if [[ ! -s "$tmpfile" ]]; then
    echo "⚠️  Spec is empty, aborting"
    _spec_helper_cleanup_tmpfile "$tmpfile"
    return 1
  fi

  # Show what we're about to send
  echo "📤 Sending spec to $dispatcher dispatcher..."

  # Pipe to dispatcher
  cat "$tmpfile" | "$dispatcher"

  # Optional: Save completed spec for reference
  local spec_archive="${SPEC_ARCHIVE_DIR}/"
  mkdir -p "$spec_archive"
  cp "$tmpfile" "$spec_archive/$(date +%Y%m%d-%H%M%S)-${dispatcher}.txt"
  echo "💾 Spec saved to $spec_archive"

  # Cleanup temp file
  _spec_helper_cleanup_tmpfile "$tmpfile"
}

# Export function for use in shell
alias spec='spec_dispatch'
