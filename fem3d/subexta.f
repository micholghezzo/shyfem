c
c $Id: subexta.f,v 1.6 2001/11/16 07:35:43 georg Exp $
c
c extra file administration routines
c
c revision log :
c
c 08.05.1998	ggu	changed read of node numbers through nrdveci
c 20.01.2000    ggu     common block /dimdim/ eliminated
c 01.02.2000    ggu     module framework introduced
c 20.05.2015    ggu     modules introduced
c 20.10.2017    ggu     new framework - read also table with strings
c 22.11.2017    ccf     write also waves and sediment concentration
c
c******************************************************************
c******************************************************************
c******************************************************************

!==================================================================
        module extra
!==================================================================

        implicit none

        integer, save :: knausm = 0
        integer, save, allocatable :: knaus(:)
        integer, save, allocatable :: knext(:)
        character*80, save, allocatable :: chext(:)

!==================================================================
        contains
!==================================================================

!==================================================================
        end module extra
!==================================================================

	subroutine extra_read_section(n)

	use extra
	use nls

	integer n

	call nls_init_section

	!n = nls_read_vector()
	n = nls_read_ictable()
	knausm = n

	if( n > 0 ) then
	  allocate(knaus(n))
	  allocate(knext(n))
	  allocate(chext(n))
	  !call nls_copy_int_vect(n,knaus)
	  call nls_copy_ictable(n,knaus,chext)
	  knext = knaus
	end if

	call nls_finish_section

	end subroutine extra_read_section

c******************************************************************
c******************************************************************
c******************************************************************

	subroutine mod_ext(mode)

	implicit none

	integer mode

	include 'modules.h'

	if( mode .eq. M_AFTER ) then
	   call wrexta
	else if( mode .eq. M_INIT ) then
	   call inexta
	else if( mode .eq. M_READ ) then
	   call rdexta
	else if( mode .eq. M_CHECK ) then
	   call ckexta
	else if( mode .eq. M_SETUP ) then
	   call wrexta				!ggu 7/5/2001 -> write it=0
	else if( mode .eq. M_PRINT ) then
	   call prexta
	else if( mode .eq. M_TEST ) then
	   call tsexta
	else if( mode .eq. M_BEFOR ) then
c	   nothing
	else
	   write(6,*) 'unknown mode : ', mode
	   stop 'error stop mod_ext'
	end if

	end

c******************************************************************

	subroutine inexta

	implicit none

	end

c******************************************************************

	subroutine rdexta

	use extra

	implicit none

	integer n
	logical handlesec

	if( .not. handlesec('extra') ) return

	call extra_read_section(n)

	if( n .lt. 0 ) then
	  write(6,*) 'read error in section $extra'
	  stop 'error stop rdexta'
	end if

	end

c******************************************************************

	subroutine ckexta

	use extra
	use shympi

	implicit none

	integer k,knode
	integer ipint
	logical bstop

	bstop = .false.

        do k=1,knausm
           knode=ipint(knaus(k))                !$$EXTINW
           if(knode.le.0) then
	     if( .not. bmpi ) then
                write(6,*) 'section EXTRA : node not found ',knaus(k)
                bstop=.true.
	     end if
	   else if( .not. shympi_is_inner_node(knode) ) then
	     knode = 0
           end if
           knaus(k)=knode
        end do

	if( bstop ) stop 'error stop: ckexta'

	end

c******************************************************************

	subroutine prexta

	use extra

	implicit none

	integer i,k

        if(knausm.le.0) return

        write(6,*)
        write(6,*) 'extra section : ',knausm
	do i=1,knausm
	  k = knext(i)
          write(6,*) i,k,'  ',trim(chext(i))
	end do
        write(6,*)

	end

c******************************************************************

	subroutine tsexta

	use extra

	implicit none

	integer i

        write(6,*) '/knausc/'
        write(6,*) knausm
	do i=1,knausm
          write(6,*) i,knext(i),'  ',trim(chext(i))
	end do

	end

c******************************************************************
c******************************************************************
c******************************************************************

	subroutine wrexta

c writes and administers ext file

	use mod_hydro
	use mod_hydro_print
	use mod_ts
	use mod_conz, only : cnv
        use mod_waves, only: waveh,wavep,waved
        use mod_sediment, only : tcn
	use mod_depth
	use basin
	use levels
	use extra
	use shympi

	implicit none

	include 'simul.h'

	integer nbext,ierr
	integer ivar,m,j,k,iv,nlv2d
	real href,hzmin
	double precision atime,atime0
	character*80 femver,title
	integer kext(knausm)
	real hdep(knausm)
	real x(knausm)
	real y(knausm)
	real vals(nlv,knausm,3)
	integer, save :: nvar
	logical, save :: btemp,bsalt,bconz,bwave,bsedi
	integer, save, allocatable :: il(:)
	integer, save, allocatable :: kind(:,:)
	character*80 strings(knausm)

	integer ideffi,ipext
	real getpar
	logical has_output_d,next_output_d

	double precision, save :: da_out(4) = 0
	integer, save :: icall = 0

	if( icall .eq. -1 ) return

