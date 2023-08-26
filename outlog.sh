#!/bin/bash
#######################################################################
#Author: Li Zengru
#Email: zrli@iphy.ac.cn
#Created time: 2022,12,02
#last Edit: 2022,12,02
#Group: SM6,  The Institute of Physics, Chinese Academy of Sciences
#######################################################################

######parameters##############################
#1: cycle number
#2: result pdb file
#3: output file
##############################################

# grep cycle
cycle=$1

# grep residues
str_res=$(grep WHOLE: $2)
for ary1 in $str_res
do
    str1=$ary1
done
res=$str1

# grep R factor
str_work=$(grep "R VALUE            (WORKING SET) :" $2)
for ary2 in $str_work
do
    str2=$ary2
done
work=$str2

str_free=$(grep "FREE R VALUE                     :" $2)
for ary3 in $str_free
do
    str3=$ary3
done
free=$str3

# output
blank=" "
string=$cycle$blank$res$blank$work$blank$free
echo $string >> $3
