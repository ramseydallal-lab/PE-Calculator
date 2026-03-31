version 19.5
clear all
set more off
set varabbrev off
set linesize 255

/**************************************************************************
* 105_etables_supplement.do
*
* Purpose:
*   Create a manifest of supplementary eTables produced by the locked
*   pipeline and generate reviewer-facing secondary DVT/VTE analyses.
*
* Inputs:
*   - ${FINAL_OUT}/91_locked_analysis_file_final_pe.dta
*   - Locked table files created by prior numbered scripts
*
* Outputs:
*   - ${FINAL_TABLES}/105_etables_supplement.csv
*   - ${FINAL_TABLES}/105_dvt_vte_incidence_by_year.csv
*   - ${FINAL_TABLES}/105_dvt_vte_overlap_2024.csv
*   - ${FINAL_TABLES}/105_dvt_vte_secondary_model_performance.csv
*   - ${FINAL_TABLES}/105_dvt_secondary_coefficients.csv
*   - ${FINAL_TABLES}/105_vte_secondary_coefficients.csv
*
* Dependencies:
*   - 90_config_final_pe.do
*   - 91_build_locked_analysis_file.do
*
* Guardrails:
*   - Does not hand-enter manuscript values
*   - Reuses the locked discharge predictor set and temporal split
*   - Avoids rerunning full M0-M6 searches for secondary outcomes
*
* Main analysis steps:
*   1. Enumerate locked supplementary tables
*   2. Record file existence and description
*   3. Summarize DVT and VTE incidence by year
*   4. Summarize 2024 PE/DVT overlap
*   5. Fit lean secondary discharge models for DVT and VTE composite
*   6. Export secondary-outcome coefficient tables for calculator planning
*
* Export steps:
*   - eTable manifest CSV
*   - DVT/VTE descriptive and performance CSVs
*   - DVT/VTE coefficient CSVs
*
* Completion:
*   - Prints export path
**************************************************************************/

do "/Volumes/DallalMinix/ramseymini/Library/CloudStorage/OneDrive-ThomasJeffersonUniversityanditsAffiliates/_Enterprise/stats/Pulmonary Embolism/Locked/do/final_model/90_config_final_pe.do"

capture log close _all
log using "${FINAL_LOG}/105_etables_supplement.log", replace text

final_need_file, file("${FINAL_OUT}/91_locked_analysis_file_final_pe.dta") tag("locked analysis dataset")
use locked_row_id pe dvt_postop vte_composite puf_year train test age_cat bmi_cat discancr_b optime_cat los3 ///
    asaclas_id fnstatus2_id inout_id wrvu_s1 wrvu_s2 wrvu_s3 wrvu_s4 cpt3_pool ///
    using "${FINAL_OUT}/91_locked_analysis_file_final_pe.dta", clear

