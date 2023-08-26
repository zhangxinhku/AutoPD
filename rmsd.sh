#!/bin/bash

fixed_model=${1}
moving_model=${2}

grep -v "UNK UNX" ${fixed_model} > fixed_model.pdb
grep -v "UNK UNX" ${moving_model} > moving_model.pdb

phenix.superpose_and_morph fixed_model=fixed_model.pdb moving_model=moving_model.pdb morph=false trim=false

rm fixed_model.pdb moving_model.pdb 
name=$(basename "${moving_model}" .pdb)
mv moving_model_superposed.pdb ${name}_superposed.pdb
