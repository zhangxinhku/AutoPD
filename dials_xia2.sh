#Input variables
DATAPATH=${1}
ROTATION_AXIS=${2}
ROUND=${3}
scr_dir=${4}
file_type=${5}
Flag_DIALS_XIA2=${6}
SPACE_GROUP=${7}
UNIT_CELL_CONSTANTS=$( echo ${8} | sed 's/  */,/g')

#Determine whether running this script according to Flag_DIALS_XIA2
case "${Flag_DIALS_XIA2}" in
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

cd DIALS_XIA2
mkdir -p DIALS_XIA2_${ROUND}
cd DIALS_XIA2_${ROUND}

#Rotation axis selection
case "${ROTATION_AXIS}" in
  "-1")
    REVERSE_ROTATION_AXIS=True
    ;;
  *)
    REVERSE_ROTATION_AXIS=False
    ;;
esac

#DIALS_XIA2 processing
if [ -z "${SPACE_GROUP}" ]; then
    xia2 pipeline=dials atom=Se ${DATAPATH} hdf5_plugin=${scr_dir}/dectris-neggia.so reverse_phi=${REVERSE_ROTATION_AXIS} misigma=1.500000 cc_half=0.300000 rmerge=2.000000 resolution.completeness=0.850000 > /dev/null &
    # Get the PID of the last command to wait for its completion later
    CMD_PID=$!

    # Loop to check for the file
    while kill -0 $CMD_PID 2> /dev/null; do
      if [[ -e "xia2-error.txt" ]]; then
        # Kill the xia2 process
        kill $CMD_PID
      fi
      sleep 2 # Check every 2 seconds
    done

    # Wait for your xia2 command to finish
    wait $CMD_PID
else
    xia2 pipeline=dials atom=Se ${DATAPATH} hdf5_plugin=${scr_dir}/dectris-neggia.so reverse_phi=${REVERSE_ROTATION_AXIS} xia2.settings.space_group=${SPACE_GROUP} xia2.settings.unit_cell=${UNIT_CELL_CONSTANTS} misigma=1.500000 cc_half=0.300000 rmerge=2.000000 resolution.completeness=0.850000 > /dev/null &
    # Get the PID of the last command to wait for its completion later
    CMD_PID=$!

    # Loop to check for the file
    while kill -0 $CMD_PID 2> /dev/null; do
      if [[ -e "xia2-error.txt" ]]; then
        # Kill the xia2 process
        kill $CMD_PID
      fi
      sleep 2 # Check every 2 seconds
    done

    # Wait for your xia2 command to finish
    wait $CMD_PID
fi

if [[ -e "xia2-error.txt" ]]; then
    Flag_DIALS_XIA2=0
    echo "Flag_DIALS_XIA2=${Flag_DIALS_XIA2}" >> ../../temp.txt
    echo "Round ${ROUND} DIALS_XIA2 processing failed!"
    exit 1
fi

if [ ! -f "DataFiles/AUTOMATIC_DEFAULT_free.mtz" ]; then
    Flag_DIALS_XIA2=0
    echo "Flag_DIALS_XIA2=${Flag_DIALS_XIA2}" >> ../../temp.txt
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
    Flag_DIALS_XIA2=0
    echo "Flag_DIALS_XIA2=${Flag_DIALS_XIA2}" >> ../../temp.txt
    echo "Round ${ROUND} DIALS_XIA2 processing failed!"
    exit 1
fi

ctruncate -mtzin DataFiles/AUTOMATIC_DEFAULT_free.mtz -mtzout DataFiles/AUTOMATIC_DEFAULT_truncated.mtz -colin '/*/*/[IMEAN,SIGIMEAN]' -colano '/*/*/[I(+),SIGI(+),I(-),SIGI(-)]' > LogFiles/AUTOMATIC_DEFAULT_ctruncate.log

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
${scr_dir}/dr_log.sh DIALS_XIA2_${ROUND}/LogFiles/AUTOMATIC_DEFAULT_aimless.log DIALS_XIA2_${ROUND}/LogFiles/AUTOMATIC_DEFAULT_ctruncate.log >> DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log

#Output Rmerge
Rmerge_DIALS_XIA2=$(grep 'Rmerge  (all I+ and I-)' DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log | awk '{print $6}')
Resolution_DIALS_XIA2=$(grep 'High resolution limit' DIALS_XIA2_SUMMARY/DIALS_XIA2_SUMMARY.log | awk '{print $4}')

#Determine running successful or failed using Rmerge 
if [ "${Rmerge_DIALS_XIA2}" = "" ];then
    Flag_DIALS_XIA2=0
    echo "Round ${ROUND} DIALS_XIA2 processing failed!"
elif [ $(echo "${Rmerge_DIALS_XIA2} <= 0" | bc) -eq 1 ];then
    Flag_DIALS_XIA2=0
    echo "Round ${ROUND} DIALS_XIA2 processing failed!"
else
    Flag_DIALS_XIA2=1
    echo "Round ${ROUND} DIALS_XIA2 processing succeeded!"
    echo "DIALS_XIA2 ${Rmerge_DIALS_XIA2} ${Resolution_DIALS_XIA2}" >> ../temp1.txt
fi

#For invoking in autopipeline_parrallel.sh
echo "Flag_DIALS_XIA2=${Flag_DIALS_XIA2}" >> ../temp.txt

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
${scr_dir}/plot.sh ${L_statistic}

#Go back to data_reduction folder
cd ../..
