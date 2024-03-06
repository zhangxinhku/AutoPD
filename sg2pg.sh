#!/bin/bash
#############################################################################################################
# Script Name: sg2pg.sh
# Description: This script determines point group from space group.
# Author: ZHANG Xin
# Date Created: 2023-06-01
# Last Modified: 2024-03-05
#############################################################################################################

#Input parameter
space_group=$1

#Determine point group from space group
case "$space_group" in
    "P1") echo "1" ;;
    "P121" | "P1211") echo "P2" ;;
    "C121") echo "C2" ;;
    "I121") echo "I2" ;;
    "P222" | "P2221" | "P2122" | "P2212" | "P22121" | "P21221" | "P21212" | "P212121") echo "P222" ;;
    "C2221" | "C2122" | "C2212" | "C222") echo "C222" ;;
    "F222") echo "F222" ;;
    "I222" | "I212121") echo "I222" ;;
    "P4" | "P41" | "P42" | "P43") echo "P4" ;;
    "I4" | "I41") echo "I4" ;;
    "P422" | "P4212" | "P4122" | "P41212" | "P4222" | "P42212" | "P4322" | "P43212") echo "P422" ;;
    "I422" | "I4122") echo "I422" ;;
    "P3" | "P31" | "P32") echo "P3" ;;
    "R3") echo "R3" ;;
    "P312" | "P321" | "P3112" | "P3121" | "P3212" | "P3221") echo "P32" ;;
    "R32") echo "R32" ;;
    "P6" | "P61" | "P62" | "P63" | "P64" | "P65") echo "6" ;;
    "P622" | "P6122" | "P6222" | "P6322" | "P6422" | "P6522") echo "622" ;;
    "P23" | "P213") echo "P23" ;;
    "F23") echo "F23" ;;
    "I23" | "I213") echo "I23" ;;
    "P432" | "P4232" | "P4332" | "P4132") echo "P432" ;;
    "F432" | "F4132") echo "F432" ;;
    "I432" | "I4132") echo "I432" ;;
    *)
        echo "Invalid space group name!"
        ;;
esac