foreach v in locked_row_id pe dvt_postop vte_composite puf_year train test age_cat bmi_cat discancr_b optime_cat los3 ///
    asaclas_id fnstatus2_id inout_id wrvu_s1 wrvu_s2 wrvu_s3 wrvu_s4 cpt3_pool {
    final_need_var, var(`v')
}

quietly count if !missing(dvt_postop)
if r(N) == 0 {
    di as error "FATAL: dvt_postop is missing for all observations in the locked analysis file"
    exit 459
}

quietly count if !missing(vte_composite)
if r(N) == 0 {
    di as error "FATAL: vte_composite is missing for all observations in the locked analysis file"
    exit 459
}

preserve
    keep if train == 1 | test == 1
    gen byte dvt_nonmissing = !missing(dvt_postop)
    gen byte vte_nonmissing = !missing(vte_composite)
    collapse (count) n_total=locked_row_id (sum) pe_events=pe dvt_events=dvt_postop vte_events=vte_composite ///
        dvt_n=dvt_nonmissing vte_n=vte_nonmissing, by(puf_year)
    gen double pe_rate = pe_events / n_total
    gen double dvt_rate = dvt_events / dvt_n if dvt_n > 0
    gen double vte_rate = vte_events / vte_n if vte_n > 0
    order puf_year n_total pe_events pe_rate dvt_n dvt_events dvt_rate vte_n vte_events vte_rate
    export delimited using "${FINAL_TABLES}/105_dvt_vte_incidence_by_year.csv", replace
restore

preserve
    keep if test == 1 & !missing(dvt_postop)
    gen str24 overlap_group = ""
    replace overlap_group = "Neither" if pe == 0 & dvt_postop == 0
    replace overlap_group = "PE only" if pe == 1 & dvt_postop == 0
    replace overlap_group = "DVT only" if pe == 0 & dvt_postop == 1
    replace overlap_group = "PE and DVT" if pe == 1 & dvt_postop == 1
    collapse (count) n=locked_row_id, by(overlap_group)
    egen long overlap_total = total(n)
    gen double pct_2024 = 100 * n / overlap_total
    order overlap_group n pct_2024
    export delimited using "${FINAL_TABLES}/105_dvt_vte_overlap_2024.csv", replace
restore

local FINAL_DIS "i.age_cat i.bmi_cat i.discancr_b i.optime_cat i.los3 i.asaclas_id i.fnstatus2_id i.inout_id c.wrvu_s1 c.wrvu_s2 c.wrvu_s3 c.wrvu_s4 i.cpt3_pool"

tempvar predictor_ok fit_dvt eval_dvt fit_vte eval_vte p_dvt_locked p_vte_locked
gen byte `predictor_ok' = !missing(age_cat, bmi_cat, discancr_b, optime_cat, los3, asaclas_id, fnstatus2_id, inout_id, ///
    wrvu_s1, wrvu_s2, wrvu_s3, wrvu_s4, cpt3_pool)
gen byte `fit_dvt' = train == 1 & `predictor_ok' == 1 & !missing(dvt_postop)
gen byte `eval_dvt' = test == 1 & `predictor_ok' == 1 & !missing(dvt_postop)
gen byte `fit_vte' = train == 1 & `predictor_ok' == 1 & !missing(vte_composite)
gen byte `eval_vte' = test == 1 & `predictor_ok' == 1 & !missing(vte_composite)

quietly count if `fit_dvt'
if r(N) == 0 {
    di as error "FATAL: no complete-case training sample for postoperative DVT secondary analysis"
    exit 459
}
quietly count if `eval_dvt'
if r(N) == 0 {
    di as error "FATAL: no scorable 2024 validation sample for postoperative DVT secondary analysis"
    exit 459
}

quietly count if `fit_vte'
if r(N) == 0 {
    di as error "FATAL: no complete-case training sample for VTE composite secondary analysis"
    exit 459
}
quietly count if `eval_vte'
if r(N) == 0 {
    di as error "FATAL: no scorable 2024 validation sample for VTE composite secondary analysis"
    exit 459
}

tempfile secondary_perf etables
tempname secpost posth
postfile `secpost' str24 outcome long n_train long n_test long events_train long events_test ///
    double auc brier logloss cint cslope using "`secondary_perf'", replace

quietly logit dvt_postop `FINAL_DIS' if `fit_dvt'
estimates store dvt_secondary_locked
predict double `p_dvt_locked' if `eval_dvt', pr
quietly count if `fit_dvt'
local dvt_n_train = r(N)
quietly count if `eval_dvt'
local dvt_n_test = r(N)
quietly count if `fit_dvt' & dvt_postop == 1
local dvt_events_train = r(N)
quietly count if `eval_dvt' & dvt_postop == 1
local dvt_events_test = r(N)
local dvt_nonevents_test = `dvt_n_test' - `dvt_events_test'
if `dvt_events_test' == 0 | `dvt_nonevents_test' == 0 {
    local dvt_auc = .
    local dvt_brier = .
    local dvt_logloss = .
    local dvt_cint = .
    local dvt_cslope = .
}
else {
    quietly final_eval_binary, outcome(dvt_postop) pvar(`p_dvt_locked') sample(`eval_dvt')
    local dvt_auc = r(auc)
    local dvt_brier = r(brier)
    local dvt_logloss = r(logloss)
    local dvt_cint = r(cint)
    local dvt_cslope = r(cslope)
}
post `secpost' ("postop_dvt") (`dvt_n_train') (`dvt_n_test') (`dvt_events_train') (`dvt_events_test') ///
    (`dvt_auc') (`dvt_brier') (`dvt_logloss') (`dvt_cint') (`dvt_cslope')

quietly logit vte_composite `FINAL_DIS' if `fit_vte'
estimates store vte_secondary_locked
predict double `p_vte_locked' if `eval_vte', pr
quietly count if `fit_vte'
local vte_n_train = r(N)
quietly count if `eval_vte'
local vte_n_test = r(N)
quietly count if `fit_vte' & vte_composite == 1
local vte_events_train = r(N)
quietly count if `eval_vte' & vte_composite == 1
local vte_events_test = r(N)
local vte_nonevents_test = `vte_n_test' - `vte_events_test'
if `vte_events_test' == 0 | `vte_nonevents_test' == 0 {
    local vte_auc = .
    local vte_brier = .
    local vte_logloss = .
    local vte_cint = .
    local vte_cslope = .
}
else {
    quietly final_eval_binary, outcome(vte_composite) pvar(`p_vte_locked') sample(`eval_vte')
    local vte_auc = r(auc)
    local vte_brier = r(brier)
    local vte_logloss = r(logloss)
    local vte_cint = r(cint)
    local vte_cslope = r(cslope)
}
post `secpost' ("vte_composite") (`vte_n_train') (`vte_n_test') (`vte_events_train') (`vte_events_test') ///
    (`vte_auc') (`vte_brier') (`vte_logloss') (`vte_cint') (`vte_cslope')
postclose `secpost'

preserve
    use "`secondary_perf'", clear
    export delimited using "${FINAL_TABLES}/105_dvt_vte_secondary_model_performance.csv", replace
restore

estimates restore dvt_secondary_locked
final_export_betas, using("${FINAL_TABLES}/105_dvt_secondary_coefficients.csv") modelname("postop_dvt_secondary_locked")

estimates restore vte_secondary_locked
final_export_betas, using("${FINAL_TABLES}/105_vte_secondary_coefficients.csv") modelname("vte_composite_secondary_locked")

postfile `posth' str32 etable_id str120 description str244 file_path byte exists using "`etables'", replace
post `posth' ("eTable1") ("Locked analysis build summary") ("${FINAL_TABLES}/91_locked_analysis_file_build_summary.csv") (fileexists("${FINAL_TABLES}/91_locked_analysis_file_build_summary.csv"))
post `posth' ("eTable2") ("Manifest and required-variable QC") ("${FINAL_TABLES}/92_qc_required_vars.csv") (fileexists("${FINAL_TABLES}/92_qc_required_vars.csv"))
post `posth' ("eTable3") ("Procedure backbone comparison") ("${FINAL_TABLES}/93_compare_procedure_backbones.csv") (fileexists("${FINAL_TABLES}/93_compare_procedure_backbones.csv"))
post `posth' ("eTable4") ("Candidate additions comparison") ("${FINAL_TABLES}/94_candidate_additions_discharge.csv") (fileexists("${FINAL_TABLES}/94_candidate_additions_discharge.csv"))
post `posth' ("eTable5") ("Missing-data sensitivity") ("${FINAL_TABLES}/98_missing_data_sensitivity.csv") (fileexists("${FINAL_TABLES}/98_missing_data_sensitivity.csv"))
post `posth' ("eTable6") ("Subgroup calibration and heterogeneity") ("${FINAL_TABLES}/99_subgroup_calibration_and_heterogeneity.csv") (fileexists("${FINAL_TABLES}/99_subgroup_calibration_and_heterogeneity.csv"))
post `posth' ("eTable7") ("DVT and VTE incidence by year") ("${FINAL_TABLES}/105_dvt_vte_incidence_by_year.csv") (fileexists("${FINAL_TABLES}/105_dvt_vte_incidence_by_year.csv"))
post `posth' ("eTable8") ("2024 overlap of PE and postoperative DVT") ("${FINAL_TABLES}/105_dvt_vte_overlap_2024.csv") (fileexists("${FINAL_TABLES}/105_dvt_vte_overlap_2024.csv"))
post `posth' ("eTable9") ("Secondary discharge-model performance for DVT and VTE composite") ("${FINAL_TABLES}/105_dvt_vte_secondary_model_performance.csv") (fileexists("${FINAL_TABLES}/105_dvt_vte_secondary_model_performance.csv"))
post `posth' ("eTable10") ("Secondary discharge-model coefficients for postoperative DVT") ("${FINAL_TABLES}/105_dvt_secondary_coefficients.csv") (fileexists("${FINAL_TABLES}/105_dvt_secondary_coefficients.csv"))
post `posth' ("eTable11") ("Secondary discharge-model coefficients for VTE composite") ("${FINAL_TABLES}/105_vte_secondary_coefficients.csv") (fileexists("${FINAL_TABLES}/105_vte_secondary_coefficients.csv"))
postclose `posth'

preserve
    use "`etables'", clear
    export delimited using "${FINAL_TABLES}/105_etables_supplement.csv", replace
restore

di as text "Wrote ${FINAL_TABLES}/105_etables_supplement.csv"
di as text "Wrote ${FINAL_TABLES}/105_dvt_vte_incidence_by_year.csv"
di as text "Wrote ${FINAL_TABLES}/105_dvt_vte_overlap_2024.csv"
di as text "Wrote ${FINAL_TABLES}/105_dvt_vte_secondary_model_performance.csv"
di as text "Wrote ${FINAL_TABLES}/105_dvt_secondary_coefficients.csv"
di as text "Wrote ${FINAL_TABLES}/105_vte_secondary_coefficients.csv"
di as text "105_etables_supplement.do complete."
log close
