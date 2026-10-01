module module_write_nsslref

use module_constants, only: zero, one
use module_kinds, only: r_kind,i_kind

contains

  subroutine write_bufr_nsslref(maxlvl,nCell,numref,ref3d_column,idate)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    write_bufr_nsslref
!   prgmmr: hu           org: essl/gsd                date: 2008-12-01
!   
! abstract: write NSSL mosaic reflectivity in RR grid into bufr
!   
! program history log:
!   2008-12-01  kleist
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  linux 
!
!$$$
    implicit none

! Explicitly declare external functions and subroutines
    external :: openbf,openmb,datelen,ufbint,writsb,closbf

    integer :: nCell
    REAL(r_kind) :: ref3d_column(maxlvl+2,nCell)   ! 3D reflectivity in column
    real(r_kind) :: hdr(5),obs(1,35)
    character(80):: hdrstr='SID XOB YOB DHR TYP'
    character(80):: obsstr='HREF'

    REAL(i_kind),PARAMETER ::  MXBF = 160000_i_kind
    INTEGER(i_kind) :: ibfmsg = MXBF/4_i_kind

    character(8) subset,sid
    integer(i_kind) :: ludx,lendian_in,idate

    INTEGER(i_kind)  ::  maxlvl
    INTEGER(i_kind)  ::  numref
    INTEGER(i_kind)  ::  i,n,k,iret


!mhu    idate=2008120100
    subset='ADPUPA'
    sid='NSSLREF'
    ludx=22
    lendian_in=10

!
!  covert BUFR value of missing (-64) and no echo (-63) from cloud analysis
!  value of missing (-999.0) and no echo (-99.0)
!
    DO i=1,numref
    DO k=1,maxlvl
      if(ref3d_column(k+1,i) < -63.0 .and. ref3d_column(k+1,i) > -100.0 ) then
        ref3d_column(k+1,i)=-63.0_r_kind
      elseif(ref3d_column(k+1,i) < -100.0) then
        ref3d_column(k+1,i)=-64.0_r_kind
      endif
    ENDDO
    ENDDO

    open(ludx,file='prepobs_prep.bufrtable',action='read')
    open(lendian_in,file='NSSLRefInGSI.bufr',action='write',form='unformatted')

    call datelen(10)
    call openbf(lendian_in,'OUT',ludx)
    do n=1,numref
      hdr(1)=transfer(sid,hdr(1))
      hdr(2)=ref3d_column(1,n)/10.0_r_kind  ! XOB = cell index
      hdr(3)=0                              ! YOB = 0
      hdr(4)=0
      hdr(5)=500

      do k=1,maxlvl
        obs(1,k)=ref3d_column(1+k,n)
      enddo
      call openmb(lendian_in,subset,idate)
      call ufbint(lendian_in,hdr,5,   1,iret,hdrstr)
      call ufbint(lendian_in,obs,1,maxlvl,iret,obsstr)
      call writsb(lendian_in,ibfmsg,iret)
!      write(6,*) 'write_bufr_nsslref,1st: write BUFR message ibfmsg(1:',iret,') to local system'
    enddo
    call closbf(lendian_in)
    write(6,*) 'write_bufr_nsslref, DONE: write columns:',numref

end subroutine write_bufr_nsslref

subroutine write_netcdf_nsslref( FILE_NAME,nlvls,nCell,ref0,lon_m,lat_m,msclev )
  use netcdf
  implicit none

  character*256 FILE_NAME
  integer :: ncid

  integer, parameter             :: NDIMS=2
  character (len = *), parameter :: LVL_NAME = "height"
  character (len = *), parameter :: CELL_NAME = "cell"
  character (len = *), parameter :: LAT_NAME = "latitude"
  character (len = *), parameter :: LON_NAME = "longitude"
  integer :: lvl_dimid, cell_dimid
  integer :: NLVLS, NCELL

  real, dimension(NCELL) :: lon_m
  real, dimension(NCELL) :: lat_m
  real, dimension(NCELL, NLVLS) :: ref0
  real, dimension(NLVLS) :: msclev

  integer :: lon_varid, lat_varid, dimids(NDIMS)
  integer :: ref_varid, lvl_varid

  character (len = *), parameter :: UNITS = "units"
  character (len = *), parameter :: REF_UNITS = "dBZ"
  character (len = *), parameter :: LAT_UNITS = "degrees_north"
  character (len = *), parameter :: LON_UNITS = "degrees_east"
  character (len = *), parameter :: LVL_UNITS = "meter"

  character (len = *), parameter :: REF_NAME="reflectivity"
  
  print*,"Start to write out"
  write(*,*) 'max min',maxval(ref0),minval(ref0)

  ! Create the file. 
  call check( nf90_create(FILE_NAME, nf90_clobber, ncid) )

  ! Define the dimensions. 
  call check( nf90_def_dim(ncid, LVL_NAME, NLVLS, lvl_dimid) )
  call check( nf90_def_dim(ncid, CELL_NAME, NCELL, cell_dimid) )

  ! Define the coordinate variables.
  call check( nf90_def_var(ncid, LAT_NAME, NF90_REAL, cell_dimid, lat_varid) )
  call check( nf90_def_var(ncid, LON_NAME, NF90_REAL, cell_dimid, lon_varid) )
  call check( nf90_def_var(ncid, LVL_NAME, NF90_REAL, lvl_dimid, lvl_varid) )

  ! Assign units attributes to coordinate variables.
  call check( nf90_put_att(ncid, lat_varid, UNITS, LAT_UNITS) )
  call check( nf90_put_att(ncid, lon_varid, UNITS, LON_UNITS) )
  call check( nf90_put_att(ncid, lvl_varid, UNITS, LVL_UNITS) )

  dimids = (/ cell_dimid, lvl_dimid /)
  
  ! Define the netCDF variables for the reflectivity data.
  call check( nf90_def_var(ncid, REF_NAME, NF90_REAL, dimids, ref_varid) )

  ! Assign units attributes to the netCDF variables.
  call check( nf90_put_att(ncid, ref_varid, UNITS, REF_UNITS) )

  ! End define mode.
  call check( nf90_enddef(ncid) )

  ! Write the coordinate variable data. This will put the latitudes
  ! and longitudes of our data grid into the netCDF file.
  call check( nf90_put_var(ncid, lat_varid, lat_m) )
  call check( nf90_put_var(ncid, lon_varid, lon_m) )
  call check( nf90_put_var(ncid, lvl_varid, msclev) )

  ! Write the data.
  call check( nf90_put_var(ncid, ref_varid, ref0))

  ! Close the file.
  call check( nf90_close(ncid) )
   
  ! If we got this far, everything worked as expected. Yipee! 
  print *,"*** SUCCESS writing file "//trim(FILE_NAME)//"!"

contains
  subroutine check(status)
    integer, intent ( in) :: status
    
    if(status /= nf90_noerr) then 
      print *, trim(nf90_strerror(status))
      stop "Stopped"
    end if
  end subroutine check

end subroutine write_netcdf_nsslref

end module module_write_nsslref
