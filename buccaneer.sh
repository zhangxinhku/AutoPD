#!/bin/bash

start_time=$(date +%s)

echo ""
echo "----------------------------------------- Buccaneer -----------------------------------------"
echo ""

MTZ=$(readlink -f "${1}")
PDB=$(readlink -f "${2}")
SEQUENCE=$(readlink -f "${3}")

mkdir -p BUCCANEER
cd BUCCANEER

sigmaa HKLIN ${MTZ} HKLOUT PHASER_OUT_SIGMAA.mtz << EOF > SIGMAA.log
LABIN FP=F SIGFP=SIGF FC=FC PHIC=PHIC
LABOUT DELFWT=DELFWT FWT=FWT WCMB=WCMB
EOF

$CBIN/ccp4-python -u $CBIN/buccaneer_pipeline -stdin << END > BUCCANEER.log
pdbin-ref $CLIB/data/reference_structures/reference-1tqw.pdb
mtzin-ref $CLIB/data/reference_structures/reference-1tqw.mtz
colin-ref-fo FP.F_sigF.F,FP.F_sigF.sigF
colin-ref-hl FC.ABCD.A,FC.ABCD.B,FC.ABCD.C,FC.ABCD.D
seqin ${SEQUENCE}
colin-fo F,SIGF
colin-free FreeR_flag
mtzin PHASER_OUT_SIGMAA.mtz
colin-phifom PHWT,FOM
pdbin ${PDB}
pdbin-mr ${PDB}
buccaneer-keyword mr-model-seed
cycles 5
buccaneer-anisotropy-correction
buccaneer-fix-position
buccaneer-1st-cycles 3
buccaneer-1st-sequence-reliability 0.99
buccaneer-nth-cycles 2
buccaneer-nth-sequence-reliability 0.99
buccaneer-nth-correlation-mode
buccaneer-new-residue-name UNK
buccaneer-resolution 2.0
buccaneer-keyword model-filter-sigma 0.01
buccaneer-keyword mr-model-filter-sigma 0.01
refmac-mlhl 0
refmac-twin 0
prefix .
END

tail -n 13 BUCCANEER.log | head -n 6

BUILT=$(grep 'CA ' buccaneer.pdb | wc -l)
PLACED=$(grep 'CA ' buccaneer.pdb | grep -v 'UNK'  | wc -l)
echo "" | tee -a BUCCANEER.log
echo "BUILT=${BUILT}" | tee -a BUCCANEER.log
echo "PLACED=${PLACED}" | tee -a BUCCANEER.log

echo ""
echo "Buccaneer finished!"

end_time=$(date +%s)
total_time=$((end_time - start_time))

hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))

echo "" | tee -a BUCCANEER.log
echo "Buccaneer took: ${hours}h ${minutes}m ${seconds}s" | tee -a BUCCANEER.log

cp BUCCANEER.log ../SUMMARY
cp buccaneer.pdb ../SUMMARY/BUCCANEER.pdb
