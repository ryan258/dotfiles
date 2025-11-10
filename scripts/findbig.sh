#!/bin/bash
# findbig.sh - Find the 10 largest files/folders in the current directory
set -euo pipefail

echo "Searching for the top 10 largest files and folders here..."
du -ah . | sort -rh | head -n 10

# ---