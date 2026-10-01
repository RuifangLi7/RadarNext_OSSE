module module_read_grib2

use grib_mod

real, parameter:: clear_air=-99.0,missing=-999.0

contains

subroutine read_grib2_head(filename,nx,ny,nz,rlonmin,rlatmax,rdx,rdy)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    read_grib2  read grib2 file head information
!   prgmmr: Ming Hu          org: GSD                 date: 2015-05-20
!
! abstract: read grib2 file head
!
!
! program history log:
!   2015-05-20  Hu, initial documentation
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  Zeus
!
!$$$ end documentation block

!  use gridmod, only: idsl5,regional

  implicit none
  
! Explicitly declare external functions and subroutines
  external :: baopenr,skgb,baread,gb_info,gf_getfld,gf_free,baclose

  character*256,intent(in)  :: filename
  integer, intent(out)      :: nx,ny,nz
  real,    intent(out)      :: rlonmin,rlatmax
  real*8,  intent(out)      :: rdx,rdy
!
!
  type(gribfield) :: gfld
  logical :: expand=.true.
  integer :: ifile
  character(len=1),allocatable,dimension(:) :: cgrib
  integer,parameter :: msk1=32000
  integer :: lskip, lgrib,iseek
  integer :: currlen
  integer :: icount , lengrib
  integer :: listsec0(3)
  integer :: listsec1(13)
  integer year, month, day, hour, minute, second

  integer :: numfields,numlocal,maxlocal,ierr
  integer :: grib_edition
  integer :: itot
!  real    :: dx,dy,lat1,lon1
  real    :: scale_factor
!
!
  integer :: nn,n,iret
!
!
  scale_factor=1.0e6
  ifile=10
  loopfile: do nn=1,1
!     write(6,*) 'read in grib2 file head', trim(filename)
  
     lskip=0
     lgrib=0
     iseek=0
     icount=0
     itot=0
     currlen=0
! Open GRIB2 file 
     call baopenr(ifile,trim(filename),iret)

     if (iret.eq.0) then
        VERSION: do

         ! Search opend file for the next GRIB2 messege (record).
           call skgb(ifile,iseek,msk1,lskip,lgrib)

         ! Check for EOF, or problem
           if (lgrib.eq.0) then
              exit
           endif

         ! Check size, if needed allocate more memory.
           if (lgrib.gt.currlen) then
              if (allocated(cgrib)) deallocate(cgrib)
              allocate(cgrib(lgrib))
              currlen=lgrib
           endif

         ! Read a given number of bytes from unblocked file.
           call baread(ifile,lskip,lgrib,lengrib,cgrib)

           if(lgrib.ne.lengrib) then
              write(*,*) 'ERROR, read_grib2 lgrib ne lengrib', &
                    lgrib,lengrib
              stop 1234
           endif

           iseek=lskip+lgrib
           icount=icount+1

         ! Unpack GRIB2 field
           call gb_info(cgrib,lengrib,listsec0,listsec1, &
                     numfields,numlocal,maxlocal,ierr)
           if(ierr.ne.0) then
              write(6,*) 'Error querying GRIB2 message',ierr
              stop
           endif
           itot=itot+numfields

           grib_edition=listsec0(2)
           if (grib_edition.ne.2) then
              exit VERSION
           endif
!           write(*,*) 'listsec0=',listsec0
!           write(*,*) 'listsec1=',listsec1
!           write(*,*) 'numfields=',numfields

! get information form grib2 file
           n=1
           call gf_getfld(cgrib,lengrib,n,.FALSE.,expand,gfld,ierr)
           year  =gfld%idsect(6)     !(FOUR-DIGIT) YEAR OF THE DATA
           month =gfld%idsect(7)     ! MONTH OF THE DATA
           day   =gfld%idsect(8)     ! DAY OF THE DATA
           hour  =gfld%idsect(9)     ! HOUR OF THE DATA
           minute=gfld%idsect(10)    ! MINUTE OF THE DATA
           second=gfld%idsect(11)    ! SECOND OF THE DATA
!           write(*,*) 'year,month,day,hour,minute,second='
!           write(*,*) year,month,day,hour,minute,second
           
