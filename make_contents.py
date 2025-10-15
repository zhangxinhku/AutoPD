#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
make_contents.py
----------------
Generate a contents.json file for ModelCraft/CCP4 from a copy number and a FASTA file.

Functionality:
1. Read the FASTA file (may contain multiple chains).
2. For each chain:
   - Concatenate all sequence lines into a single string.
   - Ignore the FASTA header.
3. Write out a JSON file with the structure:

{
    "copies": 1,
    "proteins": [
        {
            "sequence": "SNALHLEPLHF..."
        },
        {
            "sequence": "SNAMSTLRLK..."
        }
    ]
}
"""

import sys, json

def fasta_to_sequences(fasta_file):
    """Read a FASTA file -> return a list of sequence strings (ignore headers)."""
    sequences = []
    seq = []
    with open(fasta_file) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith(">"):
                # Save the previous sequence
                if seq:
                    sequences.append("".join(seq))
                    seq = []
            else:
                seq.append(line)
        # Save the last sequence
        if seq:
            sequences.append("".join(seq))
    return sequences

def main():
    if len(sys.argv) < 3:
        print("Usage: python make_contents.py <copies> <fasta_file> [output.json]")
        sys.exit(1)

    copies = int(sys.argv[1])              # e.g., 1
    fasta_file = sys.argv[2]               # FASTA input file
    out_file = sys.argv[3] if len(sys.argv) > 3 else "contents.json"

    sequences = fasta_to_sequences(fasta_file)

    data = {
        "copies": copies,
        "proteins": [{"sequence": s} for s in sequences]
    }

    with open(out_file, "w") as f:
        json.dump(data, f, indent=4)

if __name__ == "__main__":
    main()

