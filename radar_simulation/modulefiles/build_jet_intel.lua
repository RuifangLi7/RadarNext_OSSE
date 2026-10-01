help([[
This module loads libraries for building the RRFS workflow on
the NOAA RDHPC machine Jet using Intel-2022.1.2
]])

whatis([===[Loads libraries needed for building the RRFS workflow on Jet ]===])

prepend_path("MODULEPATH", "/contrib/spack-stack/spack-stack-1.5.1/envs/gsi-addon-rocky8/install/modulefiles//Core")

load("stack-intel/2021.5.0")
load("stack-intel-oneapi-mpi/2021.5.1")
load("parallelio/2.5.10")
load("jasper/2.0.32")
load("libpng/1.6.37")
load("g2/3.4.5")
--load("g2tmpl/1.10.2")
setenv("g2tmpl_ROOT","/lfs5/BMC/wrfruc/mhu/rrfs/lib/g2tmpl/install")
load("w3emc/2.10.0")
load("w3nco/2.4.1")
load("wgrib2/2.0.8")
load("ncio/1.1.2")
load("nco/5.0.6")
load("bufr/11.7.0")

setenv("CMAKE_C_COMPILER","mpiicc")
setenv("CMAKE_CXX_COMPILER","mpiicpc")
setenv("CMAKE_Fortran_COMPILER","mpiifort")
