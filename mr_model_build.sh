#!/bin/bash
#############################################################################################################
# Script Name: mr_model_build.sh
# Description: This script performs molecular replacement (MR) followed by automated model building. 
#              The workflow integrates Phaser (MR), ModelCraft, Phenix Autobuild, and IPCAS 2.0.
#              It selects and refines models based on R-free values.
#
# Usage:
#   ./mr_model_build.sh <MTZ_IN>
#
# Arguments:
#   MTZ_IN   Integer flag (0 or 1) 
#            - 1: An experimental MTZ file was provided (skip data reduction).
#            - 0: MTZ will be obtained from data reduction step.
#
# Workflow:
#   1. Run Phaser Molecular Replacement (mr.sh).
#   2. If MR successful:
#        - Perform model building with ModelCraft.
#        - Evaluate ModelCraft R-free value.
#        - If ModelCraft fails or R-free > 0.35, run Phenix Autobuild.
#        - If Autobuild also fails or R-free > 0.35, run IPCAS 2.0 iterative model building.
#   3. Copy best results (MTZ/PDB/logs) into SUMMARY directory for downstream use.
#
# Inputs:
#   - MTZ file (from data reduction or SAD).
#   - FASTA sequence file (environment variable $SEQUENCE).
#   - Initial MR search models (from PHASER).
#
# Outputs:
#   - SUMMARY/PHASER.1.pdb      : Initial MR solution.
#   - SUMMARY/ModelCraft.pdb    : ModelCraft-built model (if available).
#   - SUMMARY/AUTOBUILD.pdb     : Phenix Autobuild model (if available).
#   - SUMMARY/IPCAS.pdb         : IPCAS 2.0 model (if available).
#   - Corresponding MTZ files and logs in SUMMARY/.
#
# Dependencies:
#   - CCP4 (Phaser, ModelCraft, IPCAS)
#   - Phenix (Autobuild)
#   - awk, grep, bc
#
# Author: ZHANG Xin
# Date Created: 2025-03-03
# Last Modified: 2025-08-03
#############################################################################################################

# Input variable: indicates if MTZ is provided
MTZ_IN=${1}

# Step 1: Run Molecular Replacement using Phaser
${SOURCE_DIR}/mr.sh ${MTZ_IN}

# Check if MR was successful
if [ -s "PHASER_MR/MR_SUMMARY/MR_BEST.txt" ]; then
  echo ""
  echo "Refinement Results:"
  awk '{print $1, "R-work="$6, "R-free="$7}' PHASER_MR/MR_SUMMARY/MR_BEST.txt
#  r_free_refine=$(sort -k6,6n "PHASER_MR/MR_SUMMARY/MR_BEST.txt" | awk 'NR==1 {print $7}')
#  r_work=$(sort -k6,6n "PHASER_MR/MR_SUMMARY/MR_BEST.txt" | awk 'NR==1 {print $5}')
else
  exit 1
fi

# Step 2: Model building with ModelCraft
echo ""
echo "============================================================================================="
echo "                                         Model building                                      "
echo "============================================================================================="
echo ""
echo "ModelCraft will be performed."

${SOURCE_DIR}/modelcraft.sh

# Extract R-free values from ModelCraft and Refinement outputs
r_free_modelcraft=$(grep "R-free:" SUMMARY/MODELCRAFT.log | tail -n 1 | awk '{print $2}')
r_free_refine=$(grep 'FREE R VALUE                     :' "SUMMARY/REFINEMENT.pdb" 2>/dev/null | cut -d ':' -f 2 | xargs | grep -Eo '^[0-9.]+' || echo 0)
export r_free_modelcraft r_free_refine

# Select MTZ file for subsequent building
if [ -f "SUMMARY/PHASER.1.mtz" ]; then
  MTZ="SUMMARY/PHASER.1.mtz"
else
  MTZ=$(find SUMMARY -type f -name "*.mtz" ! -name "MODELCRAFT.mtz" ! -name "REFINEMENT.mtz" -print -quit)
fi

# Step 3: Run Phenix Autobuild if ModelCraft failed or insufficient quality
if [ ! -f "SUMMARY/modelcraft.pdb" ] || [ "$(echo "${r_free_modelcraft} > 0.35" | bc)" -eq 1 ] || [ "${MODEL_BUILD}" = "autobuild" ] || [ "${MODEL_BUILD}" = "all" ]; then
    echo ""
    echo "Phenix Autobuild will be performed."
    
    ${SOURCE_DIR}/autobuild.sh ${MTZ}
    
    if [ -f "AUTOBUILD/AUTOBUILD_SUMMARY/AUTOBUILD.pdb" ]; then
        cp AUTOBUILD/AUTOBUILD_SUMMARY/* SUMMARY/
        r_free_autobuild=$(grep 'FREE R VALUE                     :' "AUTOBUILD/AUTOBUILD_SUMMARY/AUTOBUILD.pdb" 2>/dev/null | cut -d ':' -f 2 | xargs)
    else
        echo "AUTOBUILD.pdb does not exist."
    fi
    
    # Step 4: Run IPCAS 2.0 if Autobuild also fails or insufficient quality       
    if [ ! -f "SUMMARY/AUTOBUILD.pdb" ] || [ "$(echo "${r_free_autobuild} > 0.35" | bc)" -eq 1 ] || [ "${MODEL_BUILD}" = "all" ]; then
        echo ""
        echo "IPCAS 2.0 will be performed."
        
        # Select best PDB to seed IPCAS
        if [ -f "SUMMARY/AUTOBUILD.pdb" ] && [ $(echo "$r_free_autobuild < $r_free_refine" | bc) -eq 1 ] && [ $(echo "$r_free_autobuild > 0" | bc) -eq 1 ]; then
          PDB=$(readlink -f "SUMMARY/AUTOBUILD.pdb")
        elif [ -f "SUMMARY/REFINEMENT.pdb" ] && [ $(echo "$r_free_refine > 0" | bc) -eq 1 ]; then
          PDB=$(readlink -f "SUMMARY/REFINEMENT.pdb")
        else
          PDB=$(readlink -f "SUMMARY/PHASER.1.pdb")
        fi
        
        # Run IPCAS
        "${SOURCE_DIR}/ipcas.sh" "${MTZ}" "${PDB}" "${SEQUENCE}" 0.5 ${IPCAS_CYCLE} . > IPCAS.log
        echo ""
        cat IPCAS/result
        mv IPCAS.log IPCAS/Summary/
    
        if [ "$(ls -A IPCAS/Summary/)" ]; then
            cp IPCAS/Summary/Free_*.mtz SUMMARY/IPCAS.mtz
            cp IPCAS/Summary/Free_*.pdb SUMMARY/IPCAS.pdb
            cp IPCAS/Summary/IPCAS.log SUMMARY/
        else
            echo "IPCAS.pdb does not exist."
        fi
    fi
fi
