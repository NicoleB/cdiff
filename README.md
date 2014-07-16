# C. difficile in allo HCT

This repo contains many of the Stata .do files used in my C. diff project, where I determine the incidence and risk factors of C. difficile among our allo HCT patients. Note: Since files with patient information have been excluded from this repo, this repo is far from complete.

## control_2007.do
Runs a sequence of .do files, combining patient demographic data, clinical C. difficile testing results, and chart review edits into a one-row-per-patient survival analysis dataset. Each row represents the survival analysis outcome, either C. difficile incidence or a censoring event.

## datesAtRisk.do
Creates the survival analysis dataset (**control_2007.do**), stsets it and runs the **stsplit.do** script (within **stcox_prep.do**). This runs an `stsplit` splitting on failures, thereby creating a new row for every day (1-100) that anyone in the population experiences a C. diff failure. The time-series commands (`tsset` and `tsfill`) creates a row for all the remaining "non-failure" days. This .do file preps the "time template" of relevant dates for a later merge with the inpatient/outpatient data prepped by **inOutpt.do**.

## inOutpt.do
One of the better commented .do files. Transforms raw inpatient and outpatient billing data into indicators for inpatient/outpatient status, which will then be merged onto the master "time template" created in **datesAtRisk.do**. Indicators include determining place of C. difficile acquisition (inpatient, outpatient, or other) by taking into account the 3 day incubation period of C. difficile.

## stcox_prep.do
Preps the data for survival analysis via `stset`, and creates a new row for every possible failure time by running **stsplit.do**.

## stsplit.do
Splits on failure times, thereby creating a new row at the time of any failure occurring in the population, using the timeline of days 1-100 post-transplant.

Stata discusses the method of splitting on failure times in a bit more detail on page 13 of their [stsplit manual] (http://www.stata.com/manuals13/ststsplit.pdf "Stata's stsplit manual"). An excerpt:
>To split data at failure times, you would use stsplit with the following syntax, ignoring other
options:

>`stsplit [if], at(failures)`

>This form of episode splitting is useful for Cox regression with time-varying covariates. Splitting at the failure times is useful because of a property of the maximum partial-likelihood estimator for a
Cox regression model: the likelihood is evaluated only at the times at which failures occur in the
data, and the computation depends only on the risk pools at those failure times. Changes in covariates
between failure times do not affect estimates for a Cox regression model. Thus, to ﬁt a model with
time-varying covariates, all you have to do is deﬁne the values of these time-varying covariates at all
failure times at which a subject was at risk (Collett 2003, chap. 8). After splitting at failure times, you deﬁne time-varying covariates by referring to the system variable `_t` (analysis time) or the timevar variable used to `stset` the data.

>_Collett, D. 2003. Modelling Survival Data in Medical Research. 2nd ed. London: Chapman & Hall/CRC_

After `stsplit`ting the data on failure times, the time-dependent variables were filled into the new rows, thereby creating time-varying covariates.
