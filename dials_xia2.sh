#!/bin/bash
#############################################################################################################
# Script Name: dials_xia2.sh
# Description: Automated wrapper for the xia2 pipeline using DIALS.
#              This script runs xia2 with the DIALS backend, applies optional geometry and space group
#              parameters, monitors for runtime errors or timeouts, and collects processed data.
#              Post-processing includes AIMLESS, CTRUNCATE, and Pointless, and results are summarized
#              with refined parameters and statistical plots.
#
# Usage Example:
#   ./dials_xia2.sh round=1 flag=0 sp="P212121" cell_constants="78.3 84.1 96.5 90 90 90"
#
# Required Environment Variables:
#   SOURCE_DIR     Path to helper scripts (e.g., plot.sh, dr_log.sh, durin-plugin.so)
#   DATA_PATH      Directory containing diffraction image files
#   FILE_TYPE      Format of diffraction images (e.g., h5, cbf, img)
#
# Optional Variables:
#   BEAM_X, BEAM_Y           Beam center in mm (converted to pixels from header.log)
#   DISTANCE                 Crystal-to-detector distance (mm)
#   IMAGE_START, IMAGE_END   Image range for processing
#   ROTATION_AXIS            Rotation axis vector (comma-separated, e.g., "1,0,0")
#   SPACE_GROUP              Space group symbol (e.g., "P212121")
#   UNIT_CELL_CONSTANTS      Unit cell parameters "a b c alpha beta gamma"
#
# Exit Codes:
#   0  Success
#   1  Failure (error, timeout, or missing MTZ file)
#
# Author:      ZHANG Xin
# Created:     2023-06-01
# Last Edited: 2025-08-03
#############################################################################################################

#############################################
# Parse command-line arguments
#############################################
for arg in "$@"; do
    IFS="=" read -r key value <<< "$arg"
    case $key in
        round) ROUND="$value" ;;
        flag) FLAG_DIALS_XIA2="$value" ;;
        sp) SPACE_GROUP="$value" ;;
        cell_constants) UNIT_CELL_CONSTANTS="$value" ;;
    esac
done

# Allow overrides from input variables
if [[ -n "$SPACE_GROUP_INPUT" ]]; then
    SPACE_GROUP=$SPACE_GROUP_INPUT
fi
if [[ -n "$CELL_CONSTANTS_INPUT" ]]; then
    UNIT_CELL_CONSTANTS=$CELL_CONSTANTS_INPUT
fi

#Determine whether running this script according to Flag_DIALS_XIA2
case "${FLAG_DIALS_XIA2}" in
    "")
        mkdir -p DIALS_XIA2
        cd DIALS_XIA2
        mkdir -p DIALS_XIA2_SUMMARY
        cd ..
        ;;
    "1")
        exit # Skip processing if flagged as complete
        ;;
esac

#############################################
# Compute beam center in pixels if provided
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
cd DIALS_XIA2
mkdir -p DIALS_XIA2_${ROUND}
cd DIALS_XIA2_${ROUND}

#############################################
# Collect optional arguments for xia2
#############################################
args=()

for param in "goniometer.axes=${ROTATION_AXIS}" "xia2.settings.space_group=${SPACE_GROUP}" "xia2.settings.unit_cell=${UNIT_CELL_CONSTANTS}" "mosflm_beam_centre=${BEAM}" "geometry.detector.distance=${DISTANCE}"; do
    IFS="=" read -r key value <<< "$param"
    [ -n "$value" ] && args+=("$key=$value")
done

#############################################
# Run xia2 with pipeline=dials
# Start asynchronously to monitor timeout/errors
#############################################d
if [ -n "${IMAGE_START}" ] && [ -n "${IMAGE_END}" ]; then
  if [ "${FILE_TYPE}" = "h5" ]; then
    IMAGE_NAME=$(find "${DATA_PATH}" -maxdepth 1 -type f -name "*master.h5" -print -quit | xargs realpath)
  else
    IMAGE_NAME=$(ls -1 "${DATA_PATH}" | head -1 | xargs -I{} realpath "${DATA_PATH}/{}")
  fi     
  xia2 pipeline=dials image=${IMAGE_NAME}:${IMAGE_START}:${IMAGE_END} hdf5_plugin=${SOURCE_DIR}/durin-plugin.so atom=X "${args[@]}" > /dev/null &
  CMD_PID=$!
else
  xia2 pipeline=dials ${DATA_PATH} hdf5_plugin=${SOURCE_DIR}/durin-plugin.so atom=X "${args[@]}" > /dev/null &
  CMD_PID=$!
fi

