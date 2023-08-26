start_time=$(date +%s)

#Input variables
DATAPATH=${1}
ROTATION_AXIS=${2}
ROUND=${3}
scr_dir=${4}
file_type=${5}
processor=${6}
Flag_DIALS=${7}
SPACE_GROUP=${8}
UNIT_CELL_CONSTANTS=$( echo ${9} | sed 's/  */,/g')

#Determine whether running this script according to Flag_DIALS
case "${Flag_DIALS}" in
    "")
        mkdir DIALS
        cd DIALS
        mkdir DIALS_SUMMARY
        cd ..
        ;;
    "1")
        rm DIALS_${ROUND}.log
        exit
        ;;
esac

cd DIALS
mkdir DIALS_${ROUND}
cd DIALS_${ROUND}

#Rotation axis selection
case "${ROTATION_AXIS}" in
  "-1")
    ROTATION_AXIS=-1
    ;;
  *)
    ROTATION_AXIS=1
    ;;
esac

#DIALS processing

#1_import
case "${file_type}" in
  "h5")
    file_name=$(find ${DATAPATH} -maxdepth 1 -type f -name "*master.h5" -printf "%f")
    dials.import ${DATAPATH}/${file_name} geometry.goniometer.axes=${ROTATION_AXIS},0,0
    ;;
  *)
    dials.import ${DATAPATH} geometry.goniometer.axes=${ROTATION_AXIS},0,0
    ;;
esac
cp dials.import.log 1_dials.import.log
cp imported.expt 1_imported.expt
#2_generate_masks
#3_find_spots
dials.find_spots imported.expt
cp dials.find_spots.log 3_dials.find_spots.log
cp strong.refl 3_strong.refl
#4_index
if [ -z "${SPACE_GROUP}" ]; then
    dials.index imported.expt strong.refl image_range="1 10"
else
    dials.index imported.expt strong.refl space_group=${SPACE_GROUP} unit_cell=${UNIT_CELL_CONSTANTS} image_range="1 10"
