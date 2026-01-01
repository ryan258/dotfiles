#!/usr/bin/env python3
import sys
import math
import argparse
import csv
import os
from datetime import datetime

def calculate_pearson(x, y):
    n = len(x)
    if n != len(y):
        raise ValueError("Datasets must have equal length")
    if n < 2:
        return 0.0

    sum_x = sum(x)
    sum_y = sum(y)
    sum_x_sq = sum(xi * xi for xi in x)
    sum_y_sq = sum(yi * yi for yi in y)
    sum_xy = sum(xi * yi for xi, yi in zip(x, y))

    numerator = sum_xy - (sum_x * sum_y / n)
    denominator = math.sqrt((sum_x_sq - sum_x**2 / n) * (sum_y_sq - sum_y**2 / n))

    if denominator == 0:
        return 0.0
    return numerator / denominator

def load_dataset(filepath, date_col, value_col, delimiter='|'):
    if not os.path.exists(filepath):
        print(f"Error: File not found: {filepath}", file=sys.stderr)
        sys.exit(1)

    data = {}
    with open(filepath, 'r') as f:
        reader = csv.reader(f, delimiter=delimiter)
        for row in reader:
            if len(row) > max(date_col, value_col):
                try:
                    # Simple date normalization
                    date_str = row[date_col].split(' ')[0] 
                    value = float(row[value_col])
                    
                    # Handle multiple entries per day by averaging? 
                    # For now, let's just append to list and process later
                    if date_str not in data:
                        data[date_str] = []
                    data[date_str].append(value)
                except ValueError:
                    continue
    
    # Average daily values
    averaged_data = {}
    for date, values in data.items():
        averaged_data[date] = sum(values) / len(values)
        
    return averaged_data

def correlate(file1, file2, date_col_1=1, val_col_1=2, date_col_2=1, val_col_2=2):
    data1 = load_dataset(file1, date_col_1, val_col_1)
    data2 = load_dataset(file2, date_col_2, val_col_2)
    
    # Find common dates
    common_dates = sorted(set(data1.keys()) & set(data2.keys()))
    
    if len(common_dates) == 0:
        print(f"Error: No overlapping dates between {file1} and {file2}", file=sys.stderr)
        sys.exit(1)
    elif len(common_dates) < 5:
        print(f"Warning: Only {len(common_dates)} overlapping data points (recommended minimum: 5)", file=sys.stderr)
        # Continue anyway

        
    x = [data1[d] for d in common_dates]
    y = [data2[d] for d in common_dates]
    
    r = calculate_pearson(x, y)
    print(f"{r:.4f}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Correlation Engine')
    subparsers = parser.add_subparsers(dest='command')
    
    corr_parser = subparsers.add_parser('correlate')
    corr_parser.add_argument('file1')
    corr_parser.add_argument('file2')
    corr_parser.add_argument('--d1', type=int, default=1, help='Date column index file 1 (0-based)')
    corr_parser.add_argument('--v1', type=int, default=2, help='Value column index file 1 (0-based)')
    corr_parser.add_argument('--d2', type=int, default=1, help='Date column index file 2 (0-based)')
    corr_parser.add_argument('--v2', type=int, default=2, help='Value column index file 2 (0-based)')
    
    args = parser.parse_args()
    
    if args.command == 'correlate':
        correlate(args.file1, args.file2, args.d1, args.v1, args.d2, args.v2)
