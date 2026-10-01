program process_NSSL_mosaic
!
!   PRGMMR: Ming Hu          ORG: GSD        DATE: 2007-12-17
!           Ruifang Li       ORG: GSL        DATE: 2026-09-30        
!
! ABSTRACT: 
!     This routine read in NR reflectiivty mosaic fields and 
!     interpolate them into MRMS grids.
!
!     tversion=8  : NSSL 8 tiles netcdf
!     tversion=81 : NCEP 8 tiles binary
!     tversion=4  : NSSL 4 tiles binary
!     tversion=1  : NSSL 1 tile grib2
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
  use mpi
  use module_kinds, only: r_kind,i_kind
  use module_read_NSSL_refmosaic, only: read_nsslref
  use module_mpasio, only: read_MPAS_dim,read_MPAS_lat_lon,read_MPAS_1D_int
  use module_write_nsslref, only: write_bufr_nsslref,write_netcdf_nsslref
  use module_mosaic_interp, only: mosaic2grid
  use module_read_grib2, only: clear_air,missing,read_grib2_head,read_grib2_sngle,read_grib2_allsngle
  use grib_mod
  use netcdf

  implicit none

  type(read_nsslref) :: readref 
  type(gribfield) :: gfld

! MPI variables
  integer :: npe, mype, mypeLocal,ierror

!  namelist files
  integer      ::  tversion
  character*12 :: analysis_time
  CHARACTER*180   dataPath
  namelist/setup/ tversion,analysis_time,dataPath


  integer, parameter :: maxMosaiclvl=33
  integer :: levelheight(maxMosaiclvl)
  data levelheight /500, 750, 1000, 1250, 1500, 1750, 2000, 2250, 2500,         &
                    2750, 3000, 3500, 4000, 4500, 5000, 5500, 6000, 6500, 7000, &
                    7500, 8000, 8500, 9000, 10000, 11000, 12000, 13000, 14000,  &
                    15000, 16000, 17000, 18000, 19000/

  integer  :: nx,ny,nz,ntot,height,var_scale,nr_lvl,clear_lvl,lvl_start
  integer  :: yr, mo, da, hr, mn, sc
  integer i,ii,j,jj,k,lugb,iret,scale_factor,true_min,second_min
  integer :: maxcores,imiss,iclear,igood
  integer ::   mscNlon   ! number of longitude of mosaic data
  integer ::   mscNlat   ! number of latitude of mosaic data
  integer ::   mscNlev   ! number of vertical levels of mosaic data
  INTEGER(i_kind)  ::  maxlvl,numlvl,numref,idate,iyear,imon,iday,ihour,iminute
  integer, target :: idsect(13),ipdtmpl(15),igdtmpl(19),idrtmpl(5)
  integer:: ndimensions,nvariables,nattributes,unlimiteddimid,len,status,ncid,varid
  integer,allocatable,dimension(:):: dims

  byte, allocatable  :: r_mask(:,:,:), r_mask2(:,:)
  byte :: one=1

  real(8),parameter:: R = 6371000 ! meter
  real*8 :: rdx,rdy,dlon,dlat
  real, allocatable :: msclon(:)        ! longitude of mosaic data
  real, allocatable :: msclat(:)        ! latitude of mosaic data
  real, allocatable :: msclev(:)        ! level of mosaic data
  real, allocatable :: mscValue(:,:),mscGeomHgtValue(:,:,:),mscRefdValue(:,:,:),simulRefdValue(:,:,:)
  real  :: rlatmax,rlonmin,lonMin,latMin,lonMax,latMax,good_pct
  real  :: true_max,low_hgt,high_hgt,low_refd,high_refd,min_refd,max_refd,wgt,mrms_hgt
  real, allocatable, target :: fld(:)

  character*4    :: year
  character*2    :: mon,day,hour,minute
  character*5    :: hgt_str(maxMosaiclvl)
  character*10   :: ncfile
  character*20   :: name
  character*256  :: nr_file, nr_refd,nr_hgt,mosaic_file


!**********************************************************************
!
!            END OF DECLARATIONS....start of program

