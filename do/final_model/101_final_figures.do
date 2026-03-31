version 19.5
clear all
set more off
set varabbrev off
set linesize 255

/**************************************************************************
* 101_final_figures.do
*
* Purpose:
*   Generate locked final figures for discrimination and calibration.
*
* Inputs:
*   - ${FINAL_OUT}/96_final_discharge_predictions_2024.dta
*   - ${FINAL_OUT}/97_final_update_predictions_2024.dta
*
* Outputs:
*   - ${FINAL_FIGURES}/101_roc_discharge.pdf
*   - ${FINAL_FIGURES}/101_roc_update.pdf
*   - ${FINAL_FIGURES}/101_calibration_discharge.pdf
*   - ${FINAL_FIGURES}/101_calibration_update.pdf
*   - ${FINAL_FIGURES}/101_calibration_vigintile_discharge.pdf
*   - ${FINAL_FIGURES}/101_calibration_vigintile_update.pdf
*   - ${FINAL_TABLES}/101_calibration_decile_discharge.csv
*   - ${FINAL_TABLES}/101_calibration_decile_update.csv
*   - ${FINAL_TABLES}/101_calibration_vigintile_discharge.csv
*   - ${FINAL_TABLES}/101_calibration_vigintile_update.csv
*
* Dependencies:
*   - 90_config_final_pe.do
*   - 96_fit_final_discharge_model.do
*   - 97_fit_final_update_model.do
*
* Guardrails:
*   - Uses only locked prediction files
*   - Exports figures programmatically
*
* Main analysis steps:
*   1. Draw ROC figures for discharge and update models
*   2. Build decile-based calibration plots
*   3. Build vigintile and loess-smoothed calibration plots
*
* Export steps:
*   - PDF figures in locked figures directory
*
* Completion:
*   - Prints figure paths
**************************************************************************/

do "/Volumes/DallalMinix/ramseymini/Library/CloudStorage/OneDrive-ThomasJeffersonUniversityanditsAffiliates/_Enterprise/stats/Pulmonary Embolism/Locked/do/final_model/90_config_final_pe.do"

capture log close _all
log using "${FINAL_LOG}/101_final_figures.log", replace text

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
        di as error "FATAL: unsupported figure model specification: `model'"
        exit 198
    }

    final_need_file, file("`dta'") tag("`model' prediction dataset")
    use "`dta'", clear

    quietly summarize `pvar' if !missing(pe, `pvar'), meanonly
    local x_max = r(max)
    if missing(`x_max') | `x_max' <= 0 local x_max = 0.02
    if `x_max' < 0.02 local x_max = 0.02

    quietly roctab pe `pvar', graph
    graph export "${FINAL_FIGURES}/101_roc_`model'.pdf", replace

    preserve
        xtile risk_decile = `pvar', nq(10)
        collapse (mean) pred_mean=`pvar' obs_mean=pe (count) n=pe, by(risk_decile)
        export delimited using "${FINAL_TABLES}/101_calibration_decile_`model'.csv", replace
        twoway ///
            (scatter obs_mean pred_mean, mcolor(navy) msymbol(circle)) ///
            (line obs_mean pred_mean, lcolor(navy)) ///
            (function y = x, range(0 `x_max') lpattern(dash) lcolor(maroon)), ///
            xtitle("Mean predicted risk") ///
            ytitle("Observed PE rate") ///
            title("Calibration by Decile: `model'") ///
            legend(off)
        graph export "${FINAL_FIGURES}/101_calibration_`model'.pdf", replace
    restore

    preserve
        xtile risk_vigintile = `pvar', nq(20)
        collapse (mean) pred_mean=`pvar' obs_mean=pe (count) n=pe, by(risk_vigintile)
        sort pred_mean
        lowess obs_mean pred_mean, bwidth(.8) nograph gen(obs_loess)
        export delimited using "${FINAL_TABLES}/101_calibration_vigintile_`model'.csv", replace
        twoway ///
            (scatter obs_mean pred_mean, mcolor(navy) msymbol(circle_hollow)) ///
            (line obs_mean pred_mean, sort lcolor(navy) lpattern(solid)) ///
            (line obs_loess pred_mean, sort lcolor(forest_green) lwidth(medthick)) ///
            (function y = x, range(0 `x_max') lpattern(dash) lcolor(maroon)), ///
            xtitle("Mean predicted risk") ///
            ytitle("Observed PE rate") ///
            title("Calibration by Vigintile: `model'") ///
            subtitle("Observed vs predicted with loess-smoothed trend") ///
            legend(order(1 "Observed vigintiles" 3 "Loess smooth" 4 "Ideal")) 
        graph export "${FINAL_FIGURES}/101_calibration_vigintile_`model'.pdf", replace
    restore
}

di as text "Wrote locked figures to ${FINAL_FIGURES}"
di as text "Wrote calibration summary tables to ${FINAL_TABLES}"
di as text "101_final_figures.do complete."
log close
