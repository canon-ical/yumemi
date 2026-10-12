# BRIEF yumemi-0121 r2 ── reviewer P0 1 and three P1

Batch: yumemi-0121 (r2)
Base: impl/yumemi-0121 `fd6cbf6` (r1 `6edc7ac` + reviewer's README fix)
Parent goal: ship 0.12.1 without creating silent failures and without changing how ★ is written.

## What to close (reviewer gate 2, see results "## r2" — copy the findings there)

1. **P0-1 nested Refused branches go silent.** The runtime skips `failed` when the refusal's `when` branch exists *anywhere* in the Component, but a `when(Refused(..))` branch nested inside the same Service's `when(Failed)` branch is hidden with it. Count only refusal branches that are not inside a `<svc>.failed` branch. Sibling form (BRIEF item 4) shows only the refusal text; nested form shows both texts as in 0.12.0. Add the nested case to the state check, align README (around lines 133/137) and the results' "51 v6 に足す行". Re-run the copied app's muses and console tests and report which of the 6 earlier failures remain
2. **P1-1 a Component inside a ★ `html.form`.** The HTML parser drops the Component's form, so its controls submit through the outer form's method (GET puts the body in the URL). Make the generator stop this nesting with a new rule (★ that nests like this never worked, so no working ★ changes). Give the rule a number after the current last one and a test
3. **P1-2 owner given but not in the table.** When `owner` is passed and `<owner>/<name>` is not registered, return `unregistered read` instead of falling back to name-only lookup. Test it
4. **P1-5** extend `declared_and_a_star_constructor_of_the_same_name_test` to check the stop code and that `consent_missing` sits in `refused` and not in `requires`

Not this time: P1-3 (Failed vs css.State(Failed)), P1-4 (requires not a literal list / nested service dirs) — note under "次の版へ".

Checks as in the r1 BRIEF: root `npm ci` → `gleam test` (read the text, not the exit code), fixtures regenerate with diff 0, the copied app's generator exit 0. No version bump, no tag, no publish. No product name or executive name in src/README/commit messages. Commit as `git-as 真壁`.
