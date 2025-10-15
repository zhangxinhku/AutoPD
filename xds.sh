#!/bin/bash
#############################################################################################################
# Script Name: xds.sh
# Description: Automated pipeline for processing X-ray diffraction data with XDS and CCP4 tools.
#              This script runs XDS in sequential steps (XYCORR → INIT → COLSPOT → IDXREF … → CORRECT),
#              performs scaling and merging with XSCALE and AIMLESS, evaluates resolution with DIALS,
#              and prepares an MTZ file for structure determination. It also extracts useful statistics
#              and generates summary reports and plots.
#
# Usage Example:
#   ./xds.sh round=1 flag=0 sp="P212121" cell_constants="78.3 84.1 96.5 90 90 90"
#
# Required Environment Variables:
#   SOURCE_DIR     Path to helper scripts (e.g., generate_XDS.INP, plot.sh, get_sg_number.sh)
#   DATA_PATH      Directory containing diffraction image files
#   FILE_TYPE      Format of diffraction images (e.g., h5, cbf, bz2, img)
#
# Optional Variables:
#   BEAM_X, BEAM_Y           Beam center coordinates (pixels)
#   DISTANCE                 Crystal-to-detector distance (mm)
#   IMAGE_START, IMAGE_END   Image range to process
#   ROTATION_AXIS            Rotation axis vector (comma-separated, e.g. "1,0,0")
#   SPACE_GROUP              Space group symbol (e.g., "P212121")
#   UNIT_CELL_CONSTANTS      Unit cell parameters "a b c alpha beta gamma"
#
# Exit Codes:
#   0  Success
#   1  Failure during XDS or subsequent steps
#
# Author:      ZHANG Xin
# Created:     2023-06-01
# Last Edited: 2025-08-03
#############################################################################################################

# Enable extended pattern matching
shopt -s extglob

start_time=$(date +%s)

#############################################
# Parse command-line arguments
#############################################
for arg in "$@"; do
    IFS="=" read -r key value <<< "$arg"
    case $key in
        round) ROUND="$value" ;;
        flag) FLAG_XDS="$value" ;;
        sp) SPACE_GROUP="$value" ;;
#        sp_number) SPACE_GROUP_NUMBER="$value" ;;
        cell_constants) UNIT_CELL_CONSTANTS="$value" ;;
    esac
done

# Allow override from input variables
if [[ -n "$SPACE_GROUP_INPUT" ]]; then
    SPACE_GROUP=$SPACE_GROUP_INPUT
fi
if [[ -n "$CELL_CONSTANTS_INPUT" ]]; then
    UNIT_CELL_CONSTANTS=$CELL_CONSTANTS_INPUT
fi

#############################################
# Determine whether running this script according to Flag_XDS
#############################################
case "${FLAG_XDS}" in
    "")
        mkdir -p XDS
        cd XDS
        mkdir -p XDS_SUMMARY
        cd ..
        ;;
    "1")
        exit # Skip processing if flag is set
        ;;
esac

cd XDS
mkdir -p XDS_${ROUND}
cd XDS_${ROUND}

