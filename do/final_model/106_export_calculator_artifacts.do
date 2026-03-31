version 19.5
clear all
set more off
set varabbrev off
set linesize 255

/**************************************************************************
* 106_export_calculator_artifacts.do
*
* Purpose:
*   Export calculator-facing coefficient and metadata artifacts.
*
* Inputs:
*   - ${FINAL_OUT}/91_locked_analysis_file_final_pe.dta
*   - ${FINAL_TABLES}/96_final_discharge_coefficients.csv
*   - ${FINAL_TABLES}/97_final_update_coefficients.csv
*   - ${FINAL_TABLES}/96_final_discharge_performance.csv
*   - ${FINAL_TABLES}/97_final_update_performance.csv
*   - ${FINAL_TABLES}/105_dvt_secondary_coefficients.csv
*   - ${FINAL_TABLES}/105_vte_secondary_coefficients.csv
*   - ${FINAL_TABLES}/105_dvt_vte_secondary_model_performance.csv
*
* Outputs:
*   - ${FINAL_OUT}/106_calculator_coefficients_discharge.csv
*   - ${FINAL_OUT}/106_calculator_coefficients_update.csv
*   - ${FINAL_OUT}/106_calculator_coefficients_dvt.csv
*   - ${FINAL_OUT}/106_calculator_coefficients_vte.csv
*   - ${FINAL_OUT}/106_calculator_knots.csv
*   - ${FINAL_OUT}/106_calculator_cpt3_pool_levels.csv
*   - ${FINAL_OUT}/106_calculator_model_summary.csv
*   - ${FINAL_OUT}/106_calculator_variable_manifest.csv
*   - ${FINAL_OUT}/106_calculator_input_dictionary.csv
*   - ${FINAL_OUT}/106_calculator_clinician_guidance.txt
*   - ${FINAL_OUT}/106_calculator_metadata.txt
*
* Dependencies:
*   - 90_config_final_pe.do
*   - 91_build_locked_analysis_file.do
*   - 96_fit_final_discharge_model.do
*   - 97_fit_final_update_model.do
*
* Guardrails:
*   - Recomputes spline-knot metadata from the locked analysis file
*   - Exports only deterministic locked artifacts
*
* Main analysis steps:
*   1. Copy coefficient tables to calculator-named exports
*   2. Export spline-knot metadata
*   3. Export CPT3 pooled-level frequency table
*   4. Export combined model-summary and variable-manifest tables
*   5. Export clinician-facing input dictionary and guidance text
*
* Export steps:
*   - Calculator coefficient and metadata files
*
* Completion:
*   - Prints export paths
**************************************************************************/

do "/Volumes/DallalMinix/ramseymini/Library/CloudStorage/OneDrive-ThomasJeffersonUniversityanditsAffiliates/_Enterprise/stats/Pulmonary Embolism/Locked/do/final_model/90_config_final_pe.do"

capture log close _all
log using "${FINAL_LOG}/106_export_calculator_artifacts.log", replace text

final_need_file, file("${FINAL_OUT}/91_locked_analysis_file_final_pe.dta") tag("locked analysis dataset")
final_need_file, file("${FINAL_TABLES}/96_final_discharge_coefficients.csv") tag("discharge coefficients")
final_need_file, file("${FINAL_TABLES}/97_final_update_coefficients.csv") tag("update coefficients")
final_need_file, file("${FINAL_TABLES}/96_final_discharge_performance.csv") tag("discharge performance")
final_need_file, file("${FINAL_TABLES}/97_final_update_performance.csv") tag("update performance")
final_need_file, file("${FINAL_TABLES}/105_dvt_secondary_coefficients.csv") tag("DVT secondary coefficients")
final_need_file, file("${FINAL_TABLES}/105_vte_secondary_coefficients.csv") tag("VTE secondary coefficients")
final_need_file, file("${FINAL_TABLES}/105_dvt_vte_secondary_model_performance.csv") tag("DVT/VTE secondary performance")

import delimited using "${FINAL_TABLES}/96_final_discharge_coefficients.csv", clear varnames(1)
export delimited using "${FINAL_OUT}/106_calculator_coefficients_discharge.csv", replace

import delimited using "${FINAL_TABLES}/97_final_update_coefficients.csv", clear varnames(1)
export delimited using "${FINAL_OUT}/106_calculator_coefficients_update.csv", replace

import delimited using "${FINAL_TABLES}/105_dvt_secondary_coefficients.csv", clear varnames(1)
export delimited using "${FINAL_OUT}/106_calculator_coefficients_dvt.csv", replace

import delimited using "${FINAL_TABLES}/105_vte_secondary_coefficients.csv", clear varnames(1)
export delimited using "${FINAL_OUT}/106_calculator_coefficients_vte.csv", replace

use "${FINAL_OUT}/91_locked_analysis_file_final_pe.dta", clear
preserve
    keep train workrvu_clean
    keep if train == 1 & !missing(workrvu_clean)
    centile workrvu_clean, centile(25 50 75)
    local k1 = r(c_1)
    local k2 = r(c_2)
    local k3 = r(c_3)
