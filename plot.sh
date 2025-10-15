#!/bin/bash
#############################################################################################################
# Script Name: plot.sh
# Description: Generates quality-control plots for data reduction statistics using gnuplot.
#
# Usage Example:
#   ./plot.sh <L_statistic>
#
# Input:
#   1. L_statistic (numeric) - the L-test statistic value for twinning analysis.
#   2. Required data files:
#        - cchalf_vs_resolution.dat
#        - completeness_vs_resolution.dat
#        - analysis_vs_resolution.dat
#        - scales_vs_batch.dat
#        - rmerge_and_i_over_sigma_vs_batch.dat
#        - L_test.dat
#
# Output:
#   SVG plots in the current directory
#
# Dependencies:
#   - gnuplot
#   - bc
#
# Author:      ZHANG Xin
# Created:     2023-06-01
# Last Edited: 2025-08-06
#############################################################################################################

L_statistic=${1:-0.500}  # default value if not provided

#############################################
# Input validation
#############################################
required_files=(
  "cchalf_vs_resolution.dat"
  "completeness_vs_resolution.dat"
  "analysis_vs_resolution.dat"
  "scales_vs_batch.dat"
  "rmerge_and_i_over_sigma_vs_batch.dat"
  "L_test.dat"
)

for file in "${required_files[@]}"; do
  if [ ! -s "$file" ]; then
    echo "Error: Required file '$file' not found or empty!"
    exit 1
  fi
done

#############################################
# Helper: ensure axis ranges are valid
#############################################
ensure_range() {
  local min=$1
  local max=$2
  if [ "$min" = "$max" ]; then
    min=$(echo "$min - 0.05" | bc)
    max=$(echo "$max + 0.05" | bc)
  fi
  echo "$min $max"
}

#############################################
# Compute resolution axis values
#############################################
high_Dmid=$(head -1 cchalf_vs_resolution.dat | awk '{print $3}')
low_Dmid=$(tail -1 cchalf_vs_resolution.dat | awk '{print $3}')
high_value=$(echo "scale=6; 1/(${low_Dmid})^2" | bc)
low_value=$(echo "scale=6; 1/(${high_Dmid})^2" | bc)
step=$(echo "scale=6; (${high_value}-${low_value})/9" | bc)

value=()
Dmid=()
for (( i=0; i<10; i++ ))
do
    value[i]=$(echo "scale=6; ${low_value}+${i}*${step}" | bc)
    Dmid[i]=$(echo "scale=2; 1/sqrt(${value[i]})" | bc)
done

#############################################
# Compute ranges for each plot
#############################################
# CC(1/2) and CC_Anom
cc_min=$(awk '{print $4; print $7}' cchalf_vs_resolution.dat | sort -n | head -1)
cc_max=$(awk '{print $4; print $7}' cchalf_vs_resolution.dat | sort -n | tail -1)
read cc_min cc_max <<< $(ensure_range $cc_min $cc_max)

# Completeness
cmpl_min=$(awk '{print $7; print $10}' completeness_vs_resolution.dat | sort -n | head -1)
cmpl_max=$(awk '{print $7; print $10}' completeness_vs_resolution.dat | sort -n | tail -1)
read cmpl_min cmpl_max <<< $(ensure_range $cmpl_min $cmpl_max)

# I/Sigma
ios_min=$(awk '{print $14}' analysis_vs_resolution.dat | sort -n | head -1)
ios_max=$(awk '{print $14}' analysis_vs_resolution.dat | sort -n | tail -1)
read ios_min ios_max <<< $(ensure_range $ios_min $ios_max)

# Rmerge/Rmeas/Rpim
rmerge_min=$(awk '{print $4; print $7; print $8}' analysis_vs_resolution.dat | sort -n | head -1)
rmerge_max=$(awk '{print $4; print $7; print $8}' analysis_vs_resolution.dat | sort -n | tail -1)
read rmerge_min rmerge_max <<< $(ensure_range $rmerge_min $rmerge_max)

# Batch plots
batch_number=$(tail -1 scales_vs_batch.dat | awk '{print $1}')
scale_y_min=$(awk '{print $5; print $6}' scales_vs_batch.dat | sort -n | head -1)
scale_y_max=$(awk '{print $5; print $6}' scales_vs_batch.dat | sort -n | tail -1)
read scale_y_min scale_y_max <<< $(ensure_range $scale_y_min $scale_y_max)

scale_y2_min=$(awk '{print $8; print $9}' scales_vs_batch.dat | sort -n | head -1)
scale_y2_max=$(awk '{print $8; print $9}' scales_vs_batch.dat | sort -n | tail -1)
read scale_y2_min scale_y2_max <<< $(ensure_range $scale_y2_min $scale_y2_max)

