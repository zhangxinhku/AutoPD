#Input variables
L_statistic=${1}

#Calculate values for resolution axis
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

#cchalf_vs_resolution
echo "set term svg size 1000,600 enhanced background rgb 'white' font 'Arial Narrow,20'" > cchalf_vs_resolution.gp
echo "set encoding utf8" >> cchalf_vs_resolution.gp
echo "set grid" >> cchalf_vs_resolution.gp
echo "set key outside" >> cchalf_vs_resolution.gp
echo "set title 'CC(1/2) and CC\_Anom against Resolution' offset 0,1" >> cchalf_vs_resolution.gp
echo "set xlabel 'Resolution [Å]'" >> cchalf_vs_resolution.gp
echo "set ylabel 'CC(1/2) and CC\_Anom' offset 1,0" >> cchalf_vs_resolution.gp
echo "set format y '%.2f'" >> cchalf_vs_resolution.gp
echo "set xtics (\"${high_Dmid}\" ${low_value}, \"${Dmid[1]}\" ${value[1]}, \"${Dmid[2]}\" ${value[2]}, \"${Dmid[3]}\" ${value[3]}, \"${Dmid[4]}\" ${value[4]}, \"${Dmid[5]}\" ${value[5]}, \"${Dmid[6]}\" ${value[6]}, \"${Dmid[7]}\" ${value[7]}, \"${Dmid[8]}\" ${value[8]}, \"${low_Dmid}\" ${high_value})" >> cchalf_vs_resolution.gp
echo "set yrange [0:1]" >> cchalf_vs_resolution.gp
echo "set xrange [${low_value}:${high_value}]" >> cchalf_vs_resolution.gp
echo "set output 'cchalf_vs_resolution.svg'" >> cchalf_vs_resolution.gp
echo "plot 'cchalf_vs_resolution.dat' using 2:7 with lines lc rgb '#fb9a99' lw 2 ti 'CC(1/2)',      'cchalf_vs_resolution.dat' using 2:4 with lines lc rgb '#a6cee3' lw 2 ti 'CC\_Anom'" >> cchalf_vs_resolution.gp
gnuplot cchalf_vs_resolution.gp

#completeness_vs_resolution
echo "set term svg size 1000,600 enhanced background rgb 'white' font 'Arial Narrow,20'" > completeness_vs_resolution.gp
echo "set encoding utf8" >> completeness_vs_resolution.gp
echo "set grid" >> completeness_vs_resolution.gp
echo "set key outside" >> completeness_vs_resolution.gp
echo "set title 'Completeness and AnomCompleteness against Resolution' offset 0,1" >> completeness_vs_resolution.gp
echo "set xlabel 'Resolution [Å]'" >> completeness_vs_resolution.gp
echo "set ylabel 'Completeness and AnomCompleteness' offset 1,0" >> completeness_vs_resolution.gp
echo "set format y '%.2f'" >> completeness_vs_resolution.gp
echo "set xtics (\"${high_Dmid}\" ${low_value}, \"${Dmid[1]}\" ${value[1]}, \"${Dmid[2]}\" ${value[2]}, \"${Dmid[3]}\" ${value[3]}, \"${Dmid[4]}\" ${value[4]}, \"${Dmid[5]}\" ${value[5]}, \"${Dmid[6]}\" ${value[6]}, \"${Dmid[7]}\" ${value[7]}, \"${Dmid[8]}\" ${value[8]}, \"${low_Dmid}\" ${high_value})" >> completeness_vs_resolution.gp
echo "set yrange [0:100]" >> completeness_vs_resolution.gp
echo "set xrange [${low_value}:${high_value}]" >> completeness_vs_resolution.gp
echo "set output 'completeness_vs_resolution.svg'" >> completeness_vs_resolution.gp
echo "plot 'completeness_vs_resolution.dat' using 2:7 with lines lc rgb '#e31a1c' lw 2 ti 'Completeness',      'completeness_vs_resolution.dat' using 2:10 with lines lc rgb '#1f78b4' lw 2 ti 'AnomCmpl'" >> completeness_vs_resolution.gp
gnuplot completeness_vs_resolution.gp