!           write(*,*) 'source center =',gfld%idsect(1)
!           write(*,*) 'Indicator of model =',gfld%ipdtmpl(5)
!           write(*,*) 'observation level (m)=',gfld%ipdtmpl(12)
!           write(*,*) 'map projection=',gfld%igdtnum
           if (gfld%igdtnum.eq.0) then ! Lat/Lon grid aka Cylindrical
                                       ! Equidistant
              nx = gfld%igdtmpl(8)
              ny = gfld%igdtmpl(9)
              nz = 1
              rdx = gfld%igdtmpl(17)/scale_factor
              rdy = gfld%igdtmpl(18)/scale_factor
              rlatmax = gfld%igdtmpl(12)/scale_factor
              rlonmin = gfld%igdtmpl(13)/scale_factor 
!              write(*,*) 'nx,ny=',nx,ny
!              write(*,*) 'dx,dy=',rdx,rdy
!              write(*,*) 'lat1,lon1=',rlatmax,rlonmin
           else
               write(*,*) 'unknown projection'
               stop 1235
           endif

           call gf_free(gfld)

        enddo VERSION ! skgb
     endif

     CALL BACLOSE(ifile,ierr)
     nullify(gfld%local)
     if (allocated(cgrib)) deallocate(cgrib)
  enddo loopfile
  return
end subroutine read_grib2_head

subroutine read_grib2_sngle(filename,ntot,height,var)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    read_grib2  read grib2 file
!   prgmmr: Ming Hu          org: GSD                 date: 2015-05-20
!
! abstract: read grib2 file
!
!
! program history log:
!   2015-05-20  parrish, initial documentation
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  Zeu
!
!$$$ end documentation block

!  use gridmod, only: idsl5,regional

  implicit none

! Explicitly declare external functions and subroutines
  external :: baopenr,skgb,baread,gb_info,gf_getfld,gf_free,baclose

  character*256,intent(in)  :: filename
  integer, intent(in)       :: ntot
  real, intent(out) :: var(ntot)
  integer, intent(out) :: height
!
!
  type(gribfield) :: gfld
  logical :: expand=.true.
  integer :: ifile
  character(len=1),allocatable,dimension(:) :: cgrib
  integer,parameter :: msk1=32000
  integer :: lskip, lgrib,iseek
  integer :: currlen
  integer :: icount , lengrib
  integer :: listsec0(3)
  integer :: listsec1(13)
  integer year, month, day, hour, minute, second

  integer :: numfields,numlocal,maxlocal,ierr
  integer :: grib_edition
  integer :: itot
  integer :: nx,ny
  real    :: dx,dy,lat1,lon1
  real    :: scale_factor, true_min,second_min,third_min,true_max
!
!
  integer :: nn,n,j,iret,ii,jj,kk,mm,itotal
!
!
  scale_factor=1.0e6
  ifile=12
  loopfile: do nn=1,1
     write(6,*) 'read mosaic in grib2 file ', trim(filename)
  
     lskip=0
     lgrib=0
     iseek=0
     icount=0
     itot=0
     currlen=0
! Open GRIB2 file 
     call baopenr(ifile,trim(filename),iret)
     if (iret.eq.0) then
        VERSION: do

         ! Search opend file for the next GRIB2 messege (record).
           call skgb(ifile,iseek,msk1,lskip,lgrib)

         ! Check for EOF, or problem
           if (lgrib.eq.0) then
              exit
           endif

         ! Check size, if needed allocate more memory.
           if (lgrib.gt.currlen) then
              if (allocated(cgrib)) deallocate(cgrib)
              allocate(cgrib(lgrib))
              currlen=lgrib
           endif

         ! Read a given number of bytes from unblocked file.
           call baread(ifile,lskip,lgrib,lengrib,cgrib)

           if(lgrib.ne.lengrib) then
              write(*,*) 'ERROR, read_grib2 lgrib ne lengrib', &
                    lgrib,lengrib
              stop 1234
           endif

           iseek=lskip+lgrib
           icount=icount+1
           !write(*,*) 'iseek,icount ',iseek, icount

         ! Unpack GRIB2 field
           call gb_info(cgrib,lengrib,listsec0,listsec1, &
                     numfields,numlocal,maxlocal,ierr)
           if(ierr.ne.0) then
              write(6,*) 'Error querying GRIB2 message',ierr
              stop
           endif
           itot=itot+numfields

           grib_edition=listsec0(2)
           if (grib_edition.ne.2) then
              exit VERSION
           endif
           write(*,*) 'listsec0=',listsec0
           write(*,*) 'listsec1=',listsec1
           write(*,*) 'numfields=',numfields,lengrib