restore

clear
set obs 3
gen str16 knot_name = ""
gen double knot_value = .
replace knot_name = "knot_25" in 1
replace knot_name = "knot_50" in 2
replace knot_name = "knot_75" in 3
replace knot_value = `k1' in 1
replace knot_value = `k2' in 2
replace knot_value = `k3' in 3
export delimited using "${FINAL_OUT}/106_calculator_knots.csv", replace

use train cpt3_pool pe using "${FINAL_OUT}/91_locked_analysis_file_final_pe.dta", clear
preserve
    keep if train == 1 & !missing(cpt3_pool)
    collapse (count) n=pe, by(cpt3_pool)
    gsort -n
    export delimited using "${FINAL_OUT}/106_calculator_cpt3_pool_levels.csv", replace
restore

tempfile perf96 perf97 perf105 model_manifest

import delimited using "${FINAL_TABLES}/96_final_discharge_performance.csv", clear varnames(1)
gen str24 calculator_model = "pe_discharge"
gen str20 calculator_role = "primary"
gen str24 outcome = "pe"
gen long events_train = .
gen long events_test = pe_test
save "`perf96'", replace

import delimited using "${FINAL_TABLES}/97_final_update_performance.csv", clear varnames(1)
gen str24 calculator_model = "pe_update"
gen str20 calculator_role = "primary"
gen str24 outcome = "pe"
gen long events_train = .
gen long events_test = pe_test
save "`perf97'", replace

import delimited using "${FINAL_TABLES}/105_dvt_vte_secondary_model_performance.csv", clear varnames(1)
gen str24 calculator_model = ""
replace calculator_model = "dvt_discharge" if outcome == "postop_dvt"
replace calculator_model = "vte_discharge" if outcome == "vte_composite"
gen str20 calculator_role = "secondary"
append using "`perf96'"
append using "`perf97'"
capture confirm variable pe_test
if _rc gen long pe_test = .
order calculator_model calculator_role model outcome n_train n_test events_train events_test pe_test auc brier logloss cint cslope
export delimited using "${FINAL_OUT}/106_calculator_model_summary.csv", replace

import delimited using "${FINAL_TABLES}/96_final_discharge_coefficients.csv", clear varnames(1)
gen str24 calculator_model = "pe_discharge"
gen str20 calculator_role = "primary"
save "`model_manifest'", replace

import delimited using "${FINAL_TABLES}/97_final_update_coefficients.csv", clear varnames(1)
gen str24 calculator_model = "pe_update"
gen str20 calculator_role = "primary"
append using "`model_manifest'"
save "`model_manifest'", replace

import delimited using "${FINAL_TABLES}/105_dvt_secondary_coefficients.csv", clear varnames(1)
gen str24 calculator_model = "dvt_discharge"
gen str20 calculator_role = "secondary"
append using "`model_manifest'"
save "`model_manifest'", replace

import delimited using "${FINAL_TABLES}/105_vte_secondary_coefficients.csv", clear varnames(1)
gen str24 calculator_model = "vte_discharge"
gen str20 calculator_role = "secondary"
append using "`model_manifest'"
order calculator_model calculator_role model term coef
export delimited using "${FINAL_OUT}/106_calculator_variable_manifest.csv", replace

clear
input ///
str24 calculator_mode str20 display_group byte display_order str40 clinical_input str48 internal_term ///
str160 definition str80 allowed_values byte calculator_required str40 available_when str120 notes
"discharge_pe" "baseline" 1 "Age at operation" "age_cat" "<50 years=1; 50-64 years=2; 65-74 years=3; >=75 years=4" "Numeric age in years" 1 "at discharge" "Clinician enters age; app maps to locked age categories."
"discharge_pe" "baseline" 2 "Body mass index" "bmi_cat" "<30.0=1; 30.0-39.9=2; 40.0-49.9=3; >=50.0=4" "Numeric BMI in kg/m^2" 1 "at discharge" "Clinician enters BMI; app maps to locked BMI categories."
"discharge_pe" "baseline" 3 "Disseminated cancer" "discancr_b" "Binary disseminated cancer indicator used in locked model" "No; Yes" 1 "at discharge" "Use a plain yes/no clinician-facing question."
"discharge_pe" "baseline" 4 "Operative time" "optime_cat" "<60 min=1; 60-119 min=2; 120-179 min=3; 180-239 min=4; >=240 min=5" "Numeric minutes" 1 "at discharge" "Clinician enters total operative minutes."
"discharge_pe" "baseline" 5 "Postoperative length of stay" "los3" "0-3 days=1; 4-6 days=2; >=7 days=3" "Numeric postoperative days" 1 "at discharge" "Use only at discharge; not for preoperative counseling."
"discharge_pe" "baseline" 6 "ASA physical status" "asaclas_id" "ASA 1-5 plus none assigned/unknown category used in locked data" "ASA 1; ASA 2; ASA 3; ASA 4; ASA 5; Unknown" 1 "at discharge" "Display clinician-readable ASA labels."
"discharge_pe" "baseline" 7 "Inpatient vs outpatient case" "inout_id" "Reference=inpatient; modeled outpatient category" "Inpatient; Outpatient" 1 "at discharge" "Use the actual index-case status."
"discharge_pe" "procedure" 8 "Procedure / CPT selection" "cpt3_pool + wrvu spline" "Procedure selection drives pooled CPT-3 family and work RVU spline terms" "Procedure search or CPT lookup" 1 "at discharge" "Do not ask clinicians to enter pooled CPT family directly."
"update_pe" "events" 9 "Readmission timing" "readm_when" "No readmission=0; POD 0-3=1; POD 4-7=2; POD 8-14=3; POD 15-30=4" "None; 0-3 days; 4-7 days; 8-14 days; 15-30 days" 1 "after discharge" "Use first readmission within 30 days."
"update_pe" "events" 10 "Reoperation timing" "reop_when" "No reoperation=0; POD 0-3=1; POD 4-7=2; POD 8-14=3; POD 15-30=4" "None; 0-3 days; 4-7 days; 8-14 days; 15-30 days" 1 "after discharge" "Use first reoperation within 30 days."
"discharge_pe" "omitted" 11 "Functional status" "fnstatus2_id" "Locked research model included this term, but simplified bedside calculator omits it" "Independent; Partially dependent; Totally dependent; Unknown" 0 "not shown in app" "Omitted intentionally for usability; manuscript model remains unchanged."
end
export delimited using "${FINAL_OUT}/106_calculator_input_dictionary.csv", replace

