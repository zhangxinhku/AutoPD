#!/bin/bash
#############################################################################################################
# Script Name: data_reduction.sh
# Description: This script is used for data reduction.
# Author: ZHANG Xin
# Date Created: 2023-06-01
# Last Modified: 2024-03-05
#############################################################################################################

start_time=$(date +%s)

#Input variables
#for arg in "$@"; do
#    IFS="=" read -r key value <<< "$arg"
#    case $key in
#        space_group) SPACE_GROUP="$value" ;;
#        cell_constants) UNIT_CELL_CONSTANTS="$value" ;;
#    esac

#done
#if [[ -n "$CELL_CONSTANTS_INPUT" ]]; then
#    UNIT_CELL="\"$(echo "$CELL_CONSTANTS_INPUT" | tr ',，' ' ')\""
#    UNIT_CELL_CONSTANTS=\"${UNIT_CELL_CONSTANTS}\"
#fi

#Optional parameters
#args=()

#for param in "sp=${SPACE_GROUP}" "cell_constants=${UNIT_CELL_CONSTANTS}"; do
#    IFS="=" read -r key value <<< "$param"
#    [ -n "$value" ] && args+=("$key=$value")
#done
#echo ${args[@]}

#Determine file type
FILE_TYPE=$(find "${DATA_PATH}" -maxdepth 1 -type f ! -name '.*' | head -n 1 | awk -F. '{if (NF>1) print $NF}')
export FILE_TYPE

#Create and enter folder for data reduction
mkdir -p DATA_REDUCTION
cd DATA_REDUCTION
mkdir -p DATA_REDUCTION_SUMMARY SAD_INPUT

#Extract header information
${SOURCE_DIR}/header.sh > header.log

#First round data processing
echo ""
echo "-------------------------------- First round data processing --------------------------------"
echo ""
ROUND=1

parallel -u "{}" ::: "${SOURCE_DIR}/xds.sh round=${ROUND}" "${SOURCE_DIR}/xds_xia2.sh round=${ROUND}" "${SOURCE_DIR}/dials_xia2.sh round=${ROUND}" "${SOURCE_DIR}/autoproc.sh round=${ROUND}"

#Set Flags
flags=("FLAG_XDS" "FLAG_XDS_XIA2" "FLAG_DIALS_XIA2" "FLAG_autoPROC")

for flag in "${flags[@]}"; do
  value=$(grep "${flag}=" temp.txt | cut -d '=' -f 2)
  declare "${flag}=${value}"
done

#Second round data processing
echo ""
if [[ (${FLAG_XDS} -eq 1 && ${FLAG_XDS_XIA2} -eq 1 && ${FLAG_DIALS_XIA2} -eq 1 && ${FLAG_autoPROC} -eq 1) ]] || [[ -n "$CELL_CONSTANTS_INPUT" ]]; then
    echo "No need for second round data processing."
elif [[ (${FLAG_XDS} -eq 0 && ${FLAG_XDS_XIA2} -eq 0 && ${FLAG_DIALS_XIA2} -eq 0 && ${FLAG_autoPROC} -eq 0) ]];then
    echo "Data reduction failed."
    exit 1
else
    echo "-------------------------------- Second round data processing -------------------------------"
    echo ""
    #Compare first round result
    BEST_1=$(cat "temp1.txt" | sort -k 2 | head -n 1 | cut -d ' ' -f 1)

    #Extract space group and cell parameters from best first round result
    #SPACE_GROUP_NUMBER=$(grep 'Space group number:' ${BEST_1}/${BEST_1}_SUMMARY/${BEST_1}_SUMMARY.log | cut -d ':' -f 2 | sed 's/ //g')
    SPACE_GROUP=$(grep 'Space group:' ${BEST_1}/${BEST_1}_SUMMARY/${BEST_1}_SUMMARY.log | cut -d ':' -f 2 | sed 's/ //g')
    UNIT_CELL_CONSTANTS=$(grep 'Unit cell:' ${BEST_1}/${BEST_1}_SUMMARY/${BEST_1}_SUMMARY.log | cut -d ':' -f 2 | sed 's/^ *//g' | sed 's/ *$//g' | sed 's/  */,/g')
    UNIT_CELL="\"$(grep 'Unit cell:' ${BEST_1}/${BEST_1}_SUMMARY/${BEST_1}_SUMMARY.log | cut -d ':' -f 2 | sed 's/^ *//g' | sed 's/ *$//g')\"" # | sed 's/  */ /g'

    #For second round input
    if [ "${SPACE_GROUP}" == "P2122" ] || [ "${SPACE_GROUP}" == "P2212" ]; then
      SPACE_GROUP="P2221"
    fi
    if [ "${SPACE_GROUP}" == "I121" ]; then
      SPACE_GROUP="C121"
    fi
    if [ "${SPACE_GROUP}" == "I1211" ]; then
      SPACE_GROUP="C1211"
    fi
    ROUND=2
    parallel -u ::: "${SOURCE_DIR}/xds.sh round=${ROUND} flag=${FLAG_XDS} sp=${SPACE_GROUP} cell_constants=\"${UNIT_CELL_CONSTANTS}\"" "${SOURCE_DIR}/xds_xia2.sh round=${ROUND} flag=${FLAG_XDS_XIA2} sp=${SPACE_GROUP} cell_constants=\"${UNIT_CELL_CONSTANTS}\"" "${SOURCE_DIR}/dials_xia2.sh round=${ROUND} flag=${FLAG_DIALS_XIA2} sp=${SPACE_GROUP} cell_constants=\"${UNIT_CELL_CONSTANTS}\"" "${SOURCE_DIR}/autoproc.sh round=${ROUND} flag=${FLAG_autoPROC} sp=${SPACE_GROUP} cell_constants=${UNIT_CELL}"
