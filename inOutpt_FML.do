* Import, merge, clean, and prep raw inpatient/outpatient billing data
* for use as time-varying "timevar_inOuPat" var in Cox model and sum stats

cd ~/FHCRC/cdiff/data-dta/



* Outpatient data prep

	*ADULTS AND PEDS

		* Import raw outpatient dataset
		use HPMInfo_OP.dta, clear // vars: uwid patientaccountnumber patientmedrecno checkindatetime dischargedatetime
								  //	   days hwhflagdeleteyesifuencounter entity patienttype
	
		* Standardize uwids
		do ~/FHCRC/automation/standardID.do
	
		* Remove unneeded vars
		keep uwid checkindatetime dischargedatetime days
	
		* Create indicator var for inpatient/outpatient
		ge inOuPat = 1  // 1 == outpatient
		
		* Save changes
		save outPat.dta, replace
		

		
* Inpatient data prep

	*ADULTS ONLY
		*Import raw inpatient dataset
		use HPMInfo_IP.dta, clear // vars: uwid patientaccountnumber patientmedrecno checkindatetime dischargedatetime 
								  //       days hwhflagdeleteyesifuencounter entity hsptypetxdate txdatebwcheckindisch
								  //	   txdatecheckin txdatedisch txdate
	
		* Standardize uwids
		do ~/FHCRC/automation/standardID.do
	
		* Remove unneeded vars
		keep uwid checkindatetime dischargedatetime days
	
		* Create indicator var for inpatient/outpatient
		ge inOuPat = 2 // 2 == inpatient
		
		* Save changes
		save inPatAd.dta, replace
		
		
* Prep in/outpatient data for merge with Cdiff data

	* Append in (adult) & outpatient (adult & ped) datasets
	append using outPat.dta

	* Convert dates (HRF-to-SID)

		* Get rid of embedded blanks
		foreach var of varlist checkindatetime dischargedatetime {
			replace `var' = subinstr(`var', " ", "",.)
		}

		* Create SID from HRF
		ge date_checkIn = date(checkindatetime, "MDY", 2014)
		ge date_checkOu = date(dischargedatetime, "MDY", 2014)
			
			* Fill in date_checkou missings (24 of them), indicate
			ge date_checkOuAssum = cond(date_checkOu==., 1, .)
			replace date_checkOu = date_checkIn + (days) if date_checkOu == .

			
	* Create full in/out timelines using all known dates
		
		* Clean up entries
			* Drop duplicate entries
			duplicates drop uwid date_checkIn date_checkOu inOuPat, force
			
			* Edit outpatient data to reflect days
			replace date_checkOu = date_checkIn if inlist(days, 1, 0) & inOuPat==1
			ge sameDay = 1 if date_checkIn == date_checkOu

			* Drop new duplicate entries
			duplicates report uwid date_checkIn date_checkOu inOuPat if inOuPat==1 // all dups from outpatient visits
			duplicates drop uwid date_checkIn date_checkOu inOuPat, force				

			* It appears that multiday OP visits are more accurately represented by OP visits of days 0/1
			* Multiday OP visits overestimate the duration of OP visits & overlap IP visits
			drop if inOuPat==1 & days>1
			drop date_checkOuAssum //no longer needed
			
			* Now, drop if outpatient visit occured on day of inpatient admittance
			duplicates tag uwid date_checkIn, gen(dup)
			drop if inOuPat==1 & dup>0
			
			* Drop the few redundant IP listings of days==1
			drop if dup>0 & inOuPat==2 & days==1
			drop dup //no longer needed
		
		* New obs (1 obs for checkin, 1 obs for checkout)
		expand 2, gen(checkInOu) // 0 == original obs (check-in), 1 == new obs (check-out)
		ge date_failtime = cond(checkInOu == 0, date_checkIn, date_checkOu)
		
		* Drop "check-out" obs for same day obs
		drop if sameDay==1 & checkInOu == 1

		
	* Create temp panels per in/outpatient exposures
	
		* Temp panel ID
		egen temp_panID = group(uwid date_checkIn date_checkOu)
		
		* Fill in dates & carryforward details for each panel:
		tsset temp_panID date_failtime
		tsfill
		bysort temp_panID (date_failtime): carryforward uwid days inOuPat date_check*, replace
		
		
	* Clean up overlapping entries 
	duplicates tag uwid date_failtime, gen(dup)
	drop if dup==1 & inOuPat==1 // if IP overlap with OP, give preference to IP
	drop dup
	duplicates tag uwid date_failtime, gen(dup)
	duplicates drop uwid date_failtime, force // if IP overlap with IP, drop either one of the IP

	
	* Drop unnecessary vars
	keep uwid inOuPat date_failtime
	
	* Convert to upn, retaining uwid
	merge m:1 uwid using ~/FHCRC/automation/convertID2.dta, keepusing(upn uwid) keep(master match) nogenerate

	*Save
	save inOutPtTimes.dta, replace

	
