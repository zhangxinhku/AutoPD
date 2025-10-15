#!/bin/bash
#############################################################################################################
# Script Name: autopipeline.sh
# Description: Main controller script for AutoPD (Automated Pipeline for Data Reduction and Structure 
#              Determination). This script coordinates all modules, including data reduction (XDS/xia2/autoPROC), 
#              MrParse, molecular replacement (MR), AlphaFold prediction, and SAD phasing. It manages inputs,
#              prepares directories, executes processing pipelines in parallel when possible, and logs results.
#
# Usage Example:
#   ./autopipeline.sh data_path=/path/to/images seq_file=sequence.fasta \
#       space_group=P212121 cell="78.3 84.1 96.5 90 90 90" rotation_axis="1,0,0" out_dir=AutoPD_run1
#
# Required Arguments:
#   data_path       Directory containing diffraction images
#   seq_file        Protein sequence file (FASTA)
#
# Optional Arguments:
#   mtz_file        Experimental MTZ file (bypasses data reduction)
#   uniprot_id      UniProt ID for fetching homologs
#   pdb_path        Directory containing user-provided MR templates (.pdb)
#   rotation_axis   Rotation axis vector (comma-separated, e.g., "1,0,0")
#   out_dir         Output directory name (default: AutoPD_processed)
#   mp_date         MrParse cutoff date for excluding homologs released after this date
#   z               Number of copies in asymmetric unit
#   atom            Atom type for anomalous scattering (default: Se)
#   space_group     Space group symbol (e.g., P212121)
#   cell            Unit cell constants "a b c alpha beta gamma"
#   beam_x,beam_y   Beam center coordinates
#   distance        Crystal-to-detector distance (mm)
#   image_start,end Image range to process (numbers only)
#   ipcas_cycle     Number of IPCAS cycles (default: 20)
#   af_predict      true/false: Run AlphaFold prediction
#   af_split        true/false: Split AlphaFold models with Phenix
#   pae_split       true/false: Split AlphaFold models using PAE with CCP4
#   sad             true/false: Enable SAD phasing
#   model_build     Strategy for model building (if specified)
#
# Exit Codes:
#   0  Success (pipeline completed normally)
#   1  Failure (missing required inputs or MTZ files)
#
# Author:      ZHANG Xin
# Created:     2023-06-01
# Last Edited: 2025-08-03
#############################################################################################################

start_time=$(date +%s)

#############################################
# Locate AutoPD directory
#############################################
SOURCE_DIR=$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

#############################################
# Initialize input variables
#############################################
DATA_PATH=""
SEQUENCE=""
EXPERIMENT=""
UNIPROT_ID=""
MR_TEMPLATE_PATH=""
ROTATION_AXIS=""
OUT_DIR="AutoPD_processed"
DATE=""
Z=""
ATOM="Se"
SPACE_GROUP=""
CELL_CONSTANTS=""
BEAM_X=""
BEAM_Y=""
DISTANCE=""
IMAGE_START=""
IMAGE_END=""
IPCAS_CYCLE="20"
AF_PREDICT="false"
AF_SPLIT="true"
PAE_SPLIT="false"
SAD="false"
MODEL_BUILD=""

#############################################
# Parse command-line arguments
#############################################
for arg in "$@"; do
  if [[ "$arg" == *=* ]]; then
    key="${arg%%=*}"
    value="${arg#*=}"

    case $key in
      data_path) DATA_PATH="$value";;            #The path contains diffraction images
      seq_file) SEQUENCE="$value";;              #The sequence file
      mtz_file) EXPERIMENT="$value";;            #The mtz file
      uniprot_id) UNIPROT_ID="$value";;          #The uniprot_id
      pdb_path) MR_TEMPLATE_PATH="$value";;      #The path contains search models for MR
      rotation_axis) ROTATION_AXIS="$value";;    #Rotation axis, e.g. 1,0,0
      out_dir) OUT_DIR="$value";;                #Output folder name
      mp_date) DATE="$value";;                   #The homologs released after this date will be excluded from the result of MrParse, for data testing.
      z) Z_INPUT="$value";;                      #The number of asymmetric unit copies 
      atom) ATOM="$value";;                      #The atom type of anomalous scattering
      space_group) SPACE_GROUP_INPUT="$value";;  #Space group
      cell) CELL_CONSTANTS_INPUT="$value";;      #Cell Parameters
      beam_x) BEAM_X="$value" ;;                 #Beam center x
      beam_y) BEAM_Y="$value" ;;                 #Beam center y
      distance) DISTANCE="$value" ;;             #The crystal to detector distance
      image_start) IMAGE_START="$value" ;;       #Process a specific image range within a scan. image_start and image_end are numbers denoting the image range
      image_end) IMAGE_END="$value" ;;           #Process a specific image range within a scan. image_start and image_end are numbers denoting the image range
      ipcas_cycle) IPCAS_CYCLE="$value" ;;       #IPCAS cycle
      af_predict) AF_PREDICT="$value" ;;         #AlphaFold Prediction by Phenix
      af_split) AF_SPLIT="$value" ;;             #Splitting by Phenix
      pae_split) PAE_SPLIT="$value" ;;           #PAE Splitting by CCP4
      sad) SAD="$value" ;;                       #SAD will be performed
      model_build) MODEL_BUILD="$value" ;;       #Model building strategy
      *) echo "Invalid parameter: $arg" >&2; exit 1;;
    esac
  else
    echo "Invalid parameter: $arg" >&2; exit 1;
  fi
