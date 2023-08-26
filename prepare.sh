#!/bin/bash
#######################################################################
#Author: Li Zengru
#Email: zrli@iphy.ac.cn
#Created time: 2022,12,02
#last Edit: 2023,01,11
#Group: SM6,  The Institute of Physics, Chinese Academy of Sciences
#######################################################################

######parameters##############################
#1: input mtz file
##############################################

# crystallographic parameters
${CETC}/mtzdmp $1 -e > mtzdmp.log

num_cell=$(grep -n "Cell Dimensions" mtzdmp.log)
num_cell=$(echo $num_cell | cut -d ' ' -f 1)
num_cell=`expr ${num_cell%?} + 2`

cell_dim=$(head -n $num_cell mtzdmp.log | tail -n -1)
inta=1
for ary in $cell_dim
do
    cell[$inta]=$ary
    let "inta++"
done
CELL_A=${cell[1]}
CELL_B=${cell[2]}
CELL_C=${cell[3]}
CELL_ALPHA=${cell[4]}
CELL_BETA=${cell[5]}
CELL_GAMMA=${cell[6]}

# resolution
num_res=$(grep -n "Resolution Range" mtzdmp.log)
num_res=$(echo $num_res | cut -d ' ' -f 1)
num_res=`expr ${num_res%?} + 2`

inf=$(head -n $num_res mtzdmp.log | tail -n -1)
intc=1
for ary3 in $inf
do
    string[$intc]=$ary3
    let "intc++"
done
reso=${string[6]}

# make parameter pool
echo "CELL_A="$CELL_A >> prepare.sh
echo "CELL_B="$CELL_B >> prepare.sh
echo "CELL_C="$CELL_C >> prepare.sh
echo "CELL_ALPHA="$CELL_ALPHA >> prepare.sh
echo "CELL_BETA="$CELL_BETA >> prepare.sh
echo "CELL_GAMMA="$CELL_GAMMA >> prepare.sh

echo "set CELL_A = "$CELL_A >> prepare.csh
echo "set CELL_B = "$CELL_B >> prepare.csh
echo "set CELL_C = "$CELL_C >> prepare.csh
echo "set CELL_ALPHA = "$CELL_ALPHA >> prepare.csh
echo "set CELL_BETA = "$CELL_BETA >> prepare.csh
echo "set CELL_GAMMA = "$CELL_GAMMA >> prepare.csh
echo "set reso="$reso >> buccaneer.tmp

# move intermediate file
mkdir para
mv mtzdmp.log prepare.sh prepare.csh buccaneer.tmp para
