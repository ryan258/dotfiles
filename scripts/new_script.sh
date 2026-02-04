#!/usr/bin/env bash
set -euo pipefail

# --- new_script.sh: New Script Creation Utility ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/lib/common.sh"
fi

if [ -f "$SCRIPT_DIR/lib/config.sh" ]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/lib/config.sh"
fi

if [ -z "$1" ]; then
  echo "Usage: new_script.sh <script_name> [--force]"
  echo "Example: new_script.sh my_tool"
  echo ""
  echo "Options:"
  echo "  --force    Override name collision warnings"
  exit 1
fi

SCRIPT_NAME_RAW="$1"
SCRIPT_NAME=$(sanitize_input "$SCRIPT_NAME_RAW")
SCRIPT_NAME=${SCRIPT_NAME//$'\n'/ }

if [ -z "$SCRIPT_NAME" ]; then
  echo "Error: Script name is required." >&2
  exit 1
fi
if [[ "$SCRIPT_NAME" == -* ]]; then
  echo "Error: Script name cannot start with '-'." >&2
  exit 1
fi
if ! [[ "$SCRIPT_NAME" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "Error: Script name can only contain letters, numbers, '_' and '-'." >&2
  exit 1
fi

SCRIPTS_DIR="$SCRIPT_DIR"
SCRIPTS_DIR=$(validate_path "$SCRIPTS_DIR") || exit 1
SCRIPT_PATH="$SCRIPTS_DIR/$SCRIPT_NAME.sh"

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
ALIASES_FILE="$DOTFILES_DIR/zsh/aliases.zsh"
ALIASES_FILE=$(validate_path "$ALIASES_FILE") || exit 1

# --- Collision Detection ---
FORCE_MODE=false
if [ "${2:-}" == "--force" ]; then
  FORCE_MODE=true
fi

COLLISIONS_FOUND=false

# Check 1: Script file already exists
if [ -f "$SCRIPT_PATH" ]; then
  echo "⚠️  Collision: Script already exists at $SCRIPT_PATH"
  COLLISIONS_FOUND=true
fi

# Check 2: Alias already exists in aliases.zsh
if [ -f "$ALIASES_FILE" ] && grep -q "^alias $SCRIPT_NAME=" "$ALIASES_FILE"; then
  echo "⚠️  Collision: Alias '$SCRIPT_NAME' already exists in $ALIASES_FILE"
  COLLISIONS_FOUND=true
fi

# Check 3: Another script with similar name exists
for ext in .sh .bash .zsh ""; do
  OTHER_SCRIPT="$SCRIPTS_DIR/$SCRIPT_NAME$ext"
  if [ -f "$OTHER_SCRIPT" ] && [ "$OTHER_SCRIPT" != "$SCRIPT_PATH" ]; then
    echo "⚠️  Collision: Similar script exists at $OTHER_SCRIPT"
    COLLISIONS_FOUND=true
    break
  fi
done

# Check 4: System command exists
if command -v "$SCRIPT_NAME" >/dev/null 2>&1; then
  echo "⚠️  Collision: '$SCRIPT_NAME' exists as a system command ($(command -v "$SCRIPT_NAME"))"
  COLLISIONS_FOUND=true
fi

# Exit if collisions found and not in force mode
if [ "$COLLISIONS_FOUND" = true ] && [ "$FORCE_MODE" = false ]; then
  echo ""
  echo "Error: Name collision detected. Use a different name or run with --force to override."
  exit 1
elif [ "$COLLISIONS_FOUND" = true ] && [ "$FORCE_MODE" = true ]; then
  echo ""
  echo "⚠️  Force mode enabled. Proceeding despite collisions..."
  echo ""
fi

# 1. Create the new script file

echo "Creating new script at $SCRIPT_PATH..."
cat << EOF > "$SCRIPT_PATH"
#!/usr/bin/env bash
set -euo pipefail

# --- $SCRIPT_NAME.sh ---

echo "Hello from $SCRIPT_NAME.sh!"
EOF

# 2. Make the script executable
chmod +x "$SCRIPT_PATH"

# 3. Add an alias to zsh/aliases.zsh
ALIAS_LINE="alias $SCRIPT_NAME=\"$SCRIPT_NAME.sh\""
echo "Adding alias to $ALIASES_FILE..."

# Add to the CORE PRODUCTIVITY SCRIPTS section for consistency
awk -v alias_line="$ALIAS_LINE" ' 
  /CORE PRODUCTIVITY SCRIPTS/ {
    print
    print alias_line
    next
  }
  { print }
' "$ALIASES_FILE" > "${ALIASES_FILE}.tmp" && mv "${ALIASES_FILE}.tmp" "$ALIASES_FILE"

echo "✅ Done!"
echo "New script created at $SCRIPT_PATH"
echo "Alias '$SCRIPT_NAME' added to $ALIASES_FILE"
echo "Please restart your shell or run 'source ~/.zshrc'"