! get information form grib2 file
           n=1
           call gf_getfld(cgrib,lengrib,n,.FALSE.,expand,gfld,ierr)

           year  =gfld%idsect(6)     !(FOUR-DIGIT) YEAR OF THE DATA
           month =gfld%idsect(7)     ! MONTH OF THE DATA
           day   =gfld%idsect(8)     ! DAY OF THE DATA
           hour  =gfld%idsect(9)     ! HOUR OF THE DATA
           minute=gfld%idsect(10)    ! MINUTE OF THE DATA
           second=gfld%idsect(11)    ! SECOND OF THE DATA
           !write(*,*) 'year,month,day,hour,minute,second=',year,month,day,hour,minute,second
           
           !write(*,*) 'source center =',gfld%idsect(1)
           !write(*,*) 'Indicator of model =',gfld%ipdtmpl(5)
           !write(*,*) 'observation level (m)=',gfld%ipdtmpl(12)
           !write(*,*) 'map projection=',gfld%igdtnum
           height=gfld%ipdtmpl(12)
           if (gfld%igdtnum.eq.0) then ! Lat/Lon grid aka Cylindrical
                                       ! Equidistant
              nx = gfld%igdtmpl(8)
              ny = gfld%igdtmpl(9)
              dx = gfld%igdtmpl(17)/scale_factor
              dy = gfld%igdtmpl(18)/scale_factor
              lat1 = gfld%igdtmpl(12)/scale_factor
              lon1 = gfld%igdtmpl(13)/scale_factor 
              !write(*,*) 'nx,ny=',nx,ny
              !write(*,*) 'dx,dy=',dx,dy
              !write(*,*) 'lat1,lon1=',lat1,lon1
           else
               write(*,*) 'unknown projection'
               stop 1235
           endif


          write(*,'(a,i4)') 'discipline ', gfld%discipline
          write(*,'(a,i4)') 'griddef ', gfld%griddef
          write(*,'(a,i4)') 'ibmap '  , gfld%ibmap

          write(*,'(a,5i4)') &
          '     idrtlen,      igdtnum,      igdtlen,      interp_opt,      idrtnum ',&
           gfld%idrtlen, gfld%igdtnum, gfld%igdtlen, gfld%interp_opt, gfld%idrtnum

          write(*,'(a,4i4)') &
          '    num_coord,      num_opt,      numoct_opt,      version ',&
          gfld%num_coord, gfld%num_opt, gfld%numoct_opt, gfld%version

          write(*,'(a,4i10)') &
          '     ipdtlen,      ipdtnum,      locallen,      ngrdpts ', & 
           gfld%ipdtlen, gfld%ipdtnum, gfld%locallen, gfld%ngrdpts

          write(*,*) 'bmap ', gfld%bmap
          write(*,*) 'idrtmpl ', gfld%idrtmpl
          write(*,*) 'idsect used ', gfld%idsect
          write(*,*) 'igdtmpl used ',gfld%igdtmpl
          write(*,*) 'ipdtmpl used ',gfld%ipdtmpl
          write(*,*) 'local ',gfld%local


           call gf_free(gfld)
         ! Continue to unpack GRIB2 field.
           NUM_FIELDS: do n = 1, numfields
           ! e.g. U and V would =2, otherwise its usually =1
             call gf_getfld(cgrib,lengrib,n,.true.,expand,gfld,ierr)
             if (ierr.ne.0) then
               write(*,*) ' ERROR extracting field gf_getfld = ',ierr
               cycle
             endif

             write(*,*) 'gfld%ndpts=',n,gfld%ndpts
             !write(*,*) 'gfld%unpacked=',n,gfld%unpacked

!             fldmax=gfld%fld(1)
!             fldmin=gfld%fld(1)
!             sum=gfld%fld(1)
             if(ntot .ne. gfld%ndpts) then
                write(*,*) 'Error, wrong dimension ',ntot, gfld%ndpts
                if (gfld%ndpts .eq. 17280557) then  ! ntotal for max/min=0 levels
                  var=-99.0
                  cycle
                else  
                 stop 1234
                endif 
             endif

             ii=0; jj=0; kk=0; mm=0
             do j=1,gfld%ndpts
               var(j)=gfld%fld(j)
               if (var(j) < 200 .and. (var(j)> -10)) then
                  ii=ii+1     
               elseif  (var(j) < -98 .and. (var(j)> -100)) then  
                  jj=jj+1
               elseif  (var(j) < -998 .and. (var(j)> -1000)) then     
                  kk=kk+1
               else
                  mm=mm+1 
                  write(*,*) 'others ',var(j)    
               !   var(j)=-999.0     
                  !write(*,*) j,var(j)
               endif        
             enddo
             itotal=ii+jj+kk+mm
             true_min = minval(var(:))
             second_min = minval(var(:), mask = (var(:) > true_min))
             third_min = minval(var(:), mask = (var(:) > second_min))
             write(*,'(a,i8,5i10,4F25.2)') 'single: level,num_good,num_-99,num_-999,num_other,max,mins1-3' , &
                     height,ii,jj,kk,mm,itotal,maxval(var),minval(var),second_min,third_min

             call gf_free(gfld)
           enddo NUM_FIELDS
        !return
        enddo VERSION ! skgb
     endif

     CALL BACLOSE(ifile,ierr)
     if (allocated(cgrib)) deallocate(cgrib)
     nullify(gfld%local)
  enddo loopfile
  return