*Complete with the Ped inpatient/outpatient data
	*PEDS ONLY
		*Import raw inpatient dataset
		import delimited ~/FHCRC/cdiff/data-orig/all_hospitalization_dates.csv, clear // vars: upn location locationlong date

		*Standardize uwids
		do ~/FHCRC/automation/standardID.do
		
		*Add converted uwids
		merge m:1 upn using ~/FHCRC/automation/convertID2.dta, keepusing(upn uwid) keep(master match) nogenerate
		
		* Create indicator for inpatient/outpatient
		ge inOuPat = cond( inlist(substr(locationlong, 1, 3), "Out", "Dis"), 1, .) // 1 == outpatient/discharged
		replace inOuPat = 2 if inOuPat ==. // 2 == inpatient
		
		*Create indicator for inpatient/outpatient/discharge
		ge inOuDis = inOuPat
		replace inOuDis = 0 if locationlong == "Discharged" // 0 == discharged (need this for RMC analysis)
		
		*Convert dates (HRF-to-SID), create date_failtime:
		ge date_failtime = date(date, "YMD", 2014)
		
		* Save changes
		duplicates drop
		save inPatPed.dta, replace
			
	*Append to adult inpatient & adult/ped outpatient data
		append using inOutPtTimes.dta, generate(appendVar)
		
		*Make sure inOuPat is consistent within upn:date_failtime
		ge derp = .
		bysort upn date_failtime (inOuPat): replace derp = 1 if inOuPat[1]!=inOuPat
		bysort upn date_failtime (derp): carryforward derp, replace
		list upn date_failtime appendVar inOuPat if derp==1
		
		bysort upn date_failtime (appendVar): assert(appendVar[1]!=appendVar[1+_n]) if derp==1 //assertion passed. discrepancies in appended data.
		
		*Drop inconsistent UW billing data, preference given to master FHCRC data.
		*Keep derp to track this.
		drop if derp==1 & appendVar==1
		
		bysort upn date_failtime (inOuPat): assert(inOuPat[1]==inOuPat) //assertion passed!
		
		*Carryforward inOuDis
		bysort upn date_failtime (inOuDis): carryforward inOuDis, replace
		bysort upn date_failtime (inOuDis): assert(inOuDis[1]==inOuDis) //assertion passed!

		*Save completed time-series data
		keep upn uwid inOuPat inOuDis date_failtime derp
		duplicates drop		
		save inOutDisPtTimes.dta, replace

