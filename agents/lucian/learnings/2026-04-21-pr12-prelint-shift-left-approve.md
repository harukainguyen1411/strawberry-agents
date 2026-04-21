# PR #12 — prelint shift-left approve (Karma plan)

Date: 2026-04-21
Concern: personal
Verdict: APPROVE

## Plan

`plans/approved/personal/2026-04-21-plan-prelint-shift-left.md` — Orianna body-hash `7347316a9dcc3cd6f760e580039dafa85dbb43b66d8e1a923a438fb97f455857`. Quick-lane Karma plan, 4 tasks (T1-T4), 130 total minutes.

## Fidelity verdict

All four tasks implemented faithfully. Rule 12 xfail-first ordering held (T1 commit `26eb0d4` precedes T2 `19d15ee`). Body hash unchanged since sign → no silent plan drift. 5-rule parity to Orianna confirmed (not subset, not superset) per plan §3 table. Docs (`plan-lifecycle.md` + `key-scripts.md`) enumerate all five rules with Orianna-parity framing and explicit grandfathering.

## Drift findings

1. **Hook-name drift** — plan said "extend `pre-commit-t-plan-structure.sh`"; PR created a parallel `pre-commit-zz-plan-structure.sh` and marked the old hook superseded. Invariant (all 5 rules at pre-commit) still holds, so non-blocking drift note.
2. **Dogfooding OQ1 hit** — running the new hook against the plan file itself flags `` `proposed/` `` / `` `approved/` `` on line 95 as missing paths. Plan §4 claimed it dogfoods; it doesn't if re-staged. Grandfathering saves it today; follow-up needed on next edit.
3. **Perf claim not reproducible** — commit/PR body claim 180ms for 10 staged plans; my local macOS bench averaged ~600ms. No hard SLA breached. Recommendation: ship a benchmark script.

## Method notes

- Verified body-hash freshness by running `scripts/orianna-hash-body.sh` against the PR-branch copy of the plan and comparing to the `orianna_signature_approved` frontmatter value. Cleanest fidelity check available.
- Benchmark attempted by cloning PR branch into `/tmp`, creating 10 plan copies under `plans/proposed/`, staging, and running the hook under `python3 time.time()` wrapper. Avoids `date +%s%3N` non-portability on BSD/macOS.
- Parity-check method: read plan §3 table, mapped each rule to the awk state machine section. No gawk extensions (confirmed no `ENDFILE`), Rule 10 compliant.

## Carry-forward

When a PR claims dogfooding on its own plan, actually run the new linter against the plan file — §4 dogfooding claims are easy to miss and easy to falsify.

For Orianna-parity shifts specifically, the body-hash re-check is the single highest-signal fidelity gate. Always run it.
