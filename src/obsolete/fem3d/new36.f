
!--------------------------------------------------------------------------
!
!    Copyright (C) 1988,1990,1992,1998-1999,2001,2003-2004  Georg Umgiesser
!    Copyright (C) 2008,2010,2014-2020  Georg Umgiesser
!
!    This file is part of SHYFEM.
!
!    SHYFEM is free software: you can redistribute it and/or modify
!    it under the terms of the GNU General Public License as published by
!    the Free Software Foundation, either version 3 of the License, or
!    (at your option) any later version.
!
!    SHYFEM is distributed in the hope that it will be useful,
!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
!    GNU General Public License for more details.
!
!    You should have received a copy of the GNU General Public License
!    along with SHYFEM. Please see the file COPYING in the main directory.
!    If not, see <http://www.gnu.org/licenses/>.
!
!    Contributions to this file can be found below in the revision log.
!
!--------------------------------------------------------------------------

! closing routines
!
! contents :
!
! subroutine sp136(ic)		opens and closes sections & inlets
!
! subroutine inclos		initializes closing sections
! subroutine rdclos(isc)	reads closing sections
! subroutine ckclos		post-processes closing sections
! subroutine prclos		prints info on closing sections
! subroutine tsclos		tests closing sections
!
! subroutine insvcl(name,lip,ltot,isc,iweich,ival)
!			inserts vector in data structure of closing sections
! subroutine convk(lip,isc,bstop)
!			converts node to internal number
!
! function volag(mode,z)        determination of water volume in whole basin
!
! revision log :
!
! 26.07.1988	ggu	(introduction of ic)
! 15.12.1988	ggu	(bfluss,bspec)
! 20.12.1988	ggu	(iop=6,7,8 using level out of lagoon)
! 14.03.1990	ggu	(completely restructured)
! 31.03.1990	ggu	(test : change chezy values ^^^^)
! 27.08.1992	ggu	$$0 - not used
! 27.08.1992	ggu	$$1 - for new algorithm (const. form func.)
! 31.08.1992	ggu	$$impli - implicit time step
! 24.09.1992	ggu	$$2 - special technital (fluxes) -> deleted
! 24.09.1992	ggu	$$3 - chezy closing
! 29.09.1992	ggu	$$4 - remove writing of vectors (NAN)
! 25.03.1998	ggu	integrated changes from technital version
! 27.03.1998	ggu	utility routines for reading etc...
! 27.03.1998	ggu	dead code deleted, xv(1) -> xv(3,1)
! 27.03.1998	ggu	/bnd/ substituted by utility routine
! 29.04.1998	ggu	uses module for semi-implicit time-step
! 22.10.1999	ggu	volag copied to this file (only used here)
! 05.12.2001	ggu	fixed compiler error with -Wall -pedantic
! 09.12.2003	ggu	fix for icl=10 (FIX)
! 10.03.2004	ggu	RQVDT - value in rqv is now discharge [m**3/s]
! 11.10.2008	ggu	bug in call to nrdnxt (real instead of double p.)
! 23.03.2010	ggu	changed v6.1.1
! 05.12.2014	ggu	changed VERS_7_0_8
! 12.12.2014	ggu	changed VERS_7_0_9
! 19.12.2014	ggu	changed VERS_7_0_10
! 23.12.2014	ggu	changed VERS_7_0_11
! 19.01.2015	ggu	changed VERS_7_1_3
! 05.05.2015	ggu	changed VERS_7_1_10
! 17.07.2015	ggu	changed VERS_7_1_80
! 20.07.2015	ggu	changed VERS_7_1_81
! 25.05.2016	ggu	changed VERS_7_5_10
! 14.11.2017	ggu	changed VERS_7_5_36
! 05.12.2017	ggu	changed VERS_7_5_39
! 18.12.2018	ggu	changed VERS_7_5_52
! 16.02.2019	ggu	changed VERS_7_5_60
! 13.03.2019	ggu	changed VERS_7_5_61
! 06.11.2019	ggu	setimp adapted
! 16.02.2020	ggu	femtime eliminated
! 09.11.2023	ggu	daux introduced to avoid error
!
!************************************************************************

	subroutine sp136(ic)

! opens and closes sections & inlets
!
! iclose	1 : closing by diminishing depth
!		2 : closing by diminishing flux
!		3 : closing by diminishing flux that depends on
!			water volumn in basin
!		4 : partial closing by changing chezy
!		...2 and 3 may be used only with ibnd != 0
!
! kboc		vector containing node numbers that define
!		...opening/closing section
! ibnd		number of open boundary to use for opening/closing
!		...(kboc and ibnd are mutually esclusive)
!
! kref		reference node in section (used for mode)
! kin,kout	inner and outer node for section (used for mode)
! kdir		node defining direction for icl=2,3 : direction = kdir-kref
!		...default for nodes kref=kin=kout=kdir and
!		...kref is middle node in section
!
! ibndz		number of boundary that is used to establish the value
!		...of zout instead of taking it from node kout
!		...(when a section is closed at an open boundary
!		...the value of zout at node kout is similar to zin
!		...and not to the value of z outside of the section)
!
! itb		vector containing: it1,imode1,it2,imode2...
!		...where it. is the time from when imode. is valid
! imode		= 100 * icl + iop
!
! icl		0:no closing  1:forced closing
!		2:vref=0 and change to positive dir. (empty basin)
!		3:vref=0 and change to negative dir. (full basin)
!		4:vref>vdate  5:vref<vdate
!		6:zout>zdate  7:zout<zdate
!		8:zin>zdate  9:zin<zdate
!		icl>20:immediate (e.g. 25 <=> icl=5 + immediate)
!
! iop		0:no opening  1:forced opening
!		2:zin>zout  3:zin<zout	(same as 4,5 with zdiff=0.)
!		4:zin-zout>zdiff  5:zin-zout<zdiff
!		6:zout>zdate  7:zout<zdate
!		iop>20:immediate (e.g. 25 <=> icl=5 + immediate)
!
! isoft		number of timesteps for which opening/closing
!		...has to be distributed
! mnstp		number of timesteps for which no opening/closing
!		...can be performed after last action
!
! zdate,zdiff	water level variables used in mode
! vdate		velocity variable used in mode

	use mod_bound_dynamic
	use mod_diff_visc_fric
	use mod_hydro_print
	use mod_hydro
	use basin
	use shympi
	use close

	implicit none

	integer ic		!0 if no change in configuration   (out)


