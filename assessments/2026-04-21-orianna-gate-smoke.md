# Orianna Gate v2 — End-to-End Smoke Report

> **Status: PLACEHOLDER**
> This report is stubbed per T11.1. It will be filled in during Phase 11 execution
> once the full implementation (T1–T8) is complete and the smoke harness
> (`scripts/test-orianna-lifecycle-smoke.sh`) runs successfully end-to-end.
> Plan reference: `plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §T11.1`

## When to fill in

Run `bash scripts/test-orianna-lifecycle-smoke.sh` after all Phase 5–8 scripts are
implemented. Replace this placeholder with:

- Date and commit SHA of the smoke run
- Pass/fail table for all 10 cases (T5.7 cases 1–9 + T7.2 case 10)
- Any failures with root cause and fix
- Confirmation that the freeze lift (T8.Z, T11.2) is safe to execute

## Expected sections (Phase 11)

### Run metadata

| Field | Value |
|-------|-------|
| Date | TBD |
| Branch / commit | TBD |
| Runner | Vi (TEST agent) |
| Harness | `scripts/test-orianna-lifecycle-smoke.sh` |

### Results

| Case | Description | Result |
|------|-------------|--------|
| APPROVED_SIGN | Sign approved phase | TBD |
| APPROVED_VERIFY | Verify approved signature | TBD |
| EDIT_STALE_DETECT | Stale sig detected after body edit | TBD |
| RESIGN_AFTER_EDIT | Re-sign after body edit | TBD |
| INPROGRESS_SIGN | Sign in-progress phase | TBD |
| PROMOTE_TO_INPROGRESS | Promote to in-progress | TBD |
| IMPLEMENTED_SIGN | Sign implemented phase | TBD |
| PROMOTE_TO_IMPLEMENTED | Promote to implemented | TBD |
| POSTHOC_ALL_SIGS_VALID | Post-hoc verify all 3 signatures | TBD |
| OFFLINE_FAIL_T7_2 | Offline-fail (claude CLI absent) | TBD |

### Failures and fixes

TBD

### Freeze lift recommendation

TBD — populated when all 10 cases pass.
