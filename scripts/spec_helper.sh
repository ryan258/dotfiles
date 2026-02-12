#!/usr/bin/env bash
# Spec helper for structured dispatcher inputs
# NOTE: SOURCED file. Do NOT use set -euo pipefail.

if [[ -n "${_SPEC_HELPER_LOADED:-}" ]]; then
  return 0
fi
readonly _SPEC_HELPER_LOADED=true

SPEC_HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SPEC_HELPER_DIR/lib/common.sh" ]; then
  # shellcheck disable=SC1090
  source "$SPEC_HELPER_DIR/lib/common.sh"
fi
if [ -f "$SPEC_HELPER_DIR/lib/config.sh" ]; then
  # shellcheck disable=SC1090
  source "$SPEC_HELPER_DIR/lib/config.sh"
else
  echo "Error: configuration library not found at $SPEC_HELPER_DIR/lib/config.sh" >&2
  return 1
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  echo "Error: DATA_DIR is not set. Source config.sh before spec_helper.sh." >&2
  return 1
fi

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SPEC_HELPER_DIR/.." && pwd)}"

spec_dispatch() {
  local dispatcher="${1}"

  # Validate dispatcher
  if [[ -z "$dispatcher" ]]; then
    echo "Usage: spec <dispatcher>"
    echo "Available: tech, creative, content, strategy, market, research, stoic"
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

  # Open in user's preferred editor
  if command -v code &> /dev/null && [[ "$EDITOR" == "code" || "$EDITOR" == "code --wait" ]]; then
    code --wait "$tmpfile"
  else
    "${EDITOR:-vim}" "$tmpfile"
  fi

  # Check if user actually wrote something
  if [[ ! -s "$tmpfile" ]]; then
    echo "⚠️  Spec is empty, aborting"
    rm "$tmpfile"
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
  rm "$tmpfile"
}

# Export function for use in shell
alias spec='spec_dispatch'
