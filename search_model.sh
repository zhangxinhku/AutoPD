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
  seq_length=$(grep -m1 'L=' mrparse.log | grep -oP '(?<=L=)\d+')
  if [ ! -d "homologs" ] || [ -z "$(ls -A homologs)" ]; then
    echo "Sequence $((i+1))    No homologs were found."
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
    sort -k2,2nr -k6r,6 homologs.txt -o homologs.txt
    model_name_h=$(awk 'NR==1 {print $1}' homologs.txt)
    seq_id_h=$(awk 'NR==1 {print $2}' homologs.txt)
    file_name_h=$(echo homologs/${model_name_h}* | cut -d ' ' -f 1)
    model_length_h=$(awk 'NR==1 {print $5}' homologs.txt)
    length_ratio_h=$(echo "scale=2; $model_length_h / $seq_length" | bc)
    model_date=$(awk 'NR==1 {print $6}' homologs.txt)
    echo "Sequence $((i+1))    Homologous Model: $model_name_h model_length=$model_length_h seq_id=$seq_id_h model_date=$model_date"
    if (( $(echo "$length_ratio_h >= 0.3" | bc -l) )); then
      if [ ! -f "$file_name_h" ]; then
        model_id=$(echo "$model_name_h" | cut -c1-4)
        chain_id=$(echo "$model_name_h" | cut -c6)
        phenix.fetch_pdb $model_id 
        mv $model_id.pdb pdb_files
        awk -v chain="$chain_id" '{if (substr($0, 22, 1) == chain) print}' pdb_files/$model_id.pdb > homologs/${model_id}_${chain_id}.pdb
      fi      
      if grep -q "ATOM" $file_name_h; then
        echo "Sequence $((i+1))    Homologous model will be used in MR." 
        cp ${file_name_h} "../../SEARCH_MODELS/HOMOLOGS/ENSEMBLE$((i+1)).pdb"
      else
        echo "Sequence $((i+1))    No atoms in homologous model."
      fi
    else
      echo "Sequence $((i+1))    Homologous model is too short for MR."
    fi
  fi
  
  if [ -d "models" ] && [ -n "$(ls -A models)" ] && [ -f af_models.json ]; then
    python3 ${SOURCE_DIR}/json_to_table.py af_models.json
    sort -k2,2nr -k7,7nr af_models.txt -o af_models.txt
    model_name_afdb=$(awk 'NR==1 {print $1}' af_models.txt)
    model_length_afdb=$(awk 'NR==1 {print $5}' af_models.txt)
    length_ratio_afdb=$(echo "scale=2; $model_length_afdb / $seq_length" | bc)
    file_name_afdb=$(echo models/${model_name_afdb}_* | cut -d ' ' -f 1)
    if grep -q "ATOM" "$file_name_afdb" 2>/dev/null; then
      seq_id_afdb=$(awk 'NR==1 {print $2}' af_models.txt)
      plddt_afdb=$(awk 'NR==1 {print $7}' af_models.txt)
      echo "Sequence $((i+1))    AlphaFold Database Model: $model_name_afdb model_length=$model_length_afdb seq_id=$seq_id_afdb plddt=$plddt_afdb"
    else
      seq_id_afdb=0
    fi
  else
    echo "Sequence $((i+1))    No AlphaFold Database models were found."
    plddt_afdb=0
    seq_id_afdb=0
  fi
    
  if [ "$(echo "$seq_id_afdb >= 0.9" | bc -l)" -eq 1 ] && [ "$(echo "$plddt_afdb >= 90" | bc -l)" -eq 1 ] && [ "$(echo "$length_ratio_afdb >= 0.6" | bc -l)" -eq 1 ] && [ "$AF_PREDICT" != "true" ] && [ "$PAE_SPLIT" != "true" ]; then
    # The highest sequence identity is higher than 0.9, keep this model.
    echo "Sequence $((i+1))    AlphaFold Database model will be used in MR." 
    cp ${file_name_afdb} ../../SEARCH_MODELS/AF_MODELS/AF_DB$((i+1)).pdb
  else
    echo "Sequence $((i+1))    Phenix.PredictModel will be performed."
    cd ..
    mkdir predict_${i}
    cd predict_${i}
    seq_file=$(find ../SEQ_FILES -type f | awk "NR==$(($i+1))")
    # Predict a new model for this chain using AlphaFold
    phenix.predict_and_build seq_file=$seq_file prediction_server=PhenixServer stop_after_predict=True include_templates_from_pdb=False > PredictAndBuild.log
    plddt_afp=$(awk -F= '/plDDT =/ {gsub(/[[:space:]]/, "", $2); last=$2} END{print last}' PredictAndBuild.log)
    if [ ! -f "pae_matrix.jsn" ]; then
      echo "AlphaFold Prediction failed. No ensemble will be used for Sequence $((i+1))."
    elif [ "$AF_PREDICT" != "true" ] && [ "$PAE_SPLIT" != "true" ] && [ "$(echo "$seq_id_afdb >= 0.9" | bc -l)" -eq 1 ] && [ "$(echo "$plddt_afdb > $plddt_afp" | bc -l)" -eq 1 ]; then
      echo "Sequence $((i+1))    AlphaFold Database model will be used in MR." 
      cp ../mrparse_${i}/${file_name_afdb} ../../SEARCH_MODELS/AF_MODELS/AF_DB$((i+1)).pdb
    else
      if [ "$(find "PredictAndBuild_0_CarryOn" -mindepth 1 | head -n 1)" ]; then
        # Prediction is successful. Process this predicted model.
        if [ "$PAE_SPLIT" = "true" ]; then
          i2run editbfac \
	    --XYZIN PredictAndBuild_0_CarryOn/PredictAndBuild_0_rebuilt.pdb \
	    --PAEIN pae_matrix.jsn \
	    --noDb >log.txt
          mv log.txt ProcessPredictedModels.log
          echo "Sequence $((i+1))    AlphaFold Prediction Model: plddt=$plddt_afp "
          echo "Sequence $((i+1))    AlphaFold Prediction model will be used in MR." 
          for file in converted_model_chain*.pdb; do
            base=$(basename "$file" .pdb)
            cp "$file" "../../SEARCH_MODELS/AF_MODELS/${base}_${i}.pdb"
          done
        else
          phenix.process_predicted_model PredictAndBuild_0_CarryOn/PredictAndBuild_0_rebuilt.pdb b_value_field_is=*plddt > ProcessPredictedModel.log
          model_length_afp=$(grep -m 1 "Final residues:" ProcessPredictedModel.log | awk '{print $3}')
          echo "Sequence $((i+1))    AlphaFold Prediction Model: model_length=$model_length_afp plddt=$plddt_afp "
          echo "Sequence $((i+1))    AlphaFold Prediction model will be used in MR." 
          for file in PredictAndBuild_0_rebuilt_processed_*.pdb; do
            base=$(basename "$file" .pdb)
            cp "$file" "../../SEARCH_MODELS/AF_MODELS/${base}_${i}.pdb"
          done
        fi
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
