# Orianna lifecycle smoke — 7→11 debug session

Date: 2026-04-20
Plan: plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §T11.1

## Summary

Debugged 4 failing cases in `scripts/test-orianna-lifecycle-smoke.sh` (T11.1). All 4 were fixed. Final result: 11/11 PASS.

## Root causes and fixes

### PROMOTE_TO_INPROGRESS (plan-promote.sh source-dir restriction)

`plan-promote.sh` line 108-113 had a hard check that only `plans/proposed/*.md` was
accepted as the source. Gate-v2 requires `approved→in-progress` and `in-progress→implemented`
transitions too. The TARGET_DIR computation (`dirname/dirname + target`) was already correct
for any source directory; only the validation case-statement needed expanding to also accept
`plans/approved/*.md` and `plans/in-progress/*.md`.

Fix: commit 3ddac26.

### IMPLEMENTED_SIGN + POSTHOC_ALL_SIGS_VALID (body-stability violation)

orianna-sign.sh does carry-forward hash checks: when signing for `implemented`, it verifies
that approved and in_progress signatures are still valid against the CURRENT body hash.
The smoke harness was appending a new `## Test results` section to the plan body AFTER
in_progress signing (changing the body hash), which invalidated the carry-forward checks.

The design requires the plan body to be stable (identical hash) across all signings. Any body
edit between signings must be followed by re-signing the affected phase before the next phase
can be signed. The harness violated this by treating the test results section as a post-signing
addition.

Fix: put the CI test results link in the initial plan content (before any signing) so the body
hash is stable from first sign to last. Architecture evidence only modifies `architecture/key-scripts.md`
(not the plan body) — that's safe. Commit 9541b0c.

### Pre-existing uncommitted fixes (_lib_gdoc.sh, orianna-verify-signature.sh)

Two additional files had uncommitted on-disk changes from a prior session:
- `_lib_gdoc.sh`: was missing REPO env var honor, needed for test harness operating on temp repos
- `orianna-verify-signature.sh`: rename-skip logic for the signing-commit walker; tracks SIGNING_COMMIT_PLAN_PATH so post-promote (git mv) verify works correctly

Committed as 79e2298.

## Invariants learned

1. **Body hash is frozen at signing time.** Any edit to the plan body after a signing invalidates
   that phase's carry-forward. The only safe edits between phases are frontmatter additions
   (new signature fields) and changes to other files.

2. **Test results section must be final before in_progress signing.** The implemented gate needs
   a CI link; it must be in the body before the first signing (or at minimum before in_progress
   signing) so it doesn't change the hash later.

3. **plan-promote.sh must handle all forward lifecycle transitions.** The original proposed-only
   restriction was from the v1 single-stage design. Gate-v2 extends promote to all stages.

4. **REPO env var must be honored in _lib_gdoc.sh.** plan-promote.sh sources _lib_gdoc.sh;
   if _lib_gdoc.sh doesn't respect REPO, all git/file ops target the wrong tree in test mode.
