# PR #52 — Root `.firebaserc` is orthogonal to the deployment-pipeline ADR

## Context
PR #52 on `harukainguyen1411/strawberry-app` added a root `.firebaserc` with `default: myapps-b31ea` to fix permanently-red `Firebase Hosting PR Preview` and `Deploy Preview` checks. Question for review: does this conflict with the ADR decision in `plans/in-progress/2026-04-17-deployment-pipeline.md` that `apps/myapps/firebase.json` is the single canonical Firebase surface config?

## Finding
No conflict. A `.firebaserc` at any location declares only a *project alias* — it does not declare any surface (hosting/functions/firestore/storage) and does not override `firebase.json`. The ADR's §1a load-bearing decision concerns surface config and the `apps/myapps/` CWD for CLI invocation (line 153). The preview workflows use `FirebaseExtended/action-hosting-deploy` from the repo root, which is a separate invocation path the ADR explicitly carves out as orthogonal (Scope line 35 — Hosting/preview continues via `preview.yml`/`release.yml`).

Both `.firebaserc` files (root and `apps/myapps/`) resolve `default` → `myapps-b31ea`, so no ambiguity. Different invocation CWDs → different files read → same answer.

## Pattern to remember
When a PR touches Firebase config files, first categorize: is it **surface config** (`firebase.json`) or **alias/project selection** (`.firebaserc`)? Only the former is constrained by the ADR's single-canonical-surface rule. The latter can legitimately live at multiple levels if different tools (action vs local CLI) run from different CWDs.

## Review outcome
Approved as `duongntd99`. `reviewDecision` stayed `REVIEW_REQUIRED` — branch protection likely expects a different approver identity; consistent with prior PRs.
