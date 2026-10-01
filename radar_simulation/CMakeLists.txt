cmake_minimum_required(VERSION 3.15)

project(RRFS_UTILS
	VERSION 1.0.0
	LANGUAGES C Fortran)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
set(CMAKE_DIRECTORY_LABELS ${PROJECT_NAME})

include(compiler_flags)
include(GNUInstallDirs)

SET(CMAKE_C_COMPILER_ID "Intel")
SET(CMAKE_Fortran_COMPILER_ID "Intel")
#SET(CMAKE_BUILD_TYPE "Release")

SET(CFLAGS "${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_${CMAKE_BUILD_TYPE}}")      
SET(CPPFLAGS "${CMAKE_CPP_FLAGS} ${CMAKE_CPP_FLAGS_${CMAKE_BUILD_TYPE}}")
SET(LDFLAGS "${CMAKE_SHARED_LINKER_FLAGS} ${CMAKE_SHARED_LINKER_FLAGS_${CMAKE_BUILD_TYPE}}")

if(NOT CMAKE_BUILD_TYPE MATCHES "^(Debug|Release|RelWithDebInfo|MinSizeRel|Production)$")
  message(STATUS "Setting build type to 'Release' as none was specified.")
  set(CMAKE_BUILD_TYPE
      "Release"
      CACHE STRING "Choose the type of build." FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo" "Production")
endif()

if(NOT CMAKE_C_COMPILER_ID MATCHES "^(GNU|Intel|Clang|AppleClang)$")
  message(WARNING "${CMAKE_C_COMPILER_ID} is not supported.")
endif()

if(NOT CMAKE_Fortran_COMPILER_ID MATCHES "^(GNU|Intel)$")
  message(WARNING "${CMAKE_Fortran_COMPILER_ID} is not supported.")
endif()

# User options
option(OPENMP "Enable OpenMP Threading" ON)

# Echo user options
message(STATUS "OPENMP ................. ${OPENMP}")

#list(APPEND SUBLIST "MPAS_ENSMEAN_RECENTER")
#list(APPEND SUBLIST "ENS_MEAN_RECENTER")
#list(APPEND SUBLIST "MOSAIC")
#list(APPEND SUBLIST "LARCCLD")
#list(APPEND SUBLIST "METARCLD")
#list(APPEND SUBLIST "LIGHTNING")
#list(APPEND SUBLIST "REFMOSAIC_NONVAR")
#list(APPEND SUBLIST "CLOUDANALYSIS")
list(APPEND SUBLIST "RADAR")
option(RRFS_UTL_ALL "" ON)
foreach(X IN LISTS SUBLIST)
  string(TOLOWER ${X} x)
  option(${X} "Enable building ${x}.fd" ${RRFS_UTL_ALL})
endforeach()

# Dependencies
find_package(MPI REQUIRED)
find_package(NetCDF REQUIRED Fortran)
if(OPENMP)
  find_package(OpenMP REQUIRED)
endif()

# NCEPLibs dependencies
find_package(bacio REQUIRED)
find_package(g2 REQUIRED)
find_package(g2tmpl REQUIRED)
#find_package(sp REQUIRED)
#find_package(ip REQUIRED)
find_package(w3emc REQUIRED)
find_package(w3nco REQUIRED)
find_package(bufr REQUIRED)
#find_package(wrf_io REQUIRED)

# Other dependencies
#find_package(ncdiag REQUIRED)
#find_package(mgbf REQUIRED)
#find_package(gsi REQUIRED)

#add_subdirectory(baselib/regional_esg_grid.fd)
add_subdirectory(baselib/wps_map_utils.fd)
add_subdirectory(baselib)

foreach(X IN LISTS SUBLIST)
  if(${${X}})
    string(TOLOWER ${X} x)
    add_subdirectory(${x}.fd)
  endif()
endforeach()
