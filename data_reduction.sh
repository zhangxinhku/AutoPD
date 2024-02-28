#!/bin/bash
start_time=$(date +%s)

#Input variables
DATA_PATH=${1}
SOURCE_DIR=${2}
ROTATION_AXIS=${3}

#Determine file type
FILE_TYPE=$(find "${DATA_PATH}" -maxdepth 1 -type f ! -name '.*' | head -n 1 | awk -F. '{if (NF>1) print $NF}')

#Create and enter folder for data reduction
mkdir -p DATA_REDUCTION
cd DATA_REDUCTION

#Extract header information
${SOURCE_DIR}/header.sh ${DATA_PATH} ${FILE_TYPE} > header.log

#First round data processing
echo ""
echo "-------------------------------- First round data processing --------------------------------"
echo ""
ROUND=1
parallel -u ::: "${SOURCE_DIR}/xds.sh data_path=${DATA_PATH} rotation_axis=${ROTATION_AXIS} round=${ROUND} source_dir=${SOURCE_DIR} file_type=${FILE_TYPE}" "${SOURCE_DIR}/xds_xia2.sh data_path=${DATA_PATH} rotation_axis=${ROTATION_AXIS} round=${ROUND} source_dir=${SOURCE_DIR} file_type=${FILE_TYPE}" "${SOURCE_DIR}/dials_xia2.sh data_path=${DATA_PATH} rotation_axis=${ROTATION_AXIS} round=${ROUND} source_dir=${SOURCE_DIR} file_type=${FILE_TYPE}" "${SOURCE_DIR}/autoproc.sh data_path=${DATA_PATH} rotation_axis=${ROTATION_AXIS} round=${ROUND} source_dir=${SOURCE_DIR} file_type=${FILE_TYPE}"

FLAG_XDS=$(grep 'FLAG_XDS=' temp.txt | cut -d '=' -f 2)
FLAG_XDS_XIA2=$(grep 'FLAG_XDS_XIA2=' temp.txt | cut -d '=' -f 2)
FLAG_DIALS_XIA2=$(grep 'FLAG_DIALS_XIA2=' temp.txt | cut -d '=' -f 2)
FLAG_autoPROC=$(grep 'FLAG_autoPROC=' temp.txt | cut -d '=' -f 2)

#Compare first round result
BEST_1=$(cat "temp1.txt" | sort -k 2 | head -n 1 | cut -d ' ' -f 1)

#Extract space group and cell parameters from best first round result
SPACE_GROUP_NUMBER=$(grep 'Space group number:' ${BEST_1}/${BEST_1}_SUMMARY/${BEST_1}_SUMMARY.log | cut -d ':' -f 2 | sed 's/ //g')
SPACE_GROUP=$(grep 'Space group:' ${BEST_1}/${BEST_1}_SUMMARY/${BEST_1}_SUMMARY.log | cut -d ':' -f 2 | sed 's/ //g')
UNIT_CELL_CONSTANTS=$(grep 'Unit cell:' ${BEST_1}/${BEST_1}_SUMMARY/${BEST_1}_SUMMARY.log | cut -d ':' -f 2 | sed 's/^ *//g' | sed 's/ *$//g' | sed 's/  */,/g')
UNIT_CELL=$(grep 'Unit cell:' ${BEST_1}/${BEST_1}_SUMMARY/${BEST_1}_SUMMARY.log | cut -d ':' -f 2 | sed 's/^ *//g' | sed 's/ *$//g' | sed 's/  */ /g')


if [ "${SPACE_GROUP}" == "P2122" ] || [ "${SPACE_GROUP}" == "P2212" ]; then
    SPACE_GROUP="P2221"
fi

#Second round data processing
echo ""
if [[ ${FLAG_XDS} -eq 1 && ${FLAG_XDS_XIA2} -eq 1 && ${FLAG_DIALS_XIA2} -eq 1 && ${FLAG_autoPROC} -eq 1 ]]; then
    echo "No need for second round data processing."
