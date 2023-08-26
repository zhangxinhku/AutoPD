#Input variables
DATAPATH=${1}
ROTATION_AXIS=${2}
ROUND=${3}
scr_dir=${4}
file_type=${5}
Flag_autoPROC=${6}
SPACE_GROUP=${7}
UNIT_CELL_CONSTANTS=${8}

#Determine whether running this script according to Flag_autoPROC
case "${Flag_autoPROC}" in
    "")
        mkdir -p autoPROC
        cd autoPROC
        mkdir -p autoPROC_SUMMARY
        cd ..
        ;;
    "1")
        exit
        ;;
esac

cd autoPROC

#Rotation axis selection
case "${ROTATION_AXIS}" in
  "-1")
    REVERSE_ROTATION_AXIS=yes
    ;;
  *)
    REVERSE_ROTATION_AXIS=no
    ;;
esac

#autoPROC processing
if [ "${file_type}" = "h5" ]; then
    file_name=$(find ${DATAPATH} -maxdepth 1 -type f -name "*master.h5" -printf "%f")
    process -ANO -h5 ${DATAPATH}/${file_name} -d autoPROC_${ROUND} ReversePhi=${REVERSE_ROTATION_AXIS} symm="${SPACE_GROUP}" cell="${UNIT_CELL_CONSTANTS}" > autoPROC_${ROUND}.log
else
    process -ANO -I ${DATAPATH} -d autoPROC_${ROUND} ReversePhi=${REVERSE_ROTATION_AXIS} symm="${SPACE_GROUP}" cell="${UNIT_CELL_CONSTANTS}" > autoPROC_${ROUND}.log
fi

if [ ! -f "autoPROC_${ROUND}/truncate-unique.mtz" ]; then
    Flag_autoPROC=0
    echo "Flag_autoPROC=${Flag_autoPROC}" >> ../temp.txt
    echo "Round ${ROUND} autoPROC processing failed!"
    exit
fi

ctruncate -mtzin autoPROC_${ROUND}/aimless.mtz -mtzout autoPROC_${ROUND}/aimless_truncated.mtz -colin '/*/*/[IMEAN,SIGIMEAN]' -colano '/*/*/[I(+),SIGI(+),I(-),SIGI(-)]' > autoPROC_${ROUND}/ctruncate.log
mv autoPROC_${ROUND}.log autoPROC_${ROUND}

#Output autoPROC processing result
cp autoPROC_${ROUND}/autoPROC_${ROUND}.log autoPROC_SUMMARY/autoPROC.log
cp autoPROC_${ROUND}/truncate-unique.mtz autoPROC_SUMMARY/autoPROC.mtz
cp ../header.log autoPROC_SUMMARY/autoPROC_SUMMARY.log
echo "Refined parameters:" >> autoPROC_SUMMARY/autoPROC_SUMMARY.log
distance_refined=$(grep "CRYSTAL TO DETECTOR DISTANCE (mm)" autoPROC_${ROUND}/CORRECT.LP | awk '{print $6}')
echo "Distance_refined               [mm] = ${distance_refined}" >> autoPROC_SUMMARY/autoPROC_SUMMARY.log
beam_center_refined=$(grep "DETECTOR COORDINATES (PIXELS) OF DIRECT BEAM" autoPROC_${ROUND}/CORRECT.LP | awk '{print $7 "," $8}')
echo "Beam_center_refined         [pixel] = ${beam_center_refined}" >> autoPROC_SUMMARY/autoPROC_SUMMARY.log
${scr_dir}/dr_log.sh autoPROC_${ROUND}/aimless.log autoPROC_${ROUND}/ctruncate.log >> autoPROC_SUMMARY/autoPROC_SUMMARY.log

#Output Rmerge
Rmerge_autoPROC=$(grep 'Rmerge  (all I+ and I-)' autoPROC_SUMMARY/autoPROC_SUMMARY.log | awk '{print $6}')
Resolution_autoPROC=$(grep 'High resolution limit' autoPROC_SUMMARY/autoPROC_SUMMARY.log | awk '{print $4}')

#Determine running successful or failed using Rmerge 
if [ "${Rmerge_autoPROC}" = "" ];then
    Flag_autoPROC=0
    echo "Round ${ROUND} autoPROC processing failed!"
elif [ $(echo "${Rmerge_autoPROC} <= 0" | bc) -eq 1 ];then
    Flag_autoPROC=0
    echo "Round ${ROUND} autoPROC processing failed!"
else
    Flag_autoPROC=1
    echo "Round ${ROUND} autoPROC processing succeeded!"
    echo "autoPROC ${Rmerge_autoPROC} ${Resolution_autoPROC}" >> ../temp1.txt
fi

#For invoking in autopipeline_parrallel.sh
echo "Flag_autoPROC=${Flag_autoPROC}" >> ../temp.txt

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
${scr_dir}/plot.sh ${L_statistic}

#cp ../autoPROC_${ROUND}/SPOT.XDS_pre-cleanup.SpotsPerImage.png ../../DATA_REDUCTION_SUMMARY/spots_vs_batches.png

#Go back to data_reduction folder
cd ../..
