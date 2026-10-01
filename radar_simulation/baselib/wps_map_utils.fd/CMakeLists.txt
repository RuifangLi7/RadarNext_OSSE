list(APPEND src_wps_map_utils
  module_wps_constants.f90
  module_wps_misc_definitions.f90
  module_wps_map_utils.f90)

set(module_dir "${CMAKE_CURRENT_BINARY_DIR}/include")
add_library(wps_map_utils STATIC ${src_wps_map_utils})
add_library(${PROJECT_NAME}::wps_map_utils ALIAS wps_map_utils)
set_target_properties(wps_map_utils PROPERTIES Fortran_MODULE_DIRECTORY "${module_dir}")
#target_include_directories(wps_map_utils PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
#                                          $<INSTALL_INTERFACE:include>)
install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include DESTINATION ${CMAKE_INSTALL_PREFIX})

install(
  TARGETS wps_map_utils
  EXPORT ${PROJECT_NAME}Exports
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