! local
	logical bclos,bopen,bimm,bact
	logical bspec
	logical bdepcl,bflxcl,bspecl,bchez

	integer i,ie,j,ii
        integer nsc,ipful,ivful,jivful,ivdim
        integer nkboc,jkboc,niboc,jiboc,jhboc
        integer nitb,jitb,kout,kin,kref,kdir,isoft
        integer mnstp,iclos,istp,iact,imode
        integer jflux,ibnd,ibndz
        real zdate,vdate,scal,href,zdiff

	integer iclose,isw,kn,kboc
	integer ibtyp,icltot,ioptot,icl,iop
	integer k1,k2,k,l
	integer icycle
	integer nbc
	integer it,idt
	real dt
	real scalo,zin,zout,zref,u,v,uvref2,dx,dy
	real h1,h2,z1,z2,hm,flux1,flux2,geyer
	real fluxnn,rmass,hboc,h
	real u1,u2,v1,v2,uv1,uv2
	real volact,dvolac

	integer nvert
	integer kvert(10)
	real hdep(10)

	real czcls(3) !$$3

	integer iround
	real getpar
	real volag,flxnod,areavl
	real zvbnds
	integer itybnd,ideffi,nbnds
	double precision dtime,daux

!---------------------------------------------------------------
!        integer ipnt,id,isect
!       ipnt(id,isect) = lhead + lsect*(isect-1) + id
!---------------------------------------------------------------

! save & data
	real volmax,volini,dvolin
	save volmax,volini,dvolin
	logical binit,bfull,bfalse	!$$ALPHA
	save binit,bfull,bfalse	!$$ALPHA
	integer implit
        save implit
	integer nb13
	save nb13
!	real weight
!       save weight
	real hdry
	save hdry

! data
	data binit /.true./
	data bfull /.false./	!write full info every time step
	data bfalse /.false./	!$$ALPHA
        data implit /9/   !number of time steps with implicit scheme
!       data weight /1./  !weight to be used
	data hdry /-2./

!+++++++++++++++++++++++++++++++++++++++++++++++
        data czcls /.2,.2,.2/  !$$3
!+++++++++++++++++++++++++++++++++++++++++++++++

!---------------------------------------------------------------
        integer ipnt,id,isect
        ipnt(id,isect) = lhead + lsect*(isect-1) + id
!---------------------------------------------------------------

	iclose=iround(getpar('iclose'))
	if(iclose.le.0) return		!no closing enabled
!
	if( shympi_is_parallel() ) then
	  stop 'error stop sp136: cannot run in mpi mode'
	end if

	if(iclose.gt.0.and.iclose.ne.4) then
	  iclose=2  !$$1 - for new model close only thru flux
	end if

	bdepcl = iclose.eq.1	!changing depth quota
	bflxcl = iclose.eq.2	!diminishing flux at boundary
	bspecl = iclose.eq.3	!as 2 but flux is function of filling
	bchez  = iclose.eq.4	!partial closing by changing chezy  !$$3
!
	if( binit ) then	!open file
	  nb13=ideffi('datdir','runnam','.cls','form','new')
	  if( nb13 .le. 0 ) then
	    stop 'error stop sp136 : Cannot open CLS file'
	  end if
	end if

	ic=0				!----   do not compute new uv-matrix
	nsc=ipccv(ipnt(lnsect,0))	!number of sections
	nbc = nbnds()

	icycle = 4			!cyclic openings

	call get_timestep(dt)
	call get_act_dtime(dtime)
	idt = nint(dt)
	it = nint(dtime)

	write(nb13,*) '**********',it,'   **********'
	write(nb13,*) '***********************************'
	write(nb13,*)

	do j=1,nsc
!
	if(binit) then				!first call
!
! 		dimension and filling of vectors
!
!$$0            ipdim=ipccv(ipnt(lipdim,0))
		ivdim=ipccv(ipnt(livdim,0))
!$$0            jipful=ipccv(ipnt(lipful,0))
		jivful=ipccv(ipnt(livful,0))
!
!		parameters for section nodes
!
		nkboc=ipccv(ipnt(lnkboc,j))
		jkboc=ipccv(ipnt(lkboc,j))-1
!
!		reserve space for hboc
!
		jhboc=jivful
		jivful=jivful+nkboc
		ipccv(ipnt(lhboc,j))=jhboc+1
		if(jivful.gt.ivdim) goto 89
!
!		reserve space for flux
!
		jflux=jivful
		jivful=jivful+nkboc
		ipccv(ipnt(lflux,j))=jflux+1
		if(jivful.gt.ivdim) goto 89
!
!		control nodes
!
		kout=ipccv(ipnt(lkout,j))
		kin=ipccv(ipnt(lkin,j))
		kref=ipccv(ipnt(lkref,j))
		kdir=ipccv(ipnt(lkdir,j))
!
		if(kref.le.0) kref=ivccv(jkboc+1)	!take first section node
		if(kdir.le.0) kdir=kref
		if(kout.le.0) kout=kref
		if(kin.le.0)  kin=kref
!
		ipccv(ipnt(lkout,j))=kout
		ipccv(ipnt(lkin,j))=kin
		ipccv(ipnt(lkref,j))=kref
		ipccv(ipnt(lkdir,j))=kdir
!
!		parameters for element index
!
		jiboc=jivful
		niboc=0
!
		do ie=1,nel
		  isw=0		!isw=1 ==> node in element ie found
!
!		  depth for control and section nodes
!

		  call depvele(ie,0,nvert,hdep)
		  call nindex(ie,nvert,kvert)

		  do i=1,nvert
		    kn = kvert(i)
		    if(kn.eq.kref) rpccv(ipnt(lhref,j)) = hdep(i)
		    do ii=1,nkboc
			kboc=ivccv(jkboc+ii)
			if(kn.eq.kboc) then
			  rvccv(jhboc+ii) = hdep(i)
			  isw=1
			end if
		    end do
		  end do
!
!		  put in element index
!
		  if(isw.eq.1) then
			niboc=niboc+1
			if(jiboc+niboc.gt.ivdim) goto 89
			ivccv(jiboc+niboc)=ie
		  end if
		end do
