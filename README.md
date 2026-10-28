The entire process creating syntethic MRMS observations has 4 steps:

1. Create a radar network. The output is a text file containing a list of the radars with metadata. Scripts and outputs are found in setup_radar_network/

2. Create a mask file. Scripts that do this are found in radar_masking/. The script requires a network text file as input, as well as the terrain file. Steps for interpolating the source terrain file to the grid on which the mask will be created are found in the script at radar_masking/regrid_terrain.py

3. Spatially interpolate the nature run fields to the synthetic obs grid (in this case, MRMS). This is done using the code in directory radar_simulation/. README shows steps to simulate observation.

3. Create synthetic obs files by processing interpolated files for realism. This includes slant-range-based smoothing (to account for beam spreading) and attenuation by atmospheric gases and rain. A script and workflow for this is found in directory radar_processing/

