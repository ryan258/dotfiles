#!/usr/bin/env bash
set -euo pipefail
# --- Gets the weather for a specified city (or your current location) ---
# It uses the website wttr.in, which is designed for terminals.
# Usage: ./weather.sh [city]
# Example: ./weather.sh "New York"

city="${1:-Bentonville}"

echo "Fetching the weather for $city..."
curl "https://wttr.in/$city"