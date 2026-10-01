#!/bin/sh -l

#SBATCH -A wrfruc
#SBATCH -t 08:00:00  # maxium
#SBATCH --ntasks=1
#SBATCH --partition=hercules


set -x

module load wgrib2

yymm=202205
nr_dir=/work/noaa/wrfruc/murdzek/nature_run_spring/UPP
nr2MrmsGrid=/work2/noaa/wrfruc/Ruifang.Li/RadarNext_OSSE/Data/nr2MrmsGrid

echo "Start: $(date)"
for dd in $(seq -w 05 05); do
 for hh in $(seq -w 10 10); do
  for min in $(seq -w 30 15 30); do

    nr_file=${nr_dir}/${yymm}${dd}/wrfnat_${yymm}${dd}${hh}${min}_er.grib2
    if [[ -s ${nr_file} ]]; then
      wgrib2 -v ${nr_file} -match_fs "HGT"  -match "hybrid" -set_grib_type same -new_grid_interpolation neighbor \
       	     -new_grid latlon 230.004999:7000:0.010000  54.995000:3500:-0.01 ${nr2MrmsGrid}/HGT_${yymm}${dd}${hh}${min}.grib2

      wgrib2 -v ${nr_file} -match_fs "REFD"  -match "hybrid" -set_grib_type same -new_grid_interpolation neighbor \
      	     -new_grid latlon 230.004999:7000:0.010000  54.995000:3500:-0.01 ${nr2MrmsGrid}/REFD_${yymm}${dd}${hh}${min}.grib2
    else
      echo "NR file not exist: ${nr_file}" 
    fi	    

  done
 done
done

echo "End: $(date)"




