from Bio.Blast import NCBIWWW
from Bio.Blast import NCBIXML
import requests
import json
import sys
import os

def get_uniprot_id(sequence, filename):
    # Perform BLAST search, send the sequence to NCBI server
    result_handle = NCBIWWW.qblast("blastp", "swissprot", sequence)

    # Parse BLAST search result
    blast_record = NCBIXML.read(result_handle)
    result_handle.close()

    # If no alignments were found, raise an exception
    if not blast_record.alignments:
        raise ValueError(f"No UniProt ID found for the sequence in {filename}.")
    
    # Get the first matching UniProt ID
    hit = blast_record.alignments[0].accession

    return hit

try:
    # Get the sequence file name from command line arguments
    sequence_file = sys.argv[1]

    # Read the first line from the input file to get the sequence
    with open(sequence_file, 'r') as file:
        next(file)  # Skip the first line
        sequence = file.readline().strip()
        
    # Print the sequence file name and sequence
    print("")
    print(f"Sequence file name: {sequence_file}\nSequence: {sequence}")

    # Get UniProt ID
    uniprot_id = get_uniprot_id(sequence, sequence_file)

    print("UniProt ID:", uniprot_id)

    URL = f"https://alphafold.ebi.ac.uk/api/prediction/{uniprot_id}"

    response = requests.get(URL, headers={"accept": "application/json"})
    if response.status_code == 200:
        data = json.loads(response.text)
        pdb_url = data[0]["pdbUrl"]
       
        pdb_response = requests.get(pdb_url)
        if pdb_response.status_code == 200:
            pdb_filename = f"{os.path.splitext(sequence_file)[0]}.pdb"
            with open(pdb_filename, 'wb') as file:
                file.write(pdb_response.content)
            print(f"Model for {sequence_file} downloaded successfully!")
        else:
            print("Unable to download model for {sequence_file}!")
    else:
        print("API request failed!")
    print("")

except ValueError as error:
    print(error)
    sys.exit(1)
