!> ####################################################################
!! **Module**  : surface_physics \n
!! **Author**  : Mario Krapp \n 
!! **Purpose** : This module contains all functionality and subroutines 
!!               for the snow/ice energy and mass balance.
!! ####################################################################
module surface_physics

    implicit none 
     
    ! define precision (machine specific)
    integer, parameter:: dp=kind(0.d0)
    
    ! constansts used throughout this module
    double precision, parameter :: pi   = 3.141592653589793238462643_dp
    double precision, parameter :: t0   = 273.15_dp  !< melting point [K]
    double precision, parameter :: sigm = 5.67e-8_dp !< Stefan-Boltzmann constant [W/(m2 K4)]
    double precision, parameter :: eps  = 0.62197_dp !< ratio of the molar weight of water vapor
                                                     !! to the molar weight of dry air
    double precision, parameter :: cls  = 2.83e6_dp  !< latent heat of sublimation [J/kg]
    double precision, parameter :: clm  = 3.30e5_dp  !< latent heat of melting [J/kg]
    double precision, parameter :: clv  = 2.5e6_dp   !< latent heat of condensation [J/kg]
    double precision, parameter :: cap  = 1000.0_dp  !< specific heat capacitiy of air [J/(kg K)]
    double precision, parameter :: rhow = 1000.0_dp  !< density of water [kg/m3]
    double precision, parameter :: hsmax= 5.0_dp     !< maximum snow height [m]


    ! Define all parameters needed for the surface module
    type surface_param_class
        character (len=256) :: name, boundary(30), alb_scheme
        integer             :: nx        !< number of grid points
        integer             :: n_ksub    !< number of sub-daily time steps
        double precision    :: ceff      !< surface specific heat capacity of snow/ice [J/Km2]
        double precision    :: albr      !< background albedo (bare ice) [no unit]
        double precision    :: albl      !< background albedo (bare land) [no unit]
        double precision    :: alb_smax  !< maximum snow albedo (fresh snow) [no unit]
        double precision    :: alb_smin  !< minimum snow albedo (old, wet snow) [no unit]
        double precision    :: hcrit     !< critical snow height for which grid cell is 50%snow covered [m]
        double precision    :: rcrit     !< critical snow height for which refreezing fraction is 50% [m]
        double precision    :: amp       !< Amplitude of diurnal cycle [K]
        double precision    :: csh       !< sensible heat exchange coefficient [no unit]
        double precision    :: clh       !< latent heat exchange coefficient [no unit]
        double precision    :: tmin      !< minimum temperature for which albedo decline becomes effective ("slater") [K]
        double precision    :: tmax      !< maximum temperature for which albedo decline becomes effective ("slater") [K]
        double precision    :: tstic     !< time step [s]
        double precision    :: tsticsub  !< sub-time step [s]
        double precision    :: shf_enh   !< sensible heat flux enhancement factor for positive u*(tsurf-t2m) [no unit]
        double precision    :: lhf_enh   !< latent heat flux enhancement factor over land (mask==1) [no unit]
        double precision    :: tau_a     !< dry albedo decline for "isba" albedo scheme [1/day]
        double precision    :: tau_f     !< wet albedo decline for "isba" albedo scheme [1/day]
        double precision    :: w_crit    !< critical liquid water content for "isba" albedo scheme [kg/m2]
        double precision    :: mcrit     !< critical melt rate for "isba" and "denby" albedo scheme [m/s]
        double precision    :: afac      !< param [no unit]
        double precision    :: tmid      !< param for "alex" albedo parametrization [K]
    end type

    type surface_state_class
        ! Model variables
        double precision, allocatable, dimension(:) :: t2m         !< 2m air temperature [K]
        double precision, allocatable, dimension(:) :: tsurf       !< surface temperature [K]
        double precision, allocatable, dimension(:) :: hsnow       !< snow pack height (water equivalent) [m]
        double precision, allocatable, dimension(:) :: hice        !< ice thickness (water equivalent) [m]
        double precision, allocatable, dimension(:) :: alb         !< grid-averaged albedo [no unit]
        double precision, allocatable, dimension(:) :: alb_snow    !< snow albedo [no unit]
        double precision, allocatable, dimension(:) :: melt        !< potential surface melt [m/s]
        double precision, allocatable, dimension(:) :: melted_snow !< actual melted snow [m/s]
        double precision, allocatable, dimension(:) :: melted_ice  !< actual melted ice [m/s]
        double precision, allocatable, dimension(:) :: refr     !< refreezing [m/s]
        double precision, allocatable, dimension(:) :: smb      !< surface mass balance [m/s]
        double precision, allocatable, dimension(:) :: acc      !< surface accumulation [m/s]
        double precision, allocatable, dimension(:) :: lhf      !< latent heat flux [W/m2]
        double precision, allocatable, dimension(:) :: shf      !< sensible heat flux [W/m2]
        double precision, allocatable, dimension(:) :: lwu      !< upwelling longwave radiation [W/m2]
        double precision, allocatable, dimension(:) :: subl     !< sublimation [??]
        double precision, allocatable, dimension(:) :: evap     !< evaporation [??]
        double precision, allocatable, dimension(:) :: smb_snow !< surface mass balance of snow [m/s]
        double precision, allocatable, dimension(:) :: smb_ice  !< surface mass balance of ice [m/s]
        double precision, allocatable, dimension(:) :: runoff   !< potential surface runoff [m/s]
        ! Forcing variables
        double precision, allocatable, dimension(:) :: sf       !< snow fall [m/s]
        double precision, allocatable, dimension(:) :: rf       !< rain fall [m/s]
        double precision, allocatable, dimension(:) :: sp       !< surface pressure [Pa]
        double precision, allocatable, dimension(:) :: lwd      !< downwelling longwave radiation [W/m2]
        double precision, allocatable, dimension(:) :: swd      !< downwelling shortwave radiation [W/m2]
        double precision, allocatable, dimension(:) :: wind     !< surface wind speed [m/s]
        double precision, allocatable, dimension(:) :: rhoa     !< air density [kg/m3]
        double precision, allocatable, dimension(:) :: qq       !< air specific humidity [kg/kg]
        integer,          allocatable, dimension(:) :: mask     !< ocean/land/ice mask [0/1/2]
    end type

    type boundary_opt_class 
        logical :: t2m, tsurf, hsnow, alb, melt, refr, smb, acc, lhf, shf, subl
    end type

    type surface_physics_class

        type(surface_param_class) :: par        ! physical parameters
        type(boundary_opt_class)  :: bnd, bnd0  ! boundary switches (bnd0 for equilibration)

        ! Daily variables, month and annual averages, forcing variables
        type(surface_state_class) :: now, mon, ann 

    end type

    private
    public :: mass_balance, energy_balance, surface_energy_and_mass_balance
    public :: surface_physics_class, surface_state_class, surface_param_class
    public :: surface_physics_par_load, surface_alloc, surface_dealloc
    public :: surface_boundary_define, surface_physics_average
    public :: print_param, print_boundary_opt

    public :: sigm, cap, eps, cls, clv  
    public :: longwave_upward, latent_heat_flux, sensible_heat_flux 

