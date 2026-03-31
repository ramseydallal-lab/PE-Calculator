version 19.5
clear all
set more off
set varabbrev off
set linesize 255

/**************************************************************************
* 91_build_locked_analysis_file.do
*
* Purpose:
*   Build the locked, analysis-ready dataset used by all downstream final
*   model scripts.
*
* Inputs:
*   - ${SOURCE_DTA}/nsqip_puf20_24_combined_clean.dta
*
* Outputs:
*   - ${FINAL_OUT}/91_locked_analysis_file_final_pe.dta
*   - ${FINAL_TABLES}/91_locked_analysis_file_build_summary.csv
*
* Dependencies:
*   - 90_config_final_pe.do
*
* Guardrails:
*   - Fails early if the source clean dataset is absent
*   - Creates all derived variables deterministically
*   - Writes only to locked output/table/log folders
*
* Main analysis steps:
*   1. Load configuration
*   2. Load source clean dataset
*   3. Derive locked variables and cohort flags
*   4. Save locked analysis file
*
* Export steps:
*   - Export year-level row and event counts
*
* Completion:
*   - Prints saved locked dataset path
**************************************************************************/

do "/Volumes/DallalMinix/ramseymini/Library/CloudStorage/OneDrive-ThomasJeffersonUniversityanditsAffiliates/_Enterprise/stats/Pulmonary Embolism/Locked/do/final_model/90_config_final_pe.do"

capture log close _all
log using "${FINAL_LOG}/91_build_locked_analysis_file.log", replace text

local force_rebuild 0
local reuse_current 0

if fileexists("${FINAL_OUT}/91_locked_analysis_file_final_pe.dta") & `force_rebuild' == 0 {
    use "${FINAL_OUT}/91_locked_analysis_file_final_pe.dta", clear
    local reuse_current 1

    capture confirm variable dvt_postop
    if _rc local reuse_current 0
    capture confirm variable vte_composite
    if _rc local reuse_current 0

    if `reuse_current' == 1 {
        quietly count if !missing(dvt_postop)
        if r(N) == 0 local reuse_current 0
        quietly count if !missing(vte_composite)
        if r(N) == 0 local reuse_current 0
    }

    if `reuse_current' == 1 {
        di as text "Locked analysis file already exists; reusing current build."
    }
    else {
        di as text "Existing locked analysis file lacks usable DVT/VTE outcomes; rebuilding."
    }
}

if !fileexists("${FINAL_OUT}/91_locked_analysis_file_final_pe.dta") | `force_rebuild' == 1 | `reuse_current' == 0 {
    quietly final_pick_build_source
    local build_source "`r(build_source)'"
    local build_source_tag "`r(build_source_tag)'"
    final_need_file, file("`build_source'") tag("build source")
    di as text "Building locked analysis file from: `build_source_tag'"
    di as text "Path: `build_source'"
    use "`build_source'", clear

    final_prepare_locked_analysis

    capture drop locked_row_id
    gen long locked_row_id = _n
    order locked_row_id, first

    quietly count if train == 1 | test == 1
    if r(N) == 0 {
        di as error "FATAL: no 2020-2024 observations found after cohort flags were created"
        exit 459
    }

    compress
    save "${FINAL_OUT}/91_locked_analysis_file_final_pe.dta", replace

    capture file close buildfh
    file open buildfh using "${FINAL_OUT}/91_locked_analysis_file_build_source.txt", write replace
    file write buildfh "Locked analysis build source" _n
    file write buildfh "Created: `c(current_date)' `c(current_time)'" _n
    file write buildfh "Source tag: `build_source_tag'" _n
    file write buildfh "Source path: `build_source'" _n
    file close buildfh
}

preserve
    keep if train == 1 | test == 1
    gen byte dvt_nonmissing = !missing(dvt_postop)
    gen byte vte_nonmissing = !missing(vte_composite)
    collapse (count) n=pe (sum) pe_events=pe dvt_events=dvt_postop vte_events=vte_composite dvt_n=dvt_nonmissing vte_n=vte_nonmissing, by(puf_year)
    gen double pe_rate = pe_events / n
    gen double dvt_rate = dvt_events / dvt_n if dvt_n > 0
    gen double vte_rate = vte_events / vte_n if vte_n > 0
    order puf_year n pe_events pe_rate
    export delimited using "${FINAL_TABLES}/91_locked_analysis_file_build_summary.csv", replace
restore

di as text "Saved locked analysis file: ${FINAL_OUT}/91_locked_analysis_file_final_pe.dta"
di as text "91_build_locked_analysis_file.do complete."
log close
