#!/bin/sh
#

dir_root=$(pwd)
COMPILER=${COMPILER:-intel}

#HOMErrfs="/work2/noaa/wrfruc/Ruifang.Li/RadarNext_OSSE/Code/rrfs-workflow"
#source "${HOMErrfs}"/workflow/tools/detect_machine.sh
#source "${HOMErrfs}"/workflow/tools/init.sh
source ./detect_machine.sh
source ./init.sh

################# Hera or Ursa ####################
if [[ -d /scratch3 ]]; then
    if [[ -d /apps/slurm_hera ]]; then
        platform=hera
    else
        platform=ursa
    fi
    source /etc/profile.d/modules.sh

################# Jet ####################
elif [[ -d /jetmon ]] ; then
    source /etc/profile.d/modules.sh
    platform=jet

################# Cheyenne ####################
elif [[ -d /glade ]] ; then
    platform=derecho

################# MSU HPC2 ####################
elif [[ -d /work/noaa ]] ; then
    hoststr=$(hostname)
    if [[ "$hoststr" == "hercules"* ]]; then
        platform=hercules
    else
        platform=orion
    fi

################# Gaea C6 ####################
elif [[ -d /gpfs/f6 ]] ; then ### gaea c6
    platform=gaeac6

################# WCOSS2 ####################
elif [[ -d /lfs ]] ; then  ### orion
    platform=wcoss2

################# Generic ####################
else
    echo -e "\nunknown machine"
    exit 9
fi

if [ ! -f $modulefile ]; then
    echo "modulefiles $modulefile does not exist"
    exit 10
fi

module purge
module use ${dir_root}/modulefiles
module load build_${platform}_${COMPILER}.lua
module list 

build_root=${dir_root}/build
rm -rf "${build_root}"
mkdir -p "${build_root}"
cd "${build_root}" || exit 1

cmake .. -DCMAKE_INSTALL_PREFIX=.

make VERBOSE=1 -j 1 
make install

exit
