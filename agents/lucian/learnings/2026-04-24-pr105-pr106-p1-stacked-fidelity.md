# PR #105 + PR #106 (missmp/company-os) — P1 factory Phase B stacked fidelity review

**Date:** 2026-04-24
**Plan:** `plans/in-progress/work/2026-04-22-p1-factory-build-ipad-link.md`
**Verdicts:** APPROVE both (advisory — reviewer-auth gap on missmp/*)

## What landed

- **PR #105** (`feat/p1-s3-stream` → `feat/demo-studio-v3`): Phase B S3 pipeline — T.P1.0 scaffolds, T.P1.2 config_mgmt_client, T.P1.3a/3b factory_build.py + WS-apply steps, T.P1.4 s2_config_to_factory_content translator, T.P1.5a _run_build_job flag-gated rewrite, T.P1.5b wall-clock ceiling, T.P1.6 build_complete payload extension. 4 commits; xfail scaffold precedes impl (Rule 12 OK).
- **PR #106** (`test/p1-t7-fault-injection` → `feat/demo-studio-v3`): superset branch — all 4 PR #105 commits + 1 fixture commit adding `tools/demo-factory/tests/fixtures/ws_client_fault.py` exporting `make_faulty_ws_client`, `PIPELINE_STEP_FIRST_CALL`, `patch_timeout_ceiling`. Flips the last reason-taxonomy xfail green.

## Contract verification (§D2 / §D6)

- Real-path `build_complete` payload: `{buildId, projectId, shortcode, projectUrl, demoUrl, passUrls, configVersion}` — exact match.
- Mock-path `build_complete`: identical key set, empty/None values — T.P1.6 DoD satisfied.
- `build_failed` reason enum: all five emitted (`config_fetch_failed`, `config_invalid`, `ws_api_failed`, `timeout`, `unexpected`).

## Drift flagged

1. PR #105 title narrower than diff (labels only T.P1.5b but covers all of Phase B except T.P1.7).
2. PR #105 body mislabels "trigger_factory wiring (T.P1.4)" — T.P1.4 is the translator; actual S1 trigger wiring (T.P1.8/T.P1.9) is NOT in the diff. Phase C remains deferred. Cosmetic but masks scope.
3. PR #105 final commit relaxes `strict=True` → `strict=False` on the lone ws_api_failed xfail so the stacked gap between #105 merging and #106 merging doesn't trip xpass. Functionally correct; cleaner would have been a single combined PR or skip-until-fixture. Follow-up: restore strict after #106 lands.

## Rule 12 insight (reinforced)

Rule 12 is a **per-branch** invariant enforced by pre-push hook, not a per-PR merge-order invariant. Stacked PRs where branch B is a strict superset of branch A (B includes all A's commits plus new ones) can merge in order A→B without violating Rule 12, provided each branch's own xfail-before-impl ordering is intact. This pattern is preferable to reversing the order when B's stated scope is "tail-only delta of A" — reversing would force B to re-claim A's full impl diff.

## Reviewer-auth gap

`strawberry-reviewers` still has no access to `missmp/company-os` (404 on `/repos/missmp/company-os`). Advisory verdicts posted as chat output only. Known gap; same as PR #57, #59, #77, #78, #103, #104 on this repo.