c--------------------------------------------------------------
c initialization
c--------------------------------------------------------------

	if( icall .eq. 0 ) then
          call init_output_d('itmext','idtext',da_out)
	  call assure_initial_output_d(da_out)
          if( .not. has_output_d(da_out) ) icall = -1
	  if( knausm .le. 0 ) icall = -1
	  if( icall .eq. -1 ) return

          btemp = ( nint(getpar('itemp')) > 0 )
          bsalt = ( nint(getpar('isalt')) > 0 )
          bconz = ( nint(getpar('iconz')) == 1 )
          bsedi = ( nint(getpar('isedi')) > 0 )
          bwave = ( nint(getpar('iwave')) > 0 )

          nvar = 2				!includes zeta and vel
          if( btemp ) nvar = nvar + 1
          if( bsalt ) nvar = nvar + 1
          if( bconz ) nvar = nvar + 1
          if( bsedi ) nvar = nvar + 1
          if( bwave ) nvar = nvar + 1

	  if( shympi_is_master() ) then
	    nbext=ideffi('datdir','runnam','.ext','unform','new')
            if(nbext.le.0) goto 99
	    da_out(4) = nbext
            call ext_write_header(nbext,0,knausm,nlv,nvar,ierr)
            if( ierr /= 0 ) goto 98
	  end if

	  allocate(il(knausm))
	  allocate(kind(2,knausm))
	  il = 0
	  kext = 0
	  hdep = 0.
	  x = 0.
	  y = 0.
	  strings = ' '
	  title = descrp
	  href = getpar('href')
	  hzmin = getpar('hzmin')
	  call collect_header(knausm,kext,hdep,x,y,il,strings,kind)
	  call get_shyfem_version(femver)
	  call get_absolute_ref_time(atime0)
	  if( shympi_is_master() ) then
            call ext_write_header2(nbext,0,knausm,nlv
     +                          ,atime0
     +                          ,href,hzmin,title,femver
     +                          ,kext,hdep,il,x,y,strings,hlv
     +                          ,ierr)
            if( ierr /= 0 ) goto 96
	  end if
        end if

	icall = icall + 1

c--------------------------------------------------------------
c write file ext
c--------------------------------------------------------------

        if( .not. next_output_d(da_out) ) return

        nbext = nint(da_out(4))
	call get_absolute_act_time(atime)

	nlv2d = nlv
	!nlv2d = 1	!to be tested
	vals = 0.

c	-------------------------------------------------------
c	barotropic velocities and water level
c	-------------------------------------------------------

	iv = 1
	ivar = 1
	m = 3
	do j=1,knausm
	  !k = knaus(j)
	  !if( k <= 0 ) cycle
	  call shympi_getvals(kind(:,j),up0v,vals(1,j,1))
	  call shympi_getvals(kind(:,j),vp0v,vals(1,j,2))
	  call shympi_getvals(kind(:,j),znv,vals(1,j,3))
	  !vals(1,j,1) = up0v(k)
	  !vals(1,j,2) = vp0v(k)
	  !vals(1,j,3) = znv(k)
	end do
	if( shympi_is_master() ) then
        call ext_write_record(nbext,0,atime,knausm,nlv2d
     +                                  ,ivar,m,il,vals,ierr)
        if( ierr /= 0 ) goto 97
	end if

c	-------------------------------------------------------
c	velocities
c	-------------------------------------------------------

	iv = iv + 1
	ivar = 2
	m = 2
	do j=1,knausm
	  !k = knaus(j)
	  !if( k <= 0 ) cycle
	  call shympi_getvals(kind(:,j),uprv,vals(:,j,1))
	  call shympi_getvals(kind(:,j),vprv,vals(:,j,2))
	  !vals(:,j,1) = uprv(:,k)
	  !vals(:,j,2) = vprv(:,k)
	end do
	if( shympi_is_master() ) then
          call ext_write_record(nbext,0,atime,knausm,nlv
     +                                  ,ivar,m,il,vals,ierr)
          if( ierr /= 0 ) goto 97
	end if

c	-------------------------------------------------------
c	temperature
c	-------------------------------------------------------

	m = 1

	if( btemp ) then
	  iv = iv + 1
	  ivar = 12
	  do j=1,knausm
	    !k = knaus(j)
	    !if( k <= 0 ) cycle
	    call shympi_getvals(kind(:,j),tempv,vals(:,j,1))
	    !vals(:,j,1) = tempv(:,k)
	  end do
	  if( shympi_is_master() ) then
            call ext_write_record(nbext,0,atime,knausm,nlv
     +                                  ,ivar,m,il,vals,ierr)
            if( ierr /= 0 ) goto 97
	  end if
	end if

c	-------------------------------------------------------
c	salinity
c	-------------------------------------------------------

	if( bsalt ) then
	  iv = iv + 1
	  ivar = 11
	  do j=1,knausm
	    !k = knaus(j)
	    !if( k <= 0 ) cycle
	    call shympi_getvals(kind(:,j),saltv,vals(:,j,1))
	    !vals(:,j,1) = saltv(:,k)
	  end do
	  if( shympi_is_master() ) then
            call ext_write_record(nbext,0,atime,knausm,nlv
     +                                  ,ivar,m,il,vals,ierr)
            if( ierr /= 0 ) goto 97
	  end if
	end if