#############################################
# Monitor runtime and check for errors
#############################################
TIMEOUT=36000 # 10 hours max runtime
COUNTER=0

# Loop to check both the file and the timeout
while kill -0 $CMD_PID 2> /dev/null; do
  if [[ -e "xia2-error.txt" ]]; then
    FLAG_DIALS_XIA2=0
    echo "FLAG_DIALS_XIA2=${FLAG_DIALS_XIA2}" >> ../../temp.txt
    echo "Round ${ROUND} DIALS_XIA2 processing failed!"
    exit 1
  fi

  # Break the loop if the command runs more than the timeout
  if [[ $COUNTER -ge $TIMEOUT ]]; then
    echo "Round ${ROUND} DIALS_XIA2 processing failed! Timeout!"
    kill $CMD_PID
    exit 1
  fi

  sleep 10 # Check every 2 seconds
  ((COUNTER+=10)) # Increment the counter by 2 for each sleep
done

# Wait for your xia2 command to finish if it didn't time out
wait $CMD_PID

#############################################
# Check for successful MTZ output
#############################################
if [ ! -f "DataFiles/AUTOMATIC_DEFAULT_free.mtz" ]; then
    FLAG_DIALS_XIA2=0
    echo "FLAG_DIALS_XIA2=${FLAG_DIALS_XIA2}" >> ../../temp.txt
    echo "Round ${ROUND} DIALS_XIA2 processing failed!"
    exit 1
fi

#############################################
# Post-processing with AIMLESS, CTRUNCATE, and Pointless
#############################################
aimless hklin DEFAULT/scale/AUTOMATIC_DEFAULT_scaled_unmerged.mtz hklout DEFAULT/scale/AUTOMATIC_DEFAULT_aimless.mtz > LogFiles/AUTOMATIC_DEFAULT_aimless.log << EOF
bins 20
scales constant
anomalous on
output unmerged
EOF

if [ ! -f "DEFAULT/scale/AUTOMATIC_DEFAULT_aimless.mtz" ]; then
    FLAG_DIALS_XIA2=0
    echo "FLAG_DIALS_XIA2=${FLAG_DIALS_XIA2}" >> ../../temp.txt
    echo "Round ${ROUND} DIALS_XIA2 processing failed!"
    exit 1
fi

ctruncate -mtzin DataFiles/AUTOMATIC_DEFAULT_free.mtz -mtzout DataFiles/AUTOMATIC_DEFAULT_truncated.mtz -colin '/*/*/[IMEAN,SIGIMEAN]' -colano '/*/*/[I(+),SIGI(+),I(-),SIGI(-)]' > LogFiles/AUTOMATIC_DEFAULT_ctruncate.log

pointless hklin DataFiles/AUTOMATIC_DEFAULT_free.mtz hklout DataFiles/pointless.mtz > LogFiles/pointless.log

cd ..

#############################################
# Save results and refined parameters
#############################################
cp DIALS_XIA2_${ROUND}/xia2.txt DIALS_XIA2_SUMMARY/DIALS_XIA2.log
cp DIALS_XIA2_${ROUND}/DataFiles/AUTOMATIC_DEFAULT_free.mtz DIALS_XIA2_SUMMARY/DIALS_XIA2.mtz
cp ../header.log DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log

