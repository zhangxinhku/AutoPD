#!/bin/bash
#############################################################################################################
# Script Name: header.sh
# Description: Extract diffraction image header information using DIALS.
#              Generates standardized header information for AutoPD data reduction logs.
#
# Usage Example:
#   ./header.sh
#
# Required Environment Variables:
#   DATA_PATH    Path to diffraction image files
#   FILE_TYPE    Type of diffraction files (e.g., h5, cbf, img)
#
# Outputs:
#   Writes formatted header summary to stdout (typically redirected to header.log).
#
# Dependencies:
#   DIALS (dials.import, dials.show)
#
# Author:      ZHANG Xin
# Created:     2023-06-01
# Last Edited: 2024-03-05
#############################################################################################################

#############################################
# Import diffraction data with DIALS
#############################################
case "${FILE_TYPE}" in
  "h5")
    # For Eiger / Pilatus HDF5 data: import the master file
    file_name=$(find "${DATA_PATH}" -maxdepth 1 -type f ! -name '.*' -name "*master.h5" -printf "%f")
    dials.import ${DATA_PATH}/${file_name} > /dev/null
    ;;
  *)
    # For standard image formats (cbf, img, etc.)
    dials.import ${DATA_PATH} > /dev/null
    ;;
esac

# Generate a human-readable summary
dials.show imported.expt > imported.txt

#############################################
# Print formatted header information
#############################################
echo "============================================================================================="
echo "                                       Data reduction                                        "
echo "============================================================================================="
echo ""
echo "------------------------------------- Header information ------------------------------------"
echo ""
echo "Location of raw images              = ${DATA_PATH}"

# Extract number of images
number_of_images=$(grep "number of images" imported.txt | awk '{print $4}')
echo "Number of images                    = ${number_of_images}"

# Extract image range
image_range=$(grep "image range" imported.txt | cut -d '{' -f2 | cut -d '}' -f1)
echo "Image range (start,end)             = ${image_range}"

# Extract exposure time
exposure_time=$(grep "exposure time" imported.txt | awk '{print $3}')
echo "Exposure time             [seconds] = ${exposure_time}"

# Extract wavelength
wavelength=$(grep "wavelength" imported.txt | awk '{print $2}')
echo "Wavelength                      [Å] = ${wavelength}"

# Extract oscillation start and step
oscillation_start=$(grep "oscillation" imported.txt | cut -d '{' -f2 | cut -d ',' -f1 | xargs printf "%.3f")
oscillation=$(grep "oscillation" imported.txt | cut -d ',' -f2 | cut -d '}' -f1 | xargs printf "%.3f")
oscillation_end=$(echo "scale=3; ${oscillation_start}+${number_of_images}*${oscillation}" | bc)
echo "Oscillation (start,end)    [degree] = ${oscillation_start},${oscillation_end}"
echo "Oscillation-angle          [degree] = ${oscillation}"

# Extract pixel size
pixel_size=$(grep "pixel_size" imported.txt | cut -d '{' -f2 | cut -d '}' -f1)
echo "Pixel size (X,Y)               [mm] = ${pixel_size}"

# Extract image size
image_size=$(grep "image_size" imported.txt | cut -d '{' -f2 | cut -d '}' -f1)
echo "Image size (X,Y)            [pixel] = ${image_size}"

# Extract resolution estimates
max_resolution_at_corners=$(grep "Max resolution (at corners)" imported.txt | awk '{print $5}')
echo "Max resolution (at corners)     [Å] = ${max_resolution_at_corners}"
max_resolution_inscribed=$(grep "Max resolution (inscribed)" imported.txt | awk '{print $4}')
echo "Max resolution (inscribed)      [Å] = ${max_resolution_inscribed}"

# Extract detector distance
distance=$(grep "distance" imported.txt | head -n 1 | awk '{print $2}' | xargs printf "%.2f")
echo "Distance_start                 [mm] = ${distance}"

# Extract beam center
beam_center_start=$(grep "px" imported.txt | cut -d '(' -f2 | cut -d ')' -f1)
echo "Beam_center_start (X,Y)     [pixel] = ${beam_center_start}"
