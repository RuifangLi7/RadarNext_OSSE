module module_mosaic_interp

contains

subroutine mosaic2grid(readref,nCell,maxlvl,lon_m,lat_m,ref3d)
!
!   PRGMMR: Ming Hu          ORG: GSL        DATE: 2022-01-20
!
! ABSTRACT: 
!     This routine interpolate NSSL reflectiivty mosaic fields to grid
!
! PROGRAM HISTORY LOG:
!
!   variable list
!
! USAGE:
!   INPUT FILES:  mosaic_files
!
!   OUTPUT FILES:
!
! REMARKS:
!
! ATTRIBUTES:
!   LANGUAGE: FORTRAN 90 + EXTENSIONS
!   MACHINE:  wJET
!
!$$$
!
!_____________________________________________________________________
!
  use module_kinds, only: r_kind,i_kind
  use module_read_NSSL_refmosaic, only: read_nsslref

  implicit none
!
  type(read_nsslref),intent(in) :: readref 
  integer,intent(in) :: nCell,maxlvl
  real,intent(in)    :: lon_m(nCell)    !
  real,intent(in)    :: lat_m(nCell)    !
  real,intent(inout) :: ref3d(nCell,maxlvl)   ! 3D reflectivity
!
!  For reflectiivty mosaic
!
  REAL   :: lonMin,latMin,lonMax,latMax
  REAL*8 :: dlon,dlat
!
!  ** misc
!      
  integer i,k,kk
  integer :: tversion

  REAL ::  rlat,rlon
  INTEGER  :: ip,jp,ipp1,jpp1
  REAL ::  rip,rjp
  REAL ::  dip,djp
  REAL ::  w1,w2,w3,w4
  REAL ::  ref1,ref2,ref3,ref4
  real, allocatable :: mscValue(:,:)

!**********************************************************************
!
!
  tversion=readref%tversion
  dlon=readref%dlon
  dlat=readref%dlat
  latMax=readref%latMax
  lonMax=readref%lonMax
  lonMin=readref%lonMin
  latMin=readref%latMin
!
  if(readref%if_fileexist) then
!
     allocate(mscValue(readref%mscNlon,readref%mscNlat))
     do k=1, readref%mscNlev
          if(tversion == 1) then
             kk=readref%ilevel
             mscValue(:,:) = readref%mscValue3d(:,:,1)
          else
             kk=k
             mscValue(:,:) = readref%mscValue3d(:,:,k)
          endif
!
          DO i=1,nCell
             rlat=lat_m(i)
             rlon=lon_m(i)

             if(tversion == 14 ) then
               rip=(rlon-lonMin)/dlon+1
               rjp=(rlat-latMin)/dlat+1
               ip=int(rip)
               jp=int(rjp)
               dip=rip-ip
               djp=rjp-jp
             elseif(tversion == 8 .or. tversion == 81) then
               rip=(rlon-lonMin)/dlon+1
               rjp=(latMax-rlat)/dlat+1
               ip=int(rip)
               jp=int(rjp)
               dip=rip-ip
               djp=rjp-jp 
             elseif(tversion == 4 ) then
               rip=(rlon-lonMin)/dlon+1
               rjp=(rlat-latMin)/dlat+1
               ip=int(rip)
               jp=int(rjp)
               dip=rip-ip
               djp=rjp-jp
             elseif(tversion == 1 ) then
               if(rlon<0.0) rlon=360.0+rlon
               rip=(rlon-lonMin)/dlon+1
               rjp=(latMax-rlat)/dlat+1
               ip=int(rip)
               jp=int(rjp)
               dip=rip-ip
               djp=rjp-jp
             else
               write(*,*) ' Unknown Mosaic format !!'
               stop 123
             endif
             if( ip >= 1 .and. ip <= readref%mscNlon ) then
             if( jp >= 1 .and. jp <= readref%mscNlat ) then
! inside mosaic domain
               ipp1=min(ip+1,readref%mscNlon)
               jpp1=min(jp+1,readref%mscNlat)
               w1=(1.0-dip)*(1.0-djp)
               w2=dip*(1.0-djp)
               w3=dip*djp
               w4=(1.0-dip)*djp
               ref1=mscValue(ip,jp)
               ref2=mscValue(ipp1,jp)
               ref3=mscValue(ipp1,jpp1)
               ref4=mscValue(ip,jpp1)
               if(ref1 > readref%rthresh_ref .and. ref2 > readref%rthresh_ref .and.  &
                  ref3 > readref%rthresh_ref .and. ref4 > readref%rthresh_ref ) then
                  ref3d(i,kk)=(ref1*w1+ref2*w2+ref3*w3+ref4*w4)/float(readref%var_scale)
               elseif(ref1 > readref%rthresh_miss .and. ref2 > readref%rthresh_miss .and.  &
                  ref3 > readref%rthresh_miss .and. ref4 > readref%rthresh_miss ) then
                  ref3d(i,kk)=-99.0   ! clear
               else
                  ref3d(i,kk)=-999.0  ! no observation
               endif
             endif
             endif
          ENDDO
      ENDDO  ! mscNlev

      deallocate(mscValue)
  else
     ref3d=-999.0
!     write(*,*) trim(readref%mosaicfile), '   does not exist!!!'
  endif

end subroutine mosaic2grid

end module module_mosaic_interp
