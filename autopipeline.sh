#!/bin/bash
# Program:
#      Protein crystal diffraction data auto-processing pipeline.
# History:
# 2022/08/30       ZHANG Xin       First release

start_time=$(date +%s)

#Script directory
scr_dir=$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

DATA_PATH=""
SEQUENCE=""
EXPERIMENT=""
MR_TEMPLATE_PATH=""
ROTATION_AXIS=""
DR_CRITERION="rmerge" # rmerge resolution Default:rmerge
MODEL_BUILDING=2 # 1->Buccaneer 2->Autobuild 3-> IPCAS Default:2
OUT_DIR="pipeline_processed"
DATE=""
Z=""

for arg in "$@"; do
  if [[ "$arg" == *=* ]]; then
    key="${arg%%=*}"
    value="${arg#*=}"

    case $key in
      data_path) DATA_PATH="$value";;
      seq_file) SEQUENCE="$value";;
      mtz_file) EXPERIMENT="$value";;
      pdb_path) MR_TEMPLATE_PATH="$value";;
      rotation_axis) ROTATION_AXIS="$value";; 
      dr_criterion) DR_CRITERION="$value";;
      model_building) MODEL_BUILDING="$value";;
      out_dir) OUT_DIR="$value";;
      mp_date) DATE="$value";;
      z) Z="$value";;
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

#Input
if [ -z "${DATA_PATH}" ]; then
    echo "Warning: No data path was input. Data reduction will be skipped."
    DR="false"
elif [ ! -e "${DATA_PATH}" ]; then
    echo "Warning: Data path does not exist. Data reduction will be skipped."
    DR="false"
else
    echo "Data: ${DATA_PATH}"
fi

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
mkdir -p SEARCH_MODELS SUMMARY INPUT_FILES

#Optional input
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

if [ -z "${MR_TEMPLATE_PATH}" ]; then
    echo "No molecular replacement template was input."
elif [ ! -e "${MR_TEMPLATE_PATH}" ]; then
    echo "MR template path does not exist."
else
    cp ${MR_TEMPLATE_PATH}/*.pdb INPUT_FILES
    rm -f SEARCH_MODELS/*.pdb
   
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

echo "============================================================================================="
echo "                                   Data reduction & MrParse                                  "
echo "============================================================================================="

if [ "${DR}" = "false" ] && [ "${MP}" = "false" ]; then
  echo ""
  echo "Data reduction and MrParse will be skipped."
elif [ "${DR}" = "false" ]; then
  echo ""
  echo "Data reduction will be skipped."
  ${scr_dir}/search_model.sh ${scr_dir} ${SEQUENCE} ${DATE} | tee SEARCH_MODEL.log
elif [ "${MP}" = "false" ]; then
  echo ""
  echo "MrParse will be skipped."
  ${scr_dir}/data_reduction.sh ${DATA_PATH} ${scr_dir} ${ROTATION_AXIS} | tee DATA_REDUCTION.log
else    
  parallel -u ::: "${scr_dir}/search_model.sh ${scr_dir} ${SEQUENCE} ${DATE} | tee SEARCH_MODEL.log" "${scr_dir}/data_reduction.sh ${DATA_PATH} ${scr_dir} ${ROTATION_AXIS} | tee DATA_REDUCTION.log"
fi

if [ ! -f "${SEQUENCE}" ]; then 
    echo "Normal termination: Sequence is needed for the following parts." 
    exit 1
fi

if [ -z "$(find DATA_REDUCTION/DATA_REDUCTION_SUMMARY -maxdepth 1 -type f -name '*.mtz' 2>/dev/null)" ] && [ -z "$(find INPUT_FILES -maxdepth 1 -type f -name '*.mtz' 2>/dev/null)" ]; then
    echo "ERROR: No mtz files found."
    exit 1
fi

if [ -z "$(find SEARCH_MODELS -maxdepth 1 -type f -name '*.pdb')" ]; then
    echo "ERROR: No pdb files found."
    exit 1
else
    cp SEARCH_MODELS/* SUMMARY/
fi

#exit
echo ""
echo "============================================================================================="
echo "                                    Molecular Replacement                                    "
echo "============================================================================================="


#Molecular replacement
${scr_dir}/mr.sh ${SEQUENCE} ${MTZ_IN} ${Z}

if [ -z "$(find PHASER_MR/MR_SUMMARY/ -maxdepth 1 -type f -name '*.pdb')" ]; then
    echo "ERROR: No pdb files found."
    exit 1
fi

echo ""
echo "============================================================================================="
echo "                                         Model building                                      "
echo "============================================================================================="
echo ""

#Model building and Refinement
echo "CCP4 Buccaneer will be performed."
${scr_dir}/buccaneer.sh ${SEQUENCE} ${scr_dir}
    
if [ -f "BUCCANEER/BUCCANEER_SUMMARY/BUCCANEER.pdb" ]; then
    cp BUCCANEER/BUCCANEER_SUMMARY/* SUMMARY/
    num=$(grep 'Best R-free' BUCCANEER/BUCCANEER_SUMMARY/BUCCANEER.log | awk '{print $NF}')
    r_free=$(grep 'R-work:' "BUCCANEER/BUCCANEER_SUMMARY/BUCCANEER.log" 2>/dev/null | sort -k4,4n | head -1 | awk '{print $4}')
    cp PHASER_MR/MR_${num}/*.mtz SUMMARY/ 2>/dev/null
    cp PHASER_MR/MR_${num}/*.pdb SUMMARY/
    cp PHASER_MR/MR_${num}/*.log SUMMARY/
else
    echo "BUCCANEER.pdb does not exist."
fi

MTZ="SUMMARY/PHASER.1.mtz"
PDB="SUMMARY/PHASER.1.pdb"

if [ ! -f "BUCCANEER/BUCCANEER_SUMMARY/BUCCANEER.pdb" ] || [ "$(echo "${r_free} > 0.35" | bc)" -eq 1 ]; then
     echo "Phenix.autobuild will be performed."
#    "${scr_dir}/autobuild.sh" "${MTZ}" "${PDB}" "${SEQUENCE}"
fi

#  "ipcas")
#    echo "IPCAS will be performed."
#    ${scr_dir}/ipcas.sh ${MTZ} ${PDB} ${SEQUENCE} 0.5 10 . > IPCAS.log
#    mv IPCAS.log IPCAS

end_time=$(date +%s)
total_time=$((end_time - start_time))

hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))
echo "Total time: ${hours}h ${minutes}m ${seconds}s"
