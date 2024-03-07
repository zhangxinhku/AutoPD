#!/bin/bash
#############################################################################################################
# Script Name: autobuild.sh
# Description: This script is used for Phenix Autobuild.
# Author: ZHANG Xin
# Date Created: 2023-06-01
# Last Modified: 2024-03-05
#############################################################################################################

start_time=$(date +%s)

echo ""
echo "----------------------------------------- Autobuild -----------------------------------------"
echo ""

#Input variables
MTZ=$(readlink -f "${1}")
PDB=$(readlink -f "${2}")
SEQUENCE=$(readlink -f "${3}")

#Create folder for Phenix Autobuild
rm -rf AUTOBUILD
mkdir -p AUTOBUILD
cd AUTOBUILD
mkdir -p AUTOBUILD_SUMMARY

#Get the processor number
nproc=$(nproc)

#phenix.autobuild
phenix.autobuild data=${MTZ} model=${PDB} nproc=${nproc}  > AUTOBUILD.log

awk '/SOLUTION/,/Citations for AutoBuild:/' AUTOBUILD.log | sed '$d'
grep 'Best solution on cycle:' AUTOBUILD.log

echo ""
echo "Autobuild finished!"

#Copy output files to SUMMARY folder
cp AutoBuild_run_1_/overall_best.pdb AUTOBUILD_SUMMARY/AUTOBUILD.pdb
cp AutoBuild_run_1_/overall_best_denmod_map_coeffs.mtz AUTOBUILD_SUMMARY/AUTOBUILD.mtz
mv AUTOBUILD.log AUTOBUILD_SUMMARY/AUTOBUILD.log

#Calculate and echo timing information
end_time=$(date +%s)
total_time=$((end_time - start_time))
hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))

echo "" | tee -a AUTOBUILD_SUMMARY/AUTOBUILD.log
echo "Phenix.autobuild took: ${hours}h ${minutes}m ${seconds}s" | tee -a AUTOBUILD_SUMMARY/AUTOBUILD.log

#Go to data processing folder
cd ..