capture file close calcguide
file open calcguide using "${FINAL_OUT}/106_calculator_clinician_guidance.txt", write replace
file write calcguide "Simplified clinician-facing calculator guidance" _n
file write calcguide "Created: `c(current_date)' `c(current_time)'" _n
file write calcguide "Use clinically entered concepts only: age, BMI, disseminated cancer, operative time, postoperative length of stay at discharge, ASA class, inpatient/outpatient status, and procedure selection." _n
file write calcguide "For the update model, also record timing of first readmission and first reoperation within 30 days." _n
file write calcguide "The bedside calculator omits baseline functional status to improve usability; the locked research manuscript model still includes that term." _n
file write calcguide "Predicted risk reflects observed ACS-NSQIP outcomes under 2020-2024 care patterns and may be influenced by thromboprophylaxis or preventive care not fully captured in the source data." _n
file write calcguide "Low predicted risk does not necessarily equal low untreated biologic thrombosis risk." _n
file close calcguide

capture file close calcmeta
file open calcmeta using "${FINAL_OUT}/106_calculator_metadata.txt", write replace
file write calcmeta "Locked PE calculator artifacts" _n
file write calcmeta "Created: `c(current_date)' `c(current_time)'" _n
file write calcmeta "Discharge coefficients: ${FINAL_OUT}/106_calculator_coefficients_discharge.csv" _n
file write calcmeta "Update coefficients: ${FINAL_OUT}/106_calculator_coefficients_update.csv" _n
file write calcmeta "DVT discharge coefficients: ${FINAL_OUT}/106_calculator_coefficients_dvt.csv" _n
file write calcmeta "VTE discharge coefficients: ${FINAL_OUT}/106_calculator_coefficients_vte.csv" _n
file write calcmeta "Spline knots: ${FINAL_OUT}/106_calculator_knots.csv" _n
file write calcmeta "CPT3 pool levels: ${FINAL_OUT}/106_calculator_cpt3_pool_levels.csv" _n
file write calcmeta "Model summary: ${FINAL_OUT}/106_calculator_model_summary.csv" _n
file write calcmeta "Variable manifest: ${FINAL_OUT}/106_calculator_variable_manifest.csv" _n
file write calcmeta "Input dictionary: ${FINAL_OUT}/106_calculator_input_dictionary.csv" _n
file write calcmeta "Clinician guidance: ${FINAL_OUT}/106_calculator_clinician_guidance.txt" _n
file write calcmeta "Current locked PE manuscript models still include fnstatus2_id, but the simplified bedside calculator omits this input because its incremental predictive contribution was negligible in locked discharge ablation testing." _n
file write calcmeta "DVT and VTE exports are discharge-stage secondary models only; no update-stage DVT/VTE model is exported yet." _n
file write calcmeta "The discharge PE model uses spline basis terms wrvu_s1-wrvu_s4 created by mkspline with training quartile knots." _n
file write calcmeta "Procedure entry should be clinician-facing and map internally to pooled CPT-3 family and work RVU terms." _n
file write calcmeta "Observed risk estimates are conditioned on historical NSQIP-era care patterns and incompletely observed prophylaxis exposure." _n
file write calcmeta "TODO: confirm final app-side factor-level label mapping before external release." _n
file close calcmeta

di as text "Wrote calculator artifacts to ${FINAL_OUT}"
di as text "106_export_calculator_artifacts.do complete."
log close
