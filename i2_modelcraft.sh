#!/bin/bash
#############################################################################################################
# Script Name: i2_buccaneer.sh
# Description: Wrapper script for automated model building in CCP4i2 using ModelCraft (successor to Buccaneer).
#
# Workflow:
#   1. Validate inputs: MTZ file, PDB file, and sequence file (provided via $SEQUENCE env var).
#   2. Run CCP4i2 ModelCraft with the given diffraction data (MTZ), sequence (FASTA), and initial model (PDB).
#   3. Save run output to MODELCRAFT.log.
#   4. Warn the user if errors are detected in the log.
#
# Usage:
#   ./i2_buccaneer.sh <MTZ file> <PDB file>
#
# Inputs:
#   - MTZ : Diffraction data file (must contain F, SIGF, and FreeR_flag labels).
#   - PDB : Initial MR model (e.g., from Phaser or refinement).
#   - SEQUENCE : Environment variable containing path to FASTA sequence file.
#
# Outputs:
#   - MODELCRAFT.log : Log of the ModelCraft run.
#
# Requirements:
#   - CCP4i2 installation with 'modelcraft' command available in PATH.
#   - Valid sequence file set via $SEQUENCE environment variable.
#
# Notes:
#   - ModelCraft integrates Buccaneer and other building/refinement steps, providing improved performance and
#     automation over standalone Buccaneer.
#   - If errors are found in MODELCRAFT.log, check CCP4i2 environment setup and input data integrity.
#
# Author: ZHANG Xin
# Date Created: 2023-06-01
# Last Modified: 2025-08-10

# Input variables
MTZ=$(readlink -f "${1}")
PDB=$(readlink -f "${2}")
MTZ_DIR=$(dirname "$MTZ")

if [[ -z "${SEQUENCE}" ]]; then
    echo "Error: SEQUENCE not set. Please provide FASTA file."
    exit 1
fi

if [[ ! -f "${MTZ}" ]] || [[ ! -f "${PDB}" ]]; then
    echo "Error: MTZ or PDB file not found."
    exit 1
fi

Z_NUMBER=$(tail -1 $MTZ_DIR/phaser_cca.log | cut -d= -f2)

python3 ${SOURCE_DIR}/make_contents.py $Z_NUMBER ${SEQUENCE} contents.json

# Run Modelcraft with CCP4i2 wrapper
modelcraft xray \
  --data ${MTZ} \
  --observations F,SIGF \
  --freerflag FreeR_flag \
  --contents contents.json \
  --model ${PDB} \
  > MODELCRAFT.log
  
cd modelcraft
phenix.cif_as_pdb modelcraft.cif > /dev/null 2>&1
cd ..
	
if grep -q "Error" MODELCRAFT.log; then
   echo "Warning: Buccaneer encountered errors. Check BUCCANEER.log."
fi

