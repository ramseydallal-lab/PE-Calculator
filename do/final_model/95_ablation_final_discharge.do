version 19.5
clear all
set more off
set varabbrev off
set linesize 255

/**************************************************************************
* 95_ablation_final_discharge.do
*
* Purpose:
*   Compare the locked final discharge model against an ablated version
*   excluding functional status, using an identical complete-case sample.
*
* Inputs:
*   - ${FINAL_OUT}/91_locked_analysis_file_final_pe.dta
*
* Outputs:
*   - ${FINAL_TABLES}/95_ablation_final_discharge.csv
*   - ${FINAL_OUT}/95_ablation_final_discharge_checkpoint.dta
*   - ${FINAL_OUT}/95_ablation_final_discharge_checkpoint.csv
*
* Dependencies:
*   - 90_config_final_pe.do
*   - 91_build_locked_analysis_file.do
*
* Guardrails:
*   - Uses the same complete-case train/test cohort for full and ablated models
*   - Keeps the procedure backbone identical between parent and ablated models
*   - Saves checkpoint results so interrupted runs can resume
*
* Main analysis steps:
*   1. Load locked analysis file
*   2. Define shared complete-case samples
*   3. Resume from any saved ablation checkpoints
*   4. Fit full and ablated discharge models
*   5. Export comparative performance metrics
*
* Export steps:
*   - CSV comparison table
*   - Checkpoint .dta/.csv after each completed model
*
* Completion:
*   - Prints ablation export path
**************************************************************************/

do "/Volumes/DallalMinix/ramseymini/Library/CloudStorage/OneDrive-ThomasJeffersonUniversityanditsAffiliates/_Enterprise/stats/Pulmonary Embolism/Locked/do/final_model/90_config_final_pe.do"

capture log close _all
log using "${FINAL_LOG}/95_ablation_final_discharge.log", replace text

local force_refit 0
local checkpoint_dta "${FINAL_OUT}/95_ablation_final_discharge_checkpoint.dta"
local checkpoint_csv "${FINAL_OUT}/95_ablation_final_discharge_checkpoint.csv"
local checkpoint_spec_tag "95_ablation_checkpoint_v20260328"

final_need_file, file("${FINAL_OUT}/91_locked_analysis_file_final_pe.dta") tag("locked analysis dataset")
use pe train test age_cat bmi_cat discancr_b optime_cat los3 asaclas_id fnstatus2_id inout_id ///
    wrvu_s1 wrvu_s2 wrvu_s3 wrvu_s4 cpt3_pool ///
    using "${FINAL_OUT}/91_locked_analysis_file_final_pe.dta", clear

foreach v in pe train test age_cat bmi_cat discancr_b optime_cat los3 asaclas_id fnstatus2_id inout_id ///
    wrvu_s1 wrvu_s2 wrvu_s3 wrvu_s4 cpt3_pool {
    final_need_var, var(`v')
}

tempvar ab_train_ok ab_test_ok
gen byte `ab_train_ok' = train == 1 & !missing(pe, age_cat, bmi_cat, discancr_b, optime_cat, los3, asaclas_id, fnstatus2_id, inout_id, ///
    wrvu_s1, wrvu_s2, wrvu_s3, wrvu_s4, cpt3_pool)
gen byte `ab_test_ok' = test == 1 & !missing(pe, age_cat, bmi_cat, discancr_b, optime_cat, los3, asaclas_id, fnstatus2_id, inout_id, ///
    wrvu_s1, wrvu_s2, wrvu_s3, wrvu_s4, cpt3_pool)

quietly count if `ab_train_ok'
if r(N) == 0 {
    di as error "FATAL: no shared complete-case training sample for ablation analysis"
    exit 459
}
quietly count if `ab_test_ok'
if r(N) == 0 {
    di as error "FATAL: no shared complete-case validation sample for ablation analysis"
    exit 459
}

local FULL "i.age_cat i.bmi_cat i.discancr_b i.optime_cat i.los3 i.asaclas_id i.fnstatus2_id i.inout_id c.wrvu_s1 c.wrvu_s2 c.wrvu_s3 c.wrvu_s4 i.cpt3_pool"
local REDUCED "i.age_cat i.bmi_cat i.discancr_b i.optime_cat i.los3 i.asaclas_id i.inout_id c.wrvu_s1 c.wrvu_s2 c.wrvu_s3 c.wrvu_s4 i.cpt3_pool"

quietly count if `ab_test_ok' & pe == 1
local pe_test = r(N)
quietly count if `ab_test_ok'
local n_test = r(N)
quietly count if `ab_train_ok'
local n_train = r(N)
local checkpoint_sample_key "`n_train'|`n_test'|`pe_test'"

if `force_refit' == 0 & fileexists("`checkpoint_dta'") {
    preserve
        use "`checkpoint_dta'", clear
        capture confirm variable model
        if _rc local force_refit 1
        capture confirm variable spec_tag
        if _rc local force_refit 1
        capture confirm variable sample_key
        if _rc local force_refit 1
        if `force_refit' == 0 {
            quietly count
            if r(N) == 0 local force_refit 1
            if r(N) > 2 local force_refit 1
            quietly count if spec_tag != "`checkpoint_spec_tag'" | sample_key != "`checkpoint_sample_key'"
            if r(N) > 0 local force_refit 1
        }
    restore
}

