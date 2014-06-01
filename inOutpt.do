cd /Users/nicole/FHCRC/cdiff/data-dta

* Create dates from failure times
	* Import Cdiff time-varying (long) data
	use 
* Outpatient data prep
	* Import
	use HPMInfo_OP.dta // vars: uwid patientaccountnumber patientmedrecno checkindatetime dischargedatetime days hwhflagdeleteyesifuencounter entity patienttype
	* Remove unneeded vars
	keep uwid checkindatetime dischargedatetime days
	rename checkindatetime ouPat_admit
	rename dischargedatetime ouPat_disch


	
	* Dates (HRF-to-SID)
