################################ Autobuild ################################
start_time=$(date +%s)
#Input variables
echo ""
echo "----------------------------------------- Autobuild -----------------------------------------"
echo ""
MTZ=$(readlink -f "${1}")
PDB=$(readlink -f "${2}")
SEQUENCE=$(readlink -f "${3}")

#Create folder for autobuild
mkdir -p AUTOBUILD
cd AUTOBUILD
mkdir -p SUMMARY

nproc=$(nproc)

#phenix.autobuild
phenix.autobuild data=${MTZ} seq_file=${SEQUENCE} model=${PDB} quick=true nproc=${nproc} skip_hexdigest=True skip_xtriage=True remove_residues_on_special_positions=True  > AUTOBUILD.log

awk '/SOLUTION/,/Citations for AutoBuild:/' AUTOBUILD.log | sed '$d'

BUILT=$(grep 'CA ' AutoBuild_run_1_/overall_best.pdb | wc -l)
PLACED=$(grep 'CA ' AutoBuild_run_1_/overall_best.pdb | grep -v 'UNK'  | wc -l)
echo "BUILT=${BUILT}" | tee -a AUTOBUILD.log
echo "PLACED=${PLACED}" | tee -a AUTOBUILD.log

echo ""
echo "Autobuild finished!"

end_time=$(date +%s)
total_time=$((end_time - start_time))

hours=$((total_time / 3600))
minutes=$(( (total_time % 3600) / 60 ))
seconds=$((total_time % 60))

echo "" | tee -a AUTOBUILD.log
echo "Phenix.autobuild took: ${hours}h ${minutes}m ${seconds}s" | tee -a AUTOBUILD.log

cp AutoBuild_run_1_/overall_best.pdb SUMMARY/AUTOBUILD.pdb
mv AUTOBUILD.log SUMMARY/AUTOBUILD.log

#Copy results to SUMMARY folder
#cp AutoBuild_run_1_/overall_best.pdb ../SUMMARY/AUTOBUILD.pdb
#cp AUTOBUILD.log ../SUMMARY/AUTOBUILD.pdb

#Go to data processing folder
cd ..