end subroutine read_grib2_sngle


subroutine read_grib2_allsngle(filename,ntot,lvl,clear_lvl,height,var)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    read_grib2  read grib2 file
!   prgmmr: Ming Hu          org: GSD                 date: 2015-05-20
!
! abstract: read grib2 file
!
!
! program history log:
!   2015-05-20  parrish, initial documentation
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  Zeu
!
!$$$ end documentation block

!  use gridmod, only: idsl5,regional

  implicit none

! Explicitly declare external functions and subroutines
  external :: baopenr,skgb,baread,gb_info,gf_getfld,gf_free,baclose

  character*256,intent(in)  :: filename
  integer, intent(in)       :: ntot,lvl
  integer, intent(out) :: height
  integer, intent(inout) :: clear_lvl
  !real, intent(out) :: var(ntot)
  real, intent(out) :: var(ntot,lvl)
!
!
  type(gribfield) :: gfld
  logical :: expand=.true.
  integer :: ifile
  character(len=1),allocatable,dimension(:) :: cgrib
    integer,parameter :: msk1=32000
  integer :: lskip, lgrib,iseek
  integer :: currlen
  integer :: icount , lengrib
  integer :: listsec0(3)
  integer :: listsec1(13)
  integer year, month, day, hour, minute, second

  integer :: numfields,numlocal,maxlocal,ierr
  integer :: grib_edition,itot,nx,ny
  integer :: nn,n,j,iret,ii,imiss,iclear,igood,iclear_lvl
  real(8),parameter:: R = 6371000 ! meter
  real    :: dx,dy,lat1,lon1
  real    :: scale_factor,max_val,true_min,second_min,third_min,true_max
  real    :: var_geopHgt(ntot,lvl)

!
  scale_factor=1.0e6
  ifile=12
  loopfile: do nn=1,1
     write(6,*) 'read mosaic in grib2 file ', trim(filename)

     lskip=0
     lgrib=0
     iseek=0
     icount=0
     itot=0
     currlen=0


     if (trim(filename).eq. "nr_refd") then
       max_val=200.0
     elseif (trim(filename).eq. "nr_hgt") then
       max_val=99999.0
     else
       write(*,*) "Unknow field"
       return
     endif

! Open GRIB2 file
     call baopenr(ifile,trim(filename),iret)
     if (iret.eq.0) then
        VERSION: do

         ! Search opend file for the next GRIB2 messege (record).
           call skgb(ifile,iseek,msk1,lskip,lgrib)

         ! Check for EOF, or problem
           if (lgrib.eq.0) then
              exit
           endif
         ! Check size, if needed allocate more memory.
           if (lgrib.gt.currlen) then
              if (allocated(cgrib)) deallocate(cgrib)
              allocate(cgrib(lgrib))
              currlen=lgrib
           endif

         ! Read a given number of bytes from unblocked file.
           call baread(ifile,lskip,lgrib,lengrib,cgrib)

           if(lgrib.ne.lengrib) then
              write(*,*) 'ERROR, read_grib2 lgrib ne lengrib', &
                    lgrib,lengrib
              stop 1234
           endif

           iseek=lskip+lgrib
           icount=icount+1
           !write(*,*) 'iseek,icount ',iseek, icount

         ! Unpack GRIB2 field
           call gb_info(cgrib,lengrib,listsec0,listsec1, &
                     numfields,numlocal,maxlocal,ierr)
           if(ierr.ne.0) then
              write(6,*) 'Error querying GRIB2 message',ierr
              stop
           endif
           itot=itot+numfields

           grib_edition=listsec0(2)
           if (grib_edition.ne.2) then
              exit VERSION
           endif
           !write(*,*) 'listsec0=',listsec0
           !write(*,*) 'listsec1=',listsec1
           !write(*,*) 'numfields=',numfields,lengrib