#i_over_sigma_vs_resolution
echo "set term svg size 1000,600 enhanced background rgb 'white' font 'Arial Narrow,20'" > i_over_sigma_vs_resolution.gp
echo "set encoding utf8" >> i_over_sigma_vs_resolution.gp
echo "set grid" >> i_over_sigma_vs_resolution.gp
echo "set key outside" >> i_over_sigma_vs_resolution.gp
echo "set title 'Mean(I/SigI) against Resolution' offset 0,1" >> i_over_sigma_vs_resolution.gp
echo "set xlabel 'Resolution [Å]'" >> i_over_sigma_vs_resolution.gp
echo "set ylabel 'Mean(I/SigI)' offset 1,0" >> i_over_sigma_vs_resolution.gp
echo "set format y '%.2f'" >> i_over_sigma_vs_resolution.gp
echo "set xtics (\"${high_Dmid}\" ${low_value}, \"${Dmid[1]}\" ${value[1]}, \"${Dmid[2]}\" ${value[2]}, \"${Dmid[3]}\" ${value[3]}, \"${Dmid[4]}\" ${value[4]}, \"${Dmid[5]}\" ${value[5]}, \"${Dmid[6]}\" ${value[6]}, \"${Dmid[7]}\" ${value[7]}, \"${Dmid[8]}\" ${value[8]}, \"${low_Dmid}\" ${high_value})" >> i_over_sigma_vs_resolution.gp
echo "set yrange [0:*]" >> i_over_sigma_vs_resolution.gp
echo "set xrange [${low_value}:${high_value}]" >> i_over_sigma_vs_resolution.gp
echo "set output 'i_over_sigma_vs_resolution.svg'" >> i_over_sigma_vs_resolution.gp
echo "plot 'analysis_vs_resolution.dat' using 2:14 with lines lc rgb '#e31a1c' lw 2 ti 'Mn(I/sigI)'" >> i_over_sigma_vs_resolution.gp
gnuplot i_over_sigma_vs_resolution.gp

#rmerge_rmeans_rpim_vs_resolution
echo "set term svg size 1000,600 enhanced background rgb 'white' font 'Arial Narrow,20'" > rmerge_rmeans_rpim_vs_resolution.gp
echo "set encoding utf8" >> rmerge_rmeans_rpim_vs_resolution.gp
echo "set grid" >> rmerge_rmeans_rpim_vs_resolution.gp
echo "set key outside" >> rmerge_rmeans_rpim_vs_resolution.gp
echo "set title 'Rmerge, Rmeans and Rpim against Resolution' offset 0,1" >> rmerge_rmeans_rpim_vs_resolution.gp
echo "set xlabel 'Resolution [Å]'" >> rmerge_rmeans_rpim_vs_resolution.gp
echo "set ylabel 'Rmerge, Rmeans and Rpim' offset 1,0" >> rmerge_rmeans_rpim_vs_resolution.gp
echo "set format y '%.2f'" >> rmerge_rmeans_rpim_vs_resolution.gp
echo "set xtics (\"${high_Dmid}\" ${low_value}, \"${Dmid[1]}\" ${value[1]}, \"${Dmid[2]}\" ${value[2]}, \"${Dmid[3]}\" ${value[3]}, \"${Dmid[4]}\" ${value[4]}, \"${Dmid[5]}\" ${value[5]}, \"${Dmid[6]}\" ${value[6]}, \"${Dmid[7]}\" ${value[7]}, \"${Dmid[8]}\" ${value[8]}, \"${low_Dmid}\" ${high_value})" >> rmerge_rmeans_rpim_vs_resolution.gp
echo "set yrange [0:*]" >> rmerge_rmeans_rpim_vs_resolution.gp
echo "set xrange [${low_value}:${high_value}]" >> rmerge_rmeans_rpim_vs_resolution.gp
echo "set output 'rmerge_rmeans_rpim_vs_resolution.svg'" >> rmerge_rmeans_rpim_vs_resolution.gp
echo "plot 'analysis_vs_resolution.dat' using 2:4 with lines lc rgb '#e31a1c' lw 2 ti 'Rmerge',      'analysis_vs_resolution.dat' using 2:7 with lines lc rgb '#1f78b4' lw 2 ti 'Rmeans',      'analysis_vs_resolution.dat' using 2:8 with lines lc rgb '#33a02c' lw 2 ti 'Rpim'" >> rmerge_rmeans_rpim_vs_resolution.gp
gnuplot rmerge_rmeans_rpim_vs_resolution.gp

