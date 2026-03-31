version 19.5
clear all
set more off
set varabbrev off
set linesize 255

/**************************************************************************
* 107_analysis_audit_trail.do
*
* Purpose:
*   Build a file-level audit trail for the locked final-model workflow.
*
* Inputs:
*   - Numbered locked do-files
*   - Locked outputs from prior scripts
*
* Outputs:
*   - ${FINAL_OUT}/107_analysis_audit_trail.csv
*   - ${FINAL_OUT}/107_analysis_audit_trail.txt
*
* Dependencies:
*   - 90_config_final_pe.do
*
* Guardrails:
*   - Uses absolute paths only
*   - Records existence without mutating prior outputs
*
* Main analysis steps:
*   1. Enumerate numbered do-files
*   2. Enumerate key locked outputs
*   3. Export audit manifest
*
* Export steps:
*   - Audit CSV
*   - Audit text summary
*
* Completion:
*   - Prints export paths
**************************************************************************/

do "/Volumes/DallalMinix/ramseymini/Library/CloudStorage/OneDrive-ThomasJeffersonUniversityanditsAffiliates/_Enterprise/stats/Pulmonary Embolism/Locked/do/final_model/90_config_final_pe.do"

capture log close _all
log using "${FINAL_LOG}/107_analysis_audit_trail.log", replace text

tempfile audit
tempname posth
postfile `posth' str16 record_type str40 record_id str244 path byte exists using "`audit'", replace

