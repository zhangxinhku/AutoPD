#!/bin/bash
#############################################################################################################
# Script Name: i2_buccaneer.sh
# Description: This script is used for CCP4i2 Buccaneer.
# Author: ZHANG Xin
# Date Created: 2023-06-01
# Last Modified: 2024-03-05
#############################################################################################################

#Input variables
MTZ=$(readlink -f "${1}")
PDB=$(readlink -f "${2}")
SEQ_FILE=$(readlink -f "${3}")

#Extract sequence from sequence file
sequence=""

while IFS= read -r line
do
    if [[ $line != \>* ]]
    then
        sequence+="$line"
    fi
done < "${SEQ_FILE}"

#Determine ASU contents
$CCP4/lib/python3.7/site-packages/ccp4i2/bin/i2run ProvideAsuContents \
	--ASU_CONTENT \
                   sequence=${sequence} \
	           nCopies=1 \
	           polymerType=PROTEIN \
	--noDb > ASU.log
	
ASU=$(readlink -f ASUCONTENTFILE.asu.xml)

#CCP4i2 Buccaneer
$CCP4/lib/python3.7/site-packages/ccp4i2/bin/i2run buccaneer_build_refine_mr \
	--F_SIGF \
		fullPath=${MTZ} \
		columnLabels="/*/*/[F,SIGF]" \
	--FREERFLAG \
		fullPath=${MTZ} \
		columnLabels="/*/*/[FreeR_flag]" \
	--ASUIN ${ASU} \
	--BUCCANEER_MR_MODE_XYZIN ${PDB} \
	--noDb &> BUCCANEER.log