! MPI setup
  !call MPI_INIT(ierror) 
  !call MPI_COMM_SIZE(mpi_comm_world,npe,ierror)
  !call MPI_COMM_RANK(mpi_comm_world,mype,ierror)
  mype=0
  if(mype==0) write(6,*) 'total cores for this run is ',npe
  print *
  !if(npe < maxcores) then
  !   write(6,*) 'ERROR, this run must use ',maxcores,' or more cores !!!'
  !   call MPI_FINALIZE(ierror)
  !   stop 1234
  !endif

  scale_factor=1.0e6

  datapath="./"
  open(15, file='namelist.file')
    read(15,setup)
  close(15)

  if(mype==0) then
    write(6,*)
    write(6,*) 'tversion = ', tversion
    write(6,*) 'analysis_time = ', analysis_time
    write(6,*) 'dataPath = ', dataPath
    write(6,*)
  endif

  year=analysis_time(1:4)
  mon=analysis_time(5:6)
  day=analysis_time(7:8)
  hour=analysis_time(9:10)
  minute=analysis_time(11:12)

  write(*,'(5a4)'), year,mon,day,hour,minute

  read(analysis_time,'(I10)') idate
  read(year,'(I4)') iyear
  read(mon,*) imon
  read(day,*) iday
  read(hour,*) ihour
  read(minute,*) iminute
  if(mype==0) write(6,'(a,i12,i6,4i4)') 'cycle time is :', idate, iyear, imon, iday, ihour, iminute


  if( tversion == 8 .or. tversion == 14) then
     maxcores=8
  elseif( tversion == 81 ) then
     maxcores=8
  elseif( tversion == 4 ) then
     maxcores=4
  elseif( tversion == 1 ) then
     maxcores=1
  else
     write(*,*) 'unknow tversion !'
     stop 1234
  endif

  nr_refd='nr_refd'
  nr_hgt='nr_hgt'
  print *
  write(*,*) 'Read reflectivity header info'
  call read_grib2_head(nr_refd,nx,ny,nz,rlonmin,rlatmax,rdx,rdy)
  var_scale=1
  mscNlon=nx
  mscNlat=ny
  mscNlev=nz
  dlon=rdx
  dlat=rdy
  lonMin=rlonmin
  lonMax=lonMin+dlon*(mscNlon-1)
  latMax=rlatmax
  latMin=latMax-dlat*(mscNlat-1)
  write(*,*) 'mscNlon,mscNlat,mscNlev'
  write(*,*) mscNlon,mscNlat,mscNlev
  write(*,*) 'dlon,dlat,lonMin,lonMax,latMax,latMin'
  write(*,*) dlon,dlat,lonMin,lonMax,latMax,latMin
  print *

  nr_lvl=100
  clear_lvl=0
  ntot = nx*ny*nz
  allocate(mscValue(mscNlon,mscNlat))
  allocate(mscGeomHgtValue(mscNlon,mscNlat,nr_lvl))   ! geometric height
  allocate(mscRefdValue(mscNlon,mscNlat,nr_lvl))
  allocate(simulRefdValue(mscNlon,mscNlat,maxMosaiclvl)) 
  allocate(r_mask(mscNlon,mscNlat,maxMosaiclvl))      ! radar mask
  allocate(r_mask2(mscNlon,mscNlat))

  print *
  write(*,*) 'Read reflectivity and height from NR'
  call read_grib2_allsngle(nr_hgt,ntot,nr_lvl,clear_lvl,height,mscGeomHgtValue)
  print *
  call read_grib2_allsngle(nr_refd,ntot,nr_lvl,clear_lvl,height,mscRefdValue)

  if(nr_lvl /= height) then
     write(6,*) 'ERROR, NR level is not right ', nr_lvl, height
     stop 777
  endif

! refd: set up the missing value on the clear air levels for those out of NR domain
! refd=0 on clear air levles when returned from read_grib2_allsngle 
  print *
  write(*,*) 'Set reflectivity on clear air levels but out of NR domain to missing'
  do k=1,nr_lvl
    min_refd=minval(mscRefdValue(:,:,k))
    max_refd=maxval(mscRefdValue(:,:,k))
    if (min_refd .eq. max_refd .and. min_refd > -0.00001 .and. min_refd < 0.00001) then
      write(*,'(a,i4,f10.2)') 'Refractivity clear air level, min/max: ',k, min_refd
      do j=1,mscNlat
        do i=1,mscNlon
          if (mscRefdValue(i,j,1) > -1000 .and. mscRefdValue(i,j,1)< -998 ) then
            mscRefdValue(i,j,k)=missing
          endif
        enddo
      enddo
    endif  
  enddo