#Get batch number
batch_number=$(tail -1 scales_vs_batch.dat | awk '{print $1}')

#scales_vs_batch
echo "set term svg size 1000,600 enhanced background rgb 'white' font 'Arial Narrow,20'" > scales_vs_batch.gp
echo "set encoding utf8" >> scales_vs_batch.gp
echo "set grid" >> scales_vs_batch.gp
echo "set key outside" >> scales_vs_batch.gp
echo "set title 'Scales against rotation range' offset 0,1" >> scales_vs_batch.gp
echo "set tics" >> scales_vs_batch.gp
echo "set xlabel 'Batch'" >> scales_vs_batch.gp
echo "set ylabel 'Mn(k) and 0k' tc rgb '#e31a1c' offset 1,0" >> scales_vs_batch.gp
echo "set y2label 'Bfactor and Bdecay' tc rgb '#1f78b4' offset -1,0" >> scales_vs_batch.gp
echo "set ytics textcolor rgb '#e31a1c'" >> scales_vs_batch.gp
echo "set y2tics textcolor rgb '#1f78b4'" >> scales_vs_batch.gp
echo "set format y '%.2f'" >> scales_vs_batch.gp
echo "set format y2 '%.2f'" >> scales_vs_batch.gp
echo "set ytics nomirror" >> scales_vs_batch.gp
echo "set xrange [1:${batch_number}]" >> scales_vs_batch.gp
y_max=$(awk '{print $5"\n"$6}' scales_vs_batch.dat | sort -n | tail -1)
y_max=$(echo "scale=0; if (${y_max}==${y_max}/1) ${y_max} else ${y_max}/1+1" | bc)
y2_min=$(awk '{print $8"\n"$9}' scales_vs_batch.dat | sort -n | head -1)
y2_min=$(echo "scale=0; if (${y2_min}==${y2_min}/1) ${y2_min} else ${y2_min}/1-1" | bc)
((y2_min == 0)) && y2_min=-1
echo "set yrange [0:${y_max}]" >> scales_vs_batch.gp
echo "set y2range [${y2_min}:0]" >> scales_vs_batch.gp
echo "set output 'scales_vs_batch.svg'" >> scales_vs_batch.gp
echo "plot 'scales_vs_batch.dat' using 4:5 smooth bezier with lines lc rgb '#e31a1c' lw 2 ti 'Mn(k)', 'scales_vs_batch.dat' using 4:5 with lines lc rgb '#fb9a99' lw 1 ti 'Mn(k)(raw)', 'scales_vs_batch.dat' using 4:6 smooth bezier with lines lc rgb '#1f78b4' lw 2 ti '0k', 'scales_vs_batch.dat' using 4:6 with lines lc rgb '#a6cee3' lw 1 ti '0k(raw)', 'scales_vs_batch.dat' using 4:8 with lines lc rgb '#33a02c' lw 2 ti 'Bfactor' axes x1y2, 'scales_vs_batch.dat' using 4:9 with lines lc rgb '#b2df8a' lw 2 ti 'Bdecay' axes x1y2" >> scales_vs_batch.gp
gnuplot scales_vs_batch.gp

