version 19.5
clear all
set more off
set varabbrev off
set linesize 255

/**************************************************************************
* 92_manifest_and_qc.do
*
* Purpose:
*   Create a locked input/output manifest and basic dataset QC for the
*   analysis-ready file.
*
* Inputs:
*   - ${FINAL_OUT}/91_locked_analysis_file_final_pe.dta
*
* Outputs:
*   - ${FINAL_TABLES}/92_manifest_files.csv
*   - ${FINAL_TABLES}/92_qc_required_vars.csv
*   - ${FINAL_TABLES}/92_participant_flow.csv
*   - ${FINAL_OUT}/92_manifest_and_qc.txt
*
* Dependencies:
*   - 90_config_final_pe.do
*   - 91_build_locked_analysis_file.do
*
* Guardrails:
*   - Fails if the locked analysis dataset is missing
*   - Checks all required variables before exporting QC
*
* Main analysis steps:
*   1. Build a file manifest
*   2. Load locked analysis file
*   3. Summarize required variable missingness and nonmissing counts
*   4. Export participant-flow counts for manuscript reporting
*
* Export steps:
*   - CSV manifest
*   - CSV variable QC table
*   - Text summary
*
* Completion:
*   - Prints manifest/QC export paths
**************************************************************************/

do "/Volumes/DallalMinix/ramseymini/Library/CloudStorage/OneDrive-ThomasJeffersonUniversityanditsAffiliates/_Enterprise/stats/Pulmonary Embolism/Locked/do/final_model/90_config_final_pe.do"

capture log close _all
log using "${FINAL_LOG}/92_manifest_and_qc.log", replace text

tempfile manifest qcvars flow
tempname mh qh fh

postfile `mh' str80 file_tag str244 file_path byte exists using "`manifest'", replace
post `mh' ("source_clean") ("${SOURCE_DTA}/nsqip_puf20_24_combined_clean.dta") (fileexists("${SOURCE_DTA}/nsqip_puf20_24_combined_clean.dta"))
post `mh' ("locked_analysis") ("${FINAL_OUT}/91_locked_analysis_file_final_pe.dta") (fileexists("${FINAL_OUT}/91_locked_analysis_file_final_pe.dta"))
post `mh' ("source_project_state") ("${SOURCE_PROJECT_STATE}") (fileexists("${SOURCE_PROJECT_STATE}"))
postclose `mh'

final_need_file, file("${FINAL_OUT}/91_locked_analysis_file_final_pe.dta") tag("locked analysis dataset")
use "${FINAL_OUT}/91_locked_analysis_file_final_pe.dta", clear

local req_vars locked_row_id pe dvt_postop vte_composite puf_year train test age_cat bmi_cat discancr_b optime_cat los3 ///
    asaclas_id fnstatus2_id inout_id workrvu_clean wrvu_s1 wrvu_s2 wrvu_s3 wrvu_s4 ///
    cpt3 cpt3_pool readm_when reop_when sex3 steroid_b hxchf_b dialysis_b

postfile `qh' str40 variable long n_total long n_nonmissing long n_missing double pct_missing using "`qcvars'", replace
quietly count
local n_total = r(N)

foreach v of local req_vars {
    final_need_var, var(`v')
    quietly count if !missing(`v')
    local n_nonmissing = r(N)
    local n_missing = `n_total' - `n_nonmissing'
    post `qh' ("`v'") (`n_total') (`n_nonmissing') (`n_missing') (100 * `n_missing' / `n_total')
}
postclose `qh'

tempvar discharge_cc update_cc dvt_cc vte_cc
gen byte `discharge_cc' = train == 1 & !missing(pe, age_cat, bmi_cat, discancr_b, optime_cat, los3, asaclas_id, fnstatus2_id, inout_id, wrvu_s1, wrvu_s2, wrvu_s3, wrvu_s4, cpt3_pool)
replace `discharge_cc' = 2 if test == 1 & !missing(pe, age_cat, bmi_cat, discancr_b, optime_cat, los3, asaclas_id, fnstatus2_id, inout_id, wrvu_s1, wrvu_s2, wrvu_s3, wrvu_s4, cpt3_pool)
gen byte `update_cc' = train == 1 & !missing(pe, age_cat, bmi_cat, discancr_b, optime_cat, los3, asaclas_id, fnstatus2_id, inout_id, wrvu_s1, wrvu_s2, wrvu_s3, wrvu_s4, cpt3_pool, readm_when, reop_when)
replace `update_cc' = 2 if test == 1 & !missing(pe, age_cat, bmi_cat, discancr_b, optime_cat, los3, asaclas_id, fnstatus2_id, inout_id, wrvu_s1, wrvu_s2, wrvu_s3, wrvu_s4, cpt3_pool, readm_when, reop_when)
gen byte `dvt_cc' = train == 1 & !missing(dvt_postop, age_cat, bmi_cat, discancr_b, optime_cat, los3, asaclas_id, fnstatus2_id, inout_id, wrvu_s1, wrvu_s2, wrvu_s3, wrvu_s4, cpt3_pool)
replace `dvt_cc' = 2 if test == 1 & !missing(dvt_postop, age_cat, bmi_cat, discancr_b, optime_cat, los3, asaclas_id, fnstatus2_id, inout_id, wrvu_s1, wrvu_s2, wrvu_s3, wrvu_s4, cpt3_pool)
gen byte `vte_cc' = train == 1 & !missing(vte_composite, age_cat, bmi_cat, discancr_b, optime_cat, los3, asaclas_id, fnstatus2_id, inout_id, wrvu_s1, wrvu_s2, wrvu_s3, wrvu_s4, cpt3_pool)
replace `vte_cc' = 2 if test == 1 & !missing(vte_composite, age_cat, bmi_cat, discancr_b, optime_cat, los3, asaclas_id, fnstatus2_id, inout_id, wrvu_s1, wrvu_s2, wrvu_s3, wrvu_s4, cpt3_pool)

postfile `fh' str32 flow_step str80 definition long n long pe_events long dvt_events long vte_events using "`flow'", replace
quietly count
local flow_n = r(N)
quietly count if pe == 1
local flow_pe = r(N)
quietly count if dvt_postop == 1
local flow_dvt = r(N)
quietly count if vte_composite == 1
local flow_vte = r(N)
post `fh' ("all_locked_cases") ("All 2020-2024 locked cases after locked data build") (`flow_n') (`flow_pe') (`flow_dvt') (`flow_vte')

quietly count if train == 1
local flow_n = r(N)
quietly count if train == 1 & pe == 1
local flow_pe = r(N)
quietly count if train == 1 & dvt_postop == 1
local flow_dvt = r(N)
quietly count if train == 1 & vte_composite == 1
local flow_vte = r(N)
post `fh' ("development_all") ("Temporal development cohort: puf_year 2020-2023") (`flow_n') (`flow_pe') (`flow_dvt') (`flow_vte')

quietly count if test == 1
local flow_n = r(N)
quietly count if test == 1 & pe == 1
local flow_pe = r(N)
quietly count if test == 1 & dvt_postop == 1
local flow_dvt = r(N)
quietly count if test == 1 & vte_composite == 1
local flow_vte = r(N)
post `fh' ("validation_all") ("Temporal validation cohort: puf_year 2024") (`flow_n') (`flow_pe') (`flow_dvt') (`flow_vte')

quietly count if `discharge_cc' == 1
local flow_n = r(N)
quietly count if `discharge_cc' == 1 & pe == 1
local flow_pe = r(N)
post `fh' ("development_discharge_cc") ("Development complete-case cohort for locked discharge PE model") (`flow_n') (`flow_pe') (.) (.)

quietly count if `discharge_cc' == 2
local flow_n = r(N)
quietly count if `discharge_cc' == 2 & pe == 1
local flow_pe = r(N)
post `fh' ("validation_discharge_cc") ("Validation complete-case cohort for locked discharge PE model") (`flow_n') (`flow_pe') (.) (.)

