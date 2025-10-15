#!/bin/bash
#############################################################################################################
# Script Name: xds_xia2.sh
# Description: Automated wrapper script for running the xia2 pipelines (3d and 3dii) with XDS integration.
#              The script attempts data reduction using xia2 pipeline=3d first, and if that fails, falls back
#              to xia2 pipeline=3dii. It applies optional geometry and crystallographic parameters, monitors
#              runtime, and collects key statistics for summary and plotting.
#
# Usage Example:
#   ./xds_xia2.sh round=1 flag=0 sp="P212121" cell_constants="78.3 84.1 96.5 90 90 90"
#
# Required Environment Variables:
#   SOURCE_DIR     Path to helper scripts (e.g., plot.sh, dr_log.sh, durin-plugin.so)
#   DATA_PATH      Directory containing diffraction image files
#   FILE_TYPE      Format of diffraction images (e.g., h5, cbf, img)
#
# Optional Variables:
#   BEAM_X, BEAM_Y           Beam center in mm (converted to pixels using header.log)
#   DISTANCE                 Crystal-to-detector distance (mm)
#   IMAGE_START, IMAGE_END   Image range for processing
#   ROTATION_AXIS            Rotation axis vector (comma-separated, e.g., "1,0,0")
#   SPACE_GROUP              Space group symbol (e.g., "P212121")
#   UNIT_CELL_CONSTANTS      Unit cell parameters "a b c alpha beta gamma"
#
# Exit Codes:
#   0  Success
#   1  Failure (e.g., timeout, xia2 error, missing MTZ)
#
# Author:      ZHANG Xin
# Created:     2023-06-01
# Last Edited: 2024-08-03
#############################################################################################################

#############################################
# Parse command-line arguments
#############################################
for arg in "$@"; do
    IFS="=" read -r key value <<< "$arg"
    case $key in
        round) ROUND="$value" ;;
        flag) FLAG_XDS_XIA2="$value" ;;
        sp) SPACE_GROUP="$value" ;;
        cell_constants) UNIT_CELL_CONSTANTS="$value" ;;
    esac
done

# Override if input variables provided
if [[ -n "$SPACE_GROUP_INPUT" ]]; then
    SPACE_GROUP=$SPACE_GROUP_INPUT
fi
if [[ -n "$CELL_CONSTANTS_INPUT" ]]; then
    UNIT_CELL_CONSTANTS=$CELL_CONSTANTS_INPUT
fi
#############################################
# Determine whether running this script according to Flag_XDS_XIA2
#############################################
case "${FLAG_XDS_XIA2}" in
    "")
        mkdir -p XDS_XIA2
        cd XDS_XIA2
        mkdir -p XDS_XIA2_SUMMARY
        cd ..
        ;;
    "1")
        exit # Skip processing if already flagged as done
        ;;
esac

#############################################
# Compute beam center in pixels (if provided)
#############################################
if [ -n "${BEAM_X}" ]; then
    PIXEL_X=$(grep "Pixel size (X,Y)" header.log | awk '{print $6}' | cut -d ',' -f1)
    PIXEL_Y=$(grep "Pixel size (X,Y)" header.log | awk '{print $6}' | cut -d ',' -f2)
    BEAM_X=$(echo "scale=2; ${BEAM_X}*${PIXEL_X}" | bc)
    BEAM_Y=$(echo "scale=2; ${BEAM_Y}*${PIXEL_Y}" | bc)
    BEAM=${BEAM_X},${BEAM_Y}
else
    BEAM=""
fi

#############################################
# Prepare working directory
#############################################
cd XDS_XIA2
mkdir -p XDS_XIA2_${ROUND}
cd XDS_XIA2_${ROUND}

#############################################
# Collect optional parameters for xia2
#############################################
args=()

for param in "goniometer.axes=${ROTATION_AXIS}" "xia2.settings.space_group=${SPACE_GROUP}" "xia2.settings.unit_cell=${UNIT_CELL_CONSTANTS}" "mosflm_beam_centre=${BEAM}" "geometry.detector.distance=${DISTANCE}"; do
    IFS="=" read -r key value <<< "$param"
    [ -n "$value" ] && args+=("$key=$value")
done

