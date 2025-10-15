#!/bin/bash
#############################################################################################################
# Script Name: sad.sh
# Description: This script runs a Single-wavelength Anomalous Dispersion (SAD) phasing pipeline using Crank2. 
#              It takes MTZ data, sequence file, anomalous atom type, and wavelength as input and 
#              performs substructure detection, hand determination, density modification, 
#              and model building to produce phased electron density maps and a PDB model.
#
# Usage:
#   ./sad.sh <MTZ_file> <Sequence_file> <Atom_type> <Wavelength>
#
# Arguments:
#   MTZ_file        Path to MTZ file containing anomalous data (with I(+), I(-), and SIGI columns).
#   Sequence_file   Protein sequence file in FASTA format.
#   Atom_type       Heavy atom type used for anomalous scattering (e.g., Se, S, Fe).
#   Wavelength      Data collection wavelength in Ångströms (used to refine anomalous contribution).
#
# Input:
#   - MTZ reflection data with anomalous pairs.
#   - Protein sequence (FASTA format).
#
# Output:
#   - crank2.mtz : Output MTZ file with phased data.
#   - crank2.pdb : Built protein model after SAD phasing.
#   - crank2 directory with detailed intermediate logs and results.
#
# Dependencies:
#   - CCP4 (with Crank2 installed)
#   - Python (for Crank2 driver script)
#
# Example:
#   ./sad.sh data.mtz sequence.fasta Se 0.979
#
# Author: ZHANG Xin
# Date Created: 2023-06-01
# Last Modified: 2025-08-03
#############################################################################################################

# Input variables
MTZ=${1}        # Path to MTZ file
SEQ=${2}        # Path to sequence file
ATOM=${3}       # Heavy atom type for anomalous scattering
WAVELENGTH=${4} # Data collection wavelength

# Run Crank2 SAD pipeline
python3 $CCP4/share/ccp4i/crank2/crank2.py \
    dirout crank2 \               # Output directory name
    hklout crank2.mtz \           # Output MTZ file
    xyzout crank2.pdb << END      # Output PDB file

# SAD phasing steps
faest      afro           # Estimate F and ΔF from anomalous differences
substrdet  prasa          # Substructure detection (heavy atom search)
refatompick               # Refine heavy atom positions
handdet                   # Determine correct hand (enantiomorph)
dmfull                    # Density modification for improved maps
comb_phdmmb               # Combine phase information and build model

# Input MTZ data: anomalous pairs
fsigf plus i=I(+) sigi=SIGI(+) file=${MTZ}
fsigf minus i=I(-) sigi=SIGI(-) wavel=${WAVELENGTH}

# Protein sequence
sequence file=${SEQ}

# Heavy atom substructure model
model substr atomtype=${ATOM}

# Define target phasing method
target::SAD

END
