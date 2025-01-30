#!/bin/bash
#############################################################################################################
# Script Name: autopipeline.sh
# Description: This script controls all modules in the AutoPD.
# Author: ZHANG Xin
# Date Created: 2023-06-01
# Last Modified: 2024-03-05
#############################################################################################################
start_time=$(date +%s)

#Get AutoPD directory
SOURCE_DIR=$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

#Input variables
DATA_PATH=""
SEQUENCE=""
EXPERIMENT=""
MR_TEMPLATE_PATH=""
ROTATION_AXIS=""
OUT_DIR="AutoPD_processed"
DATE=""
Z=""
ATOM=""
SPACE_GROUP=""
BEAM_X=""
BEAM_Y=""

for arg in "$@"; do
  if [[ "$arg" == *=* ]]; then
    key="${arg%%=*}"
    value="${arg#*=}"

    case $key in
      data_path) DATA_PATH="$value";;            #The path contains diffraction images
      seq_file) SEQUENCE="$value";;              #The sequence file
      mtz_file) EXPERIMENT="$value";;            #The mtz file
      pdb_path) MR_TEMPLATE_PATH="$value";;      #The path contains search models for MR
      rotation_axis) ROTATION_AXIS="$value";;    #Rotation axis, e.g. 1,0,0
      out_dir) OUT_DIR="$value";;                #Output folder name
      mp_date) DATE="$value";;                   #The homologs released after this date will be excluded from the result of MrParse, for data testing.
      z) Z="$value";;                            #The number of asymmetric unit copies 
      atom) ATOM="$value";;                      #The atom type of anomalous scattering
      space_group) SPACE_GROUP="$value";;        #Space group
      beam_x) BEAM_X="$value" ;;                 #Beam center x
      beam_y) BEAM_Y="$value" ;;                 #Beam center y
      *) echo "Invalid parameter: $arg" >&2; exit 1;;
    esac
  else
    echo "Invalid parameter: $arg" >&2; exit 1;
  fi
done

DATA_PATH=$(readlink -f "${DATA_PATH}")
SEQUENCE=$(readlink -f "${SEQUENCE}")
EXPERIMENT=$(readlink -f "${EXPERIMENT}")
MR_TEMPLATE_PATH=$(readlink -f "${MR_TEMPLATE_PATH}")

export SOURCE_DIR DATA_PATH SEQUENCE ROTATION_AXIS BEAM_X BEAM_Y ATOM

#Create and enter folder for data processing
if [ -d "$OUT_DIR" ]; then
  suffix=1
  while [ -d "${OUT_DIR}_${suffix}" ]; do
    suffix=$((suffix + 1))
  done
  OUT_DIR="${OUT_DIR}_${suffix}"
fi

mkdir -p ${OUT_DIR}
cd ${OUT_DIR}
mkdir -p SUMMARY INPUT_FILES

#Input check
if [ -z "${DATA_PATH}" ]; then
    echo "Warning: No data path was input. Data reduction will be skipped."
    DR="false"
elif [ ! -e "${DATA_PATH}" ]; then
    echo "Warning: Data path does not exist. Data reduction will be skipped."
    DR="false"
else
    echo "Data: ${DATA_PATH}"
fi

if [ -z "${SEQUENCE}" ]; then
    echo "Warning: No sequence was input. Only data reduction will be performed."
    MP="false"
elif [ ! -e "${SEQUENCE}" ]; then
    echo "Warning: Sequence path does not exist. Only data reduction will be performed."
    MP="false"
else
    cp ${SEQUENCE} INPUT_FILES
    echo "Sequence: ${SEQUENCE}"
fi

if [ -z "${EXPERIMENT}" ]; then
    MTZ_IN=0
    echo "No experimental mtz file was input."
elif [ ! -e "${EXPERIMENT}" ]; then
    MTZ_IN=0
    echo "Experimental mtz file does not exist."
else
    MTZ_IN=1
    cp ${EXPERIMENT} INPUT_FILES/
    cp ${EXPERIMENT} SUMMARY/
    echo "An experimental mtz file was input. Data reduction will be skipped."
    echo "Experimental mtz file: ${EXPERIMENT}"
    DR="false"
fi

if [ -z "${ATOM}" ]; then
    SAD="false"
    mkdir -p SEARCH_MODELS/HOMOLOGS SEARCH_MODELS/AF_MODELS SEARCH_MODELS/INPUT_MODELS
else
    SAD="true"
    MP="false"
fi

if [ -z "${MR_TEMPLATE_PATH}" ]; then
    echo "No molecular replacement template was input."
elif [ ! -e "${MR_TEMPLATE_PATH}" ]; then
    echo "MR template path does not exist."
