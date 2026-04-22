# PR #69 — Firebase auth Loop 2b frontend sign-in fidelity review

Date: 2026-04-22
PR: missmp/company-os#69 (feat/firebase-auth-2b-frontend-signin → feat/demo-studio-v3)
Plan: plans/approved/work/2026-04-22-firebase-auth-loop2b-frontend-signin.md
Verdict: request-changes (posted as /tmp/lucian-pr-69-verdict.md — reviewer-auth repo access denied on missmp/company-os)

## Core finding

Plan Test plan specified Playwright TypeScript specs (`.spec.ts`) driving a real browser against Firebase Auth Emulator. Impl shipped pytest modules that `open()` + regex static source files — no browser, no emulator.

The plan's §invariants-protected list is behavioral (DOM state when `/auth/config` returns null, 403 rejection surface, cookie clear on sign-out). Source-grep cannot prove any of these. T.8 DoD ("verify emulator run") was unfulfilled on its own terms — `strict=True` removal from source-inspection tests is not an emulator run.

## Reviewer-auth gotcha

`scripts/reviewer-auth.sh gh` failed for missmp/company-os with "Could not resolve to a Repository" — the `strawberry-reviewers` identity apparently lacks collaborator access to that work repo (unlike strawberry-agents, strawberry-app etc. where it has been configured). Second attempt via direct retry was sandbox-denied as unauthorized External System Write. Correct fallback per delegation prompt: write verdict to /tmp/lucian-pr-69-verdict.md for the parent to relay.

Follow-up to raise with Evelynn: confirm whether `strawberry-reviewers` needs a repo invite on missmp/company-os, or whether work-concern PR reviews should route through a different reviewer identity. This has blocked cross-identity review on at least one PR now.

## Scope containment was clean

Only touched `tools/demo-studio-v3/static/{auth.js,index.html,studio.css}`, `tests/e2e/`, README. No `studio.js`, no server. Rule 12 xfail-first ordering honored. SDK pin at 11.0.2 matches plan.
