#!/bin/bash

fixed_model=${1}
moving_model=${2}

grep -vE "UNK UNX|UNK  UNX" ${fixed_model} > fixed_model.pdb
grep -vE "UNK UNX|UNK  UNX" ${moving_model} > moving_model.pdb

name=$(basename "${moving_model}" .pdb)

csymmatch -stdin << EOF
pdbin moving_model.pdb
pdbin-ref fixed_model.pdb
pdbout ${name}_SYMMETRY.pdb
origin-hand
EOF

rm fixed_model.pdb moving_model.pdb 
