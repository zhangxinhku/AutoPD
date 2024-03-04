#!/bin/bash

MTZ=$(readlink -f "${1}")
PDB=$(readlink -f "${2}")
SEQ_FILE=$(readlink -f "${3}")

sequence=""

while IFS= read -r line
do
    if [[ $line != \>* ]]
    then
        sequence+="$line"
    fi
done < "${SEQ_FILE}"

i2run ProvideAsuContents \
	--ASU_CONTENT \
                   sequence=${sequence} \
	           nCopies=1 \
	           polymerType=PROTEIN \
	--noDb > ASU.log
	
ASU=$(readlink -f ASUCONTENTFILE.asu.xml)

i2run buccaneer_build_refine_mr \
	--F_SIGF \
		fullPath=${MTZ} \
		columnLabels="/*/*/[F,SIGF]" \
	--FREERFLAG \
		fullPath=${MTZ} \
		columnLabels="/*/*/[FreeR_flag]" \
	--ASUIN ${ASU} \
	--BUCCANEER_MR_MODE_XYZIN ${PDB} \
	--noDb &> BUCCANEER.log
