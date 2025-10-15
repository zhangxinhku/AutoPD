#!/bin/bash
#############################################################################################################
# Script Name: dr_log.sh
# Description: Generate a concise summary of data reduction results from AIMLESS and CTRUNCATE logs.
#              Extracts space group, unit cell, resolution range, mosaicity, key statistics, and twinning tests.
#
# Usage Example:
#   ./dr_log.sh aimless.log ctruncate.log
#
# Required Arguments:
#   aimless.log      Path to AIMLESS log file
#   ctruncate.log    Path to CTRUNCATE log file
#
# Outputs:
#   Writes summary information to stdout (typically appended to *_SUMMARY.log by calling scripts).
#
# Author:      ZHANG Xin
# Created:     2023-06-01
# Last Edited: 2024-08-03
#############################################################################################################

#############################################
# Input variables
#############################################
aimless=${1}
ctruncate=${2}

#############################################
# Extract summary from AIMLESS log
#############################################
echo ""
echo "------------------------------------ Summary from AIMLESS -----------------------------------"
echo ""

# Number of batches
batches=$(grep "* Number of Batches" ${aimless} | awk '{print $6}')
echo "The number of batches:  ${batches}"

# Space group and number
space_group=$(grep "* Space group" ${aimless} | cut -d "'" -f 2)
echo "Space group:  ${space_group}"
space_group_number=$(grep "* Space group" ${aimless} | rev | cut -d ')' -f 2 | cut -d ' ' -f 1 | rev)
echo "Space group number:  ${space_group_number}"

# Unit cell
unit_cell=$(grep -A2 "* Cell Dimensions" ${aimless} | tail -1 | sed 's/^ *//g')
echo "Unit cell:  ${unit_cell}"

# Resolution limits
low_resolution_overall=$(grep "Low resolution limit" ${aimless} | awk '{print $4}')
low_resolution_outershell=$(grep "Low resolution limit" ${aimless} | awk '{print $6}')
high_resolution_overall=$(grep "High resolution limit" ${aimless} | awk '{print $4}')
high_resolution_outershell=$(grep "High resolution limit" ${aimless} | awk '{print $6}')
echo "Resolution:  ${low_resolution_overall} - ${high_resolution_overall} (${low_resolution_outershell} - ${high_resolution_outershell})"

# Average mosaicity
average_mosaicity=$(grep "Average mosaicity" ${aimless} | cut -d ":" -f 2 | sed 's/^ *//g')
echo "Average mosaicity:  ${average_mosaicity}"

echo ""
grep "Overall  InnerShell  OuterShell" -A25 ${aimless}
echo ""

#############################################
# Extract twinning test from CTRUNCATE log
#############################################
echo "--------------------------------------- Twinning test ---------------------------------------"
echo ""
grep "L statistic =" -A5 ${ctruncate}
echo ""
grep "TWINNING SUMMARY" -A5 ${ctruncate}
