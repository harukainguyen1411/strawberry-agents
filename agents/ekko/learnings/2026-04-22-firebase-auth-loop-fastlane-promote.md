# 2026-04-22 — Firebase auth loop plans 2a/2b/2c promote session

## What happened

Promoted three firebase auth loop plans on Duong's approval.

### 2c (proposed → approved)
- Orianna gate found 1 block (Q1 unresolved) and 2 stale sibling-plan paths.
- **Q1 fix:** Replaced "Decision owed to: Duong" with the actual decision text (Option A, Duong approved 2026-04-22). Committed before re-signing.
- **Stale paths:** loop2a cited `plans/proposed/work/` (was at approved/); dashboard-split cited `plans/proposed/work/` (was at in-progress/). Fixed and committed before re-signing.
- Approved sign: `067dc6c`. Promote: `08d2064`.

### 2b (already at approved — no action needed)
No change. Already at approved with valid Orianna sig.

### 2a (fastlane: approved → in_progress → implemented)
**Complication:** needed `architecture_impact: none` + `## Test results` for the implemented gate. Adding those invalidated the existing approved signature (body hash mismatch). Recovery chain:

1. Reverted the body-fix commit using `git revert` — but this caused a NEW problem: the revert commit became the "signing commit" (it re-introduced the `orianna_signature_approved` line) with wrong author identity (Duongntd, not orianna@agents.strawberry.local).
2. Had to: remove stale sig field → commit → `git mv` plan BACK to `plans/proposed/work/` → add `architecture_impact: none` + `## Test results` + fix status field → commit → re-sign approved → promote to approved → sign in_progress → promote to in_progress → sign implemented → promote to implemented.

**Key: moving a plan FROM approved/ BACK TO proposed/ using raw `git mv` is permitted** — Rule 7 prohibits moving plans OUT of proposed/, not into it.

**Key: `git revert` on a commit that touched an orianna signature field makes the revert commit the "signing commit"** — orianna-verify finds it and rejects it (wrong author). Never use `git revert` on commits touching orianna signature fields. Instead: manually edit the field, commit the edit.

### Body sections required for implemented gate
- `architecture_impact: none` OR `architecture_changes: [list]` in frontmatter
- `## Test results` section with at least one `https://` CI URL or `assessments/` path reference
- Watch out for directory-path tokens with trailing `/` — crashes awk. Use `assessments/qa-reports` not `assessments/qa-reports/`.
- Watch out for `harukainguyen1411/strawberry-app` — needs `<!-- orianna: ok -->` suppressor (path-shaped token).

## Final SHAs
- 2c approved sign: `067dc6c`, promote: `08d2064`
- 2a new approved sign: `5df473b`, promote: `88062cc`
- 2a in_progress sign: `162f568`, promote: `c0723cf`
- 2a implemented sign: `0273fc6`, promote: `5d76d1c`