#rmerge_and_i_over_sigma_vs_batch
echo "set term svg size 1000,600 enhanced background rgb 'white' font 'Arial Narrow,20'" > rmerge_and_i_over_sigma_vs_batch.gp
echo "set encoding utf8" >> rmerge_and_i_over_sigma_vs_batch.gp
echo "set grid" >> rmerge_and_i_over_sigma_vs_batch.gp
echo "set key outside" >> rmerge_and_i_over_sigma_vs_batch.gp
echo "set title 'Rmerge, <I/σ> against Batches' offset 0,1" >> rmerge_and_i_over_sigma_vs_batch.gp
echo "set xlabel 'Batch'" >> rmerge_and_i_over_sigma_vs_batch.gp
echo "set ylabel 'Rmerge' tc rgb '#e31a1c' offset 1,0" >> rmerge_and_i_over_sigma_vs_batch.gp
echo "set y2label '<I/σ>' tc rgb '#1f78b4' offset -1,0" >> rmerge_and_i_over_sigma_vs_batch.gp
echo "set ytics textcolor rgb '#e31a1c'" >> rmerge_and_i_over_sigma_vs_batch.gp
echo "set y2tics textcolor rgb '#1f78b4'" >> rmerge_and_i_over_sigma_vs_batch.gp
echo "set format y '%.2f'" >> rmerge_and_i_over_sigma_vs_batch.gp
echo "set format y2 '%.2f'" >> rmerge_and_i_over_sigma_vs_batch.gp
echo "set ytics nomirror" >> rmerge_and_i_over_sigma_vs_batch.gp
echo "set xrange [1:${batch_number}]" >> rmerge_and_i_over_sigma_vs_batch.gp
y_max=$(awk '{print $6}' rmerge_and_i_over_sigma_vs_batch.dat | sort -n | tail -1)
y_max=$(echo "scale=0; if (${y_max}==${y_max}/1) ${y_max} else ${y_max}/1+1" | bc)
y2_max=$(awk '{print $5}' rmerge_and_i_over_sigma_vs_batch.dat | sort -n | tail -1)
y2_max=$(echo "scale=0; if (${y2_max}==${y2_max}/1) ${y2_max} else ${y2_max}/1+1" | bc)
echo "set yrange [0:${y_max}]" >> rmerge_and_i_over_sigma_vs_batch.gp
echo "set y2range [0:${y2_max}]" >> rmerge_and_i_over_sigma_vs_batch.gp
echo "set output 'rmerge_and_i_over_sigma_vs_batch.svg'" >> rmerge_and_i_over_sigma_vs_batch.gp
echo "plot 'rmerge_and_i_over_sigma_vs_batch.dat' using 2:6 smooth bezier with lines lc rgb '#e31a1c' lw 2 ti 'Rmerge', 'rmerge_and_i_over_sigma_vs_batch.dat' using 2:6 with lines lc rgb '#fb9a99' lw 1 ti 'Rmerge(raw)', 'rmerge_and_i_over_sigma_vs_batch.dat' using 2:5 smooth bezier with lines lc rgb '#1f78b4' lw 2 ti '<I/σ>' axes x1y2, 'rmerge_and_i_over_sigma_vs_batch.dat' using 2:5 with lines lc rgb '#a6cee3' lw 1 ti '<I/σ>(raw)' axes x1y2" >> rmerge_and_i_over_sigma_vs_batch.gp
gnuplot rmerge_and_i_over_sigma_vs_batch.gp

#L_test
echo "set term svg size 1000,600 enhanced background rgb 'white' font 'Arial Narrow,20'" > L_test.gp
echo "set encoding utf8" >> L_test.gp
echo "set grid" >> L_test.gp
echo "set key outside" >> L_test.gp
echo "set title 'L-test' offset 0,1" >> L_test.gp
echo "set xlabel '|L|'" >> L_test.gp
echo "set ylabel" >> L_test.gp
echo "set xtics" >> L_test.gp
echo "set ytics" >> L_test.gp
echo "set xrange [0:1]" >> L_test.gp
echo "set yrange [0:1]" >> L_test.gp
echo "set output 'L_test.svg'" >> L_test.gp
echo "set label 'L statistic of this dataset =  ${L_statistic}' at graph 0.98,0.20 right textcolor rgb '#1f78b4' font 'Verdana, 14'" >> L_test.gp
echo "set label 'Relation between L statistics and twinning fraction:' at graph 0.98,0.16 right font 'Verdana, 14'" >> L_test.gp
echo "set label 'Twinning fraction = 0.000  L statistics = 0.500' at graph 0.98,0.12 right textcolor rgb '#e31a1c' font 'Verdana, 14'" >> L_test.gp
echo "set label 'Twinning fraction = 0.100  L statistics = 0.440' at graph 0.98,0.08 right textcolor rgb '#1f78b4' font 'Verdana, 14'" >> L_test.gp
echo "set label 'Twinning fraction = 0.500  L statistics = 0.375' at graph 0.98,0.04 right textcolor rgb '#33a02c' font 'Verdana, 14'" >> L_test.gp
echo "plot 'L_test.dat' using 1:2 with lines lc rgb '#1f78b4' lw 2 ti 'N(L)', 'L_test.dat' using 1:3 with lines lc rgb '#e31a1c' lw 2 ti 'Untwinned', 'L_test.dat' using 1:4 with lines lc rgb '#33a02c' lw 2 ti 'Twinned'" >> L_test.gp
gnuplot L_test.gp