if `force_refit' == 1 | !fileexists("`checkpoint_dta'") {
    preserve
        clear
        set obs 0
        gen str24 model = ""
        gen str40 spec_tag = ""
        gen str40 sample_key = ""
        gen long n_train = .
        gen long n_test = .
        gen long pe_test = .
        gen double auc = .
        gen double brier = .
        gen double logloss = .
        gen double cint = .
        gen double cslope = .
        save "`checkpoint_dta'", replace
        export delimited using "`checkpoint_csv'", replace
    restore
}

quietly final_checkpoint_has_model, using("`checkpoint_dta'") model("full_fnstatus")
if r(exists) == 0 {
    quietly logit pe `FULL' if `ab_train_ok'
    predict double p_full if `ab_test_ok', pr
    quietly final_eval_binary, outcome(pe) pvar(p_full) sample(`ab_test_ok')
    local auc = r(auc)
    local brier = r(brier)
    local logloss = r(logloss)
    local cint = r(cint)
    local cslope = r(cslope)
    tempfile row_full
    preserve
        clear
        set obs 1
        gen str24 model = "full_fnstatus"
        gen str40 spec_tag = "`checkpoint_spec_tag'"
        gen str40 sample_key = "`checkpoint_sample_key'"
        gen long n_train = `n_train'
        gen long n_test = `n_test'
        gen long pe_test = `pe_test'
        gen double auc = `auc'
        gen double brier = `brier'
        gen double logloss = `logloss'
        gen double cint = `cint'
        gen double cslope = `cslope'
        save "`row_full'", replace
    restore
    preserve
        use "`checkpoint_dta'", clear
        append using "`row_full'"
        save "`checkpoint_dta'", replace
        export delimited using "`checkpoint_csv'", replace
    restore
}

quietly final_checkpoint_has_model, using("`checkpoint_dta'") model("ablated_no_fnstatus")
if r(exists) == 0 {
    quietly logit pe `REDUCED' if `ab_train_ok'
    predict double p_reduced if `ab_test_ok', pr
    quietly final_eval_binary, outcome(pe) pvar(p_reduced) sample(`ab_test_ok')
    local auc = r(auc)
    local brier = r(brier)
    local logloss = r(logloss)
    local cint = r(cint)
    local cslope = r(cslope)
    tempfile row_reduced
    preserve
        clear
        set obs 1
        gen str24 model = "ablated_no_fnstatus"
        gen str40 spec_tag = "`checkpoint_spec_tag'"
        gen str40 sample_key = "`checkpoint_sample_key'"
        gen long n_train = `n_train'
        gen long n_test = `n_test'
        gen long pe_test = `pe_test'
        gen double auc = `auc'
        gen double brier = `brier'
        gen double logloss = `logloss'
        gen double cint = `cint'
        gen double cslope = `cslope'
        save "`row_reduced'", replace
    restore
    preserve
        use "`checkpoint_dta'", clear
        append using "`row_reduced'"
        save "`checkpoint_dta'", replace
        export delimited using "`checkpoint_csv'", replace
    restore
}

use "`checkpoint_dta'", clear
export delimited using "${FINAL_TABLES}/95_ablation_final_discharge.csv", replace

di as text "Wrote ${FINAL_TABLES}/95_ablation_final_discharge.csv"
di as text "Wrote `checkpoint_dta'"
di as text "95_ablation_final_discharge.do complete."
log close
