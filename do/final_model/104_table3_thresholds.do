version 19.5
clear all
set more off
set varabbrev off
set linesize 255

/**************************************************************************
* 104_table3_thresholds.do
*
* Purpose:
*   Produce a manuscript-ready threshold table from the locked threshold
*   utility output.
*
* Inputs:
*   - ${FINAL_TABLES}/100_threshold_utility_tables.csv
*
* Outputs:
*   - ${FINAL_TABLES}/104_table3_thresholds.csv
*
* Dependencies:
*   - 90_config_final_pe.do
*   - 100_threshold_utility_tables.do
*
* Guardrails:
*   - Reads only locked threshold output
*
* Main analysis steps:
*   1. Import threshold utility data
*   2. Keep the manuscript threshold rows
*
* Export steps:
*   - Table 3 CSV
*
* Completion:
*   - Prints export path
**************************************************************************/

do "/Volumes/DallalMinix/ramseymini/Library/CloudStorage/OneDrive-ThomasJeffersonUniversityanditsAffiliates/_Enterprise/stats/Pulmonary Embolism/Locked/do/final_model/90_config_final_pe.do"

capture log close _all
log using "${FINAL_LOG}/104_table3_thresholds.log", replace text

final_need_file, file("${FINAL_TABLES}/100_threshold_utility_tables.csv") tag("threshold utility table")

import delimited using "${FINAL_TABLES}/100_threshold_utility_tables.csv", clear varnames(1)
capture confirm numeric variable threshold
if _rc {
    destring threshold, replace force
}
keep if inlist(round(threshold, 0.001), 0.005, 0.010, 0.020)
quietly count
if r(N) == 0 {
    di as error "FATAL: manuscript threshold filter returned zero rows; check threshold coding in ${FINAL_TABLES}/100_threshold_utility_tables.csv"
    exit 459
}
export delimited using "${FINAL_TABLES}/104_table3_thresholds.csv", replace

di as text "Wrote ${FINAL_TABLES}/104_table3_thresholds.csv"
di as text "104_table3_thresholds.do complete."
log close
