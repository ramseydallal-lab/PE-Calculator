# AGENTS.md — Pulmonary Embolism Locked Final Model Project

You are writing Stata 19.5 do-files for a locked production pipeline.

## Project root
All writable work must stay under:

/Volumes/DallalMinix/ramseymini/Library/CloudStorage/OneDrive-ThomasJeffersonUniversityanditsAffiliates/_Enterprise/stats/Pulmonary Embolism/Locked

## Allowed write locations
- do/final_model/
- logs/
- output/
- ster/
- tables/
- figures/
- tmp/
- archive/

Do not write outside these paths.
Do not modify raw data.
Do not modify exploratory scripts outside do/final_model unless explicitly instructed.

## Primary objective
Create robust, audit-ready, rerunnable Stata do-files for final model lock-down, validation, sensitivity analysis, figures, and manuscript tables.

## Stata version and style
- Target Stata 19.5 syntax.
- Start every do-file with:
    version 19.5
    clear all
    set more off
    set varabbrev off
    set linesize 255
- Use explicit comments and section headers.
- Prefer local macros within files; use globals only for project paths defined in 90_config_final_pe.do.
- Never rely on the working directory.
- Always use quoted absolute-path globals from config.
- Never abbreviate variable names.
- Use deterministic seeds when applicable.

## Required anti-bug rules
- Never nest preserve within preserve.
- If preserve is used, exactly one matching restore must occur on all code paths.
- Prefer tempfiles and frames when safer than preserve/restore.
- Never use capture noisily around core modeling commands.
- Avoid broad capture drop patterns unless necessary; if used, comment why.
- Before saving a file, ensure the destination folder exists.
- Before overwriting an existing do-file, create a timestamped backup in archive/.
- All tempfiles must be local tempfile objects, not hard-coded paths.
- All append/postfile workflows must explicitly initialize target structures.
- All factor-variable specifications must be explicit and stable.
- Any generated file name must include a deterministic model or task label.
- Check for required variables before modeling; fail early with clear error text.
- For every model-comparison do-file, ensure identical validation cohort usage.
- For ablation comparisons, ensure identical complete-case sample between parent and ablated model.
- Do not hand-edit manuscript values; generate export tables programmatically.

## Required validation pass before saving each do-file
The agent must inspect the produced do-file and verify:
1. all opening and closing braces balance
2. all quoted strings balance
3. every preserve has one restore
4. every postfile has postclose
5. tempfiles/tempnames are declared before use
6. all referenced globals/locals are defined or imported
7. every save/export target directory is created or assumed from config
8. no relative paths are used
9. no duplicate local names shadow critical macros in the same block
10. no invalid Stata comment syntax is present

If any of these fail, revise before saving.

## Required file naming
Create only numbered do-files:
90_config_final_pe.do
91_build_locked_analysis_file.do
92_manifest_and_qc.do
93_compare_procedure_backbones.do
94_candidate_additions_discharge.do
95_ablation_final_discharge.do
96_fit_final_discharge_model.do
97_fit_final_update_model.do
98_missing_data_sensitivity.do
99_subgroup_calibration_and_heterogeneity.do
100_threshold_utility_tables.do
101_final_figures.do
102_table1_descriptives.do
103_table2_model_performance.do
104_table3_thresholds.do
105_etables_supplement.do
106_export_calculator_artifacts.do
107_analysis_audit_trail.do
108_freeze_final_release.do

## Writing requirements for each do-file
Each do-file must contain:
- Purpose block
- Inputs
- Outputs
- Dependencies
- Guardrails for required variables/files
- Main analysis steps
- Export steps
- End-of-file completion message

## Modeling principles
- Use out-of-sample AUC, Brier, log loss, calibration intercept, calibration slope, and threshold operating characteristics as primary decision metrics.
- Do not use coefficient p-values alone to keep or drop predictors.
- Stop model search after the locked candidate stage.
- Prefer parsimony when validation performance loss is trivial.
- Explicitly separate development, validation, ablation, and sensitivity workflows.

## If uncertain
Do not invent variable names or file names.
Read existing files in Locked/ first.
If uncertainty remains, leave a clearly marked TODO block instead of guessing.
