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

export SOURCE_DIR="${SOURCE_DIR}"
export DATA_PATH="${DATA_PATH}"
export SEQUENCE="${SEQUENCE}"
export ROTATION_AXIS="${ROTATION_AXIS}"
export BEAM_X="${BEAM_X}"
export BEAM_Y="${BEAM_Y}"
export ATOM="${ATOM}"

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
    cp ${EXPERIMENT} INPUT_FILES
    cp ${EXPERIMENT} SUMMARY
    echo "An experimental mtz file was input. Data reduction will be skipped."
    echo "Experimental mtz file: ${EXPERIMENT}"
    DR="false"
fi

if [ -z "${ATOM}" ]; then
    SAD="false"
    mkdir -p SEARCH_MODELS
else
    SAD="true"
    MP="false"
fi

if [ -z "${MR_TEMPLATE_PATH}" ]; then
    echo "No molecular replacement template was input."
elif [ ! -e "${MR_TEMPLATE_PATH}" ]; then
    echo "MR template path does not exist."
else
    cp ${MR_TEMPLATE_PATH}/*.pdb INPUT_FILES
   
    i=1
    # Loop through each .pdb file
    for pdb_file in INPUT_FILES/*.pdb; do
    # Copy the file to the destination directory with the new name
      cp "${pdb_file}" "SEARCH_MODELS/ENSEMBLE${i}.pdb"
    # Increment counter
      ((i++))
    done 
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
    exit 1
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

if [ -z "$(find SEARCH_MODELS -maxdepth 1 -type f -name '*.pdb')" ]; then
    echo "ERROR: No search model found."
    exit 1
else
    cp SEARCH_MODELS/* SUMMARY/
fi

echo ""
echo "============================================================================================="
echo "                                    Molecular Replacement                                    "
echo "============================================================================================="

${SOURCE_DIR}/mr.sh ${MTZ_IN} ${Z}

if [ -z "$(find PHASER_MR/MR_SUMMARY/ -maxdepth 1 -type f -name '*.pdb')" ]; then
    echo "ERROR: No pdb files found."
    exit 1
fi

#Model building and Refinement
echo ""
echo "============================================================================================="
echo "                                         Model building                                      "
echo "============================================================================================="
echo ""

#Buccaneer
echo "Buccaneer will be performed."
${SOURCE_DIR}/buccaneer.sh
    
if [ -f "BUCCANEER/BUCCANEER_SUMMARY/BUCCANEER.pdb" ]; then
    cp BUCCANEER/BUCCANEER_SUMMARY/* SUMMARY/
    num=$(grep 'Best R-free' BUCCANEER/BUCCANEER_SUMMARY/BUCCANEER.log | awk '{print $NF}')
    r_free=$(grep 'R-work:' "BUCCANEER/BUCCANEER_SUMMARY/BUCCANEER.log" 2>/dev/null | sort -k4,4n | head -1 | awk '{print $4}')
    if [ -d "DATA_REDUCTION" ]; then
        name=$(find "PHASER_MR/MR_${num}" -type f -name "*.mtz" ! -name "PHASER.1.mtz" -exec basename {} \; | sed 's/\.mtz$//' | head -n 1)
        cp DATA_REDUCTION/DATA_REDUCTION_SUMMARY/${name}_SUMMARY.log SUMMARY/
    fi
    cp PHASER_MR/MR_${num}/*.mtz SUMMARY/ 2>/dev/null
    cp PHASER_MR/MR_${num}/*.pdb SUMMARY/
    cp PHASER_MR/MR_${num}/*.log SUMMARY/
else
    echo "BUCCANEER.pdb does not exist."
fi

#Phenix Autobuild
PDB="SUMMARY/PHASER.1.pdb"
if [ -f "SUMMARY/PHASER.1.mtz" ]; then
  MTZ="SUMMARY/PHASER.1.mtz"
else
  MTZ=$(find SUMMARY -name "*.mtz" -print -quit)
fi

if [ ! -f "BUCCANEER/BUCCANEER_SUMMARY/BUCCANEER.pdb" ] || [ "$(echo "${r_free} > 0.35" | bc)" -eq 1 ]; then
     echo "Phenix Autobuild will be performed."
    "${SOURCE_DIR}/autobuild.sh" "${MTZ}" "${PDB}"
    
    if [ -f "AUTOBUILD/AUTOBUILD_SUMMARY/AUTOBUILD.pdb" ]; then
        cp AUTOBUILD/AUTOBUILD_SUMMARY/* SUMMARY/
        r_free=$(grep 'Best solution on cycle:' AUTOBUILD/AUTOBUILD_SUMMARY/AUTOBUILD.log | awk -F'/' '{print $3}')
    else
        echo "AUTOBUILD.pdb does not exist."
    fi
    
    #IPCAS
    if [ ! -f "AUTOBUILD/AUTOBUILD_SUMMARY/AUTOBUILD.pdb" ] || [ "$(echo "${r_free} > 0.35" | bc)" -eq 1 ]; then
        echo ""
        echo "IPCAS 2.0 will be performed."
        ${SOURCE_DIR}/ipcas.sh ${MTZ} ${PDB} ${SEQUENCE} 0.5 15 . > IPCAS.log
    
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
