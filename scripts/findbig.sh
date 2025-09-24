#!/bin/bash
# findbig.sh - Find the 10 largest files/folders in the current directory

echo "Searching for the top 10 largest files and folders here..."
du -ah . | sort -rh | head -n 10

# ---