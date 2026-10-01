#!/bin/sh -l

## more info: https://intranet.hpc.msstate.edu/helpdesk/resource-docs/slurm_guide.php#slurm-submission
#SBATCH -A wrfruc
#SBATCH -t 08:00:00  # maxium
#SBATCH --ntasks=1   # total process, 
#SBATCH --mem=150G
#SBATCH --partition=hercules-2   # hercules
#SBATCH --qos=batch      # normal, ood not working

set -x

COMPILER=${COMPILER:-intel}
platform=hercules
dir_root=/work2/noaa/wrfruc/Ruifang.Li/RadarNext_OSSE
NR=/work/noaa/wrfruc/murdzek/nature_run_spring/UPP
nr2MrmsGrid="${dir_root}/Data/nr2MrmsGrid"
refl_MRMS="${dir_root}/Data/refl_MRMS"
refl_simul="${dir_root}/Data/refl_simulated"
mask="/work/noaa/wrfruc/jdduda/radar_mask/radar_mask.nc"
yyyy=2022
mm=04


module purge
module use ${dir_root}/radar_simulation/modulefiles
module load build_${platform}_${COMPILER}.lua
module list
ulimit -s unlimited
ulimit -a

# Run Program
# =========================

echo "start_process: $(date)  "

cd ${refl_simul}

for dd in $(seq -w 29 29); do
 for hh in $(seq -w 12 12); do
  #for min in 00 15 30 45; do
  for min in 15; do
   
    # NR file
    nr_refd=${nr2MrmsGrid}/REFD_${yyyy}${mm}${dd}${hh}${min}.grib2
    nr_hgt=${nr2MrmsGrid}/HGT_${yyyy}${mm}${dd}${hh}${min}.grib2

    if [[ -s ${nr_refd} ]] && [[ -s ${nr_hgt} ]] ; then
      echo "Process ${yyyy}${mm}${dd}-${hh}${min} column"
      tmp=${yyyy}${mm}${dd}-${hh}${min}
      mkdir -p ${tmp}     
      cd ${tmp}
      rm *
      ln -sf ${nr_refd} nr_refd
      ln -sf ${nr_hgt} nr_hgt
      ln -sf ${mask} radar_mask

      valid=${yyyy}${mm}${dd}${hh}${min}

# Create namelists for NR
cat << EOF > namelist.file
   &setup
    tversion=1,
    analysis_time = ${valid},
    dataPath = './',
   /
EOF

      exec=/${dir_root}/radar_simulation/build/bin/process_NSSL_mosaic.exe
      echo "start_simulate: $(date)  "
      srun --export=ALL ${exec}
      echo "end_simulate: $(date)  "

    else
      echo "INFO: can't find NR file ${nr_refd} or ${nr_hgt}. Skip ${yyyy}${mm}${dd}-${hh}${min}"	    
    fi
    cd ..
    echo " "

  done #min
 done 
done
      
echo "end_process: $(date)  "

