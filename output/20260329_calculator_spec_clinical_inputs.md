# PE / DVT Calculator Specification (Clinical Input Draft)

## Purpose

This document defines the proposed clinician-facing input set for the locked pulmonary embolism calculator and the planned postoperative DVT/VTE secondary outputs. The calculator is intended to be:

- easy to use at the bedside
- restricted to clinically available data
- parsimonious rather than statistically maximal
- transparent about differences from the locked research models

## Core Design Principles

1. The manuscript models remain the locked research reference.
2. The bedside calculator may simplify weak predictors if their incremental contribution is negligible.
3. Users should enter clinical concepts, not encoded Stata variables.
4. Procedure-related inputs should be selected through a CPT/procedure lookup that maps internally to the locked procedure terms.
5. The calculator should estimate observed risk under real-world NSQIP-era care patterns, not untreated biologic thrombosis risk.

## Research Model vs Simplified Calculator

The locked research PE models include baseline functional status (`fnstatus2_id`). The simplified calculator is planned to omit this question because locked ablation testing showed only trivial change in discrimination when functional status was removed from the discharge model.

The simplified calculator should therefore include an explicit note that:

- the research model included functional status
- the bedside calculator omits this input to improve usability
- resulting risk estimates may differ trivially from the full research model

## Required Warning Language

Suggested calculator warning:

> This calculator was developed from ACS-NSQIP data reflecting real-world care at participating hospitals from 2020-2024. Predicted risk represents observed postoperative PE or DVT risk under contemporaneous practice patterns, not untreated baseline thrombosis risk. Thromboprophylaxis and other preventive care may not be fully captured in the source data. Some patients who appear lower risk may have had their observed risk reduced by prophylaxis or other care processes. Use these estimates to support, not replace, clinician assessment of thrombosis risk, bleeding risk, and prophylaxis decisions.

## Proposed Calculator Modes

### 1. Discharge PE Risk

Inputs:

- Age at operation (years)
- Body mass index (kg/m^2)
- Disseminated cancer present
- Operative time (minutes)
- Postoperative hospital length of stay at discharge (days)
- ASA physical status
- Inpatient vs outpatient case
- Procedure selection

Notes:

- Functional status intentionally omitted from the simplified bedside tool
- Procedure selection should drive internal mapping to pooled CPT family and work RVU terms

### 2. Update PE Risk

Inputs:

- All discharge inputs above
- Time from surgery to first readmission within 30 days
- Time from surgery to first reoperation within 30 days

### 3. Discharge DVT Risk

Inputs:

- Same simplified discharge inputs as above

### 4. Discharge VTE Composite Risk

Inputs:

- Same simplified discharge inputs as above

## Exact Input Definitions

### Age at operation

Clinical prompt:
- "Patient age at operation (years)"

Internal model term:
- `age_cat`

Locked category mapping:
- `< 50 years` -> `age_cat = 1`
- `50 to 64 years` -> `age_cat = 2`
- `65 to 74 years` -> `age_cat = 3`
- `>= 75 years` -> `age_cat = 4`

### Body mass index

Clinical prompt:
- "Body mass index (kg/m^2)"

Internal model term:
- `bmi_cat`

Locked category mapping:
- `< 30.0` -> `bmi_cat = 1`
- `30.0 to 39.9` -> `bmi_cat = 2`
- `40.0 to 49.9` -> `bmi_cat = 3`
- `>= 50.0` -> `bmi_cat = 4`

### Disseminated cancer

Clinical prompt:
- "Disseminated cancer present at the time of surgery?"

Internal model term:
- `discancr_b`

Locked coding:
- `No` -> `0`
- `Yes` -> `1`

Implementation note:
- The calculator should use a plain yes/no question and not expose the encoded binary variable name.

### Operative time

Clinical prompt:
- "Total operative time (minutes)"

Internal model term:
- `optime_cat`

Locked category mapping:
- `< 60 minutes` -> `optime_cat = 1`
- `60 to 119 minutes` -> `optime_cat = 2`
- `120 to 179 minutes` -> `optime_cat = 3`
- `180 to 239 minutes` -> `optime_cat = 4`
- `>= 240 minutes` -> `optime_cat = 5`

### Postoperative length of stay at discharge

Clinical prompt:
- "Postoperative length of stay at discharge (days)"

