#!/bin/bash
#############################################################################################################
# Script Name: sad.sh
# Description: This script is used for SAD.
# Author: ZHANG Xin
# Date Created: 2023-06-01
# Last Modified: 2024-04-17
#############################################################################################################

start_time=$(date +%s)

#Input variables
MTZ_IN=${1}
SEQ=${2}
ATOM=${3}
scr_dir=${4}

#Create folder for molecular replacement
rm -rf SAD
mkdir -p SAD
cd SAD
mkdir SAD_SUMMARY

#Get mtz files folder
if [ "${MTZ_IN}" -eq 1 ]; then
  summary_dir=$(realpath ../INPUT_FILES)
else
  summary_dir=$(realpath ../DATA_REDUCTION/DATA_REDUCTION_SUMMARY)
fi

#Do MR for each file in mtz folder
mtz_files=($(ls "${summary_dir}"/*.mtz))
num_mtz_files=${#mtz_files[@]}

for ((i=1; i<=num_mtz_files; i++)); do
  mtz_file=${mtz_files[$i-1]}
  mkdir -p SAD_$i
  cd SAD_$i
  cp ${mtz_file} .
  
  # Extract wavelength from mtz
  mtzdmp ${mtz_file} > mtzdmp.log
  WAVELENGTH=$(grep -A6 'wavelength' mtzdmp.log | tail -1 | awk '{print $1}')
  echo "Wavelength=${WAVELENGTH}"
  
  pip install gemmi > /dev/null

  # Run in background
  ${scr_dir}/crank2.sh ${mtz_file} ${SEQ} ${ATOM} ${WAVELENGTH} > crank2.log &
  echo "SAD_${i} started in background!"
  cd ..
done

# Wait for all background jobs to finish
wait

echo ""
echo "${num_mtz_files} SAD tasks are completed."
echo ""

#Extract and show SAD results
for (( i=1; i<=num_mtz_files; i++ ))
do
    if [ -f "SAD_$i/crank2.pdb" ]; then
        R_factor=$(grep 'R factor after refinement is' SAD_$i/crank2.log | tail -1 | awk '{print $6}')
        echo "${i} ${R_factor}" >> result.log
    fi
done

if [ ! -f result.log ]; then
    echo "No SAD solution!"
else
    sort -k2,2n result.log > result_sorted.log
    rm result.log
    best=$(awk 'NR==1 {print $1}' result_sorted.log)
    echo "Best SAD result: SAD_${best} R_factor=${R_factor}" | tee -a SAD_SUMMARY/crank2.log
    name=$(find "SAD_${best}" -type f -name "*.mtz" ! -name "crank2.mtz" -exec basename {} \; | sed 's/\.mtz$//' | head -n 1)
    cp SAD_${best}/crank2.log SAD_SUMMARY
    cp SAD_${best}/*.mtz SAD_SUMMARY
    cp SAD_${best}/crank2.pdb SAD_SUMMARY
    cp SAD_SUMMARY/* ../SUMMARY
fi

#Calculate and echo timing information
end_time=$(date +%s)
total_time=$((end_time - start_time))
hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))

echo "" | tee -a SAD_SUMMARY/crank2.log
echo "SAD took: ${hours}h ${minutes}m ${seconds}s" | tee -a SAD_SUMMARY/crank2.log

#Go to data processing folder
cd ..
