* Create dates from failure times
	* Import Cdiff time-varying (long) data
	cd /Users/nicole/FHCRC/cdiff/doFiles
	do control_2007.do
	do stcox_prep.do
	
	* Create dates for each failure time
	ge date_failtime = floor((date_1stFHCRCtx-1) + _t)
	
	* Fill in all other dates
	tsset upn date_failtime
	tsfill
	
	*Carryforward uwids
	gsort upn -uwid, gen(rev_uwid)
	bysort upn (rev_uwid): replace uwid = uwid[1] if uwid==""
	bysort upn (uwid): assert uwid[1]==uwid
	drop rev_uwid
	
	* Save dataset for merge with in/out data
	cd ../data-dta
	save timesAtRisk.dta, replace
	

* Outpatient data prep

	* Import raw outpatient dataset
	use HPMInfo_OP.dta, clear // vars: uwid patientaccountnumber patientmedrecno checkindatetime dischargedatetime
							  //	   days hwhflagdeleteyesifuencounter entity patienttype

	* Standardize uwids
	do ~/FHCRC/automation/standardID.do

	* Remove unneeded vars
	keep uwid checkindatetime dischargedatetime days

	* Create indicator var for inpatient/outpatient
	ge inOuPat = 1  // == outpatient
	save outPat.dta, replace
	

* Inpatient data prep

	*Import raw inpatient dataset
	use HPMInfo_IP.dta, clear // vars: uwid patientaccountnumber patientmedrecno checkindatetime dischargedatetime 
							  //       days hwhflagdeleteyesifuencounter entity hsptypetxdate txdatebwcheckindisch
							  //	   txdatecheckin txdatedisch txdate

	* Standardize uwids
	do ~/FHCRC/automation/standardID.do

	* Remove unneeded vars
	keep uwid checkindatetime dischargedatetime days

	* Create indicator var for inpatient/outpatient
	ge inOuPat = 2 // == inpatient

	
* Prep in/outpatient data for merge with Cdiff data

	* Append in/outpatient datasets
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
		
		* Create new date var for all in/out dates, indicate
			
			* Clean up entries
				
				* Drop duplicate entries
				duplicates drop uwid date_checkIn date_checkOu inOuPat, force
				
				* Edit outpatient data to reflect days
				replace date_checkOu = date_checkIn if inlist(days, 1, 0) & inOuPat==1
				ge sameDay = 1 if date_checkIn == date_checkOu

				* Drop new duplicate entries
				duplicates report uwid date_checkIn date_checkOu inOuPat if inOuPat==1 // all dups from outpatient visits
				duplicates drop uwid date_checkIn date_checkOu inOuPat, force

			* New obs (1 obs for checkin, 1 obs for checkout)
			expand 2, gen(checkInOu) // 0 == original obs (check-in), 1 == new obs (check-out)
			ge date_failtime = cond(checkInOu == 0, date_checkIn, date_checkOu)
			
			* Drop "check-out" obs for same day obs
			drop if sameDay==1 & checkInOu == 1

		* Create temp panels per in/outpatient exposures
		
			* Temp panel ID
			egen temp_panID = group(uwid date_checkIn date_checkOu)
			
			* Drop if outpatient visit occurred during inpatient admittance
			duplicates tag temp_panID date_failtime, gen(dup)
			drop if dup==1 & inOuPat==1
			
			* Fill in dates for each category:
			tsset temp_panID date_failtime
			tsfill
		
			* inOuPat == 2
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
