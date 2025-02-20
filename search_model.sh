#!/bin/bash
#############################################################################################################
# Script Name: search_model.sh
# Description: This script is used for generating search models using MrParse and AlphaFold.
# Author: ZHANG Xin
# Date Created: 2023-06-01
# Last Modified: 2024-03-05
#############################################################################################################

start_time=$(date +%s)

#Input variables
DATE=${1}

#Create folder for search models
mkdir -p MRPARSE
cd MRPARSE
mkdir -p SEQ_FILES
cd SEQ_FILES

#Determine the number pf unique chains in the sequence
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
echo ""
echo "Sequence count: ${seq_count}"
cd ..

#Generate search models using MrParse and AlphaFold

find SEQ_FILES -type f | while IFS= read -r file; do
  mrparse --seqin "$file" --max_hits 5 --ccp4cloud >> mrparse.log
done

dir=$(pwd)

process_models() {
  local i=$1
  cd ${dir}/mrparse_${i}
  
  if [ ! -d "homologs" ] || [ -z "$(ls -A homologs)" ]; then
    echo "No homologs were found for sequence $((i+1))."
  else
    if ! grep -qE '^\s*\[\s*\]\s*$' homologs.json; then
      # The homologs.json is not empty
      python3 ${SOURCE_DIR}/json_to_table.py homologs.json ${DATE}
    else
      # The homologs.json is empty
      for file in "homologs"/*; do
        if [ -f "$file" ]; then
          # There are homologs
          if grep -q "ATOM" "$file"; then
            # There are atoms in the homologs file
            filename=$(basename -- "$file")
            filename="${filename%_*}"

            seq_id=$(head -n 1 "$file" | awk '{print $NF}')
            seq_id=$(echo "scale=2; $seq_id / 100" | bc)

            echo -e "${filename}\t${seq_id}" >> homologs.txt
          else
            rm "$file"
          fi
        fi
      done
    fi
    sort -k2,2nr -k6,6nr homologs.txt -o homologs.txt
    model_name=$(head -1 homologs.txt | awk '{print $1}')
    file_name=$(echo homologs/${model_name}_* | cut -d ' ' -f 1)
    if grep -q "ATOM" "$file_name" 2>/dev/null; then
      cp ${file_name} ../../SEARCH_MODELS/HOMOLOGS/ENSEMBLE$((i+1)).pdb
    fi
  fi
  
  if [ -d "models" ] && [ -n "$(ls -A models)" ] && [ -f af_models.json ]; then
    python3 ${SOURCE_DIR}/json_to_table.py af_models.json
    sort -k2,2nr -k7,7nr af_models.txt -o af_models.txt
    model_name=$(head -1 af_models.txt | awk '{print $1}')
    model_length=$(head -1 af_models.txt | awk '{print $5}')
    seq_length=$(grep -m1 'L=' mrparse.log | grep -oP '(?<=L=)\d+')
    length_ratio=$(echo "scale=2; $model_length / $seq_length" | bc)
    file_name=$(echo models/${model_name}_* | cut -d ' ' -f 1)
    if grep -q "ATOM" "$file_name" 2>/dev/null; then
      seq_id=$(awk 'NR==1 {print $2}' af_models.txt)
      plddt=$(awk 'NR==1 {print $7}' af_models.txt)
    else
      seq_id=0
    fi
  else
    echo "No AlphaFold models were found for sequence $((i+1))."
    seq_id=0
  fi
    
  if [ "$(echo "$seq_id >= 0.9" | bc -l)" -eq 1 ] && [ "$(echo "$plddt >= 90" | bc -l)" -eq 1 ] && [ "$(echo "$length_ratio >= 0.6" | bc -l)" -eq 1 ] && [ "$AF_PREDICT" != "true" ]; then
    # The highest sequence identity is higher than 0.9, keep this model.
    cp ${file_name} ../../SEARCH_MODELS/AF_MODELS/AF_DB$((i+1)).pdb
  else
    echo "Phenix.PredictModel will be performed for sequence $((i+1))."
    cd ..
    mkdir predict_${i}
    cd predict_${i}
    seq_file=$(find ../SEQ_FILES -type f | awk "NR==$(($i+1))")
    # Predict a new model for this chain using AlphaFold
    phenix.predict_and_build seq_file=$seq_file prediction_server=PhenixServer stop_after_predict=True include_templates_from_pdb=False > PredictAndBuild.log
    if [ "$(find "PredictAndBuild_0_CarryOn" -mindepth 1 | head -n 1)" ]; then
      # Prediction is successful. Process this predicted model.
      if [ "$PAE_SPLIT" = "true" ]; then
        i2run editbfac \
	  --XYZIN PredictAndBuild_0_CarryOn/PredictAndBuild_0_rebuilt.pdb \
	  --PAEIN pae_matrix.jsn \
	  --noDb >log.txt
        mv log.txt ProcessPredictedModels.log
        for file in converted_model_chain*.pdb; do
          base=$(basename "$file" .pdb)
          cp "$file" "../../SEARCH_MODELS/AF_MODELS/${base}_${i}.pdb"
        done
      else
        phenix.process_predicted_model PredictAndBuild_0_CarryOn/PredictAndBuild_0_rebuilt.pdb b_value_field_is=*plddt > ProcessPredictedModel.log
        for file in PredictAndBuild_0_rebuilt_processed_*.pdb; do
          base=$(basename "$file" .pdb)
          cp "$file" "../../SEARCH_MODELS/AF_MODELS/${base}_${i}.pdb"
        done
      fi
    fi
  fi
}

export -f process_models

for i in $(seq 0 $((${seq_count}-1))); do
  process_models $i &
done
wait
cd ${dir}

if [ -d "../SEARCH_MODELS/HOMOLOGS" ] && [ "$(ls -A ../SEARCH_MODELS/HOMOLOGS)" ]; then
  for i in $(seq 0 $((${seq_count}-1))); do
    if [ ! -f ../SEARCH_MODELS/HOMOLOGS/ENSEMBLE$((i+1)).pdb ] && [ -f ../SEARCH_MODELS/AF_MODELS/ENSEMBLE$((i+1)).pdb ]; then
      cp ../SEARCH_MODELS/AF_MODELS/ENSEMBLE$((i+1)).pdb ../SEARCH_MODELS/HOMOLOGS/ENSEMBLE$((i+1)).pdb
    fi
  done
fi

#Calculate and echo timing information
end_time=$(date +%s)
total_time=$((end_time - start_time))
hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))
echo "MrParse took: ${hours}h ${minutes}m ${seconds}s" | tee ../SEARCH_MODEL.log
echo ""

mv ../SEARCH_MODEL.log .
cd ..
