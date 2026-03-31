version 19.5
clear all
set more off
set varabbrev off
set linesize 255

/**************************************************************************
* 99_subgroup_calibration_and_heterogeneity.do
*
* Purpose:
*   Summarize subgroup calibration and heterogeneity for the locked
*   discharge and update models.
*
* Inputs:
*   - ${FINAL_OUT}/91_locked_analysis_file_final_pe.dta
*   - ${FINAL_OUT}/96_final_discharge_predictions_2024.dta
*   - ${FINAL_OUT}/97_final_update_predictions_2024.dta
*
* Outputs:
*   - ${FINAL_TABLES}/99_subgroup_calibration_and_heterogeneity.csv
*
* Dependencies:
*   - 90_config_final_pe.do
*   - 91_build_locked_analysis_file.do
*   - 96_fit_final_discharge_model.do
*   - 97_fit_final_update_model.do
*
* Guardrails:
*   - Uses explicit subgroup definitions already present in the data
*   - Merges only on locked_row_id
*
* Main analysis steps:
*   1. Merge 2024 predictions onto subgroup metadata
*   2. Evaluate subgroup calibration for discharge and update models
*   3. Export long-format subgroup summary
*
* Export steps:
*   - Long-format subgroup results CSV
*
* Completion:
*   - Prints export path
**************************************************************************/

do "/Volumes/DallalMinix/ramseymini/Library/CloudStorage/OneDrive-ThomasJeffersonUniversityanditsAffiliates/_Enterprise/stats/Pulmonary Embolism/Locked/do/final_model/90_config_final_pe.do"

capture log close _all
log using "${FINAL_LOG}/99_subgroup_calibration_and_heterogeneity.log", replace text

final_need_file, file("${FINAL_OUT}/91_locked_analysis_file_final_pe.dta") tag("locked analysis dataset")
final_need_file, file("${FINAL_OUT}/96_final_discharge_predictions_2024.dta") tag("discharge predictions")
final_need_file, file("${FINAL_OUT}/97_final_update_predictions_2024.dta") tag("update predictions")

use "${FINAL_OUT}/91_locked_analysis_file_final_pe.dta", clear
keep if test == 1
keep locked_row_id pe age_cat sex3 inout_id

merge 1:1 locked_row_id using "${FINAL_OUT}/96_final_discharge_predictions_2024.dta", keep(master match) nogen
merge 1:1 locked_row_id using "${FINAL_OUT}/97_final_update_predictions_2024.dta", keep(master match) nogen

tempfile subgrp
tempname posth
postfile `posth' str12 model str12 subgroup_var str20 subgroup_level long n long pe_events double mean_pred auc brier logloss cint cslope using "`subgrp'", replace

foreach pair in "discharge p_discharge_locked" "update p_update_locked" {
    local model : word 1 of `pair'
    local pvar : word 2 of `pair'

    foreach subgroup in age_cat sex3 inout_id {
        quietly levelsof `subgroup' if !missing(`subgroup', `pvar', pe), local(levels)
        foreach lev of local levels {
            tempvar sg_ok
            gen byte `sg_ok' = (`subgroup' == `lev') & !missing(pe, `pvar')
            quietly count if `sg_ok'
            local n = r(N)
            quietly count if `sg_ok' & pe == 1
            local pe_events = r(N)
            local non_events = `n' - `pe_events'
            quietly summarize `pvar' if `sg_ok', meanonly
            local mean_pred = r(mean)
            if `n' == 0 | `pe_events' == 0 | `non_events' == 0 {
                post `posth' ("`model'") ("`subgroup'") ("`lev'") (`n') (`pe_events') (`mean_pred') (.) (.) (.) (.) (.)
            }
            else {
                quietly final_eval_binary, outcome(pe) pvar(`pvar') sample(`sg_ok')
                post `posth' ("`model'") ("`subgroup'") ("`lev'") (`n') (`pe_events') (`mean_pred') (r(auc)) (r(brier)) (r(logloss)) (r(cint)) (r(cslope))
            }
            drop `sg_ok'
        }
    }
}
postclose `posth'

use "`subgrp'", clear
export delimited using "${FINAL_TABLES}/99_subgroup_calibration_and_heterogeneity.csv", replace

di as text "Wrote ${FINAL_TABLES}/99_subgroup_calibration_and_heterogeneity.csv"
di as text "99_subgroup_calibration_and_heterogeneity.do complete."
log close
