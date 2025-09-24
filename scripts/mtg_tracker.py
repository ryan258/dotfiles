#!/usr/bin/env python3
# mtg_fixed_processor.py - Properly handle foil vs non-foil matching

import csv
import json
import sys

if len(sys.argv) != 4:
    print("Usage: python3 mtg_fixed_processor.py <buylist.json> <collection.csv> <output.csv>")
    sys.exit(1)

buylist_file = sys.argv[1]
collection_file = sys.argv[2] 
output_file = sys.argv[3]

# Load buylist data
print("Loading buylist data...")
with open(buylist_file, 'r') as f:
    buylist_data = json.load(f)

print(f"Loaded {len(buylist_data['data'])} buylist entries")

# Process collection
matched_count = 0
total_value = 0.0
all_cards = []

def find_best_match(card_name, card_edition, is_foil):
    """Find the best matching buylist entry"""
    
    # Convert foil status to buylist format
    target_foil_str = "true" if is_foil else "false"
    
    # Edition mappings
    edition_map = {
        "revised edition": "3rd edition",
        "fourth edition": "4th edition", 
        "unlimited edition": "unlimited"
    }
    
    mapped_edition = edition_map.get(card_edition.lower(), card_edition.lower())
    
    # Try exact name + edition + foil match first
    exact_matches = [
        card for card in buylist_data['data']
        if (card['name'].lower() == card_name.lower() and
            card['edition'].lower() == mapped_edition and
            card['is_foil'] == target_foil_str)
    ]
    
    if exact_matches:
        return exact_matches[0]
    
    # Try name + foil match (any edition, but conservative price cap)
    name_foil_matches = [
        card for card in buylist_data['data']
        if (card['name'].lower() == card_name.lower() and
            card['is_foil'] == target_foil_str and
            float(card['price_buy']) < 300)  # Reasonable price cap
    ]
    
    if name_foil_matches:
        # Return the cheapest to be conservative
        return min(name_foil_matches, key=lambda x: float(x['price_buy']))
    
    return None

print("Processing collection...")
with open(collection_file, 'r') as f:
    reader = csv.reader(f)
    header = next(reader)
    
    # Write output header
    with open(output_file, 'w', newline='') as out_f:
        writer = csv.writer(out_f)
        enhanced_header = header + ['Buy Price', 'Retail Price', 'Qty Buying', 'Total Buy Value', 'Foil Status Match']
        writer.writerow(enhanced_header)
        
        for row in reader:
            if len(row) < 19:
                continue
                
            count = int(row[0]) if row[0].isdigit() else 0
            name = row[2].strip()
            edition = row[3].strip()
            foil_field = row[8].strip() if len(row) > 8 else ""
            
            # Determine if card is foil
            is_foil = foil_field.lower() in ["foil", "true", "1", "yes"]
            
            # Find match
            match = find_best_match(name, edition, is_foil)
            
            if match:
                matched_count += 1
                buy_price = float(match['price_buy'])
                retail_price = float(match['price_retail'])
                qty_buying = match['qty_buying']
                total_buy_value = count * buy_price
                total_value += total_buy_value
                
                # Check if foil status matches
                foil_match = "Yes" if match['is_foil'] == ("true" if is_foil else "false") else "No"
                
                # Store for top cards list
                if total_buy_value > 0:
                    foil_indicator = " (FOIL)" if is_foil else ""
                    all_cards.append((total_buy_value, name + foil_indicator, edition, count, buy_price))
            else:
                buy_price = 0.0
                retail_price = 0.0
                qty_buying = 0
                total_buy_value = 0.0
                foil_match = "No Match"
            
            # Write enhanced row
            enhanced_row = row + [
                f"{buy_price:.2f}",
                f"{retail_price:.2f}",
                str(qty_buying),
                f"{total_buy_value:.2f}",
                foil_match
            ]
            writer.writerow(enhanced_row)

# Show results
print(f"\nProcessing complete!")
print(f"Cards processed: {reader.line_num - 1}")
print(f"Cards matched: {matched_count}")
print(f"Total collection value: ${total_value:.2f}")

# Sort and show top cards
all_cards.sort(reverse=True)

print(f"\n=== Top 20 Most Valuable Cards ===")
for i, (total_value, name, edition, count, buy_price) in enumerate(all_cards[:20]):
    print(f"{i+1:2d}. {name:<40} {edition:<20} {count}x @ ${buy_price:<6.2f} = ${total_value:.2f}")

# Value distribution
high_value = len([c for c in all_cards if c[0] >= 50])
medium_value = len([c for c in all_cards if 10 <= c[0] < 50])
low_value = len([c for c in all_cards if 1 <= c[0] < 10])

print(f"\nValue Distribution:")
print(f"Cards worth $50+: {high_value}")
print(f"Cards worth $10-49: {medium_value}")
print(f"Cards worth $1-9: {low_value}")