! get information form grib2 file
           n=1
           call gf_getfld(cgrib,lengrib,n,.FALSE.,expand,gfld,ierr)
           year  =gfld%idsect(6)     !(FOUR-DIGIT) YEAR OF THE DATA
           month =gfld%idsect(7)     ! MONTH OF THE DATA
           day   =gfld%idsect(8)     ! DAY OF THE DATA
           hour  =gfld%idsect(9)     ! HOUR OF THE DATA
           minute=gfld%idsect(10)    ! MINUTE OF THE DATA
           second=gfld%idsect(11)    ! SECOND OF THE DATA
           !write(*,*) 'year,month,day,hour,minute,second=',year,month,day,hour,minute,second
           !write(*,*) 'source center =',gfld%idsect(1)
           !write(*,*) 'Indicator of model =',gfld%ipdtmpl(5)
           !write(*,*) 'observation level (m)=',gfld%ipdtmpl(12)
           !write(*,*) 'map projection=',gfld%igdtnum
           height=gfld%ipdtmpl(12)
           if (gfld%igdtnum.eq.0) then ! Lat/Lon grid aka Cylindrical
                                       ! Equidistant
              nx = gfld%igdtmpl(8)
              ny = gfld%igdtmpl(9)
              dx = gfld%igdtmpl(17)/scale_factor
              dy = gfld%igdtmpl(18)/scale_factor
              lat1 = gfld%igdtmpl(12)/scale_factor
              lon1 = gfld%igdtmpl(13)/scale_factor
              !write(*,*) 'nx,ny=',nx,ny
              !write(*,*) 'dx,dy=',dx,dy,  gfld%igdtmpl(17)
              !write(*,*) 'lat1,lon1=',lat1,lon1

           else
               write(*,*) 'unknown projection'
               stop 1235
           endif

           call gf_free(gfld)
         ! Continue to unpack GRIB2 field.
           NUM_FIELDS: do n = 1, numfields
           ! e.g. U and V would =2, otherwise its usually =1
             call gf_getfld(cgrib,lengrib,n,.true.,expand,gfld,ierr)
             if (ierr.ne.0) then
               write(*,*) ' ERROR extracting field gf_getfld = ',ierr
               cycle
             endif

             !write(*,*) 'gfld%ndpts=',n,gfld%ndpts
             !write(*,*) 'gfld%unpacked=',n,gfld%unpacked

!             fldmax=gfld%fld(1)
!             fldmin=gfld%fld(1)
!             sum=gfld%fld(1)

             imiss=0; iclear=0; igood=0
             if(ntot .ne. gfld%ndpts) then   ! happen for refd at clear air level: min/max=0
                write(*,'(2a,i6,2i10)') 'Error, wrong dimension:  ',trim(filename), height, ntot, gfld%ndpts
                  var(:,height)=0.0
                  clear_lvl=clear_lvl+1
                  cycle
             endif
          
             ! hieght: geoptential -> geometric  
             if (trim(filename) .eq. "nr_hgt") then
                 var_geopHgt(:,height)=var(:,height)
                 var(:,height)=(var_geopHgt(:,height) * R) / (R - var_geopHgt(:,height)) 
             endif    

             ! assign missing value for those out of NR domain but on MRMS domain
             do j=1,gfld%ndpts
               var(j,height)=gfld%fld(j)

               if (var(j,height) > max_val) then
                 imiss=imiss+1
                 var(j,height)=missing
               else
                   igood=igood+1      
               endif
             enddo        

             call gf_free(gfld)
           enddo NUM_FIELDS

           true_min = minval(var(:,height))
           second_min = minval(var(:,height), mask = (var(:,height) > true_min))
           third_min = minval(var(:,height), mask = (var(:,height) > second_min))
           true_max=maxval(var(:,height))
           write(*,'(2a,i4,2i10,4F15.4)') 'all_level,missing,good,1-2-3_mins,max:  ',trim(filename),height,imiss,igood,&
                                         true_min,second_min,third_min,true_max

        enddo VERSION ! skgb
     endif

     CALL BACLOSE(ifile,ierr)
     if (allocated(cgrib)) deallocate(cgrib)
     nullify(gfld%local)
  enddo loopfile
  return
end subroutine read_grib2_allsngle



end module module_read_grib2
