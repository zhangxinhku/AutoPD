#!/usr/bin/env python3
#############################################################################################################
# Script Name: json_to_table.py
# Description: Convert homologs.json or af_models.json from MrParse/AlphaFold output into a tab-delimited text
#              table with optional cutoff filtering for homolog release dates.
#
# Usage:
#   python json_to_table.py [json_file_path] [optional_cutoff_date]
#
# Example:
#   python json_to_table.py homologs.json 2020-01-01
#   python json_to_table.py af_models.json
#
# Input:
#   - homologs.json: Homology models with fields like name, seq_ident, region_id, etc.
#   - af_models.json: AlphaFold models with confidence metrics.
#
# Output:
#   - homologs.txt or af_models.txt: Tab-delimited table sorted by sequence identity and pLDDT.
#
# Dependencies:
#   - Python 3.7+
#   - pandas (`pip install pandas`)
#
# Author: ZHANG Xin
# Date Created: 2023-06-01
# Last Modified: 2025-08-03
#############################################################################################################

import json
import pandas as pd
import sys
import os
import re
from datetime import datetime

def extract_release_dates(log_file_name, names):
    """Extract release dates from log file for given names"""
    release_dates = {}
    try:
        with open(log_file_name, 'r', encoding='utf-8') as file:
            for line in file:
                for name in names.copy():  # Iterate over a copy to avoid modification during iteration
                    if name in line:
                        # Search for release_date pattern in log line
                        match = re.search(r'release_date: (\d{4}-\d{2}-\d{2})', line)
                        if match:
                            release_dates[name] = match.group(1)
                            names.remove(name)
                        break  # Proceed to next line after match
    except FileNotFoundError:
        print(f"Warning: {log_file_name} not found. 'release_date' will be set to 'Unknown' for all entries.")
    
    # Set 'Unknown' for remaining names without dates
    for name in names:
        release_dates[name] = 'Unknown'
    return release_dates

def json_to_txt(json_file_path, cutoff_date=None):
    """Convert JSON data to formatted text table"""
    # Load JSON data
    with open(json_file_path, 'r', encoding='utf-8') as file:
        data = json.load(file)
    
    # Exit if input data is empty
    if not data:
        print("Error: Input JSON data is empty")
        sys.exit(1)

    file_name = os.path.basename(json_file_path)
    
    # Process homologs data
    if file_name == 'homologs.json':
        # Collect names for date extraction
        names = [item['name'] for item in data]
        release_dates = extract_release_dates('mrparse.log', names)
        
        # Add release dates to items
        for item in data:
            item['release_date'] = release_dates.get(item['name'], 'Unknown')
        
        # Apply date filtering if specified
        if cutoff_date:
            try:
                cutoff_date_obj = datetime.strptime(cutoff_date, "%Y-%m-%d")
                filtered_data = []
                for item in data:
                    rd = item['release_date']
                    if rd == 'Unknown':
                        continue  # Skip items with unknown dates
                    try:
                        item_date = datetime.strptime(rd, "%Y-%m-%d")
                        if item_date < cutoff_date_obj:
                            filtered_data.append(item)
                    except ValueError:
                        continue
                data = filtered_data
            except ValueError:
                print(f"Error: Invalid cutoff date format {cutoff_date}, expected YYYY-MM-DD")
                sys.exit(1)
        
        # Exit if no data remains after filtering
        if not data:
            print("No homologs found before cutoff date.")
            sys.exit(1)

        # Define output fields and sort
        fields = ['name', 'seq_ident', 'region_id', 'range', 'length', 'release_date']
        data.sort(key=lambda x: (x['seq_ident'], x.get('avg_plddt', 0)), reverse=True)

    # Process AlphaFold models data
    elif file_name == 'af_models.json':
        fields = ['name', 'seq_ident', 'region_id', 'range', 'length', 'h_score', 'avg_plddt']
        data.sort(key=lambda x: (x['seq_ident'], x['avg_plddt']), reverse=True)
        if not data:
            print("Error: No AlphaFold models found")
            sys.exit(1)

    # Create DataFrame with specified columns
    df = pd.DataFrame(data, columns=fields)
    
    # Generate output text file
    txt_file_path = os.path.splitext(json_file_path)[0] + '.txt'
    with open(txt_file_path, 'w', encoding='utf-8') as f:
        # Calculate column widths
        max_lengths = [max(len(str(x)) for x in df[col]) for col in df.columns]
        
        # Write formatted rows only
        for _, row in df.iterrows():
            formatted = [str(row[col]).ljust(width) for col, width in zip(df.columns, max_lengths)]
            f.write('\t'.join(formatted) + '\n')

if __name__ == '__main__':
    # Validate command line arguments
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        print("Usage: python json_to_table.py [json_file_path] [optional_cutoff_date]")
        sys.exit(1)

    json_file_path = sys.argv[1]
    cutoff_date = sys.argv[2] if len(sys.argv) == 3 else None

    try:
        json_to_txt(json_file_path, cutoff_date)
    except Exception as e:
        print(f"Error: {str(e)}")
        sys.exit(1)
