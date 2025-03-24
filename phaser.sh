#!/bin/bash 
#Input variables
TEMPLATE_NUMBER=${1}
MTZ_DIR=${2}
ENSEMBLE_PATH=$(readlink -f "${3}")
FLAG=${4}

mtz_files=($(ls "${MTZ_DIR}"/*.mtz))  
num_mtz_files=${#mtz_files[@]}

solution_num=0

for ((i=1; i<=num_mtz_files; i++)); do
  mtz_file=${mtz_files[$i-1]}
  ${SOURCE_DIR}/ipcas_mtz.sh ${mtz_file} ${mtz_file} FP SIGFP FreeR_flag F SIGF FreeR_flag > /dev/null 2>&1
  mkdir -p MR_${FLAG}_$i
  cd MR_${FLAG}_$i
  cp ${mtz_file} .
  
  if [[ -z "${Z_INPUT}" ]]; then
    phenix.xtriage ${mtz_file} ${SEQUENCE} obs_labels='F,SIGF' > xtriage.log
    #Extract NUMBER from phenix.xtriage result
    Z_NUMBER=$(grep 'Best guess :' xtriage.log | awk '{print $4}')
    Z_NUMBER=${Z_NUMBER:-1}
    echo "MR_${FLAG}_$i Most probable Z=${Z_NUMBER}"
  else
    echo "Input Z=${Z_INPUT}"
    Z_NUMBER=${Z_INPUT}
  fi

  echo "TITLE phaser_mr
MODE MR_AUTO
ROOT PHASER
HKLIN ${mtz_file}
LABIN F=F SIGF=SIGF
SGALTERNATIVE SELECT ALL" > phaser_input.txt

  for ((j=1; j<=${TEMPLATE_NUMBER}; j++)); do
    first_line=$(head -n 1 ${ENSEMBLE_PATH}/ENSEMBLE${j}.pdb)
    
    if [[ $first_line == *ID* ]]; then
      IDENTITY=$(echo "$first_line" | awk -F 'ID ' '{print $2}')
    else
      IDENTITY=90
    fi
    echo "ENSEMBLE ensemble${j} PDB ${ENSEMBLE_PATH}/ENSEMBLE${j}.pdb IDENTITY ${IDENTITY}" >> phaser_input.txt
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
wait 
