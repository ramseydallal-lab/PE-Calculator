version 19.5
clear all
set more off
set varabbrev off
set linesize 255

/**************************************************************************
* 90_config_final_pe.do
*
* Purpose:
*   Define absolute locked-pipeline paths, create approved output folders,
*   and install shared helper programs for the final model workflow.
*
* Inputs:
*   - Read-only parent project at the absolute SOURCE_ROOT below.
*
* Outputs:
*   - Locked-path globals
*   - Shared helper programs
*
* Dependencies:
*   - Stata 19.5
*   - Source clean dataset:
*       ${SOURCE_DTA}/nsqip_puf20_24_combined_clean.dta
*
* Guardrails:
*   - Uses only absolute paths
*   - Creates only approved locked folders
*   - Does not modify raw/source data
*
* Main analysis steps:
*   1. Define locked and source roots
*   2. Create approved locked folders
*   3. Define shared helper programs
*
* Export steps:
*   - None
*
* Completion:
*   - Prints a configuration-loaded message
**************************************************************************/

* ------------------------------------------------------------------------
* Absolute project paths
* ------------------------------------------------------------------------
global FINAL_ROOT "/Volumes/DallalMinix/ramseymini/Library/CloudStorage/OneDrive-ThomasJeffersonUniversityanditsAffiliates/_Enterprise/stats/Pulmonary Embolism/Locked"
global FINAL_DO "${FINAL_ROOT}/do/final_model"
global FINAL_LOG "${FINAL_ROOT}/logs"
global FINAL_OUT "${FINAL_ROOT}/output"
global FINAL_STER "${FINAL_ROOT}/ster"
global FINAL_TABLES "${FINAL_ROOT}/tables"
global FINAL_FIGURES "${FINAL_ROOT}/figures"
global FINAL_TMP "${FINAL_ROOT}/tmp"
global FINAL_ARCHIVE "${FINAL_ROOT}/archive"

global SOURCE_ROOT "/Volumes/DallalMinix/ramseymini/Library/CloudStorage/OneDrive-ThomasJeffersonUniversityanditsAffiliates/_Enterprise/stats/Pulmonary Embolism"
global SOURCE_DO "${SOURCE_ROOT}/do"
global SOURCE_DTA "${SOURCE_ROOT}/dta"
global SOURCE_OUTPUT "${SOURCE_ROOT}/output"
global SOURCE_TABLES "${SOURCE_ROOT}/tables"
global SOURCE_FIGURES "${SOURCE_ROOT}/figures"
global SOURCE_PROJECT_STATE "${SOURCE_ROOT}/PROJECT_STATE.md"

global SSD_ROOT "/Volumes/DallalMinix/Applications/STATA DTA"
global SSD_CLEAN_DTA "${SSD_ROOT}/nsqip_puf20_24_combined_clean.dta"
global SSD_ANALYSIS_READY_DTA "${SSD_ROOT}/nsqip_puf20_24_analysis_ready_v01.dta"
global SSD_ANALYSIS_READY_POOL_DTA "${SSD_ROOT}/nsqip_puf20_24_analysis_ready_v01_withcpt3pool.dta"

local run_date = subinstr(c(current_date), " ", "", .)
local run_time = subinstr(c(current_time), ":", "", .)
global RUN_DATE "`run_date'"
global RUN_TIME "`run_time'"
global RUNSTAMP "${RUN_DATE}_${RUN_TIME}"

* ------------------------------------------------------------------------
* Approved locked folders
* ------------------------------------------------------------------------
capture mkdir "${FINAL_ROOT}/do"
capture mkdir "${FINAL_DO}"
capture mkdir "${FINAL_LOG}"
capture mkdir "${FINAL_OUT}"
capture mkdir "${FINAL_STER}"
capture mkdir "${FINAL_TABLES}"
capture mkdir "${FINAL_FIGURES}"
capture mkdir "${FINAL_TMP}"
capture mkdir "${FINAL_ARCHIVE}"

