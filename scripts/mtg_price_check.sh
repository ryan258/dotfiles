#!/bin/bash
# mtg_final_tracker.sh - Simple wrapper script

set -e

API_URL="https://api.cardkingdom.com/api/pricelist"
COLLECTION_FILE="${1:-collection.csv}"
OUTPUT_DIR="$HOME/mtg_prices"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="$OUTPUT_DIR/collection_with_prices_$TIMESTAMP.csv"
BUYLIST_CACHE="$OUTPUT_DIR/buylist_cache_$TIMESTAMP.json"

mkdir -p "$OUTPUT_DIR"

echo "=== MTG Collection Price Tracker ==="
echo "Collection: $COLLECTION_FILE"
echo "Output: $OUTPUT_FILE"
echo ""

if [ ! -f "$COLLECTION_FILE" ]; then
    echo "Error: Collection file not found: $COLLECTION_FILE"
    exit 1
fi

echo "Fetching buylist data..."
curl -s -f "$API_URL" > "$BUYLIST_CACHE"

echo "Processing with Python..."
echo "Arguments: '$BUYLIST_CACHE' '$COLLECTION_FILE' '$OUTPUT_FILE'"

# Debug: Check if files exist
if [ ! -f "$BUYLIST_CACHE" ]; then
    echo "ERROR: Buylist cache missing: $BUYLIST_CACHE"
    exit 1
fi

if [ ! -f ~/scripts/mtg_tracker.py ]; then
    echo "ERROR: Python script missing: ~/scripts/mtg_tracker.py"
    exit 1
fi

python3 ~/scripts/mtg_tracker.py "$BUYLIST_CACHE" "$COLLECTION_FILE" "$OUTPUT_FILE"

echo ""
echo "Files created:"
echo "- Output: $OUTPUT_FILE"  
echo "- Buylist cache: $BUYLIST_CACHE"