# C. difficile in allo HCT

This repo contains many of the Stata .do files used in my C. diff project, where I determine the incidence and risk factors of C. difficile among our allo HCT patients. Note: Since files with patient information have been excluded from this repo, this repo is far from complete.

## control_2007.do
Runs a sequence of .do files, combining patient demographic data, clinical C. difficile testing results, and chart review edits into a one-row-per-patient survival analysis dataset. Each row represents the survival analysis outcome, either C. difficile incidence or a censoring event.

## datesAtRisk.do
 Creates the survival analysis dataset (**control_2007.do**), stsets it and runs the **stsplit.do** script (within **stcox_prep.do**). This runs an `stsplit` splitting on failures, thereby creating a new row for every day (1-100) that anyone in the population experiences a C. diff failure. The time-series commands (`tsset` and `tsfill`) creates a row for all the remaining "non-failure" days.
