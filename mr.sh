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

#Determine the number of search models
TEMPLATE_NUMBER=$(ls SEARCH_MODELS/*.pdb | wc -l)

#Rename search models
counter=1
for file in SEARCH_MODELS/*.pdb; do
    new_name="SEARCH_MODELS/ENSEMBLE${counter}.pdb"
    mv -f "$file" "$new_name" 2>/dev/null || true
    let counter+=1
done

echo ""
echo "MR template number: ${TEMPLATE_NUMBER}"

#Create folder for molecular replacement
rm -rf PHASER_MR
mkdir -p PHASER_MR
cd PHASER_MR
mkdir MR_SUMMARY

echo "------------------------------------------Phaser MR------------------------------------------"
echo ""

#Get mtz files folder
if [ "${MTZ_IN}" -eq 1 ]; then
  summary_dir=$(realpath ../INPUT_FILES)
else
  summary_dir=$(realpath ../DATA_REDUCTION/DATA_REDUCTION_SUMMARY)
fi

#Do MR for each file in mtz folder
mtz_files=($(ls "${summary_dir}"/*.mtz))
num_mtz_files=${#mtz_files[@]}

solution_num=0

for ((i=1; i<=num_mtz_files; i++)); do
  mtz_file=${mtz_files[$i-1]}
  mkdir -p MR_$i
  cd MR_$i
  cp ${mtz_file} .
  
  if [[ -z "${Z_NUMBER}" ]]; then
    #phaser_cca
    phaser << eof > phaser_cca.log
    TITLE phaser_cca
    MODE CCA
    ROOT PHASER_CCA
    HKLIN ${mtz_file}
    LABIN F=F SIGF=SIGF
    COMPOSITION BY ASU
    COMPOSITION PROTEIN SEQ ${SEQUENCE} NUM 1
eof

    #Extract NUMBER from phaser_cca result
    CCA_EXIT_STATUS=$(grep 'EXIT STATUS:' phaser_cca.log | awk '{print $3}')

    Z_NUMBER=$(awk '/loggraph/{flag=1;next}/\$\$/{flag=0}flag' phaser_cca.log | sort -k2,2nr | head -n 1 | awk '{print $1}')

    echo ""
    echo "MR_$i Phaser CCA EXIT STATUS: ${CCA_EXIT_STATUS}"
    
    if [ ${CCA_EXIT_STATUS} == "FAILURE" ]; then
      exit 1
    else
      echo "MR_$i Most probable Z=${Z_NUMBER}"
      echo ""
    fi
  else
    echo "Input Z=${Z_NUMBER}"
  fi

  echo "TITLE phaser_mr
MODE MR_AUTO
ROOT PHASER
HKLIN ${mtz_file}
LABIN F=F SIGF=SIGF
SGALTERNATIVE SELECT ALL" > phaser_input.txt

  for ((j=1; j<=${TEMPLATE_NUMBER}; j++)); do
    first_line=$(head -n 1 ../../SEARCH_MODELS/ENSEMBLE${j}.pdb)
    
    if [[ $first_line == *ID* ]]; then
      IDENTITY=$(echo "$first_line" | awk -F 'ID ' '{print $2}')
    else
      IDENTITY=90
    fi
    echo "ENSEMBLE ensemble${j} PDB ../../SEARCH_MODELS/ENSEMBLE${j}.pdb IDENTITY ${IDENTITY}" >> phaser_input.txt
  done

  echo "COMPOSITION BY ASU" >> phaser_input.txt
  echo "COMPOSITION PROTEIN SEQ ${SEQUENCE} NUM ${Z_NUMBER}" >> phaser_input.txt

  for ((j=1; j<=TEMPLATE_NUMBER; j++)); do
    echo "SEARCH ENSEMBLE ensemble${j} NUM ${Z_NUMBER}" >> phaser_input.txt
  done

  phaser < phaser_input.txt > phaser_mr.log &

  cd ..
  Z_NUMBER=""
done
#IDENTITY ${IDENTITY}
wait 

echo ""
echo "${num_mtz_files} Phaser tasks are completed."
echo ""

#Extract and show MR results
for (( i=1; i<=num_mtz_files; i++ ))
do
    if [ -f "MR_$i/PHASER.1.pdb" ]; then
        ((solution_num++))
        cp "MR_$i/phaser_cca.log" "MR_SUMMARY/phaser_cca_${i}.log"
        cp "MR_$i/PHASER.1.pdb" "MR_SUMMARY/Phaser_${i}.pdb"
        cp "MR_$i/PHASER.1.mtz" "MR_SUMMARY/Phaser_${i}.mtz" 2>/dev/null
        cp "MR_$i/phaser_mr.log" "MR_SUMMARY/phaser_mr_${i}.log"
        MR_EXIT_STATUS=$(grep 'EXIT STATUS:' MR_$i/phaser_mr.log | awk '{print $3}')
	echo "MR_$i Phaser MR EXIT STATUS: ${MR_EXIT_STATUS}"
    fi
done

if [ $solution_num -eq 0 ]; then
    echo "No MR solution!"
fi

#Calculate and echo timing information
end_time=$(date +%s)
total_time=$((end_time - start_time))
hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))

echo "" | tee -a phaser_mr.log
echo "Molecular replacement took: ${hours}h ${minutes}m ${seconds}s" | tee -a phaser_mr.log

mv phaser_mr.log MR_SUMMARY/

#Go to data processing folder
cd ..
