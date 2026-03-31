version 19.5
clear all
set more off
set varabbrev off
set linesize 255

/**************************************************************************
* 93_compare_procedure_backbones.do
*
* Purpose:
*   Compare candidate procedure backbones on an identical complete-case
*   train/test cohort before final model lock-down.
*
* Inputs:
*   - ${FINAL_OUT}/91_locked_analysis_file_final_pe.dta
*
* Outputs:
*   - ${FINAL_TABLES}/93_compare_procedure_backbones.csv
*   - ${FINAL_OUT}/93_compare_procedure_backbones_checkpoint.dta
*   - ${FINAL_OUT}/93_compare_procedure_backbones_checkpoint.csv
*
* Dependencies:
*   - 90_config_final_pe.do
*   - 91_build_locked_analysis_file.do
*
* Guardrails:
*   - Uses identical complete-case train/test cohorts across all models
*   - Fails if required spline/CPT variables are absent
*   - Saves model-level checkpoints so interrupted runs can resume
*
* Main analysis steps:
*   1. Load locked analysis file
*   2. Define a shared complete-case cohort for all procedure backbones
*   3. Resume from any saved backbone checkpoints
*   4. Fit remaining backbone candidates
*   5. Evaluate on a shared 2024 validation cohort
*
* Export steps:
*   - Export CSV of backbone performance metrics
*   - Export checkpoint .dta/.csv after each completed model
*
* Completion:
*   - Prints comparison-table path
**************************************************************************/

do "/Volumes/DallalMinix/ramseymini/Library/CloudStorage/OneDrive-ThomasJeffersonUniversityanditsAffiliates/_Enterprise/stats/Pulmonary Embolism/Locked/do/final_model/90_config_final_pe.do"

capture log close _all
log using "${FINAL_LOG}/93_compare_procedure_backbones.log", replace text

local force_refit 0
local checkpoint_dta "${FINAL_OUT}/93_compare_procedure_backbones_checkpoint.dta"
local checkpoint_csv "${FINAL_OUT}/93_compare_procedure_backbones_checkpoint.csv"
local checkpoint_spec_tag "93_backbone_checkpoint_v20260328"

final_need_file, file("${FINAL_OUT}/91_locked_analysis_file_final_pe.dta") tag("locked analysis dataset")
use pe train test age_cat bmi_cat discancr_b optime_cat los3 asaclas_id fnstatus2_id inout_id ///
    major workrvu_clean wrvu_s1 wrvu_s2 wrvu_s3 wrvu_s4 cpt3_pool ///
    using "${FINAL_OUT}/91_locked_analysis_file_final_pe.dta", clear

foreach v in pe train test age_cat bmi_cat discancr_b optime_cat los3 asaclas_id fnstatus2_id inout_id ///
    major workrvu_clean wrvu_s1 wrvu_s2 wrvu_s3 wrvu_s4 cpt3_pool {
    final_need_var, var(`v')
}

tempvar proc_train_ok proc_test_ok
gen byte `proc_train_ok' = train == 1 & !missing(pe, age_cat, bmi_cat, discancr_b, optime_cat, los3, asaclas_id, fnstatus2_id, inout_id, ///
    major, workrvu_clean, wrvu_s1, wrvu_s2, wrvu_s3, wrvu_s4, cpt3_pool)
gen byte `proc_test_ok' = test == 1 & !missing(pe, age_cat, bmi_cat, discancr_b, optime_cat, los3, asaclas_id, fnstatus2_id, inout_id, ///
    major, workrvu_clean, wrvu_s1, wrvu_s2, wrvu_s3, wrvu_s4, cpt3_pool)

quietly count if `proc_train_ok'
if r(N) == 0 {
    di as error "FATAL: no common complete-case training sample for procedure backbone comparison"
    exit 459
}
quietly count if `proc_test_ok'
if r(N) == 0 {
    di as error "FATAL: no common complete-case validation sample for procedure backbone comparison"
    exit 459
}

local BASE "i.age_cat i.bmi_cat i.discancr_b i.optime_cat i.los3 i.asaclas_id i.fnstatus2_id i.inout_id"

quietly count if `proc_test_ok' & pe == 1
local pe_test = r(N)
quietly count if `proc_test_ok'
local n_test = r(N)
quietly count if `proc_train_ok'
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
            if r(N) > 4 local force_refit 1
            quietly count if spec_tag != "`checkpoint_spec_tag'" | sample_key != "`checkpoint_sample_key'"
            if r(N) > 0 local force_refit 1
        }
    restore
}

if `force_refit' == 1 | !fileexists("`checkpoint_dta'") {
    preserve
        clear
        set obs 0
        gen str32 model = ""
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

quietly final_checkpoint_has_model, using("`checkpoint_dta'") model("M1_base+major")
if r(exists) == 0 {
    quietly logit pe `BASE' i.major if `proc_train_ok'
    predict double p_m1 if `proc_test_ok', pr
    quietly final_eval_binary, outcome(pe) pvar(p_m1) sample(`proc_test_ok')
    local auc = r(auc)
    local brier = r(brier)
    local logloss = r(logloss)
    local cint = r(cint)
    local cslope = r(cslope)
    tempfile row_m1
    preserve
        clear
        set obs 1
        gen str32 model = "M1_base+major"
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
        save "`row_m1'", replace
    restore
    preserve
        use "`checkpoint_dta'", clear
        append using "`row_m1'"
        gsort -auc
        save "`checkpoint_dta'", replace
        export delimited using "`checkpoint_csv'", replace
    restore
}

