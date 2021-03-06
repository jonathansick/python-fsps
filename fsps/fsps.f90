module driver

  use sps_vars; use sps_utils
  implicit none
  save

  !f2py intent(hide) pset
  type(PARAMS) :: pset

  !f2py intent(hide) ocompsp
  type(COMPSPOUT), dimension(ntfull) :: ocompsp

  integer :: is_setup=0

  !f2py intent(hide) has_ssp
  integer, dimension(nz) :: has_ssp=0

contains

  subroutine setup(compute_vega_mags0,redshift_colors0,smooth_velocity0)

    ! Load all the data files/templates into memory.

    implicit none

    integer, intent(in) :: compute_vega_mags0, redshift_colors0, &
         smooth_velocity0
    compute_vega_mags = compute_vega_mags0
    redshift_colors = redshift_colors0
    smooth_velocity = smooth_velocity0
    call sps_setup(-1)
    is_setup = 1

  end subroutine

  subroutine set_ssp_params(imf_type0,imf1,imf2,imf3,vdmc,mdave,dell,&
                            delt,sbss,fbhb,pagb,agb_dust)

    ! Set the parameters that affect the SSP computation.

    implicit none

    integer, intent(in) :: imf_type0
    double precision, intent(in) :: imf1,imf2,imf3,vdmc,mdave,dell,&
                                    delt,sbss,fbhb,pagb,agb_dust

    imf_type=imf_type0
    pset%imf1=imf1
    pset%imf2=imf2
    pset%imf3=imf3
    pset%vdmc=vdmc
    pset%mdave=mdave
    pset%dell=dell
    pset%delt=delt
    pset%sbss=sbss
    pset%fbhb=fbhb
    pset%pagb=pagb
    pset%agb_dust=agb_dust 

    has_ssp(:) = 0

  end subroutine

  subroutine set_csp_params(dust_type0,zmet,sfh,wgp1,wgp2,wgp3,evtype,tau,&
                            const,tage,fburst,tburst,dust1,dust2,&
                            logzsol,zred,pmetals,dust_clumps,frac_nodust,&
                            dust_index,dust_tesc,frac_obrun,uvb,mwr,&
                            redgb,dust1_index,sf_start,sf_trunc,sf_theta,&
                            duste_gamma,duste_umin,duste_qpah,fcstar,&
                            masscut,sigma_smooth,min_wave_smooth,&
                            max_wave_smooth)

    ! Set all the parameters that don't affect the SSP computation.

    implicit none

    integer, intent(in) :: dust_type0,zmet,sfh,wgp1,wgp2,wgp3,evtype
    double precision, intent(in) :: tau,&
                            const,tage,fburst,tburst,dust1,dust2,&
                            logzsol,zred,pmetals,dust_clumps,frac_nodust,&
                            dust_index,dust_tesc,frac_obrun,uvb,mwr,&
                            redgb,dust1_index,sf_start,sf_trunc,sf_theta,&
                            duste_gamma,duste_umin,duste_qpah,fcstar,&
                            masscut,sigma_smooth,min_wave_smooth,&
                            max_wave_smooth

    pset%zmet=zmet
    pset%sfh=sfh
    pset%wgp1=wgp1
    pset%wgp2=wgp2
    pset%wgp3=wgp3
    pset%evtype=evtype

    pset%tau=tau
    pset%const=const
    pset%tage=tage
    pset%fburst=fburst
    pset%tburst=tburst
    pset%dust1=dust1
    pset%dust2=dust2
    pset%logzsol=logzsol
    pset%zred=zred
    pset%pmetals=pmetals
    pset%dust_clumps=dust_clumps
    pset%frac_nodust=frac_nodust
    pset%dust_index=dust_index
    pset%dust_tesc=dust_tesc
    pset%frac_obrun=frac_obrun
    pset%uvb=uvb
    pset%mwr=mwr
    pset%redgb=redgb
    pset%dust1_index=dust1_index
    pset%sf_start=sf_start
    pset%sf_trunc=sf_trunc
    pset%sf_theta=sf_theta
    pset%duste_gamma=duste_gamma
    pset%duste_umin=duste_umin
    pset%duste_qpah=duste_qpah
    pset%fcstar=fcstar
    pset%masscut=masscut
    pset%sigma_smooth=sigma_smooth
    pset%min_wave_smooth=min_wave_smooth
    pset%max_wave_smooth=max_wave_smooth

  end subroutine

  subroutine ssps

    ! Loop over the metallicity grid and compute all the SSPs.

    implicit none
    integer :: zi
    do zi=1,nz
      call ssp(zi)
    enddo

  end subroutine

  subroutine ssp(zi)

    ! Compute a SSP at a single metallicity.

    implicit none
    integer, intent(in) :: zi
    pset%zmet = zi
    call ssp_gen(pset, mass_ssp_zz(zi,:),lbol_ssp_zz(zi,:),&
                 spec_ssp_zz(zi,:,:))
    has_ssp(zi) = 1

  end subroutine

  subroutine compute

    ! Compute the full CSP (and the SSP if it isn't already cached).

    implicit none
    integer :: zmet
    zmet = pset%zmet
    if (has_ssp(zmet) .eq. 0) then
      call ssp(zmet)
    endif
    call compsp(0,1,'',mass_ssp_zz(zmet,:),lbol_ssp_zz(zmet,:),&
                spec_ssp_zz(zmet,:,:),pset,ocompsp)

  end subroutine

  subroutine get_spec(ns,n_age,spec_out)

    ! Get the grid of spectra for the computed CSP at all ages.

    implicit none
    integer :: i
    integer, intent(in) :: ns,n_age
    double precision, dimension(n_age,ns), intent(out) :: spec_out
    do i=1,n_age
      spec_out(i,:) = ocompsp(i)%spec
    enddo

  end subroutine

  subroutine get_mags(n_age,n_bands,z_red,mc,mags)

    ! Get the photometric magnitudes in all the recognized bands.
    implicit none
    integer :: i
    integer, intent(in) :: n_age, n_bands
    double precision, intent(in) :: z_red
    integer, dimension(n_bands), intent(in) :: mc
    double precision, dimension(n_age,n_bands), intent(out) :: mags
    do i=1,n_age
      call getmags(z_red,ocompsp(i)%spec,mags(i,:),mc)
    enddo

  end subroutine

  subroutine get_setup_vars(cvms, rcolors, svel)

    implicit none
    integer, intent(out) :: cvms, rcolors, svel
    cvms = compute_vega_mags
    rcolors = redshift_colors
    svel = smooth_velocity

  end subroutine

  subroutine get_nz(n_z)

    ! Get the number of metallicity bins (hard coded in sps_vars).
    implicit none
    integer, intent(out) :: n_z
    n_z = nz

  end subroutine

  subroutine get_ntfull(n_age)

    ! Get the total number of time steps (hard coded in sps_vars).
    implicit none
    integer, intent(out) :: n_age
    n_age = ntfull

  end subroutine

  subroutine get_nspec(ns)

    ! Get the number of wavelength bins in the spectra (hard coded in
    ! sps_vars).
    implicit none
    integer, intent(out) :: ns
    ns = nspec

  end subroutine

  subroutine get_nbands(nb)

    ! Get the number of known filters (hard coded in sps_vars).
    implicit none
    integer, intent(out) :: nb
    nb = nbands

  end subroutine

  subroutine get_lambda(ns,lambda)

    ! Get the grid of wavelength bins.
    implicit none
    integer, intent(in) :: ns
    double precision, dimension(ns), intent(out) :: lambda
    lambda = spec_lambda

  end subroutine

  subroutine get_isochrone_dimensions(n_age,n_mass)

    implicit none

    ! Get the dimensions of the produced isochrones.
    integer, intent(out) :: n_age,n_mass
    n_age = nt
    n_mass = n_mass

  end subroutine

  subroutine get_nmass_isochrone(zz, tt, nmass)

    implicit none

    ! Get the number of masses included in a specific isochrone.
    integer, intent(in) :: zz,tt
    integer, intent(out) :: nmass
    nmass = nmass_isoc(zz,tt)

  end subroutine

  subroutine get_stats(n_age,age,mass_csp,lbol_csp,sfr,mdust)

    implicit none

    ! Get some stats about the computed SP.
    integer :: i
    integer, intent(in) :: n_age
    double precision, dimension(n_age), intent(out) :: age,mass_csp,&
                                                       lbol_csp,sfr,mdust

    do i=1,n_age
      age(i)      = ocompsp(i)%age
      mass_csp(i) = ocompsp(i)%mass_csp
      lbol_csp(i) = ocompsp(i)%lbol_csp
      sfr(i)      = ocompsp(i)%sfr
      mdust(i)    = ocompsp(i)%mdust
    enddo

  end subroutine

  subroutine get_isochrone(zz,tt,n_mass,n_mags,time_out,z_out,&
                           mass_init_out,logl_out,logt_out,logg_out,&
                           ffco_out,phase_out,wght_out,mags_out)

    implicit none

    integer, intent(in) :: zz,tt,n_mass,n_mags
    double precision, intent(out) :: time_out, z_out
    double precision, dimension(n_mass), intent(out) :: mass_init_out
    double precision, dimension(n_mass), intent(out) :: logl_out
    double precision, dimension(n_mass), intent(out) :: logt_out
    double precision, dimension(n_mass), intent(out) :: logg_out
    double precision, dimension(n_mass), intent(out) :: ffco_out
    double precision, dimension(n_mass), intent(out) :: phase_out
    double precision, dimension(n_mass), intent(out) :: wght_out
    double precision, dimension(n_mass, n_mags), intent(out) :: mags_out
    integer :: i
    double precision, dimension(nm) :: wght
    double precision, dimension(nspec)  :: spec
    double precision, dimension(nbands) :: mags

    call imf_weight(mini_isoc(zz,tt,:), wght, nmass_isoc(zz,tt))
    do i = 1, nmass_isoc(zz,tt)
    ! Compute mags on isochrone at this mass
    call getspec(pset, mact_isoc(zz,tt,i), &
      logt_isoc(zz,tt,i), 10**logl_isoc(zz,tt,i), logg_isoc(zz,tt,i), &
      phase_isoc(zz,tt,i), ffco_isoc(zz,tt,i), spec)
    call getmags(0.d0, spec, mags)
    mass_init_out(i) = mini_isoc(zz,tt,i)
    logl_out(i) = logl_isoc(zz,tt,i)
    logt_out(i) = logt_isoc(zz,tt,i)
    logg_out(i) = logg_isoc(zz,tt,i)
    ffco_out(i) = ffco_isoc(zz,tt,i)
    phase_out(i) = phase_isoc(zz,tt,i)
    wght_out(i) = wght(i)
    mags_out(i,:) = mags(:)
    end do

    ! Fill in time and metallicity of this isochrone
    time_out = timestep_isoc(zz, tt)
    z_out = log10(zlegend(zz) / 0.0190) ! log(Z/Zsolar)

  end subroutine

end module