#############################################
# Define a helper function to run xia2
# Monitors for errors or timeout
#############################################
run_xia2_with_timeout() {
    local pipeline=$1
    local timeout=$2
    local start_time=$(date +%s)
    if [ -n "${IMAGE_START}" ] && [ -n "${IMAGE_END}" ]; then
      if [ "${FILE_TYPE}" = "h5" ]; then
        IMAGE_NAME=$(find "${DATA_PATH}" -maxdepth 1 -type f -name "*master.h5" -print -quit | xargs realpath)
      else
        IMAGE_NAME=$(ls -1 "${DATA_PATH}" | head -1 | xargs -I{} realpath "${DATA_PATH}/{}")
      fi     
      xia2 pipeline=${pipeline} image=${IMAGE_NAME}:${IMAGE_START}:${IMAGE_END} hdf5_plugin=${SOURCE_DIR}/durin-plugin.so atom=X "${args[@]}" > /dev/null &
      local cmd_pid=$!
    else
      xia2 pipeline=${pipeline} ${DATA_PATH} hdf5_plugin=${SOURCE_DIR}/durin-plugin.so atom=X "${args[@]}" > /dev/null &
      local cmd_pid=$!
    fi

    while kill -0 $cmd_pid 2> /dev/null; do
      if [[ -e "xia2-error.txt" ]]; then
        #echo "Error detected: Round ${ROUND} XDS_XIA2 ${pipeline} processing failed!"
        kill $cmd_pid > /dev/null 2>&1
        return 1 # Signal failure
      fi

      local current_time=$(date +%s)
      local elapsed_time=$((current_time - start_time))

      if [[ $elapsed_time -ge $timeout ]]; then
        echo "Timeout: Round ${ROUND} XDS_XIA2 ${pipeline} command exceeded ${timeout} seconds."
        kill $cmd_pid > /dev/null 2>&1
        return 1 # Signal timeout
      fi

      sleep 10
    done

    wait $cmd_pid
    return 0 #Successful
}

#############################################
# Attempt xia2 pipeline=3d, fallback to 3dii
#############################################
mkdir xia2_3d
cd xia2_3d
mode=3d

if ! run_xia2_with_timeout "3d" 3600 || [ ! -f "DataFiles/AUTOMATIC_DEFAULT_free.mtz" ]; then
    # If 3d fails or times out, attempt to run 3dii
    cd ..
    mkdir -p xia2_3dii
    cd xia2_3dii
    mode=3dii
    if ! run_xia2_with_timeout "3dii" 3600; then
        echo "Round ${ROUND} XDS_XIA2 processing failed!"
        exit 1 # Exit if 3dii also fails or times out
    fi
fi

#############################################
# Post-processing with CCP4 tools
#############################################
if [ ! -f "DataFiles/AUTOMATIC_DEFAULT_free.mtz" ]; then
    FLAG_XDS_XIA2=0
    echo "FLAG_XDS_XIA2=${FLAG_XDS_XIA2}" >> ../../temp.txt
    echo "Round ${ROUND} XDS_XIA2 processing failed!"
    exit 1
fi

pointless hklin DataFiles/AUTOMATIC_DEFAULT_free.mtz hklout DataFiles/pointless.mtz > LogFiles/pointless.log

ctruncate -mtzin DataFiles/AUTOMATIC_DEFAULT_free.mtz -mtzout DataFiles/AUTOMATIC_DEFAULT_truncated.mtz -colin '/*/*/[IMEAN,SIGIMEAN]' -colano '/*/*/[I(+),SIGI(+),I(-),SIGI(-)]' > LogFiles/AUTOMATIC_DEFAULT_ctruncate.log
cd ../..

#############################################
# Save results and generate summary
#############################################
cp XDS_XIA2_${ROUND}/xia2_${mode}/xia2.txt XDS_XIA2_SUMMARY/XDS_XIA2.log
cp XDS_XIA2_${ROUND}/xia2_${mode}/DataFiles/AUTOMATIC_DEFAULT_free.mtz XDS_XIA2_SUMMARY/XDS_XIA2.mtz
cp ../header.log XDS_XIA2_SUMMARY/XDS_XIA2_SUMMARY.log