* ------------------------------------------------------------------------
* Shared helper programs
* ------------------------------------------------------------------------
capture program drop final_need_file
program define final_need_file
    syntax , FILE(string) [TAG(string)]
    capture confirm file "`file'"
    if _rc {
        if "`tag'" == "" local tag "`file'"
        di as error "FATAL: required file missing: `tag'"
        di as error "Path: `file'"
        exit 601
    }
end

capture program drop final_need_var
program define final_need_var
    syntax , VAR(name)
    capture confirm variable `var'
    if _rc {
        di as error "FATAL: required variable missing: `var'"
        exit 111
    }
end

capture program drop final_pick_build_source
program define final_pick_build_source, rclass
    if fileexists("${SSD_ANALYSIS_READY_POOL_DTA}") {
        return local build_source "${SSD_ANALYSIS_READY_POOL_DTA}"
        return local build_source_tag "ssd_analysis_ready_withcpt3pool"
        exit
    }

    if fileexists("${SSD_ANALYSIS_READY_DTA}") {
        return local build_source "${SSD_ANALYSIS_READY_DTA}"
        return local build_source_tag "ssd_analysis_ready"
        exit
    }

    if fileexists("${SSD_CLEAN_DTA}") {
        return local build_source "${SSD_CLEAN_DTA}"
        return local build_source_tag "ssd_clean"
        exit
    }

    return local build_source "${SOURCE_DTA}/nsqip_puf20_24_combined_clean.dta"
    return local build_source_tag "source_clean"
end

capture program drop final_clamp01
program define final_clamp01
    syntax varname
    quietly replace `varlist' = 1e-15 if `varlist' <= 0 & !missing(`varlist')
    quietly replace `varlist' = 1 - 1e-15 if `varlist' >= 1 & !missing(`varlist')
end