! vertical interpolation refd from NR levels to MRMS columns
  print *
  write(*,*) 'Vertical interpolation reflectivity from NR levels to MRMS 33 levels'
  simulRefdValue=missing
  do j=1,mscNlat
    do i=1,mscNlon
      do ii=1,maxMosaiclvl
        mrms_hgt=levelheight(ii)
        do k=1,nr_lvl
          low_hgt=mscGeomHgtValue(i,j,k)
          high_hgt=mscGeomHgtValue(i,j,k+1)     
          low_refd=mscRefdValue(i,j,k)
          high_refd=mscRefdValue(i,j,k+1)
          if (mrms_hgt > low_hgt .and. mrms_hgt < high_hgt  .and. low_refd > missing .and. high_refd > missing) then
             wgt=(mrms_hgt-low_hgt)/(high_hgt-low_hgt)
             simulRefdValue(i,j,ii)=wgt*high_refd+(1-wgt)*low_refd
             !write(*,'(a,2i8,6F15.4)') 'lat, lon, mrms_hgt, low_hgt, high_hgt, low_refd, high_refd, simul_refd ',& 
             !        j, i, mrms_hgt,low_hgt,high_hgt, low_refd, high_refd,simulRefdValue(i,j,ii)
          endif   
        enddo  
      enddo ! maxMosaiclvl
    enddo
  enddo


! Read radar mask and apply to simulated obs  
  print *
  write(*,*) "Read radar mask and apply to simulated obs"
  ncfile="radar_mask"
  status = nf90_open(ncfile, nf90_nowrite, ncid)
  if(status /= nf90_noerr) write(*,*) 'Error to open file', status

  iret=nf90_inquire(ncid,ndimensions,nvariables,nattributes,unlimiteddimid)
  write(*,'(a60,4i5)') 'ndimensions,nvariables,nattributes,unlimiteddimid ',ndimensions,nvariables,nattributes,unlimiteddimid
  allocate(dims(ndimensions))
  do k=1,ndimensions
    iret=nf90_inquire_dimension(ncid,k,name,len)   ! name: time, height,height_lo, height_hi
    dims(k)=len
    !write(*,*) 'dims ', name, dims(k)
  enddo

  status = nf90_inq_varid(ncid, "mask", varid)
  if(status /= nf90_noerr) write(*,*) 'Error to get mask',status

  status = nf90_get_var(ncid, varid, r_mask, start = (/1,1,1/),count =(/mscNlon,mscNlat,maxMosaiclvl/))
  do k=1,maxMosaiclvl
    do j=1,mscNlat
      r_mask2(:, mscNlat-j+1)=r_mask(:,j,k) ! reverse south and north
    enddo
    r_mask(:,:,k)=r_mask2(:,:)
    true_min = minval(r_mask(:,:,k))
    second_min = minval(r_mask(:,:,k), mask = (r_mask(:,:,k) > true_min))
    write(*,'(a,4i4)') 'Hgt_mask: ',k,  true_min, second_min, maxval(r_mask(:,:,k))
  enddo

  do k=1,maxMosaiclvl
    do j=1,mscNlat
      do i=1,mscNlon
        if (r_mask(i,j,k) /= one ) then
            simulRefdValue(i,j,k)=missing
        endif
      enddo
    enddo
  enddo


! gfld info: https://github.com/NOAA-EMC/NCEPLIBS-g2/blob/develop/src/gribmod.F90.in
! putgb2: https://github.com/NOAA-EMC/NCEPLIBS-g2/blob/develop/src/g2gf.F90
! call putgb2 subroutine to write simulated refd to MRMS reflectivity grib2 format
! read MRMS reflectivity obs as below, write same info to simulated obs

  print *
  write(*,*) 'Write simulated refd to MRMS reflectivity grib2 format'
  print *
  gfld%griddef=0
  gfld%igdtnum=0
  gfld%interp_opt=0
  gfld%num_coord=0
  gfld%num_opt=0
  gfld%numoct_opt=0
  gfld%ipdtnum=0
  gfld%locallen=0
