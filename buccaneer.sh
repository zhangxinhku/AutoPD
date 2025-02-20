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

#Create folder for Buccaneer
mkdir -p BUCCANEER
cd BUCCANEER
mkdir -p BUCCANEER_SUMMARY

start_dir=$(pwd)
for folder in ../PHASER_MR/MR_SUMMARY/*; do
  if [ -d "$folder" ]; then
    folder_path=$(realpath "$folder")
    folder_name=$(basename "$folder")
    mkdir -p "BUCCANEER_${folder_name}"
    cd "BUCCANEER_${folder_name}" || exit
    
    if [ -f "${folder_path}/REFINEMENT/XYZOUT.pdb" ]; then
        PDB=$(readlink -f "${folder_path}/REFINEMENT/XYZOUT.pdb")
    else
        PDB=$(readlink -f "${folder_path}/PHASER.1.pdb")
    fi
    
    if [ -f "${folder_path}/PHASER.1.mtz" ]; then
        MTZ=$(readlink -f "${folder_path}/PHASER.1.mtz")
    else
        MTZ=$(find ${folder_path} -maxdepth 1 -name "*.mtz" -print -quit)
    fi
    
    ${SOURCE_DIR}/i2_buccaneer.sh ${MTZ} ${PDB} &
    cd "$start_dir" || exit
  fi
done

wait
echo "All Buccaneer processes finished!"
echo ""

cd "$start_dir" || exit
best_r_free=99999

for folder in BUCCANEER_MR*; do
  if [ -d "$folder" ]; then
    folder_name=$(basename "$folder")
    r_work=$(grep 'R VALUE            (WORKING SET) :' "$folder_name/XYZOUT.pdb" 2>/dev/null | cut -d ':' -f 2 | xargs)
    r_free=$(grep 'FREE R VALUE                     :' "$folder_name/XYZOUT.pdb" 2>/dev/null | cut -d ':' -f 2 | xargs)
    echo "$folder_name: R-work=$r_work  R-free=$r_free"
    r_free=${r_free:-99999}
  
    if (( $(echo "$r_free < $best_r_free" | bc -l) )); then
      best_r_free=$r_free
      best="${folder_name#*_}"
    fi
  fi
done

#Output Buccaneer results
if [ -n "$best" ]; then
  cp "BUCCANEER_${best}/BUCCANEER.log" BUCCANEER_SUMMARY/
  cp "BUCCANEER_${best}/XYZOUT.pdb" BUCCANEER_SUMMARY/BUCCANEER.pdb
  cp "BUCCANEER_${best}/FPHIOUT.mtz" BUCCANEER_SUMMARY/BUCCANEER.mtz
  echo "Best R-free $best_r_free is from BUCCANEER_${best}" | tee -a BUCCANEER_SUMMARY/BUCCANEER.log
  cp BUCCANEER_SUMMARY/* ../SUMMARY/
  cp ../PHASER_MR/MR_SUMMARY/${best}/*.* ../SUMMARY/
  cp ../PHASER_MR/MR_SUMMARY/${best}/REFINEMENT/XYZOUT.pdb ../SUMMARY/REFINEMENT.pdb
  cp ../PHASER_MR/MR_SUMMARY/${best}/REFINEMENT/FPHIOUT.mtz ../SUMMARY/REFINEMENT.mtz
    
  if [ -d "../DATA_REDUCTION" ]; then
    dr_name=$(find "../PHASER_MR/MR_SUMMARY/${best}" -maxdepth 1 -type f -name "*.mtz" ! -name "PHASER.1.mtz" -exec basename {} \; | sed 's/\.mtz$//' | head -n 1)
    cp ../DATA_REDUCTION/DATA_REDUCTION_SUMMARY/${dr_name}_SUMMARY.log ../SUMMARY/
  fi
    
  if [[ "$best" == MR_A* ]]; then
    cp ../SEARCH_MODELS/AF_MODELS/* ../SUMMARY/
  elif [[ "$best" == MR_H* ]]; then
    cp ../SEARCH_MODELS/HOMOLOGS/* ../SUMMARY/
  else
    cp ../SEARCH_MODELS/INPUT_MODELS/* ../SUMMARY/
  fi
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
