#!/bin/bash
set -euo pipefail

# --- new_script.sh: New Script Creation Utility ---

if [ -z "$1" ]; then
  echo "Usage: new_script.sh <script_name>"
  echo "Example: new_script.sh my_tool"
  exit 1
fi

SCRIPT_NAME="$1"
SCRIPTS_DIR="$(dirname "$0")"
SCRIPT_PATH="$SCRIPTS_DIR/$SCRIPT_NAME.sh"
ALIASES_FILE="$HOME/dotfiles/zsh/aliases.zsh"

# 1. Create the new script file
if [ -f "$SCRIPT_PATH" ]; then
  echo "Error: Script already exists at $SCRIPT_PATH"
  exit 1
fi

echo "Creating new script at $SCRIPT_PATH..."
cat << EOF > "$SCRIPT_PATH"
#!/bin/bash
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
