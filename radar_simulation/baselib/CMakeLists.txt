set(module_dir "${CMAKE_CURRENT_BINARY_DIR}/include")

add_library(kinds STATIC module_kinds.f90)
add_library(${PROJECT_NAME}::kinds ALIAS kinds)
set_target_properties(kinds PROPERTIES Fortran_MODULE_DIRECTORY "${module_dir}")
target_include_directories(kinds PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
                                       $<INSTALL_INTERFACE:include>)
install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include DESTINATION ${CMAKE_INSTALL_PREFIX})
list(APPEND BASE_LIB_Targets kinds)

add_library(constants STATIC module_constants.f90)
add_library(${PROJECT_NAME}::constants ALIAS constants)
set_target_properties(constants PROPERTIES Fortran_MODULE_DIRECTORY "${module_dir}")
target_link_libraries(constants PRIVATE ${PROJECT_NAME}::kinds)
target_include_directories(constants PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
                                       $<INSTALL_INTERFACE:include>)
install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include DESTINATION ${CMAKE_INSTALL_PREFIX})
list(APPEND BASE_LIB_Targets constants)

add_library(ncio STATIC module_ncio.f90)
add_library(${PROJECT_NAME}::ncio ALIAS ncio)
set_target_properties(ncio PROPERTIES Fortran_MODULE_DIRECTORY "${module_dir}")
target_link_libraries(ncio PUBLIC NetCDF::NetCDF_Fortran)
target_include_directories(ncio PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
                                       $<INSTALL_INTERFACE:include>)
install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include DESTINATION ${CMAKE_INSTALL_PREFIX})
list(APPEND BASE_LIB_Targets ncio)

add_library(mpasio STATIC module_mpasio.f90)
add_library(${PROJECT_NAME}::mpasio ALIAS mpasio)
set_target_properties(mpasio PROPERTIES Fortran_MODULE_DIRECTORY "${module_dir}")
target_link_libraries(mpasio PUBLIC NetCDF::NetCDF_Fortran)
target_include_directories(mpasio PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
                                       $<INSTALL_INTERFACE:include>)
install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include DESTINATION ${CMAKE_INSTALL_PREFIX})
list(APPEND BASE_LIB_Targets mpasio)

add_library(map_proj_helper STATIC module_map_proj_helper.f90)
add_library(${PROJECT_NAME}::map_proj_helper ALIAS map_proj_helper)
set_target_properties(map_proj_helper PROPERTIES Fortran_MODULE_DIRECTORY "${module_dir}")
target_link_libraries(map_proj_helper PRIVATE ${PROJECT_NAME}::wps_map_utils)
target_include_directories(map_proj_helper PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/wps_map_utils.fd/include>
                                       $<INSTALL_INTERFACE:include>)
install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include DESTINATION ${CMAKE_INSTALL_PREFIX})
list(APPEND BASE_LIB_Targets map_proj_helper)

#add_library (map_util STATIC module_map_utils.f90)
#add_library(${PROJECT_NAME}::map_util ALIAS map_util)
#target_link_libraries(map_util PUBLIC gsi::gsi)
#set_target_properties(map_util PROPERTIES Fortran_MODULE_DIRECTORY "${module_dir}")
#target_include_directories(map_util PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
#                                           $<INSTALL_INTERFACE:include>)
#install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include DESTINATION ${CMAKE_INSTALL_PREFIX})
#list(APPEND BASE_LIB_Targets map_util)
#
#add_library (esggrid_util STATIC module_esggrid_util.f90)
#add_library(${PROJECT_NAME}::esggrid_util ALIAS esggrid_util)
#target_link_libraries( esggrid_util PUBLIC ${PROJECT_NAME}::pesglib)
#set_target_properties(esggrid_util PROPERTIES Fortran_MODULE_DIRECTORY "${module_dir}")
#target_include_directories(esggrid_util PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
#                                               $<INSTALL_INTERFACE:include>)
#install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include DESTINATION ${CMAKE_INSTALL_PREFIX})
#list(APPEND BASE_LIB_Targets esggrid_util)

install(
  TARGETS ${BASE_LIB_Targets}
  EXPORT ${PROJECT_NAME}Exports
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