else
    echo "-------------------------------- Second round data processing -------------------------------"
fi
echo ""
ROUND=2
parallel -u ::: "${SOURCE_DIR}/xds.sh data_path=${DATA_PATH} rotation_axis=${ROTATION_AXIS} round=${ROUND} source_dir=${SOURCE_DIR} file_type=${FILE_TYPE} flag=${FLAG_XDS} sp_number=${SPACE_GROUP_NUMBER} cell_constants=\"${UNIT_CELL_CONSTANTS}\"" "${SOURCE_DIR}/xds_xia2.sh data_path=${DATA_PATH} rotation_axis=${ROTATION_AXIS} round=${ROUND} source_dir=${SOURCE_DIR} file_type=${FILE_TYPE} flag=${FLAG_XDS_XIA2} sp=${SPACE_GROUP} cell_constants=\"${UNIT_CELL_CONSTANTS}\"" "${SOURCE_DIR}/dials_xia2.sh data_path=${DATA_PATH} rotation_axis=${ROTATION_AXIS} round=${ROUND} source_dir=${SOURCE_DIR} file_type=${FILE_TYPE} flag=${FLAG_DIALS_XIA2} sp=${SPACE_GROUP} cell_constants=\"${UNIT_CELL_CONSTANTS}\"" "${SOURCE_DIR}/autoproc.sh data_path=${DATA_PATH} rotation_axis=${ROTATION_AXIS} round=${ROUND} source_dir=${SOURCE_DIR} file_type=${FILE_TYPE} flag=${FLAG_autoPROC} sp=\"\\\"$SPACE_GROUP\\\"\" cell_constants=\"\\\"$UNIT_CELL\\\"\""

#Output summary results
echo ""
echo "Data reduction summary:"
echo ""
echo "           Resolution   Rmerge   I/Sigma   CC(1/2)   Completeness   Multiplicity   Space group                           Cell"
echo ""

if [ -f "XDS/XDS_SUMMARY/XDS_SUMMARY.log" ]; then
    XDS_resolution=$(grep 'High resolution limit' XDS/XDS_SUMMARY/XDS_SUMMARY.log | awk '{print $4}')
    XDS_rmerge=$(grep 'Rmerge  (all I+ and I-)' XDS/XDS_SUMMARY/XDS_SUMMARY.log | awk '{print $6}')
    XDS_i_over_sigma=$(grep 'Mean((I)/sd(I))' XDS/XDS_SUMMARY/XDS_SUMMARY.log | awk '{print $2}')
    XDS_cc_half=$(grep 'Mn(I) half-set correlation CC(1/2)' XDS/XDS_SUMMARY/XDS_SUMMARY.log | awk '{print $5}')
    XDS_completeness=$(grep 'Completeness' XDS/XDS_SUMMARY/XDS_SUMMARY.log | awk '{print $2}')
    XDS_multiplicity=$(grep 'Multiplicity' XDS/XDS_SUMMARY/XDS_SUMMARY.log | awk '{print $2}')
    XDS_space_group=$(grep 'Space group:' XDS/XDS_SUMMARY/XDS_SUMMARY.log | cut -d ':' -f 2 | sed 's/ //g')
    XDS_cell=$(grep 'Unit cell:' XDS/XDS_SUMMARY/XDS_SUMMARY.log | cut -d ':' -f 2 | sed 's/^ *//g' | sed 's/ *$//g' | sed 's/  */ /g')
    printf "XDS           %.2f       %.3f      %.1f     %.3f        %.1f           %.1f          %s     %.4f %.4f %.4f %.4f %.4f %.4f\n" ${XDS_resolution} ${XDS_rmerge} ${XDS_i_over_sigma} ${XDS_cc_half} ${XDS_completeness} ${XDS_multiplicity} ${XDS_space_group} ${XDS_cell}
    echo ""
fi

