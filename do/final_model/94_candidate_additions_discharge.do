version 19.5
clear all
set more off
set varabbrev off
set linesize 255

/**************************************************************************
* 94_candidate_additions_discharge.do
*
* Purpose:
*   Test candidate discharge-model additions against the locked procedure
*   backbone on an identical complete-case cohort.
*
* Inputs:
*   - ${FINAL_OUT}/91_locked_analysis_file_final_pe.dta
*
* Outputs:
*   - ${FINAL_TABLES}/94_candidate_additions_discharge.csv
*   - ${FINAL_OUT}/94_candidate_additions_discharge_summary.txt
*
* Dependencies:
*   - 90_config_final_pe.do
*   - 91_build_locked_analysis_file.do
*
* Guardrails:
*   - Uses the same complete-case train/test cohort for all candidate models
*   - Stops at the candidate-testing stage; no adaptive model search beyond
*     the predeclared candidate set
*
* Main analysis steps:
*   1. Load locked analysis file
*   2. Create identical complete-case train/test samples
*   3. Fit M0-M6 candidate-addition models
*   4. Quantify incremental validation gains versus M0
*   5. Record the locked retention decision
*
* Export steps:
*   - Candidate comparison CSV
*   - Candidate testing summary text
*
* Completion:
*   - Prints candidate comparison path
**************************************************************************/

do "/Volumes/DallalMinix/ramseymini/Library/CloudStorage/OneDrive-ThomasJeffersonUniversityanditsAffiliates/_Enterprise/stats/Pulmonary Embolism/Locked/do/final_model/90_config_final_pe.do"

capture log close _all
log using "${FINAL_LOG}/94_candidate_additions_discharge.log", replace text

local checkpoint_dta "${FINAL_OUT}/94_candidate_additions_discharge_checkpoint.dta"
local checkpoint_csv "${FINAL_OUT}/94_candidate_additions_discharge_checkpoint.csv"
local final_csv "${FINAL_TABLES}/94_candidate_additions_discharge.csv"
local checkpoint_spec_tag "94_cand_additions_ckpt_20260328"
local checkpoint_usable 0
local MODEL_M0 "M0_base+bestproc"
local MODEL_M1 "M1_base+bestproc+sex3"
local MODEL_M2 "M2_base+bestproc+sex3+steroid"
local MODEL_M3 "M3_base+bestproc+sex3+hxchf"
local MODEL_M4 "M4_base+bestproc+sex3+dialysis"
local MODEL_M5 "M5_base+bestproc+sex3+steroid+hxchf"
local MODEL_M6 "M6_bestproc+sex3+steroid+hxchf+dial"

final_need_file, file("${FINAL_OUT}/91_locked_analysis_file_final_pe.dta") tag("locked analysis dataset")
use pe train test age_cat bmi_cat discancr_b optime_cat los3 asaclas_id fnstatus2_id inout_id ///
    wrvu_s1 wrvu_s2 wrvu_s3 wrvu_s4 cpt3_pool sex3 steroid_b hxchf_b dialysis_b ///
    using "${FINAL_OUT}/91_locked_analysis_file_final_pe.dta", clear

