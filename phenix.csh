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
#2: input pdb file
##############################################

# run phenix.autobuild
phenix.autobuild data=./dm/dm.mtz   seq_file=$1 map_file=dm/dm.mtz model=$2      quick=true       nbatch=3 nproc=4 skip_hexdigest=True input_map_labels='FP PHIDM FOMDM' ncycle_refine=1 n_random_loop=1 rebuild_in_place=False   skip_xtriage=True remove_residues_on_special_positions=True
# test_flag_value=1 

# move intermediate file
mkdir phenix
mv AutoBuild_run_1_ PDS phenix
mkdir result
cp phenix/AutoBuild_run_1_/*001.pdb result/result.pdb
cp phenix/AutoBuild_run_1_/*001.mtz result/result.mtz
mkdir phenix/ncs
mv find_ncs.* phenix/ncs
