# PR #6 — Plan-structure pre-lint (Karma) — plan-fidelity review

**Verdict:** CHANGES_REQUESTED.

## Blocks found

1. **Hook ordering violates plan T4.** Dispatcher is alphabetical; `pre-commit-plan-structure.sh` sorts BEFORE `pre-commit-secrets-guard.sh`, but plan T4 says "ordered AFTER secrets-guard (secrets always win) and BEFORE unit-tests." The install-hooks.sh comment candidly admits the inversion rather than fixing it.
2. **Refactor not performed — duplication instead of extraction.** Plan §3, §5, and T1 DoD all say the new `_lib_plan_structure.sh` should source `_lib_orianna_estimates.sh` ("No logic duplication", "single source of truth"). Actual implementation reimplements the awk estimate-validation logic in parallel and no existing callers were rewired. This IS the drift risk §5 flagged as the primary concern.

## Lesson for future plan-fidelity reviews

When a plan explicitly names a refactoring risk in its own §5 Risks table ("Drift between lib X and prompt Y — T1 explicitly extracts the single source"), verify the diff actually performs the extraction. "Additive new lib" != "extracted single source". Check that old callers were rewired.

Also: when a PR's own `install-hooks.sh` comments acknowledge a deviation from plan ordering ("plan-structure runs before secrets-guard alphabetically"), that is structural divergence, not a design note.

## Follow-up

If Talon fixes B1 by renaming the hook to sort after `pre-commit-secrets-guard.sh`, verify B2 fix also rewires `orianna-fact-check.sh` / `fact-check-plan.sh` — otherwise the `_lib_orianna_estimates.sh` path and the new path will diverge the moment anyone tweaks rules.
