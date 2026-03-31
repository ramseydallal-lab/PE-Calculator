# Pulmonary Embolism Locked Pipeline

Locked production workspace for the postoperative PE final-model project.

## What is included

- Locked Stata pipeline source in `do/final_model/`
- Project instructions in `AGENTS.md`
- Repo-scoped Codex config in `.codex/`
- Calculator v3 front-end and validation bundle in `output/`
- Reusable monitoring and validation utilities in `tmp/`

## What is intentionally excluded from git

- Large generated datasets (`.dta`)
- Stata model artifacts (`.ster`)
- Logs, temporary files, and archive backups
- Bulk generated tables and figures

These outputs remain in the locked workspace on disk and can be regenerated from the pipeline.

## Key release artifacts

- Calculator: `output/PE_Risk_Calculator_NSQIP_v3.html`
- Calculator model data: `output/PE_Risk_Calculator_NSQIP_v3_modeldata.js`
- Calculator validation report: `output/PE_Risk_Calculator_NSQIP_v3_validation_report.txt`
- Manuscript/supplement methods draft: `output/20260328_locked_methods_manuscript_and_supplement.rtf`

## Current note

Calculator validation passed on 12 of 12 representative cases against the locked exported model outputs.
