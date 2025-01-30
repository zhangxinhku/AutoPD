#!/bin/bash
#############################################################################################################
# Script Name: autoproc.sh
# Description: This script is used for autoPROC.
# Author: ZHANG Xin
# Date Created: 2023-06-01
# Last Modified: 2024-03-05
#############################################################################################################

#Input variables
for arg in "$@"; do
    IFS="=" read -r key value <<< "$arg"
    case $key in
        round) ROUND="$value" ;;
        flag) FLAG_autoPROC="$value" ;;
        sp) SPACE_GROUP="$value" ;;
        cell_constants) UNIT_CELL="$value" ;;
    esac
done

#Determine whether running this script according to Flag_autoPROC
case "${FLAG_autoPROC}" in
    "")
        mkdir -p autoPROC
        cd autoPROC
        mkdir -p autoPROC_SUMMARY
        ;;
    "1")
        exit
        ;;
    "0")
        cd autoPROC
        ;;
esac 

#Beam center
if [ -n "${BEAM_X}" ]; then
    BEAM="${BEAM_X} ${BEAM_Y}"
else
    BEAM=""
fi

#Optional parameters
args=()

for param in "autoPROC_XdsKeyword_ROTATION_AXIS=${ROTATION_AXIS}" "beam=${BEAM}"; do
    IFS="=" read -r key value <<< "$param"
    [ -n "$value" ] && args+=("$key=$value")
done

#autoPROC processing
if [ "${FILE_TYPE}" = "h5" ]; then
    file_name=$(find "${DATA_PATH}" -maxdepth 1 -type f ! -name '.*' -name "*master.h5" -printf "%f")
    process -ANO -h5 ${DATA_PATH}/${file_name} -d autoPROC_${ROUND} symm=${SPACE_GROUP} cell="${UNIT_CELL}" ${args[@]} > autoPROC_${ROUND}.log
else
    process -ANO -I ${DATA_PATH} -d autoPROC_${ROUND} symm=${SPACE_GROUP} cell="${UNIT_CELL}" "${args[@]}" > autoPROC_${ROUND}.log
fi

if [ ! -f "autoPROC_${ROUND}/staraniso_alldata-unique.mtz" ]; then
    FLAG_autoPROC=0
    echo "FLAG_autoPROC=${FLAG_autoPROC}" >> ../temp.txt
    echo "Round ${ROUND} autoPROC processing failed!"
    exit
fi

{
ctruncate -mtzin autoPROC_${ROUND}/aimless.mtz -mtzout autoPROC_${ROUND}/aimless_truncated.mtz -colin '/*/*/[IMEAN,SIGIMEAN]' -colano '/*/*/[I(+),SIGI(+),I(-),SIGI(-)]' > autoPROC_${ROUND}/ctruncate.log
} 2>/dev/null

mv autoPROC_${ROUND}.log autoPROC_${ROUND}

#Output autoPROC processing result
cp autoPROC_${ROUND}/autoPROC_${ROUND}.log autoPROC_SUMMARY/autoPROC.log
cp autoPROC_${ROUND}/staraniso_alldata-unique.mtz autoPROC_SUMMARY/autoPROC.mtz
cp ../header.log autoPROC_SUMMARY/autoPROC_SUMMARY.log
echo "Refined parameters:" >> autoPROC_SUMMARY/autoPROC_SUMMARY.log
distance_refined=$(grep "CRYSTAL TO DETECTOR DISTANCE (mm)" autoPROC_${ROUND}/CORRECT.LP | awk '{print $6}')
echo "Distance_refined               [mm] = ${distance_refined}" >> autoPROC_SUMMARY/autoPROC_SUMMARY.log
beam_center_refined=$(grep "DETECTOR COORDINATES (PIXELS) OF DIRECT BEAM" autoPROC_${ROUND}/CORRECT.LP | awk '{print $7 "," $8}')
echo "Beam_center_refined         [pixel] = ${beam_center_refined}" >> autoPROC_SUMMARY/autoPROC_SUMMARY.log
${SOURCE_DIR}/dr_log.sh autoPROC_${ROUND}/aimless.log autoPROC_${ROUND}/ctruncate.log autoPROC_${ROUND}/pointless.log >> autoPROC_SUMMARY/autoPROC_SUMMARY.log

