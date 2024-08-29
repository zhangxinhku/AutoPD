#######################################################################
#Author: Li Zengru
#Email: zrli@iphy.ac.cn
#Created time: 2022,12,02
#last Edit: 2022,12,02
#Group: SM6,  The Institute of Physics, Chinese Academy of Sciences
#######################################################################

###############For mac########################
# please run the follow code in terminal to
# install the readlink command when you are
# first run this script in mac
# 1: brew install coreutils
# 2: echo 'export PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"' >> ~/.bash_profile
# 3: echo "alias readlink=greadlink" >> ~/.bash_profile
##############################################

######parameters##############################
#1: input mtz file
#2: input pdb file
#3: input seq file
#4: solvent content
#5: cycle number
#6: output folder
##############################################
SECONDS=0
# input check
if [ $# != 6 ]
then
    echo "mtzin pdbin seqin solc cycle outfold"
    exit
fi

# absoulte path
cur_dir=$(pwd)
scr_dir=$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
mtz_dir=$(readlink -f $1)
#mtz_dir="$(dirname $(readlink -f "${1}"))/$(basename $1)"
pdb_dir=$(readlink -f $2)
seq_dir=$(readlink -f $3)
out_dir=$(readlink -f $6)
tmp_dir=$out_dir/tmp

# output folder
if [ -d "$out_dir" ]
then
    out_dir=$out_dir/IPCAS
fi
mkdir $out_dir

${scr_dir}/ipcas_mtz.sh ${1} ${1}  F SIGF FreeR_flag #FP SIGFP FREE

# run cycle
num=1
last_num=0
cycle=$5
while(($num <= $cycle))
do
    mkdir $tmp_dir
    cd $tmp_dir
    mkdir start
    if [ $num == 1 ]
    then
        cp $pdb_dir start/start.pdb
    else
        cp $out_dir/cycle_$last_num/result/result.pdb start/start.pdb
    fi
    cp $mtz_dir start/start.mtz
    cp $seq_dir start/seq
    $scr_dir/prepare.sh start/start.mtz
    $scr_dir/fraction.sh para/prepare.sh start/start.pdb
    $scr_dir/oasis.csh start/start.mtz
    $scr_dir/dm.csh $4
    if [ $(($num%2)) -eq 1 ]
    then
        $scr_dir/phenix.csh start/seq start/start.pdb
    elif [ $(($num%2)) -eq 0 ]
    then
        $scr_dir/buccaneer.csh start/seq dm/dm.mtz start/start.pdb
    fi
    $scr_dir/outlog.sh $num result/result.pdb $out_dir/result
    cd ..
    mv tmp cycle_$num
    mv cycle_$num $out_dir
    let "num++"
    let "last_num++"
done

# make summary
$scr_dir/result.sh $out_dir/result $out_dir
Rwork=$(awk '$4!=""' $out_dir/result | sort -k4,4n | head -1 | awk '{print $3}')
Rfree=$(awk '$4!=""' $out_dir/result | sort -k4,4n | head -1 | awk '{print $4}')
echo 'cycle Residues Rwork Rfree' | cat - $out_dir/result > $out_dir/temp && mv $out_dir/temp $out_dir/result

#BUILT=$(grep 'CA ' $out_dir/Summary/Free_cycle_*.pdb | wc -l)
#PLACED=$(grep 'CA ' $out_dir/Summary/Free_cycle_*.pdb | grep -v 'UNK'  | wc -l)
echo "" >> $out_dir/result
echo "Best solution: Rwork=${Rwork} Rfree=${Rfree}" >> $out_dir/result
#echo "BUILT=${BUILT}" >> $out_dir/result
#echo "PLACED=${PLACED}" >> $out_dir/result

duration=$SECONDS
mins=$(($duration / 60))
hours=0
if [ $mins -ge 60 ]
then
    hours=$(($mins / 60))
    mins=$(($mins % 60))
fi
secs=$(($duration % 60))
echo "IPCAS took: $hours h $mins m $secs s" >> $out_dir/result
