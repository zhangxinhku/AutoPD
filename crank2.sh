#!/bin/bash
#############################################################################################################
# Script Name: sad.sh
# Description: This script is used for SAD.
# Author: ZHANG Xin
# Date Created: 2023-06-01
# Last Modified: 2024-04-17
#############################################################################################################

#Input variables
MTZ=${1}
SEQ=${2}
ATOM=${3}
WAVELENGTH=${4}

python3 $CCP4/share/ccp4i/crank2/crank2.py dirout crank2 hklout crank2.mtz xyzout crank2.pdb << END

faest      afro
substrdet  prasa
refatompick
handdet
dmfull
comb_phdmmb

fsigf plus i=I(+) sigi=SIGI(+) file=${MTZ}
fsigf minus i=I(-) sigi=SIGI(-) wavel=${WAVELENGTH}
sequence file=${SEQ}
model substr atomtype=${ATOM}

target::SAD

END