* Merge long Cdiff data (timesAtRisk.dta) with inOutPtTimes.dta, discard irrelevant times

	* Import Cdiff stsplit (long) data, tsfill all at-risk dates
	do ~/FHCRC/cdiff/doFiles/datesAtRisk.do
	
	* Merge with in/outpatient dates, discarding unneeded dates
	merge 1:1 uwid date_failtime using ~/FHCRC/cdiff/data-dta/inOutDisPtTimes.dta, keep(1 3) nogenerate
	
	*Lots of missing values in inOuPat. Create new vars:

		* Inpatient (1) vs. outpatient/anywhere (0)
		ge timevar_In_v_Else = cond(inOuPat==2, 1, 0)
		
		* Dummy: Inpatient (2) vs. outpatient (1) vs. nowhere/discharged (0)
		ge timevar_i_InOuNo = cond(inOuPat!=. & inOuDis!=0, inOuPat, 0)

		*Visualize
		
		bysort upn (date_failtime): ge spikeTime = _n
		assert _t == spikeTime if _t!=. & _t!=100.125
		replace spikeTime = floor(spikeTime)
		
		*NOTE: don't try looping/simplifying the following code blocks.
		*Doing so (in Stata) requires the same # of lines with far less readability
			*Inpatient start/stop			
			bysort upn (date_failtime): ge date_startIn = spikeTime if timevar_In_v_Else[_n]==1 & inlist(timevar_In_v_Else[_n-1], 0, .)
			bysort upn (date_failtime): ge date_stopIn = spikeTime+1 if timevar_In_v_Else[_n]==1 & inlist(timevar_In_v_Else[_n+1], 0, .)
			bysort upn (date_failtime): carryforward date_startIn, replace
			replace date_startIn = . if date_stopIn ==.
			
			*Outpatient/anywhere start/stop
			bysort upn (date_failtime): ge date_startOuAny = spikeTime if timevar_In_v_Else[_n]==0 & inlist(timevar_In_v_Else[_n-1], 1, .)
			bysort upn (date_failtime): ge date_stopOuAny = spikeTime+1 if timevar_In_v_Else[_n]==0 & inlist(timevar_In_v_Else[_n+1], 1, .)
			bysort upn (date_failtime): carryforward date_startOuAny, replace
			replace date_startOuAny = . if date_stopOuAny ==.
			
			*Outpatient start/stop
			bysort upn (date_failtime): ge date_startOu = spikeTime if timevar_i_InOuNo[_n]==1 & inlist(timevar_In_v_Else[_n-1], 2, 0, .)
			bysort upn (date_failtime): ge date_stopOu = spikeTime+1 if timevar_i_InOuNo[_n]==1 & inlist(timevar_In_v_Else[_n+1], 2, 0, .)
			bysort upn (date_failtime): carryforward date_startOu, replace
			replace date_startOu = . if date_stopOu ==.
			
			*Discharged start/stop (only applies to peds)
			bysort upn (date_failtime): ge date_startDis = spikeTime if timevar_i_InOuNo[_n]==0 & inlist(timevar_i_InOuNo[_n-1], 2, 1, .)
			bysort upn (date_failtime): ge date_stopDis = spikeTime+1 if timevar_i_InOuNo[_n]==0 & inlist(timevar_i_InOuNo[_n+1], 2, 1, .)
			bysort upn (date_failtime): carryforward date_startDis, replace
			replace date_startDis = . if date_stopDis ==.
			
			foreach var of varlist date_stop* {
				replace `var' = `var'-1 if failure!=.
				replace `var' = 100 if `var'==101
				}
				
			bysort upn (hspname): carryforward hspname, replace
			egen patNumPed = group(upn) if hspname==1
			egen patNumAd = group(upn) if hspname==0
			
			*Graph
			   * Peds, all: inpatient, discharged, else
				twoway (rspike date_startIn date_stopIn patNumPed, horizontal lcolor(gs0)) ///
			   (rspike date_startOu date_stopOu patNumPed, horizontal lcolor(blue)) ///
			   (rspike date_startDis date_stopDis patNumPed, horizontal lcolor(green)) ///
			   (scatter patNumPed _t if failure!=., msymbol(x) mcolor(red))
			   
			   *Peds, all: inpatient, else
				twoway (rspike date_startIn date_stopIn patNumPed, horizontal lcolor(gs0)) ///
			   (rspike date_startOuAny date_stopOuAny patNumPed, horizontal lcolor(gs11)) ///
			   (scatter patNumPed _t if failure!=., msymbol(x) mcolor(red))
			   
			   *Adults, all: inpatient, else
			   twoway (rspike date_startIn date_stopIn patNumAd, horizontal lcolor(gs0)) ///
			   (rspike date_startOu date_stopOu patNumAd, horizontal lcolor(gs11)) ///
			   (scatter patNumAd _t if failure!=., msymbol(x) mcolor(red))
		
	
	* Testing association between increased IP or OP exposure and CDI
	
		* Create running LOS run time vars "runTimeIP runTimeOP runTimeNO"
		local runSuff "IP OP NO"
		local num_inOu 2 1 .
		local n : word count `num_inOu'
		
		forvalues i = 1/`n' {
			local a : word `i' of `num_inOu'
			local b : word `i' of `runSuff'
			bysort uwid inOuPat (date_failtime): ge runTime`b' = _n if inOuPat == `a'
			bysort uwid (date_failtime): carryforward runTime`b', replace
			replace runTime`b' = 0 if runTime`b' == .
		}
		
		
	
	
	* Vars for testing association between CDI and location of acquisition
	* (where acquisition exposure occurs days 1-3; CDI occurs day 4)
		
		* Where HAI = any (constant or intermittent) IP or OP during acquisition exposure period
		bysort uwid (date_failtime): ge acqHospEver = 1 if inOuPat[_n-1] != . | inOuPat[_n-2] != . | inOuPat[_n-3] != .
		
		* Where HAI = any IP acquisition exposure period
		bysort uwid (date_failtime): ge acqIPEver = cond(inOuPat[_n-1] == 2 | inOuPat[_n-2] == 2 | inOuPat[_n-3] == 2, 1, 0)
		
		bysort uwid (date_failtime): ge acqIPAlways = cond(inOuPat[_n-1] == 2 & inOuPat[_n-2] == 2 & inOuPat[_n-3] == 2, 1, 0)
		* How many (among cases) were IP acquired: percent acquired IP vs. mixed or always not IP
		