!
!		memorize computed parameters
!
		jivful=jivful+niboc
		ipccv(ipnt(livful,0))=jivful
		ipccv(ipnt(lniboc,j))=niboc
		ipccv(ipnt(liboc,j))=jiboc+1
!
!		set variables
!
		ipccv(ipnt(listp,j))=ipccv(ipnt(lmnstp,j))
		rpccv(ipnt(lscal,j))=0.
		ipccv(ipnt(liact,j))=1
!
!		control ibnd
!
		ibnd=ipccv(ipnt(libnd,j))
		ibndz=ipccv(ipnt(libndz,j))
		if(ibnd.gt.nbc) goto 82
		if(ibndz.gt.nbc) goto 82
		if(ibndz.le.0.and.ibnd.gt.0) ibndz=ibnd
		ipccv(ipnt(libndz,j))=ibndz
!
!		!-----------------------------------------
		write(nb13,*)
		write(nb13,*) 'first call for closing section nr. : ',j
		write(nb13,*)
		write(nb13,*) 'kout,kin  : ',ipv(kout),ipv(kin)
		write(nb13,*) 'kref,kdir : ',ipv(kref),ipv(kdir)
		write(nb13,*) 'nkboc : ',nkboc
		write(nb13,*) 'kboc : '
		write(nb13,*) (ipv(ivccv(jkboc+ii)),ii=1,nkboc)
		write(nb13,*) 'href : '
		write(nb13,*) rpccv(ipnt(lhref,j))
		write(nb13,*) 'hboc : '
		write(nb13,*) (rvccv(jhboc+ii),ii=1,nkboc)
		write(nb13,*) 'niboc : ',niboc
		write(nb13,*) 'iboc : '
		write(nb13,*) (ipev(ivccv(jiboc+ii)),ii=1,niboc)
		write(nb13,*)
!		!-----------------------------------------
!
		write(nb13,*) '----------------------------'
		ipful=ipccv(ipnt(lipful,0))
		ivful=ipccv(ipnt(livful,0))
!$$4		write(nb13,*) (ipccv(i),i=1,ipful)
!$$4		write(nb13,*) (rpccv(i),i=1,ipful)
!$$4		write(nb13,*) (ivccv(i),i=1,ivful)
!$$4		write(nb13,*) (rvccv(i),i=1,ivful)
		write(nb13,*) '----------------------------'
	end if
!
! get parameters
!
	nkboc=ipccv(ipnt(lnkboc,j))
	jkboc=ipccv(ipnt(lkboc,j))-1
	niboc=ipccv(ipnt(lniboc,j))
	jiboc=ipccv(ipnt(liboc,j))-1
	jhboc=ipccv(ipnt(lhboc,j))-1
	nitb=ipccv(ipnt(lnitb,j))
	jitb=ipccv(ipnt(litb,j))-1
	kout=ipccv(ipnt(lkout,j))
	kin=ipccv(ipnt(lkin,j))
	kref=ipccv(ipnt(lkref,j))
	kdir=ipccv(ipnt(lkdir,j))
	isoft=ipccv(ipnt(lisoft,j))
	zdate=rpccv(ipnt(lzdate,j))
	vdate=rpccv(ipnt(lvdate,j))
	mnstp=ipccv(ipnt(lmnstp,j))
	iclos=ipccv(ipnt(liclos,j))
	istp=ipccv(ipnt(listp,j))
	scalo=rpccv(ipnt(lscal,j))
	href=rpccv(ipnt(lhref,j))
	iact=ipccv(ipnt(liact,j))
	imode=ipccv(ipnt(limode,j))
	zdiff=rpccv(ipnt(lzdiff,j))
	jflux=ipccv(ipnt(lflux,j))-1
	ibnd=ipccv(ipnt(libnd,j))
	ibndz=ipccv(ipnt(libndz,j))
!
	if(bfull) then
!
	write(nb13,*) '-------------------------------------------------'
	write(nb13,*) 'section :',j
	write(nb13,*) 'nkboc,jkboc,niboc,jiboc :',nkboc,jkboc,niboc,jiboc
	write(nb13,*) 'jhboc,nitb,jitb :',jhboc,nitb,jitb
	write(nb13,*) 'kout,kin,kref,kdir :',kout,kin,kref,kdir
	write(nb13,*) 'isoft,zdate,vdate :',isoft,zdate,vdate
	write(nb13,*) 'mnstp,iclos,istp :',mnstp,iclos,istp
	write(nb13,*) 'scal,href,iact,imode :',scal,href,iact,imode
	write(nb13,*) 'zdiff,jflux,ibnd,ibndz :',zdiff,jflux,ibnd,ibndz
!
	write(nb13,*) 'kboc :'
	write(nb13,*) (ivccv(jkboc+i),i=1,nkboc)
	write(nb13,*) 'iboc :'
	write(nb13,*) (ivccv(jiboc+i),i=1,niboc)
	write(nb13,*) 'hboc :'
	write(nb13,*) (rvccv(jhboc+i),i=1,nkboc)
	write(nb13,*) 'flux :'
	write(nb13,*) (rvccv(jflux+i),i=1,nkboc)
	write(nb13,*) 'itb :'
	write(nb13,*) (ivccv(jitb+i),i=1,nitb)
	write(nb13,*) '-------------------------------------------------'
!
	end if
!
!	new open & close mode
!
	bact=.true.
	do while (iact.gt.0.and.it.ge.ivccv(jitb+iact) &
     &			.and.ivccv(jitb+iact).ne.-999)
		imode=ivccv(jitb+iact+1)
		iact=iact+2
		if( iact .gt. nitb ) then	!no more data
		  if( icycle .gt. 0 ) then	!use old data
		    iact = iact - icycle
                    !if( iact .le. 0 ) iact = 1
		  else				!no more closings
		    iact = 0
		  end if
		end if
!		bact=.false.			!not used (why ?)
	end do
!
!	levels & velocities
!
	istp=istp+1
	zin=xv(3,kin)
	zout=xv(3,kout)
        zref=xv(3,kref)
	zin=znv(kin)
	zout=znv(kout)
        zref=znv(kref)
	!u=xv(1,kref)
	!v=xv(2,kref)
	u=xv(1,kin)    !BUG FIX 27.5.2004
	v=xv(2,kin)
	uvref2=u*u+v*v
