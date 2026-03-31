version 19.5
clear all
set more off
set varabbrev off
set linesize 255

/**************************************************************************
* 102_table1_descriptives.do
*
* Purpose:
*   Generate long-format descriptive tables for manuscript Table 1.
*
* Inputs:
*   - ${FINAL_OUT}/91_locked_analysis_file_final_pe.dta
*
* Outputs:
*   - ${FINAL_TABLES}/102_table1a_pe_vs_nope.csv
*   - ${FINAL_TABLES}/102_table1b_dev_vs_val.csv
*
* Dependencies:
*   - 90_config_final_pe.do
*   - 91_build_locked_analysis_file.do
*
* Guardrails:
*   - Generates table values programmatically
*   - Uses explicit variable lists already present in the locked dataset
*
* Main analysis steps:
*   1. Build PE vs no-PE descriptives
*   2. Build development vs validation descriptives
*
* Export steps:
*   - Two long-format CSV tables
*
* Completion:
*   - Prints export paths
**************************************************************************/

do "/Volumes/DallalMinix/ramseymini/Library/CloudStorage/OneDrive-ThomasJeffersonUniversityanditsAffiliates/_Enterprise/stats/Pulmonary Embolism/Locked/do/final_model/90_config_final_pe.do"

capture log close _all
log using "${FINAL_LOG}/102_table1_descriptives.log", replace text

final_need_file, file("${FINAL_OUT}/91_locked_analysis_file_final_pe.dta") tag("locked analysis dataset")
use "${FINAL_OUT}/91_locked_analysis_file_final_pe.dta", clear

tempfile table1a table1b
tempname a1 b1
postfile `a1' str24 table_name str20 group_name str40 variable str20 level long n double pct using "`table1a'", replace
postfile `b1' str24 table_name str20 group_name str40 variable str20 level long n double pct using "`table1b'", replace

local catvars age_cat bmi_cat discancr_b optime_cat los3 asaclas_id fnstatus2_id inout_id sex3 steroid_b hxchf_b dialysis_b

foreach g in 0 1 {
    local gname = cond(`g' == 0, "No_PE", "PE")
    quietly count if pe == `g'
    local denom = r(N)
    foreach v of local catvars {
        quietly levelsof `v' if pe == `g' & !missing(`v'), local(levels)
        foreach lev of local levels {
            quietly count if pe == `g' & `v' == `lev'
            local n = r(N)
            local pct = .
            if `denom' > 0 local pct = 100 * `n' / `denom'
            post `a1' ("table1a") ("`gname'") ("`v'") ("`lev'") (`n') (`pct')
        }
    }
}
postclose `a1'

gen byte dev_val_group = .
replace dev_val_group = 1 if train == 1
replace dev_val_group = 2 if test == 1

foreach g in 1 2 {
    local gname = cond(`g' == 1, "Development", "Validation")
    quietly count if dev_val_group == `g'
    local denom = r(N)
    foreach v of local catvars {
        quietly levelsof `v' if dev_val_group == `g' & !missing(`v'), local(levels)
        foreach lev of local levels {
            quietly count if dev_val_group == `g' & `v' == `lev'
            local n = r(N)
            local pct = .
            if `denom' > 0 local pct = 100 * `n' / `denom'
            post `b1' ("table1b") ("`gname'") ("`v'") ("`lev'") (`n') (`pct')
        }
    }
}
postclose `b1'

preserve
    use "`table1a'", clear
    export delimited using "${FINAL_TABLES}/102_table1a_pe_vs_nope.csv", replace
restore

preserve
    use "`table1b'", clear
    export delimited using "${FINAL_TABLES}/102_table1b_dev_vs_val.csv", replace
restore

di as text "Wrote ${FINAL_TABLES}/102_table1a_pe_vs_nope.csv"
di as text "Wrote ${FINAL_TABLES}/102_table1b_dev_vs_val.csv"
di as text "102_table1_descriptives.do complete."
log close