c	-------------------------------------------------------
c	concentration
c	-------------------------------------------------------

	if( bconz ) then
	  iv = iv + 1
	  ivar = 10
	  do j=1,knausm
	    !k = knaus(j)
	    !if( k <= 0 ) cycle
	    call shympi_getvals(kind(:,j),cnv,vals(:,j,1))
	    !vals(:,j,1) = cnv(:,k)
	  end do
	  if( shympi_is_master() ) then
            call ext_write_record(nbext,0,atime,knausm,nlv
     +                                  ,ivar,m,il,vals,ierr)
            if( ierr /= 0 ) goto 97
	  end if
	end if

c	-------------------------------------------------------
c	total suspended sediment concentration
c	-------------------------------------------------------

	if( bsedi ) then
	  iv = iv + 1
	  ivar = 800
	  do j=1,knausm
	    !k = knaus(j)
	    !if( k <= 0 ) cycle
	    call shympi_getvals(kind(:,j),tcn,vals(:,j,1))
	    !vals(:,j,1) = tcn(:,k)
	  end do
	  if( shympi_is_master() ) then
            call ext_write_record(nbext,0,atime,knausm,nlv
     +                                  ,ivar,m,il,vals,ierr)
            if( ierr /= 0 ) goto 97
	  end if
	end if

c       -------------------------------------------------------
c       waves
c       -------------------------------------------------------

        if( bwave ) then
          iv = iv + 1
          ivar = 230
	  m = 3
          do j=1,knausm
            !k = knaus(j)
	    !if( k <= 0 ) cycle
	    call shympi_getvals(kind(:,j),waveh,vals(1,j,1))
	    call shympi_getvals(kind(:,j),wavep,vals(1,j,2))
	    call shympi_getvals(kind(:,j),waved,vals(1,j,3))
            !vals(1,j,1) = waveh(k)
            !vals(1,j,2) = wavep(k)
            !vals(1,j,3) = waved(k)
          end do
	  if( shympi_is_master() ) then
            call ext_write_record(nbext,0,atime,knausm,nlv2d
     +                                  ,ivar,m,il,vals,ierr)
            if( ierr /= 0 ) goto 97
	  end if
        end if

c--------------------------------------------------------------
c error check
c--------------------------------------------------------------

	if( iv /= nvar ) goto 91

c--------------------------------------------------------------
c end of routine
c--------------------------------------------------------------

	return
   91   continue
	write(6,*) 'iv,nvar: ',iv,nvar
	write(6,*) 'iv is different from nvar'
	stop 'error stop wrexta: internal error (1)'
   99   continue
	write(6,*) 'Error opening EXT file :'
	stop 'error stop wrexta: opening ext file'
   96   continue
	write(6,*) 'Error writing second header of EXT file'
	write(6,*) 'unit,ierr :',nbext,ierr
	stop 'error stop wrexta: writing second ext header'
   98   continue
	write(6,*) 'Error writing first header of EXT file'
	write(6,*) 'unit,ierr :',nbext,ierr
	stop 'error stop wrexta: writing first ext header'
   97   continue
	write(6,*) 'Error writing record of EXT file'
	write(6,*) 'unit,iv,ierr :',nbext,iv,ierr
	write(6,*) btemp,bsalt,bconz,bwave,bsedi
	stop 'error stop wrexta: writing ext record'
	end

c*********************************************************

	subroutine collect_header(n,kext,hdep,x,y,il,strings,kind)

	use basin
	use levels
	use mod_depth
	use extra
	use shympi

	implicit none

	integer n
	integer kext(n)
	real hdep(n)
	real x(n)
	real y(n)
	integer il(n)
	character*(*) strings(n)
	integer kind(2,n)

	integer j,k,ke,ki,id

	if( n /= knausm ) stop 'error stop collect_header: internal error'

	do j=1,knausm
	  ke = knext(j)
	  call shympi_find_node(ke,ki,id)
	  kind(1,j) = ki
	  kind(2,j) = id
	end do

	do j=1,knausm
	  k = knaus(j)
	  ke = knext(j)
          kext(j) = knext(j)
	  strings(j) = chext(j)

	  call shympi_collect_node_value_r(k,xgv,x(j))
	  call shympi_collect_node_value_r(k,ygv,y(j))
	  call shympi_getvals(kind(:,j),hkv_max,hdep(j))
	  !call shympi_getvals(kind(:,j),xgv,x(j))
	  !call shympi_getvals(kind(:,j),ygv,y(j))
	  call shympi_getvals(kind(:,j),ilhkv,il(j))
	end do

	call shympi_barrier
	return

	if( shympi_is_master() ) then
	  do j=1,knausm
	    ke = knext(j)
	    ki = kind(1,j)
	    id = kind(2,j)
	    write(6,*) '++ ',ke,ki,id,y(j)
	  end do
	end if
	call shympi_finalize
	stop

	end

c*********************************************************

