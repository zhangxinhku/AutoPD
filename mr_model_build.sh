#!/bin/bash
#############################################################################################################
# Script Name: mr_model_build.sh
# Description: This script is used for molecular replacement and model building.
# Author: ZHANG Xin
# Date Created: 2025-03-03
# Last Modified: 2025-03-03
#############################################################################################################

#Input variables
MTZ_IN=${1}

${SOURCE_DIR}/mr.sh ${MTZ_IN}

if [ -s "PHASER_MR/MR_SUMMARY/MR_BEST.txt" ]; then
  echo ""
  echo "Refinement Results:"
  awk '{print $1, "R-work="$6, "R-free="$7}' PHASER_MR/MR_SUMMARY/MR_BEST.txt
#  r_free_refine=$(sort -k6,6n "PHASER_MR/MR_SUMMARY/MR_BEST.txt" | awk 'NR==1 {print $7}')
#  r_work=$(sort -k6,6n "PHASER_MR/MR_SUMMARY/MR_BEST.txt" | awk 'NR==1 {print $5}')
else
  exit 1
fi

#Model building
#Buccaneer
echo ""
echo "============================================================================================="
echo "                                         Model building                                      "
echo "============================================================================================="
echo ""
echo "Buccaneer will be performed."

${SOURCE_DIR}/buccaneer.sh

r_free_buccaneer=$(grep 'FREE R VALUE                     :' "SUMMARY/BUCCANEER.pdb" 2>/dev/null | cut -d ':' -f 2 | xargs | grep -Eo '^[0-9.]+' || echo 0)
r_free_refine=$(grep 'FREE R VALUE                     :' "SUMMARY/REFINEMENT.pdb" 2>/dev/null | cut -d ':' -f 2 | xargs | grep -Eo '^[0-9.]+' || echo 0)
export r_free_buccaneer r_free_refine

if [ -f "SUMMARY/PHASER.1.mtz" ]; then
  MTZ="SUMMARY/PHASER.1.mtz"
else
  MTZ=$(find SUMMARY -type f -name "*.mtz" ! -name "BUCCANEER.mtz" ! -name "REFINEMENT.mtz" -print -quit)
fi

#Phenix Autobuild
if [ ! -f "SUMMARY/BUCCANEER.pdb" ] || [ "$(echo "${r_free_buccaneer} > 0.35" | bc)" -eq 1 ] || [ "${MODEL_BUILD}" = "autobuild" ] || [ "${MODEL_BUILD}" = "all" ]; then
    echo ""
    echo "Phenix Autobuild will be performed."
    
    ${SOURCE_DIR}/autobuild.sh ${MTZ}
    
    if [ -f "AUTOBUILD/AUTOBUILD_SUMMARY/AUTOBUILD.pdb" ]; then
        cp AUTOBUILD/AUTOBUILD_SUMMARY/* SUMMARY/
        r_free_autobuild=$(grep 'FREE R VALUE                     :' "AUTOBUILD/AUTOBUILD_SUMMARY/AUTOBUILD.pdb" 2>/dev/null | cut -d ':' -f 2 | xargs)
    else
        echo "AUTOBUILD.pdb does not exist."
    fi
    
    #IPCAS       
    if [ ! -f "SUMMARY/AUTOBUILD.pdb" ] || [ "$(echo "${r_free_autobuild} > 0.35" | bc)" -eq 1 ] || [ "${MODEL_BUILD}" = "all" ]; then
        echo ""
        echo "IPCAS 2.0 will be performed."
        if [ -f "SUMMARY/AUTOBUILD.pdb" ] && [ $(echo "$r_free_autobuild < $r_free_refine" | bc) -eq 1 ] && [ $(echo "$r_free_autobuild > 0" | bc) -eq 1 ]; then
          PDB=$(readlink -f "SUMMARY/AUTOBUILD.pdb")
        elif [ -f "SUMMARY/REFINEMENT.pdb" ] && [ $(echo "$r_free_refine > 0" | bc) -eq 1 ]; then
          PDB=$(readlink -f "SUMMARY/REFINEMENT.pdb")
        else
          PDB=$(readlink -f "SUMMARY/PHASER.1.pdb")
        fi
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
