list(APPEND src_mosaic
  module_netCDFsub.f90
  module_read_ncep_binary.f90
  module_read_nssl_binary.f90
  module_read_grib2.f90
  module_read_NSSL_mosaic.f90
  module_write_nsslref.f90
  module_mosaic_interp.f90
  process_NSSL_mosaic.f90)

add_executable(process_NSSL_mosaic.exe ${src_mosaic})
target_link_libraries(process_NSSL_mosaic.exe PRIVATE ${PROJECT_NAME}::kinds
					             PRIVATE ${PROJECT_NAME}::constants
					             PRIVATE ${PROJECT_NAME}::mpasio
                                                     PRIVATE NetCDF::NetCDF_Fortran
                                                     PRIVATE g2::g2_4
                                                     PRIVATE bacio::bacio_4
                                                     PRIVATE bufr::bufr_4
                                                     PRIVATE MPI::MPI_Fortran)

install(
  TARGETS process_NSSL_mosaic.exe
  EXPORT ${PROJECT_NAME}Exports
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
