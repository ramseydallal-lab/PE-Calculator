version 19.5
clear all
set more off
set varabbrev off
set linesize 255

/**************************************************************************
* 98_missing_data_sensitivity.do
*
* Purpose:
*   Quantify missing-data sensitivity for the locked discharge and update
*   models by contrasting scorable and non-scorable cohorts.
*
* Inputs:
*   - ${FINAL_OUT}/91_locked_analysis_file_final_pe.dta
*
* Outputs:
*   - ${FINAL_TABLES}/98_missing_data_sensitivity.csv
*   - ${FINAL_TABLES}/98_missingness_by_variable.csv
*
* Dependencies:
*   - 90_config_final_pe.do
*   - 91_build_locked_analysis_file.do
*
* Guardrails:
*   - Uses explicit model-specific required-variable lists
*   - Does not impute or overwrite source data
*
* Main analysis steps:
*   1. Define discharge/update scorable cohorts
*   2. Compare scorable vs non-scorable counts and PE rates by year
*   3. Export variable-level missingness
*
* Export steps:
*   - Cohort sensitivity CSV
*   - Variable missingness CSV
*
* Completion:
*   - Prints export paths
**************************************************************************/

do "/Volumes/DallalMinix/ramseymini/Library/CloudStorage/OneDrive-ThomasJeffersonUniversityanditsAffiliates/_Enterprise/stats/Pulmonary Embolism/Locked/do/final_model/90_config_final_pe.do"

capture log close _all
log using "${FINAL_LOG}/98_missing_data_sensitivity.log", replace text

final_need_file, file("${FINAL_OUT}/91_locked_analysis_file_final_pe.dta") tag("locked analysis dataset")
use "${FINAL_OUT}/91_locked_analysis_file_final_pe.dta", clear

tempvar discharge_ok update_ok
gen byte `discharge_ok' = !missing(pe, age_cat, bmi_cat, discancr_b, optime_cat, los3, asaclas_id, fnstatus2_id, inout_id, ///
    wrvu_s1, wrvu_s2, wrvu_s3, wrvu_s4, cpt3_pool)
gen byte `update_ok' = !missing(pe, age_cat, bmi_cat, discancr_b, optime_cat, los3, asaclas_id, fnstatus2_id, inout_id, ///
    wrvu_s1, wrvu_s2, wrvu_s3, wrvu_s4, cpt3_pool, readm_when, reop_when)

tempfile sensitivity missingness
tempname sh mh
postfile `sh' str16 model int puf_year str12 cohort long n long pe_events double pe_rate using "`sensitivity'", replace

foreach model in discharge update {
    local sample_var "`update_ok'"
    if "`model'" == "discharge" {
        local sample_var "`discharge_ok'"
    }
    foreach y in 2020 2021 2022 2023 2024 {
        quietly count if puf_year == `y' & `sample_var'
        local n_score = r(N)
        quietly count if puf_year == `y' & `sample_var' & pe == 1
        local pe_score = r(N)
        local rate_score = .
        if `n_score' > 0 local rate_score = `pe_score' / `n_score'
        post `sh' ("`model'") (`y') ("scorable") (`n_score') (`pe_score') (`rate_score')

        quietly count if puf_year == `y' & !`sample_var'
        local n_noscore = r(N)
        quietly count if puf_year == `y' & !`sample_var' & pe == 1
        local pe_noscore = r(N)
        local rate_noscore = .
        if `n_noscore' > 0 local rate_noscore = `pe_noscore' / `n_noscore'
        post `sh' ("`model'") (`y') ("nonscorable") (`n_noscore') (`pe_noscore') (`rate_noscore')
    }
}
postclose `sh'

postfile `mh' str16 model str40 variable long n_total long n_missing double pct_missing using "`missingness'", replace
quietly count
local n_total = r(N)
foreach v in age_cat bmi_cat discancr_b optime_cat los3 asaclas_id fnstatus2_id inout_id wrvu_s1 wrvu_s2 wrvu_s3 wrvu_s4 cpt3_pool {
    quietly count if missing(`v')
    local n_missing = r(N)
    post `mh' ("discharge") ("`v'") (`n_total') (`n_missing') (100 * `n_missing' / `n_total')
}
foreach v in age_cat bmi_cat discancr_b optime_cat los3 asaclas_id fnstatus2_id inout_id wrvu_s1 wrvu_s2 wrvu_s3 wrvu_s4 cpt3_pool readm_when reop_when {
    quietly count if missing(`v')
    local n_missing = r(N)
    post `mh' ("update") ("`v'") (`n_total') (`n_missing') (100 * `n_missing' / `n_total')
}
postclose `mh'

preserve
    use "`sensitivity'", clear
    export delimited using "${FINAL_TABLES}/98_missing_data_sensitivity.csv", replace
restore

preserve
    use "`missingness'", clear
    export delimited using "${FINAL_TABLES}/98_missingness_by_variable.csv", replace
restore

di as text "Wrote ${FINAL_TABLES}/98_missing_data_sensitivity.csv"
di as text "Wrote ${FINAL_TABLES}/98_missingness_by_variable.csv"
di as text "98_missing_data_sensitivity.do complete."
log close
