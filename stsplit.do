stsplit, at(failure)
*GVHD
	ge day_gvhd34=(date_gvhd-date_1stFHCRCtx) if bin_grade_gvhd34==1
	bysort upn: ge timevar_gvhd34=cond(_t>=day_gvhd34, 1, 0)
	replace timevar_gvhd34=. if grade_gvhd==.
	
	ge day_gvhd234=(date_gvhd-date_1stFHCRCtx) if bin_grade_gvhd234==1
	bysort upn: ge timevar_gvhd234=cond(_t>=day_gvhd234, 1, 0)
	replace timevar_gvhd234=. if grade_gvhd==.
	
	ge day_gvhd1234=(date_gvhd-date_1stFHCRCtx) if bin_grade_gvhd1234==1
	bysort upn: ge timevar_gvhd1234=cond(_t>=day_gvhd1234, 1, 0)
	replace timevar_gvhd1234=. if grade_gvhd==.
	
*Gut GVHD
	ge day_gutgvhd34=(date_gvhd-date_1stFHCRCtx) if bin_grade_gutgvhd34==1
	bysort upn: ge timevar_gutgvhd34=cond(_t>=day_gutgvhd34, 1, 0)
	replace timevar_gutgvhd34=. if grade_gutgvhd==.
	
	ge day_gutgvhd234=(date_gvhd-date_1stFHCRCtx) if bin_grade_gutgvhd234==1
	bysort upn: ge timevar_gutgvhd234=cond(_t>=day_gutgvhd234, 1, 0)
	replace timevar_gutgvhd234=. if grade_gutgvhd==.
	
	ge day_gutgvhd1234=(date_gvhd-date_1stFHCRCtx) if bin_grade_gutgvhd1234==1
	bysort upn: ge timevar_gutgvhd1234=cond(_t>=day_gutgvhd1234, 1, 0)
	replace timevar_gutgvhd1234=. if grade_gutgvhd==.
/*
*Engraftment
	ge day_graft=date_graft-date_1stFHCRCtx
	bysort upn: ge timevar_graft=cond(_t>=day_graft, 1, 0) */
*RMD-acquired
/*	CDC Definition (as found in Multidrug-Resistant Organism..." page 35 of 43.
		"Outpatient reporting: Location CDI Incidence Rate: ...identified >3 days after admission."
	Will therefore code this for a 3 day lag.
	If admitted on _t==1, the first CDI event to be	attributed to the RMD can occur on or after _t==4.
	If discharged on _t==100, the last CDI event to be	attributed to the RMD can occur on _t==103, not after.
*/
	sort chrmcid _t
	forval num=1/14  {
		ge day_onRMD`num'=date_startRMD`num'-date_1stFHCRCtx
		ge day_offRMD`num'=date_endRMD`num'-date_1stFHCRCtx
		ge timevar_RMD`num'=cond(_t>=day_onRMD`num' & date_startRMD`num'!=. & ///
		_t<=day_offRMD`num', 1, 0)
	}
	
	*RMD timevar; no infection acquisition modeled
	ge timevar_RMD=0
	ge room_rmd=.
	forval num=1/14 {
		replace timevar_RMD=1 if timevar_RMD`num'==1 & timevar_RMD`num'!=0
		replace room_rmd=room_rmd`num' if timevar_RMD`num'==1 & room_rmd`num'!=.
		}
	
	
	ge timevar_RMD100s=1 if room_rmd<=100 & timevar_RMD==1
	
	replace timevar_RMD100s=0 if room_rmd>100 & timevar_RMD==1 & room_rmd!=.

	drop day_gvhd* day_gutgvhd* 
	* drop room_rmd1-date_endRMD14 day_onRMD1-timevar_RMD14
	
*Reset stset
sort upn time
stset time, failure(failure==1) origin(time date_1stFHCRCtx) id(upn)
