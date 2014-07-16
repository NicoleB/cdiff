********************************************************************************
*Analyze incidence of C diff within 100 days
********************************************************************************
/* hspname: 	0 "UW/SCCA" 
				1 "CHRMC" 		 */

*stset
sort upn time
stset time, failure(failure==1) origin(time date_1stFHCRCtx) id(upn)


*Split data for tvcs
do stsplit.do, nostop
