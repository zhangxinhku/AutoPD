#! /bin/bash
#######################################################################
#Author: Li Zengru
#Email: zrli@iphy.ac.cn
#Created time: 2022,12,02
#last Edit: 2022,12,02
#Group: SM6,  The Institute of Physics, Chinese Academy of Sciences
#######################################################################

######parameters##############################
#1: result file
#2: output folder
##############################################

int=1
num=$(cat $1 | wc -l)
cycle_res=1
cycle_work=1
cycle_free=1
res=0
work=1.0000
free=1.0000

while (($int <= $num))
do
    str=$(head -n $int $1 | tail -n -1)
    inta=1
    for ary in $str
    do
        inf[$inta]=$ary
        let "inta++"
    done
    cur_cycle=${inf[1]}
    cur_res=${inf[2]}
    cur_work=${inf[3]}
    cur_free=${inf[4]}
    if [ $cur_res -ge $res ]
    then
        res=$cur_res
        cycle_res=$cur_cycle
    fi
    if [ $(echo "$cur_work < $work" | bc) -eq 1 ]
    then
        work=$cur_work
        cycle_work=$cur_cycle
    fi
    if [ $(echo "$cur_free < $free" | bc) -eq 1 ]
    then
        free=$cur_free
        cycle_free=$cur_cycle
    fi
    let "int++"
done

mkdir $2/Summary
cp $2/cycle_$cycle_res/result/result.pdb $2/Summary/Res_cycle_$cycle_res.pdb
cp $2/cycle_$cycle_res/result/result.mtz $2/Summary/Res_cycle_$cycle_res.mtz
cp $2/cycle_$cycle_work/result/result.pdb $2/Summary/Work_cycle_$cycle_work.pdb
cp $2/cycle_$cycle_work/result/result.mtz $2/Summary/Work_cycle_$cycle_work.mtz
cp $2/cycle_$cycle_free/result/result.pdb $2/Summary/Free_cycle_$cycle_free.pdb
cp $2/cycle_$cycle_free/result/result.mtz $2/Summary/Free_cycle_$cycle_free.mtz