!
!	if section is associated to level boundary
!
	!ibndz = 0
	ibtyp = 0
	if(ibndz.gt.0) then
		ibtyp=itybnd(ibndz)
		if(iabs(ibtyp).eq.1) then
			zout=zvbnds(ibndz)
		end if
	end if
!
!	current direction at reference node
!
	!dx=xgv(kdir)-xgv(kref)
	!dy=ygv(kdir)-ygv(kref)
	dx=xgv(kdir)-xgv(kin)  !BUG FIX 27.5.2004
	dy=ygv(kdir)-ygv(kin)
	scal=u*dx+v*dy
!
!	!------------------------------------
	write(nb13,*)
	write(nb13,'(1x,a,7i5)') 'j,iact,imode,istp,iclos :' &
     &				,j,iact,imode,istp,iclos,ibndz,ibtyp
!	write(nb13,'(1x,a,4e12.4)') 'scal,scalo,zin,zout :'
!     +				,scal,scalo,zin,zout
	write(nb13,'(1x,a,2e10.2,6f7.3)') 'extra: ',scal,scalo &
     &				,zref,zout,zin,zdate
	write(nb13,*)
!	!------------------------------------
!
!	decide closing & opening
!
	icltot=imode/100
	ioptot=imode-100*icltot
	icl=icltot
	if(icl.gt.20) icl=icl-20
	iop=ioptot
	if(iop.gt.20) iop=iop-20
!
	bopen=.false.
	bclos=.false.
	bimm=.false.
	if(istp.le.0) then
		if(iclos.eq.0) bclos=.true.
		if(iclos.eq.1) bopen=.true.
	else if(istp.le.mnstp) then	!too few timesteps since
!		nothing			!...last close/open
	else if(iclos.eq.0) then	!inlet is open
		if(icl.eq.0) then
			!nothing
		else if(icl.eq.1) then
			bclos=.true.
		else if(icl.eq.2) then
			if(scal*scalo.lt.0.and.scal.gt.0) then
				bclos=.true.
			end if
		else if(icl.eq.3) then
			if(scal*scalo.lt.0.and.scal.lt.0) then
				bclos=.true.
			end if
		else if(icl.eq.4) then
			if(uvref2.gt.vdate*vdate) then
				bclos=.true.
			end if
		else if(icl.eq.5) then
			if(uvref2.lt.vdate*vdate) then
				bclos=.true.
			end if
		else if(icl.eq.6) then
			if(zout.gt.zdate) then
				bclos=.true.
			end if
		else if(icl.eq.7) then
			if(zout.lt.zdate) then
				bclos=.true.
			end if
		else if(icl.eq.8) then
			if(zin.gt.zdate) then
				bclos=.true.
			end if
		else if(icl.eq.9) then
			if(zin.lt.zdate) then
				bclos=.true.
			end if
		else if(icl.eq.10) then         !FIX 9.12.2003
			!if(zref.gt.zdate) then
			if(zref.gt.zdate.and.scal.gt.0.) then
				bclos=.true.
			end if
		else
			write(6,*) icl
			stop 'error stop sp136: no such code for icl'
		end if
		if(icltot.gt.20) bimm=.true.
	else if(iclos.eq.1) then	!inlet is closed
		if(iop.eq.0) then
			!nothing
		else if(iop.eq.1) then
			bopen=.true.
		else if(iop.eq.2) then
			if(zin.gt.zout) then
				bopen=.true.
			end if
		else if(iop.eq.3) then
			if(zin.lt.zout) then
				bopen=.true.
			end if
		else if(iop.eq.4) then
			if(zin-zout.gt.zdiff) then
				bopen=.true.
			end if
		else if(iop.eq.5) then
			if(zin-zout.lt.zdiff) then
				bopen=.true.
			end if
		else if(iop.eq.6) then
			if(zout.gt.zdate) then
				bopen=.true.
			end if
		else if(iop.eq.7) then
			if(zout.lt.zdate) then
				bopen=.true.
			end if
		else
			write(6,*) iop
			stop 'error stop sp136: no such code for iop'
		end if
		if(ioptot.gt.20) bimm=.true.
	end if
!
	bimm = bimm .or. (isoft.le.0)
	bimm = bimm .or. bchez  !$$3
	bspec = bspecl .and. .not.bopen .and. (iclos.eq.1)
!
	if(bclos.or.bspec) then		!close inlet
	  if(istp.gt.0.and..not.bspec) istp=-isoft
	  if(bimm)  istp=0
	  if(istp.eq.0.or.bimm) iclos=1
          if(istp.eq.-isoft.or.bimm) then	!$$impli
		call get_act_dtime(dtime)
		dtime = dtime + idt*implit
		call setimp(dtime,1.)
	  end if
!
	  if(bspecl.or.bflxcl) then
            if(ibnd.eq.0) goto 87
            do i=2,nkboc
              k1=ivccv(jkboc+i-1)
              k2=ivccv(jkboc+i)
              h1=rvccv(jhboc+i-1)
              h2=rvccv(jhboc+i)
              z1=xv(3,k1)
              z2=xv(3,k2)
              hm=(h1+z1+h2+z2)*0.5
              flux1=rvccv(jflux+i-1)
              flux2=rvccv(jflux+i)
              if(istp.eq.-isoft.or.bimm) then
                dx=xgv(k2)-xgv(k1)
                dy=ygv(k2)-ygv(k1)
                l=sqrt(dx*dx+dy*dy)
                u1=xv(1,k1)
                u2=xv(1,k2)
                v1=xv(2,k1)
                v2=xv(2,k2)
                uv1=(-u1*dy+v1*dx)/l
                uv2=(-u2*dy+v2*dx)/l
                flux1=l*(2.*uv1+uv2)/6.         !RQVDT
                flux2=l*(uv1+2.*uv2)/6.
                rvccv(jflux+i-1)=flux1
                rvccv(jflux+i)=flux2
                volini=volag(2,zdate)
                volmax=volag(0,zdate)
                dvolin=volmax-volini