quietly count if `update_cc' == 1
local flow_n = r(N)
quietly count if `update_cc' == 1 & pe == 1
local flow_pe = r(N)
post `fh' ("development_update_cc") ("Development complete-case cohort for locked update PE model") (`flow_n') (`flow_pe') (.) (.)

quietly count if `update_cc' == 2
local flow_n = r(N)
quietly count if `update_cc' == 2 & pe == 1
local flow_pe = r(N)
post `fh' ("validation_update_cc") ("Validation complete-case cohort for locked update PE model") (`flow_n') (`flow_pe') (.) (.)

quietly count if `dvt_cc' == 1
local flow_n = r(N)
quietly count if `dvt_cc' == 1 & dvt_postop == 1
local flow_dvt = r(N)
post `fh' ("development_dvt_cc") ("Development complete-case cohort for postoperative DVT secondary model") (`flow_n') (.) (`flow_dvt') (.)

quietly count if `dvt_cc' == 2
local flow_n = r(N)
quietly count if `dvt_cc' == 2 & dvt_postop == 1
local flow_dvt = r(N)
post `fh' ("validation_dvt_cc") ("Validation complete-case cohort for postoperative DVT secondary model") (`flow_n') (.) (`flow_dvt') (.)

quietly count if `vte_cc' == 1
local flow_n = r(N)
quietly count if `vte_cc' == 1 & vte_composite == 1
local flow_vte = r(N)
post `fh' ("development_vte_cc") ("Development complete-case cohort for VTE composite secondary model") (`flow_n') (.) (.) (`flow_vte')

quietly count if `vte_cc' == 2
local flow_n = r(N)
quietly count if `vte_cc' == 2 & vte_composite == 1
local flow_vte = r(N)
post `fh' ("validation_vte_cc") ("Validation complete-case cohort for VTE composite secondary model") (`flow_n') (.) (.) (`flow_vte')
postclose `fh'

preserve
    use "`manifest'", clear
    export delimited using "${FINAL_TABLES}/92_manifest_files.csv", replace
restore

preserve
    use "`qcvars'", clear
    export delimited using "${FINAL_TABLES}/92_qc_required_vars.csv", replace
restore

preserve
    use "`flow'", clear
    export delimited using "${FINAL_TABLES}/92_participant_flow.csv", replace
restore

capture file close manifestfh
file open manifestfh using "${FINAL_OUT}/92_manifest_and_qc.txt", write replace
file write manifestfh "Locked PE final model manifest and QC" _n
file write manifestfh "Created: `c(current_date)' `c(current_time)'" _n
file write manifestfh "Locked analysis dataset: ${FINAL_OUT}/91_locked_analysis_file_final_pe.dta" _n
file write manifestfh "Manifest CSV: ${FINAL_TABLES}/92_manifest_files.csv" _n
file write manifestfh "QC CSV: ${FINAL_TABLES}/92_qc_required_vars.csv" _n
file write manifestfh "Participant flow CSV: ${FINAL_TABLES}/92_participant_flow.csv" _n
file close manifestfh

di as text "Wrote ${FINAL_TABLES}/92_manifest_files.csv"
di as text "Wrote ${FINAL_TABLES}/92_qc_required_vars.csv"
di as text "Wrote ${FINAL_TABLES}/92_participant_flow.csv"
di as text "92_manifest_and_qc.do complete."
log close