#############################################
# Identify diffraction data file template
#############################################
case "${FILE_TYPE}" in
  "h5")
    # Look for master HDF5 file
    filename=$(find "${DATA_PATH}" -maxdepth 1 -type f ! -name '.*' -name "*master.h5" -printf "%f")
    ;;
  +([0-9]))
    # Replace numeric suffix with question marks (wildcard for XDS)
    filename=$(basename $(find ${DATA_PATH} -type f ! -name '.*' -name "*.[0-9]*" | head -1) | perl -pe 's/(\d+)$/ "?" x length($1) /e')
    ;;
  "bz2")
    # Handle compressed data with numeric suffixes
    filename=$(basename $(find ${DATA_PATH} -type f -name "*.bz2" | head -1))
    base=${filename%.*}
    middle=${base#*.*}
    base=${filename%%.*}
    ext=${filename##*.}
    case "${middle}" in
      +([0-9]))
        filename=$(echo "${base}.${middle}" | perl -pe 's/(\d+)$/ "?" x length($1) /e')
        filename="${filename}.${ext}"
        ;;
      *)
        digits=${base##*_}
        num_stars=$(printf "%0.s?" $(seq 1 ${#digits}))
        filename="${base%_*}_${num_stars}.${middle}.${ext}"
        ;;
    esac
    ;;
  *)
    # Generic file type handling(e.g., img, cbf)
    filename=$(ls ${DATA_PATH}/*.${FILE_TYPE} 2>/dev/null | head -1)
    filename=$(basename "${filename}")
    base=${filename%.*}
    ext=${filename##*.}

    suffix=$(echo "${base}" | sed -e 's/.*[^0-9]\([0-9]*\)$/\1/')
    suffix_length=${#suffix}

    num_stars=$(printf "%0.s?" $(seq 1 ${suffix_length}))

    new_base=$(echo "${base}" | sed -e "s/[0-9]*$/${num_stars}/")
    filename="${new_base}.${ext}"
    ;;
esac

# Log data output
echo "Data: ${DATA_PATH}/${filename}" > XDS_${ROUND}.log
echo "" >> XDS_${ROUND}.log

#############################################
# Generate input files for XDS and XSCALE
#############################################
${SOURCE_DIR}/generate_XDS.INP "${DATA_PATH}/${filename}" > generate_XDS.log
cat generate_XDS.log >> XDS_${ROUND}.log
echo "" >> XDS_${ROUND}.log
cp ${SOURCE_DIR}/XSCALE.INP XSCALE.INP

# Insert Durin plugin if HDF5 data
if [ "${FILE_TYPE}" = "h5" ]; then
  sed -i "/NAME_TEMPLATE_OF_DATA_FRAMES/a LIB=${SOURCE_DIR}/durin-plugin.so" XDS.INP
fi

# Apply optional parameters (beam center)
if [ -n "${BEAM_X}" ]; then
    sed -i "s/ORGX=.*$/ORGX= ${BEAM_X} ORGY= ${BEAM_Y}/g" XDS.INP
fi

# Apply optional parameters (crystal to detector distance)
if [ -n "${DISTANCE}" ]; then
    sed -i "s/DETECTOR_DISTANCE=.*$/DETECTOR_DISTANCE= ${DISTANCE}/g" XDS.INP
fi

# Apply optional parameters (image range)
if [ -n "${IMAGE_START}" ] && [ -n "${IMAGE_END}" ]; then
    sed -i "s/DATA_RANGE=.*$/DATA_RANGE=${IMAGE_START} ${IMAGE_END}/g" XDS.INP
    sed -i "s/SPOT_RANGE=.*$/SPOT_RANGE=${IMAGE_START} ${IMAGE_END}/g" XDS.INP
fi

# Apply optional parameters (rotation axis)
if [ -n "${ROTATION_AXIS}" ]; then
    ROTATION_AXIS="${ROTATION_AXIS//,/ }"
    sed -i "s/ROTATION_AXIS=.*$/ROTATION_AXIS= ${ROTATION_AXIS}/g" XDS.INP
fi

# Apply optional parameters (space group and unit cell)
if [ -n "${SPACE_GROUP}" ]; then
    SPACE_GROUP_NUMBER=$(${SOURCE_DIR}/get_sg_number.sh "${SPACE_GROUP}")
    sed -i "s/SPACE_GROUP_NUMBER=.*$/SPACE_GROUP_NUMBER=${SPACE_GROUP_NUMBER}/g" XDS.INP
fi

if [ -n "${UNIT_CELL_CONSTANTS}" ]; then
    sed -i "s/UNIT_CELL_CONSTANTS=.*$/UNIT_CELL_CONSTANTS=${UNIT_CELL_CONSTANTS}/g" XDS.INP
fi

#############################################
# Run XDS pipeline step by step
# (XYCORR → INIT → COLSPOT → IDXREF → DEFPIX → INTEGRATE → CORRECT, etc.)
#############################################
# Each step edits XDS.INP with the appropriate JOB keyword,
# runs XDS or xds_par, saves logs and input snapshots, and checks for errors.

#1_XYCORR
sed -i 's/JOB=.*$/JOB= XYCORR/g' XDS.INP
xds > XYCORR.log
cp XDS.INP XYCORR.INP
cp XYCORR.INP 1_XYCORR.INP
cp XYCORR.log 1_XYCORR.log

if [ ! -f "XYCORR.LP" ]; then
    FLAG_XDS=0
    echo "FLAG_XDS=${FLAG_XDS}" >> ../../temp.txt
    echo "Round ${ROUND} XDS processing failed!"
    exit 1
fi

cp XYCORR.LP 1_XYCORR.LP
cat XYCORR.log >> XDS_${ROUND}.log
echo "" >> XDS_${ROUND}.log

#2_INIT
sed -i 's/JOB=.*$/JOB= INIT/g' XDS.INP
#Set the number of processors to be used
#sed -i '3iMAXIMUM_NUMBER_OF_PROCESSORS=24' XDS.INP
xds > INIT.log
cp XDS.INP INIT.INP
cp INIT.INP 2_INIT.INP
cp INIT.log 2_INIT.log
cp INIT.LP 2_INIT.LP
cat INIT.log >> XDS_${ROUND}.log
echo "" >> XDS_${ROUND}.log

#3_COLSPOT Set SPOT_RANGE=DATA_RANGE
sed -i 's/JOB=.*$/JOB= COLSPOT/g' XDS.INP
#sed -i 's/MAXIMUM_NUMBER_OF_PROCESSORS=.*$/!MAXIMUM_NUMBER_OF_PROCESSORS=24/g' XDS.INP
#DATA_RANGE=$(grep 'DATA_RANGE=' XDS.INP | cut -d '=' -f 2)
#sed -i "s/SPOT_RANGE=.*$/SPOT_RANGE=${DATA_RANGE}/g" XDS.INP
xds_par > COLSPOT.log
cp XDS.INP COLSPOT.INP
cp COLSPOT.INP 3_COLSPOT.INP
cp COLSPOT.log 3_COLSPOT.log
cp COLSPOT.LP 3_COLSPOT.LP
cat COLSPOT.log >> XDS_${ROUND}.log
echo "" >> XDS_${ROUND}.log

#4_IDXREF
sed -i 's/JOB=.*$/JOB= IDXREF/g' XDS.INP
#sed -i 's/REFINE(IDXREF)=.*$/REFINE(IDXREF)= POSITION CELL BEAM ORIENTATION AXIS/g' XDS.INP
xds_par > IDXREF.log
cp XDS.INP IDXREF.INP
cp IDXREF.INP 4_IDXREF.INP
cp IDXREF.log 4_IDXREF.log
cp IDXREF.LP 4_IDXREF.LP

if [ ! -f "XPARM.XDS" ]; then
    FLAG_XDS=0
    echo "FLAG_XDS=${FLAG_XDS}" >> ../../temp.txt
    echo "Round ${ROUND} XDS processing failed!"
    exit 1
fi

cp XPARM.XDS 4_XPARM.XDS
cat IDXREF.log >> XDS_${ROUND}.log
echo "" >> XDS_${ROUND}.log

if grep -q "!!! ERROR !!!" "XDS_${ROUND}.log" && ! grep -q "!!! ERROR !!! INSUFFICIENT PERCENTAGE (< 50%) OF INDEXED REFLECTIONS" "XDS_${ROUND}.log"; then
    FLAG_XDS=0
    echo "FLAG_XDS=${FLAG_XDS}" >> ../../temp.txt
    echo "Round ${ROUND} XDS processing failed!"
    exit 1
fi

#5_DEFPIX Update UNTRUSTED_ELLIPSE ORGX ORGY DETECTOR_DISTANCE ROTATION_AXIS INCIDENT_BEAM_DIRECTION
sed -i 's/JOB=.*$/JOB= DEFPIX/g' XDS.INP
#ORGX=$(awk 'NR == 9 {print $1}' 4_XPARM.XDS)
#ORGY=$(awk 'NR == 9 {print $2}' 4_XPARM.XDS)
#sed -i "s/ORGX=.*$/ORGX= ${ORGX} ORGY= ${ORGY}/g" XDS.INP
#DETECTOR_DISTANCE=$(awk 'NR == 9 {print $3}' 4_XPARM.XDS)
#sed -i "s/DETECTOR_DISTANCE=.*$/DETECTOR_DISTANCE= ${DETECTOR_DISTANCE}/g" XDS.INP
#ROTATION_AXIS=$(awk 'NR == 2 {print $4, $5, $6}' 4_XPARM.XDS)
#sed -i "s/ROTATION_AXIS=.*$/ROTATION_AXIS= ${ROTATION_AXIS}/g" XDS.INP
#INCIDENT_BEAM_DIRECTION=$(awk 'NR == 3 {print $2, $3, $4}' 4_XPARM.XDS)
#sed -i "s/INCIDENT_BEAM_DIRECTION=.*$/INCIDENT_BEAM_DIRECTION= ${INCIDENT_BEAM_DIRECTION}/g" XDS.INP
xds > DEFPIX.log
cp XDS.INP DEFPIX.INP
cp DEFPIX.INP 5_DEFPIX.INP
cp DEFPIX.log 5_DEFPIX.log
cp DEFPIX.LP 5_DEFPIX.LP
cat DEFPIX.log >> XDS_${ROUND}.log
echo "" >> XDS_${ROUND}.log

#6_INTEGRATE
#SPACE_GROUP_NUMBER=$(awk 'NR == 4 {print $1}' 4_XPARM.XDS)
#UNIT_CELL_CONSTANTS=$(awk 'NR == 4 {print $2, $3, $4, $5, $6, $7}' 4_XPARM.XDS)
#sed -i "s/SPACE_GROUP_NUMBER=.*$/SPACE_GROUP_NUMBER=${SPACE_GROUP_NUMBER}/g" XDS.INP
#ssed -i "s/UNIT_CELL_CONSTANTS=.*$/UNIT_CELL_CONSTANTS=${UNIT_CELL_CONSTANTS}/g" XDS.INP
sed -i 's/JOB=.*$/JOB= INTEGRATE/g' XDS.INP
#sed -i 's/REFINE(INTEGRATE)=.*$/REFINE(INTEGRATE)= POSITION CELL BEAM ORIENTATION/g' XDS.INP

MAX_RUN_TIME=60m
timeout $MAX_RUN_TIME xds_par -par NUMBER_OF_FORKED_INTEGRATE_JOBS=2 > INTEGRATE.log

if [ $? -eq 124 ]; then
    FLAG_XDS=0
    echo "FLAG_XDS=${FLAG_XDS}" >> ../../temp.txt
    echo "Timeout. Round ${ROUND} XDS processing failed!"
    exit 1
fi

cp XDS.INP INTEGRATE.INP
cp INTEGRATE.INP 6_INTEGRATE.INP
cp INTEGRATE.log 6_INTEGRATE.log
cp INTEGRATE.LP 6_INTEGRATE.LP
cp INTEGRATE.HKL 6_INTEGRATE.HKL 2>/dev/null
cat INTEGRATE.log >> XDS_${ROUND}.log
echo "" >> XDS_${ROUND}.log

#7_CORRECT
sed -i 's/JOB=.*$/JOB= CORRECT/g' XDS.INP
#sed -i 's/! STRICT_ABSORPTION_CORRECTION=.*$/STRICT_ABSORPTION_CORRECTION=TRUE/g' XDS.INP
xds_par > CORRECT.log
cp XDS.INP CORRECT.INP
cp CORRECT.INP 7_CORRECT.INP
cp CORRECT.log 7_CORRECT.log
cp CORRECT.LP 7_CORRECT.LP

if [ ! -f "GXPARM.XDS" ]; then
    FLAG_XDS=0
    echo "FLAG_XDS=${FLAG_XDS}" >> ../../temp.txt
    echo "Round ${ROUND} XDS processing failed!"
    exit 1
fi

cp GXPARM.XDS 7_GXPARM.XDS
cp XDS_ASCII.HKL 7_XDS_ASCII.HKL
cat CORRECT.log >> XDS_${ROUND}.log
echo "" >> XDS_${ROUND}.log

#8_IDXREF Update SPACE_GROUP_NUMBER UNIT_CELL_CONSTANTS
cp 4_IDXREF.INP XDS.INP
if [ -n "${SPACE_GROUP}" ]; then
    SPACE_GROUP_NUMBER=$(${SOURCE_DIR}/get_sg_number.sh "${SPACE_GROUP}")
else
    SPACE_GROUP_NUMBER=$(awk 'NR == 4 {print $1}' 7_GXPARM.XDS)
fi
UNIT_CELL_CONSTANTS=$(awk 'NR == 4 {print $2, $3, $4, $5, $6, $7}' 7_GXPARM.XDS)
sed -i "s/SPACE_GROUP_NUMBER=.*$/SPACE_GROUP_NUMBER=${SPACE_GROUP_NUMBER}/g" XDS.INP
sed -i "s/UNIT_CELL_CONSTANTS=.*$/UNIT_CELL_CONSTANTS=${UNIT_CELL_CONSTANTS}/g" XDS.INP
xds_par > IDXREF.log
cp XDS.INP IDXREF.INP
cp IDXREF.INP 8_IDXREF.INP
cp IDXREF.log 8_IDXREF.log
cp IDXREF.LP 8_IDXREF.LP
cp XPARM.XDS 8_XPARM.XDS
cat IDXREF.log >> XDS_${ROUND}.log
echo "" >> XDS_${ROUND}.log

#9_DEFPIX Update DETECTOR_DISTANCE ROTATION_AXIS INCIDENT_BEAM_DIRECTION
cp 7_CORRECT.INP XDS.INP
sed -i 's/JOB=.*$/JOB= DEFPIX/g' XDS.INP
ORGX=$(awk 'NR == 9 {print $1}' 8_XPARM.XDS)
ORGY=$(awk 'NR == 9 {print $2}' 8_XPARM.XDS)
sed -i "s/ORGX=.*$/ORGX= ${ORGX} ORGY= ${ORGY}/g" XDS.INP
DETECTOR_DISTANCE=$(awk 'NR == 9 {print $3}' 8_XPARM.XDS)
sed -i "s/DETECTOR_DISTANCE=.*$/DETECTOR_DISTANCE= ${DETECTOR_DISTANCE}/g" XDS.INP
ROTATION_AXIS=$(awk 'NR == 2 {print $4, $5, $6}' 8_XPARM.XDS)
sed -i "s/ROTATION_AXIS=.*$/ROTATION_AXIS= ${ROTATION_AXIS}/g" XDS.INP
INCIDENT_BEAM_DIRECTION=$(awk 'NR == 3 {print $2, $3, $4}' 8_XPARM.XDS)
sed -i "s/INCIDENT_BEAM_DIRECTION=.*$/INCIDENT_BEAM_DIRECTION= ${INCIDENT_BEAM_DIRECTION}/g" XDS.INP
xds > DEFPIX.log
cp XDS.INP DEFPIX.INP
cp DEFPIX.INP 9_DEFPIX.INP
cp DEFPIX.log 9_DEFPIX.log
cp DEFPIX.LP 9_DEFPIX.LP
cat DEFPIX.log >> XDS_${ROUND}.log
echo "" >> XDS_${ROUND}.log

#10_INTEGRATE
sed -i 's/JOB=.*$/JOB= INTEGRATE/g' XDS.INP
xds_par -par NUMBER_OF_FORKED_INTEGRATE_JOBS=2 > INTEGRATE.log #
cp XDS.INP INTEGRATE.INP
cp INTEGRATE.INP 10_INTEGRATE.INP
cp INTEGRATE.log 10_INTEGRATE.log
cp INTEGRATE.LP 10_INTEGRATE.LP
cp INTEGRATE.HKL 10_INTEGRATE.HKL 2>/dev/null
cat INTEGRATE.log >> XDS_${ROUND}.log
echo "" >> XDS_${ROUND}.log

#11_CORRECT
sed -i 's/JOB=.*$/JOB= CORRECT/g' XDS.INP
xds_par > CORRECT.log
cp XDS.INP CORRECT.INP
cp CORRECT.INP 11_CORRECT.INP
cp CORRECT.log 11_CORRECT.log
cp CORRECT.LP 11_CORRECT.LP
cp GXPARM.XDS 11_GXPARM.XDS
cp XDS_ASCII.HKL 11_XDS_ASCII.HKL
cat CORRECT.log >> XDS_${ROUND}.log
echo "" >> XDS_${ROUND}.log

#############################################
# Scaling, merging, and resolution estimation
#############################################
#12_XSCALE with xscale_par
xscale_par > XSCALE.log
cp XSCALE.log 12_XSCALE.log
cp XSCALE.INP 12_XSCALE.INP
cp XSCALE.LP 12_XSCALE.LP
cat XSCALE.log >> XDS_${ROUND}.log
echo "" >> XDS_${ROUND}.log

#13_pointless for HKL to mtz
pointless xdsin XDS_XSCALE.HKL hklout pointless.mtz > pointless.log
cp pointless.log 13_pointless.log
cp pointless.mtz 13_pointless.mtz
cat pointless.log >> XDS_${ROUND}.log
echo "" >> XDS_${ROUND}.log

#14_aimless
{
aimless hklin pointless.mtz hklout XDS.mtz xmlout aimless.xml scalepack XDS.sca > aimless.log << EOF
RUN 1 ALL
BINS 20
ANOMALOUS ON
RESOLUTION LOW 999 HIGH 0.000000
REFINE PARALLEL AUTO
SCALES CONSTANT
OUTPUT MTZ MERGED UNMERGED
OUTPUT SCALEPACK MERGED
EOF
} 2>/dev/null

cp aimless.log 14_aimless.log
cp aimless.xml 14_aimless.xml
cat aimless.log >> XDS_${ROUND}.log
echo "" >> XDS_${ROUND}.log

if [ ! -f "XDS_unmerged.mtz" ]; then
    FLAG_XDS=0
    echo "FLAG_XDS=${FLAG_XDS}" >> ../../temp.txt
    echo "Round ${ROUND} XDS processing failed!"
    exit 1
fi

#15_dials.estimate_resolution to refine resolution limit cc_half=0.3 misigma=2.0 completeness=0.85
dials.estimate_resolution XDS_unmerged.mtz > /dev/null
cp dials.estimate_resolution.log 15_dials.estimate_resolution.log
cp dials.estimate_resolution.html 15_dials.estimate_resolution.html
cat dials.estimate_resolution.log >> XDS_${ROUND}.log
echo "" >> XDS_${ROUND}.log
resolution=$(sed -n '4,7p' dials.estimate_resolution.log | awk '{if ($NF ~ /^[0-9.]+$/) print $NF; else print ""}' | sort -nr | head -n 1)
resolution=${resolution:-0}

#16_aimless for merging with resolution cutoff
{
aimless hklin pointless.mtz hklout XDS.mtz xmlout aimless.xml scalepack XDS.sca > aimless.log << EOF
RUN 1 ALL
BINS 20
ANOMALOUS ON
RESOLUTION LOW 999 HIGH ${resolution}
REFINE PARALLEL AUTO
SCALES CONSTANT
OUTPUT MTZ MERGED UNMERGED
OUTPUT SCALEPACK MERGED
EOF
} 2>/dev/null

cp aimless.log 16_aimless.log
cp aimless.xml 16_aimless.xml
cat aimless.log >> XDS_${ROUND}.log
echo "" >> XDS_${ROUND}.log

Rmeas_XDS=$(grep 'Rmeas (all I+ & I-)' 16_aimless.log | awk '{print $6}')
Rmeas_XDS=${Rmeas_XDS:-0}

if [ $(echo "${Rmeas_XDS} <= 0" | bc) -eq 1 ] || [ $(echo "${Rmeas_XDS} >= 100" | bc) -eq 1 ];then
    FLAG_XDS=0
    echo "FLAG_XDS=${FLAG_XDS}" >> ../../temp.txt
    echo "Round ${ROUND} XDS processing failed!"
    exit 1
else
    echo "XDS ${Rmeas_XDS}" >> ../../temp1.txt
fi

#17_ctruncate to generate truncated intensities
{
ctruncate -mtzin XDS.mtz -mtzout XDS_truncated.mtz -colin '/*/*/[IMEAN,SIGIMEAN]' -colano '/*/*/[I(+),SIGI(+),I(-),SIGI(-)]' > ctruncate.log
} 2>/dev/null

cp ctruncate.log 17_ctruncate.log
cat ctruncate.log >> XDS_${ROUND}.log
echo "" >> XDS_${ROUND}.log

if [ ! -f "XDS_truncated.mtz" ]; then
    FLAG_XDS=0
    echo "FLAG_XDS=${FLAG_XDS}" >> ../../temp.txt
    echo "Round ${ROUND} XDS processing failed!"
    exit 1
fi

#18_freeR_flag to assign R-free set
freerflag hklin XDS_truncated.mtz hklout XDS_free.mtz > freeR_flag.log 2>/dev/null << EOF
FREERFRAC 0.05
UNIQUE
EOF
cp freeR_flag.log 18_freeR_flag.log
cat freeR_flag.log >> XDS_${ROUND}.log
echo "" >> XDS_${ROUND}.log

if [ ! -f "XDS_free.mtz" ]; then
    FLAG_XDS=0
    echo "FLAG_XDS=${FLAG_XDS}" >> ../../temp.txt
    echo "Round ${ROUND} XDS processing failed!"
    exit 1
fi

cd ..

#############################################
# Collect results and generate summary
#############################################
cp XDS_${ROUND}/XDS_free.mtz XDS_SUMMARY/XDS.mtz
cp XDS_${ROUND}/XDS_${ROUND}.log XDS_SUMMARY/XDS.log
cp ../header.log XDS_SUMMARY/XDS_SUMMARY.log

# Append refined parameters and statistics to summary
echo "Refined parameters:" >> XDS_SUMMARY/XDS_SUMMARY.log
distance_refined=$(grep "CRYSTAL TO DETECTOR DISTANCE (mm)" XDS_${ROUND}/CORRECT.LP | awk '{print $6}')
echo "Distance_refined               [mm] = ${distance_refined}" >> XDS_SUMMARY/XDS_SUMMARY.log
beam_center_refined=$(grep "DETECTOR COORDINATES (PIXELS) OF DIRECT BEAM" XDS_${ROUND}/CORRECT.LP | awk '{print $7 "," $8}')
echo "Beam_center_refined         [pixel] = ${beam_center_refined}" >> XDS_SUMMARY/XDS_SUMMARY.log
${SOURCE_DIR}/dr_log.sh XDS_${ROUND}/aimless.log XDS_${ROUND}/ctruncate.log XDS_${ROUND}/pointless.log >> XDS_SUMMARY/XDS_SUMMARY.log

#For invoking in autopipeline_parrallel.sh
echo "FLAG_XDS=1" >> ../temp.txt
echo "Round ${ROUND} XDS processing succeeded!"

#Check Anomalous Signal strong anomalous signal
if grep -q "strong anomalous signal" "XDS_SUMMARY/XDS_SUMMARY.log" && grep -q "Estimate of the resolution limit" "XDS_SUMMARY/XDS_SUMMARY.log"; then
    echo "Strong anomalous signal found in XDS.mtz"
    cp XDS_SUMMARY/XDS.mtz ../SAD_INPUT
fi

#Extract statistics data
mkdir -p STATISTICS_FIGURES
cd STATISTICS_FIGURES
#cchalf_vs_resolution
grep -A25 '$TABLE:  Correlations CC(1/2) within dataset' ../XDS_${ROUND}/aimless.log | tail -20 > cchalf_vs_resolution.dat
#completeness_vs_resolution
grep -A24 '$TABLE:  Completeness & multiplicity v. resolution' ../XDS_${ROUND}/aimless.log | tail -20 > completeness_vs_resolution.dat
#i_over_sigma_vs_resolution & rmerge_rmeans_rpim_vs_resolution
grep -m1 -A28 '$TABLE:  Analysis against resolution' ../XDS_${ROUND}/aimless.log | tail -20 > analysis_vs_resolution.dat
#scales_vs_batch
start=$(($(grep -n '    N  Run    Phi    Batch     Mn(k)        0k      Number   Bfactor    Bdecay' ../XDS_${ROUND}/aimless.log | head -1 | cut -d ':' -f 1)+1))
end=$(($(grep -n '    N  Run    Phi    Batch     Mn(k)        0k      Number   Bfactor    Bdecay' ../XDS_${ROUND}/aimless.log | tail -1 | cut -d ':' -f 1)-2))
sed -n "${start},${end}p" ../XDS_${ROUND}/aimless.log > scales_vs_batch.dat
#rmerge_and_i_over_sigma_vs_batch
start=$(($(grep -n '    N   Batch    Mn(I)   RMSdev  I/rms  Rmerge    Number  Nrej Cm%poss  AnoCmp MaxRes CMlplc   Chi^2  Chi^2c SmRmerge' ../XDS_${ROUND}/aimless.log | head -1 | cut -d ':' -f 1)+1))
end=$(($(grep -n '    N   Batch    Mn(I)   RMSdev  I/rms  Rmerge    Number  Nrej Cm%poss  AnoCmp MaxRes CMlplc   Chi^2  Chi^2c SmRmerge' ../XDS_${ROUND}/aimless.log | tail -1 | cut -d ':' -f 1)-2))
sed -n "${start},${end}p" ../XDS_${ROUND}/aimless.log > rmerge_and_i_over_sigma_vs_batch.dat
#L_test
grep -A24 '$TABLE: L test for twinning:' ../XDS_${ROUND}/ctruncate.log | tail -21 > L_test.dat
L_statistic=$(grep 'L statistic =' ../XDS_${ROUND}/ctruncate.log | awk '{print $4}')

# Generate plots from AIMLESS and CTRUNCATE logs
${SOURCE_DIR}/plot.sh ${L_statistic}

#############################################
# Timing information
#############################################
end_time=$(date +%s)
total_time=$((end_time - start_time))
hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))
echo "Total time: ${hours}h ${minutes}m ${seconds}s" >> ../XDS_${ROUND}/XDS_${ROUND}.log

# Return to main data reduction directory
cd ../..
