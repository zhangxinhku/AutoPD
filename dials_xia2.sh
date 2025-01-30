#!/bin/bash
#############################################################################################################
# Script Name: dials_xia2.sh
# Description: This script is used for xia2-dials.
# Author: ZHANG Xin
# Date Created: 2023-06-01
# Last Modified: 2024-03-05
#############################################################################################################

#Input variables
for arg in "$@"; do
    IFS="=" read -r key value <<< "$arg"
    case $key in
        round) ROUND="$value" ;;
        flag) FLAG_DIALS_XIA2="$value" ;;
        sp) SPACE_GROUP="$value" ;;
        cell_constants) UNIT_CELL_CONSTANTS="$value" ;;
    esac
done

#Determine whether running this script according to Flag_DIALS_XIA2
case "${FLAG_DIALS_XIA2}" in
    "")
        mkdir -p DIALS_XIA2
        cd DIALS_XIA2
        mkdir -p DIALS_XIA2_SUMMARY
        cd ..
        ;;
    "1")
        exit
        ;;
esac

#Beam center
if [ -n "${BEAM_X}" ]; then
    PIXEL_X=$(grep "Pixel size (X,Y)" header.log | awk '{print $6}' | cut -d ',' -f1)
    PIXEL_Y=$(grep "Pixel size (X,Y)" header.log | awk '{print $6}' | cut -d ',' -f2)
    BEAM_X=$(echo "scale=2; ${BEAM_X}*${PIXEL_X}" | bc)
    BEAM_Y=$(echo "scale=2; ${BEAM_Y}*${PIXEL_Y}" | bc)
    BEAM=${BEAM_X},${BEAM_Y}
else
    BEAM=""
fi

#Create folder for xia2-dials
cd DIALS_XIA2
mkdir -p DIALS_XIA2_${ROUND}
cd DIALS_XIA2_${ROUND}

#Optional parameters
args=()

for param in "goniometer.axes=${ROTATION_AXIS}" "xia2.settings.space_group=${SPACE_GROUP}" "xia2.settings.unit_cell=${UNIT_CELL_CONSTANTS}" "mosflm_beam_centre=${BEAM}"; do
    IFS="=" read -r key value <<< "$param"
    [ -n "$value" ] && args+=("$key=$value")
done

#xia2-dials processing

# Start the xia2 command in the background
xia2 pipeline=dials ${DATA_PATH} hdf5_plugin=${SOURCE_DIR}/durin-plugin.so ${args[@]} > /dev/null &
CMD_PID=$!

# Initialize a counter for the timeout (3600 seconds for 1 hour)
TIMEOUT=360000
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

if [ ! -f "DataFiles/AUTOMATIC_DEFAULT_free.mtz" ]; then
    FLAG_DIALS_XIA2=0
    echo "FLAG_DIALS_XIA2=${FLAG_DIALS_XIA2}" >> ../../temp.txt
    echo "Round ${ROUND} DIALS_XIA2 processing failed!"
    exit 1
fi

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

#Output DIALS_XIA2 processing result
cp DIALS_XIA2_${ROUND}/xia2.txt DIALS_XIA2_SUMMARY/DIALS_XIA2.log
cp DIALS_XIA2_${ROUND}/DataFiles/AUTOMATIC_DEFAULT_free.mtz DIALS_XIA2_SUMMARY/DIALS_XIA2.mtz
cp ../header.log DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log
echo "Refined parameters:" >> DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log
dials.show DIALS_XIA2_${ROUND}/DataFiles/*SWEEP1.expt > DIALS_XIA2_${ROUND}/DataFiles/SWEEP1.log
distance_refined=$(grep "distance" DIALS_XIA2_${ROUND}/DataFiles/SWEEP1.log | awk '{print $2}')
echo "Distance_refined               [mm] = ${distance_refined}" >> DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log
beam_center_refined=$(grep "px:" DIALS_XIA2_${ROUND}/DataFiles/SWEEP1.log | cut -d '(' -f2 | cut -d ')' -f1)
echo "Beam_center_refined         [pixel] = ${beam_center_refined}" >> DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log
rm DIALS_XIA2_${ROUND}/DataFiles/SWEEP1.log
${SOURCE_DIR}/dr_log.sh DIALS_XIA2_${ROUND}/LogFiles/AUTOMATIC_DEFAULT_aimless.log DIALS_XIA2_${ROUND}/LogFiles/AUTOMATIC_DEFAULT_ctruncate.log DIALS_XIA2_${ROUND}/LogFiles/pointless.log >> DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log

#Extract Rmerge Resolution Space group Point group
Rmerge_DIALS_XIA2=$(grep 'Rmerge  (all I+ and I-)' DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log | awk '{print $6}')
Resolution_DIALS_XIA2=$(grep 'High resolution limit' DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log | awk '{print $4}')
SG_DIALS_XIA2=$(grep 'Space group:' DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log | cut -d ':' -f 2 | sed 's/^ *//g' | sed 's/ //g')
PointGroup_DIALS_XIA2=$(${SOURCE_DIR}/sg2pg.sh ${SG_DIALS_XIA2})
Completeness_DIALS_XIA2=$(grep 'Completeness' DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log | awk '{print $2}')

#Determine running successful or failed using Rmerge 
if [ "${Rmerge_DIALS_XIA2}" = "" ];then
    FLAG_DIALS_XIA2=0
    echo "Round ${ROUND} DIALS_XIA2 processing failed!"
    rm DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log
    exit
elif [ $(echo "${Rmerge_DIALS_XIA2} <= 0" | bc) -eq 1 ] || [ $(echo "${Rmerge_DIALS_XIA2} >= 100" | bc) -eq 1 ];then
    FLAG_DIALS_XIA2=0
    echo "Round ${ROUND} DIALS_XIA2 processing failed!"
    rm DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log
    exit
else
    FLAG_DIALS_XIA2=1
    echo "Round ${ROUND} DIALS_XIA2 processing succeeded!"
    echo "DIALS_XIA2 ${Rmerge_DIALS_XIA2} ${Resolution_DIALS_XIA2} ${PointGroup_DIALS_XIA2} ${Completeness_DIALS_XIA2}" >> ../temp1.txt
fi

#For invoking in autopipeline_parrallel.sh
echo "FLAG_DIALS_XIA2=${FLAG_DIALS_XIA2}" >> ../temp.txt

#Extract statistics data
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

#Plot statistics figures
${SOURCE_DIR}/plot.sh ${L_statistic}

#Go back to data_reduction folder
cd ../..