!  gfld%bmap=   
!  gfld%local    

  gfld%ibmap=255
  gfld%discipline=209
  gfld%idrtlen=5
  gfld%igdtlen=19
  gfld%idrtnum=41
  gfld%version=2
  gfld%ipdtlen=15
  gfld%ngrdpts=ntot ! 24500000


  ! idsect, ipdtmpl, igdtmpl, idrtmpl default=0 if not specified.   

  ! Contains the entries in the Identification Section
  idsect(1)=161
  !idsect(2)=0
  idsect(3)=255
  idsect(4)=1
  idsect(5)=3
  idsect(6)=iyear
  idsect(7)=imon
  idsect(8)=iday
  idsect(9)=ihour
  idsect(10)=iminute
  !idsect(11)=0
  idsect(12)=2
  idsect(13)=7
  gfld%idsect=>idsect
  !write(*,*) 'idsect: ',gfld%idsect


  ! Contains the data values for the Product Definition Template
  !gfld%ipdtlen=15 lenght of ipdtmpl

  ipdtmpl(1)=9
  !ipdtmpl(2)=0
  ipdtmpl(3)=8
  !ipdtmpl(4)=0
  ipdtmpl(5)=97
  !ipdtmpl(6)=0
  !ipdtmpl(7)=0
  !ipdtmpl(8)=0
  !ipdtmpl(9)=0
  ipdtmpl(10)=102
  !ipdtmpl(11)=0
  !ipdtmpl(12)=    ! height, meter
  ipdtmpl(13)=255
  ipdtmpl(14)=1
  !ipdtmpl(15)=0
  gfld%ipdtmpl=>ipdtmpl
  !write(*,*) 'ipdtmpl: ',gfld%ipdtmpl


  ! Contains the data values for the Grid Definition Template
  !gfld%igdtlen=19  ! length of igdtmpl
  igdtmpl(1)=2
  igdtmpl(2)=1
  igdtmpl(3)=6367470
  igdtmpl(4)=1
  igdtmpl(5)=6378160
  igdtmpl(6)=1
  igdtmpl(7)=6356775
  igdtmpl(8)=nx ! 7000
  igdtmpl(9)=ny ! 3500 
  igdtmpl(10)=1
  igdtmpl(11)=1000000
  igdtmpl(12)=latMax*scale_factor ! lat 54995000
  igdtmpl(13)=lonMin*scale_factor ! lon 230005000
  igdtmpl(14)=48
  igdtmpl(15)=20005000
  igdtmpl(16)=299995000
  igdtmpl(17)=10000   ! dlon
  igdtmpl(18)=10000   ! dlat
  !igdtmpl(19)=0
  gfld%igdtmpl=>igdtmpl
  !write(*,*) 'igdtmpl: ',gfld%igdtmpl

  ! Contains the data values for the Data Representation Template
  !gfld%idrtlen=5 ! length of idrtmpl
  !idrtmpl(1)=-971237376   ! from MRMS reflectivity 
  idrtmpl(2)=0
  idrtmpl(3)=1
  idrtmpl(4)=16
  idrtmpl(5)=0
  gfld%idrtmpl=>idrtmpl
  !write(*,*) 'idrtmpl: ',gfld%idrtmpl

  allocate(fld(ntot))
  gfld%fld=>fld
  hgt_str=[character(len=5) :: "00.50", "00.75", "01.00", "01.25", "01.50", "01.75", &
                                  "02.00", "02.25", "02.50", "02.75", "03.00", "03.50", &
                                  "04.00", "04.50", "05.00", "05.50", "06.00", "06.50", &
                                  "07.00", "07.50", "08.00", "08.50", "09.00", "10.00", &
                                  "11.00", "12.00", "13.00", "14.00", "15.00", "16.00", &
                                  "17.00", "18.00", "19.00"]
  do k=1,maxMosaiclvl
    gfld%ipdtmpl(12)=levelheight(k)
    fld=reshape(simulRefdValue(:,:,k),[ntot])
    lugb=k
    mosaic_file="MergedReflectivityQC_"//hgt_str(k)//"_"//year//mon//day//"-"//hour//minute//"00."//"grib2"
    call baopenw(lugb,trim(mosaic_file),iret)
    call putgb2(lugb, gfld, iret)
    call baclose(lugb,iret)
  enddo

end program process_NSSL_mosaic
