#Input variables
TEMPLATE_NUMBER=${1}
MTZ_DIR=${2}
ENSEMBLE_PATH=$(readlink -f "${3}")
FLAG=${4}
Z_NUMBER=${5}

mtz_files=($(ls "${MTZ_DIR}"/*.mtz))
num_mtz_files=${#mtz_files[@]}

solution_num=0

for ((i=1; i<=num_mtz_files; i++)); do
  mtz_file=${mtz_files[$i-1]}
  ${SOURCE_DIR}/ipcas_mtz.sh ${mtz_file} ${mtz_file} FP SIGFP FreeR_flag F SIGF FreeR_flag > /dev/null 2>&1
  mkdir -p MR_${FLAG}_$i
  cd MR_${FLAG}_$i
  cp ${mtz_file} .
  
  if [[ -z "${Z_NUMBER}" ]]; then
    #phaser_cca
    phaser << eof > phaser_cca.log
    TITLE phaser_cca
    MODE CCA
    ROOT PHASER_CCA
    HKLIN ${mtz_file}
    LABIN F=F SIGF=SIGF
    COMPOSITION BY ASU
    COMPOSITION PROTEIN SEQ ${SEQUENCE} NUM 1
eof

    #Extract NUMBER from phaser_cca result
    CCA_EXIT_STATUS=$(grep 'EXIT STATUS:' phaser_cca.log | awk '{print $3}')

    Z_NUMBER=$(awk '/loggraph/{flag=1;next}/\$\$/{flag=0}flag' phaser_cca.log | sort -k2,2nr | head -n 1 | awk '{print $1}')

    echo ""
    echo "MR_${FLAG}_$i Phaser CCA EXIT STATUS: ${CCA_EXIT_STATUS}"
    
    if [ ${CCA_EXIT_STATUS} == "FAILURE" ]; then
      exit 1
    else
      echo ""
      echo "MR_${FLAG}_$i Most probable Z=${Z_NUMBER}"
    fi
  else
    echo "Input Z=${Z_NUMBER}"
  fi

  echo "TITLE phaser_mr
MODE MR_AUTO
ROOT PHASER
HKLIN ${mtz_file}
LABIN F=F SIGF=SIGF
SGALTERNATIVE SELECT ALL" > phaser_input.txt

  for ((j=1; j<=${TEMPLATE_NUMBER}; j++)); do
    first_line=$(head -n 1 ${ENSEMBLE_PATH}/ENSEMBLE${j}.pdb)
    
    if [[ $first_line == *ID* ]]; then
      IDENTITY=$(echo "$first_line" | awk -F 'ID ' '{print $2}')
    else
      IDENTITY=90
    fi
    echo "ENSEMBLE ensemble${j} PDB ${ENSEMBLE_PATH}/ENSEMBLE${j}.pdb IDENTITY ${IDENTITY}" >> phaser_input.txt
  done

  echo "COMPOSITION BY ASU" >> phaser_input.txt
  echo "COMPOSITION PROTEIN SEQ ${SEQUENCE} NUM ${Z_NUMBER}" >> phaser_input.txt

  for ((j=1; j<=TEMPLATE_NUMBER; j++)); do
    echo "SEARCH ENSEMBLE ensemble${j} NUM ${Z_NUMBER}" >> phaser_input.txt
  done

  phaser < phaser_input.txt > phaser_mr.log &

  cd ..
  Z_NUMBER=""
done
#IDENTITY ${IDENTITY}
wait 
