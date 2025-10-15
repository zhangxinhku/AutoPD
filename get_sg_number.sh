#!/bin/bash
#############################################################################################################
# Script Name: get_sg_number.sh
# Description: Look up International Tables for Crystallography space group numbers from symbols (65 common).
# Usage: ./sg2num.sh <space_group_symbol>
# Example: ./sg2num.sh P212121  -> 19
# Author: ZHANG Xin
# Created: 2023-06-01
# Last Modified: 2024-08-03
#############################################################################################################

# Define an associative array mapping 65 common protein space group symbols to their ITC numbers
declare -A space_groups=(
  ["P1"]=1
  ["P121"]=3
  ["P1211"]=4
  ["C121"]=5
  ["P222"]=16
  ["P2221"]=17
  ["P21212"]=18
  ["P212121"]=19
  ["C2221"]=20
  ["C222"]=21
  ["F222"]=22
  ["I222"]=23
  ["I212121"]=24
  ["P4"]=75
  ["P41"]=76
  ["P42"]=77
  ["P43"]=78
  ["I4"]=79
  ["I41"]=80
  ["P422"]=89
  ["P4212"]=90
  ["P4122"]=91
  ["P41212"]=92
  ["P4222"]=93
  ["P42212"]=94
  ["P4322"]=95
  ["P43212"]=96
  ["I422"]=97
  ["I4122"]=98
  ["P3"]=143
  ["P31"]=144
  ["P32"]=145
  ["R3"]=146
  ["P312"]=149
  ["P321"]=150
  ["P3112"]=151
  ["P3121"]=152
  ["P3212"]=153
  ["P3221"]=154
  ["R32"]=155
  ["P6"]=168
  ["P61"]=169
  ["P65"]=170
  ["P62"]=171
  ["P64"]=172
  ["P63"]=173
  ["P622"]=177
  ["P6122"]=178
  ["P6522"]=179
  ["P6222"]=180
  ["P6422"]=181
  ["P6322"]=182
  ["P23"]=195
  ["F23"]=196
  ["I23"]=197
  ["P213"]=198
  ["I213"]=199
  ["P432"]=207
  ["P4232"]=208
  ["F432"]=209
  ["F4132"]=210
  ["I432"]=211
  ["P4332"]=212
  ["P4132"]=213
  ["I4132"]=214
)

# Input validation
if [ $# -ne 1 ]; then
  echo "Usage: $0 <space_group_symbol>"
  echo "Example: $0 P212121"
  exit 1
fi

# Retrieve the input space group symbol
space_group_symbol=$1

# Look up the corresponding space group number; default to 0 if not found
space_group_number=${space_groups[$space_group_symbol]:-0}

# Output result
if [ "$space_group_number" -eq 0 ]; then
  echo "Error: Unknown space group symbol '$space_group_symbol'."
else
  echo $space_group_number
fi
