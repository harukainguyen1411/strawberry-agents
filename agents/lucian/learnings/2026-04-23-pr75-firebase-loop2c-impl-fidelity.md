# PR #75 — Firebase Loop 2c route migration fidelity

**Date:** 2026-04-23
**Repo:** `missmp/company-os`
**Branch:** `feat/firebase-auth-2c-impl` → `feat/demo-studio-v3`
**Verdict:** advisory comment (structurally aligned)
**Comment URL:** https://github.com/missmp/company-os/pull/75#issuecomment-4301276588

## Plan/ADR
- Parent ADR: `plans/in-progress/work/2026-04-22-firebase-auth-for-demo-studio.md` (Orianna `f4cbd61c…`)
- Loop plan: `plans/approved/work/2026-04-22-firebase-auth-loop2c-route-migration.md` (Orianna `16e8dd93…`)

## What passed cleanly
- All §2.4 dep swaps present: `require_user` on `/session/new`, `require_session_owner` on 7 session-scoped routes, `require_session_or_owner` on `/chat`, `/logs`, `/stream` with internal-secret bypass preserved.
- `/preview` correctly left public (404 stub; BD.B.8 deletion target).
- `/build`, `/reauth`, `/complete` correctly retain `verify_internal_secret` inline (S2S callbacks; no user identity path) — matches parent ADR §3.4 and T.PREC.1 audit outcome.
- Claim-on-first-touch at `/auth/session/{sid}` matches Q1 Option A (Duong-decided 2026-04-22) — Firebase cookie present → claim or 403; no cookie → legacy mint fallback.
- `set_session_owner` uses Firestore transactional pattern (TOCTOU-safe), mirroring `transition_session_status` per plan §2.2.
- Additive-only: no legacy helpers deleted (correctly deferred to Loop 2d).

## Drift flagged
1. **Plan table not amended.** T.PREC.1 DoD required in-place edit of §2.4 table. PR body documents audit outcome (good) but the plan file on main still lists `/reauth`, `/complete` with `require_session_owner` proposed. Follow-up chore commit needed.
2. **Cross-PR xfail split.** T.T.1–T.T.7 xfails live in companion PR #70 (branch `feat/firebase-auth-2c-xfails`), not on impl branch. Both target same base `feat/demo-studio-v3`. Rule 12 strict reading is branch-level; flagged that merge order matters (PR #70 must land ≤ PR #75 to preserve base-branch TDD trace).

## Pattern — cross-PR xfail-first
Swain's strategy of shipping xfails and impl as separate PRs into a shared integration branch is clean for review fan-out but introduces ordering risk. Rule 12 doesn't yet have explicit language on cross-PR variants; worth surfacing in a future Evelynn/Sona sync. For now: flag as drift, require merge-order enforcement in PR body.

## Pattern — `T.PREC.1`-style audit tasks
Plans that hand-wave route current state with `(check)` markers and defer to an audit precondition task need the audit to actually *modify the plan* (not just the PR body). Otherwise downstream loops read stale decisions. Recommend future plans include explicit "amend plan file" step in the audit task DoD — which this plan did, but the PR skipped.

## Auth workflow note
`reviewer-auth.sh` broken for `missmp/company-os` (per delegation prompt). Fell back to advisory `gh pr comment` under Duongntd identity. No approval power — Senna handles merge gating separately.
