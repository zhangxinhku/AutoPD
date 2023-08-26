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
ROTATION_AXIS=1 # 1 / -1 Default:1
DR_CRITERION=""
MODEL_BUILDING=2 # 1->Buccaneer 2->Autobuild 3-> IPCAS Default:1

for arg in "$@"; do
  if [[ "$arg" == *=* ]]; then
    key="${arg%%=*}"
    value="${arg#*=}"

    case $key in
      data_path) DATA_PATH="$value";;
      sequence) SEQUENCE="$value";;
      mtz) EXPERIMENT="$value";;
      pdb_path) MR_TEMPLATE_PATH="$value";;
      rotation_axis) ROTATION_AXIS="$value";; 
      model_building) MODEL_BUILDING="$value";;
      dr_criterion) DR_CRITERION="$value";;
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
    echo "Please enter the name of the output directory:"
    read folder_name
elif [ ! -e "${DATA_PATH}" ]; then
    echo "Warning: Data path does not exist. Data reduction will be skipped."
    DR="false"
    echo "Please enter the output directory:"
    read folder_name
else
    folder_name=${DATA_PATH%/}
    folder_name=${folder_name##*/}
    echo "Data: ${DATA_PATH}"
fi

#Create and enter folder for data processing
mkdir -p ${folder_name}
cd ${folder_name}
mkdir -p ALPHAFOLD_MODEL SUMMARY

#Optional input
if [ -z "${SEQUENCE}" ]; then
    echo "Warning: No sequence was input. Only data reduction will be performed."
    AF="false"
elif [ ! -e "${SEQUENCE}" ]; then
    echo "Warning: Sequence path does not exist. Only data reduction will be performed."
    AF="false"
else
    echo "Sequence: ${SEQUENCE}"
    cd ALPHAFOLD_MODEL
    seq_count=0
    while IFS= read -r line; do
        if [[ ${line:0:1} == ">" ]]; then
            seq_count=$((seq_count+1))
            header=${line#*>}
            id=${header%%|*}
            output_sequence="${id}.fasta"
            > "${output_sequence}"
        fi
        echo $line >> ${output_sequence}
    done < "${SEQUENCE}"
    echo "Sequence count: ${seq_count}"
    cd ..
fi

if [ -z "${EXPERIMENT}" ]; then
    echo "No experimental mtz file was input."
elif [ ! -e "${EXPERIMENT}" ]; then
    echo "Experimental mtz file does not exist."
else
    echo "An experimental mtz file was input. Data reduction will be skipped."
    echo "Experimental mtz file: ${EXPERIMENT}"
    DR="false"
fi

if [ -z "${MR_TEMPLATE_PATH}" ]; then
    echo "No molecular replacement template was input."
elif [ ! -e "${MR_TEMPLATE_PATH}" ]; then
    echo "MR template path does not exist."
else
    rm ALPHAFOLD_MODEL/*.pdb
   
    i=1
    # Loop through each .pdb file
    for pdb_file in ${MR_TEMPLATE_PATH}/*.pdb; do
    # Copy the file to the destination directory with the new name
      cp "${pdb_file}" "ALPHAFOLD_MODEL/ENSEMBLE${i}.pdb"
    # Increment counter
      ((i++))
    done 
    echo "Molecular replacement templates were input. Alphafold model retrieval will be skipped."
    echo "MR template path: ${MR_TEMPLATE_PATH}"
    AF="false"
fi

echo "============================================================================================="
echo "                             Data reduction & AF model retrieval                             "
echo "============================================================================================="

if [ "${DR}" = "false" ] && [ "${AF}" = "false" ]; then
  echo ""
  echo "Data reduction and AF model retrieval will be skipped."
elif [ "${DR}" = "false" ]; then
  echo ""
  echo "Data reduction will be skipped."
  ${scr_dir}/fetch_alphafold.sh ${scr_dir} ${seq_count} | tee FETCH_ALPHAFOLD.log
elif [ "${AF}" = "false" ]; then
  echo ""
  echo "AF model retrieval will be skipped."
  ${scr_dir}/data_reduction.sh ${DATA_PATH} ${scr_dir} ${ROTATION_AXIS} | tee DATA_REDUCTION.log
  if [ "${DR_CRITERION}" = "resolution" ]; then
    EXPERIMENT=$(readlink -f "SUMMARY/BEST_Resolution.mtz")
    echo "BEST_Resolution.mtz will be used in MR."
  else
    EXPERIMENT=$(readlink -f "SUMMARY/BEST_Rmerge.mtz")
    echo "BEST_Rmerge.mtz will be used in MR."
  fi
else    
  parallel -u ::: "${scr_dir}/fetch_alphafold.sh ${scr_dir} ${seq_count} | tee FETCH_ALPHAFOLD.log" "${scr_dir}/data_reduction.sh ${DATA_PATH} ${scr_dir} ${ROTATION_AXIS} | tee DATA_REDUCTION.log"
  if [ "${DR_CRITERION}" = "resolution" ]; then
    EXPERIMENT=$(readlink -f "SUMMARY/BEST_Resolution.mtz")
    echo "BEST_Resolution.mtz will be used in MR."
  else
    EXPERIMENT=$(readlink -f "SUMMARY/BEST_Rmerge.mtz")
    echo "BEST_Rmerge.mtz will be used in MR."
  fi
fi

if [ ! -f "${SEQUENCE}" ]; then 
    echo "Normal termination: Sequence is needed for the following parts." 
    exit 1
fi

if [ ! -f "${EXPERIMENT}" ]; then
    echo "ERROR: No mtz file found."
    exit 1
fi

if [ -z "$(find ALPHAFOLD_MODEL -maxdepth 1 -type f -name '*.pdb')" ]; then
    echo "ERROR: No PDB files found."
    exit 1
fi

#exit
echo ""
echo "============================================================================================="
echo "                                    Molecular Replacement                                    "
echo "============================================================================================="


#Molecular replacement
${scr_dir}/mr.sh ${SEQUENCE} ${EXPERIMENT}
#exit

PDB=$(readlink -f "SUMMARY/PHASER.pdb")

if [ -f "SUMMARY/PHASER.mtz" ]; then
    MTZ=$(readlink -f "SUMMARY/PHASER.mtz")
else
    MTZ=$(readlink -f "SUMMARY/BEST_Rmerge.mtz")
fi

if [ ! -f "${PDB}" ]; then
    echo "ERROR: No pdb file found."
    exit 1
fi

echo ""
echo "============================================================================================="
echo "                                         Model building                                      "
echo "============================================================================================="
echo ""

#Model building and Refinement
case ${MODEL_BUILDING} in
  "autobuild")
    echo "Phenix.autobuild will be performed."
    echo ""
    ${scr_dir}/autobuild.sh ${MTZ} ${PDB} ${SEQUENCE}
    ;;
  "ipcas")
    ${scr_dir}/ipcas.sh ${MTZ} ${PDB} ${SEQUENCE} 0.5 10 . > IPCAS.log
    mv IPCAS.log IPCAS
    ;;
  *)
    ${scr_dir}/buccaneer.sh ${MTZ} ${PDB} ${SEQUENCE}
    ;;
esac
end_time=$(date +%s)
total_time=$((end_time - start_time))

hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))
echo "Total time: ${hours}h ${minutes}m ${seconds}s"