r_y_min=$(awk '{print $6}' rmerge_and_i_over_sigma_vs_batch.dat | sort -n | head -1)
r_y_max=$(awk '{print $6}' rmerge_and_i_over_sigma_vs_batch.dat | sort -n | tail -1)
read r_y_min r_y_max <<< $(ensure_range $r_y_min $r_y_max)

r_y2_min=$(awk '{print $5}' rmerge_and_i_over_sigma_vs_batch.dat | sort -n | head -1)
r_y2_max=$(awk '{print $5}' rmerge_and_i_over_sigma_vs_batch.dat | sort -n | tail -1)
read r_y2_min r_y2_max <<< $(ensure_range $r_y2_min $r_y2_max)

# L-test
lt_min=$(awk '{print $2; print $3; print $4}' L_test.dat | sort -n | head -1)
lt_max=$(awk '{print $2; print $3; print $4}' L_test.dat | sort -n | tail -1)
read lt_min lt_max <<< $(ensure_range $lt_min $lt_max)

#############################################
# Plot 1: CC(1/2) vs Resolution
#############################################
gnuplot << EOF
set term svg size 1000,600 enhanced background rgb 'white' font 'Arial Narrow,20'
set encoding utf8; set grid; set key outside
set title 'CC(1/2) and CC_Anom against Resolution'
set xlabel 'Resolution [Å]'; set ylabel 'CC(1/2) and CC_Anom'
set format y '%.2f'
set xtics ("${high_Dmid}" ${low_value}, "${Dmid[1]}" ${value[1]}, "${Dmid[2]}" ${value[2]}, \
"${Dmid[3]}" ${value[3]}, "${Dmid[4]}" ${value[4]}, "${Dmid[5]}" ${value[5]}, \
"${Dmid[6]}" ${value[6]}, "${Dmid[7]}" ${value[7]}, "${Dmid[8]}" ${value[8]}, \
"${low_Dmid}" ${high_value})
set yrange [${cc_min}:${cc_max}]
set xrange [${low_value}:${high_value}]
set output 'cchalf_vs_resolution.svg'
plot 'cchalf_vs_resolution.dat' using 2:7 with lines lc rgb '#fb9a99' lw 2 ti 'CC(1/2)', \
     'cchalf_vs_resolution.dat' using 2:4 with lines lc rgb '#a6cee3' lw 2 ti 'CC_Anom'
EOF

#############################################
# Plot 2: Completeness vs Resolution
#############################################
gnuplot << EOF
set term svg size 1000,600 enhanced background rgb 'white' font 'Arial Narrow,20'
set grid; set key outside
set title 'Completeness and AnomCompleteness against Resolution'
set xlabel 'Resolution [Å]'; set ylabel 'Completeness (%)'
set format y '%.2f'
set xtics ("${high_Dmid}" ${low_value}, "${Dmid[1]}" ${value[1]}, "${Dmid[2]}" ${value[2]}, \
"${Dmid[3]}" ${value[3]}, "${Dmid[4]}" ${value[4]}, "${Dmid[5]}" ${value[5]}, \
"${Dmid[6]}" ${value[6]}, "${Dmid[7]}" ${value[7]}, "${Dmid[8]}" ${value[8]}, \
"${low_Dmid}" ${high_value})
set yrange [${cmpl_min}:${cmpl_max}]
set xrange [${low_value}:${high_value}]
set output 'completeness_vs_resolution.svg'
plot 'completeness_vs_resolution.dat' using 2:7 with lines lc rgb '#e31a1c' lw 2 ti 'Completeness', \
     'completeness_vs_resolution.dat' using 2:10 with lines lc rgb '#1f78b4' lw 2 ti 'AnomCmpl'
EOF

#############################################
# Plot 3: I/Sigma vs Resolution
#############################################
gnuplot << EOF
set term svg size 1000,600 enhanced background rgb 'white' font 'Arial Narrow,20'
set grid; set key outside
set title 'Mean(I/SigI) against Resolution'
set xlabel 'Resolution [Å]'; set ylabel 'Mean(I/SigI)'
set format y '%.2f'
set xtics ("${high_Dmid}" ${low_value}, "${Dmid[1]}" ${value[1]}, "${Dmid[2]}" ${value[2]}, \
"${Dmid[3]}" ${value[3]}, "${Dmid[4]}" ${value[4]}, "${Dmid[5]}" ${value[5]}, \
"${Dmid[6]}" ${value[6]}, "${Dmid[7]}" ${value[7]}, "${Dmid[8]}" ${value[8]}, \
"${low_Dmid}" ${high_value})
set yrange [${ios_min}:${ios_max}]
set xrange [${low_value}:${high_value}]
set output 'i_over_sigma_vs_resolution.svg'
plot 'analysis_vs_resolution.dat' using 2:14 with lines lc rgb '#33a02c' lw 2 ti 'Mn(I/sigI)'
EOF

