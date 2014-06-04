* Import, merge, clean, and prep raw inpatient/outpatient billing data
* for use as time-varying "timevar_inOuPat" var in Cox model and sum stats


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

	* Drop unnecessary vars, save
	keep uwid inOuPat date_failtime
	save inOutPtTimes.dta, replace
	
	*Create test dataset to ensure all uwid in Cdiff data are accounted for in billing data
	keep uwid
	duplicates drop
	save uwidOnlyInOut.dta
	clear
	

* Merge long Cdiff data (timesAtRisk.dta) with inOutPtTimes.dta, discard irrelevant times

	* Import Cdiff stsplit (long) data, tsfill all at-risk dates
	do /Users/nicole/FHCRC/cdiff/doFiles/datesAtRisk.do

	* Establish that all Cdiff pts are accounted for in in/outpt billing data
	cd ../data-dta
	merge m:1 uwid using uwidOnlyInOut.dta, nogenerate
	
	* Merge with in/outpatient dates, discarding unneeded dates
	merge 1:1 uwid date_failtime using inOutPtTimes.dta, keep(1 3) nogenerate


* Create timevars for analysis

	* Inpatient (1) vs. outpatient + nowhere (0)
	ge timevar_In_v_OuNo = cond(inOuPat==2, 1, 0)
	
	* Dummy: Inpatient (2) vs. nowhere (0); outpatient (1) vs. nowhere (0)
	ge timevar_dum_InOuNo = cond(inOuPat!=., inOuPat, 0)

	* Dummy: Inpatient (2) vs. outpatient (0); nowhere (1) vs. outpatient (0)
	ge timevar_dum_InNoOu = inOuPat
	replace timevar_dum_InNoOu = 0 if inOuPat==1
	replace timevar_dum_InNoOu = 1 if inOuPat==.






