foreach v in pe train test age_cat bmi_cat discancr_b optime_cat los3 asaclas_id fnstatus2_id inout_id ///
    wrvu_s1 wrvu_s2 wrvu_s3 wrvu_s4 cpt3_pool sex3 steroid_b hxchf_b dialysis_b {
    final_need_var, var(`v')
}

tempvar cand_train_ok cand_test_ok
gen byte `cand_train_ok' = train == 1 & !missing(pe, age_cat, bmi_cat, discancr_b, optime_cat, los3, asaclas_id, fnstatus2_id, inout_id, ///
    wrvu_s1, wrvu_s2, wrvu_s3, wrvu_s4, cpt3_pool, sex3, steroid_b, hxchf_b, dialysis_b)
gen byte `cand_test_ok' = test == 1 & !missing(pe, age_cat, bmi_cat, discancr_b, optime_cat, los3, asaclas_id, fnstatus2_id, inout_id, ///
    wrvu_s1, wrvu_s2, wrvu_s3, wrvu_s4, cpt3_pool, sex3, steroid_b, hxchf_b, dialysis_b)

quietly count if `cand_train_ok'
if r(N) == 0 {
    di as error "FATAL: no common complete-case training sample for candidate testing"
    exit 459
}
local n_train = r(N)
quietly count if `cand_test_ok'
if r(N) == 0 {
    di as error "FATAL: no common complete-case validation sample for candidate testing"
    exit 459
}

local BASE_DIS "i.age_cat i.bmi_cat i.discancr_b i.optime_cat i.los3 i.asaclas_id i.fnstatus2_id i.inout_id"
local PROC_BEST "c.wrvu_s1 c.wrvu_s2 c.wrvu_s3 c.wrvu_s4 i.cpt3_pool"

quietly count if `cand_test_ok' & pe == 1
local pe_test = r(N)
quietly count if `cand_test_ok'
local n_test = r(N)
local checkpoint_sample_key "`n_train'|`n_test'|`pe_test'"

if fileexists("`checkpoint_dta'") {
    preserve
        use "`checkpoint_dta'", clear
        capture confirm variable model
        if _rc == 0 {
            replace model = "`MODEL_M6'" if strpos(model, "M6_full_base+bestproc+sex3+steroid+hxchf+dial") == 1
            replace model = "`MODEL_M6'" if strpos(model, "M6_bestproc+sex3+steroid+hxchf+dial") == 1
            gsort model -auc
            by model: keep if _n == 1
            save "`checkpoint_dta'", replace
            export delimited using "`checkpoint_csv'", replace
        }
        local checkpoint_valid = 1
        capture confirm variable model
        if _rc local checkpoint_valid = 0
        capture confirm variable spec_tag
        if _rc local checkpoint_valid = 0
        capture confirm variable sample_key
        if _rc local checkpoint_valid = 0
        capture confirm variable n_train
        if _rc local checkpoint_valid = 0
        capture confirm variable n_test
        if _rc local checkpoint_valid = 0
        capture confirm variable pe_test
        if _rc local checkpoint_valid = 0
        if `checkpoint_valid' == 1 {
            quietly count
            if r(N) == 0 local checkpoint_valid = 0
            if r(N) > 7 local checkpoint_valid = 0
            quietly count if spec_tag != "`checkpoint_spec_tag'" | sample_key != "`checkpoint_sample_key'"
            if r(N) > 0 local checkpoint_valid = 0
            quietly count if n_train != `n_train' | n_test != `n_test' | pe_test != `pe_test'
            if r(N) > 0 local checkpoint_valid = 0
        }
        if `checkpoint_valid' == 1 local checkpoint_usable 1
    restore
}

if `checkpoint_usable' == 0 & fileexists("`final_csv'") {
    preserve
        capture import delimited using "`final_csv'", clear varnames(1)
        local recover_csv = (_rc == 0)
        if `recover_csv' == 1 {
            capture confirm variable model
            if _rc local recover_csv = 0
            capture confirm variable n_train
            if _rc local recover_csv = 0
            capture confirm variable n_test
            if _rc local recover_csv = 0
            capture confirm variable pe_test
            if _rc local recover_csv = 0
            capture confirm variable auc
            if _rc local recover_csv = 0
            capture confirm variable brier
            if _rc local recover_csv = 0
            capture confirm variable logloss
            if _rc local recover_csv = 0
            capture confirm variable cint
            if _rc local recover_csv = 0
            capture confirm variable cslope
            if _rc local recover_csv = 0
        }
        if `recover_csv' == 1 {
            replace model = "`MODEL_M6'" if strpos(model, "M6_full_base+bestproc+sex3+steroid+hxchf+dial") == 1
            replace model = "`MODEL_M6'" if strpos(model, "M6_bestproc+sex3+steroid+hxchf+dial") == 1
            keep model n_train n_test pe_test auc brier logloss cint cslope
            gsort model -auc
            by model: keep if _n == 1
            quietly count
            if r(N) == 0 local recover_csv = 0
            if r(N) > 7 local recover_csv = 0
            quietly count if n_train != `n_train' | n_test != `n_test' | pe_test != `pe_test'
            if r(N) > 0 local recover_csv = 0
        }
        if `recover_csv' == 1 {
            gen str48 spec_tag = "`checkpoint_spec_tag'"
            gen str40 sample_key = "`checkpoint_sample_key'"
            save "`checkpoint_dta'", replace
            export delimited using "`checkpoint_csv'", replace
            local checkpoint_usable 1
        }
    restore
}