!               !----------------
!                write(nb13,*) 'vol..ini,max,diff:',volini,volmax,dvolin
!                write(nb13,*) 'u,v,uv1,flux1 ',u1,v1,uv1,flux1
!                write(nb13,*) 'u,v,uv2,flux2 ',u2,v2,uv2,flux2
!               !----------------
              end if
              if(bspecl) then
                volact=volag(2,zdate)
                dvolac=volmax-volact
                geyer=(dvolac/dvolin)**0.5
                write(nb13,*) 'volact,dvolac :',volact,dvolac
              else
!                geyer=-float(istp-1)/float(isoft+1)
                geyer=-float(istp)/float(isoft+1)  !$$1
              end if
!cc              rqv(k1)=rqv(k1)+hm*flux1*geyer
!cc              rqv(k2)=rqv(k2)+hm*flux2*geyer
            end do

            if(istp.eq.-isoft.or.bimm) then
              do i=1,nkboc
                k1=ivccv(jkboc+i)
                fluxnn = -flxnod(k1)    !RQVDT
                rmass=(xv(3,k1)-xv(3,k1+nkn))*areavl(k1)
                rvccv(jflux+i)=fluxnn
                write(nb13,*) 'new  ',j,i,fluxnn,rmass
                rqv(k1)=rqv(k1)+fluxnn
                rzv(k1)=flag
              end do
            else
              geyer=-float(istp-1)/float(isoft+1)
              do i=1,nkboc
                k1=ivccv(jkboc+i)
                fluxnn=rvccv(jflux+i)
                rqv(k1)=rqv(k1)+fluxnn*geyer
                write(nb13,*) 'new  ',j,i,rqv(k1),geyer
              end do
            end if

		else if(bdepcl) then
		  do i=1,niboc
		    ie=ivccv(jiboc+i)
		    do ii=1,3
		      kn=nen3v(ii,ie)
		      do k=1,nkboc
			kboc=ivccv(jkboc+k)
			if(kn.eq.kboc) then
				hboc=rvccv(jhboc+k)
				h=hdry+(hdry-href) &
     &					*float(istp)/float(isoft+1)
				if(istp.ge.0) then
					h=hdry
				else if(h.gt.hboc) then
					h=hboc
				end if
				hm3v(ii,ie)=h
!				!----------------
				write(nb13,*) 'ie,kn,h: ' &
     &					,ipev(ie),ipv(kn),h
!				!----------------
			end if
		      end do
		    end do
		  end do
		end if
!
		if(istp.eq.-isoft.or.bimm) then
			if(iact.gt.0.and.ivccv(jitb+iact).eq.-999 &
     &					.and.bact) then
				imode=ivccv(jitb+iact+1)
				iact=iact+2
				if( iact .gt. nitb ) then   !no more data
				  if( icycle .gt. 0 ) then  !use old data
				    iact = iact - icycle
				  else			    !no more closings
				    iact = 0
				  end if
				end if
				bact=.false.
			end if
!
			if(ibnd.gt.0) then
				ibtyp=itybnd(ibnd)
				if(.not.bchez) then !$$3
				  if(ibtyp.lt.0) goto 85
				  call stybnd(ibnd,-ibtyp)
				end if
			end if
!
			ic=1	!------ compute new uv-matrix
!
			write(6,*) 'inlet ',j,' closed at it = ',it
			write(nb13 ,*) 'inlet ',j,' closed at it = ',it
		end if
	end if
!
        if(bchez.and.iclos.eq.1) then !$$3
            do i=1,niboc
              ie=ivccv(jiboc+i)
              czv(ie)=czcls(j)
            end do
!           !----------------
            write(nb13,*) 'chezy : ' &
     &        ,j,niboc,czv(ie)
!           !----------------
        end if
!
	if(bopen) then		!open inlet
          bimm=.true. !$$1 - always open immediately

	  if(istp.gt.0) istp=-isoft
	  if(bimm)  istp=0
	  if(istp.eq.0.or.bimm) iclos=0
          if(istp.eq.-isoft.or.bimm) then	!$$impli
		daux = it+idt*implit
		call setimp(daux,1.)
	  end if
!
		if(istp.eq.-isoft.or.bimm) then
			if(iact.gt.0.and.ivccv(jitb+iact).eq.-999 &
     &					.and.bact) then
				imode=ivccv(jitb+iact+1)
				iact=iact+2
				if( iact .gt. nitb ) then   !no more data
				  if( icycle .gt. 0 ) then  !use old data
				    iact = iact - icycle
				  else			    !no more closings
				    iact = 0
				  end if
				end if
				bact=.false.
			end if
!
			if(ibnd.gt.0) then
				ibtyp=itybnd(ibnd)
				if(.not.bchez) then  !$$3
				  if(ibtyp.gt.0) goto 84
				  call stybnd(ibnd,-ibtyp)
				end if
			end if
!
			ic=1	!------ compute new uv-matrix
!
			write(6,*) 'inlet ',j,' opened at it = ',it
			write(nb13 ,*) 'inlet ',j,' opened at it = ',it
		end if
	end if
!
	ipccv(ipnt(liclos,j))=iclos
	ipccv(ipnt(listp,j))=istp
	ipccv(ipnt(liact,j))=iact
	ipccv(ipnt(limode,j))=imode
	rpccv(ipnt(lscal,j))=scal
!
	end do
!
	binit=.false.
!
	write(nb13,*) '***********************************'
!
	return
   82	continue
	write(6,*) 'Impossible value for ibnd or ibndz'
	write(6,*) 'ibnd,ibndz,nbc : ',ibnd,ibndz,nbc
	stop 'error stop : sp136'
   84	continue
	write(6,*) 'Wrong type of boundary for opening : ',ibtyp
	stop 'error stop : sp136'
   85	continue
	write(6,*) 'Wrong type of boundary for closing: ',ibtyp
	stop 'error stop : sp136'
   87	continue
	write(6,*) 'For this closing section must be boundary'
	write(6,*) 'iclose, ibnd : ',iclose,ibnd
	stop 'error stop : sp136'
   89	continue
	write(6,*) 'Dimension error for array ivccv'
	write(6,*) 'ivdim : ',ivdim
	stop 'error stop : sp136'
	end

!********************************************************************
!********************************************************************
!********************************************************************
!********************************************************************
!********************************************************************

	subroutine inclos