quietly final_checkpoint_has_model, using("`checkpoint_dta'") model("M2_base+wrvu_lin")
if r(exists) == 0 {
    quietly logit pe `BASE' c.workrvu_clean if `proc_train_ok'
    predict double p_m2 if `proc_test_ok', pr
    quietly final_eval_binary, outcome(pe) pvar(p_m2) sample(`proc_test_ok')
    local auc = r(auc)
    local brier = r(brier)
    local logloss = r(logloss)
    local cint = r(cint)
    local cslope = r(cslope)
    tempfile row_m2
    preserve
        clear
        set obs 1
        gen str32 model = "M2_base+wrvu_lin"
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
        save "`row_m2'", replace
    restore
    preserve
        use "`checkpoint_dta'", clear
        append using "`row_m2'"
        gsort -auc
        save "`checkpoint_dta'", replace
        export delimited using "`checkpoint_csv'", replace
    restore
}

quietly final_checkpoint_has_model, using("`checkpoint_dta'") model("M3_base+wrvu_spline")
if r(exists) == 0 {
    quietly logit pe `BASE' c.wrvu_s1 c.wrvu_s2 c.wrvu_s3 c.wrvu_s4 if `proc_train_ok'
    predict double p_m3 if `proc_test_ok', pr
    quietly final_eval_binary, outcome(pe) pvar(p_m3) sample(`proc_test_ok')
    local auc = r(auc)
    local brier = r(brier)
    local logloss = r(logloss)
    local cint = r(cint)
    local cslope = r(cslope)
    tempfile row_m3
    preserve
        clear
        set obs 1
        gen str32 model = "M3_base+wrvu_spline"
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
        save "`row_m3'", replace
    restore
    preserve
        use "`checkpoint_dta'", clear
        append using "`row_m3'"
        gsort -auc
        save "`checkpoint_dta'", replace
        export delimited using "`checkpoint_csv'", replace
    restore
}

quietly final_checkpoint_has_model, using("`checkpoint_dta'") model("M4_base+major+cpt3")
if r(exists) == 0 {
    quietly logit pe `BASE' i.major i.cpt3_pool if `proc_train_ok'
    predict double p_m4 if `proc_test_ok', pr
    quietly final_eval_binary, outcome(pe) pvar(p_m4) sample(`proc_test_ok')
    local auc = r(auc)
    local brier = r(brier)
    local logloss = r(logloss)
    local cint = r(cint)
    local cslope = r(cslope)
    tempfile row_m4
    preserve
        clear
        set obs 1
        gen str32 model = "M4_base+major+cpt3"
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
        save "`row_m4'", replace
    restore
    preserve
        use "`checkpoint_dta'", clear
        append using "`row_m4'"
        gsort -auc
        save "`checkpoint_dta'", replace
        export delimited using "`checkpoint_csv'", replace
    restore
}

quietly final_checkpoint_has_model, using("`checkpoint_dta'") model("M5_base+wrvu_lin+cpt3")
if r(exists) == 0 {
    quietly logit pe `BASE' c.workrvu_clean i.cpt3_pool if `proc_train_ok'
    predict double p_m5 if `proc_test_ok', pr
    quietly final_eval_binary, outcome(pe) pvar(p_m5) sample(`proc_test_ok')
    local auc = r(auc)
    local brier = r(brier)
    local logloss = r(logloss)
    local cint = r(cint)
    local cslope = r(cslope)
    tempfile row_m5
    preserve
        clear
        set obs 1
        gen str32 model = "M5_base+wrvu_lin+cpt3"
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
        save "`row_m5'", replace
    restore
    preserve
        use "`checkpoint_dta'", clear
        append using "`row_m5'"
        gsort -auc
        save "`checkpoint_dta'", replace
        export delimited using "`checkpoint_csv'", replace
    restore
}

quietly final_checkpoint_has_model, using("`checkpoint_dta'") model("M6_base+wrvu_spline+cpt3")
if r(exists) == 0 {
    quietly logit pe `BASE' c.wrvu_s1 c.wrvu_s2 c.wrvu_s3 c.wrvu_s4 i.cpt3_pool if `proc_train_ok'
    predict double p_m6 if `proc_test_ok', pr
    quietly final_eval_binary, outcome(pe) pvar(p_m6) sample(`proc_test_ok')
    local auc = r(auc)
    local brier = r(brier)
    local logloss = r(logloss)
    local cint = r(cint)
    local cslope = r(cslope)
    tempfile row_m6
    preserve
        clear
        set obs 1
        gen str32 model = "M6_base+wrvu_spline+cpt3"
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
        save "`row_m6'", replace
    restore
    preserve
        use "`checkpoint_dta'", clear
        append using "`row_m6'"
        gsort -auc
        save "`checkpoint_dta'", replace
        export delimited using "`checkpoint_csv'", replace
    restore
}

use "`checkpoint_dta'", clear
gsort -auc
export delimited using "${FINAL_TABLES}/93_compare_procedure_backbones.csv", replace

di as text "Wrote ${FINAL_TABLES}/93_compare_procedure_backbones.csv"
di as text "Wrote `checkpoint_dta'"
di as text "93_compare_procedure_backbones.do complete."
log close