if `checkpoint_usable' == 0 {
    preserve
        clear
        set obs 0
        gen str80 model = ""
        gen str48 spec_tag = ""
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

quietly final_checkpoint_has_model, using("`checkpoint_dta'") model("`MODEL_M0'")
if r(exists) == 0 {
    quietly logit pe `BASE_DIS' `PROC_BEST' if `cand_train_ok'
    predict double p_m0 if `cand_test_ok', pr
    quietly final_eval_binary, outcome(pe) pvar(p_m0) sample(`cand_test_ok')
    local auc = r(auc)
    local brier = r(brier)
    local logloss = r(logloss)
    local cint = r(cint)
    local cslope = r(cslope)
    tempfile row_m0
    preserve
        clear
        set obs 1
        gen str80 model = "`MODEL_M0'"
        gen str48 spec_tag = "`checkpoint_spec_tag'"
        gen str40 sample_key = "`checkpoint_sample_key'"
        gen long n_train = `n_train'
        gen long n_test = `n_test'
        gen long pe_test = `pe_test'
        gen double auc = `auc'
        gen double brier = `brier'
        gen double logloss = `logloss'
        gen double cint = `cint'
        gen double cslope = `cslope'
        save "`row_m0'", replace
    restore
    preserve
        use "`checkpoint_dta'", clear
        append using "`row_m0'"
        gsort -auc
        save "`checkpoint_dta'", replace
        export delimited using "`checkpoint_csv'", replace
    restore
}

