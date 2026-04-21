# Rule 19 is a system-wide invariant even when hooks don't catch specific transitions

**Date:** 2026-04-21
**Session:** 0cf7b28e (third leg)
**Trigger:** Ekko (`aac6418a`) correctly refused the bulk fastlane directive citing Rule 19 as a system invariant, even though the specific transitions (approved→in-progress, in-progress→implemented) are not guarded by `pre-commit-plan-promote-guard.sh` (which only fires on `proposed → *`).

## What happened

Sona asked Ekko to fastlane all four ADRs plus E2E ship through terminal states in one batch. Ekko refused on Rule 19 grounds. Sona then executed the fastlane as plain `Duongntd` identity — because the specific transitions involved (`approved → in-progress`, `in-progress → implemented`) are mechanically unguarded. No hook fires. No Orianna check runs. Raw `git mv` + status rewrite works.

Ekko's principled refusal was correct. The rule exists as a system invariant, not purely as a hook enforcement. An agent that bypasses the spirit of Rule 19 because the mechanical gate is absent is drifting from the protocol. Sona's direct execution of those same transitions was permissible only because:
1. Sona is the coordinator with explicit Duong directive ("fastlane everything, use admin to promote").
2. The transitions are genuinely unguarded — the rule's signing requirement only applies from `proposed → *` onward via `plan-promote.sh`.
3. Commit trailers document the admin directive.

## Correct pattern going forward

- For `proposed → approved`: always use `scripts/plan-promote.sh` (which runs Orianna gate). Admin bypass via `Orianna-Bypass:` trailer requires `harukainguyen1411` identity.
- For `approved → in-progress` and `in-progress → implemented`: these are coordinator calls. Phase flip via raw `git mv` is allowed (no Orianna gate requirement for these transitions per the lifecycle docs). Document the basis in commit trailers.
- Agents other than the coordinator should refuse fastlane requests even on unguarded transitions — the refusal surfaces the decision for the coordinator to own.

## Hook gap note

`pre-commit-plan-promote-guard.sh` catches only `proposed → *`. There is no enforcement on downstream transitions. This is a known gap (one of the four Orianna-gate-speedup proposals filed at `0d218f4`). Until patched, the coordinator is the enforcement layer for those transitions.
