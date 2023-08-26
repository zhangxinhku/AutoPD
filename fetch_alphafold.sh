#!/bin/bash

start_time=$(date +%s)

scr_dir=${1}
seq_count=${2}

cd ALPHAFOLD_MODEL

# Find all fasta files in current directory
fasta_files=$(ls *.fasta)

# Convert list of files to array
readarray -t fasta_array <<<"$fasta_files"

# Get the first $seq_count files
files_to_process=("${fasta_array[@]:0:$seq_count}")

# Use parallel to execute the python script
printf '%s\n' "${files_to_process[@]}" | parallel -j "$seq_count" --joblog run.log "python ${scr_dir}/uniprot_alphafold.py {}"

i=1
# Loop through each .pdb file
for pdb_file in *.pdb; do
# Copy the file to the destination directory with the new name
mv "${pdb_file}" "ENSEMBLE${i}.pdb"
# Increment counter
((i++))
done 

mv ../FETCH_ALPHAFOLD.log .
cd ..
end_time=$(date +%s)
total_time=$((end_time - start_time))

hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))
echo "Model retrieval took: ${hours}h ${minutes}m ${seconds}s" 
echo ""