done

#############################################
# Normalize paths
#############################################
DATA_PATH=$(readlink -f "${DATA_PATH}")
SEQUENCE=$(readlink -f "${SEQUENCE}")
EXPERIMENT=$(readlink -f "${EXPERIMENT}")
MR_TEMPLATE_PATH=$(readlink -f "${MR_TEMPLATE_PATH}")

# Export key variables for child scripts
export SOURCE_DIR DATA_PATH SEQUENCE UNIPROT_ID ROTATION_AXIS BEAM_X BEAM_Y DISTANCE IMAGE_START IMAGE_END Z_INPUT ATOM SPACE_GROUP_INPUT CELL_CONSTANTS_INPUT AF_PREDICT PAE_SPLIT IPCAS_CYCLE MODEL_BUILD AF_SPLIT

#############################################
# Prepare output directories
#############################################
if [ -d "$OUT_DIR" ]; then
  suffix=1
  while [ -d "${OUT_DIR}_${suffix}" ]; do
    suffix=$((suffix + 1))
  done
  OUT_DIR="${OUT_DIR}_${suffix}"
fi

mkdir -p ${OUT_DIR}
cd ${OUT_DIR}
mkdir -p SUMMARY INPUT_FILES SEARCH_MODELS/HOMOLOGS SEARCH_MODELS/AF_MODELS SEARCH_MODELS/INPUT_MODELS

#############################################
# Input checks
#############################################
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

if [ -z "${MR_TEMPLATE_PATH}" ]; then
    echo "No molecular replacement template was input."
elif [ ! -e "${MR_TEMPLATE_PATH}" ]; then
    echo "MR template path does not exist."
else
    cp ${MR_TEMPLATE_PATH}/*.pdb INPUT_FILES
    cp ${MR_TEMPLATE_PATH}/*.pdb SEARCH_MODELS/INPUT_MODELS
    echo "Molecular replacement templates were input. MrParse will be skipped."
    echo "MR template path: ${MR_TEMPLATE_PATH}"
    MP="false"
fi

#############################################
# Data Reduction & MrParse
#############################################
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
  ${SOURCE_DIR}/data_reduction.sh | tee DATA_REDUCTION.log
else    
  parallel -u ::: "${SOURCE_DIR}/search_model.sh ${DATE} | tee SEARCH_MODEL.log" "${SOURCE_DIR}/data_reduction.sh | tee DATA_REDUCTION.log"
fi

# Require sequence for further steps
if [ ! -f "${SEQUENCE}" ]; then 
    echo "Normal termination: Sequence is needed for the following parts." 
    exit 0
fi

# Require at least one MTZ
if [ -z "$(find DATA_REDUCTION/DATA_REDUCTION_SUMMARY -maxdepth 1 -type f -name '*.mtz' 2>/dev/null)" ] && [ -z "$(find INPUT_FILES -maxdepth 1 -type f -name '*.mtz' 2>/dev/null)" ]; then
    echo "ERROR: No mtz files found."
    exit 1
fi

#############################################
# SAD signal check
#############################################
if [ -d "DATA_REDUCTION/SAD_INPUT" ] && find "DATA_REDUCTION/SAD_INPUT" -maxdepth 1 -type f -size +0 2>/dev/null | grep -q .; then
    SAD="true"
    echo "SAD will be performed."
else
    echo "No strong anomalous signal was found."
fi

#############################################
# Molecular Replacement (MR) check
#############################################
if [ -z "$(find SEARCH_MODELS -maxdepth 2 -type f -name '*.pdb')" ]; then
    echo "No search model was found."
    MR="false"
fi

#############################################
# Run MR and/or SAD
#############################################
echo ""
echo "============================================================================================="
echo "                                 Molecular Replacement & SAD                                 "
echo "============================================================================================="

if [ "${MR}" = "false" ] && [ "${SAD}" != "true" ]; then
  echo ""
  echo "Both MR and SAD cannot be performed."
  exit 1
elif [ "${MR}" = "false" ]; then
  echo ""
  echo "MR will be skipped."
  ${SOURCE_DIR}/sad.sh ${MTZ_IN}
elif [ "${SAD}" != "true" ]; then
  echo ""
  echo "SAD will be skipped."
  ${SOURCE_DIR}/mr_model_build.sh ${MTZ_IN}
else    
  parallel -u ::: "${SOURCE_DIR}/sad.sh ${MTZ_IN}" "${SOURCE_DIR}/mr_model_build.sh ${MTZ_IN}"
fi 

#############################################
# Print timing information
#############################################
end_time=$(date +%s)
total_time=$((end_time - start_time))
hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))
echo "Total time: ${hours}h ${minutes}m ${seconds}s"
