#!/bin/bash
start_time=$(date +%s)

#Input variables
DATAPATH=${1}
scr_dir=${2}
ROTATION_AXIS=${3}

#Determine file type
file_type=$(find ${DATAPATH} -maxdepth 1 -type f | head -n 1 | awk -F. '{print $NF}')

#Create and enter folder for data reduction
mkdir -p DATA_REDUCTION
cd DATA_REDUCTION

#Extract header information
${scr_dir}/header.sh ${DATAPATH} ${file_type} > header.log

#Rotation axis
ROTATION_AXIS=${ROTATION_AXIS:-1}

#First round data processing
echo ""
echo "-------------------------------- First round data processing --------------------------------"
echo ""
ROUND=1
parallel -u ::: "${scr_dir}/xds.sh ${DATAPATH} ${ROTATION_AXIS} ${ROUND} ${scr_dir} ${file_type}" "${scr_dir}/xds_xia2.sh ${DATAPATH} ${ROTATION_AXIS} ${ROUND} ${scr_dir} ${file_type}" "${scr_dir}/dials_xia2.sh ${DATAPATH} ${ROTATION_AXIS} ${ROUND} ${scr_dir} ${file_type}" "${scr_dir}/autoproc.sh ${DATAPATH} ${ROTATION_AXIS} ${ROUND} ${scr_dir} ${file_type}"

Flag_XDS=$(grep 'Flag_XDS=' temp.txt | cut -d '=' -f 2)
Flag_XDS_XIA2=$(grep 'Flag_XDS_XIA2=' temp.txt | cut -d '=' -f 2)
Flag_DIALS_XIA2=$(grep 'Flag_DIALS_XIA2=' temp.txt | cut -d '=' -f 2)
Flag_autoPROC=$(grep 'Flag_autoPROC=' temp.txt | cut -d '=' -f 2)

#Compare first round result
BEST_1=$(cat "temp1.txt" | sort -k 2 | head -n 1 | cut -d ' ' -f 1)

#Extract space group and cell parameters from best first round result
SPACE_GROUP_NUMBER=$(grep 'Space group number:' ${BEST_1}/${BEST_1}_SUMMARY/${BEST_1}_SUMMARY.log | cut -d ':' -f 2 | sed 's/ //g')
SPACE_GROUP=$(grep 'Space group:' ${BEST_1}/${BEST_1}_SUMMARY/${BEST_1}_SUMMARY.log | cut -d ':' -f 2 | sed 's/ //g')
UNIT_CELL_CONSTANTS=$(grep 'Unit cell:' ${BEST_1}/${BEST_1}_SUMMARY/${BEST_1}_SUMMARY.log | cut -d ':' -f 2 | sed 's/^ *//g' | sed 's/ *$//g' | sed 's/  */ /g')

if [ "${SPACE_GROUP}" == "P2122" ]; then
    SPACE_GROUP="P2221"
fi

#Second round data processing
echo ""
if [[ ${Flag_XDS} -eq 1 && ${Flag_XDS_XIA2} -eq 1 && ${Flag_DIALS_XIA2} -eq 1 && ${Flag_autoPROC} -eq 1 ]]; then
    echo "No need for second round data processing."
else
    echo "-------------------------------- Second round data processing -------------------------------"
fi
echo ""
ROUND=2
parallel -u ::: "${scr_dir}/xds.sh ${DATAPATH} ${ROTATION_AXIS} ${ROUND} ${scr_dir} ${file_type} ${Flag_XDS} ${SPACE_GROUP_NUMBER} \"${UNIT_CELL_CONSTANTS}\"" "${scr_dir}/xds_xia2.sh ${DATAPATH} ${ROTATION_AXIS} ${ROUND} ${scr_dir} ${file_type} ${Flag_XDS_XIA2} ${SPACE_GROUP} \"${UNIT_CELL_CONSTANTS}\"" "${scr_dir}/dials_xia2.sh ${DATAPATH} ${ROTATION_AXIS} ${ROUND} ${scr_dir} ${file_type} ${Flag_DIALS_XIA2} ${SPACE_GROUP} \"${UNIT_CELL_CONSTANTS}\"" "${scr_dir}/autoproc.sh ${DATAPATH} ${ROTATION_AXIS} ${ROUND} ${scr_dir} ${file_type} ${Flag_autoPROC} ${SPACE_GROUP} \"${UNIT_CELL_CONSTANTS}\""

#Output summary results
echo ""
echo "Data reduction summary:"
echo ""
echo "           Resolution   Rmerge   I/Sigma   CC(1/2)   Completeness   Multiplicity   Spacegroup                           Cell"
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
#Compare first and second round result
BEST_Rmerge=$(cat "temp1.txt" | sort -k 2 | head -n 1 | cut -d ' ' -f 1)
BEST_Resolution=$(cat "temp1.txt" | sort -k 3 | head -n 1 | cut -d ' ' -f 1)

echo "Best Rmerge result is from ${BEST_Rmerge}"
echo ""
cp ${BEST_Rmerge}/${BEST_Rmerge}_SUMMARY/${BEST_Rmerge}.mtz DATA_REDUCTION_SUMMARY/BEST_Rmerge.mtz
cp ${BEST_Rmerge}/${BEST_Rmerge}_SUMMARY/${BEST_Rmerge}_SUMMARY.log DATA_REDUCTION_SUMMARY/BEST_Rmerge.log
echo "Best Resolution result is from ${BEST_Resolution}"
echo ""
cp ${BEST_Resolution}/${BEST_Resolution}_SUMMARY/${BEST_Resolution}.mtz DATA_REDUCTION_SUMMARY/BEST_Resolution.mtz
cp ${BEST_Resolution}/${BEST_Resolution}_SUMMARY/${BEST_Resolution}_SUMMARY.log DATA_REDUCTION_SUMMARY/BEST_Resolution.log
cp DATA_REDUCTION_SUMMARY/* ../SUMMARY
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
