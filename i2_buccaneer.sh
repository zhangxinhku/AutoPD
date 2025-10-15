#!/bin/bash
#############################################################################################################
# Script Name: i2_buccaneer.sh
# Description: Wrapper script for running CCP4i2 Buccaneer after MR refinement.
#
# Workflow:
#   1. Read input MTZ and PDB files.
#   2. Extract the sequence from the provided FASTA ($SEQUENCE env var).
#   3. Generate ASU (Asymmetric Unit) content file using CCP4i2 ProvideAsuContents.
#   4. Run CCP4i2 buccaneer_build_refine_mr with MTZ, sequence, and initial PDB.
#   5. Save logs and outputs to BUCCANEER.log.
#
# Usage:
#   ./i2_buccaneer.sh <MTZ file> <PDB file>
#
# Inputs:
#   - MTZ : Diffraction data file (must contain F, SIGF, FreeR_flag labels)
#   - PDB : Initial MR model (e.g., from Phaser or refined)
#   - SEQUENCE : Environment variable containing path to FASTA sequence file
#
# Outputs:
#   - BUCCANEER.log : Log of Buccaneer run
#   - ASU.log       : Log of ASU content generation
#   - Intermediate files: ASUCONTENTFILE.asu.xml
#
# Requirements:
#   - CCP4 with i2run (tested on CCP4i2 environment)
#   - SEQUENCE must be set in the environment
#
# Author: ZHANG Xin
# Date Created: 2023-06-01
# Last Modified: 2024-03-05
#############################################################################################################

# Input variables
MTZ=$(readlink -f "${1}")
PDB=$(readlink -f "${2}")

if [[ -z "${SEQUENCE}" ]]; then
    echo "Error: SEQUENCE not set. Please provide FASTA file."
    exit 1
fi

if [[ ! -f "${MTZ}" ]] || [[ ! -f "${PDB}" ]]; then
    echo "Error: MTZ or PDB file not found."
    exit 1
fi

# Extract protein sequence from FASTA file
sequence=""

while IFS= read -r line
do
    if [[ $line != \>* ]]
    then
        sequence+="$line"
    fi
done < "${SEQUENCE}"

# Generate ASU contents file
$CCP4/lib/python3.9/site-packages/ccp4i2/bin/i2run ProvideAsuContents \
	--ASU_CONTENT \
                   sequence=${sequence} \
	           nCopies=1 \
	           polymerType=PROTEIN \
	--noDb > ASU.log

if [[ ! -f ASUCONTENTFILE.asu.xml ]]; then
    echo "Error: ASU content file not generated. Check ASU.log for details."
    exit 1
fi
	
ASU=$(readlink -f ASUCONTENTFILE.asu.xml)

# Run Buccaneer with CCP4i2 wrapper
$CCP4/lib/python3.9/site-packages/ccp4i2/bin/i2run buccaneer_build_refine_mr \
	--F_SIGF \
		fullPath=${MTZ} \
		columnLabels="/*/*/[F,SIGF]" \
	--FREERFLAG \
		fullPath=${MTZ} \
		columnLabels="/*/*/[FreeR_flag]" \
	--ASUIN ${ASU} \
	--BUCCANEER_MR_MODE_XYZIN ${PDB} \
	--noDb &> BUCCANEER.log
	
if grep -q "Error" BUCCANEER.log; then
   echo "Warning: Buccaneer encountered errors. Check BUCCANEER.log."
fi

