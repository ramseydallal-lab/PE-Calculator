version 19.5
clear all
set more off
set varabbrev off
set linesize 255

/**************************************************************************
* 97_fit_final_update_model.do
*
* Purpose:
*   Fit the locked final update model and export coefficients,
*   predictions, and validation metrics.
*
* Inputs:
*   - ${FINAL_OUT}/91_locked_analysis_file_final_pe.dta
*
* Outputs:
*   - ${FINAL_STER}/97_final_update_model.ster
*   - ${FINAL_OUT}/97_final_update_predictions_2024.dta
*   - ${FINAL_OUT}/97_final_update_model_metadata.txt
*   - ${FINAL_TABLES}/97_final_update_performance.csv
*   - ${FINAL_TABLES}/97_final_update_coefficients.csv
*
* Dependencies:
*   - 90_config_final_pe.do
*   - 91_build_locked_analysis_file.do
*
* Guardrails:
*   - Requires all final update predictors to be present
*   - Uses POD0-inclusive event bins from the locked analysis file
*   - Reuses saved .ster and prediction artifacts when available
*
* Main analysis steps:
*   1. Load locked analysis file
*   2. Fit final update model on 2020-2023 complete cases
*   3. Save model and score 2024
*   4. Export performance and coefficients
*
* Export steps:
*   - .ster model
*   - 2024 prediction dataset
*   - Performance CSV
*   - Coefficient CSV
*
* Completion:
*   - Prints export paths
**************************************************************************/

do "/Volumes/DallalMinix/ramseymini/Library/CloudStorage/OneDrive-ThomasJeffersonUniversityanditsAffiliates/_Enterprise/stats/Pulmonary Embolism/Locked/do/final_model/90_config_final_pe.do"

capture log close _all
log using "${FINAL_LOG}/97_fit_final_update_model.log", replace text

local force_refit 0
local metadata_file "${FINAL_OUT}/97_final_update_model_metadata.txt"
local model_spec_tag "97_final_update_v20260328"

final_need_file, file("${FINAL_OUT}/91_locked_analysis_file_final_pe.dta") tag("locked analysis dataset")
use locked_row_id pe puf_year train test age_cat bmi_cat discancr_b optime_cat los3 asaclas_id fnstatus2_id inout_id ///
    workrvu_clean wrvu_s1 wrvu_s2 wrvu_s3 wrvu_s4 cpt3_pool readm_when reop_when ///
    using "${FINAL_OUT}/91_locked_analysis_file_final_pe.dta", clear

