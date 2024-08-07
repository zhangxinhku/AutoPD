#!/bin/bash
#############################################################################################################
# Script Name: buccaneer.sh
# Description: This script is used for Buccaneer.
# Author: ZHANG Xin
# Date Created: 2023-06-01
# Last Modified: 2024-03-05
#############################################################################################################

start_time=$(date +%s)

echo ""
echo "----------------------------------------- Buccaneer -----------------------------------------"
echo ""

#Input variables
SEQUENCE=$(readlink -f "${1}")
scr_dir=${2}

#Create folder for Buccaneer
mkdir -p BUCCANEER
cd BUCCANEER
mkdir -p BUCCANEER_SUMMARY

#Determine the number of Buccaneer tasks
pdb_count=$(find ../PHASER_MR -mindepth 1 -maxdepth 1 -type d | wc -l | awk '{print $1-1}')

#Perform Buccaneer jobs for every MR solutions
for (( i=1; i<=pdb_count; i++ ))
do
    mkdir -p BUCCANEER_${i}
    cd BUCCANEER_${i}

    if [ ! -f "../../PHASER_MR/MR_SUMMARY/Phaser_${i}.pdb" ]; then
        echo "Phaser_${i}.pdb does not exist, skipping..."
        cd ..
        continue
    fi
    
    PDB=$(readlink -f "../../PHASER_MR/MR_SUMMARY/Phaser_${i}.pdb")
    
    if [ -f "../../PHASER_MR/MR_SUMMARY/Phaser_${i}.mtz" ]; then
        MTZ=$(readlink -f "../../PHASER_MR/MR_SUMMARY/Phaser_${i}.mtz")
    elif [ -d "../../DATA_REDUCTION" ] && find ../../DATA_REDUCTION -type f -name '*.mtz' | read -r; then
        summary_dir=$(realpath ../../DATA_REDUCTION/DATA_REDUCTION_SUMMARY)
        mtz_files=($(ls "${summary_dir}"/*.mtz))
        MTZ=${mtz_files[$i-1]}
    else
        mtz_file=$(find "../../INPUT_FILES" -name '*.mtz' -print -quit)
        MTZ=$(readlink -f "$mtz_file")
    fi
    
    ${scr_dir}/i2_buccaneer.sh ${MTZ} ${PDB} ${SEQUENCE} &

    cd ..
    echo "Buccaneer ${i} started in background!"
done

wait

echo "All Buccaneer processes finished!"
echo ""

#Determine the best Buccaneer result by Rfree
best_r_free=99999
best_i=0

for i in $(seq 1 $pdb_count); do
  grep 'R-work:' "BUCCANEER_$i/BUCCANEER.log" 2>/dev/null | sort -k4,4n | head -1 
  r_free=$(grep 'R-work:' "BUCCANEER_$i/BUCCANEER.log" 2>/dev/null | sort -k4,4n | head -1 | awk '{print $4}')
  r_free=${r_free:-99999}
  
  if (( $(echo "$r_free < $best_r_free" | bc -l) )); then
    best_r_free=$r_free
    best_i=$i
  fi
done

#Output Buccaneer results
if [ $best_i -ne 0 ]; then
  cp "BUCCANEER_${best_i}/BUCCANEER.log" BUCCANEER_SUMMARY/
  cp "BUCCANEER_${best_i}/XYZOUT.pdb" BUCCANEER_SUMMARY/BUCCANEER.pdb
  cp "BUCCANEER_${best_i}/FPHIOUT.mtz" BUCCANEER_SUMMARY/BUCCANEER.mtz
  echo "Best R-free $best_r_free is from BUCCANEER ${best_i}" | tee -a BUCCANEER_SUMMARY/BUCCANEER.log
else
  echo "No valid R-free values found."
fi

#Calculate and echo timing information
end_time=$(date +%s)
total_time=$((end_time - start_time))
hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))

echo "" | tee -a BUCCANEER_SUMMARY/BUCCANEER.log
echo "Buccaneer took: ${hours}h ${minutes}m ${seconds}s" | tee -a BUCCANEER_SUMMARY/BUCCANEER.log

#Go to data processing folder
cd ..