quietly final_checkpoint_has_model, using("`checkpoint_dta'") model("`MODEL_M1'")
if r(exists) == 0 {
    quietly logit pe `BASE_DIS' `PROC_BEST' i.sex3 if `cand_train_ok'
    predict double p_m1 if `cand_test_ok', pr
    quietly final_eval_binary, outcome(pe) pvar(p_m1) sample(`cand_test_ok')
    local auc = r(auc)
    local brier = r(brier)
    local logloss = r(logloss)
    local cint = r(cint)
    local cslope = r(cslope)
    tempfile row_m1
    preserve
        clear
        set obs 1
        gen str80 model = "`MODEL_M1'"
        gen str48 spec_tag = "`checkpoint_spec_tag'"
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

quietly final_checkpoint_has_model, using("`checkpoint_dta'") model("`MODEL_M2'")
if r(exists) == 0 {
    quietly logit pe `BASE_DIS' `PROC_BEST' i.sex3 i.steroid_b if `cand_train_ok'
    predict double p_m2 if `cand_test_ok', pr
    quietly final_eval_binary, outcome(pe) pvar(p_m2) sample(`cand_test_ok')
    local auc = r(auc)
    local brier = r(brier)
    local logloss = r(logloss)
    local cint = r(cint)
    local cslope = r(cslope)
    tempfile row_m2
    preserve
        clear
        set obs 1
        gen str80 model = "`MODEL_M2'"
        gen str48 spec_tag = "`checkpoint_spec_tag'"
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

quietly final_checkpoint_has_model, using("`checkpoint_dta'") model("`MODEL_M3'")
if r(exists) == 0 {
    quietly logit pe `BASE_DIS' `PROC_BEST' i.sex3 i.hxchf_b if `cand_train_ok'
    predict double p_m3 if `cand_test_ok', pr
    quietly final_eval_binary, outcome(pe) pvar(p_m3) sample(`cand_test_ok')
    local auc = r(auc)
    local brier = r(brier)
    local logloss = r(logloss)
    local cint = r(cint)
    local cslope = r(cslope)
    tempfile row_m3
    preserve
        clear
        set obs 1
        gen str80 model = "`MODEL_M3'"
        gen str48 spec_tag = "`checkpoint_spec_tag'"
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

quietly final_checkpoint_has_model, using("`checkpoint_dta'") model("`MODEL_M4'")
if r(exists) == 0 {
    quietly logit pe `BASE_DIS' `PROC_BEST' i.sex3 i.dialysis_b if `cand_train_ok'
    predict double p_m4 if `cand_test_ok', pr
    quietly final_eval_binary, outcome(pe) pvar(p_m4) sample(`cand_test_ok')
    local auc = r(auc)
    local brier = r(brier)
    local logloss = r(logloss)
    local cint = r(cint)
    local cslope = r(cslope)
    tempfile row_m4
    preserve
        clear
        set obs 1
        gen str80 model = "`MODEL_M4'"
        gen str48 spec_tag = "`checkpoint_spec_tag'"
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

quietly final_checkpoint_has_model, using("`checkpoint_dta'") model("`MODEL_M5'")
if r(exists) == 0 {
    quietly logit pe `BASE_DIS' `PROC_BEST' i.sex3 i.steroid_b i.hxchf_b if `cand_train_ok'
    predict double p_m5 if `cand_test_ok', pr
    quietly final_eval_binary, outcome(pe) pvar(p_m5) sample(`cand_test_ok')
    local auc = r(auc)
    local brier = r(brier)
    local logloss = r(logloss)
    local cint = r(cint)
    local cslope = r(cslope)
    tempfile row_m5
    preserve
        clear
        set obs 1
        gen str80 model = "`MODEL_M5'"
        gen str48 spec_tag = "`checkpoint_spec_tag'"
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

quietly final_checkpoint_has_model, using("`checkpoint_dta'") model("`MODEL_M6'")
if r(exists) == 0 {
    quietly logit pe `BASE_DIS' `PROC_BEST' i.sex3 i.steroid_b i.hxchf_b i.dialysis_b if `cand_train_ok'
    predict double p_m6 if `cand_test_ok', pr
    quietly final_eval_binary, outcome(pe) pvar(p_m6) sample(`cand_test_ok')
    local auc = r(auc)
    local brier = r(brier)
    local logloss = r(logloss)
    local cint = r(cint)
    local cslope = r(cslope)
    tempfile row_m6
    preserve
        clear
        set obs 1
        gen str80 model = "`MODEL_M6'"
        gen str48 spec_tag = "`checkpoint_spec_tag'"
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
keep model n_train n_test pe_test auc brier logloss cint cslope
egen double auc_base = max(cond(model == "`MODEL_M0'", auc, .))
egen double brier_base = max(cond(model == "`MODEL_M0'", brier, .))
egen double logloss_base = max(cond(model == "`MODEL_M0'", logloss, .))
egen double auc_best = max(auc)

gen double delta_auc_vs_m0 = auc - auc_base
gen double delta_brier_vs_m0 = brier - brier_base
gen double delta_logloss_vs_m0 = logloss - logloss_base
gen byte best_auc_model = (auc == auc_best)
gen byte retain_locked = 0

local auc_gain_threshold = 0.001
quietly summarize auc_base, meanonly
local auc_m0 = r(mean)
quietly summarize auc_best, meanonly
local auc_best_val = r(mean)
local auc_gain_best = `auc_best_val' - `auc_m0'

quietly count if best_auc_model == 1
local n_best = r(N)
levelsof model if best_auc_model == 1, local(best_models)

if `auc_gain_best' >= `auc_gain_threshold' & `n_best' == 1 {
    replace retain_locked = 1 if best_auc_model == 1
    local locked_choice "`best_models'"
    local locked_rule "retain single best candidate because AUC gain over M0 is at least 0.001"
}
else {
    replace retain_locked = 1 if model == "`MODEL_M0'"
    local locked_choice "`MODEL_M0'"
    local locked_rule "retain parsimonious M0 because best candidate AUC gain over M0 is less than 0.001"
}

gsort -auc
export delimited using "`final_csv'", replace

capture file close sumfh
local n_train_fmt : display %12.0fc `n_train'
local n_test_fmt : display %12.0fc `n_test'
local pe_test_fmt : display %12.0fc `pe_test'
local auc_best_fmt : display %9.6f `auc_best_val'
local auc_m0_fmt : display %9.6f `auc_m0'
local auc_gain_fmt : display %9.6f `auc_gain_best'
local best_models_text `"`best_models'"'
local best_models_text : subinstr local best_models_text `"""' "", all
local locked_choice_text `"`locked_choice'"'
local locked_choice_text : subinstr local locked_choice_text `"""' "", all
file open sumfh using "${FINAL_OUT}/94_candidate_additions_discharge_summary.txt", write replace
file write sumfh "Locked candidate additions summary" _n
file write sumfh "Created: `c(current_date)' `c(current_time)'" _n
file write sumfh "Common training N: `n_train_fmt'" _n
file write sumfh "Common validation N: `n_test_fmt'" _n
file write sumfh "Validation PE events: `pe_test_fmt'" _n
file write sumfh "Best AUC model(s): `best_models_text'" _n
file write sumfh "Best AUC: `auc_best_fmt'" _n
file write sumfh "M0 AUC: `auc_m0_fmt'" _n
file write sumfh "Best minus M0 AUC delta: `auc_gain_fmt'" _n
file write sumfh "Locked choice: `locked_choice_text'" _n
file write sumfh "Decision rule: `locked_rule'" _n
file close sumfh

di as text "Wrote ${FINAL_TABLES}/94_candidate_additions_discharge.csv"
di as text "Wrote ${FINAL_OUT}/94_candidate_additions_discharge_summary.txt"
di as text "94_candidate_additions_discharge.do complete."
log close
