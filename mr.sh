#!/bin/bash

start_time=$(date +%s)

#Input variables
SEQUENCE=${1}
EXPERIMENT=${2}

TEMPLATE_NUMBER=$(ls ALPHAFOLD_MODEL/*.pdb | wc -l)
SEQUENCE_NAME=$(basename $(find ALPHAFOLD_MODEL/ -name "*.fasta" | head -n 1) | cut -d "_" -f 1)
echo ""
echo "MR template number: ${TEMPLATE_NUMBER}"

#Create folder for molecular replacement
rm -rf PHASER_MR
mkdir -p PHASER_MR
cd PHASER_MR
echo ""
echo "------------------------------------Cell Content Analysis------------------------------------"

#phaser_cca
phaser << eof > phaser_cca.log
TITLE phaser_cca
MODE CCA
ROOT PHASER_CCA
HKLIN ${EXPERIMENT}
LABIN F=F SIGF=SIGF
COMPOSITION BY ASU
COMPOSITION PROTEIN SEQ ${SEQUENCE} NUM 1
eof

#Extract NUMBER from phaser_cca result
CCA_EXIT_STATUS=$(grep 'EXIT STATUS:' phaser_cca.log | awk '{print $3}')

Z_NUMBER=$(awk '/loggraph/{flag=1;next}/\$\$/{flag=0}flag' phaser_cca.log | sort -k2,2nr | head -n 1 | awk '{print $1}')

echo ""
echo "Phaser CCA EXIT STATUS: ${CCA_EXIT_STATUS}"
if [ ${CCA_EXIT_STATUS} == "FAILURE" ]; then
    exit 1
else
    echo "The most probable Z=${Z_NUMBER}"
    echo ""
fi

echo "------------------------------------------Phaser MR------------------------------------------"
echo ""

echo "TITLE phaser_mr
MODE MR_AUTO
ROOT PHASER
HKLIN ${EXPERIMENT}
LABIN F=F SIGF=SIGF
SGALTERNATIVE SELECT ALL" > phaser_input.txt

for ((i=1; i<=${TEMPLATE_NUMBER}; i++))
do
  echo "ENSEMBLE ensemble${i} PDB ../ALPHAFOLD_MODEL/ENSEMBLE${i}.pdb IDENTITY 90" >> phaser_input.txt
done

echo "COMPOSITION BY ASU" >> phaser_input.txt

echo "COMPOSITION PROTEIN SEQ ${SEQUENCE} NUM ${Z_NUMBER}" >> phaser_input.txt

for ((i=1; i<=TEMPLATE_NUMBER; i++))
do
  echo "SEARCH ENSEMBLE ensemble${i} NUM ${Z_NUMBER}" >> phaser_input.txt
done

phaser < phaser_input.txt > phaser_mr.log

MR_EXIT_STATUS=$(grep 'EXIT STATUS:' phaser_mr.log | awk '{print $3}')
echo "Phaser MR EXIT STATUS: ${MR_EXIT_STATUS}"


if [ ! -f "PHASER.1.pdb" ]; then
    echo "No MR solution!"
    exit 1
fi

end_time=$(date +%s)
total_time=$((end_time - start_time))

hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))

echo "" | tee -a phaser_mr.log
echo "Molecular replacement took: ${hours}h ${minutes}m ${seconds}s" | tee -a phaser_mr.log

#Copy results to SUMMARY folder
cp PHASER.1.pdb ../SUMMARY/PHASER.pdb
cp PHASER.1.mtz ../SUMMARY/PHASER.mtz
cp phaser_cca.log ../SUMMARY/PHASER_CCA.log
cp phaser_mr.log ../SUMMARY/PHASER_MR.log

#Go to data processing folder
cd ..
