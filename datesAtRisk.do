* Create dates for each day at risk per pt

	* Import Cdiff stsplit (long) data
	cd /Users/nicole/FHCRC/cdiff/doFiles
	do control_2007.do
	do stcox_prep.do
	
	* Create dates for each failure time
	ge date_failtime = floor((date_1stFHCRCtx-1) + _t)
	
	* Fill in all other dates
	tsset upn date_failtime
	tsfill
	
	*Carryforward uwids
	bysort upn (uwid): carryforward uwid, replace
	bysort upn (uwid): assert uwid[1]==uwid

* Save
save ../data-dta/datesAtRisk, replace
