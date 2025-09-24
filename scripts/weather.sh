#!/bin/bash

# --- Gets the weather for a specified city (or your current location) ---
# It uses the website wttr.in, which is designed for terminals.

# You can change this to your preferred city
city="Bentonville"

echo "Fetching the weather for $city..."
curl "https://wttr.in/$city"