# Append refined detector parameters
echo "Refined parameters:" >> XDS_XIA2_SUMMARY/XDS_XIA2_SUMMARY.log
distance_refined=$(grep "CRYSTAL TO DETECTOR DISTANCE (mm)" XDS_XIA2_${ROUND}/xia2_${mode}/LogFiles/*CORRECT.log | awk '{print $6}')
echo "Distance_refined               [mm] = ${distance_refined}" >> XDS_XIA2_SUMMARY/XDS_XIA2_SUMMARY.log
beam_center_refined=$(grep "DETECTOR COORDINATES (PIXELS) OF DIRECT BEAM" XDS_XIA2_${ROUND}/xia2_${mode}/LogFiles/*CORRECT.log | awk '{print $7 "," $8}')
echo "Beam_center_refined         [pixel] = ${beam_center_refined}" >> XDS_XIA2_SUMMARY/XDS_XIA2_SUMMARY.log
${SOURCE_DIR}/dr_log.sh XDS_XIA2_${ROUND}/xia2_${mode}/LogFiles/AUTOMATIC_DEFAULT_aimless.log XDS_XIA2_${ROUND}/xia2_${mode}/LogFiles/AUTOMATIC_DEFAULT_ctruncate.log >> XDS_XIA2_SUMMARY/XDS_XIA2_SUMMARY.log

#############################################
# Evaluate Rmeas and determine success/failure
#############################################
Rmeas_XDS_XIA2=$(grep 'Rmeas (all I+ & I-)' XDS_XIA2_SUMMARY/XDS_XIA2_SUMMARY.log | awk '{print $6}')
Rmeas_XDS_XIA2=${Rmeas_XDS_XIA2:-0}

if [ $(echo "${Rmeas_XDS_XIA2} <= 0" | bc) -eq 1 ] || [ $(echo "${Rmeas_XDS_XIA2} >= 100" | bc) -eq 1 ];then
    FLAG_XDS_XIA2=0
    echo "Round ${ROUND} XDS_XIA2 processing failed!"
    rm XDS_XIA2_SUMMARY/XDS_XIA2_SUMMARY.log
    exit 1
else
    echo "FLAG_XDS_XIA2=1" >> ../temp.txt
    echo "Round ${ROUND} XDS_XIA2 processing succeeded!"
    echo "XDS_XIA2 ${Rmeas_XDS_XIA2}" >> ../temp1.txt
fi

#############################################
# Check for strong anomalous signal
#############################################
if grep -q "strong anomalous signal" "XDS_XIA2_SUMMARY/XDS_XIA2_SUMMARY.log" && grep -q "Estimate of the resolution limit" "XDS_XIA2_SUMMARY/XDS_XIA2_SUMMARY.log"; then
    echo "Strong anomalous signal found in XDS_XIA2.mtz"
    cp XDS_XIA2_SUMMARY/XDS_XIA2.mtz ../SAD_INPUT
fi

#############################################
# Extract statistics for plotting
#############################################
mkdir -p STATISTICS_FIGURES
cd STATISTICS_FIGURES

#cchalf_vs_resolution
grep -A25 '$TABLE:  Correlations CC(1/2) within dataset' ../XDS_XIA2_${ROUND}/xia2_${mode}/LogFiles/AUTOMATIC_DEFAULT_aimless.log | tail -20 > cchalf_vs_resolution.dat

#completeness_vs_resolution
grep -A24 '$TABLE:  Completeness & multiplicity v. resolution' ../XDS_XIA2_${ROUND}/xia2_${mode}/LogFiles/AUTOMATIC_DEFAULT_aimless.log | tail -20 > completeness_vs_resolution.dat

#i_over_sigma_vs_resolution & rmerge_rmeans_rpim_vs_resolution
grep -m1 -A28 '$TABLE:  Analysis against resolution' ../XDS_XIA2_${ROUND}/xia2_${mode}/LogFiles/AUTOMATIC_DEFAULT_aimless.log | tail -20 > analysis_vs_resolution.dat

#scales_vs_batch
start=$(($(grep -n '    N  Run    Phi    Batch     Mn(k)        0k      Number   Bfactor    Bdecay' ../XDS_XIA2_${ROUND}/xia2_${mode}/LogFiles/AUTOMATIC_DEFAULT_aimless.log | head -1 | cut -d ':' -f 1)+1))
end=$(($(grep -n '    N  Run    Phi    Batch     Mn(k)        0k      Number   Bfactor    Bdecay' ../XDS_XIA2_${ROUND}/xia2_${mode}/LogFiles/AUTOMATIC_DEFAULT_aimless.log | tail -1 | cut -d ':' -f 1)-2))
sed -n "${start},${end}p" ../XDS_XIA2_${ROUND}/xia2_${mode}/LogFiles/AUTOMATIC_DEFAULT_aimless.log > scales_vs_batch.dat

#rmerge_and_i_over_sigma_vs_batch
start=$(($(grep -n '    N   Batch    Mn(I)   RMSdev  I/rms  Rmerge    Number  Nrej Cm%poss  AnoCmp MaxRes CMlplc   Chi^2  Chi^2c SmRmerge' ../XDS_XIA2_${ROUND}/xia2_${mode}/LogFiles/AUTOMATIC_DEFAULT_aimless.log | head -1 | cut -d ':' -f 1)+1))
end=$(($(grep -n '    N   Batch    Mn(I)   RMSdev  I/rms  Rmerge    Number  Nrej Cm%poss  AnoCmp MaxRes CMlplc   Chi^2  Chi^2c SmRmerge' ../XDS_XIA2_${ROUND}/xia2_${mode}/LogFiles/AUTOMATIC_DEFAULT_aimless.log | tail -1 | cut -d ':' -f 1)-2))
sed -n "${start},${end}p" ../XDS_XIA2_${ROUND}/xia2_${mode}/LogFiles/AUTOMATIC_DEFAULT_aimless.log > rmerge_and_i_over_sigma_vs_batch.dat

#L_test
grep -A24 '$TABLE: L test for twinning:' ../XDS_XIA2_${ROUND}/xia2_${mode}/LogFiles/AUTOMATIC_DEFAULT_ctruncate.log | tail -21 > L_test.dat
L_statistic=$(grep 'L statistic =' ../XDS_XIA2_${ROUND}/xia2_${mode}/LogFiles/AUTOMATIC_DEFAULT_ctruncate.log | awk '{print $4}')

# Generate plots
${SOURCE_DIR}/plot.sh ${L_statistic}

#############################################
# Return to main directory
#############################################
cd ../..
