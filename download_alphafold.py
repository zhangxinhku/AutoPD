#!/usr/bin/env python3
#############################################################################################################
# Script Name: download_alphafold.py
# Description: Download AlphaFold PDB file from EBI AlphaFold DB, calculate average pLDDT,
#              and insert it into the PDB as a REMARK line.
# Usage:       python3 download_alphafold.py <UniProt_ID>
# Example:     python3 download_alphafold.py P00520
#
# Input:       UniProt accession ID (string, e.g., P00520).
# Output:      PDB file saved in the current directory with an additional REMARK line showing average pLDDT.
#
# Dependencies:
#   - Python 3.7+
#   - requests library (`pip install requests`)
#
# Author: ZHANG Xin
# Date Created: 2023-06-01
# Last Modified: 2025-08-03
#############################################################################################################

import requests
import argparse
import re

def download_alphafold_pdb(uniprot_id):
    # Construct API URL for the PDB file
    pdb_url = f"https://alphafold.ebi.ac.uk/files/AF-{uniprot_id}-F1-model_v4.pdb"
    
    try:
        # Download PDB file
        pdb_response = requests.get(pdb_url, stream=True)
        pdb_response.raise_for_status()

        # Read lines and collect pLDDT values
        pdb_lines = []
        plddt_values = []
        for line in pdb_response.iter_lines():
            decoded_line = line.decode('utf-8')
            pdb_lines.append(decoded_line)
            
            # Check if the line is an ATOM or HETATM record
            if decoded_line.startswith(('ATOM', 'HETATM')):
                # Extract pLDDT from columns 61-66 (0-based index 60-66)
                if len(decoded_line) >= 66:
                    plddt_str = decoded_line[60:66].strip()
                    if plddt_str:
                        try:
                            plddt = float(plddt_str)
                            plddt_values.append(plddt)
                        except ValueError:
                            pass  # Skip invalid pLDDT values

        # Calculate average pLDDT
        avg_plddt = sum(plddt_values) / len(plddt_values) if plddt_values else 0.0

        # Create new REMARK line
        new_remark = f"REMARK   1   Average pLDDT: {avg_plddt:.2f}"

        # Determine the position to insert the new REMARK line
        insert_pos = 0
        last_remark_1 = -1

        # Find the last occurrence of 'REMARK   1'
        for idx, line in enumerate(pdb_lines):
            if line.startswith('REMARK   1'):
                last_remark_1 = idx
            elif line.startswith('REMARK'):
                # Other REMARK lines, stop here
                break
            elif not line.startswith('REMARK') and last_remark_1 != -1:
                # Non-REMARK line after REMARK block, stop
                break

        # Set insertion position
        if last_remark_1 != -1:
            insert_pos = last_remark_1 + 1
        else:
            # Look for HEADER to insert after
            for idx, line in enumerate(pdb_lines):
                if line.startswith('HEADER'):
                    insert_pos = idx + 1
                    break
            # If no HEADER, insert at the beginning
            else:
                insert_pos = 0

        # Insert the new REMARK line
        pdb_lines.insert(insert_pos, new_remark)

        # Determine filename from Content-Disposition or default
        filename = f"AF-{uniprot_id}-F1-model_v4.pdb"
        if 'Content-Disposition' in pdb_response.headers:
            content_disp = pdb_response.headers['Content-Disposition']
            match = re.search(r'filename=(["\']?)([^;"\']+)\1', content_disp)
            if match:
                filename = match.group(2)

        # Write the modified content to the file
        with open(filename, 'w') as f:
            f.write('\n'.join(pdb_lines))

        print(f"File saved as {filename} plddt={avg_plddt}")
        return True

    except requests.exceptions.HTTPError as err:
        print(f"HTTP Error: {err}")
    except Exception as e:
        print(f"Error processing file: {e}")
    return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Download AlphaFold PDB with average pLDDT remark')
    parser.add_argument('uniprot_id', type=str, help='UniProt ID (e.g. P00520)')
    args = parser.parse_args()
    
    download_alphafold_pdb(args.uniprot_id)
