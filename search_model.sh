#!/bin/bash
#!/bin/bash
#############################################################################################################
# Script Name: search_model.sh
# Description: Generate search models for molecular replacement using MrParse and/or AlphaFold predictions.
#
# This script:
#   1. Downloads AlphaFold DB models if a UniProt ID is provided.
#   2. Runs MrParse to identify homologous models from sequence input.
#   3. Runs AlphaFold predictions (via Phenix) when no UniProt ID is provided.
#   4. Processes and filters models based on sequence identity, length ratio,
#      and pLDDT scores to prepare ensembles for MR.
#   5. Outputs processed models into SEARCH_MODELS directories for later use.
#
# Usage:
#   ./search_model.sh <date_cutoff>
#
# Example:
#   ./search_model.sh 2022-01-01
#
# Arguments:
#   <date_cutoff>  Date filter for excluding PDB homologs released after this date.
#
# Environment Variables (exported by autopipeline.sh):
#   UNIPROT_ID     UniProt ID for downloading AFDB models
#   SEQUENCE       Path to input FASTA sequence
#   SOURCE_DIR     Directory containing pipeline scripts
#   AF_PREDICT     Whether to run AlphaFold prediction locally (true/false)
#   AF_SPLIT       Whether to split AF models by chain/domain (true/false)
#   PAE_SPLIT      Whether to split models using PAE matrix (true/false)
#   DATE           Date cutoff for homolog selection
#
# Author: ZHANG Xin
# Created: 2023-06-01
# Last Modified: 2025-08-03
#############################################################################################################

start_time=$(date +%s)

# Input variable: date filter for homolog selection
DATE=${1}

# ==============================================================================================
# Case 1: UniProt ID is provided -> download AlphaFold DB models instead of running MrParse
# ==============================================================================================
if [[ -n "$UNIPROT_ID" ]]; then
    mkdir -p AFDB_MODELS
    cd AFDB_MODELS
    
    # Download AlphaFold DB model
    python3 ${SOURCE_DIR}/download_alphafold.py $UNIPROT_ID
    
    # Extract average pLDDT from downloaded model
    plddt_afdb=$(grep 'Average pLDDT' *.pdb | awk '{print $NF}')
    
    # Determine cutoff for filtering
    if (( $(echo "${plddt_afdb:-0} >= 60" | bc) )); then
      plddt_cutoff=60
    else
      plddt_cutoff=40
    fi
    
    # Process AlphaFold model
    phenix.process_predicted_model *.pdb b_value_field_is=plddt minimum_plddt=$plddt_cutoff > ProcessPredictedModel.log
    cp *_processed_*.pdb ../SEARCH_MODELS/AF_MODELS/
    
    echo "UniProt ID was provided. MrParse and AlphaFold Prediction will be skipped."
    cd ..
    exit 1
fi

# ==============================================================================================
# Case 2: No UniProt ID -> run MrParse and AlphaFold prediction
# ==============================================================================================

# Create folder structure for MrParse
mkdir -p MRPARSE
cd MRPARSE
mkdir -p SEQ_FILES
cd SEQ_FILES

# Split multi-chain FASTA into individual sequence files
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

# Run MrParse for homologous model search (unless disabled)
if [ "$AF_PREDICT" != "true" ];then
  find SEQ_FILES -type f | while IFS= read -r file; do
    mrparse --seqin "$file" --max_hits 5 --ccp4cloud >> mrparse.log
  done
fi

dir=$(pwd)

# ==============================================================================================
# Step: Run AlphaFold prediction with Phenix for each sequence
# ==============================================================================================
process_af_prediction() {
  local i=$1
  cd ${dir}
  mkdir -p predict_${i}
  cd predict_${i}
  
  seq_file=$(find ../SEQ_FILES -type f | awk "NR==$(($i+1))")
  
  # Run AlphaFold prediction
  phenix.predict_and_build seq_file=$seq_file prediction_server=PhenixServer stop_after_predict=True include_templates_from_pdb=False > PredictAndBuild.log
}

for i in $(seq 0 $((${seq_count}-1))); do
  (process_af_prediction $i) &
done
wait
cd ${dir}