capture program drop final_yn_to_byte
program define final_yn_to_byte
    syntax varname(string) , GEN(name)
    capture drop `gen'

    capture confirm variable `varlist'
    if _rc {
        gen byte `gen' = .
        exit
    }

    capture confirm string variable `varlist'
    if _rc {
        gen byte `gen' = .
        quietly replace `gen' = (`varlist' != 0) if !missing(`varlist')
        exit
    }

    gen strL __tmp_yn = lower(trim(`varlist'))
    gen byte `gen' = .
    quietly replace `gen' = 1 if inlist(__tmp_yn, "yes", "y", "1", "true", "t", "present", "pos", "+")
    quietly replace `gen' = 0 if inlist(__tmp_yn, "no", "n", "0", "false", "f", "absent", "neg", "-", "none", "null", "na", "n/a", ".", "")
    drop __tmp_yn
end

capture program drop final_prepare_locked_analysis
program define final_prepare_locked_analysis
    local has_dvt_source 0

    final_need_var, var(pe)
    final_need_var, var(puf_year)
    final_need_var, var(age_n)
    final_need_var, var(bmi)
    final_need_var, var(optime)
    final_need_var, var(tothlos)
    final_need_var, var(workrvu)
    final_need_var, var(discancr_b)
    final_need_var, var(asaclas_id)
    final_need_var, var(fnstatus2_id)
    final_need_var, var(inout_id)
    final_need_var, var(readmpodays1)
    final_need_var, var(readmpodays2)
    final_need_var, var(readmpodays3)
    final_need_var, var(readmpodays4)
    final_need_var, var(readmpodays5)
    final_need_var, var(retorpodays)
    final_need_var, var(retor2podays)
    final_need_var, var(sex_id)
    final_need_var, var(steroid)
    final_need_var, var(hxchf)
    final_need_var, var(dialysis)

    capture confirm variable cpt
    if _rc {
        capture confirm variable cpt3
        if _rc {
            di as error "FATAL: either cpt or cpt3 must exist to build cpt3_pool"
            exit 111
        }
    }

    capture assert inlist(pe, 0, 1) if !missing(pe)
    if _rc {
        di as error "FATAL: pe is not coded 0/1"
        exit 459
    }

    replace bmi = . if bmi <= 0 | bmi > 100
    replace optime = . if optime <= 0
    replace tothlos = . if tothlos < 0
    replace workrvu = . if workrvu <= 0 | workrvu > 200

    capture confirm variable age_cat
    if _rc {
        gen byte age_cat = .
        replace age_cat = 1 if age_n < 50
        replace age_cat = 2 if inrange(age_n, 50, 64)
        replace age_cat = 3 if inrange(age_n, 65, 74)
        replace age_cat = 4 if age_n >= 75
    }

    capture confirm variable bmi_cat
    if _rc {
        gen byte bmi_cat = .
        replace bmi_cat = 1 if bmi < 30
        replace bmi_cat = 2 if inrange(bmi, 30, 39.999)
        replace bmi_cat = 3 if inrange(bmi, 40, 49.999)
        replace bmi_cat = 4 if bmi >= 50
    }

    capture confirm variable optime_cat
    if _rc {
        gen byte optime_cat = .
        replace optime_cat = 1 if optime < 60
        replace optime_cat = 2 if inrange(optime, 60, 119)
        replace optime_cat = 3 if inrange(optime, 120, 179)
        replace optime_cat = 4 if inrange(optime, 180, 239)
        replace optime_cat = 5 if optime >= 240
    }

    capture confirm variable los3
    if _rc {
        gen byte los3 = .
        replace los3 = 1 if tothlos <= 3
        replace los3 = 2 if inrange(tothlos, 4, 6)
        replace los3 = 3 if tothlos >= 7
    }

    capture confirm variable workrvu_clean
    if _rc gen double workrvu_clean = workrvu
    replace workrvu_clean = . if workrvu_clean <= 0 | workrvu_clean > 200

    capture confirm variable major
    if _rc gen byte major = (workrvu_clean >= 12) if !missing(workrvu_clean)

    capture drop readm_pod_min reop_pod_min any_readm any_reop readm_when reop_when
    capture drop train test n_cpt3_train

    capture confirm variable cpt
    if !_rc {
        capture drop cpt3
        gen int cpt3 = floor(cpt / 100) if !missing(cpt)
        replace cpt3 = . if cpt3 <= 0 | cpt3 > 999
    }
    else {
        final_need_var, var(cpt3)
        replace cpt3 = . if cpt3 <= 0 | cpt3 > 999
    }

    capture confirm variable steroid_b
    if _rc final_yn_to_byte steroid, gen(steroid_b)

    capture confirm variable hxchf_b
    if _rc final_yn_to_byte hxchf, gen(hxchf_b)

    capture confirm variable dialysis_b
    if _rc final_yn_to_byte dialysis, gen(dialysis_b)

    capture confirm variable sex3
    if _rc {
        gen byte sex3 = .
        replace sex3 = 0 if sex_id == 1
        replace sex3 = 1 if sex_id == 3
    }

    capture confirm variable dvt_postop
    if !_rc {
        local has_dvt_source 1
        replace dvt_postop = . if !inlist(dvt_postop, 0, 1) & !missing(dvt_postop)
    }
    else {
        capture confirm variable othdvt_b
        if !_rc {
            local has_dvt_source 1
            gen byte dvt_postop = othdvt_b if !missing(othdvt_b)
        }
        else {
            capture confirm variable othdvt
            if !_rc {
                local has_dvt_source 1
                capture confirm string variable othdvt
                if _rc == 0 {
                    gen byte dvt_postop = 0
                    replace dvt_postop = 1 if !inlist(othdvt, "No Complication", "No", "NULL", "")
                    replace dvt_postop = . if othdvt == "" | missing(othdvt)
                }
                else {
                    gen byte dvt_postop = (othdvt >= 1 & !missing(othdvt))
                }
            }
            else {
                gen byte dvt_postop = .

                capture confirm numeric variable nothdvt
                if !_rc {
                    local has_dvt_source 1
                    replace dvt_postop = (nothdvt == 1) if !missing(nothdvt)
                }

                capture confirm numeric variable dothdvt
                if !_rc {
                    local has_dvt_source 1
                    replace dvt_postop = (!missing(dothdvt) & dothdvt != -99) if missing(dvt_postop)
                }
            }
        }
    }

    capture assert inlist(dvt_postop, 0, 1) if !missing(dvt_postop)
    if _rc {
        di as error "FATAL: dvt_postop is not coded 0/1 after locked derivation"
        exit 459
    }

    capture drop vte_composite
    gen byte vte_composite = .
    replace vte_composite = 1 if pe == 1
    replace vte_composite = 1 if dvt_postop == 1
    replace vte_composite = 0 if pe == 0 & dvt_postop == 0

    if `has_dvt_source' {
        quietly summarize dvt_postop if inrange(puf_year, 2020, 2024), meanonly
        if r(N) > 0 {
            di as text "Locked DVT prevalence = " %9.6f r(mean)
            if r(mean) > 0.20 | r(mean) < 0.0001 {
                di as error "WARN: DVT prevalence is extreme; verify OTHDVT/NOTHDVT/DOTHDVT coding."
            }
        }
        else {
            di as error "WARN: dvt_postop was derived but is missing for all 2020-2024 observations."
        }
    }
    else {
        di as error "WARN: no DVT source variable found; dvt_postop and vte_composite remain missing where pe==0."
    }

    foreach v in readmpodays1 readmpodays2 readmpodays3 readmpodays4 readmpodays5 retorpodays retor2podays {
        replace `v' = . if `v' == -99
    }

    egen int readm_pod_min = rowmin(readmpodays1 readmpodays2 readmpodays3 readmpodays4 readmpodays5)
    egen int reop_pod_min = rowmin(retorpodays retor2podays)
    gen byte any_readm = !missing(readm_pod_min)
    gen byte any_reop = !missing(reop_pod_min)

    gen byte readm_when = 0
    replace readm_when = 1 if inrange(readm_pod_min, 0, 3)
    replace readm_when = 2 if inrange(readm_pod_min, 4, 7)
    replace readm_when = 3 if inrange(readm_pod_min, 8, 14)
    replace readm_when = 4 if inrange(readm_pod_min, 15, 30)

    gen byte reop_when = 0
    replace reop_when = 1 if inrange(reop_pod_min, 0, 3)
    replace reop_when = 2 if inrange(reop_pod_min, 4, 7)
    replace reop_when = 3 if inrange(reop_pod_min, 8, 14)
    replace reop_when = 4 if inrange(reop_pod_min, 15, 30)

    gen byte train = inrange(puf_year, 2020, 2023)
    gen byte test = (puf_year == 2024)

    capture confirm variable cpt3_pool
    if _rc {
        bys cpt3: egen long n_cpt3_train = total(train)
        gen int cpt3_pool = cpt3
        replace cpt3_pool = 999 if missing(cpt3_pool)
        replace cpt3_pool = 999 if n_cpt3_train < 20000
        capture drop n_cpt3_train
    }

    capture confirm variable wrvu_s1
    local need_spline = _rc
    capture confirm variable wrvu_s2
    if _rc local need_spline = 1
    capture confirm variable wrvu_s3
    if _rc local need_spline = 1
    capture confirm variable wrvu_s4
    if _rc local need_spline = 1

    if `need_spline' {
        preserve
            keep if train == 1 & !missing(workrvu_clean)
            quietly count
            if r(N) == 0 {
                di as error "FATAL: no nonmissing workrvu_clean values in training data"
                restore
                exit 459
            }
            centile workrvu_clean, centile(25 50 75)
            local k1 = r(c_1)
            local k2 = r(c_2)
            local k3 = r(c_3)
        restore

        mkspline wrvu_s1 `k1' wrvu_s2 `k2' wrvu_s3 `k3' wrvu_s4 = workrvu_clean
    }

    order pe dvt_postop vte_composite puf_year train test age_cat bmi_cat discancr_b optime_cat los3 asaclas_id fnstatus2_id inout_id ///
        workrvu_clean wrvu_s1 wrvu_s2 wrvu_s3 wrvu_s4 major cpt3 cpt3_pool ///
        readm_when reop_when sex3 steroid_b hxchf_b dialysis_b
end

capture program drop final_eval_binary
program define final_eval_binary, rclass
    syntax , OUTCOME(name) PVAR(name) SAMPLE(name)

    tempvar ok p lp pc brier_i ll_i
    gen byte `ok' = (`sample' == 1) & !missing(`outcome', `pvar')

    quietly count if `ok'
    local n_eval = r(N)
    quietly count if `ok' & `outcome' == 1
    local n_event = r(N)

    if `n_eval' == 0 {
        return scalar n_eval = 0
        return scalar n_event = 0
        return scalar auc = .
        return scalar brier = .
        return scalar logloss = .
        return scalar cint = .
        return scalar cslope = .
        drop `ok'
        exit
    }

    gen double `p' = `pvar' if `ok'
    final_clamp01 `p'
    gen double `lp' = log(`p' / (1 - `p')) if `ok'

    quietly roctab `outcome' `p' if `ok', nodetail
    return scalar auc = r(area)

    gen double `brier_i' = (`p' - `outcome')^2 if `ok'
    quietly summarize `brier_i' if `ok', meanonly
    return scalar brier = r(mean)

    gen double `pc' = min(max(`p', 1e-15), 1 - 1e-15) if `ok'
    gen double `ll_i' = -(`outcome' * ln(`pc') + (1 - `outcome') * ln(1 - `pc')) if `ok'
    quietly summarize `ll_i' if `ok', meanonly
    return scalar logloss = r(mean)

    capture quietly logit `outcome' if `ok', offset(`lp')
    if _rc return scalar cint = .
    else   return scalar cint = _b[_cons]

    capture quietly logit `outcome' c.`lp' if `ok'
    if _rc return scalar cslope = .
    else   return scalar cslope = _b[`lp']

    return scalar n_eval = `n_eval'
    return scalar n_event = `n_event'

    drop `ok' `p' `lp' `pc' `brier_i' `ll_i'
end

capture program drop final_export_betas
program define final_export_betas
    syntax , USING(string) MODELNAME(string)

    tempname bh
    matrix `bh' = e(b)
    local cnames : colnames `bh'
    local k = colsof(`bh')

    tempfile beta_tmp
    tempname posth
    postfile `posth' str64 model str128 term double coef using "`beta_tmp'", replace
    forvalues j = 1/`k' {
        local tname : word `j' of `cnames'
        post `posth' ("`modelname'") ("`tname'") (`bh'[1, `j'])
    }
    postclose `posth'

    preserve
        use "`beta_tmp'", clear
        export delimited using "`using'", replace
    restore
end

capture program drop final_checkpoint_has_model
program define final_checkpoint_has_model, rclass
    syntax , USING(string) MODEL(string)

    capture confirm file "`using'"
    if _rc {
        return scalar exists = 0
        exit
    }

    preserve
        use "`using'", clear
        capture confirm variable model
        if _rc {
            restore
            return scalar exists = 0
            exit
        }

        quietly count if model == "`model'"
        local has_model = (r(N) > 0)
    restore

    return scalar exists = `has_model'
end

di as text "Configuration loaded for locked PE final model pipeline."
di as text "Locked root: ${FINAL_ROOT}"
di as text "Source root: ${SOURCE_ROOT}"
di as text "90_config_final_pe.do complete."
