---
title: Persist Firebase auth env vars in demo-studio-v3 deploy.sh
slug: 2026-04-27-deploy-sh-firebase-env-persist
date: 2026-04-27
concern: work
tier: quick
complexity: quick
status: approved
owner: karma
orianna_gate_version: 2
tests_required: false
qa_plan: none
qa_plan_none_justification: "infra-only diff (deploy.sh + .env.example); no UI/user-flow surface; verification is bash -n syntax check + manual /auth/config probe post-deploy"
priority: P1
last_reviewed: 2026-04-27
---

## Context

Ekko hot-fixed prod auth on `demo-studio-00031-kc9` by appending four Firebase env vars to the live Cloud Run revision via `gcloud run services update`. Those vars are NOT in `tools/demo-studio-v3/deploy.sh`, which uses `--set-env-vars` (full replacement). The next `deploy.sh` run will wipe the hotfix and reproduce the "Auth not configured" failure.

This plan bakes the four vars into `deploy.sh` (line 37, the single `--set-env-vars=...` line) so subsequent deploys preserve them, and documents them in `.env.example` for local-dev parity. All four values are committable: three are plain config; `FIREBASE_WEB_API_KEY` is a public browser-side Web API key by Firebase design (security comes from auth-domain allowlist + security rules, not key secrecy — confirmed by Firebase docs).

This is quick-lane: trivial, infra-only diff, no business-logic change, no tests. The verification is a `bash -n` syntax check plus a future `deploy.sh` run reproducing a populated `/auth/config` response.

## Repo & branch

- Workspace: `~/Documents/Work/mmp/workspace/company-os/`
- Base branch: `feat/demo-studio-v3` (the PR #119 / PR #32 stacked branch)
- Working branch: `fix/pr32-deploy-sh-firebase-env` (created via `scripts/safe-checkout.sh`)
- PR target: `feat/demo-studio-v3` (NOT `main`) — mirrors PR #119's pattern

## Tasks

### T1 — Branch + edit deploy.sh
- kind: ops
- estimate_minutes: 5
- files: `tools/demo-studio-v3/deploy.sh`
- detail: From `~/Documents/Work/mmp/workspace/company-os/`, run `scripts/safe-checkout.sh fix/pr32-deploy-sh-firebase-env feat/demo-studio-v3` to create the worktree off the right base. Then in `tools/demo-studio-v3/deploy.sh`, find the single `--set-env-vars="..."` line (currently line 37) for the `demo-studio` Cloud Run service. Append these four `KEY=VALUE` pairs to the comma-separated list (do NOT add a new flag — keep it one `--set-env-vars` argument so semantics stay "full replacement, but now complete"):
  - `FIREBASE_PROJECT_ID=mmpt-233505`
  - `FIREBASE_WEB_API_KEY=AIzaSyAgkWImbKAPcrDusooFZJBUOqc7A2tV0wo`
  - `FIREBASE_AUTH_DOMAIN=mmpt-233505.firebaseapp.com`
  - `ALLOWED_EMAIL_DOMAIN=missmp.eu`
- DoD: `bash -n tools/demo-studio-v3/deploy.sh` exits 0; `grep -c FIREBASE_WEB_API_KEY tools/demo-studio-v3/deploy.sh` returns 1; the existing keys (FIRESTORE_PROJECT_ID, FACTORY_URL, etc.) are unchanged.

### T2 — Document the four vars in .env.example
- kind: ops
- estimate_minutes: 3
- files: `tools/demo-studio-v3/.env.example`
- detail: Append a `# Firebase auth (browser-side; non-secret by design)` section with the four var names only — no values. One short comment per var:
  - `FIREBASE_PROJECT_ID` — GCP/Firebase project id
  - `FIREBASE_WEB_API_KEY` — public Firebase Web API key (browser-exposed; not a secret)
  - `FIREBASE_AUTH_DOMAIN` — Firebase-hosted auth domain
  - `ALLOWED_EMAIL_DOMAIN` — sign-in email-domain allowlist
- DoD: file ends with the new section; existing lines untouched; no values committed.

### T3 — Commit + push + open PR
- kind: ops
- estimate_minutes: 5
- files: (n/a — git ops)
- detail: Stage both files. Single commit using `ops:` prefix per Strawberry Rule 5 (the diff is infra/ops-only — `deploy.sh` is the deploy script; the cohesive `.env.example` doc-touch rides under the same commit). Suggested message: `ops: persist firebase auth env vars in demo-studio-v3 deploy.sh`. Push the branch. Open a PR with `gh pr create --base feat/demo-studio-v3 --head fix/pr32-deploy-sh-firebase-env`. PR body should reference Ekko's hot-fix (revision `demo-studio-00031-kc9`) and explain the persistence rationale.
- DoD: PR opened against `feat/demo-studio-v3` (NOT main); commit message starts with `ops:`; pre-commit and pre-push hooks pass clean; no `--no-verify`; PR URL captured for handoff.

### T4 — Senna + Lucian review
- kind: review
- estimate_minutes: 10
- files: (PR review)
- detail: Request Senna review (correctness/diff-discipline) and Lucian review (ops/Cloud Run env-var semantics). Either may approve; both must be green before merge. No `--admin` merge (Strawberry Rule 18). Author cannot self-approve.
- DoD: at least one non-author approving review on the PR; all required CI checks green; PR mergeable into `feat/demo-studio-v3`.

## Verification

- `bash -n tools/demo-studio-v3/deploy.sh` — syntax check (must pass; runs in T1).
- Post-merge into `feat/demo-studio-v3`, after the next end-to-end deploy of demo-studio: hit `/auth/config` on the new revision; response should include the four Firebase fields populated. (Manual; Duong validates sign-in.)

## Out of scope

- No QA/Akali dispatch (no UI surface change in this PR).
- No Secret Manager migration — values are non-secret by Firebase design.
- No god-PR #32 changes; this lands in `feat/demo-studio-v3` and rides PR #32 from there.

## References

- Ekko hot-fix task: foreground `a156a2d06f9dab1a0` (revision `demo-studio-00031-kc9`).
- Firebase Web API key public-by-design: https://firebase.google.com/docs/projects/api-keys
- Strawberry Rules: 5 (commit prefix), 11 (no rebase), 18 (no admin merge).
- Stacked-PR pattern: PR #119 (base `feat/demo-studio-v3`).

## Orianna approval

- **Date:** 2026-04-27
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Structural gates green (qa_plan frontmatter + body checks pass; plan-structure-lint passes). Owner is karma; tasks T1–T4 are concrete with explicit files, DoDs, and estimates. The `qa_plan: none` justification correctly identifies the diff as infra-only with no UI/user-flow surface, satisfying Rule 16 carve-out. Quick-lane scope is appropriate for a four-line env-var persistence fix preventing hot-fix regression on next deploy.
