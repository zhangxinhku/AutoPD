#!/bin/bash
#############################################################################################################
# Script Name: sg2pg.sh
# Description: Determines crystallographic point group from a given space group symbol.
#
# Usage Example:
#   ./sg2pg.sh P212121
#
# Input:
#   A space group symbol (string), e.g. "P212121" or "C121"
#
# Output:
#   Corresponding point group (string), printed to stdout
#
# Exit Codes:
#   0   Success
#   1   Invalid or unsupported space group
#
# Author:      ZHANG Xin
# Created:     2023-06-01
# Last Edited: 2025-08-03
#############################################################################################################

#############################################
# Read input parameter
#############################################
space_group=$1

#############################################
# Map space group to point group
#############################################
case "$space_group" in
    # Triclinic
    "P1") echo "1" ;;
    
    # Monoclinic
    "P121" | "P1211") echo "P2" ;;
    "C121") echo "C2" ;;
    "I121") echo "I2" ;;
    
    # Orthorhombic
    "P222" | "P2221" | "P2122" | "P2212" | "P22121" | "P21221" | "P21212" | "P212121") echo "P222" ;;
    "C2221" | "C2122" | "C2212" | "C222") echo "C222" ;;
    "F222") echo "F222" ;;
    "I222" | "I212121") echo "I222" ;;
    
    # Tetragonal
    "P4" | "P41" | "P42" | "P43") echo "P4" ;;
    "I4" | "I41") echo "I4" ;;
    "P422" | "P4212" | "P4122" | "P41212" | "P4222" | "P42212" | "P4322" | "P43212") echo "P422" ;;
    "I422" | "I4122") echo "I422" ;;
    
    # Trigonal / Hexagonal
    "P3" | "P31" | "P32") echo "P3" ;;
    "R3") echo "R3" ;;
    "H3") echo "H3" ;;
    "P312" | "P321" | "P3112" | "P3121" | "P3212" | "P3221") echo "P32" ;;
    "R32") echo "R32" ;;
    "H32") echo "H32" ;;
    "P6" | "P61" | "P62" | "P63" | "P64" | "P65") echo "6" ;;
    "P622" | "P6122" | "P6222" | "P6322" | "P6422" | "P6522") echo "622" ;;
    
    # Cubic
    "P23" | "P213") echo "P23" ;;
    "F23") echo "F23" ;;
    "I23" | "I213") echo "I23" ;;
    "P432" | "P4232" | "P4332" | "P4132") echo "P432" ;;
    "F432" | "F4132") echo "F432" ;;
    "I432" | "I4132") echo "I432" ;;
    
    # Fallback
    *)
        echo "Invalid space group name!"
        exit 1
        ;;
esac
