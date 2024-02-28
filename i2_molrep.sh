#!/bin/bash

MTZ=$(readlink -f "${1}")
PDB=$(readlink -f "${2}")
SEQ_FILE=$(readlink -f "${3}")

mkdir -p molrep
cd molrep

sequence=""

while IFS= read -r line
do
    if [[ $line != \>* ]]
    then
        sequence+="$line"
    fi
done < "${SEQ_FILE}"

/home/programs/ccp4-8.0/lib/python3.7/site-packages/ccp4i2/bin/i2run ProvideAsuContents \
	--ASU_CONTENT \
                   sequence=${sequence} \
	           nCopies=1 \
	           polymerType=PROTEIN \
	--noDb > ASU.log
	
ASU=$(readlink -f ASUCONTENTFILE.asu.xml)

/home/programs/ccp4-8.0/lib/python3.7/site-packages/ccp4i2/bin/i2run molrep_pipe \
	--inputData.F_SIGF \
	                  fullPath=${MTZ} \
	                  columnLabels="/*/*/[F,SIGF]" \
	--inputData.FREERFLAG \
	                  fullPath=${MTZ} \
	                  columnLabels="/*/*/[FreeR_flag]" \
	--ASUIN ${ASU} \
	--XYZIN ${PDB} \
	--noDb &> MOLREP.log
