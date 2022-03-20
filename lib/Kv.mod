COMMENT

	kv.mod

	Potassium channel, Hodgkin-Huxley style kinetics
	Kinetic rates based roughly on Sah et al. and Hamill et al. (1991)

	Author: Zach Mainen, Salk Institute, 1995, zach@salk.edu

	Steps taken to allow variable time step integration, as in 
	Kv.mod from Mainen and Sejnowski 1996 on SenseLab (CCohen):
	
	Made threadsafe.

	Changed breakpoint solve method to cnexp, to allow variable time
	step integration.

	Removed tadj calculation as trates(v) procedure, added tadj calculation
	to initial block, to ensure all threads calculate tadj at initialization.

	Removed:

	dt as a PARAMETER

	LOCAL nexp
	PROCEDURE states() {	

		: Compute state variable n at the current v and dt.
	    trates(v)
	    n = n + nexp*(ninf-n)
	    VERBATIM
	    return 0;
	    ENDVERBATIM
	} 

	Added: current DERIVATIVE block.

	Removed:
	PROCEDURE trates(v) {

		: Computes rate and other constants at current v.
		: Call once from HOC to initialize inf at resting v.

		LOCAL tinc
		TABLE ninf, nexp
		
		DEPEND dt, celsius, temp, Ra, Rb, tha, qa
		
		FROM vmin TO vmax WITH 199

		rates(v): not consistently executed from here if usetable_hh == 1	

		tinc = -dt * tadj
		nexp = 1 - exp(tinc/ntau)
	}

	PROCEDURE rates(v) {

		: Computes rate and other constants at current v.
	    : Call once from HOC to initialize inf at resting v.

		a = Ra * (v - tha) / (1 - exp(-(v - tha)/qa))
		b = -Rb * (v - tha) / (1 - exp((v - tha)/qa))
		ntau = 1/(a+b)
		
		ninf = a*ntau
	}

	Added: current PROCEDUREs trates(v), rates(v), and FUNCTION efun(z).

	Removed: INDEPENDENT {t FROM 0 TO 1 WITH 1 (ms)}, to allow t > 1ms. t remains
	independent by default.

	End of implemented changes (CCohen).

ENDCOMMENT


NEURON {
	
	SUFFIX kv
	USEION k READ ek WRITE ik
	RANGE n, gk, gbar
	RANGE ninf, ntau
	GLOBAL Ra, Rb
	GLOBAL q10, temp, tadj, vmin, vmax
	THREADSAFE
}

UNITS {
	
	(mA) = (milliamp)
	(mV) = (millivolt)
	(pS) = (picosiemens)
	(um) = (micron)
} 

PARAMETER {
	
	gbar = 5   		(pS/um2)	: 0.03 mho/cm2
	v 				(mV)
								
	tha  = 25		(mV)		: v 1/2 for inf
	qa   = 9		(mV)		: inf slope		
	
	Ra   = 0.02		(/ms)		: max act rate
	Rb   = 0.002	(/ms)		: max deact rate
	
	celsius			(degC)
	temp = 23		(degC)		: original temp 	
	q10  = 2.3					: temperature sensitivity

	vmin = -120		(mV)
	vmax = 100		(mV)
}

ASSIGNED {
	
	a		(/ms)
	b		(/ms)
	ik 		(mA/cm2)
	gk		(pS/um2)
	ek		(mV)
	ninf
	ntau 	(ms)	
	tadj
}

STATE {

	n
}

INITIAL {
	
	: make all threads calculate tadj at initialization
	tadj = q10^((celsius - temp)/10 (degC))

	trates(v)
	n = ninf
}

BREAKPOINT {
    
    SOLVE states METHOD cnexp
	
	gk = tadj * gbar * n
	ik = (1e-4) * gk * (v - ek)
}

DERIVATIVE states {

	: Computes state variable n at the current v and dt
	trates(v)
    n' = (ninf-n)/ntau
}

PROCEDURE trates(v (mV)) {	

	: Computes rate and other constants at current v.
	: Call once from HOC to initialize inf at resting v.
	
	TABLE ninf, ntau
	
	DEPEND celsius, temp, Ra, Rb, tha, qa
	
	FROM vmin TO vmax WITH 199

	: Not consistently executed from here if usetable_hh == 1
	rates(v)
}

PROCEDURE rates(v) {

	: Computes rate and other constants at current v.
    : Call once from HOC to initialize inf at resting v.

	a = Ra * qa * efun(-(v - tha)/qa)
	b = Rb * qa * efun((v - tha)/qa)
	
	tadj = q10^((celsius - temp)/10)
	
	ntau = 1/tadj/(a+b)
	ninf = a/(a+b)	
}

FUNCTION efun(z) {
	
	if (fabs(z) < 1e-4) {

		efun = 1 - z/2

	} else {

		efun = z/(exp(z) - 1)
	}
}
