#!/bin/tcsh
#######################################################################
#Author: Li Zengru
#Email: zrli@iphy.ac.cn
#Created time: 2022,12,02
#last Edit: 2022,12,02
#Group: SM6,  The Institute of Physics, Chinese Academy of Sciences
#######################################################################

######parameters##############################
#1: input sequence file
#2: input mtz file
#3: input pdb file
##############################################

# run buccaneer
source para/buccaneer.tmp
$CBIN/ccp4-python -u $CBIN/buccaneer_pipeline -stdin << END
pdbin-ref $CLIB/data/reference_structures/reference-1tqw.pdb
mtzin-ref $CLIB/data/reference_structures/reference-1tqw.mtz
colin-ref-fo FP.F_sigF.F,FP.F_sigF.sigF
colin-ref-hl FC.ABCD.A,FC.ABCD.B,FC.ABCD.C,FC.ABCD.D
seqin $1
colin-fo FP,SIGFP
colin-free FREE
mtzin  $2
colin-phifom FDM,FOMDM
colin-fc FDM,PHIDM
pdbin $3
pdbin-mr $3
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
buccaneer-resolution $reso
buccaneer-keyword model-filter-sigma 0.01
buccaneer-keyword mr-model-filter-sigma 0.01
refmac-mlhl 0
refmac-twin 0
prefix .
END

# run rigid-body refinement
phenix.refine $2 buccaneer.pdb


# move intermediate file
mkdir buccaneer
mv b*.* buccaneer

# make result
mkdir result
cp buccaneer/*001.pdb result/result.pdb
cp buccaneer/*001.mtz result/result.mtz
