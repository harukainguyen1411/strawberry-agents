# PR #66 — demo-dashboard W2 route migration fidelity

**Date:** 2026-04-22
**PR:** missmp/company-os#66
**Plan:** `plans/in-progress/work/2026-04-22-demo-dashboard-service-split.md` §Wave 2
**Verdict:** APPROVE (verdict-file fallback — reviewer-auth gap)

## Shape of a clean W2 wave

This PR is textbook fidelity pattern for the dashboard-split plan. Useful template:

- **Diff scope = single new folder.** Only 9 files, all under `tools/demo-dashboard/`. No S1 touches. Cross-wave bleed (W3 S1 deletions, W5 deploy wiring, W4 auth wiring) all absent.
- **Commit chain = xfail → impl → impl → flip.** Vi's 504dcfe (strict=True xfails) precedes Viktor's impl commits; the final aaa830f is purely marker removal (additions<<deletions per file). Rule 12 satisfied structurally without needing to run anything.
- **OQ honoring = explicit in code comments.** `test_results_store.py` docstring cites OQ4 and T.W3.3 by name. Dashboard docstring cites Vi constraints 1/2/3. Makes fidelity review trivial — the code self-documents its plan provenance.

## Dead-code-by-design caveat

`test_results_store.py` was added but `main.py` route handlers inline the Firestore reads against `main.db` instead of importing from the store module. Rationale is Vi constraint 1 (tests patch `main.db` directly). This leaves `write_test_result` unused until T.W3.3 rewires S1's writer. Logged as drift note, not blocker — the code is correct, just a tad awkward.

Pattern: when a test-patching constraint dictates module-level globals, a helper module's functions may end up "reserved for later wave." That's fine; just flag it so a later reviewer doesn't try to delete dead code.

## Reviewer-auth gap continues

`scripts/reviewer-auth.sh gh api repos/missmp/company-os` still 404s (bot not a collaborator). Precedent chain: PR #57 → #59 → #61 → #66. Verdict-file fallback (`/tmp/lucian-pr-N-verdict.md`) is the established path. Sona has been flagged; no action from Lucian.

## Fidelity shortcuts reinforced

- Plan-file-not-in-diff → signature hash check skipped (PR #19 precedent holds).
- `gh pr diff N --name-only` is still the fastest scope-creep detector. 10 seconds of output ruled out W3/W4/W5 leak this session.
- Commit message prefixes match diff scope (`feat(demo-dashboard):` for code under `tools/demo-dashboard/` — Rule 5 satisfied).