else
    cp ${MR_TEMPLATE_PATH}/*.pdb INPUT_FILES SEARCH_MODELS/INPUT_MODELS
    echo "Molecular replacement templates were input. MrParse will be skipped."
    echo "MR template path: ${MR_TEMPLATE_PATH}"
    MP="false"
fi

#Data reduction and MrParse
echo "============================================================================================="
echo "                                   Data reduction & MrParse                                  "
echo "============================================================================================="

if [ "${DR}" = "false" ] && [ "${MP}" = "false" ]; then
  echo ""
  echo "Data reduction and MrParse will be skipped."
elif [ "${DR}" = "false" ]; then
  echo ""
  echo "Data reduction will be skipped."
  ${SOURCE_DIR}/search_model.sh ${DATE} | tee SEARCH_MODEL.log
elif [ "${MP}" = "false" ]; then
  echo ""
  echo "MrParse will be skipped."
  ${SOURCE_DIR}/data_reduction.sh space_group=${SPACE_GROUP} | tee DATA_REDUCTION.log
else    
  parallel -u ::: "${SOURCE_DIR}/search_model.sh ${DATE} | tee SEARCH_MODEL.log" "${SOURCE_DIR}/data_reduction.sh space_group=${SPACE_GROUP} | tee DATA_REDUCTION.log"
fi

if [ ! -f "${SEQUENCE}" ]; then 
    echo "Normal termination: Sequence is needed for the following parts." 
    exit 0
fi

if [ -z "$(find DATA_REDUCTION/DATA_REDUCTION_SUMMARY -maxdepth 1 -type f -name '*.mtz' 2>/dev/null)" ] && [ -z "$(find INPUT_FILES -maxdepth 1 -type f -name '*.mtz' 2>/dev/null)" ]; then
    echo "ERROR: No mtz files found."
    exit 1
fi

#SAD

if [ "${SAD}" = "true" ]; then
    echo ""
    echo "============================================================================================="
    echo "                                             SAD                                             "
    echo "============================================================================================="
    
    ${SOURCE_DIR}/sad.sh ${MTZ_IN}
    
    #Calculate and echo timing information
    end_time=$(date +%s)
    total_time=$((end_time - start_time))
    hours=$((total_time / 3600))
    minutes=$(( (total_time % 3600) / 60 ))
    seconds=$((total_time % 60))
    echo "Total time: ${hours}h ${minutes}m ${seconds}s"
    exit
fi

#MR

if [ -z "$(find SEARCH_MODELS -maxdepth 2 -type f -name '*.pdb')" ]; then
    echo "ERROR: No search model found."
    exit 1
fi

echo ""
echo "============================================================================================="
echo "                                    Molecular Replacement                                    "
echo "============================================================================================="

${SOURCE_DIR}/mr.sh ${MTZ_IN} ${Z}

if [ -s "PHASER_MR/MR_SUMMARY/MR_BEST.txt" ]; then
  echo ""
  echo "Refinement Results:"
  awk '{print $1, "R-work="$5, "R-free="$6}' PHASER_MR/MR_SUMMARY/MR_BEST.txt
  r_free_refine=$(sort -k6,6n "PHASER_MR/MR_SUMMARY/MR_BEST.txt" | awk 'NR==1 {print $6}')
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
    
if [ -f "BUCCANEER/BUCCANEER_SUMMARY/BUCCANEER.pdb" ]; then
    r_free=$(grep 'FREE R VALUE                     :' "BUCCANEER/BUCCANEER_SUMMARY/BUCCANEER.pdb" 2>/dev/null | cut -d ':' -f 2 | xargs)
    PDB=$(readlink -f "BUCCANEER/BUCCANEER_SUMMARY/BUCCANEER.pdb")
else
    PDB=$(readlink -f "SUMMARY/PHASER.1.pdb")
fi

#Phenix Autobuild
if [ ! -f "BUCCANEER/BUCCANEER_SUMMARY/BUCCANEER.pdb" ] || ([ "$(echo "${r_free} > 0.35" | bc)" -eq 1 ] && [ "$(echo "${r_free_refine} > 0.35" | bc)" -eq 1 ]); then
    echo ""
    echo "Phenix Autobuild will be performed."
    
    if [ -f "SUMMARY/PHASER.1.mtz" ]; then
      MTZ="SUMMARY/PHASER.1.mtz"
    else
      MTZ=$(find SUMMARY -type f -name "*.mtz" ! -name "BUCCANEER.mtz" ! -name "REFINEMENT.mtz" -print -quit)
    fi
    
    ${SOURCE_DIR}/autobuild.sh ${MTZ} ${PDB}
    
    if [ -f "AUTOBUILD/AUTOBUILD_SUMMARY/AUTOBUILD.pdb" ]; then
        cp AUTOBUILD/AUTOBUILD_SUMMARY/* SUMMARY/
        r_free=$(grep 'FREE R VALUE                     :' "AUTOBUILD/AUTOBUILD_SUMMARY/AUTOBUILD.pdb" 2>/dev/null | cut -d ':' -f 2 | xargs)
    else
        PDB=$(readlink -f "SUMMARY/PHASER.1.pdb")
        ${SOURCE_DIR}/autobuild.sh ${MTZ} ${PDB}
        if [ -f "AUTOBUILD/AUTOBUILD_SUMMARY/AUTOBUILD.pdb" ]; then
          cp AUTOBUILD/AUTOBUILD_SUMMARY/* SUMMARY/
          r_free=$(grep 'FREE R VALUE                     :' "AUTOBUILD/AUTOBUILD_SUMMARY/AUTOBUILD.pdb" 2>/dev/null | cut -d ':' -f 2 | xargs)
        else
          echo "AUTOBUILD.pdb does not exist."
        fi
    fi
    
    #IPCAS
    PDB=$(readlink -f "SUMMARY/PHASER.1.pdb")       
    if [ ! -f "AUTOBUILD/AUTOBUILD_SUMMARY/AUTOBUILD.pdb" ] || [ "$(echo "${r_free} > 0.35" | bc)" -eq 1 ]; then
        echo ""
        echo "IPCAS 2.0 will be performed."
        "${SOURCE_DIR}/ipcas.sh" "${MTZ}" "${PDB}" "${SEQUENCE}" 0.5 15 . > IPCAS.log
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

#Calculate and echo timing information
end_time=$(date +%s)
total_time=$((end_time - start_time))
hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))
echo "Total time: ${hours}h ${minutes}m ${seconds}s"
