version 19.5
clear all
set more off
set varabbrev off
set linesize 255

/**************************************************************************
* 108_freeze_final_release.do
*
* Purpose:
*   Execute the locked final-model pipeline end-to-end and write a final
*   release manifest.
*
* Inputs:
*   - Numbered locked do-files 90-107
*
* Outputs:
*   - ${FINAL_OUT}/108_freeze_final_release.txt
*
* Dependencies:
*   - 90_config_final_pe.do
*   - 91-107 numbered locked do-files
*
* Guardrails:
*   - Stops on first failed numbered do-file
*   - Verifies key release outputs before declaring freeze complete
*
* Main analysis steps:
*   1. Load config
*   2. Run numbered do-files 91-107 in sequence
*   3. Verify key release outputs
*
* Export steps:
*   - Final release manifest text file
*
* Completion:
*   - Prints final release manifest path
**************************************************************************/

do "/Volumes/DallalMinix/ramseymini/Library/CloudStorage/OneDrive-ThomasJeffersonUniversityanditsAffiliates/_Enterprise/stats/Pulmonary Embolism/Locked/do/final_model/90_config_final_pe.do"

capture log close _all
log using "${FINAL_LOG}/108_freeze_final_release.log", replace text

capture program drop _run_locked
program define _run_locked
    syntax , DOFILE(string)
    di as text "Running: `dofile'"
    capture noisily do "`dofile'"
    if _rc {
        di as error "FATAL: locked do-file failed: `dofile'"
        exit _rc
    }
end

_run_locked, dofile("${FINAL_DO}/91_build_locked_analysis_file.do")
_run_locked, dofile("${FINAL_DO}/92_manifest_and_qc.do")
_run_locked, dofile("${FINAL_DO}/93_compare_procedure_backbones.do")
_run_locked, dofile("${FINAL_DO}/94_candidate_additions_discharge.do")
_run_locked, dofile("${FINAL_DO}/95_ablation_final_discharge.do")
_run_locked, dofile("${FINAL_DO}/96_fit_final_discharge_model.do")
_run_locked, dofile("${FINAL_DO}/97_fit_final_update_model.do")
_run_locked, dofile("${FINAL_DO}/98_missing_data_sensitivity.do")
_run_locked, dofile("${FINAL_DO}/99_subgroup_calibration_and_heterogeneity.do")
_run_locked, dofile("${FINAL_DO}/100_threshold_utility_tables.do")
_run_locked, dofile("${FINAL_DO}/101_final_figures.do")
_run_locked, dofile("${FINAL_DO}/102_table1_descriptives.do")
_run_locked, dofile("${FINAL_DO}/103_table2_model_performance.do")
_run_locked, dofile("${FINAL_DO}/104_table3_thresholds.do")
_run_locked, dofile("${FINAL_DO}/105_etables_supplement.do")
_run_locked, dofile("${FINAL_DO}/106_export_calculator_artifacts.do")
_run_locked, dofile("${FINAL_DO}/107_analysis_audit_trail.do")

foreach f in ///
    "${FINAL_OUT}/91_locked_analysis_file_final_pe.dta" ///
    "${FINAL_STER}/96_final_discharge_model.ster" ///
    "${FINAL_STER}/97_final_update_model.ster" ///
    "${FINAL_TABLES}/103_table2_model_performance.csv" ///
    "${FINAL_TABLES}/104_table3_thresholds.csv" ///
    "${FINAL_TABLES}/105_dvt_vte_incidence_by_year.csv" ///
    "${FINAL_TABLES}/105_dvt_vte_overlap_2024.csv" ///
    "${FINAL_TABLES}/105_dvt_vte_secondary_model_performance.csv" ///
    "${FINAL_OUT}/107_analysis_audit_trail.csv" {
    final_need_file, file("`f'") tag("freeze verification")
}

capture file close freezefh
file open freezefh using "${FINAL_OUT}/108_freeze_final_release.txt", write replace
file write freezefh "Locked PE final release freeze complete" _n
file write freezefh "Created: `c(current_date)' `c(current_time)'" _n
file write freezefh "Key dataset: ${FINAL_OUT}/91_locked_analysis_file_final_pe.dta" _n
file write freezefh "Final discharge model: ${FINAL_STER}/96_final_discharge_model.ster" _n
file write freezefh "Final update model: ${FINAL_STER}/97_final_update_model.ster" _n
file write freezefh "DVT/VTE incidence table: ${FINAL_TABLES}/105_dvt_vte_incidence_by_year.csv" _n
file write freezefh "DVT/VTE overlap table: ${FINAL_TABLES}/105_dvt_vte_overlap_2024.csv" _n
file write freezefh "DVT/VTE secondary performance: ${FINAL_TABLES}/105_dvt_vte_secondary_model_performance.csv" _n
file write freezefh "Audit trail: ${FINAL_OUT}/107_analysis_audit_trail.csv" _n
file close freezefh

di as text "Wrote ${FINAL_OUT}/108_freeze_final_release.txt"
di as text "108_freeze_final_release.do complete."
log close
