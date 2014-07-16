cd /Users/nicole/FHCRC/cdiff/doFiles

do merged_labs_demo_all_2007.do, nostop
do Cdiff_survivalcoding_2007.do, nostop
do Cdiff_Descriptive_2007.do, nostop
do Cdiff_analyses_2007.do, nostop

/* 	At this point: one row per patient
	showing either their incident Cdiff event
	or their censorship event */