fi
cp dials.index.log 4_dials.index.log
cp indexed.expt 4_indexed.expt
cp indexed.refl 4_indexed.refl
#5_refine_bravais_settings
dials.refine_bravais_settings indexed.expt indexed.refl
cp dials.refine_bravais_settings.log 5_dials.refine_bravais_settings.log
#6_refine
dials.refine indexed.expt indexed.refl
cp dials.refine.log 6_dials.refine.log
cp refined.expt 6_refined.expt
#7_integrate
dials.integrate refined.expt refined.refl
cp dials.integrate.log 7_dials.integrate.log
cp integrated.expt 7_integrated.expt
cp integrated.refl 7_integrated.refl
#8_two_theta_refine
dials.two_theta_refine integrated.expt integrated.refl
cp dials.two_theta_refine.log 8_dials.two_theta_refine.log
cp refined_cell.expt 8_refined_cell.expt
#9_export
dials.export refined_cell.expt integrated.refl
cp dials.export.log 9_dials.export.log
cp integrated.mtz 9_integrated.mtz
#10_pointless
pointless hklin integrated.mtz hklout pointless.mtz > pointless.log
cp pointless.log 10_pointless.log
#11_index
SPACE_GROUP=$(grep "* Space group =" pointless.log | cut -d "'" -f2 | sed 's/  *//g')
UNIT_CELL_CONSTANTS=$(grep -A2 "* Cell Dimensions :" pointless.log | tail -n 1 | sed 's/^ *//g' | sed 's/ *$//g' | sed 's/  */,/g')
dials.index imported.expt strong.refl space_group=${SPACE_GROUP} unit_cell=${UNIT_CELL_CONSTANTS}
cp dials.index.log 11_dials.index.log
cp indexed.expt 11_indexed.expt
cp indexed.refl 11_indexed.refl
#12_refine
dials.refine indexed.expt indexed.refl
cp dials.refine.log 12_dials.refine.log
cp refined.expt 12_refined.expt
#13_integrate
dials.integrate refined.expt refined.refl
cp dials.integrate.log 13_dials.integrate.log
cp integrated.expt 13_integrated.expt
cp integrated.refl 13_integrated.refl
#14_two_theta_refine
dials.two_theta_refine integrated.expt integrated.refl
cp dials.two_theta_refine.log 14_dials.two_theta_refine.log
cp refined_cell.expt 14_refined_cell.expt
#15_export
dials.export refined_cell.expt integrated.refl
cp dials.export.log 15_dials.export.log
cp integrated.mtz 15_integrated.mtz
#16_pointless
pointless hklin integrated.mtz hklout pointless.mtz > pointless.log
cp pointless.log 16_pointless.log
#17_aimless
aimless hklin pointless.mtz hklout DIALS.mtz xmlout aimless.xml scalepack DIALS.sca > aimless.log << EOF
RUN 1 ALL
BINS 20
ANOMALOUS ON
INTENSITIES COMBINE
RESOLUTION LOW 999 HIGH 0.000000
REFINE PARALLEL AUTO
SDCORRECTION SAME
CYCLES 100
OUTPUT MTZ MERGED UNMERGED
OUTPUT SCALEPACK MERGED
EOF
cp aimless.log 17_aimless.log
cp aimless.xml 17_aimless.xml
#18_estimate_resolution
dials.estimate_resolution DIALS_unmerged.mtz misigma=2.0 completeness=0.85 rmerge=2.0 > /dev/null
cp dials.estimate_resolution.log 18_dials.estimate_resolution.log
cp dials.estimate_resolution.html 18_dials.estimate_resolution.html
resolution=$(tail -n 3 dials.estimate_resolution.log | awk '{print $NF}' | sort -nr | head -n 1)
#19_aimless
aimless hklin pointless.mtz hklout DIALS.mtz xmlout aimless.xml scalepack DIALS.sca > aimless.log << EOF
RUN 1 ALL
BINS 20
ANOMALOUS ON
INTENSITIES COMBINE
RESOLUTION LOW 999 HIGH ${resolution}
REFINE PARALLEL AUTO
SDCORRECTION SAME
CYCLES 100
OUTPUT MTZ MERGED UNMERGED
OUTPUT SCALEPACK MERGED
EOF
cp aimless.log 19_aimless.log
cp aimless.xml 19_aimless.xml
#20_ctruncate
ctruncate -mtzin DIALS.mtz -mtzout DIALS_truncated.mtz -colin '/*/*/[IMEAN,SIGIMEAN]' -colano '/*/*/[I(+),SIGI(+),I(-),SIGI(-)]' > ctruncate.log
cp ctruncate.log 20_ctruncate.log
#21_freeR_flag
freerflag hklin DIALS_truncated.mtz hklout DIALS_free.mtz > freeR_flag.log << EOF
FREERFRAC 0.05
UNIQUE
EOF
cp freeR_flag.log 21_freeR_flag.log
cd ..

#Output DIALS processing result
cp DIALS_${ROUND}/DIALS.mtz DIALS_SUMMARY/DIALS.mtz
cp ../header.log DIALS_SUMMARY/DIALS.log
dials.show DIALS_${ROUND}/refined.expt > DIALS_${ROUND}/refined.log
distance_end=$(grep "distance:" DIALS_${ROUND}/refined.log | awk '{print $2}')
echo "Distance_refined               [mm] = ${distance_end}" >> DIALS_SUMMARY/DIALS.log
beam_center_x_end=$(grep "px:" DIALS_${ROUND}/refined.log | cut -d '(' -f2 | cut -d ',' -f1)
echo "Beam_center_x_refined       [pixel] = ${beam_center_x_end}" >> DIALS_SUMMARY/DIALS.log
beam_center_y_end=$(grep "px:" DIALS_${ROUND}/refined.log | cut -d ',' -f2 | cut -d ')' -f1)
echo "Beam_center_y_refined       [pixel] = ${beam_center_y_end}" >> DIALS_SUMMARY/DIALS.log
rm DIALS_${ROUND}/refined.log
${scr_dir}/dr_log.sh DIALS_${ROUND}/aimless.log DIALS_${ROUND}/ctruncate.log >> DIALS_SUMMARY/DIALS.log

