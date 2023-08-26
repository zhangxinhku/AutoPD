#!/bin/tcsh
#######################################################################
#Author: Li Zengru
#Email: zrli@iphy.ac.cn
#Created time: 2022,12,02
#last Edit: 2022,12,02
#Group: SM6,  The Institute of Physics, Chinese Academy of Sciences
#######################################################################

######parameters##############################
#1: input mtz file
##############################################

# run oasis
source ./para/prepare.csh
source ${oasisbin}/oasis_env
${oasisbin}/oasis HKLIN $1 HKLOUT oasis.mtz \
frcin frac/use.frc <<+
NHA 5
SED 1
LABIN FP=FP SIGFP=SIGFP
CON C $num_C N $num_N O $num_O S $num_S
NHL
NFI
DMR
+

# merge the FREE flag
${CBIN}/cad HKLIN1 oasis.mtz HKLIN2 $1 HKLOUT oasis_free.mtz << +
LABIN FILE 1 ALL
LABIN FILE 2 E1=FREE
+

# move intermediate files
mkdir oasis
mv oasis.mtz SIGMA2.DAT oasis_free.mtz oasis
