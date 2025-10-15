#!/bin/bash
#############################################################################################################
# Script Name: mr.sh
# Description: This script performs Molecular Replacement (MR) using Phaser with multiple sets of 
#              potential search models (input models, homologous models, AlphaFold models). 
#              It automatically selects the best MR solutions based on LLG/TFZ scores, 
#              performs refinement, and records summary statistics (R-work, R-free).
#
# Workflow:
#   1. Standardize and rename input search models into ENSEMBLE#.pdb format.
#   2. Create a working directory (PHASER_MR).
#   3. Run Phaser MR with:
#        - Input models (if provided), otherwise
#        - Homologous models and AlphaFold models (in parallel), otherwise
#        - AlphaFold models only.
#   4. Parse MR solutions and extract:
#        - Log-Likelihood Gain (LLG)
#        - Translation Function Z-score (TFZ)
#        - Space group and point group
#   5. Select best MR results:
#        - Prefer TFZ ≥ 8 (statistically significant)
#        - At most one solution per space group
#   6. Refine the best MR solutions with REFMAC/Phenix (via refine.sh).
#   7. Append refinement results (R-work and R-free) to MR summary.
#   8. Save outputs in PHASER_MR/MR_SUMMARY.
#
# Usage:
#   ./mr.sh <MTZ_IN>
#
# Arguments:
#   MTZ_IN   Integer flag
#            - 1: An experimental MTZ file was provided (skip data reduction).
#            - 0: Use MTZ from data reduction results.
#
# Outputs:
#   - PHASER_MR/MR_SUMMARY/MR_BEST.txt : Best MR solutions with LLG, TFZ, SG, PG, R-work, R-free
#   - PHASER_MR/MR_SUMMARY/phaser_mr.log : Execution log with timing info
#   - PHASER_MR/<run_folder>/PHASER.1.pdb : Best MR model
#   - PHASER_MR/<run_folder>/REFINEMENT/XYZOUT.pdb : Refined structure
#
# Dependencies:
#   - CCP4 (Phaser, REFMAC)
#   - GNU Parallel
#   - awk, grep, bc, sort, timeout
#
# Author: ZHANG Xin
# Date Created: 2023-06-01
# Last Modified: 2025-08-03
#############################################################################################################


start_time=$(date +%s)

# Input flag: determines whether to use provided MTZ or reduced MTZ
MTZ_IN=${1}

