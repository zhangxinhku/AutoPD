aimless=${1}
ctruncate=${2}

echo ""
echo "------------------------------------ Summary from AIMLESS -----------------------------------"
echo ""
batches=$(grep "* Number of Batches" ${aimless} | awk '{print $6}')
echo "The number of batches:  ${batches}"
space_group=$(grep "* Space group" ${aimless} | cut -d "'" -f 2)
echo "Space group:  ${space_group}"
space_group_number=$(grep "* Space group" ${aimless} | rev | cut -d ')' -f 2 | cut -d ' ' -f 1 | rev)
echo "Space group number:  ${space_group_number}"
unit_cell=$(grep -A2 "* Cell Dimensions" ${aimless} | tail -1 | sed 's/^ *//g')
echo "Unit cell:  ${unit_cell}"
low_resolution_overall=$(grep "Low resolution limit" ${aimless} | awk '{print $4}')
low_resolution_outershell=$(grep "Low resolution limit" ${aimless} | awk '{print $6}')
high_resolution_overall=$(grep "High resolution limit" ${aimless} | awk '{print $4}')
high_resolution_outershell=$(grep "High resolution limit" ${aimless} | awk '{print $6}')
echo "Resolution:  ${low_resolution_overall} - ${high_resolution_overall} (${low_resolution_outershell} - ${high_resolution_outershell})"
average_mosaicity=$(grep "Average mosaicity" ${aimless} | cut -d ":" -f 2 | sed 's/^ *//g')
echo "Average mosaicity:  ${average_mosaicity}"
echo ""
grep "Overall  InnerShell  OuterShell" -A25 ${aimless}
echo ""
echo "--------------------------------------- Twinning test ---------------------------------------"
echo ""
grep "L statistic =" -A5 ${ctruncate}
echo ""
grep "TWINNING SUMMARY" -A5 ${ctruncate}