contains

    subroutine surface_energy_and_mass_balance(now,par,bnd,day,year)
        type(surface_state_class), intent(in out) :: now
        type(boundary_opt_class),  intent(in)     :: bnd
        type(surface_param_class), intent(in)     :: par

        integer, intent(in) :: day, year
        
        integer :: ksub

        ! quasi-relaxation loop for energy and mass balance (without hsnow update)
        do ksub = 1, par%n_ksub
            call energy_balance(now,par,bnd,day,year)
        end do
        call mass_balance(now,par,bnd,day,year)
    end subroutine

    subroutine energy_balance(now,par,bnd,day,year)
        type(surface_state_class), intent(in out) :: now
        type(boundary_opt_class),  intent(in)     :: bnd
        type(surface_param_class), intent(in)     :: par

        integer, intent(in) :: day, year

        ! auxillary variables
        double precision, dimension(par%nx) :: qsb, qmr

        ! bulk formulation of sensible heat flux (W/m^2)
        if (.not. bnd%shf) then
            now%shf = 0.0_dp
            call sensible_heat_flux(now%tsurf, now%t2m, now%wind, now%rhoa, par%csh, par%shf_enh, cap, now%shf)
        end if

        ! bulk formulation of latent heat flux (W/m^2), only accounts for sublimation/deposition,
        ! not for evaporation/condensation (would require estimate of liquid water content)
        if (.not. bnd%lhf) then  
            now%subl = 0.0_dp
            now%evap = 0.0_dp
            now%lhf  = 0.0_dp
            call latent_heat_flux(now%tsurf, now%wind, now%qq, now%sp, now%rhoa, now%mask, &
                                  par%clh, par%lhf_enh, eps, cls, clv, now%lhf, now%subl, now%evap)
        end if

        ! outgoing long-wave flux following Stefan-Boltzmann's law (W/m^2)
        now%lwu = 0.0_dp
        call longwave_upward(now%tsurf,sigm,now%lwu)

        ! residual energy from melting and refreezing
        qmr = 0.0_dp
        where (now%mask == 2)         ! ice
            qmr = (now%melted_snow + now%melted_ice - now%refr)*rhow*clm
        elsewhere                               ! land and sea
            qmr = (now%melted_snow - now%refr)*rhow*clm
        end where

        ! surface energy balance of incoming and outgoing surface fluxes (W/m^2)
        qsb  = (1.0_dp-now%alb)*now%swd + now%lwd - now%lwu - now%shf - now%lhf - qmr

        ! update surface temperature according to surface energy balance
        if (.not. bnd%tsurf) then
            now%tsurf = now%tsurf + qsb*par%tsticsub/par%ceff 
        end if
        now%t2m   = now%t2m + (now%shf+now%lhf)*par%tsticsub/par%ceff  

    end subroutine

    !! **Subroutine**  : surface_mass_balance \n
    !! **Author**  : Mario Krapp \n 
    !! **Purpose** : Main routine to calculate
    !!                * surface mass balance (m/s)
    !!                * surface (snow/ice) albedo
    !!                * snow height (m)
    !!               based on surface energy and mass balance.
    !!               Forced by atmospheric fields of
    !!                * air temperature
    !!                * surface wind speed
    !!                * air humidity
    !!                * snow fall
    !!                * rain fall
    !!                * surface pressure
    !!                * air density
    !!                * longwave radiation
    !!                * shortwave radiation
    !!
    !! ####################################################################
    subroutine mass_balance(now,par,bnd,day,year)

        type(surface_state_class), intent(in out) :: now
        type(boundary_opt_class),  intent(in)     :: bnd
        type(surface_param_class), intent(in)     :: par

        integer, intent(in) :: day, year
        
        ! auxillary variables
        double precision, dimension(par%nx) :: qmelt, qcold, &
            below, above, f_rz, f_alb, refrozen_rain, refrozen_snow, snow_to_ice 

        ! Calculate above-/below-freezing temperatures for a given mean temperature
        call diurnal_cycle(par%amp,now%tsurf-t0,above,below)

        where (now%mask >= 1)
            ! melt energy where temperature exceeds freezing (difference to heat at freezing)
            qmelt = dmax1(0.0_dp,(above)*par%ceff/par%tsticsub)
            ! watch the sign
            qcold = dmax1(0.0_dp,abs(below)*par%ceff/par%tsticsub)
        else where
            qmelt = 0.0_dp
            qcold = 0.0_dp
        end where

        ! reset surface temperature if necessary (update of temperature at the end)
        !where(tsurf_new > t0) tsurf_new = t0

        ! 1) ablation: melt (m/s); potential melt resulting from available melt energy
        if (.not. bnd%melt) then
            ! potential melt
            now%melt = qmelt/(rhow*clm)
            ! separate potential melt into actual melt of snow and ice
            now%melted_snow = dmin1(now%melt,now%hsnow/par%tsticsub)
            now%melted_ice  = now%melt-now%melted_snow

            ! actual melt is sum of melted snow and ice (melted snow over land)
            where (now%mask == 2)
                now%melt = now%melted_snow + now%melted_ice
            elsewhere
                now%melt = now%melted_snow
            end where
        end if


        ! 2) refreezing
        ! refreezing as fraction of melt (increases with snow height)
        f_rz = now%hsnow/(now%hsnow+par%rcrit)
        if (.not. bnd%refr) then
            !f_rz = (1._dp-dexp(-now%hsnow))
            ! potential refreezing
            now%refr = qcold/(rhow*clm)
            refrozen_rain = dmin1(now%refr,now%rf)
            ! potential refeezing snow
            refrozen_snow = dmax1(now%refr-refrozen_rain,0.0_dp)
            ! actual refreezing snow
            refrozen_snow = dmin1(refrozen_snow,now%melted_snow)
            ! actual refreezing
            refrozen_rain =  f_rz*refrozen_rain
            refrozen_snow =  f_rz*refrozen_snow
            now%refr = refrozen_rain + refrozen_snow
        end if 

        ! 3) potential runoff
        now%runoff = 0.0_dp
        now%runoff = now%melt + now%rf - refrozen_rain

        ! 4) accumulation: sum of all incoming solid water (just diagnostic, here)
        if (.not. bnd%acc) then
            now%acc = now%sf - now%subl/rhow + now%refr
        end if
        
        ! 5) surface mass balance
        now%smb_snow = now%sf - now%subl/rhow - now%melted_snow

        where (now%mask == 0)
            now%hsnow = 0.0_dp
        else where
            ! update snow height
            now%hsnow = dmax1(0.0_dp, now%hsnow + now%smb_snow*par%tsticsub)
        end where
        
        ! Relax snow height to maximum (eg, 5 m)
        snow_to_ice   = dmax1(0.d0,now%hsnow-hsmax)
        now%hsnow   = now%hsnow - snow_to_ice
        now%smb_ice = snow_to_ice/par%tsticsub - now%melted_ice + now%refr   ! Use to force ice sheet model
        now%hice    = now%hice + now%smb_ice*par%tsticsub ! update new ice budget: remove or add ice

        if (.not. bnd%smb) then
            where (now%mask == 2)
                now%smb = now%smb_snow + now%smb_ice - snow_to_ice/par%tsticsub
            elsewhere
                now%smb = now%smb_snow + dmax1(0.0_dp,now%smb_ice - snow_to_ice/par%tsticsub)
            end where
        end if

        ! Update snow albedo
        f_alb = now%hsnow/(now%hsnow+par%hcrit)
        if (.not. bnd%alb) then 
            if (trim(par%alb_scheme) .eq. "slater") then
                call albedo_slater(now%alb_snow,now%tsurf,par%tmin,par%tmax,par%alb_smax,par%alb_smin)
            end if
            if (trim(par%alb_scheme) .eq. "denby") then
                call albedo_denby(now%alb_snow,now%melt,par%alb_smax,par%alb_smin,par%mcrit)
            end if
            if (trim(par%alb_scheme) .eq. "isba") then
                call albedo_isba(now%alb_snow,now%sf,now%melt,par%tsticsub,par%tstic,par%tau_a,par%tau_f,&
                                 par%w_crit,par%mcrit,par%alb_smin,par%alb_smax)
            end if
            where (now%mask == 2)
                now%alb = par%albr + f_alb*(now%alb_snow - par%albr)
            end where
            where (now%mask == 1)
                now%alb = par%albl + f_alb*(now%alb_snow - par%albl)
            end where
            where (now%mask == 0)
                now%alb = 0.06_dp
            end where
            
            if (trim(par%alb_scheme) .eq. "alex") then
                now%alb_snow = par%alb_smin + (par%alb_smax - par%alb_smin)*(0.5_dp*tanh(par%afac*(now%t2m-par%tmid))+0.5_dp) 
                now%alb      = now%alb_snow 
            end if

        end if
        
        !now%t2m = t2m_new 
        ! add remainder of melted snow/ice and refreezing to surface temperature
        !where (now%mask == 2)         ! ice
        !    now%tsurf = now%tsurf  - (now%melted_snow + now%melted_ice - now%refr)*par%tsticsub*rhow*clm/par%ceff
        !elsewhere                     ! land and sea
        !    now%tsurf = now%tsurf - (now%melted_snow - now%refr)*par%tsticsub*rhow*clm/par%ceff
        !end where

        ! write prognostic and diagnostic output
        now%subl = now%subl/rhow

    end subroutine

    elemental subroutine sensible_heat_flux(ts,ta,wind,rhoa,csh,enh,cap,shf)
        double precision, intent(in) :: ts, ta, wind, rhoa
        double precision, intent(in) :: csh, cap, enh
        double precision, intent(out) :: shf
        double precision :: coeff

        ! enhancement over land
        if ( wind*(ts-ta) > 0.0_dp ) then
            coeff = enh*csh
        else
            coeff = csh
        end if
        
        shf = coeff*cap*rhoa*wind*(ts-ta)
    end subroutine

    elemental subroutine latent_heat_flux(ts, wind, shum, sp, rhoatm, mask, clh, enh, eps, cls, clv, lhf, subl, evap)
        double precision, intent(in)  :: ts, shum, sp, rhoatm, wind
        double precision, intent(in)  :: clh, eps, cls, clv, enh
        integer, intent(in)  :: mask
        double precision, intent(out) :: lhf, subl, evap
        double precision :: esat_sur, shum_sat, coeff

        subl = 0.0_dp
        evap = 0.0_dp
        lhf  = 0.0_dp
        esat_sur = 0.0_dp
        shum_sat = 0.0_dp
        coeff = 0.0_dp
        if (mask == 1) then
            coeff = enh*clh
        else
            coeff = clh
        end if
        if (ts < t0) then
            esat_sur = ei_sat(ts)
            ! specific humidity at surface (assumed to be saturated) is
            shum_sat = esat_sur*eps/(esat_sur*(eps-1.0_dp)+sp)
            ! sublimation/deposition depends on air specific humidity
            subl = coeff*wind*rhoatm*(shum_sat-shum)
            lhf = subl*cls
        else
            esat_sur = ew_sat(ts)
            ! evaporation/condensation
            ! specific humidity at surface (assumed to be saturated) is
            shum_sat = esat_sur*eps/(esat_sur*(eps-1.0_dp)+sp)
            evap = coeff*wind*rhoatm*(shum_sat-shum)
            lhf = evap*clv
        end if
    end subroutine

    elemental subroutine longwave_upward(ts,sigma,lwout)
        double precision, intent(in) :: ts, sigma
        double precision, intent(out) :: lwout
        lwout = sigma*ts*ts*ts*ts
    end subroutine

    elemental subroutine diurnal_cycle(amp,tmean,above,below)
        ! Calculate analytical expression for above-/below-freezing
        ! temperatures for a given mean temperature.
        ! Diurnal cycle amplitude can be either fixed (recommended)
        ! or decrease with surface temperature/pressure (name list)

        double precision, intent(in) :: tmean
        double precision, intent(in) :: amp
        double precision, intent(out) :: above, below
        double precision :: tmp1, tmp2

        tmp1 = 0.0_dp
        tmp2 = 0.0_dp
        if (abs(tmean/amp) < 1.0_dp) then
            tmp1 = dacos(tmean/amp)
            tmp2 = dsqrt(1.0_dp-tmean**2.0_dp/amp**2.0_dp)
        end if

        if (tmean+amp<0.0_dp) then
            below = tmean
            above = 0.0_dp
        else
            above = tmean
            below = 0.0_dp
            if (abs(tmean) < amp) then
                ! dt = 2.*x1
                above = (-tmean*tmp1+amp*tmp2+pi*tmean)/(pi-tmp1)
                ! dt = x2 - x1
                below = (tmean*tmp1-amp*tmp2)/tmp1
            end if
        end if
    end subroutine diurnal_cycle

    elemental subroutine albedo_isba(alb,sf,melt,tstic,tau,tau_a,tau_f,w_crn,mcrit,alb_smin,alb_smax)

        double precision, intent(in out) :: alb
        double precision, intent(in) :: sf, melt
        double precision, intent(in) :: tstic, tau, tau_a, tau_f, alb_smin, alb_smax, w_crn, mcrit
        double precision :: alb_dry, alb_wet, alb_new
        double precision :: w_alb
        ! where no melting occurs, albedo decreases linearly
        alb_dry = alb - tau_a*tstic/tau
        !where melting occurs, albedo decreases exponentially
        alb_wet = (alb - alb_smin)*exp(-tau_f*tstic/tau) + alb_smin
        alb_new = sf*tstic/(w_crn/rhow)*(alb_smax-alb_smin)

        ! dry/wet-averaged albedo
        w_alb = 0.0_dp
        if (melt > 0.0_dp) w_alb = 1.0_dp-melt/mcrit
        w_alb = dmin1(1.0_dp,dmax1(w_alb,0.0_dp))
        alb = (1.0_dp-w_alb)*alb_dry + w_alb*alb_wet + alb_new
        ! snow albedo is between min and max value: albmax > alb > albmin
        alb = dmin1(alb_smax,dmax1(alb,alb_smin))
    end subroutine albedo_isba


    elemental subroutine albedo_slater(alb, tsurf, tmin, tmax, alb_smax, alb_smin)
        ! Snow/ice albedo formulation based on Slater et. al., 1998
        ! Added and exponential dependence on snow height: if snow
        ! becomes thicker it is less perceptive to temperature induced
        ! albedo changes.

        double precision, intent(out)    :: alb
        double precision, intent(in)     :: tsurf
        double precision, intent(in)     :: tmin, tmax, alb_smax, alb_smin
        double precision                 :: tm
        double precision                 :: f

        tm  = 0.0_dp
        ! flexible factor ensures continuous polynomial
        f = 1.0_dp/(t0-tmin)
        if (tsurf >= tmin .and. tsurf < tmax) then
            tm = f*(tsurf - tmin)
        end if
        if (tsurf > t0) then
            tm = 1.0_dp
        end if
        ! In contrast to the formulation in their paper, I summed up alpha_nir
        ! and alpha_nir immediately (fewer parameters: alb_smax and alb_smin).
        alb = alb_smax - (alb_smax - alb_smin)*tm**3.0_dp
        ! snow cover fraction and gridpoint-averaged albedo
        !sfrac = tanh(hsnow/hcrit)
        !alb = albr*(1.-sfrac) + alb*sfrac
        !alb = albr + hsnow/(hsnow + hcrit)*(alb - albr)
        ! write albedo to domain object 'now'
    end subroutine albedo_slater

    elemental subroutine albedo_denby(alb,melt,alb_smax, alb_smin, mcrit)
        double precision, intent(out) :: alb
        double precision, intent(in) :: melt
        double precision, intent(in) :: alb_smax, alb_smin, mcrit
        alb = alb_smin + (alb_smax - alb_smin)*dexp(-melt/mcrit)
    end subroutine albedo_denby

    ! ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    ! Subroutine : a l b e d o _ r e m b o
    ! Author     : Alex Robinson, modified by M. Krapp
    ! Purpose    : Determine the current surface
    ! ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    elemental subroutine albedo_rembo(as, hsnow, albr,alb_smin,alb_smax, melt_in)
      
      implicit none
      
      double precision, intent(in out)       :: as
      double precision, intent(in)           :: hsnow
      double precision, intent(in)           :: albr, alb_smax, alb_smin
      double precision, intent(in), optional :: melt_in
      double precision :: as_snow, as_ground, depth, as_snow_planet
      double precision :: hsnow_critical, melt
      
      ! Determine the critical snow height based on number of PDDs,
      ! which correspond to vegetation growth
      ! 0-100 PDDs    = desert, 10mm
      ! 100-1000 PDDs = tundra (grass), linearly increasing between 10mm => 100mm
      hsnow_critical = 0.1_dp ! 10 mm
      
      ! Determine the scaled snowdepth
      depth = hsnow / hsnow_critical
      
      ! Determine the amount of melt to affect abledo calculation.
      ! Default is high melt everywhere, so that jump in albedo is avoided
      ! at onset of melt season.
      ! After calculating actual melt, this is included as an argument and
      ! albedo is recalculated.
      melt = 1.e-3_dp + 1.e-3_dp
      if ( present(melt_in) ) melt = melt_in
      
      ! Figure out what the surface albedo would be with no snow, 
      ! based on the type of ground underneath ( ice or land )
      as_ground = albr
      
      ! Determine current snow albedo: if melt gt eg, 1mm/day, then change albedo to melting snow!
      as_snow = alb_smax
      if (melt .gt. 1.e-3_dp) as_snow = alb_smin
      
      ! Determine snow albedo for use with REMBO (to get planetary albedo)
      ! Where PDDs > 1d3, forest snow
      as_snow_planet = as_snow

      ! First, calculate surface albedo to use for REMBO, 
      ! which is not necessarily identical to snow albedo
      ! minimum albedo is that of bare ground
      as = min(as_ground + depth*(as_snow_planet-as_ground), as_snow_planet)
      
      ! Get current surface albedo to be used for ITM melt scheme
      ! It will either be the maximum albedo (that of dry snow: as_snow)
      ! or the wet snow albedo plus a fraction depending on height of snow
      ! minimum albedo now should be that of wet snow minimum
      as = min(albr + depth*(as_snow-albr), as_snow)
      
      return
      
    end subroutine albedo_rembo

    elemental function ew_sat(t) result(fsat)

        double precision, intent(in) :: t
        double precision :: fsat
        fsat = 611.2_dp*dexp(17.62_dp*(t-t0)/(243.12_dp+t-t0))
    end function ew_sat

    elemental function ei_sat(t) result(fsat)

        double precision, intent(in) :: t
        double precision :: fsat
        fsat = 611.2_dp*dexp(22.46_dp*(t-t0)/(272.62_dp+t-t0))
    end function ei_sat


    !! Data management subroutines 

    subroutine surface_physics_average(ave,now,step,nt)
        implicit none 

        type(surface_state_class), intent(INOUT) :: ave
        type(surface_state_class), intent(IN)    :: now 
        character(len=*)  :: step
        double precision, optional :: nt 
        
        call field_average(ave%t2m,     now%t2m,  step,nt)
        call field_average(ave%tsurf,   now%tsurf,step,nt)
        call field_average(ave%hsnow,   now%hsnow,step,nt)
        call field_average(ave%alb,     now%alb,  step,nt)
        call field_average(ave%melt,    now%melt, step,nt)
        call field_average(ave%refr,    now%refr, step,nt)
        call field_average(ave%smb,     now%smb,  step,nt)
        call field_average(ave%acc,     now%acc,  step,nt)
        call field_average(ave%lhf,     now%lhf,  step,nt)
        call field_average(ave%shf,     now%shf,  step,nt)
        call field_average(ave%lwu,     now%lwu,  step,nt)

        call field_average(ave%sf,      now%sf,   step,nt)
        call field_average(ave%rf,      now%rf,   step,nt)
        call field_average(ave%sp,      now%sp,   step,nt)
        call field_average(ave%lwd,     now%lwd,  step,nt)
        call field_average(ave%swd,     now%swd,  step,nt)
        call field_average(ave%wind,    now%wind, step,nt)
        call field_average(ave%rhoa,    now%rhoa, step,nt)
        call field_average(ave%qq,      now%qq,   step,nt)

        return

    end subroutine surface_physics_average

    subroutine field_average(ave,now,step,nt)
        ! Generic routine to average a field through time 

        implicit none 
        double precision, intent(INOUT) :: ave(:)
        double precision, intent(IN)    :: now(:) 
        character(len=*)  :: step
        double precision, optional :: nt 

        if (trim(step) .eq. "init") then
            ! Initialize field to zero  
            ave = 0.0_dp 
        else if (trim(step) .eq. "step") then 
            ! Sum intermediate steps
            ave = ave + now 
        else if (trim(step) .eq. "end") then
            if (.not.  present(nt)) then 
                write(*,*) "Averaging step total not provided."
                stop 
            end if 
            ! Divide by total steps
            ave = ave / nt 
        else
            write(*,*) "Step not recognized: ",trim(step)
            stop 
        end if 

        return 

    end subroutine field_average 
 


    subroutine surface_alloc(now,npts)

        implicit none 

        type(surface_state_class) :: now 
        integer :: npts 

        allocate(now%t2m(npts))
        allocate(now%tsurf(npts))
        allocate(now%hsnow(npts))
        allocate(now%hice(npts))
        allocate(now%alb(npts))
        allocate(now%alb_snow(npts))
        allocate(now%melt(npts))
        allocate(now%melted_snow(npts))
        allocate(now%melted_ice(npts))
        allocate(now%refr(npts))
        allocate(now%smb(npts))
        allocate(now%smb_snow(npts))
        allocate(now%smb_ice(npts))
        allocate(now%acc(npts))
        allocate(now%lhf(npts))
        allocate(now%shf(npts))
        allocate(now%subl(npts))
        allocate(now%lwu(npts))
        allocate(now%runoff(npts))
        allocate(now%evap(npts))

        ! forcing fields
        allocate(now%sf(npts))
        allocate(now%rf(npts))
        allocate(now%sp(npts))
        allocate(now%lwd(npts))
        allocate(now%swd(npts))
        allocate(now%wind(npts))
        allocate(now%rhoa(npts))
        allocate(now%qq(npts))
        allocate(now%mask(npts))

        return 
    end subroutine surface_alloc 

    subroutine surface_dealloc(now)

        implicit none 

        type(surface_state_class) :: now

        deallocate(now%t2m)
        deallocate(now%tsurf)
        deallocate(now%hsnow)
        deallocate(now%hice)
        deallocate(now%alb)
        deallocate(now%alb_snow)
        deallocate(now%melt)
        deallocate(now%melted_ice)
        deallocate(now%melted_snow)
        deallocate(now%refr)
        deallocate(now%smb)
        deallocate(now%smb_snow)
        deallocate(now%smb_ice)
        deallocate(now%acc)
        deallocate(now%lhf)
        deallocate(now%shf)
        deallocate(now%subl)
        deallocate(now%lwu)
        deallocate(now%runoff)
        deallocate(now%evap)

        ! forcing fields
        deallocate(now%sf)
        deallocate(now%rf)
        deallocate(now%sp)
        deallocate(now%lwd)
        deallocate(now%swd)
        deallocate(now%wind)
        deallocate(now%rhoa)
        deallocate(now%qq)
        deallocate(now%mask)

        return 

    end subroutine surface_dealloc 

    subroutine surface_physics_par_load(par,filename)

        type(surface_param_class) :: par
        character(len=*)    :: filename 
        character(len=256)  :: boundary(30), alb_scheme

        ! Declaration of namelist parameters
        double precision    :: ceff,albr,albl,alb_smax,alb_smin,hcrit,rcrit,  &
                               amp,csh,clh,shf_enh,lhf_enh,tmin,tmax,&
                               tstic, &
                               afac,tmid, &
                               tau_a, tau_f, w_crit, mcrit
        integer :: n_ksub

        namelist /surface_physics/ boundary,tstic,ceff,csh,clh,shf_enh,lhf_enh,&
                                   alb_smax,alb_smin,albr,albl,&
                                   tmin,tmax,hcrit,rcrit,amp,&
                                   tau_a, tau_f, w_crit, mcrit, &
                                   afac,tmid, &
                                   alb_scheme, &
                                   n_ksub

        ! Store initial values in local parameter values 
        boundary      = par%boundary  ! List of boundary variables
        ceff          = par%ceff      ! effective heat capacity of snow/ice
        albr          = par%albr      ! background bare ice (bare ice)
        albl          = par%albl      ! background land (bare land)
        alb_smax      = par%alb_smax  ! maximum snow albedo (fresh snow)
        alb_smin      = par%alb_smin  ! minimum snow albedo (wet/old snow)
        hcrit         = par%hcrit     ! critical snow height (m) for surface albedo
        rcrit         = par%rcrit     ! critical snow height (m) for refreezing fraction
        amp           = par%amp       ! diurnal cycle amplitude (K)
        csh           = par%csh       ! turbulent heat exchange coeffcicient (sensible heat)
        clh           = par%clh       ! turbulent heat exchange coeffcicient (latent heat)
        tmin          = par%tmin      ! minimum albedo-affecting temperature
        tmax          = par%tmax      ! maximum albedo-affecting temperature (originally 273.15K)
        tstic         = par%tstic
        alb_scheme    = par%alb_scheme 
        tau_a         = par%tau_a  
        tau_f         = par%tau_f  
        w_crit        = par%w_crit
        mcrit         = par%mcrit

        afac          = par%afac
        tmid          = par%tmid 

        n_ksub        = par%n_ksub
        shf_enh       = par%shf_enh
        lhf_enh       = par%lhf_enh

        ! Read parameters from input namelist file
        open(7,file=trim(filename))
        read(7,nml=surface_physics)
        close(7)
