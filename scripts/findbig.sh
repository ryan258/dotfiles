#!/usr/bin/env bash
# findbig.sh - Find the 10 largest files/folders in the current directory
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Usage: ./findbig.sh
# output: Lists top 10 largest items in current directory

du -ah . | sort -rh | head -n 10

# ---
