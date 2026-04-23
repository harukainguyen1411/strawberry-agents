# PR #80/#81/#82 — Loop 2d stacked waves (W1/W2/W5) fidelity — 2026-04-23

## Context
Aphelios decomposed Loop 2d (Slack removal + UI session creation) into 7 waves.
W1/W2/W5 shipped as stacked PRs against `feat/demo-studio-v3`:
- PR #80: W1 (base = feat/demo-studio-v3)
- PR #81: W2 (base = feat/loop2d-w1-drop-slack-write)
- PR #82: W5 (base = feat/loop2d-w2-session-new-direct)

All three authored by `duongntd99`; repo `missmp/company-os` (work — bot has no access).
Posted APPROVE as plain comments via `duongntd99` per MEMORY precedent.

## Key findings

- **Stacked-PR fidelity pattern.** When a plan stacks wave PRs, fidelity review reduces
  to: (a) Rule 12 xfail→impl chain within each branch (local to that PR); (b) base chain
  walks W1.impl → W2.xfail → W2.impl → W5.xfail → W5.impl with parent-SHA continuity;
  (c) each PR's file set stays inside the plan's task-declared Files field.
- **"13 xfails" context.** The delegation prompt flagged 13 xfails added by Xayah in
  a single prep commit (c257942) across all 6 future test files. Rule 12 requires
  xfail-first ON THE SAME BRANCH — the wave PRs correctly re-declare only their
  wave's xfails fresh on their own branches. c257942 is a planning artifact on a
  separate branch; not required to be cherry-picked. Future W3/W4 PRs will re-declare
  the remaining 8 xfails on their branches. Count check: W1=5, W2=2, W5=1 = 8 landed so far.
- **Phasing bridge pattern.** W1 had to touch `main.py::create_new_session` (POST /session)
  even though that route is slated for W3 deletion — the new `create_session` signature
  is stricter (positional slack args removed, owner fields now `str` not `Optional`),
  so the to-be-deleted route needs empty-string stubs (`owner_uid=""`, `owner_email=""`)
  as a 2-wave bridge. Clean drift-note: matches plan §10 phasing; not scope creep.
- **T.W5.6 dead-import sweep is a manual grep.** Static JS is not covered by
  pre-commit hook's unit-test-for-changed-packages path, so the plan explicitly
  added T.W5.6 to scrub `/auth/session`, `goToSession`, `sessionInput`,
  `generate_session_token` references. Reviewer replicates via
  `gh api repos/.../contents/<file>?ref=<branch>` + base64-decode + grep. Cheap.
- **Anonymity enforcement.** Work-scope PRs must omit agent names. Used
  `-- reviewer (plan-fidelity lane)` sign-off consistently. No "Lucian", no
  Anthropic email, no Co-Authored-By trailer.

## Technique refined

**Parent-SHA stacked-PR chain walk:**
```bash
gh api repos/OWNER/REPO/commits/<impl-sha> --jq '{parents: [.parents[].sha[0:10]]}'
```
For a 3-PR stack: verify W2.xfail.parent == W1.impl.sha; W5.xfail.parent == W2.impl.sha.
Rule 12 still passes per-branch because each branch has its own xfail→impl pair.

## Verdicts

- PR #80: APPROVE (W1 — https://github.com/missmp/company-os/pull/80#issuecomment-4302382020)
- PR #81: APPROVE (W2 — https://github.com/missmp/company-os/pull/81#issuecomment-4302383137)
- PR #82: APPROVE (W5 — https://github.com/missmp/company-os/pull/82#issuecomment-4302384757)
