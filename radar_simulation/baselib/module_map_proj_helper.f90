module module_map_proj_helper

  use module_wps_map_utils
  use module_wps_misc_definitions

  implicit none
  public :: init_proj,write_corners 
  private

  contains

    subroutine init_proj(proj, name)
!---------------------------------------------------------------------------------------------------
!
! Initiate a proj_info derived type using a map projection name
!
! Inputs
!   this : proj_info
!     Map projection derived type
!   name : string 
!     Name of map projection
!
!
! shawn.s.murdzek@noaa.gov
!---------------------------------------------------------------------------------------------------

      implicit none

      type(proj_info), intent(out)  :: proj
      character(len=25), intent(in) :: name

      integer :: nlat, nlon
      real :: lat1, lon1, truelat1, truelat2, stdlon, dx, knowni, knownj

      if (trim(name) == 'CONUS') then
        ! Similar to HRRR Lambert Conformal projection, but slightly larger
        ! Should be large enough for MPAS 12-km and 3-km CONUS domains
        lat1 = 38.5
        lon1 = -97.5
        truelat1 = 38.5
        truelat2 = 38.5
        stdlon = -97.5
        dx = 3000.
        nlat = 1250
        nlon = 2000
        knowni = 0.5 * nlon - 1.
        knownj = 0.5 * nlat - 1.
        call map_set(PROJ_LC, &
                     proj, &
                     lat1=lat1, &
                     lon1=lon1, &
                     truelat1=truelat1, &
                     truelat2=truelat2, &
                     stdlon=stdlon, &
                     dx=dx, &
                     knowni=knowni, &
                     knownj=knownj, &
                     nlat=nlat, &
                     nlon=nlon)

      else
        write(*,*) 'ERROR: Map projection option is not recognized'
        write(*,*) 'Option =', trim(name)
        stop

      endif

    end subroutine init_proj

    subroutine write_corners(proj)
!---------------------------------------------------------------------------------------------------
!
! Write out corners of map projection
!
! Inputs
!   proj : proj_info
!     Map projection derived type
!
!
! shawn.s.murdzek@noaa.gov
!---------------------------------------------------------------------------------------------------

      implicit none

      type(proj_info), intent(in) :: proj

      real :: ll_lat, ur_lat, left_lat, bot_lat, right_lat, top_lat
      real :: ll_lon, ur_lon, left_lon, bot_lon, right_lon, top_lon

      call ij_to_latlon(proj, 0., 0., ll_lat, ll_lon)
      call ij_to_latlon(proj, real(proj%nlon), real(proj%nlat), ur_lat, ur_lon)
      call ij_to_latlon(proj, 0., real(proj%knowni), left_lat, left_lon)
      call ij_to_latlon(proj, real(proj%knownj), 0., bot_lat, bot_lon)
      call ij_to_latlon(proj, real(proj%nlon), real(proj%knowni), right_lat, right_lon)
      call ij_to_latlon(proj, real(proj%knownj), real(proj%nlat), top_lat, top_lon)

      write(*,*)
      write(*,*) 'map projection:'
      write(*,*) 'llcrnr    =', ll_lat, ll_lon
      write(*,*) 'urcrnr    =', ur_lat, ur_lon
      write(*,*) 'left ctr  =', left_lat, left_lon
      write(*,*) 'bot ctr   =', bot_lat, bot_lon
      write(*,*) 'right ctr =', right_lat, right_lon
      write(*,*) 'top ctr   =', top_lat, top_lon

    end subroutine write_corners

end module module_map_proj_helper
