#!/bin/bash

start_time=$(date +%s)

scr_dir=${1}
SEQUENCE=${2}
DATE=${3}

mkdir -p MRPARSE PREDICT_MODELS
cd MRPARSE
mkdir -p SEQ_FILES
cd SEQ_FILES

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
j=0

for file in $(find SEQ_FILES -type f); do
  mrparse --seqin "$file" --max_hits 5 --ccp4cloud >> mrparse.log
done

for i in $(seq 0 $((${seq_count}-1))); do
  cd mrparse_${i}
  mkdir -p all_models
  
  if [ ! -d "models" ] || [ -z "$(ls -A models)" ] || [ ! -f af_models.json ]; then
    touch af_models.txt
    echo "No AF models were found."
  else
    cp models/*.pdb all_models
    python ${scr_dir}/json_to_table.py af_models.json 
  fi
  
  if [ ! -d "homologs" ] || [ -z "$(ls -A homologs)" ]; then
    touch homologs.txt
    echo "No homologs were found."
  else
    cp homologs/*.pdb all_models
    if ! grep -qE '^\s*\[\s*\]\s*$' homologs.json; then
      python ${scr_dir}/json_to_table.py homologs.json ${DATE}
    else
      for file in "homologs"/*; do
        if [ -f "$file" ]; then
          filename=$(basename -- "$file")
          filename="${filename%_*}"

          ID=$(head -n 1 "$file" | awk '{print $NF}')
          ID=$(echo "scale=2; $ID / 100" | bc)

          echo -e "${filename}\t${ID}" >> homologs.txt
        fi
      done
    fi
  fi

  cat af_models.txt homologs.txt > summary.txt
  
  if [ -s summary.txt ]; then
    sort -k2 -nr summary.txt -o summary.txt
    awk 'BEGIN { OFS="\t" } { printf "%-15s %-10s %-5s %-15s %-10s %-25s %-10s\n", $1, $2, $3, $4, $5, $6, $7 }' summary.txt > temp.txt && mv temp.txt summary.txt
    best_identity=$(awk 'NR==1 {print $2}' summary.txt)
  else
    best_identity=0
  fi
  
  if (( $(echo "$best_identity >= 0.9" | bc -l) )); then
    echo "Sequence identity of search model is $best_identity."
    model_name=$(head -1 summary.txt | awk '{print $1}')
    cp all_models/${model_name}_* ../../SEARCH_MODELS/ENSEMBLE$((i+1)).pdb
    cd ..
  else
    echo "Sequence identity of search model is lower than 0.9. Phenix.PredictModel will be performed."
    cd ../../PREDICT_MODELS
    seq_file=$(find ../MRPARSE/SEQ_FILES -type f | awk "NR==$(($i+1))")
    phenix.predict_and_build seq_file=$seq_file prediction_server=PhenixServer stop_after_predict=True include_templates_from_pdb=False > PredictAndBuild_${j}.log
    if [ "$(find "PredictAndBuild_${j}_CarryOn" -mindepth 1 | head -n 1)" ]; then 
      phenix.process_predicted_model PredictAndBuild_${j}_CarryOn/PredictAndBuild_${j}_rebuilt.pdb b_value_field_is=*plddt > ProcessPredictedModel_${j}.log
      cp PredictAndBuild_${j}_rebuilt_processed.pdb ../SEARCH_MODELS/ENSEMBLE$((i+1)).pdb
    fi
    ((j++))
    cd ../MRPARSE
  fi
done

mv ../SEARCH_MODEL.log .
cd ..
end_time=$(date +%s)
total_time=$((end_time - start_time))

hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))
echo "MrParse took: ${hours}h ${minutes}m ${seconds}s" 
echo ""