Internal model term:
- `los3`

Locked category mapping:
- `0 to 3 days` -> `los3 = 1`
- `4 to 6 days` -> `los3 = 2`
- `>= 7 days` -> `los3 = 3`

Implementation note:
- This is a discharge-stage calculator input and should not be shown preoperatively.

### ASA physical status

Clinical prompt:
- "ASA physical status"

Internal model term:
- `asaclas_id`

Locked modeled categories:
- `1 = Healthy`
- `2 = Mild disturbance`
- `3 = Severe disturbance`
- `4 = Life threat`
- `5 = Moribund`
- `6 = None assigned / unknown`

Implementation note:
- The user-facing labels should be clinician-readable.

### Inpatient vs outpatient case

Clinical prompt:
- "Index operation inpatient or outpatient?"

Internal model term:
- `inout_id`

Locked coding:
- `Inpatient` -> reference category
- `Outpatient` -> modeled category

### Procedure selection

Clinical prompt:
- "Select procedure or CPT code"

Internal model terms:
- `cpt3_pool`
- `wrvu_s1`, `wrvu_s2`, `wrvu_s3`, `wrvu_s4` for PE discharge/update
- `workrvu_clean` may still appear in historical drafts but is not the preferred locked PE discharge backbone

Recommended user experience:
- The user should search by CPT code or common procedure name.
- The calculator should then internally map the selected procedure to:
  - pooled CPT-3 family
  - work RVU
  - spline-transformed work RVU terms where required

Implementation note:
- Do not ask the clinician to manually enter `cpt3_pool`.
- Manual work RVU entry should be optional at most, not required.

### Readmission timing

Clinical prompt:
- "Time from index operation to first readmission within 30 days"

Internal model term:
- `readm_when`

Locked category mapping:
- `No readmission` -> `0`
- `0 to 3 days` -> `1`
- `4 to 7 days` -> `2`
- `8 to 14 days` -> `3`
- `15 to 30 days` -> `4`

### Reoperation timing

Clinical prompt:
- "Time from index operation to first reoperation within 30 days"

Internal model term:
- `reop_when`

Locked category mapping:
- `No reoperation` -> `0`
- `0 to 3 days` -> `1`
- `4 to 7 days` -> `2`
- `8 to 14 days` -> `3`
- `15 to 30 days` -> `4`

## Inputs Deliberately Excluded From Simplified Calculator

### Functional status

Research-model term:
- `fnstatus2_id`

Reason for omission:
- improved bedside usability
- negligible incremental discrimination in locked discharge ablation testing

Required transparency note:
- omitted from simplified bedside calculator despite inclusion in the locked manuscript model

### Weak exploratory candidate additions

Not recommended for simplified calculator:
- `sex3`
- `steroid_b`
- `hxchf_b`
- `dialysis_b`

Reason:
- candidate-addition testing did not show meaningful out-of-sample improvement sufficient for retention in the locked final discharge model

## Outcome Labels for Calculator

### PE discharge risk

Suggested label:
- "Observed 30-day postoperative pulmonary embolism risk at discharge"

### PE update risk

Suggested label:
- "Updated observed 30-day postoperative pulmonary embolism risk after interval events"

### DVT discharge risk

Suggested label:
- "Observed 30-day postoperative deep venous thrombosis risk at discharge"

### VTE discharge risk

Suggested label:
- "Observed 30-day postoperative venous thromboembolism risk at discharge"

## Clinician Guidance Text

Suggested short interpretation block:

> This tool estimates observed postoperative thrombosis risk based on ACS-NSQIP patients treated under contemporary practice patterns. It is best used to support decisions about surveillance, counseling, and prophylaxis discussions after considering bleeding risk, procedure context, and local standards of care.

Suggested caution block:

> Because prophylaxis exposure is not fully captured in the source data, low predicted risk does not necessarily equal low untreated biologic risk.

## Implementation Recommendation

For version 3 of the calculator:

1. Keep the manuscript models unchanged.
2. Build the bedside interface around clinically entered concepts only.
3. Omit functional status from the bedside UI.
4. Make procedure selection the main structured input.
5. Present PE as the primary output.
6. Add DVT and VTE as secondary outputs once the locked coefficient exports are rerun from the upgraded pipeline.