foreach v in locked_row_id pe train test age_cat bmi_cat discancr_b optime_cat los3 asaclas_id fnstatus2_id inout_id ///
    wrvu_s1 wrvu_s2 wrvu_s3 wrvu_s4 cpt3_pool readm_when reop_when {
    final_need_var, var(`v')
}

tempvar fit_ok eval_ok
gen byte `fit_ok' = train == 1 & !missing(pe, age_cat, bmi_cat, discancr_b, optime_cat, los3, asaclas_id, fnstatus2_id, inout_id, ///
    wrvu_s1, wrvu_s2, wrvu_s3, wrvu_s4, cpt3_pool, readm_when, reop_when)
gen byte `eval_ok' = test == 1 & !missing(pe, age_cat, bmi_cat, discancr_b, optime_cat, los3, asaclas_id, fnstatus2_id, inout_id, ///
    wrvu_s1, wrvu_s2, wrvu_s3, wrvu_s4, cpt3_pool, readm_when, reop_when)

quietly count if `fit_ok'
if r(N) == 0 {
    di as error "FATAL: no complete-case training sample for final update model"
    exit 459
}
quietly count if `eval_ok'
if r(N) == 0 {
    di as error "FATAL: no scorable 2024 validation sample for final update model"
    exit 459
}

local FINAL_UP "i.age_cat i.bmi_cat i.discancr_b i.optime_cat i.los3 i.asaclas_id i.fnstatus2_id i.inout_id c.wrvu_s1 c.wrvu_s2 c.wrvu_s3 c.wrvu_s4 i.cpt3_pool i.readm_when i.reop_when"
local reused_saved_predictions 0

tempfile perf
tempname posth
postfile `posth' str24 model long n_train long n_test long pe_test double auc brier logloss cint cslope using "`perf'", replace
quietly count if `fit_ok'
local n_train = r(N)
quietly count if `eval_ok'
local n_test = r(N)
quietly count if `eval_ok' & pe == 1
local pe_test = r(N)

if `force_refit' == 0 & fileexists("${FINAL_STER}/97_final_update_model.ster") {
    if !fileexists("`metadata_file'") {
        local force_refit 1
    }
    else {
        capture file close metafh
        file open metafh using "`metadata_file'", read
        file read metafh line1
        file read metafh line2
        file read metafh line3
        file read metafh line4
        file close metafh

        local metadata_ok 1
        if "`line1'" != "spec_tag=`model_spec_tag'" local metadata_ok 0
        if "`line2'" != "n_train=`n_train'" local metadata_ok 0
        if "`line3'" != "n_test=`n_test'" local metadata_ok 0
        if "`line4'" != "pe_test=`pe_test'" local metadata_ok 0

        if `metadata_ok' == 0 local force_refit 1
    }
}

if `force_refit' == 0 & fileexists("${FINAL_STER}/97_final_update_model.ster") {
    estimates use "${FINAL_STER}/97_final_update_model.ster"

    if fileexists("${FINAL_OUT}/97_final_update_predictions_2024.dta") {
        preserve
            use "${FINAL_OUT}/97_final_update_predictions_2024.dta", clear
            capture confirm variable pe
            local pred_file_ok = (_rc == 0)
            capture confirm variable p_update_locked
            if _rc local pred_file_ok = 0
            if `pred_file_ok' == 1 {
                quietly count
                local pred_n = r(N)
                quietly count if pe == 1
                local pred_pe = r(N)
                if `pred_n' == `n_test' & `pred_pe' == `pe_test' {
                    local reused_saved_predictions 1
                }
            }
            if `reused_saved_predictions' == 1 {
                gen byte eval_ok_saved = 1
                quietly final_eval_binary, outcome(pe) pvar(p_update_locked) sample(eval_ok_saved)
                local auc = r(auc)
                local brier = r(brier)
                local logloss = r(logloss)
                local cint = r(cint)
                local cslope = r(cslope)
            }
        restore
    }
    if `reused_saved_predictions' == 0 {
        capture drop p_update_locked
        predict double p_update_locked if `eval_ok', pr
        quietly final_eval_binary, outcome(pe) pvar(p_update_locked) sample(`eval_ok')
        local auc = r(auc)
        local brier = r(brier)
        local logloss = r(logloss)
        local cint = r(cint)
        local cslope = r(cslope)
    }
}
else {
    quietly logit pe `FINAL_UP' if `fit_ok'
    estimates store final_update_locked
    estimates save "${FINAL_STER}/97_final_update_model.ster", replace

    capture drop p_update_locked
    predict double p_update_locked if `eval_ok', pr
    quietly final_eval_binary, outcome(pe) pvar(p_update_locked) sample(`eval_ok')
    local auc = r(auc)
    local brier = r(brier)
    local logloss = r(logloss)
    local cint = r(cint)
    local cslope = r(cslope)
}

post `posth' ("final_update_locked") (`n_train') (`n_test') (`pe_test') (`auc') (`brier') (`logloss') (`cint') (`cslope')
postclose `posth'

preserve
    use "`perf'", clear
    export delimited using "${FINAL_TABLES}/97_final_update_performance.csv", replace
restore

preserve
    if `reused_saved_predictions' == 1 {
        use "${FINAL_OUT}/97_final_update_predictions_2024.dta", clear
        export delimited using "${FINAL_TMP}/97_final_update_predictions_2024.csv", replace
        save "${FINAL_OUT}/97_final_update_predictions_2024.dta", replace
    }
    else {
        keep if `eval_ok'
        keep locked_row_id pe puf_year p_update_locked readm_when reop_when age_cat bmi_cat discancr_b optime_cat los3 asaclas_id fnstatus2_id inout_id workrvu_clean cpt3_pool
        export delimited using "${FINAL_TMP}/97_final_update_predictions_2024.csv", replace
        save "${FINAL_OUT}/97_final_update_predictions_2024.dta", replace
    }
restore

estimates use "${FINAL_STER}/97_final_update_model.ster"
final_export_betas, using("${FINAL_TABLES}/97_final_update_coefficients.csv") modelname("final_update_locked")

capture file close metafh
file open metafh using "`metadata_file'", write replace
file write metafh "spec_tag=`model_spec_tag'" _n
file write metafh "n_train=`n_train'" _n
file write metafh "n_test=`n_test'" _n
file write metafh "pe_test=`pe_test'" _n
file close metafh

di as text "Wrote ${FINAL_STER}/97_final_update_model.ster"
di as text "Wrote ${FINAL_OUT}/97_final_update_predictions_2024.dta"
di as text "Wrote `metadata_file'"
di as text "Wrote ${FINAL_TABLES}/97_final_update_performance.csv"
di as text "Wrote ${FINAL_TABLES}/97_final_update_coefficients.csv"
di as text "97_fit_final_update_model.do complete."
log close
