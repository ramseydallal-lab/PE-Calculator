# Recurring Stata Failure Modes

- Invalid syntax from unmatched `///` continuation lines.
- `preserve` inside code paths that may already be inside `preserve`.
- `restore` not reached after `exit`, `error`, or conditional branching.
- Save or export failure because the destination folder was not created first.
- Broad `capture drop` removing variables later needed by the script.
- Hard-coded temp paths instead of local `tempfile` objects.
- Local macro referenced outside its scope.
- Duplicate local macro names shadowing critical macros in the same block.
- Factor-variable specification changing base levels unexpectedly across scripts.
- `postfile` / `post` / `postclose` mismatch or variable-type mismatch.
- Merge or append operations changing the intended validation cohort.
- Prediction or ablation comparisons using non-identical complete-case samples.
- Rebuilding `cpt3` or pooled procedure variables inconsistently across scripts.
- String yes/no source variables being recoded inconsistently into byte indicators.
- Calculator exports missing the final locked coefficient set or knot metadata.
- Runtime repair should prefer reading the corresponding log in `logs/` first, then revising the numbered do-file in `do/final_model/`.
