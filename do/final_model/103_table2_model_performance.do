version 19.5
clear all
set more off
set varabbrev off
set linesize 255

/**************************************************************************
* 103_table2_model_performance.do
*
* Purpose:
*   Consolidate primary model-performance outputs into a manuscript-ready
*   Table 2 CSV and add bootstrap confidence intervals for the final PE
*   models on the fixed 2024 validation cohort.
*
* Inputs:
*   - ${FINAL_TABLES}/96_final_discharge_performance.csv
*   - ${FINAL_TABLES}/97_final_update_performance.csv
*   - ${FINAL_TABLES}/95_ablation_final_discharge.csv
*   - ${FINAL_OUT}/96_final_discharge_predictions_2024.dta
*   - ${FINAL_OUT}/97_final_update_predictions_2024.dta
*
* Outputs:
*   - ${FINAL_TABLES}/103_table2_model_performance.csv
*   - ${FINAL_TABLES}/103_model_performance_bootstrap_summary.csv
*
* Dependencies:
*   - 90_config_final_pe.do
*   - 95_ablation_final_discharge.do
*   - 96_fit_final_discharge_model.do
*   - 97_fit_final_update_model.do
*
* Guardrails:
*   - Reads only locked exported CSVs
*
* Main analysis steps:
*   1. Bootstrap fixed-cohort confidence intervals for final discharge/update
*   2. Import performance CSVs
*   3. Append into a single model-performance table
*
* Export steps:
*   - Table 2 CSV
*   - Bootstrap CI summary CSV
*
* Completion:
*   - Prints export path
**************************************************************************/

do "/Volumes/DallalMinix/ramseymini/Library/CloudStorage/OneDrive-ThomasJeffersonUniversityanditsAffiliates/_Enterprise/stats/Pulmonary Embolism/Locked/do/final_model/90_config_final_pe.do"

capture log close _all
log using "${FINAL_LOG}/103_table2_model_performance.log", replace text

final_need_file, file("${FINAL_TABLES}/96_final_discharge_performance.csv") tag("discharge performance")
final_need_file, file("${FINAL_TABLES}/97_final_update_performance.csv") tag("update performance")
final_need_file, file("${FINAL_TABLES}/95_ablation_final_discharge.csv") tag("ablation comparison")
final_need_file, file("${FINAL_OUT}/96_final_discharge_predictions_2024.dta") tag("discharge predictions")
final_need_file, file("${FINAL_OUT}/97_final_update_predictions_2024.dta") tag("update predictions")

