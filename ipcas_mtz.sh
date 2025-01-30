#!/bin/bash
#######################################################################
#Author: Li Zengru
#Email: zrli@iphy.ac.cn
#Created time: 2023,01,11
#last Edit: 2023,01,11
#Group: SM6,  The Institute of Physics, Chinese Academy of Sciences
#######################################################################

######parameters##############################
#1: input mtz file
#2: output mtz file
#3: FP
#4: SIGFP
#5: FREE
##############################################

# input check
if [ $# != 8 ]
then
    echo "mtzin mtzout FP SIGFP FREE"
    exit
fi

# ccp4 cad
${CBIN}/cad HKLIN1 $1 HKLOUT $2 << +
monitor BRIEF
labin file 1 -
    E1 = $5 -
    E2 = $3 -
    E3 = $4
labout file 1 -
    E1 = $8 -
    E2 = $6 -
    E3 = $7
ctypin file 1 -
    E1 = I -
    E2 = F -
    E3 = Q
end
+