! initializes closing sections

	use close

	implicit none

	integer i

	do i=1,ipcdim
	  ipccv(i) = 0
	end do

        ipccv(1)=ipcdim         !dimension op ipccv
        ipccv(2)=ivcdim         !dimension of ivccv
        ipccv(3)=lhead          !filling of ipccv
        ipccv(4)=0              !filling of ivccv
        ipccv(5)=lhead          !size of head
        ipccv(6)=lsect          !size of section
        ipccv(7)=0              !number of sections

	end

!********************************************************************

	subroutine rdclos(isc)

! reads closing sections

	use close

	implicit none

	integer isc		!number of actual section to read (in)

	character*6 name
	character*80 text
	real value
	double precision dvalue
	integer nsc
	integer ipdim,ivdim,ipful,ivful
	integer iweich
	integer ival

	integer nrdnxt,iround

!---------------------------------------------------------------
	integer ipnt,id,isect
        ipnt(id,isect) = lhead + lsect*(isect-1) + id
!---------------------------------------------------------------

!	check dimensions and similar

        nsc = ipccv(ipnt(lnsect,0)) + 1
	if(nsc.ne.isc) goto 82
	ipccv(ipnt(lnsect,0)) = nsc

	ipdim = ipccv(ipnt(lipdim,0))
	ivdim = ipccv(ipnt(livdim,0))
	ipful = ipccv(ipnt(lipful,0))
	ivful = ipccv(ipnt(livful,0))

	ipful = ipful+lsect
	if(ipful.gt.ipdim) goto 79
	ipccv(ipnt(lipful,0)) = ipful

!	initialize some of the parameters

        ipccv(ipnt(lmnstp,isc)) = 5
        rpccv(ipnt(lzdate,isc)) = 0.
        rpccv(ipnt(lvdate,isc)) = 0.
        rpccv(ipnt(lzdiff,isc)) = 0.

!	loop for date in str file

        iweich=1
        do while(iweich.ne.0)

            iweich = nrdnxt(name,dvalue,text)
	    value = dvalue
            call to_lower(name)

            if( iweich .eq. 2 ) then
              if( name .ne. 'kboc' .and. name .ne. 'itb' ) goto 93
	    end if

            if( iweich .eq. 1 .or. iweich .eq. 2 ) then

              if( name .eq. 'kboc' ) then
	        ival = iround(value)
	        call insvcl(name,lkboc,lnkboc,isc,iweich,ival)
              else if( name .eq. 'itb' ) then
	        ival = iround(value)
	        call insvcl(name,litb,lnitb,isc,iweich,ival)
	      else if(name.eq.'kref') then
	        ipccv(ipnt(lkref,isc))=iround(value)
	      else if(name.eq.'kdir') then
	        ipccv(ipnt(lkdir,isc))=iround(value)
	      else if(name.eq.'kout') then
	        ipccv(ipnt(lkout,isc))=iround(value)
	      else if(name.eq.'kin') then
	        ipccv(ipnt(lkin,isc))=iround(value)
	      else if(name.eq.'ibndz') then
	        ipccv(ipnt(libndz,isc))=iround(value)
	      else if(name.eq.'ibnd') then
	        ipccv(ipnt(libnd,isc))=iround(value)
	      else if(name.eq.'isoft') then
	        ipccv(ipnt(lisoft,isc))=iround(value)
	      else if(name.eq.'mnstp') then
	        ipccv(ipnt(lmnstp,isc))=iround(value)
	      else if(name.eq.'zdate') then
	        rpccv(ipnt(lzdate,isc))=value
	      else if(name.eq.'vdate') then
	        rpccv(ipnt(lvdate,isc))=value
	      else if(name.eq.'zdiff') then
	        rpccv(ipnt(lzdiff,isc))=value
	      else
		goto 96
	      end if

	    else if( iweich .eq. 0 ) then

!	      nothing

	    else

	      goto 98

            end if

        end do

	return
   79   continue
        write(6,*) 'Dimension error for ipccv'
        write(6,*) 'ipdim : ',ipdim
        stop 'error stop : rdclos'
   82   continue
        write(6,*) 'Closing sections out of order : ',isc
        stop 'error stop : rdclos'
   93   continue
        write(6,*) 'Variable not allowed in this context : ',name
        stop 'error stop : rdclos'
   96   continue
        write(6,*) 'Not recognized variable name : ',name
        stop 'error stop : rdclos'
   98   continue
        write(6,*) 'Read error in closing section : ',isc
        stop 'error stop : rdclos'
	end

!********************************************************************

	subroutine ckclos

! post-processes closing sections

	use close

	implicit none

	logical bstop
	integer nsc,ivdim,ivful
	integer nbc
	integer i,j,k
	integer nkboc,ibnd,nitb
	integer knode,kint
	integer jkboc
	integer ibndz

	integer ipint
!	integer iround
	integer nbnds,nkbnds

!---------------------------------------------------------------
	integer ipnt,id,isect
        ipnt(id,isect) = lhead + lsect*(isect-1) + id
!---------------------------------------------------------------

	bstop = .false.

        nsc=ipccv(ipnt(lnsect,0))
        ivdim=ipccv(ipnt(livdim,0))
        ivful=ipccv(ipnt(livful,0))

	nbc = nbnds()

        do j=1,nsc

           nkboc=ipccv(ipnt(lnkboc,j))
           ibnd=ipccv(ipnt(libnd,j))
           nitb=ipccv(ipnt(lnitb,j))

!	   nodes of boundary

           if(ibnd.gt.0.and.nkboc.gt.0) then
             write(6,'(a,i2,a)') ' section CLOSE ',j,' :'
             write(6,*) '   ibnd and kboc are mutually exclusive'
             bstop=.true.
           else if(ibnd.gt.0) then
             if(ibnd.gt.nbc) then
                write(6,'(a,i2,a)') ' section CLOSE ',j,' :'
                write(6,*) '   ibnd must have value of open boundary'
                write(6,*) '   ibnd : ',ibnd
                bstop=.true.
             else
                jkboc=ivful
                ipccv(ipnt(lkboc,j))=jkboc+1
                nkboc=nkbnds(ibnd)
                ivful=ivful+nkboc
                if(ivful.gt.ivdim) then
                   write(6,*) 'Dimension error for ivccv'
                   write(6,*) 'ivdim : ',ivdim
                   stop 'error stop : nlsh'
                end if
		call irbnds(ibnd,nkboc,k,ivccv(jkboc+1))
                ipccv(ipnt(lnkboc,j))=nkboc
                ipccv(ipnt(livful,0))=ivful
             end if
           else if(nkboc.gt.0.and.ibnd.eq.0) then
             jkboc=ipccv(ipnt(lkboc,j))-1
             do i=1,nkboc
                knode=ivccv(jkboc+i)
                kint=ipint(knode)
                if(knode.le.0) then
                   write(6,'(a,i2,a)') ' section CLOSE ',j,' :'
                   write(6,*) '   node not found ',knode
                   bstop=.true.
                end if
                ivccv(jkboc+i)=kint
             end do
           else
             write(6,'(a,i2,a)') ' section CLOSE ',j,' :'
             write(6,*) '   ibnd = ',ibnd,'   nkboc = ',nkboc
             write(6,*) '   No data read for kboc'
             bstop=.true.
           end if

