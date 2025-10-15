#!/bin/bash 
#############################################################################################################
# Script Name: phaser.sh
# Description: This script runs Phaser for Molecular Replacement (MR) using a set of 
#              template search models (ENSEMBLE#.pdb). For each MTZ file in the input directory,
#              it estimates the number of copies in the asymmetric unit (Z) using Phenix Xtriage 
#              (unless Z is provided), prepares input files for Phaser, and executes MR in parallel.
#
# Workflow:
#   1. Parse arguments: number of templates, MTZ directory, ensemble path, and model type flag.
#   2. Iterate over each MTZ file in MTZ_DIR.
#   3. For each MTZ:
#        - Convert MTZ to Phaser-compatible format with ipcas_mtz.sh.
#        - Estimate Z (number of molecules in the ASU) via phenix.xtriage, unless Z_INPUT is provided.
#        - Generate Phaser input script (phaser_input.txt):
#             * Input MTZ file
#             * Sequence composition
#             * Template ensemble models
#             * Search parameters (ensembles and Z)
#        - Run Phaser in MR_AUTO mode, outputting logs and solutions.
#   4. Results are stored in MR_<FLAG>_<i> subdirectories.
#
# Usage:
#   ./phaser.sh <TEMPLATE_NUMBER> <MTZ_DIR> <ENSEMBLE_PATH> <FLAG>
#
# Arguments:
#   TEMPLATE_NUMBER   Number of template models (ENSEMBLE#.pdb) to be used.
#   MTZ_DIR           Directory containing MTZ files for MR.
#   ENSEMBLE_PATH     Path to the folder containing ENSEMBLE#.pdb models.
#   FLAG              Identifier for the model type:
#                       - I : Input models
#                       - H : Homologs
#                       - A : AlphaFold models
#
# Inputs:
#   - MTZ files (*.mtz) in MTZ_DIR
#   - Protein sequence file ($SEQUENCE, passed via environment variable)
#   - Search models ENSEMBLE#.pdb in ENSEMBLE_PATH
#
# Outputs:
#   - Subdirectories MR_<FLAG>_<i> for each MTZ
#       * phaser_mr.log   : Log of Phaser run
#       * PHASER.sol      : Phaser solution file
#       * PHASER.1.pdb    : Placed MR model
#
# Dependencies:
#   - CCP4 Phaser
#   - Phenix Xtriage
#   - ipcas_mtz.sh (internal script for MTZ preparation)
#
# Author: ZHANG Xin
# Date Created: 2023-06-01
# Last Modified: 2025-08-03
#############################################################################################################

# Input variables
TEMPLATE_NUMBER=${1}
MTZ_DIR=${2}
ENSEMBLE_PATH=$(readlink -f "${3}")
FLAG=${4}

# Collect all MTZ files
mtz_files=($(ls "${MTZ_DIR}"/*.mtz))  
num_mtz_files=${#mtz_files[@]}

solution_num=0

# Loop through each MTZ file
for ((i=1; i<=num_mtz_files; i++)); do
  mtz_file=${mtz_files[$i-1]}
  
  # Preprocess MTZ file for Phaser
  ${SOURCE_DIR}/ipcas_mtz.sh ${mtz_file} ${mtz_file} FP SIGFP FreeR_flag F SIGF FreeR_flag > /dev/null 2>&1
  
  # Create directory for this MR job
  mkdir -p MR_${FLAG}_$i
  cd MR_${FLAG}_$i
  cp ${mtz_file} .
  
  
  # Determine Z (number of molecules per ASU)
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
  
  # Prepare Phaser input script
  echo "TITLE phaser_mr
MODE MR_AUTO
ROOT PHASER
HKLIN ${mtz_file}
LABIN F=F SIGF=SIGF
SGALTERNATIVE SELECT ALL" > phaser_input.txt

  # Add ensembles to Phaser input
  for ((j=1; j<=${TEMPLATE_NUMBER}; j++)); do
    first_line=$(head -n 1 ${ENSEMBLE_PATH}/ENSEMBLE${j}.pdb)
    
    if [[ $first_line == *ID* ]]; then
      IDENTITY=$(echo "$first_line" | awk -F 'ID ' '{print $2}')
    else
      IDENTITY=90
    fi
    echo "ENSEMBLE ensemble${j} PDB ${ENSEMBLE_PATH}/ENSEMBLE${j}.pdb IDENTITY ${IDENTITY}" >> phaser_input.txt
  done
  
  # Define composition based on sequence and Z
  echo "COMPOSITION BY ASU" >> phaser_input.txt
  echo "COMPOSITION PROTEIN SEQ ${SEQUENCE} NUM ${Z_NUMBER}" >> phaser_input.txt

  # Set search instructions
  for ((j=1; j<=TEMPLATE_NUMBER; j++)); do
    echo "SEARCH ENSEMBLE ensemble${j} NUM ${Z_NUMBER}" >> phaser_input.txt
  done

  phaser < phaser_input.txt > phaser_mr.log &

  cd ..
  Z_NUMBER=""
done

# Wait for all background MR jobs to finish
wait 
