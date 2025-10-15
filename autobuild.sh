#!/bin/bash
#############################################################################################################
# Script Name: autobuild.sh
# Description: This script automates model building using Phenix Autobuild.
#
# Workflow:
#   1. Determine the best available PDB model (priority: Buccaneer > Refinement > Phaser).
#   2. Create a dedicated AUTOBUILD folder for output.
#   3. Run phenix.autobuild with the chosen MTZ and PDB inputs.
#   4. If the first run fails, retry with fallback models.
#   5. Extract refinement statistics (R-work, R-free) and log them.
#   6. Copy best results to AUTOBUILD_SUMMARY and SUMMARY folders.
#
# Usage:
#   ./autobuild.sh <MTZ file>
#
# Inputs:
#   - MTZ : Input MTZ file with structure factor amplitudes
#   - SUMMARY/BUCCANEER.pdb or SUMMARY/REFINEMENT.pdb or SUMMARY/PHASER.1.pdb
#
# Outputs:
#   - AUTOBUILD_SUMMARY/AUTOBUILD.pdb : Best Autobuild model
#   - AUTOBUILD_SUMMARY/AUTOBUILD.mtz : Map coefficients
#   - AUTOBUILD_SUMMARY/AUTOBUILD.log : Log file with run details
#
# Dependencies:
#   - Phenix installation with phenix.autobuild in PATH
#   - GNU coreutils (nproc, awk, grep, cut, etc.)
#
# Author: ZHANG Xin
# Date Created: 2023-06-01
# Last Modified: 2024-03-05
#############################################################################################################

start_time=$(date +%s)

echo ""
echo "----------------------------------------- Autobuild -----------------------------------------"
echo ""

# Input variable
MTZ=$(readlink -f "${1}")

# Determine the best available model for Autobuild
if [ -f "SUMMARY/BUCCANEER.pdb" ] && [ $(echo "$r_free_buccaneer < $r_free_refine" | bc) -eq 1 ] && [ $(echo "$r_free_buccaneer > 0" | bc) -eq 1 ]; then
    PDB=$(readlink -f "SUMMARY/BUCCANEER.pdb")
elif [ -f "SUMMARY/REFINEMENT.pdb" ] && [ $(echo "$r_free_refine > 0" | bc) -eq 1 ]; then
    PDB=$(readlink -f "SUMMARY/REFINEMENT.pdb")
else
    PDB=$(readlink -f "SUMMARY/PHASER.1.pdb")
fi

# Prepare working directory
rm -rf AUTOBUILD
mkdir -p AUTOBUILD
cd AUTOBUILD

# Detect CPU count for parallelization
nproc=$(nproc)

# Run phenix.autobuild
phenix.autobuild data=${MTZ} model=${PDB} nproc=$nproc  > AUTOBUILD.log

# Fallback strategy if Autobuild fails with current model
if [ ! -f "AutoBuild_run_1_/overall_best.pdb" ] && [[ "$PDB" == *BUCCANEER.pdb ]] && [ -f "../SUMMARY/REFINEMENT.pdb" ]; then
    PDB=$(readlink -f "../SUMMARY/REFINEMENT.pdb")
    rm -rf ./*
    phenix.autobuild data=${MTZ} model=${PDB} nproc=$nproc  > AUTOBUILD.log
fi

if [ ! -f "AutoBuild_run_1_/overall_best.pdb" ] && [[ "$PDB" == *REFINEMENT.pdb ]] && [ -f "../SUMMARY/PHASER.1.pdb" ]; then
    PDB=$(readlink -f "../SUMMARY/PHASER.1.pdb")
    rm -rf ./*
    phenix.autobuild data=${MTZ} model=${PDB} nproc=$nproc  > AUTOBUILD.log
fi

# Extract solution summary from the log
awk '/SOLUTION/,/Citations for AutoBuild:/' AUTOBUILD.log

# Collect results
mkdir -p AUTOBUILD_SUMMARY
cp AutoBuild_run_1_/overall_best.pdb AUTOBUILD_SUMMARY/AUTOBUILD.pdb
cp AutoBuild_run_1_/overall_best_denmod_map_coeffs.mtz AUTOBUILD_SUMMARY/AUTOBUILD.mtz
mv AUTOBUILD.log AUTOBUILD_SUMMARY/AUTOBUILD.log

# Extract refinement stats
r_work=$(grep 'R VALUE            (WORKING SET) :' "AUTOBUILD_SUMMARY/AUTOBUILD.pdb" 2>/dev/null | cut -d ':' -f 2 | xargs)
r_free=$(grep 'FREE R VALUE                     :' "AUTOBUILD_SUMMARY/AUTOBUILD.pdb" 2>/dev/null | cut -d ':' -f 2 | xargs)
echo ""
echo "Phenix.autobuild Results: R-work=$r_work  R-free=$r_free"

echo ""
echo "Autobuild finished!"

# Timing info
end_time=$(date +%s)
total_time=$((end_time - start_time))
hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))

echo "" | tee -a AUTOBUILD_SUMMARY/AUTOBUILD.log
echo "Phenix.autobuild took: ${hours}h ${minutes}m ${seconds}s" | tee -a AUTOBUILD_SUMMARY/AUTOBUILD.log

# Go to data processing folder
cd ..
