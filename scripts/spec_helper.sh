#!/usr/bin/env bash
# Spec helper for structured dispatcher inputs
set -euo pipefail

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
  local template_file="$HOME/dotfiles/templates/${dispatcher}-spec.txt"

  # Fallback to generic template if specific one doesn't exist
  if [[ ! -f "$template_file" ]]; then
    template_file="$HOME/dotfiles/templates/dispatcher-spec-template.txt"
  fi

  # Create temp file from template (macOS compatible)
  local tmpfile; tmpfile=$(mktemp /tmp/spec-XXXXXX)
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
  local spec_archive="$HOME/.config/dotfiles-data/specs/"
  mkdir -p "$spec_archive"
  cp "$tmpfile" "$spec_archive/$(date +%Y%m%d-%H%M%S)-${dispatcher}.txt"
  echo "💾 Spec saved to $spec_archive"

  # Cleanup temp file
  rm "$tmpfile"
}

# Export function for use in shell
alias spec='spec_dispatch'