if [ -f "XDS_XIA2/XDS_XIA2_SUMMARY/XDS_XIA2_SUMMARY.log" ]; then
    XDS_XIA2_resolution=$(grep 'High resolution limit' XDS_XIA2/XDS_XIA2_SUMMARY/XDS_XIA2_SUMMARY.log | awk '{print $4}')
    XDS_XIA2_rmerge=$(grep 'Rmerge  (all I+ and I-)' XDS_XIA2/XDS_XIA2_SUMMARY/XDS_XIA2_SUMMARY.log | awk '{print $6}')
    XDS_XIA2_i_over_sigma=$(grep 'Mean((I)/sd(I))' XDS_XIA2/XDS_XIA2_SUMMARY/XDS_XIA2_SUMMARY.log | awk '{print $2}')
    XDS_XIA2_cc_half=$(grep 'Mn(I) half-set correlation CC(1/2)' XDS_XIA2/XDS_XIA2_SUMMARY/XDS_XIA2_SUMMARY.log | awk '{print $5}')
    XDS_XIA2_completeness=$(grep 'Completeness' XDS_XIA2/XDS_XIA2_SUMMARY/XDS_XIA2_SUMMARY.log | awk '{print $2}')
    XDS_XIA2_multiplicity=$(grep 'Multiplicity' XDS_XIA2/XDS_XIA2_SUMMARY/XDS_XIA2_SUMMARY.log | awk '{print $2}')
    XDS_XIA2_space_group=$(grep 'Space group:' XDS_XIA2/XDS_XIA2_SUMMARY/XDS_XIA2_SUMMARY.log | cut -d ':' -f 2 | sed 's/ //g')
    XDS_XIA2_cell=$(grep 'Unit cell:' XDS_XIA2/XDS_XIA2_SUMMARY/XDS_XIA2_SUMMARY.log | cut -d ':' -f 2 | sed 's/^ *//g' | sed 's/ *$//g' | sed 's/  */ /g')
    printf "XDS_XIA2      %.2f       %.3f      %.1f     %.3f        %.1f           %.1f          %s     %.4f %.4f %.4f %.4f %.4f %.4f\n" ${XDS_XIA2_resolution} ${XDS_XIA2_rmerge} ${XDS_XIA2_i_over_sigma} ${XDS_XIA2_cc_half} ${XDS_XIA2_completeness} ${XDS_XIA2_multiplicity} ${XDS_XIA2_space_group} ${XDS_XIA2_cell}
    echo ""
fi

if [ -f "DIALS_XIA2/DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log" ]; then
    DIALS_XIA2_resolution=$(grep 'High resolution limit' DIALS_XIA2/DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log | awk '{print $4}')
    DIALS_XIA2_rmerge=$(grep 'Rmerge  (all I+ and I-)' DIALS_XIA2/DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log | awk '{print $6}')
    DIALS_XIA2_i_over_sigma=$(grep 'Mean((I)/sd(I))' DIALS_XIA2/DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log | awk '{print $2}')
    DIALS_XIA2_cc_half=$(grep 'Mn(I) half-set correlation CC(1/2)' DIALS_XIA2/DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log | awk '{print $5}')
    DIALS_XIA2_completeness=$(grep 'Completeness' DIALS_XIA2/DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log | awk '{print $2}')
    DIALS_XIA2_multiplicity=$(grep 'Multiplicity' DIALS_XIA2/DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log | awk '{print $2}')
    DIALS_XIA2_space_group=$(grep 'Space group:' DIALS_XIA2/DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log | cut -d ':' -f 2 | sed 's/ //g')
    DIALS_XIA2_cell=$(grep 'Unit cell:' DIALS_XIA2/DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log | cut -d ':' -f 2 | sed 's/^ *//g' | sed 's/ *$//g' | sed 's/  */ /g')
    printf "DIALS_XIA2    %.2f       %.3f      %.1f     %.3f        %.1f           %.1f          %s     %.4f %.4f %.4f %.4f %.4f %.4f\n" ${DIALS_XIA2_resolution} ${DIALS_XIA2_rmerge} ${DIALS_XIA2_i_over_sigma} ${DIALS_XIA2_cc_half} ${DIALS_XIA2_completeness} ${DIALS_XIA2_multiplicity} ${DIALS_XIA2_space_group} ${DIALS_XIA2_cell}
    echo ""