# ==============================================================================================
# Step: Process MrParse and AlphaFold results for each sequence
# ==============================================================================================
process_models() {
  local i=$1
  
# ------------------------
# Process homolog models
# ------------------------
if [ "$AF_PREDICT" != "true" ];then
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
    if [ -f "homologs.txt" ]; then
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
      echo "Sequence $((i+1))    No AlphaFold Database models were found."
      afdb=0
      seq_id_afdb=0
    fi
  else
    echo "Sequence $((i+1))    No AlphaFold Database models were found."
    afdb=0
    plddt_afdb=0
    seq_id_afdb=0
  fi
  cd ..
fi

  # ------------------------
  # Process AlphaFold predictions
  # ------------------------
  cd predict_${i}
    plddt_afp=$(awk -F= '/plDDT =/ {gsub(/[[:space:]]/, "", $2); last=$2} END{print last}' PredictAndBuild.log)
    if ! find "PredictAndBuild_0_CarryOn" -mindepth 1 -maxdepth 1 | read -r; then
      echo "AlphaFold Prediction failed."
      if [[ $afdb != 0 ]]; then
        python3 ${SOURCE_DIR}/calc_vrms.py ../mrparse_${i}/AF2_files/${model_name_afdb}* ../mrparse_${i}/${file_name_afdb}
        cp ../mrparse_${i}/${file_name_afdb} ../../SEARCH_MODELS/AF_MODELS/AF_DB$((i+1)).pdb
      fi
    elif [ "$AF_PREDICT" != "true" ] && [ "$PAE_SPLIT" != "true" ] && [ "$(echo "$seq_id_afdb >= 0.85" | bc -l)" -eq 1 ] && [ "$(echo "$plddt_afdb > $plddt_afp" | bc -l)" -eq 1 ] && [ "$(echo "$length_ratio_afdb >= 0.6" | bc -l)" -eq 1 ] ; then
      echo "Sequence $((i+1))    AlphaFold Prediction Model: plddt=$plddt_afp "
      echo "Sequence $((i+1))    AlphaFold Database model will be used in MR." 
      python3 ${SOURCE_DIR}/calc_vrms.py ../mrparse_${i}/AF2_files/${model_name_afdb}* ../mrparse_${i}/${file_name_afdb}
      cp ../mrparse_${i}/${file_name_afdb} ../../SEARCH_MODELS/AF_MODELS/AF_DB$((i+1)).pdb
    else
      # Prediction is successful. Process this predicted model.
      if [ "$PAE_SPLIT" = "true" ]; then
        i2run editbfac \
	  --XYZIN PredictAndBuild_0_CarryOn/PredictAndBuild_0_rebuilt.pdb \
	  --PAEIN pae_matrix.jsn \
	  --noDb >log.txt
        mv log.txt ProcessPredictedModel.log
        model_length_afp=$(grep -m 1 "Total residues in final model:" ProcessPredictedModel.log | awk '{print $6}')
        echo "Sequence $((i+1))    AlphaFold Prediction Model: model_length=$model_length_afp plddt=$plddt_afp "
        echo "Sequence $((i+1))    AlphaFold Prediction model will be used in MR."
        python3 ${SOURCE_DIR}/calc_vrms.py PredictAndBuild_0_CarryOn/PredictAndBuild_0_rebuilt.pdb "converted_model_chain*.pdb"
        for file in converted_model_chain*.pdb; do
          base=$(basename "$file" .pdb)
          cp "$file" "../../SEARCH_MODELS/AF_MODELS/${base}_${i}.pdb"
        done
      else
        if (( $(echo "${plddt_afp:-0} >= 60" | bc) )); then
          plddt_cutoff=60
        else
          plddt_cutoff=40
        fi
        phenix.process_predicted_model PredictAndBuild_0_CarryOn/PredictAndBuild_0_rebuilt.pdb b_value_field_is=*plddt minimum_plddt=$plddt_cutoff > ProcessPredictedModel.log
        if [ -f "PredictAndBuild_0_rebuilt_processed.pdb" ]; then
          model_length_afp=$(grep -m 1 "Final residues:" ProcessPredictedModel.log | awk '{print $3}')
          echo "Sequence $((i+1))    AlphaFold Prediction Model: model_length=$model_length_afp plddt=$plddt_afp "
          echo "Sequence $((i+1))    AlphaFold Prediction model will be used in MR." 
          python3 ${SOURCE_DIR}/calc_vrms.py PredictAndBuild_0_CarryOn/PredictAndBuild_0_rebuilt.pdb "PredictAndBuild_0_rebuilt_processed*"
          if [ "$AF_SPLIT" = "false" ]; then
            cp PredictAndBuild_0_rebuilt_processed.pdb "../../SEARCH_MODELS/AF_MODELS/PredictAndBuild_0_rebuilt_processed_${i}.pdb"
          else
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

# Ensure AF models backfill homolog slots if needed
if [ -d "../SEARCH_MODELS/HOMOLOGS" ] && [ "$(ls -A ../SEARCH_MODELS/HOMOLOGS)" ]; then
  for i in $(seq 0 $((${seq_count}-1))); do
    if [ ! -f ../SEARCH_MODELS/HOMOLOGS/ENSEMBLE$((i+1)).pdb ] && [ -f ../SEARCH_MODELS/AF_MODELS/ENSEMBLE$((i+1)).pdb ]; then
      cp ../SEARCH_MODELS/AF_MODELS/ENSEMBLE$((i+1)).pdb ../SEARCH_MODELS/HOMOLOGS/ENSEMBLE$((i+1)).pdb
    fi
  done
fi

# ==============================================================================================
# Timing summary
# ==============================================================================================
end_time=$(date +%s)
total_time=$((end_time - start_time))
hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))
echo "MrParse took: ${hours}h ${minutes}m ${seconds}s" | tee ../SEARCH_MODEL.log
echo ""

mv ../SEARCH_MODEL.log .
cd ..
