c
c $Id: subvintp.f,v 1.3 2009-03-24 17:49:19 georg Exp $
c
c routines for vertical interpolation
c
c contents :
c
c revision log :
c
c 04.10.2012    ggu     copied from newbsig.f
c
c*****************************************************************

	subroutine intp_vert(bcons,nl1,zb1,var1,nl2,zb2,var2)

c vertical interpolation of variables from one grid to another

	implicit none

	logical bcons		!conserve total quantity
	integer nl1		!number of levels of first grid
	real zb1(0:nl1+1)	!depth of bottom of vertical boxes
	real var1(nl1+1)	!value of variable at center of box
	integer nl2		!number of levels of second grid
	real zb2(0:nl2)		!depth of bottom of vertical boxes
	real var2(nl2)		!value of variable at center of box (out)

c values are interpolated from first grid to second grid
c z levels refer to bottom of each grid (zb1(nl1) is total depth of column)
c zb(0) is surface ... normally 0
c variables are considered at center of box
c values are considered to be constant for every box
c bcons controlls if total quantity is conserved or not
c
c ATTENTION: arrays zb1, var1 MUST be dimensioned one element bigger
c	then the available data. The last element is altered by this
c	subroutine, but should be of no concern for the calling program
c
c output is var2, all other variables are input values

	logical bmiss
	integer l,j,ltop1,lbot1
	real ztop2,ztop1,zbot2,zbot1
	real ztop,zbot
	real vint1,vint2,fact
	real val

	zb1(nl1+1) = zb2(nl2)
	var1(nl1+1) = var1(nl1)

	ltop1 = 0
	vint2 = 0.

	do l=1,nl2
	  ztop2 = zb2(l-1)
	  zbot2 = zb2(l)

	  do while( ltop1 .lt. nl1 .and. zb1(ltop1+1) .le. ztop2 )
	    !write(6,*) 'adjourning top depth: ',ltop1,zb1(ltop1+1),ztop2
	    ltop1 = ltop1 + 1
	  end do

	  bmiss = .false.
	  do lbot1=ltop1+1,nl1+1
	    if( zb1(lbot1) .ge. zbot2 ) goto 1
	  end do
	  lbot1 = nl1
	  bmiss = .true.
    1	  continue

	  ztop1 = zb1(ltop1)
	  zbot1 = zb1(lbot1)

	  if( ztop1 .gt. ztop2 .or. zbot1 .lt. zbot2 ) goto 99
	  if( bmiss ) goto 98

	  !write(6,*) l,ltop1,lbot1,ztop2,zbot2,zb1(lbot1)

	  val = 0.
	  do j=ltop1+1,lbot1
	      ztop = max(zb1(j-1),ztop2)
	      zbot = min(zb1(j),zbot2)
	      val = val + var1(j) * ( zbot - ztop )
	  end do

	  vint2 = vint2 + val			!integrated value
	  var2(l) = val / (zbot2-ztop2)
	  ltop1 = lbot1 - 1

	end do

	zb1(nl1+1) = 0.
	var1(nl1+1) = 0.

	if( bcons ) then	!must conserve total content of scalar
	  vint1 = 0.
	  do l=1,nl1
	    ztop = zb1(l-1)
	    zbot = zb1(l)
	    vint1 = vint1 + var1(l) * ( zbot - ztop )
	  end do

	  if( vint1 .eq. vint2 ) return

	  fact = vint1 / vint2
	  do l=1,nl2
	    var2(l) = fact * var2(l)
	  end do
	end if

	return
   98	continue
	stop 'error stop intp_vert: missing value not possible'
   99	continue
	write(6,*) ztop1,ztop2
	write(6,*) zbot1,zbot2
	stop 'error stop intp_vert: interval in (1) must include (2)'
	end

c*****************************************************************

        subroutine intp_aver(n,horig,vorig,femval)

        implicit none

        integer n
        real horig(0:n)
        real vorig(n)
        real femval

        integer i
        real hacu,acu,h

        acu = 0.
        hacu = 0.
        do i=1,n
          h = horig(i) - horig(i-1)
          hacu = hacu + h
          acu = acu + h * vorig(i)
        end do

        femval = acu / hacu

        end

c*****************************************************************

	subroutine intp_vert_test

	implicit none

	integer ndim
	parameter (ndim=100)
	real zb1(0:ndim+1)
	real var1(ndim+1)
	real zb2(0:ndim)
	real var2(ndim)
	logical bcons
	integer nl1,nl2,i

	nl1 = 1
	zb1(0) = 0.
	zb1(1) = 10.

	nl2 = 1
	zb2(0) = 0.
	zb2(1) = 8.

	var1(1) = 30.

	bcons = .false.
	call intp_vert(bcons,nl1,zb1,var1,nl2,zb2,var2)
	write(6,*) bcons,var1(1),var2(1)

	bcons = .true.
	call intp_vert(bcons,nl1,zb1,var1,nl2,zb2,var2)
	write(6,*) bcons,var1(1),var2(1)

	nl1 = 2
	zb1(2) = 20.
	var1(2) = 40.

	bcons = .false.
	call intp_vert(bcons,nl1,zb1,var1,nl2,zb2,var2)
	write(6,*) bcons,(var1(i),i=1,nl1),(var2(i),i=1,nl2)

	bcons = .true.
	call intp_vert(bcons,nl1,zb1,var1,nl2,zb2,var2)
	write(6,*) bcons,(var1(i),i=1,nl1),(var2(i),i=1,nl2)

	end

c*****************************************************************

	!program main_intp_vert_test
	!call intp_vert_test
	!end

c*****************************************************************
