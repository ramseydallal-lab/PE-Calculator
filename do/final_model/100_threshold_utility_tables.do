version 19.5
clear all
set more off
set varabbrev off
set linesize 255

/**************************************************************************
* 100_threshold_utility_tables.do
*
* Purpose:
*   Export threshold operating characteristics for the locked discharge
*   and update models.
*
* Inputs:
*   - ${FINAL_OUT}/96_final_discharge_predictions_2024.dta
*   - ${FINAL_OUT}/97_final_update_predictions_2024.dta
*
* Outputs:
*   - ${FINAL_TABLES}/100_threshold_utility_tables.csv
*   - ${FINAL_TABLES}/100_top_percent_capture.csv
*
* Dependencies:
*   - 90_config_final_pe.do
*   - 96_fit_final_discharge_model.do
*   - 97_fit_final_update_model.do
*
* Guardrails:
*   - Uses explicit threshold lists
*   - Computes all metrics on the same scored validation cohort within model
*
* Main analysis steps:
*   1. Load discharge and update predictions
*   2. Compute operating characteristics by threshold
*   3. Compute capture by top-risk percentages
*
* Export steps:
*   - Threshold utility CSV
*   - Top-percentage capture CSV
*
* Completion:
*   - Prints export paths
**************************************************************************/

do "/Volumes/DallalMinix/ramseymini/Library/CloudStorage/OneDrive-ThomasJeffersonUniversityanditsAffiliates/_Enterprise/stats/Pulmonary Embolism/Locked/do/final_model/90_config_final_pe.do"

capture log close _all
log using "${FINAL_LOG}/100_threshold_utility_tables.log", replace text

tempfile thresh topx
tempname th tx
postfile `th' str12 model double threshold long n_eval long n_flagged long tp long fp long tn long fn ///
    double pct_flagged sensitivity pct_events_captured specificity ppv npv nnt_from_ppv using "`thresh'", replace
postfile `tx' str12 model double top_percent long n_eval long n_flagged long pe_captured double pct_pe_captured using "`topx'", replace

foreach model in discharge update {
    if "`model'" == "discharge" {
        local dta "${FINAL_OUT}/96_final_discharge_predictions_2024.dta"
        local pvar "p_discharge_locked"
    }
    else if "`model'" == "update" {
        local dta "${FINAL_OUT}/97_final_update_predictions_2024.dta"
        local pvar "p_update_locked"
    }
    else {
        di as error "FATAL: unsupported threshold model specification: `model'"
        exit 198
    }

    final_need_file, file("`dta'") tag("`model' prediction dataset")
    use "`dta'", clear

    quietly count if !missing(pe, `pvar')
    local n_eval = r(N)
    quietly count if !missing(pe, `pvar') & pe == 1
    local n_event = r(N)

    foreach t in 0.003 0.005 0.010 0.020 {
        capture drop flag
        gen byte flag = (`pvar' >= `t') if !missing(pe, `pvar')
        quietly count if flag == 1
        local n_flagged = r(N)
        quietly count if pe == 1 & flag == 1
        local tp = r(N)
        quietly count if pe == 0 & flag == 1
        local fp = r(N)
        quietly count if pe == 0 & flag == 0
        local tn = r(N)
        quietly count if pe == 1 & flag == 0
        local fn = r(N)

        local pct_flagged = .
        local sensitivity = .
        local pct_events_captured = .
        local specificity = .
        local ppv = .
        local npv = .
        local nnt_from_ppv = .

        if `n_eval' > 0 local pct_flagged = 100 * `n_flagged' / `n_eval'
        if (`tp' + `fn') > 0 local sensitivity = `tp' / (`tp' + `fn')
        if `n_event' > 0 local pct_events_captured = 100 * `tp' / `n_event'
        if (`tn' + `fp') > 0 local specificity = `tn' / (`tn' + `fp')
        if (`tp' + `fp') > 0 local ppv = `tp' / (`tp' + `fp')
        if (`tn' + `fn') > 0 local npv = `tn' / (`tn' + `fn')
        if `ppv' > 0 local nnt_from_ppv = 1 / `ppv'

        post `th' ("`model'") (`t') (`n_eval') (`n_flagged') (`tp') (`fp') (`tn') (`fn') ///
            (`pct_flagged') (`sensitivity') (`pct_events_captured') (`specificity') (`ppv') (`npv') (`nnt_from_ppv')
        drop flag
    }

    foreach top in 5 10 20 {
        capture drop topflag
        _pctile `pvar', p(`=100-`top'')
        local cutoff = r(r1)
        gen byte topflag = (`pvar' >= `cutoff') if !missing(pe, `pvar')
        quietly count if topflag == 1
        local n_flagged = r(N)
        quietly count if pe == 1 & topflag == 1
        local pe_captured = r(N)
        local pct_capture = .
        if `n_event' > 0 local pct_capture = 100 * `pe_captured' / `n_event'
        post `tx' ("`model'") (`top') (`n_eval') (`n_flagged') (`pe_captured') (`pct_capture')
        drop topflag
    }
}

postclose `th'
postclose `tx'

preserve
    use "`thresh'", clear
    export delimited using "${FINAL_TABLES}/100_threshold_utility_tables.csv", replace
restore

preserve
    use "`topx'", clear
    export delimited using "${FINAL_TABLES}/100_top_percent_capture.csv", replace
restore

di as text "Wrote ${FINAL_TABLES}/100_threshold_utility_tables.csv"
di as text "Wrote ${FINAL_TABLES}/100_top_percent_capture.csv"
di as text "100_threshold_utility_tables.do complete."
log close
