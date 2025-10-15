#!/bin/bash
#############################################################################################################
# Script Name: data_reduction.sh
# Description: Orchestrates data reduction using multiple pipelines (XDS, xia2-XDS, xia2-DIALS, autoPROC).
#              Performs two rounds if necessary:
#                - First round: default parameters
#                - Second round: uses refined space group and unit cell from best first-round result
#              Outputs summaries, MTZ files, and statistics for downstream MR/SAD analysis.
#
# Usage Example:
#   ./data_reduction.sh
#
# Required Environment Variables:
#   SOURCE_DIR       Path to helper scripts (xds.sh, xds_xia2.sh, etc.)
#   DATA_PATH        Directory containing diffraction image files
#
# Optional Environment Variables (from autopipeline.sh):
#   SPACE_GROUP_INPUT      Initial space group (if known)
#   CELL_CONSTANTS_INPUT   Initial unit cell parameters (a b c α β γ)
#
# Outputs:
#   DATA_REDUCTION/             Main directory for reduction runs
#   DATA_REDUCTION_SUMMARY/     Summaries of logs and MTZ files from all pipelines
#   SAD_INPUT/                  For input to SAD if anomalous signal is found
#
# Exit Codes:
#   0   Success
#   1   Failure (no successful data reduction)
#
# Author:      ZHANG Xin
# Created:     2023-06-01
# Last Edited: 2025-08-03
#############################################################################################################

start_time=$(date +%s)

#############################################
# Determine input file type from DATA_PATH
#############################################
FILE_TYPE=$(find "${DATA_PATH}" -maxdepth 1 -type f ! -name '.*' | head -n 1 | awk -F. '{if (NF>1) print $NF}')
export FILE_TYPE

#############################################
# Create directory for data reduction
#############################################
mkdir -p DATA_REDUCTION
cd DATA_REDUCTION
mkdir -p DATA_REDUCTION_SUMMARY SAD_INPUT

#############################################
# Extract header information
#############################################
${SOURCE_DIR}/header.sh > header.log

#############################################
# First round of data processing
#############################################
echo ""
echo "-------------------------------- First round data processing --------------------------------"
echo ""
ROUND=1

parallel -u "{}" ::: "${SOURCE_DIR}/xds.sh round=${ROUND}" "${SOURCE_DIR}/xds_xia2.sh round=${ROUND}" "${SOURCE_DIR}/dials_xia2.sh round=${ROUND}" "${SOURCE_DIR}/autoproc.sh round=${ROUND}"

#############################################
# Gather success/failure flags from each tool
#############################################
flags=("FLAG_XDS" "FLAG_XDS_XIA2" "FLAG_DIALS_XIA2" "FLAG_autoPROC")

for flag in "${flags[@]}"; do
  value=$(grep "${flag}=" temp.txt | cut -d '=' -f 2)
  declare "${flag}=${value}"
done

#############################################
# Second round if needed
#############################################
echo ""
if [[ (${FLAG_XDS} -eq 1 && ${FLAG_XDS_XIA2} -eq 1 && ${FLAG_DIALS_XIA2} -eq 1 && ${FLAG_autoPROC} -eq 1) ]] || [[ -n "$CELL_CONSTANTS_INPUT" ]]; then
    echo "No need for second round data processing."
elif [[ (${FLAG_XDS} -eq 0 && ${FLAG_XDS_XIA2} -eq 0 && ${FLAG_DIALS_XIA2} -eq 0 && ${FLAG_autoPROC} -eq 0) ]];then
    echo "Data reduction failed."
    exit 1
else
    echo "-------------------------------- Second round data processing -------------------------------"
    echo ""
    # Select best first-round result (lowest Rmeas)
    BEST_1=$(cat "temp1.txt" | sort -k 2 | head -n 1 | cut -d ' ' -f 1)

    # Extract refined space group and cell parameters
    #SPACE_GROUP_NUMBER=$(grep 'Space group number:' ${BEST_1}/${BEST_1}_SUMMARY/${BEST_1}_SUMMARY.log | cut -d ':' -f 2 | sed 's/ //g')
    SPACE_GROUP=$(grep 'Space group:' ${BEST_1}/${BEST_1}_SUMMARY/${BEST_1}_SUMMARY.log | cut -d ':' -f 2 | sed 's/ //g')
    UNIT_CELL_CONSTANTS=$(grep 'Unit cell:' ${BEST_1}/${BEST_1}_SUMMARY/${BEST_1}_SUMMARY.log | cut -d ':' -f 2 | sed 's/^ *//g' | sed 's/ *$//g' | sed 's/  */,/g')
    UNIT_CELL="\"$(grep 'Unit cell:' ${BEST_1}/${BEST_1}_SUMMARY/${BEST_1}_SUMMARY.log | cut -d ':' -f 2 | sed 's/^ *//g' | sed 's/ *$//g')\"" # | sed 's/  */ /g'

    # Correct problematic space groups to their proper equivalents
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

#############################################
# Output summary results
#############################################
echo ""
echo "Data reduction summary:"
echo ""
echo "           Resolution   Rmerge   Rmeas   I/Sigma   CC(1/2)   Completeness   Multiplicity   Space group                           Cell"
echo ""

# Function to extract summary metrics from logs
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

# Collect results from all pipelines
extract_values "XDS/XDS_SUMMARY/XDS_SUMMARY.log" "XDS"
extract_values "XDS_XIA2/XDS_XIA2_SUMMARY/XDS_XIA2_SUMMARY.log" "XDS_XIA2"
extract_values "DIALS_XIA2/DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log" "DIALS_XIA2"
extract_values "autoPROC/autoPROC_SUMMARY/autoPROC_SUMMARY.log" "autoPROC"

# Copy MTZs and summaries into central summary folder
names=("XDS" "XDS_XIA2" "DIALS_XIA2" "autoPROC")
for name in "${names[@]}"; do
  if [ -f "${name}/${name}_SUMMARY/${name}.mtz" ]; then
    cp "${name}/${name}_SUMMARY/${name}.mtz" "DATA_REDUCTION_SUMMARY/${name}.mtz"
    cp "${name}/${name}_SUMMARY/${name}_SUMMARY.log" "DATA_REDUCTION_SUMMARY/${name}_SUMMARY.log"
  fi
done

# Cleanup temporary files
rm *.*

#############################################
# Report total timing
#############################################
end_time=$(date +%s)
total_time=$((end_time - start_time))
hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))
echo "Data reduction took: ${hours}h ${minutes}m ${seconds}s"
echo ""

# Move main log into summary folder
cd ..
mv DATA_REDUCTION.log DATA_REDUCTION/DATA_REDUCTION_SUMMARY
cp DATA_REDUCTION/DATA_REDUCTION_SUMMARY/DATA_REDUCTION.log SUMMARY
