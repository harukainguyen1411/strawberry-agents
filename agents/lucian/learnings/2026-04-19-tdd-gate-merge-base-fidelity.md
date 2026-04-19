# 2026-04-19 — tdd-gate merge-base range fidelity (PR #55)

## Context
PR #55 on strawberry-app swapped `github.event.before` for `git merge-base HEAD origin/main` as BASE in the push-event branch of `tdd-gate.yml`. No formal plan; reviewed against Rule 12 directly.

## Ruling
Approved. Merge-base range is strictly more inclusive than BEFORE..SHA and matches the pull_request branch's PR_BASE..PR_HEAD exactly. Rule 12 intent ("xfail before impl on same branch") is preserved; no new escape hatch.

## Fidelity heuristic for range changes in enforcement gates
When a gate's commit range changes, ask:
1. Is the new range a superset of the old range for all realistic histories? (Yes here — merge-base walks back at least as far as any single push's BEFORE.)
2. Does the new range admit any commit sequence that the invariant's English text forbids? (No — "same branch" is exactly what merge-base captures.)
3. Does the new range reject any sequence the old range accepted? (No — strictly more inclusive.)

If (1) yes, (2) no, (3) no → intent preserved.

## Drift notes worth surfacing but not blocking
- `git fetch origin main --depth=0` is not idiomatic; `fetch-depth: 0` on actions/checkout is the canonical fix for shallow-clone + merge-base.
- Workflow files aren't in `apps/**`, so Rule 13's regression-test mandate is textually ambiguous for CI infra. Flagged as follow-up rather than block.

## Review URL
https://github.com/harukainguyen1411/strawberry-app/pull/55#pullrequestreview (APPROVED as strawberry-reviewers)