capture program drop final_boot_eval_ci
program define final_boot_eval_ci, rclass
    syntax , DTA(string) PVAR(name) MODELID(string) BREP(integer)

    preserve
        use "`dta'", clear
        keep if !missing(pe, `pvar')
        final_need_var, var(pe)
        final_need_var, var(`pvar')
        tempvar sample_all
        tempfile evalbase bootreps
        gen byte `sample_all' = 1
        tempname bh
        postfile `bh' double auc brier logloss cint cslope using "`bootreps'", replace

        quietly final_eval_binary, outcome(pe) pvar(`pvar') sample(`sample_all')
        local point_auc = r(auc)
        local point_brier = r(brier)
        local point_logloss = r(logloss)
        local point_cint = r(cint)
        local point_cslope = r(cslope)

        save "`evalbase'", replace

        set seed 20260329
        forvalues b = 1/`brep' {
            use "`evalbase'", clear
            bsample
            quietly final_eval_binary, outcome(pe) pvar(`pvar') sample(`sample_all')
            post `bh' (r(auc)) (r(brier)) (r(logloss)) (r(cint)) (r(cslope))
        }
        postclose `bh'

        use "`bootreps'", clear
        centile auc, centile(2.5 97.5)
        local auc_lcl = r(c_1)
        local auc_ucl = r(c_2)
        centile brier, centile(2.5 97.5)
        local brier_lcl = r(c_1)
        local brier_ucl = r(c_2)
        centile logloss, centile(2.5 97.5)
        local logloss_lcl = r(c_1)
        local logloss_ucl = r(c_2)
        centile cint, centile(2.5 97.5)
        local cint_lcl = r(c_1)
        local cint_ucl = r(c_2)
        centile cslope, centile(2.5 97.5)
        local cslope_lcl = r(c_1)
        local cslope_ucl = r(c_2)
    restore

    return local model_id "`modelid'"
    return scalar point_auc = `point_auc'
    return scalar auc_lcl = `auc_lcl'
    return scalar auc_ucl = `auc_ucl'
    return scalar point_brier = `point_brier'
    return scalar brier_lcl = `brier_lcl'
    return scalar brier_ucl = `brier_ucl'
    return scalar point_logloss = `point_logloss'
    return scalar logloss_lcl = `logloss_lcl'
    return scalar logloss_ucl = `logloss_ucl'
    return scalar point_cint = `point_cint'
    return scalar cint_lcl = `cint_lcl'
    return scalar cint_ucl = `cint_ucl'
    return scalar point_cslope = `point_cslope'
    return scalar cslope_lcl = `cslope_lcl'
    return scalar cslope_ucl = `cslope_ucl'
end

local bootstrap_reps 200
tempfile ci_summary
tempname cih
postfile `cih' str24 model_id int bootstrap_reps ///
    double auc auc_lcl auc_ucl ///
    double brier brier_lcl brier_ucl ///
    double logloss logloss_lcl logloss_ucl ///
    double cint cint_lcl cint_ucl ///
    double cslope cslope_lcl cslope_ucl using "`ci_summary'", replace

quietly final_boot_eval_ci, dta("${FINAL_OUT}/96_final_discharge_predictions_2024.dta") pvar(p_discharge_locked) modelid("final_discharge_locked") brep(`bootstrap_reps')
post `cih' ("`r(model_id)'") (`bootstrap_reps') ///
    (r(point_auc)) (r(auc_lcl)) (r(auc_ucl)) ///
    (r(point_brier)) (r(brier_lcl)) (r(brier_ucl)) ///
    (r(point_logloss)) (r(logloss_lcl)) (r(logloss_ucl)) ///
    (r(point_cint)) (r(cint_lcl)) (r(cint_ucl)) ///
    (r(point_cslope)) (r(cslope_lcl)) (r(cslope_ucl))

quietly final_boot_eval_ci, dta("${FINAL_OUT}/97_final_update_predictions_2024.dta") pvar(p_update_locked) modelid("final_update_locked") brep(`bootstrap_reps')
post `cih' ("`r(model_id)'") (`bootstrap_reps') ///
    (r(point_auc)) (r(auc_lcl)) (r(auc_ucl)) ///
    (r(point_brier)) (r(brier_lcl)) (r(brier_ucl)) ///
    (r(point_logloss)) (r(logloss_lcl)) (r(logloss_ucl)) ///
    (r(point_cint)) (r(cint_lcl)) (r(cint_ucl)) ///
    (r(point_cslope)) (r(cslope_lcl)) (r(cslope_ucl))
postclose `cih'

preserve
    use "`ci_summary'", clear
    export delimited using "${FINAL_TABLES}/103_model_performance_bootstrap_summary.csv", replace
restore

import delimited using "${FINAL_TABLES}/96_final_discharge_performance.csv", clear varnames(1)
gen str24 source_table = "96_final_discharge"
tempfile t96
save "`t96'", replace

import delimited using "${FINAL_TABLES}/97_final_update_performance.csv", clear varnames(1)
gen str24 source_table = "97_final_update"
append using "`t96'"
tempfile t97
save "`t97'", replace

import delimited using "${FINAL_TABLES}/95_ablation_final_discharge.csv", clear varnames(1)
gen str24 source_table = "95_ablation"
append using "`t97'"

preserve
    use "`ci_summary'", clear
    rename model_id model
    tempfile ci_merge
    save "`ci_merge'", replace
restore

merge m:1 model using "`ci_merge'", nogen keep(master match)
export delimited using "${FINAL_TABLES}/103_table2_model_performance.csv", replace

di as text "Wrote ${FINAL_TABLES}/103_table2_model_performance.csv"
di as text "Wrote ${FINAL_TABLES}/103_model_performance_bootstrap_summary.csv"
di as text "103_table2_model_performance.do complete."
log close
