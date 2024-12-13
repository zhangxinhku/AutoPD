#!/bin/bash

# 定义一个关联数组来存储蛋白质常见的65个空间群符号和对应的号码
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

space_group_symbol=$1

# 查找空间群号码
space_group_number=${space_groups[$space_group_symbol]:-0}

echo $space_group_number