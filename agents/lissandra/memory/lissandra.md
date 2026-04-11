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

## Review History (last 10)
- PR #71: B6 install-bee-worker.ps1. 1 MEDIUM, 4 LOW. Approved.
- PR #72: B2 Firestore + Storage Admin SDK. 1 MEDIUM, 3 LOW. Approved.
- PR #73: B4 claude.ts invocation wrapper. 2 MEDIUM, 3 LOW. Approved.
- PR #74: B8+B9 Vue frontend /bee. 1 HIGH, 2 MEDIUM, 4 LOW. Approved with HIGH blocker noted.
- PR #75: B5 orchestration loop. 2 MEDIUM (mkdir-after-claim gap; listener silent failure), 3 LOW. Approved.
- PR #89: windows push autodeploy. 3 MEDIUM all fixed. 2 LOW remain (unused imports in index.ts; no exit-code check in install script build step). Approved.

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

## Protocol
- On every PR review pass: run `coderabbit:code-review` and `simplify` skills first, then do the manual logic/security pass. Incorporate all findings into a single consolidated `gh pr comment`. This is standard protocol — do not skip.
- After posting a PR review, always message Evelynn with the PR number and verdict.

## Known Blockers
- Cannot request-changes or approve own repo PRs via gh CLI — post as comment instead.

## Feedback
- If Evelynn over-specifies a delegation, trust own skills and docs first.
