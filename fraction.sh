#!/bin/bash
#######################################################################
#Author: Li Zengru
#Email: zrli@iphy.ac.cn
#Created time: 2022,12,02
#last Edit: 2022,12,02
#Group: SM6,  The Institute of Physics, Chinese Academy of Sciences
#######################################################################

######parameters##############################
#1: input parameter shell
#2: input pdb file
##############################################

source $1
# make frc file
${CBIN}/coordconv XYZIN $2 \
XYZOUT tmp.ha  << +
input PDB -
orth 1
output HA
cell $CELL_A $CELL_B $CELL_C $CELL_ALPHA $CELL_BETA $CELL_GAMMA
end
+

awk 'BEGIN{n=0} {n++; printf "%1s %d %.4f %.4f %.4f %.4f %.4f \n",$2,n,$3,$4,$5,$6,$9;}' tmp.ha > tmp.frc
#echo "set ha_frc_file = ${name}_ha.frc" >> $1
num=$(cat tmp.frc | wc -l)

int=1
blank=" "
while(($int <= $num))
do
    str=$(head -n $int tmp.frc | tail -n -1)
    array=$(echo $str | tr " " " ")
    inta=1
    for var in $array
    do
        str2[$inta]=$var
        let "inta++"
    done
    str3=${str2[1]:0:1}$blank${str2[2]}$blank${str2[3]}$blank${str2[4]}$blank${str2[5]}$blank${str2[6]}$blank${str2[7]}
    echo $str3 >> use.frc
    let "int++"
done

# make fraction pool
num_C=$(grep -o 'C' use.frc | wc -l)
num_N=$(grep -o 'N' use.frc | wc -l)
num_O=$(grep -o 'O' use.frc | wc -l)
num_S=$(grep -o 'S' use.frc | wc -l)
echo "set num_C = "$num_C >> para/prepare.csh
echo "set num_N = "$num_N >> para/prepare.csh
echo "set num_O = "$num_O >> para/prepare.csh
echo "set num_S = "$num_S >> para/prepare.csh

# move intermediate file
mkdir frac
mv tmp.ha tmp.frc use.frc frac
