#!/bin/bash
#############################################################################################################
# Script Name: mr.sh
# Description: This script is used for molecular replacement.
# Author: ZHANG Xin
# Date Created: 2023-06-01
# Last Modified: 2024-03-05
#############################################################################################################

start_time=$(date +%s)

#Input variables
MTZ_IN=${1}
Z_NUMBER=${2}

#Rename search models
rename_pdb_files() {
  local directory=$1
  if [ -d "$directory" ] && [ "$(ls -A "$directory")" ]; then
    local counter=1
    for file in "$directory"/*.pdb; do
      new_name="$directory/ENSEMBLE${counter}.pdb"
      mv -f "$file" "$new_name" 2>/dev/null || true
      ((counter++))
    done
  fi
}

rename_pdb_files "SEARCH_MODELS/INPUT_MODELS"
rename_pdb_files "SEARCH_MODELS/HOMOLOGS"
rename_pdb_files "SEARCH_MODELS/AF_MODELS"

#Create folder for molecular replacement
rm -rf PHASER_MR
mkdir -p PHASER_MR
cd PHASER_MR
mkdir MR_SUMMARY

echo ""
echo "------------------------------------------Phaser MR------------------------------------------"
echo ""

#Get mtz files folder
if [ "${MTZ_IN}" -eq 1 ]; then
  mtz_dir=$(realpath ../INPUT_FILES)
else
  mtz_dir=$(realpath ../DATA_REDUCTION/DATA_REDUCTION_SUMMARY)
fi

#Do MR for each file in mtz folder
#Determine the number of search models
if [ -d "../SEARCH_MODELS/INPUT_MODELS" ] && [ "$(ls -A ../SEARCH_MODELS/INPUT_MODELS)" ]; then
  TEMPLATE_NUMBER=$(ls ../SEARCH_MODELS/INPUT_MODELS/*.pdb | wc -l)
  ${SOURCE_DIR}/phaser.sh ${TEMPLATE_NUMBER} "${mtz_dir}" ../SEARCH_MODELS/INPUT_MODELS I ${Z_NUMBER}
elif [ -d "../SEARCH_MODELS/HOMOLOGS" ] && [ "$(ls -A ../SEARCH_MODELS/HOMOLOGS)" ]; then
  TEMPLATE_NUMBER_H=$(ls ../SEARCH_MODELS/HOMOLOGS/*.pdb | wc -l)
  TEMPLATE_NUMBER_AF=$(ls ../SEARCH_MODELS/AF_MODELS/*.pdb | wc -l)
  parallel -u ::: "${SOURCE_DIR}/phaser.sh ${TEMPLATE_NUMBER_H} "${mtz_dir}" ../SEARCH_MODELS/HOMOLOGS H ${Z_NUMBER}" "${SOURCE_DIR}/phaser.sh ${TEMPLATE_NUMBER_AF} "${mtz_dir}" ../SEARCH_MODELS/AF_MODELS A ${Z_NUMBER}"
else
  TEMPLATE_NUMBER=$(ls ../SEARCH_MODELS/AF_MODELS/*.pdb | wc -l)
  ${SOURCE_DIR}/phaser.sh ${TEMPLATE_NUMBER} "${mtz_dir}" ../SEARCH_MODELS/AF_MODELS A ${Z_NUMBER}
fi

#Extract and show MR results
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

if [ -s "MR_SUMMARY/MR_SUMMARY.txt" ]; then
  sort -k2,2nr "MR_SUMMARY/MR_SUMMARY.txt" | awk '
  {
    if (!($3 in seen)) {
        print $0
        seen[$3] = 1
    }
  }
  ' > MR_SUMMARY/MR_BEST.txt
  echo ""
  echo "MR Results:"
  awk '{print $1, "LLG="$2, "TFZ="$5, "Space Group: "$3}' MR_SUMMARY/MR_BEST.txt
  #!/bin/bash
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

#Calculate and echo timing information
end_time=$(date +%s)
total_time=$((end_time - start_time))
hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))

echo "" | tee -a MR_SUMMARY/phaser_mr.log
echo "Molecular replacement took: ${hours}h ${minutes}m ${seconds}s" | tee -a MR_SUMMARY/phaser_mr.log

#Go to data processing folder
cd ..
