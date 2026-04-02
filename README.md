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

## Public deployment security notes

This calculator is designed to be published as a public informational site with no authentication, no PHI collection, and no client-side persistence of user-entered values.

Minimum deployment expectations:

- Serve over HTTPS only
- Do not add analytics, ad tags, session replay, trackers, or third-party embeds
- Do not log calculator inputs at the web server, CDN, or analytics layer
- Do not add free-text fields for patient information
- Keep browser-side protections enabled in the HTML: CSP, referrer policy, permissions policy, and no-store cache directives

Recommended host-level headers, which should be configured at the platform/CDN layer where supported:

- `Strict-Transport-Security`
- `X-Content-Type-Options: nosniff`
- `Content-Security-Policy` as enforced response header
- `Referrer-Policy: no-referrer`

Operational policy for public use:

- Display a visible notice not to enter direct patient identifiers
- Treat the tool as clinical decision support and educational content, not treatment automation
- Re-review content and security settings before adding any feature that transmits, stores, or exports user-entered data
