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

def linear_regression_slope(xs, ys):
    n = len(xs)
    if n < 2:
        return 0.0
    x_mean = sum(xs) / n
    y_mean = sum(ys) / n
    num = sum((x - x_mean) * (y - y_mean) for x, y in zip(xs, ys))
    den = sum((x - x_mean) ** 2 for x in xs)
    if den == 0:
        return 0.0
    return num / den

def patterns(file1, date_col=1, val_col=2, delimiter='|'):
    data = load_dataset(file1, date_col, val_col, delimiter=delimiter)
    if not data:
        print("No usable data found.")
        return

    dates = sorted(data.keys())
    values = [data[d] for d in dates]

    count = len(values)
    mean_val = sum(values) / count
    min_val = min(values)
    max_val = max(values)

    # Weekday averages
    weekday_values = {i: [] for i in range(7)}  # Monday=0
    for date_str, val in data.items():
        try:
            dt = datetime.strptime(date_str, "%Y-%m-%d")
        except ValueError:
            continue
        weekday_values[dt.weekday()].append(val)

    # Trend (simple slope per day)
    slope = linear_regression_slope(list(range(count)), values)
    threshold = max(0.01 * abs(mean_val), 0.01)
    if abs(slope) < threshold:
        trend = "flat"
    elif slope > 0:
        trend = "increasing"
    else:
        trend = "decreasing"

    print(f"Patterns for {file1}")
    print(f"Days: {count}")
    print(f"Mean: {mean_val:.2f}  Min: {min_val:.2f}  Max: {max_val:.2f}")
    print(f"Trend: {trend} (slope {slope:+.4f} per day)")
    print("")
    print("By weekday:")
    labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    for i in range(7):
        vals = weekday_values[i]
        if vals:
            avg = sum(vals) / len(vals)
            print(f"  {labels[i]}: {avg:.2f} (n={len(vals)})")
        else:
            print(f"  {labels[i]}: N/A")

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

    patterns_parser = subparsers.add_parser('patterns')
    patterns_parser.add_argument('file1')
    patterns_parser.add_argument('--d', type=int, default=1, help='Date column index (0-based)')
    patterns_parser.add_argument('--v', type=int, default=2, help='Value column index (0-based)')
    patterns_parser.add_argument('--delimiter', default='|', help='Field delimiter (default: |)')
    
    args = parser.parse_args()
    
    if args.command == 'correlate':
        correlate(args.file1, args.file2, args.d1, args.v1, args.d2, args.v2)
    elif args.command == 'patterns':
        patterns(args.file1, args.d, args.v, args.delimiter)
