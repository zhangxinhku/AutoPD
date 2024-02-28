import json
import pandas as pd
import sys
import os
import re
from datetime import datetime

def extract_release_dates(log_file_name, names):
    release_dates = {}
    try:
        with open(log_file_name, 'r', encoding='utf-8') as file:
            for line in file:
                for name in names:
                    if name in line:
                        # Search for release_date in the current line
                        match = re.search(r'release_date: (\d{4}-\d{2}-\d{2})', line)
                        if match:
                            release_dates[name] = match.group(1)
                            # Once found, remove the name from the list to avoid duplicate processing
                            names.remove(name)
                        break # Exit the current loop and process the next line

    except FileNotFoundError:
        print(f"Warning: {log_file_name} not found. 'release_date' will be set to 'Unknown' for all entries.")

    # For names that didn't have release_date found, set their release_date to 'Unknown'
    for name in names:
        release_dates[name] = 'Unknown'
    
    return release_dates

def format_row(row, max_lengths):
    # Format the row based on the maximum lengths
    formatted_row = []
    for i, item in enumerate(row):
        formatted_row.append(str(item).ljust(max_lengths[i]))
    return '\t'.join(formatted_row)  # Use tab as the separator

def json_to_txt(json_file_path, cutoff_date=None):
    # Read the JSON file
    with open(json_file_path, 'r', encoding='utf-8') as file:
        data = json.load(file)

    # Determine the fields and sorting based on the file name
    file_name = os.path.basename(json_file_path)
    if file_name == 'homologs.json':
        fields = ['name', 'seq_ident', 'region_id', 'range', 'length']
        names = [item['name'] for item in data]
        release_dates = extract_release_dates('mrparse.log', names)
        for item in data:
            item['release_date'] = release_dates.get(item['name'], 'Unknown')
        fields.append('release_date')
        # Sort the data
        data.sort(key=lambda x: (x['seq_ident'], x.get('avg_plddt', 0)), reverse=True)

        # If a cutoff date is provided, remove rows after that date
        if cutoff_date:
            cutoff_date_obj = datetime.strptime(cutoff_date, "%Y-%m-%d")
            data = [item for item in data if datetime.strptime(item['release_date'], "%Y-%m-%d") < cutoff_date_obj]

    elif file_name == 'af_models.json':
        fields = ['name', 'seq_ident', 'region_id', 'range', 'length', 'avg_plddt', 'h_score']
        # Sort the data
        data.sort(key=lambda x: (x['seq_ident'], x['avg_plddt']), reverse=True)

    # Create a DataFrame
    df = pd.DataFrame(data)[fields]

    # Calculate the maximum widths for each column
    max_lengths = [max(len(str(x)) for x in df[col]) for col in df.columns]

    # Get the output file path
    txt_file_path = os.path.splitext(json_file_path)[0] + '.txt'

    # Save the DataFrame as a text file
    with open(txt_file_path, 'w', encoding='utf-8') as f:
        # 移除了写表头的代码部分
        # Write the formatted data rows
        for index, row in df.iterrows():
            f.write(format_row(row, max_lengths) + '\n')

if __name__ == '__main__':
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        print("Usage: python json_to_table_with_sorting.py [json_file_path] [optional_cutoff_date]")
        sys.exit(1)

    json_file_path = sys.argv[1]
    cutoff_date = sys.argv[2] if len(sys.argv) == 3 else None

    json_to_txt(json_file_path, cutoff_date)