#############################################
# Plot 4: Rmerge/Rmeas/Rpim vs Resolution
#############################################
gnuplot << EOF
set term svg size 1000,600 enhanced background rgb 'white' font 'Arial Narrow,20'
set grid; set key outside
set title 'Rmerge, Rmeas and Rpim against Resolution'
set xlabel 'Resolution [Å]'; set ylabel 'Merging Statistics'
set format y '%.2f'
set xtics ("${high_Dmid}" ${low_value}, "${Dmid[1]}" ${value[1]}, "${Dmid[2]}" ${value[2]}, \
"${Dmid[3]}" ${value[3]}, "${Dmid[4]}" ${value[4]}, "${Dmid[5]}" ${value[5]}, \
"${Dmid[6]}" ${value[6]}, "${Dmid[7]}" ${value[7]}, "${Dmid[8]}" ${value[8]}, \
"${low_Dmid}" ${high_value})
set yrange [${rmerge_min}:${rmerge_max}]
set xrange [${low_value}:${high_value}]
set output 'rmerge_rmeans_rpim_vs_resolution.svg'
plot 'analysis_vs_resolution.dat' using 2:4 with lines lc rgb '#e31a1c' lw 2 ti 'Rmerge', \
     'analysis_vs_resolution.dat' using 2:7 with lines lc rgb '#1f78b4' lw 2 ti 'Rmeas', \
     'analysis_vs_resolution.dat' using 2:8 with lines lc rgb '#33a02c' lw 2 ti 'Rpim'
EOF

#############################################
# Plot 5: Scales vs Batch
#############################################
gnuplot << EOF
set term svg size 1000,600 enhanced background rgb 'white' font 'Arial Narrow,20'
set grid; set key outside
set title 'Scales against Rotation Range'
set xlabel 'Batch'
set ylabel 'Mn(k) & 0k'; set y2label 'Bfactor & Bdecay'
set ytics nomirror; set y2tics
set xrange [1:${batch_number}]
set yrange [${scale_y_min}:${scale_y_max}]
set y2range [${scale_y2_min}:${scale_y2_max}]
set output 'scales_vs_batch.svg'
plot 'scales_vs_batch.dat' using 4:5 with lines lc rgb '#e31a1c' lw 2 ti 'Mn(k)', \
     'scales_vs_batch.dat' using 4:6 with lines lc rgb '#1f78b4' lw 2 ti '0k', \
     'scales_vs_batch.dat' using 4:8 with lines lc rgb '#33a02c' lw 2 ti 'Bfactor' axes x1y2, \
     'scales_vs_batch.dat' using 4:9 with lines lc rgb '#b2df8a' lw 2 ti 'Bdecay' axes x1y2
EOF

#############################################
# Plot 6: Rmerge & I/Sigma vs Batch
#############################################
gnuplot << EOF
set term svg size 1000,600 enhanced background rgb 'white' font 'Arial Narrow,20'
set grid; set key outside
set title 'Rmerge and <I/σ> against Batches'
set xlabel 'Batch'; set ylabel 'Rmerge'; set y2label '<I/σ>'
set ytics nomirror; set y2tics
set xrange [1:${batch_number}]
set yrange [${r_y_min}:${r_y_max}]
set y2range [${r_y2_min}:${r_y2_max}]
set output 'rmerge_and_i_over_sigma_vs_batch.svg'
plot 'rmerge_and_i_over_sigma_vs_batch.dat' using 2:6 with lines lc rgb '#e31a1c' lw 2 ti 'Rmerge', \
     'rmerge_and_i_over_sigma_vs_batch.dat' using 2:5 with lines lc rgb '#1f78b4' lw 2 ti '<I/σ>' axes x1y2
EOF

#############################################
# Plot 7: L-test
#############################################
gnuplot << EOF
set term svg size 1000,600 enhanced background rgb 'white' font 'Arial Narrow,20'
set grid; set key outside
set title 'L-test'
set xlabel '|L|'; set xrange [0:1]; set yrange [${lt_min}:${lt_max}]
set output 'L_test.svg'
set label 'L statistic = ${L_statistic}' at graph 0.98,0.20 right textcolor rgb '#1f78b4' font 'Verdana,14'
set label 'Twinning fraction = 0.000  L = 0.500' at graph 0.98,0.12 right textcolor rgb '#e31a1c' font 'Verdana,14'
set label 'Twinning fraction = 0.100  L = 0.440' at graph 0.98,0.08 right textcolor rgb '#1f78b4' font 'Verdana,14'
set label 'Twinning fraction = 0.500  L = 0.375' at graph 0.98,0.04 right textcolor rgb '#33a02c' font 'Verdana,14'
plot 'L_test.dat' using 1:2 with lines lc rgb '#1f78b4' lw 2 ti 'N(L)', \
     'L_test.dat' using 1:3 with lines lc rgb '#e31a1c' lw 2 ti 'Untwinned', \
     'L_test.dat' using 1:4 with lines lc rgb '#33a02c' lw 2 ti 'Twinned'
EOF