#Output Rmerge
Rmerge_DIALS=$(grep 'Rmerge  (all I+ and I-)' DIALS_SUMMARY/DIALS.log | awk '{print $6}')

#Determine running successful or failed using Rmerge 
if [ "${Rmerge_DIALS}" = "" ];then
    Rmerge_DIALS=0
    Flag_DIALS=0
    echo "Round ${ROUND} DIALS processing failed!"
elif [ $(echo "${Rmerge_DIALS} <= 0" | bc) -eq 1 ];then
    Rmerge_DIALS=0
    Flag_DIALS=0
    echo "Round ${ROUND} DIALS processing failed!"
else
    Flag_DIALS=1
    echo "Round ${ROUND} DIALS processing succeeded!"
    echo "DIALS ${Rmerge_DIALS}" >> ../temp1.txt
    #echo $Rmerge_DIALS >> ../temp2.txt
fi

#For invoking in autopipeline_parrallel.sh
echo "Flag_DIALS=${Flag_DIALS}" >> ../temp.txt

#Extract statistics data
mkdir STATISTICS_FIGURES
cd STATISTICS_FIGURES
#cchalf_vs_resolution
grep -A25 '$TABLE:  Correlations CC(1/2) within dataset' ../DIALS_${ROUND}/aimless.log | tail -20 > cchalf_vs_resolution.dat
#completeness_vs_resolution
grep -A24 '$TABLE:  Completeness & multiplicity v. resolution' ../DIALS_${ROUND}/aimless.log | tail -20 > completeness_vs_resolution.dat
#i_over_sigma_vs_resolution & rmerge_rmeans_rpim_vs_resolution
grep -m1 -A28 '$TABLE:  Analysis against resolution' ../DIALS_${ROUND}/aimless.log | tail -20 > analysis_vs_resolution.dat
#scales_vs_batch
start=$(($(grep -n '    N  Run    Phi    Batch     Mn(k)        0k      Number   Bfactor    Bdecay' ../DIALS_${ROUND}/aimless.log | head -1 | cut -d ':' -f 1)+1))
end=$(($(grep -n '    N  Run    Phi    Batch     Mn(k)        0k      Number   Bfactor    Bdecay' ../DIALS_${ROUND}/aimless.log | tail -1 | cut -d ':' -f 1)-2))
sed -n "${start},${end}p" ../DIALS_${ROUND}/aimless.log > scales_vs_batch.dat
#rmerge_and_i_over_sigma_vs_batch
start=$(($(grep -n '    N   Batch    Mn(I)   RMSdev  I/rms  Rmerge    Number  Nrej Cm%poss  AnoCmp MaxRes CMlplc   Chi^2  Chi^2c SmRmerge SmMaxRes' ../DIALS_${ROUND}/aimless.log | head -1 | cut -d ':' -f 1)+1))
end=$(($(grep -n '    N   Batch    Mn(I)   RMSdev  I/rms  Rmerge    Number  Nrej Cm%poss  AnoCmp MaxRes CMlplc   Chi^2  Chi^2c SmRmerge SmMaxRes' ../DIALS_${ROUND}/aimless.log | tail -1 | cut -d ':' -f 1)-2))
sed -n "${start},${end}p" ../DIALS_${ROUND}/aimless.log > rmerge_and_i_over_sigma_vs_batch.dat
#L_test
grep -A24 '$TABLE: L test for twinning:' ../DIALS_${ROUND}/ctruncate.log | tail -21 > L_test.dat
L_statistic=$(grep 'L statistic =' ../DIALS_${ROUND}/ctruncate.log | awk '{print $4}')

#Plot statistics figures
${scr_dir}/plot.sh ${L_statistic}

#Go back to data_reduction folder
cd ../..

mv DIALS_${ROUND}.log DIALS/DIALS_${ROUND}

end_time=$(date +%s)
total_time=$((end_time - start_time))

hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))

echo "Total time: ${hours}h ${minutes}m ${seconds}s"