!         write(*,nml=surface_physics)
        
        ! Store local parameter values in output object
        par%boundary   = boundary 
        par%ceff       = ceff           ! effective heat capacity of snow/ice
        par%albr       = albr           ! background bare ice (bare ice)
        par%albl       = albl           ! background bare land (bare land)
        par%alb_smax   = alb_smax       ! maximum snow albedo (fresh snow)
        par%alb_smin   = alb_smin       ! minimum snow albedo (wet/old snow)
        par%hcrit      = hcrit          ! critical snow height (m) for surface albedo
        par%rcrit      = rcrit          ! critical snow height (m) for refreezing fraction
        par%amp        = amp            ! diurnal cycle amplitude (K)
        par%csh        = csh            ! turbulent heat exchange coeffcicient (sensible and latent heat)
        par%clh        = clh            ! turbulent heat exchange coeffcicient (sensible and latent heat)
        par%tmin       = tmin           ! minimum albedo-affecting temperature
        par%tmax       = tmax           ! maximum albedo-affecting temperature
        par%tstic      = tstic
        par%alb_scheme = alb_scheme
        par%tau_a      = tau_a
        par%tau_f      = tau_f
        par%w_crit     = w_crit
        par%mcrit      = mcrit

        par%afac       = afac
        par%tmid       = tmid

        par%n_ksub     = n_ksub
        par%shf_enh    = shf_enh
        par%lhf_enh    = lhf_enh

        ! initialize sub-daily time step tsticsub
        par%tsticsub = par%tstic / dble(par%n_ksub)

        return

    end subroutine surface_physics_par_load

    subroutine surface_boundary_define(bnd,boundary)

        implicit none 

        type(boundary_opt_class) :: bnd 
        character(len=256) :: boundary(:)
        integer :: q 

        ! First set all boundary fields to false
        bnd%t2m     = .FALSE.
        bnd%tsurf   = .FALSE. 
        bnd%hsnow   = .FALSE.
        bnd%alb     = .FALSE.
        bnd%melt    = .FALSE.
        bnd%refr    = .FALSE.
        bnd%smb     = .FALSE.
        bnd%acc     = .FALSE.
        bnd%lhf     = .FALSE.
        bnd%shf     = .FALSE. 
        bnd%subl    = .FALSE. 

        ! Now find boundary fields 
        do q = 1,size(boundary)

            select case(trim(boundary(q)))

                case("t2m")   
                    bnd%t2m     = .TRUE.
                case("tsurf")
                    bnd%tsurf   = .TRUE. 
                case("hsnow")
                    bnd%hsnow   = .TRUE. 
                case("alb")
                    bnd%alb     = .TRUE. 
                case("melt")
                    bnd%melt    = .TRUE. 
                case("refr")
                    bnd%refr    = .TRUE. 
                case("smb")
                    bnd%smb     = .TRUE. 
                case("acc")
                    bnd%acc     = .TRUE. 
                case("lhf")
                    bnd%lhf     = .TRUE.
                case("shf")
                    bnd%shf     = .TRUE.
                case("subl")
                    bnd%subl    = .TRUE.
                case DEFAULT 
                    ! pass 
            end select 
        end do 

        return 

    end subroutine surface_boundary_define


    subroutine print_param(par)
        
        type(surface_param_class) :: par
        integer :: q

        do q = 1,size(par%boundary)
            if ((len_trim(par%boundary(q)) .ne. 256) .and. &
                (len_trim(par%boundary(q)) .ne. 0)) then
                write(*,'(2a)') 'boundary ', trim(par%boundary(q))
            end if
        end do
        write(*,'(2a)')      'alb_scheme  ', trim(par%alb_scheme)
        write(*,'(a,i5)')    'nx         ', par%nx
        write(*,'(a,i5)')    'n_ksub     ', par%n_ksub
        write(*,'(a,g13.6)') 'ceff       ', par%ceff
        write(*,'(a,g13.6)') 'albr       ', par%albr
        write(*,'(a,g13.6)') 'albl       ', par%albl
        write(*,'(a,g13.6)') 'alb_smax   ', par%alb_smax
        write(*,'(a,g13.6)') 'alb_smin   ', par%alb_smin
        write(*,'(a,g13.6)') 'hcrit      ', par%hcrit
        write(*,'(a,g13.6)') 'rcrit      ', par%rcrit
        write(*,'(a,g13.6)') 'amp        ', par%amp
        write(*,'(a,g13.6)') 'csh        ', par%csh
        write(*,'(a,g13.6)') 'tmin       ', par%tmin
        write(*,'(a,g13.6)') 'tmax       ', par%tmax
        write(*,'(a,g13.6)') 'tstic      ', par%tstic
        write(*,'(a,g13.6)') 'tsticsub   ', par%tsticsub
        write(*,'(a,g13.6)') 'clh        ', par%clh
        write(*,'(a,g13.6)') 'tau_a      ', par%tau_a
        write(*,'(a,g13.6)') 'tau_f      ', par%tau_f
        write(*,'(a,g13.6)') 'w_crit     ', par%w_crit
        write(*,'(a,g13.6)') 'mcrit      ', par%mcrit
        write(*,'(a,g13.6)') 'shf_enh    ', par%shf_enh
        write(*,'(a,g13.6)') 'lhf_enh    ', par%lhf_enh

    end subroutine
    
    
    subroutine print_boundary_opt(bnd)
        type(boundary_opt_class) :: bnd
        write(*,'(a,l1)') 'tsurf   ', bnd%tsurf
        write(*,'(a,l1)') 'hsnow   ', bnd%hsnow
        write(*,'(a,l1)') 'alb     ', bnd%alb
        write(*,'(a,l1)') 'melt    ', bnd%melt
        write(*,'(a,l1)') 'refr    ', bnd%refr
        write(*,'(a,l1)') 'acc     ', bnd%acc
        write(*,'(a,l1)') 'lhf     ', bnd%lhf
        write(*,'(a,l1)') 'shf     ', bnd%shf
        write(*,'(a,l1)') 'subl    ', bnd%subl
        write(*,'(a,l1)') 'smb     ', bnd%smb
    end subroutine


end module surface_physics
