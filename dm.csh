#!/bin/tcsh
#######################################################################
#Author: Li Zengru
#Email: zrli@iphy.ac.cn
#Created time: 2022,12,02
#last Edit: 2022,12,02
#Group: SM6,  The Institute of Physics, Chinese Academy of Sciences
#######################################################################

######parameters##############################
#1: solvent contents
##############################################
${CBIN}/dm HKLIN  oasis/oasis_free.mtz HKLOUT dm.mtz << +
combine PERT
scheme ALL
ncycles AUTO
solc $1
LABIN  FP=FP SIGFP=SIGFP PHIO=PHIB FOMO=FOM
mode SOLV
ncsmask
LABOUT  FDM=FDM PHIDM=PHIDM FOMDM=FOMDM
RSIZE 80
+

# move intermediate file
mkdir dm
mv dm.mtz dm