!	   various other checks

           ibndz=ipccv(ipnt(libndz,j))
           if(ibndz.gt.nbc) then
                write(6,'(a,i2,a)') ' section CLOSE ',j,' :'
                write(6,*) '   ibndz must have value of open boundary'
                write(6,*) '   ibndz : ',ibndz
                bstop=.true.
           end if

           if(nitb.le.0) then
             write(6,'(a,i2,a)') ' section CLOSE ',j,' :'
             write(6,*) '   No data read for itb'
             bstop=.true.
           end if

           if(nitb.ne.(nitb/2)*2) then
             write(6,'(a,i2,a)') ' section CLOSE ',j,' :'
             write(6,*) '   Odd number of data read for itb'
             write(6,*) '   nitb = ',nitb
             bstop=.true.
           end if

	   call convk(lkref,j,bstop)
	   call convk(lkdir,j,bstop)
	   call convk(lkout,j,bstop)
	   call convk(lkin,j,bstop)
        end do

        if(bstop) stop 'error stop : ckclos'

	end

!********************************************************************

	subroutine prclos

! prints info on closing sections

	use close

	implicit none

	integer j,i
	integer nsc,ipful,ivful
	integer nkboc,jkboc,niboc,jiboc,jhboc
	integer nitb,jitb,kout,kin,kref,kdir,isoft
	integer mnstp,iclos,istp,iact,imode
	integer jflux,ibnd,ibndz
	real zdate,vdate,scal,href,zdiff

!---------------------------------------------------------------
	integer ipnt,id,isect
        ipnt(id,isect) = lhead + lsect*(isect-1) + id
!---------------------------------------------------------------

        nsc=ipccv(ipnt(lnsect,0))
        ipful=ipccv(ipnt(lipful,0))
        ivful=ipccv(ipnt(livful,0))

	if( nsc .le. 0 ) return

	write(6,*)
        write(6,*) 'closing sections :'

        write(6,*) '...header :'
        write(6,*) (ipccv(i),i=1,lhead)

        do j=1,nsc

        nkboc=ipccv(ipnt(lnkboc,j))
        jkboc=ipccv(ipnt(lkboc,j))-1
        niboc=ipccv(ipnt(lniboc,j))
        jiboc=ipccv(ipnt(liboc,j))-1
        jhboc=ipccv(ipnt(lhboc,j))-1
        nitb=ipccv(ipnt(lnitb,j))
        jitb=ipccv(ipnt(litb,j))-1
        kout=ipccv(ipnt(lkout,j))
        kin=ipccv(ipnt(lkin,j))
        kref=ipccv(ipnt(lkref,j))
        kdir=ipccv(ipnt(lkdir,j))
        isoft=ipccv(ipnt(lisoft,j))
        zdate=rpccv(ipnt(lzdate,j))
        vdate=rpccv(ipnt(lvdate,j))
        mnstp=ipccv(ipnt(lmnstp,j))
        iclos=ipccv(ipnt(liclos,j))
        istp=ipccv(ipnt(listp,j))
        scal=rpccv(ipnt(lscal,j))
        href=rpccv(ipnt(lhref,j))
        iact=ipccv(ipnt(liact,j))
        imode=ipccv(ipnt(limode,j))
        zdiff=rpccv(ipnt(lzdiff,j))
        jflux=ipccv(ipnt(lflux,j))-1
        ibnd=ipccv(ipnt(libnd,j))
        ibndz=ipccv(ipnt(libndz,j))

        write(6,*)
        write(6,*) 'section :',j
        write(6,*)
        write(6,*) 'nkboc,jkboc,niboc,jiboc :',nkboc,jkboc,niboc,jiboc
        write(6,*) 'jhboc,nitb,jitb :',jhboc,nitb,jitb
        write(6,*) 'kout,kin,kref,kdir :',kout,kin,kref,kdir
        write(6,*) 'isoft,zdate,vdate :',isoft,zdate,vdate
        write(6,*) 'mnstp,iclos,istp :',mnstp,iclos,istp
        write(6,*) 'scal,href,iact,imode :',scal,href,iact,imode
        write(6,*) 'zdiff,jflux,ibnd,ibndz :',zdiff,jflux,ibnd,ibndz

        write(6,*) 'kboc :'
        write(6,*) (ivccv(jkboc+i),i=1,nkboc)
        write(6,*) 'iboc :'
        write(6,*) (ivccv(jiboc+i),i=1,niboc)
        write(6,*) 'hboc :'
        write(6,*) (rvccv(jhboc+i),i=1,nkboc)
        write(6,*) 'flux :'
        write(6,*) (rvccv(jflux+i),i=1,nkboc)
        write(6,*) 'itb :'
        write(6,*) (ivccv(jitb+i),i=1,nitb)

        end do

	end

!********************************************************************

	subroutine tsclos

! tests closing sections

	use close

	implicit none

	integer i
	integer ipful,ivful

!---------------------------------------------------------------
	integer ipnt,id,isect
        ipnt(id,isect) = lhead + lsect*(isect-1) + id
!---------------------------------------------------------------

        write(6,*) '/close/'

        ipful=ipccv(ipnt(lipful,0))
        ivful=ipccv(ipnt(livful,0))

        write(6,*) '...header :'
        write(6,*) (ipccv(i),i=1,lhead)

        write(6,*) '...ipccv,rpccv,ivccv,rvccv :'
        write(6,*) (ipccv(i),i=1,ipful)
        write(6,*) (rpccv(i),i=1,ipful)
        write(6,*) (ivccv(i),i=1,ivful)
        write(6,*) (rvccv(i),i=1,ivful)

	end