fi

#Output summary results
echo ""
echo "Data reduction summary:"
echo ""
echo "           Resolution   Rmerge   Rmeas   I/Sigma   CC(1/2)   Completeness   Multiplicity   Space group                           Cell"
echo ""

# Function to extract values from log files
extract_values() {
    local log_file=$1
    local prefix=$2

    if [ -f "${log_file}" ]; then
        local resolution=$(grep 'High resolution limit' ${log_file} | awk '{print $4}')
        local rmerge=$(grep 'Rmerge  (all I+ and I-)' ${log_file} | awk '{print $6}')
        local rmeas=$(grep 'Rmeas (all I+ & I-)' ${log_file} | awk '{print $6}')
        local i_over_sigma=$(grep 'Mean((I)/sd(I))' ${log_file} | awk '{print $2}')
        local cc_half=$(grep 'Mn(I) half-set correlation CC(1/2)' ${log_file} | awk '{print $5}')
        local completeness=$(grep 'Completeness' ${log_file} | awk '{print $2}')
        local multiplicity=$(grep 'Multiplicity' ${log_file} | awk '{print $2}')
        local space_group=$(grep 'Space group:' ${log_file} | cut -d ':' -f 2 | sed 's/ //g')
        local cell=$(grep 'Unit cell:' ${log_file} | cut -d ':' -f 2 | sed 's/^ *//g' | sed 's/ *$//g' | sed 's/  */ /g')

        printf "%-10s  %.2f       %.3f      %.3f     %.1f     %.3f        %.1f           %.1f          %s     %.4f %.4f %.4f %.4f %.4f %.4f\n" \
       "${prefix}" ${resolution} ${rmerge} ${rmeas} ${i_over_sigma} ${cc_half} ${completeness} ${multiplicity} ${space_group} ${cell}
        echo ""
    fi
}

# Extract results for different tools
extract_values "XDS/XDS_SUMMARY/XDS_SUMMARY.log" "XDS"
extract_values "XDS_XIA2/XDS_XIA2_SUMMARY/XDS_XIA2_SUMMARY.log" "XDS_XIA2"
extract_values "DIALS_XIA2/DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log" "DIALS_XIA2"
extract_values "autoPROC/autoPROC_SUMMARY/autoPROC_SUMMARY.log" "autoPROC"

names=("XDS" "XDS_XIA2" "DIALS_XIA2" "autoPROC")
for name in "${names[@]}"; do
  if [ -f "${name}/${name}_SUMMARY/${name}.mtz" ]; then
    cp "${name}/${name}_SUMMARY/${name}.mtz" "DATA_REDUCTION_SUMMARY/${name}.mtz"
    cp "${name}/${name}_SUMMARY/${name}_SUMMARY.log" "DATA_REDUCTION_SUMMARY/${name}_SUMMARY.log"
  fi
done

rm *.*

#Calculate and echo timing information
end_time=$(date +%s)
total_time=$((end_time - start_time))
hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))
echo "Data reduction took: ${hours}h ${minutes}m ${seconds}s"
echo ""

#Go to data processing folder
cd ..
mv DATA_REDUCTION.log DATA_REDUCTION/DATA_REDUCTION_SUMMARY
cp DATA_REDUCTION/DATA_REDUCTION_SUMMARY/DATA_REDUCTION.log SUMMARY
