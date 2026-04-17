# Lissandra

## Role
- PR Reviewer (surface: logic, security, edge cases)

## Sessions (recent)
- s18: PR #95 (darkstrawberry platform monorepo phase 1). 2 MEDIUM, 4 LOW. Comment-only R1. Round 2: M1+M2 fixed. Approved.
- s19: PR #96 (darkstrawberry phase 2+3). 1 MEDIUM, 4 LOW. Comment-only. Merged.
- s20: PR #97 (bee GitHub rearchitect). 2 MEDIUM, 3 LOW. Comment-only. Merged. M2: docxUrl prefix not validated.
- s21: PR #100 (deployment architecture). 2 MEDIUM, 3 LOW. Comment-only. Merged.
- s22: PR #102 (deploy lockdown). 1 MEDIUM, 3 LOW. Fix-then-ship. M1: runbook omits bee-worker SA.
- s23: PR #105 (bee Gemini intake). 2 MEDIUM, 4 LOW. Changes requested. M1: fileRef path traversal; M2: beeIntakeSubmit idempotency missing.
- s24: PR #105 re-review (commit a8d8a7d). All 6 findings verified fixed. Approved.

## Review History (last 5)
- PR #100: deployment architecture. 2 MEDIUM (SA file perms; PR_BODY injection), 3 LOW. Comment-only. Merged.
- PR #102: deploy lockdown. 1 MEDIUM (runbook omits GCE bee-worker SA), 3 LOW. Fix-then-ship.
- PR #105 R1: bee Gemini intake. 2 MEDIUM (fileRef path traversal; no idempotency guard), 4 LOW. Changes requested.
- PR #105 R2: all 6 findings fixed (commit a8d8a7d). Approved.

## Recurring patterns
- `--dangerously-skip-permissions` / unrestricted tool access keeps appearing. Flag proactively.
- Glob-count-based ID generation is a recurring anti-pattern.
- Silent `except Exception: pass` / bare `catch {}` blocks common.
- Firebase Admin SDK bypasses Firestore security rules — check client-side rules cover new fields.
- HMAC signature verification: use raw body bytes, not re-serialized req.body.
- Router routes missing `requiresAuth` meta — global guard bypassed.
- Worker reading user-controlled fields: always validate path/URL fields against an expected prefix before file I/O or storage. (Flagged in #97 and #105.)
- Firestore Cloud Functions: always add idempotency guard — at-least-once delivery means retries re-execute. (Flagged in #96 and #105.)
- Callable Cloud Functions receiving client-supplied storage paths: validate prefix before `bucket.file()` — path traversal risk.
- `beeIntakeSubmit`-style submit handlers: check if already submitted (issueNumber present) before re-filing.
- setInterval polling in Vue composables: enforce cleanup on unmount — leaked timers continue firing.
- GitHub Actions: SA JSON written via echo to /tmp should be chmod 600.
- CI path filters using `contains(toJson(head_commit.modified))` unreliable on squash merges.
- When a "delete local SA" PR is reviewed: check secondary SA consumers.
- Two consecutive user-role turns in Gemini history: may cause API errors; watch for token-budget injection patterns.

## Protocol
- Post review as `gh pr comment` (never `gh pr review` — cannot approve/request-changes own repo).
- After posting, return structured summary to Evelynn.

## Known Blockers
- Cannot request-changes or approve own repo PRs via gh CLI — post as comment instead.
