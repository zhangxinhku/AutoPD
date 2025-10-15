#!/bin/bash
#############################################################################################################
# Script Name: sad.sh
# Description: This script performs Single-wavelength Anomalous Dispersion (SAD) phasing using Crank2.
#              It supports both experimental MTZ files and internally generated MTZ files from data reduction.
#              For each MTZ file, the script extracts the wavelength, runs Crank2 in parallel, 
#              and collects the best SAD solution based on R-factor.
#
# Usage:
#   ./sad.sh <MTZ_IN>
#
# Arguments:
#   MTZ_IN: 
#     1  -> Use experimental MTZ from INPUT_FILES
#     0  -> Use MTZ files from DATA_REDUCTION results (DATA_REDUCTION_SUMMARY or SAD_INPUT)
#
# Input:
#   - MTZ files (experimental or data reduction results)
#   - Protein sequence file ($SEQUENCE, passed via environment)
#   - Heavy atom type ($ATOM, e.g. Se, S)
#
# Output:
#   - SAD/SAD_SUMMARY/: Log files, MTZ, and final PDB from best solution
#   - SUMMARY/: Copy of best MTZ/PDB/log for pipeline integration
#
# Dependencies:
#   - CCP4 (for mtzdmp)
#   - Crank2
#   - gemmi (Python package, installed if missing)
#
# Author: ZHANG Xin
# Date Created: 2023-06-01
# Last Modified: 2024-04-17
#############################################################################################################

start_time=$(date +%s)

# Input variables
MTZ_IN=${1}

# Initialize SAD working directory
rm -rf SAD
mkdir -p SAD
cd SAD
mkdir SAD_SUMMARY

# Determine which MTZ directory to use
if [ "${MTZ_IN}" -eq 1 ]; then
  summary_dir=$(realpath ../INPUT_FILES)
elif find "../DATA_REDUCTION/SAD_INPUT" -maxdepth 1 -type f -size +0 | grep -q .; then
  summary_dir=$(realpath ../DATA_REDUCTION/SAD_INPUT)
else
  summary_dir=$(realpath ../DATA_REDUCTION/DATA_REDUCTION_SUMMARY)
fi

# Collect MTZ files
mtz_files=($(ls "${summary_dir}"/*.mtz))
num_mtz_files=${#mtz_files[@]}

# Launch SAD phasing for each MTZ file
for ((i=1; i<=num_mtz_files; i++)); do
  mtz_file=${mtz_files[$i-1]}
  mkdir -p SAD_$i
  cd SAD_$i
  cp ${mtz_file} .
  
  # Extract wavelength from MTZ file header
  mtzdmp ${mtz_file} > mtzdmp.log
  WAVELENGTH=$(grep -A6 'wavelength' mtzdmp.log | tail -1 | awk '{print $1}')
  echo "Wavelength=${WAVELENGTH}"
  
  # Extract wavelength from MTZ file header
  pip install gemmi > /dev/null

  # Run Crank2 in background
  ${SOURCE_DIR}/crank2.sh ${mtz_file} ${SEQUENCE} ${ATOM} ${WAVELENGTH} > crank2.log &
  echo "SAD_${i} started in background!"
  cd ..
done

# Wait for all background jobs to finish
wait

echo ""
echo "${num_mtz_files} SAD tasks are completed."
echo ""

# Extract SAD results and rank solutions by R-factor
for (( i=1; i<=num_mtz_files; i++ ))
do
    if [ -f "SAD_$i/crank2.pdb" ]; then
        R_factor=$(grep 'R VALUE            (WORKING SET) :' SAD_$i/crank2.pdb | cut -d ':' -f 2 | xargs)
        echo "${i} ${R_factor}" >> result.log
    fi
done

# If no solutions were found
if [ ! -f result.log ]; then
    echo "No SAD solution!"
else
    # Select the best solution
    sort -k2,2n result.log > result_sorted.log
    rm result.log
    best=$(awk 'NR==1 {print $1}' result_sorted.log)
    best_r=$(awk 'NR==1 {print $2}' result_sorted.log)
    echo "Best SAD result: SAD_${best} R_factor=${best_r}" | tee -a SAD_SUMMARY/crank2.log
    name=$(find "SAD_${best}" -type f -name "*.mtz" ! -name "crank2.mtz" -exec basename {} \; | sed 's/\.mtz$//' | head -n 1)
    
    # Copy results from best SAD run
    cp SAD_${best}/crank2.log SAD_SUMMARY
    cp SAD_${best}/*.mtz SAD_SUMMARY
    cp SAD_${best}/crank2.pdb SAD_SUMMARY
    cp SAD_SUMMARY/* ../SUMMARY
fi

# Timing information
end_time=$(date +%s)
total_time=$((end_time - start_time))
hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))

echo "" | tee -a SAD_SUMMARY/crank2.log
echo "SAD took: ${hours}h ${minutes}m ${seconds}s" | tee -a SAD_SUMMARY/crank2.log
echo ""

# Go to data processing folder
cd ..