# ----------------------------------------
# Function: Standardize search model naming
# Rename .pdb files sequentially as ENSEMBLE1.pdb, ENSEMBLE2.pdb, etc.
# ----------------------------------------
rename_pdb_files() {
  local directory=$1
  if [ -d "$directory" ] && [ "$(ls -A "$directory")" ]; then
    local counter=1
    for file in $(ls "$directory"/*.pdb | sort -V); do
      new_name="$directory/ENSEMBLE${counter}.pdb"
      mv -f "$file" "$new_name" 2>/dev/null || true
      ((counter++))
    done
  fi
}

rename_pdb_files "SEARCH_MODELS/INPUT_MODELS"
rename_pdb_files "SEARCH_MODELS/HOMOLOGS"
rename_pdb_files "SEARCH_MODELS/AF_MODELS"

# ----------------------------------------
# Create working directory for Phaser MR
# ----------------------------------------
rm -rf PHASER_MR
mkdir -p PHASER_MR
cd PHASER_MR
mkdir MR_SUMMARY

echo ""
echo "------------------------------------------Phaser MR------------------------------------------"
echo ""

# ----------------------------------------
# Determine source of MTZ input
# ----------------------------------------
if [ "${MTZ_IN}" -eq 1 ]; then
  mtz_dir=$(realpath ../INPUT_FILES)
else
  mtz_dir=$(realpath ../DATA_REDUCTION/DATA_REDUCTION_SUMMARY)
fi

# ----------------------------------------
# Run Phaser MR with available models
# ----------------------------------------
if [ -d "../SEARCH_MODELS/INPUT_MODELS" ] && [ "$(ls -A ../SEARCH_MODELS/INPUT_MODELS)" ]; then
  TEMPLATE_NUMBER=$(ls ../SEARCH_MODELS/INPUT_MODELS/*.pdb | wc -l)
  timeout 600h ${SOURCE_DIR}/phaser.sh ${TEMPLATE_NUMBER} ${mtz_dir} ../SEARCH_MODELS/INPUT_MODELS I
elif [ -d "../SEARCH_MODELS/HOMOLOGS" ] && [ "$(ls -A ../SEARCH_MODELS/HOMOLOGS)" ]; then
  TEMPLATE_NUMBER_H=$(ls ../SEARCH_MODELS/HOMOLOGS/*.pdb | wc -l)
  TEMPLATE_NUMBER_AF=$(ls ../SEARCH_MODELS/AF_MODELS/*.pdb | wc -l)
  parallel -u ::: \
    "timeout 600h ${SOURCE_DIR}/phaser.sh ${TEMPLATE_NUMBER_H} ${mtz_dir} ../SEARCH_MODELS/HOMOLOGS H" \
    "timeout 600h ${SOURCE_DIR}/phaser.sh ${TEMPLATE_NUMBER_AF} ${mtz_dir} ../SEARCH_MODELS/AF_MODELS A"
else
  TEMPLATE_NUMBER=$(ls ../SEARCH_MODELS/AF_MODELS/*.pdb | wc -l)
  timeout 600h ${SOURCE_DIR}/phaser.sh ${TEMPLATE_NUMBER} ${mtz_dir} ../SEARCH_MODELS/AF_MODELS A
fi

# ----------------------------------------
# Extract MR results: LLG, TFZ, Space Group, Point Group
# ----------------------------------------
> MR_SUMMARY/MR_SUMMARY.txt
for dir in ./*/; do
  folder_name=$(basename "$dir")
  if [ -f "$folder_name/PHASER.1.pdb" ]; then
    LLG=$(head -n 5 "$folder_name/PHASER.sol" | grep -o 'LLG=[0-9]*' | sed 's/LLG=//g' | sort -nr | head -n 1)
    TFZ=$(head -n 5 "$folder_name/PHASER.sol" | grep -o 'TFZ==\?[0-9]*\(\.[0-9]*\)\?' | sed 's/TFZ==\?//g' | sort -nr | head -n 1)
    SG=$(grep -m 1 "SOLU SPAC" "$folder_name/PHASER.sol" | awk '{print $3, $4, $5, $6}' | tr -d ' ')
    PG=$(${SOURCE_DIR}/sg2pg.sh ${SG})
    echo "$folder_name $LLG $SG $PG $TFZ" >> MR_SUMMARY/MR_SUMMARY.txt
  fi
done

# ----------------------------------------
# Select best MR solutions
# Prefer TFZ ≥ 8; one solution per space group
# ----------------------------------------
if [ -s "MR_SUMMARY/MR_SUMMARY.txt" ]; then
  if awk '$5 >= 8 { exit 1 }' "MR_SUMMARY/MR_SUMMARY.txt"; then
    cat "MR_SUMMARY/MR_SUMMARY.txt"
  else
    awk '$5 >= 8' "MR_SUMMARY/MR_SUMMARY.txt"
  fi | sort -k5,5nr | awk '
    {
      if (!($3 in seen)) {
        print $0
        seen[$3] = 1
      }
    }' > MR_SUMMARY/MR_BEST.txt
  echo ""
  echo "MR Results:"
  awk '{print $1, "LLG="$2, "TFZ="$5, "Space Group: "$3}' MR_SUMMARY/MR_BEST.txt
  
  # ----------------------------------------
  # Refine best MR solutions
  # ----------------------------------------
  awk '{print $1}' "MR_SUMMARY/MR_BEST.txt" | while read -r folder_name; do
    PDB=$(readlink -f "$folder_name/PHASER.1.pdb")
    if [ -f "$folder_name/PHASER.1.mtz" ]; then
        MTZ=$(readlink -f "$folder_name/PHASER.1.mtz")
    else
        MTZ=$(find "$folder_name" -name "*.mtz" -print -quit | xargs realpath)
    fi

    cd "$folder_name" || exit
    ${SOURCE_DIR}/refine.sh "${MTZ}" "${PDB}"
    cd ..

    r_work="N/A"
    r_free="N/A"
    if [ -f "$folder_name/REFINEMENT/XYZOUT.pdb" ]; then
        r_work=$(grep 'R VALUE            (WORKING SET) :' "$folder_name/REFINEMENT/XYZOUT.pdb" 2>/dev/null | cut -d ':' -f 2 | xargs)
        r_free=$(grep 'FREE R VALUE                     :' "$folder_name/REFINEMENT/XYZOUT.pdb" 2>/dev/null | cut -d ':' -f 2 | xargs)
    fi
    
    cp -r "$folder_name" "MR_SUMMARY/"

    awk -v folder="$folder_name" -v r_work="$r_work" -v r_free="$r_free" '
    $1 == folder {print $0, r_work, r_free; next} {print}
    ' MR_SUMMARY/MR_BEST.txt > MR_SUMMARY/MR_BEST.tmp && mv MR_SUMMARY/MR_BEST.tmp MR_SUMMARY/MR_BEST.txt
  done
else
  echo "No MR solution!"
fi

# ----------------------------------------
# Report timing
# ----------------------------------------
end_time=$(date +%s)
total_time=$((end_time - start_time))
hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))

echo "" | tee -a MR_SUMMARY/phaser_mr.log
echo "Molecular replacement took: ${hours}h ${minutes}m ${seconds}s" | tee -a MR_SUMMARY/phaser_mr.log

# Go to data processing folder
cd ..