post `posth' ("dofile") ("90_config_final_pe") ("${FINAL_DO}/90_config_final_pe.do") (fileexists("${FINAL_DO}/90_config_final_pe.do"))
post `posth' ("dofile") ("91_build_locked_analysis_file") ("${FINAL_DO}/91_build_locked_analysis_file.do") (fileexists("${FINAL_DO}/91_build_locked_analysis_file.do"))
post `posth' ("dofile") ("92_manifest_and_qc") ("${FINAL_DO}/92_manifest_and_qc.do") (fileexists("${FINAL_DO}/92_manifest_and_qc.do"))
post `posth' ("dofile") ("93_compare_procedure_backbones") ("${FINAL_DO}/93_compare_procedure_backbones.do") (fileexists("${FINAL_DO}/93_compare_procedure_backbones.do"))
post `posth' ("dofile") ("94_candidate_additions_discharge") ("${FINAL_DO}/94_candidate_additions_discharge.do") (fileexists("${FINAL_DO}/94_candidate_additions_discharge.do"))
post `posth' ("dofile") ("95_ablation_final_discharge") ("${FINAL_DO}/95_ablation_final_discharge.do") (fileexists("${FINAL_DO}/95_ablation_final_discharge.do"))
post `posth' ("dofile") ("96_fit_final_discharge_model") ("${FINAL_DO}/96_fit_final_discharge_model.do") (fileexists("${FINAL_DO}/96_fit_final_discharge_model.do"))
post `posth' ("dofile") ("97_fit_final_update_model") ("${FINAL_DO}/97_fit_final_update_model.do") (fileexists("${FINAL_DO}/97_fit_final_update_model.do"))
post `posth' ("dofile") ("98_missing_data_sensitivity") ("${FINAL_DO}/98_missing_data_sensitivity.do") (fileexists("${FINAL_DO}/98_missing_data_sensitivity.do"))
post `posth' ("dofile") ("99_subgroup_calibration_and_heterogeneity") ("${FINAL_DO}/99_subgroup_calibration_and_heterogeneity.do") (fileexists("${FINAL_DO}/99_subgroup_calibration_and_heterogeneity.do"))
post `posth' ("dofile") ("100_threshold_utility_tables") ("${FINAL_DO}/100_threshold_utility_tables.do") (fileexists("${FINAL_DO}/100_threshold_utility_tables.do"))
post `posth' ("dofile") ("101_final_figures") ("${FINAL_DO}/101_final_figures.do") (fileexists("${FINAL_DO}/101_final_figures.do"))
post `posth' ("dofile") ("102_table1_descriptives") ("${FINAL_DO}/102_table1_descriptives.do") (fileexists("${FINAL_DO}/102_table1_descriptives.do"))
post `posth' ("dofile") ("103_table2_model_performance") ("${FINAL_DO}/103_table2_model_performance.do") (fileexists("${FINAL_DO}/103_table2_model_performance.do"))
post `posth' ("dofile") ("104_table3_thresholds") ("${FINAL_DO}/104_table3_thresholds.do") (fileexists("${FINAL_DO}/104_table3_thresholds.do"))
post `posth' ("dofile") ("105_etables_supplement") ("${FINAL_DO}/105_etables_supplement.do") (fileexists("${FINAL_DO}/105_etables_supplement.do"))
post `posth' ("dofile") ("106_export_calculator_artifacts") ("${FINAL_DO}/106_export_calculator_artifacts.do") (fileexists("${FINAL_DO}/106_export_calculator_artifacts.do"))
post `posth' ("dofile") ("107_analysis_audit_trail") ("${FINAL_DO}/107_analysis_audit_trail.do") (fileexists("${FINAL_DO}/107_analysis_audit_trail.do"))
post `posth' ("dofile") ("108_freeze_final_release") ("${FINAL_DO}/108_freeze_final_release.do") (fileexists("${FINAL_DO}/108_freeze_final_release.do"))

post `posth' ("output") ("locked_analysis") ("${FINAL_OUT}/91_locked_analysis_file_final_pe.dta") (fileexists("${FINAL_OUT}/91_locked_analysis_file_final_pe.dta"))
post `posth' ("output") ("participant_flow") ("${FINAL_TABLES}/92_participant_flow.csv") (fileexists("${FINAL_TABLES}/92_participant_flow.csv"))
post `posth' ("output") ("discharge_model") ("${FINAL_STER}/96_final_discharge_model.ster") (fileexists("${FINAL_STER}/96_final_discharge_model.ster"))
post `posth' ("output") ("update_model") ("${FINAL_STER}/97_final_update_model.ster") (fileexists("${FINAL_STER}/97_final_update_model.ster"))
post `posth' ("output") ("table2") ("${FINAL_TABLES}/103_table2_model_performance.csv") (fileexists("${FINAL_TABLES}/103_table2_model_performance.csv"))
post `posth' ("output") ("table2_bootstrap_ci") ("${FINAL_TABLES}/103_model_performance_bootstrap_summary.csv") (fileexists("${FINAL_TABLES}/103_model_performance_bootstrap_summary.csv"))
post `posth' ("output") ("table3") ("${FINAL_TABLES}/104_table3_thresholds.csv") (fileexists("${FINAL_TABLES}/104_table3_thresholds.csv"))
post `posth' ("output") ("calib_decile_discharge") ("${FINAL_TABLES}/101_calibration_decile_discharge.csv") (fileexists("${FINAL_TABLES}/101_calibration_decile_discharge.csv"))
post `posth' ("output") ("calib_vigintile_discharge") ("${FINAL_TABLES}/101_calibration_vigintile_discharge.csv") (fileexists("${FINAL_TABLES}/101_calibration_vigintile_discharge.csv"))
post `posth' ("output") ("etables_supplement") ("${FINAL_TABLES}/105_etables_supplement.csv") (fileexists("${FINAL_TABLES}/105_etables_supplement.csv"))
post `posth' ("output") ("dvt_coefficients") ("${FINAL_OUT}/106_calculator_coefficients_dvt.csv") (fileexists("${FINAL_OUT}/106_calculator_coefficients_dvt.csv"))
post `posth' ("output") ("calculator_summary") ("${FINAL_OUT}/106_calculator_model_summary.csv") (fileexists("${FINAL_OUT}/106_calculator_model_summary.csv"))
post `posth' ("output") ("calculator_input_dictionary") ("${FINAL_OUT}/106_calculator_input_dictionary.csv") (fileexists("${FINAL_OUT}/106_calculator_input_dictionary.csv"))
post `posth' ("output") ("calculator_guidance") ("${FINAL_OUT}/106_calculator_clinician_guidance.txt") (fileexists("${FINAL_OUT}/106_calculator_clinician_guidance.txt"))
post `posth' ("output") ("calculator_meta") ("${FINAL_OUT}/106_calculator_metadata.txt") (fileexists("${FINAL_OUT}/106_calculator_metadata.txt"))
postclose `posth'

use "`audit'", clear
export delimited using "${FINAL_OUT}/107_analysis_audit_trail.csv", replace

capture file close auditfh
file open auditfh using "${FINAL_OUT}/107_analysis_audit_trail.txt", write replace
file write auditfh "Locked PE analysis audit trail" _n
file write auditfh "Created: `c(current_date)' `c(current_time)'" _n
file write auditfh "CSV manifest: ${FINAL_OUT}/107_analysis_audit_trail.csv" _n
file close auditfh

di as text "Wrote ${FINAL_OUT}/107_analysis_audit_trail.csv"
di as text "Wrote ${FINAL_OUT}/107_analysis_audit_trail.txt"
di as text "107_analysis_audit_trail.do complete."
log close
