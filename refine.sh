#!/bin/bash
#############################################################################################################
# Script Name: refine.sh
# Description: This script is used for CCP4i2 Refmac.
# Author: ZHANG Xin
# Date Created: 2024-10-16
# Last Modified: 2024-10-16
#############################################################################################################

start_time=$(date +%s)

#Input variables
MTZ=$(readlink -f "${1}")
PDB=$(readlink -f "${2}")

mkdir -p REFINEMENT
cd REFINEMENT

i2run prosmart_refmac \
     --F_SIGF \
		fullPath=${MTZ} \
		columnLabels="/*/*/[F,SIGF]" \
     --FREERFLAG \
		fullPath=${MTZ} \
		columnLabels="/*/*/[FreeR_flag]" \
     --XYZIN ${PDB} \
     --noDb &> REFINEMENT.log

cd ..