fi

if [ -f "autoPROC/autoPROC_SUMMARY/autoPROC_SUMMARY.log" ]; then
    autoPROC_resolution=$(grep 'High resolution limit' autoPROC/autoPROC_SUMMARY/autoPROC_SUMMARY.log | awk '{print $4}')
    autoPROC_rmerge=$(grep 'Rmerge  (all I+ and I-)' autoPROC/autoPROC_SUMMARY/autoPROC_SUMMARY.log | awk '{print $6}')
    autoPROC_i_over_sigma=$(grep 'Mean((I)/sd(I))' autoPROC/autoPROC_SUMMARY/autoPROC_SUMMARY.log | awk '{print $2}')
    autoPROC_cc_half=$(grep 'Mn(I) half-set correlation CC(1/2)' autoPROC/autoPROC_SUMMARY/autoPROC_SUMMARY.log | awk '{print $5}')
    autoPROC_completeness=$(grep 'Completeness' autoPROC/autoPROC_SUMMARY/autoPROC_SUMMARY.log | awk '{print $2}')
    autoPROC_multiplicity=$(grep 'Multiplicity' autoPROC/autoPROC_SUMMARY/autoPROC_SUMMARY.log | awk '{print $2}')
    autoPROC_space_group=$(grep 'Space group:' autoPROC/autoPROC_SUMMARY/autoPROC_SUMMARY.log | cut -d ':' -f 2 | sed 's/ //g')
    autoPROC_cell=$(grep 'Unit cell:' autoPROC/autoPROC_SUMMARY/autoPROC_SUMMARY.log | cut -d ':' -f 2 | sed 's/^ *//g' | sed 's/ *$//g' | sed 's/  */ /g')
    printf "autoPROC      %.2f       %.3f      %.1f     %.3f        %.1f           %.1f          %s     %.4f %.4f %.4f %.4f %.4f %.4f\n" ${autoPROC_resolution} ${autoPROC_rmerge} ${autoPROC_i_over_sigma} ${autoPROC_cc_half} ${autoPROC_completeness} ${autoPROC_multiplicity} ${autoPROC_space_group} ${autoPROC_cell}
    echo ""
fi

#Output best results
mkdir -p DATA_REDUCTION_SUMMARY

sort -k2,2n temp1.txt > sorted.txt
read -r best_rmerge best_point_group < <(awk 'NR==1 {print $1, $4}' sorted.txt)

declare -a names
declare -a point_groups
names+=("${best_rmerge}")
point_groups+=("${best_point_group}")

while IFS= read -r line; do
    read -r name point_group <<< $(echo $line | awk '{print $1, $4}')

    all_different=true
    for pg in "${point_groups[@]}"; do
        if [ "$point_group" == "$pg" ]; then
            all_different=false
            break
        fi
    done

    if [ "$all_different" = true ]; then
        names+=("${name}")
        point_groups+=("${point_group}")
    fi
done < <(tail -n +2 sorted.txt)

for name in "${names[@]}"; do
    cp "${name}/${name}_SUMMARY/${name}.mtz" "DATA_REDUCTION_SUMMARY/${name}.mtz"
    cp "${name}/${name}_SUMMARY/${name}_SUMMARY.log" "DATA_REDUCTION_SUMMARY/${name}_SUMMARY.log"
done

rm sorted.txt
#cp DATA_REDUCTION_SUMMARY/* ../SUMMARY
rm *.*

#Go to data processing folder
cd ..
mv DATA_REDUCTION.log DATA_REDUCTION/DATA_REDUCTION_SUMMARY
cp DATA_REDUCTION/DATA_REDUCTION_SUMMARY/DATA_REDUCTION.log SUMMARY
end_time=$(date +%s)
total_time=$((end_time - start_time))

hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))
echo "Data reduction took: ${hours}h ${minutes}m ${seconds}s" 
echo ""