!********************************************************************

	subroutine insvcl(name,lip,ltot,isc,iweich,ival)

! inserts vector in data structure of closing sections

	use close

	implicit none

	character*(*) name		!name of parameter
	integer lip			!position of pointer to data
	integer ltot			!position of pointer to data
	integer isc			!number of closing section
	integer iweich			!return value of nrdnxt (1=first call)
	integer ival			!value to insert

	integer ip,itot
	integer ivdim,ivful

!---------------------------------------------------------------
	integer ipnt,id,isect
        ipnt(id,isect) = lhead + lsect*(isect-1) + id
!---------------------------------------------------------------

	ivdim = ipccv(ipnt(livdim,0))
	ivful = ipccv(ipnt(livful,0))

	ip=ipccv(ipnt(lip,isc))-1
	itot=ipccv(ipnt(ltot,isc))

	if( iweich .eq. 1 ) then		!first call
	  if( itot .gt. 0 ) goto 80
	  ip=ivful
	  ipccv(ipnt(lip,isc))=ip+1
	end if

	itot=itot+1
	ivful=ivful+1

	if(ivful.gt.ivdim) goto 78

	ipccv(ipnt(ltot,isc))=itot
	ipccv(ipnt(livful,0))=ivful

	ivccv(ip+itot) = ival

	return
   78   continue
        write(6,*) 'Dimension error for ivccv'
        write(6,*) 'ivdim : ',ivdim
        stop 'error stop : insvcl'
   80   continue
        write(6,*) 'Variable called twice : ',name
        stop 'error stop : insvcl'
	end

!********************************************************************

	subroutine convk(lip,isc,bstop)

! converts node to internal number

	use close

	implicit none

	integer lip			!position of pointer to data (in)
	integer isc			!number of closing section   (in)
	logical bstop			!on error set to .true.      (in/out)

	integer k,kint
	integer ipint

!---------------------------------------------------------------
	integer ipnt,id,isect
        ipnt(id,isect) = lhead + lsect*(isect-1) + id
!---------------------------------------------------------------

        k = ipccv(ipnt(lip,isc))

        if( k .gt. 0 ) then
          kint = ipint(k)
          if( kint .le. 0 ) then
                write(6,'(a,i3,a)') ' section CLOSE ',isc,' :'
                write(6,*) '   node not found ',k
                bstop = .true.
          end if
          ipccv(ipnt(lip,isc)) = kint
        end if

	end

!********************************************************************

        function volag(mode,z)

! determination of water volume in whole basin
!
! uses  either actual level or a fixed level
!
! mode:
!                0       use fixed level z
!               +1       use water level of new time step
!               -1       use water level of old time step
!
! z             fixed water level, to be used with mode = 0
! volag         volume of water in basin (return value)

	use basin, only : nkn,nel,ngr,mbw

        implicit none

        real volag
        integer mode
        real z


        integer ie
        real w,vol,area

        real volele,areaele

        w=0

	if( mode .eq. 0 ) then
	  do ie=1,nel
	    vol = volele(ie,0)
	    area = areaele(ie)
	    vol = vol + area * z
	    vol = max(vol,0.)
	    w = w + vol
	  end do
	else
	  do ie=1,nel
	    vol = volele(ie,mode)
	    vol = max(vol,0.)
	    w = w + vol
	  end do
	end if

        volag=w

        end

!*****************************************************************

	subroutine set_zdate(isc,zdate)

	use close

	implicit none

	integer isc
	real zdate

	integer j
        integer isc_start,isc_end

!---------------------------------------------------------------
        integer ipnt,id,isect
        ipnt(id,isect) = lhead + lsect*(isect-1) + id
!---------------------------------------------------------------

        call make_obc_range(isc,isc_start,isc_end)

	do j=isc_start,isc_end
	    rpccv(ipnt(lzdate,j)) = zdate
	end do

	end

!*****************************************************************

	subroutine get_zdate(isc,zdate)

	use close

	implicit none

	integer isc
	real zdate

        integer isc_start,isc_end

!---------------------------------------------------------------
        integer ipnt,id,isect
        ipnt(id,isect) = lhead + lsect*(isect-1) + id
!---------------------------------------------------------------

        call make_obc_range(isc,isc_start,isc_end)

	zdate = rpccv(ipnt(lzdate,isc_start))

	end

!*****************************************************************

        subroutine make_obc_range(isc,isc_start,isc_end)

	use close

        implicit none

	integer isc
        integer isc_start
        integer isc_end

	integer nsc

!---------------------------------------------------------------
        integer ipnt,id,isect
        ipnt(id,isect) = lhead + lsect*(isect-1) + id
!---------------------------------------------------------------

	nsc=ipccv(ipnt(lnsect,0))

	if( isc .le. 0 ) then
          isc_start = 1
          isc_end = nsc
	else if( isc .le. nsc ) then
          isc_start = isc
          isc_end = isc
        else
	  write(6,*) isc,nsc
	  stop 'error stop make_obc_range: isc out of bounds'
	end if

	end

!*****************************************************************

        subroutine get_new_mode(j,it,iact,imode)

	use close

        implicit none

        integer j,it,iact,imode

        integer icycle
	integer jitb,nitb

!---------------------------------------------------------------
         integer ipnt,id,isect
         ipnt(id,isect) = lhead + lsect*(isect-1) + id
!---------------------------------------------------------------

        nitb=ipccv(ipnt(lnitb,j))
        jitb=ipccv(ipnt(litb,j))-1
        icycle = 4

	do while (              iact .gt. 0 &
     &                  .and.   it .ge. ivccv(jitb+iact) &
     &			.and.   ivccv(jitb+iact) .ne. -999 )

		imode=ivccv(jitb+iact+1)
		iact=iact+2
		if( iact .gt. nitb ) then	!no more data
		  if( icycle .gt. 0 ) then	!use old data
		    iact = iact - icycle
                    !if( iact .le. 0 ) iact = 1
		  else				!no more closings
		    iact = 0
		  end if
		end if
	end do

        end

!*****************************************************************

