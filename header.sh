#Input variables
DATAPATH=${1}
file_type=${2}
#file_name=$(find ${DATAPATH} -type f -name "*master.h5" -printf "%f")
case "${file_type}" in
  "h5")
    file_name=$(find "${DATAPATH}" -maxdepth 1 -type f ! -name '.*' -name "*master.h5" -printf "%f")
    dials.import ${DATAPATH}/${file_name} > /dev/null
    ;;
  *)
    dials.import ${DATAPATH} > /dev/null
    ;;
esac
dials.show imported.expt > imported.txt
echo "============================================================================================="
echo "                                       Data reduction                                        "
echo "============================================================================================="
echo ""
echo "------------------------------------- Header information ------------------------------------"
echo ""
echo "Location of raw images              = ${DATAPATH}"
number_of_images=$(grep "number of images" imported.txt | awk '{print $4}')
echo "Number of images                    = ${number_of_images}"
image_range=$(grep "image range" imported.txt | cut -d '{' -f2 | cut -d '}' -f1)
echo "Image range (start,end)             = ${image_range}"
exposure_time=$(grep "exposure time" imported.txt | awk '{print $3}')
echo "Exposure time             [seconds] = ${exposure_time}"
wavelength=$(grep "wavelength" imported.txt | awk '{print $2}')
echo "Wavelength                      [Å] = ${wavelength}"
oscillation_start=$(grep "oscillation" imported.txt | cut -d '{' -f2 | cut -d ',' -f1 | xargs printf "%.3f")
oscillation=$(grep "oscillation" imported.txt | cut -d ',' -f2 | cut -d '}' -f1 | xargs printf "%.3f")
oscillation_end=$(echo "scale=3; ${oscillation_start}+${number_of_images}*${oscillation}" | bc)
echo "Oscillation (start,end)    [degree] = ${oscillation_start},${oscillation_end}"
echo "Oscillation-angle          [degree] = ${oscillation}"
pixel_size=$(grep "pixel_size" imported.txt | cut -d '{' -f2 | cut -d '}' -f1)
echo "Pixel size (X,Y)               [mm] = ${pixel_size}"
image_size=$(grep "image_size" imported.txt | cut -d '{' -f2 | cut -d '}' -f1)
echo "Image size (X,Y)            [pixel] = ${image_size}"
max_resolution_at_corners=$(grep "Max resolution (at corners)" imported.txt | awk '{print $5}')
echo "Max resolution (at corners)     [Å] = ${max_resolution_at_corners}"
max_resolution_inscribed=$(grep "Max resolution (inscribed)" imported.txt | awk '{print $4}')
echo "Max resolution (inscribed)      [Å] = ${max_resolution_inscribed}"
distance=$(grep "distance" imported.txt | head -n 1 | awk '{print $2}' | xargs printf "%.2f")
echo "Distance_start                 [mm] = ${distance}"
beam_center_start=$(grep "px" imported.txt | cut -d '(' -f2 | cut -d ')' -f1)
echo "Beam_center_start (X,Y)     [pixel] = ${beam_center_start}"