# Extract refined geometry from DIALS experiment file
echo "Refined parameters:" >> DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log
dials.show DIALS_XIA2_${ROUND}/DataFiles/*SWEEP1.expt > DIALS_XIA2_${ROUND}/DataFiles/SWEEP1.log
distance_refined=$(grep "distance" DIALS_XIA2_${ROUND}/DataFiles/SWEEP1.log | awk '{print $2}')
echo "Distance_refined               [mm] = ${distance_refined}" >> DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log
beam_center_refined=$(grep "px:" DIALS_XIA2_${ROUND}/DataFiles/SWEEP1.log | cut -d '(' -f2 | cut -d ')' -f1)
echo "Beam_center_refined         [pixel] = ${beam_center_refined}" >> DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log
rm DIALS_XIA2_${ROUND}/DataFiles/SWEEP1.log
${SOURCE_DIR}/dr_log.sh DIALS_XIA2_${ROUND}/LogFiles/AUTOMATIC_DEFAULT_aimless.log DIALS_XIA2_${ROUND}/LogFiles/AUTOMATIC_DEFAULT_ctruncate.log DIALS_XIA2_${ROUND}/LogFiles/pointless.log >> DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log

#############################################
# Evaluate Rmeas and determine success/failure
#############################################
Rmeas_DIALS_XIA2=$(grep 'Rmeas (all I+ & I-)' DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log | awk '{print $6}')
Rmeas_DIALS_XIA2=${Rmeas_DIALS_XIA2:-0}

if [ $(echo "${Rmeas_DIALS_XIA2} <= 0" | bc) -eq 1 ] || [ $(echo "${Rmeas_DIALS_XIA2} >= 100" | bc) -eq 1 ];then
    FLAG_DIALS_XIA2=0
    echo "Round ${ROUND} DIALS_XIA2 processing failed!"
    rm DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log
    exit 1
else
    echo "FLAG_DIALS_XIA2=1" >> ../temp.txt
    echo "Round ${ROUND} DIALS_XIA2 processing succeeded!"
    echo "DIALS_XIA2 ${Rmeas_DIALS_XIA2}" >> ../temp1.txt
fi

#############################################
# Check for strong anomalous signal
#############################################
if grep -q "strong anomalous signal" "DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log" && grep -q "Estimate of the resolution limit" "DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log"; then
    echo "Strong anomalous signal found in DIALS_XIA2.mtz"
    cp DIALS_XIA2_SUMMARY/DIALS_XIA2.mtz ../SAD_INPUT
fi

#############################################
# Extract statistics for plotting
#############################################
mkdir -p STATISTICS_FIGURES
cd STATISTICS_FIGURES

#cchalf_vs_resolution
grep -A25 '$TABLE:  Correlations CC(1/2) within dataset' ../DIALS_XIA2_${ROUND}/LogFiles/AUTOMATIC_DEFAULT_aimless.log | tail -20 > cchalf_vs_resolution.dat

#completeness_vs_resolution
grep -A24 '$TABLE:  Completeness & multiplicity v. resolution' ../DIALS_XIA2_${ROUND}/LogFiles/AUTOMATIC_DEFAULT_aimless.log | tail -20 > completeness_vs_resolution.dat

#i_over_sigma_vs_resolution & rmerge_rmeans_rpim_vs_resolution
grep -m1 -A28 '$TABLE:  Analysis against resolution' ../DIALS_XIA2_${ROUND}/LogFiles/AUTOMATIC_DEFAULT_aimless.log | tail -20 > analysis_vs_resolution.dat

#scales_vs_batch
start=$(($(grep -n '    N  Run    Phi    Batch     Mn(k)        0k      Number   Bfactor    Bdecay' ../DIALS_XIA2_${ROUND}/LogFiles/AUTOMATIC_DEFAULT_aimless.log | head -1 | cut -d ':' -f 1)+1))
end=$(($(grep -n '    N  Run    Phi    Batch     Mn(k)        0k      Number   Bfactor    Bdecay' ../DIALS_XIA2_${ROUND}/LogFiles/AUTOMATIC_DEFAULT_aimless.log | tail -1 | cut -d ':' -f 1)-2))
sed -n "${start},${end}p" ../DIALS_XIA2_${ROUND}/LogFiles/AUTOMATIC_DEFAULT_aimless.log > scales_vs_batch.dat

#rmerge_and_i_over_sigma_vs_batch
start=$(($(grep -n '    N   Batch    Mn(I)   RMSdev  I/rms  Rmerge    Number  Nrej Cm%poss  AnoCmp MaxRes CMlplc   Chi^2  Chi^2c SmRmerge' ../DIALS_XIA2_${ROUND}/LogFiles/AUTOMATIC_DEFAULT_aimless.log | head -1 | cut -d ':' -f 1)+1))
end=$(($(grep -n '    N   Batch    Mn(I)   RMSdev  I/rms  Rmerge    Number  Nrej Cm%poss  AnoCmp MaxRes CMlplc   Chi^2  Chi^2c SmRmerge' ../DIALS_XIA2_${ROUND}/LogFiles/AUTOMATIC_DEFAULT_aimless.log | tail -1 | cut -d ':' -f 1)-2))
sed -n "${start},${end}p" ../DIALS_XIA2_${ROUND}/LogFiles/AUTOMATIC_DEFAULT_aimless.log > rmerge_and_i_over_sigma_vs_batch.dat

#L_test
grep -A24 '$TABLE: L test for twinning:' ../DIALS_XIA2_${ROUND}/LogFiles/AUTOMATIC_DEFAULT_ctruncate.log | tail -21 > L_test.dat
L_statistic=$(grep 'L statistic =' ../DIALS_XIA2_${ROUND}/LogFiles/AUTOMATIC_DEFAULT_ctruncate.log | awk '{print $4}')

# Generate plots
${SOURCE_DIR}/plot.sh ${L_statistic}

#############################################
# Return to main directory
#############################################
cd ../..