#Extract Rmerge Resolution Space group Point group
Rmerge_autoPROC=$(grep 'Rmerge  (all I+ and I-)' autoPROC_SUMMARY/autoPROC_SUMMARY.log | awk '{print $6}')
Resolution_autoPROC=$(grep 'High resolution limit' autoPROC_SUMMARY/autoPROC_SUMMARY.log | awk '{print $4}')
SG_autoPROC=$(grep 'Space group:' autoPROC_SUMMARY/autoPROC_SUMMARY.log | cut -d ':' -f 2 | sed 's/^ *//g' | sed 's/ //g')
PointGroup_autoPROC=$(${SOURCE_DIR}/sg2pg.sh ${SG_autoPROC})
Completeness_autoPROC=$(grep 'Completeness' autoPROC_SUMMARY/autoPROC_SUMMARY.log | awk '{print $2}')

#Determine running successful or failed using Rmerge 
if [ "${Rmerge_autoPROC}" = "" ];then
    FLAG_autoPROC=0
    echo "Round ${ROUND} autoPROC processing failed!"
    rm autoPROC_SUMMARY/autoPROC_SUMMARY.log
    exit
elif [ $(echo "${Rmerge_autoPROC} <= 0" | bc) -eq 1 ] || [ $(echo "${Rmerge_autoPROC} >= 100" | bc) -eq 1 ];then
    FLAG_autoPROC=0
    echo "Round ${ROUND} autoPROC processing failed!"
    rm autoPROC_SUMMARY/autoPROC_SUMMARY.log
    exit
else
    FLAG_autoPROC=1
    echo "Round ${ROUND} autoPROC processing succeeded!"
    echo "autoPROC ${Rmerge_autoPROC} ${Resolution_autoPROC} ${PointGroup_autoPROC} ${Completeness_autoPROC}" >> ../temp1.txt
fi

#For invoking in autopipeline.sh
echo "FLAG_autoPROC=${FLAG_autoPROC}" >> ../temp.txt

#Extract statistics data
mkdir -p STATISTICS_FIGURES
cd STATISTICS_FIGURES
#cchalf_vs_resolution
grep -A15 '$TABLE:  Correlations CC(1/2) within dataset' ../autoPROC_${ROUND}/aimless.log | tail -10 > cchalf_vs_resolution.dat
#completeness_vs_resolution
grep -A14 '$TABLE:  Completeness & multiplicity v. resolution' ../autoPROC_${ROUND}/aimless.log | tail -10 > completeness_vs_resolution.dat
#i_over_sigma_vs_resolution & rmerge_rmeans_rpim_vs_resolution
grep -m1 -A18 '$TABLE:  Analysis against resolution' ../autoPROC_${ROUND}/aimless.log | tail -10 > analysis_vs_resolution.dat
#scales_vs_batch
start=$(($(grep -n '    N  Run    Phi    Batch     Mn(k)        0k      Number   Bfactor    Bdecay' ../autoPROC_${ROUND}/aimless.log | head -1 | cut -d ':' -f 1)+1))
end=$(($(grep -n '    N  Run    Phi    Batch     Mn(k)        0k      Number   Bfactor    Bdecay' ../autoPROC_${ROUND}/aimless.log | tail -1 | cut -d ':' -f 1)-2))
sed -n "${start},${end}p" ../autoPROC_${ROUND}/aimless.log > scales_vs_batch.dat
#rmerge_and_i_over_sigma_vs_batch
start=$(($(grep -n '    N   Batch    Mn(I)   RMSdev  I/rms  Rmerge    Number  Nrej Cm%poss  AnoCmp MaxRes CMlplc   Chi^2  Chi^2c SmRmerge' ../autoPROC_$ROUND/aimless.log | head -1 | cut -d ':' -f 1)+1))
end=$(($(grep -n '    N   Batch    Mn(I)   RMSdev  I/rms  Rmerge    Number  Nrej Cm%poss  AnoCmp MaxRes CMlplc   Chi^2  Chi^2c SmRmerge' ../autoPROC_$ROUND/aimless.log | tail -1 | cut -d ':' -f 1)-2))
sed -n "${start},${end}p" ../autoPROC_${ROUND}/aimless.log > rmerge_and_i_over_sigma_vs_batch.dat
#L_test
grep -A24 '$TABLE: L test for twinning:' ../autoPROC_${ROUND}/ctruncate.log | tail -21 > L_test.dat
L_statistic=$(grep 'L statistic =' ../autoPROC_${ROUND}/ctruncate.log | awk '{print $4}')

#Plot statistics figures
${SOURCE_DIR}/plot.sh ${L_statistic}

#cp ../autoPROC_${ROUND}/SPOT.XDS_pre-cleanup.SpotsPerImage.png ../../DATA_REDUCTION_SUMMARY/spots_vs_batches.png

#Go back to data_reduction folder
cd ../..
