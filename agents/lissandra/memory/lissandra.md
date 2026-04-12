# Lissandra

## Role
- PR Reviewer (surface: logic, security, edge cases)

## Sessions (recent)
- s8: PR #29 (GH_TOKEN scoping) approved. PR #30 (API key isolation) 1 blocker fixed, approved.
- s9: PR #31 (team-plan-migration) approved first-pass.
- s10: PR #32 (heartbeat fix) 1 blocker awaiting fix. PR #34 (restart safeguards) approved. PR #54 myapps (kanban board) 1 blocker awaiting fix.
- s11: PR #61 (CLAUDE.md 4-tier restructure) — 2 blockers found, changes requested.
- s12: PR #61 re-review — 2 blockers fixed, 3 findings still open.
- s13: PR #62 re-review — all 6 findings fixed. Approved via comment.
- s14: PRs #66, #67, #68, #69, #70 (feedback loop + bee-worker). All approved via comment.
- s15: PRs #71, #72, #73, #74 (bee-worker B2/B4/B6/B8+B9). All approved via comment. #74 has 1 HIGH blocker (missing requiresAuth meta).
- s16: PR #75 (B5 worker.ts orchestration loop). 2 MEDIUM, 3 LOW. Approved with M1 pre-production blocker noted.
- s17: PR #89 (windows push autodeploy). 3 MEDIUM, 3 LOW. Changes requested. Round 3: all 3 MEDIUMs fixed + npm ci added. 2 LOWs remain (unused imports; no exit-code check in install script). Approved.
- s18: PR #95 (darkstrawberry platform monorepo phase 1). 2 MEDIUM, 4 LOW. Comment-only R1. Round 2: M1+M2 fixed. Approved.
- s19: PR #96 (darkstrawberry phase 2+3). 1 MEDIUM, 4 LOW. Comment-only. Merged to main (caveats accepted). Known follow-ups: fork slug collision (M1), Cloud Function idempotency (L1), admin role check (L4).
- s20: PR #97 (bee GitHub rearchitect). 2 MEDIUM, 3 LOW. Comment-only. Merged. M2: docxUrl from issue body passed to GCS downloader without prefix validation.
- s21: PR #100 (deployment architecture — Turborepo + Changesets + CI). 2 MEDIUM, 3 LOW. Comment-only. Merged. M1: SA JSON written to /tmp without chmod. M2: PR_BODY env var to Discord script.

## Review History (last 10)
- PR #95: darkstrawberry platform monorepo phase 1. 2 MEDIUM (migration cert() guard; loadRegistry idempotency), 4 LOW. Approved R2.
- PR #96: darkstrawberry phase 2+3 (registry, access control, collab, forking, notifications). 1 MEDIUM (fork slug collision), 4 LOW. Comment-only. Merged.
- PR #97: bee GitHub rearchitect (Firestore→GitHub issues). 2 MEDIUM (label swap race; docxUrl prefix not validated), 3 LOW. Comment-only. Merged.
- PR #100: deployment architecture (Turborepo, Changesets, 3 CI workflows, composite deploy). 2 MEDIUM (SA file perms; PR_BODY injection surface), 3 LOW. Comment-only. Merged.

## Recurring patterns
- `--dangerously-skip-permissions` / unrestricted tool access keeps appearing. Flag proactively.
- Glob-count-based ID generation is a recurring anti-pattern. Always flag.
- Silent `except Exception: pass` / bare `catch {}` blocks common.
- Firebase Admin SDK bypasses Firestore security rules — check client-side rules cover new fields.
- HMAC signature verification should use raw body bytes, not re-serialized req.body.
- Placeholder strings (SISTER_UID_PLACEHOLDER) in deployed scripts — deployment blocker.
- Router routes missing `requiresAuth` meta — global guard bypassed.
- `claim` before resource setup (mkdir, etc.) — if setup throws, job stuck in `running`.
- Large JSON passed as CLI argv — watch for ARG_MAX limits.
- Lock files written by service — check stale-lock cleanup on process crash.
- `detached: true` + `child.unref()` requires `stdio: "ignore"` to actually detach; piped stdio keeps event loop alive.
- NSSM `ObjectName` set to interactive user requires password — stalls unattended installs.
- Migration scripts using firebase-admin `cert()`: validate GOOGLE_APPLICATION_CREDENTIALS is a readable file path before any Firestore I/O — crash after partial writes leaves data in inconsistent state.
- Module-level mutable arrays used as registries (e.g. appRegistry): always add idempotency guard — duplicate push on double-call is a silent bug.
- Firestore Cloud Functions: always check `dispatched === true` at top of handler for idempotency — at-least-once delivery means retries will re-send notifications.
- Fork/clone flows using deterministic IDs + `setDoc`: second call silently overwrites first. Use `addDoc` or timestamp suffix to prevent collision.
- `authStore.user?.role` check: Firebase Auth user object has no `role` field — role lives in Firestore `/users/{uid}`. Always verify authStore enriches user with Firestore role before relying on it in computed properties.
- Worker reading user-controlled fields from external source (GitHub issue body, Firestore doc): always validate path/URL fields against an expected prefix before passing to file I/O or storage operations.
- setInterval polling in Vue composables: document or enforce caller obligation to call cleanup/stop on unmount — leaked timers continue firing after navigation.
- GitHub Actions: SA JSON written via `echo '...' > /tmp/sa.json` should be followed by `chmod 600` — debug logging can expose the file otherwise.
- CI path filters using `contains(toJson(head_commit.modified))` are unreliable on squash merges — only the merge commit diff is visible, not all commits in the PR. Use `dorny/paths-filter` for reliable path-based job gating.
- workflow_dispatch with a `ref` input deploying to production: validate the ref format or restrict to deploy tags — any git ref can be deployed.

## Protocol
- On every PR review pass: run `coderabbit:code-review` and `simplify` skills first, then do the manual logic/security pass. Incorporate all findings into a single consolidated `gh pr comment`. This is standard protocol — do not skip.
- After posting a PR review, always message Evelynn with the PR number and verdict.

## Known Blockers
- Cannot request-changes or approve own repo PRs via gh CLI — post as comment instead.

## Feedback
- If Evelynn over-specifies a delegation, trust own skills and docs first.
