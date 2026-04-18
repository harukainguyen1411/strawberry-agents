## Sessions
- 2026-04-18 R1: PR #144 (evelynn memory sharding). 2 CRITICAL (noclobber lock race + git add -A secret surface), 2 IMPORTANT (archive prune uses post-move mtime; last-sessions/ never pruned), 2 suggestions. Comment posted.
- 2026-04-18 R2: PR #144 re-review (commit 8696583). All 5 findings fixed. One residual structural note (partial state on bounded-loop exit) flagged as suggestion, not blocker. Cleared for merge.
- 2026-04-18 R3: PR #147 (A1 dashboards skeleton). LGTM — no blockers. it.todo correct pre-C1.
- 2026-04-18 R4: PR #148 (I2 Cloud Run SA IAM). IMPORTANT: roles/firebaseauth.admin over-privileged for token verification (no IAM needed). Suggestion: quote bucket loop array. Storage bucket-scoped grant pattern correct.
- 2026-04-18 R5: PR #146 (J1 regression lane). LGTM — xfail-flip discipline correct; PR template Testing section clean and reusable.
- 2026-04-18 R6: PR #150 (B1 Firestore schema). Changes requested. CRITICAL: approved plan deleted instead of archived (rule 4). IMPORTANT: cert("") silent failure — use ADC on Cloud Run; started_at as string breaks Timestamp ordering. SUGGESTIONS: redundant single-field indexes; named app init.
- 2026-04-18 R7: PR #151 (C1 Vitest setup). Changes requested. CRITICAL: same rule-4 violation from #150 carryover (commit 66fec7c still present). IMPORTANT: env-guard test is self-defeating (mocks own fetch, not real network); @vitest/runner explicit dep creates version-skew risk. SUGGESTION: @vitest/ui unused.
- 2026-04-18 R8: PR #149 (Ekko TDD hooks + CI). LGTM with coordination needed. IMPORTANT: PR template Testing section conflicts with #146 (J1) — both add ## Testing with different formats; needs design merge before either lands. Smoke convention, hook table, bypass policy all correct vs plan.
- 2026-04-18 R9: PR #150 re-review (commits e0a3e91, 7234702). All 5 findings resolved. LGTM. (Jayce sent wrong PR# — said 152, meant 150 fixes.)
- 2026-04-18 R10: PR #152 (G1 routing skeleton). LGTM. /monitoring/* reservation correct. xfail it.todo correct pre-C1. Process note: retarget base from chore/a1 to main after #147 merges.
- 2026-04-18 R11: PR #153 (F1+F2 auth). Changes requested. CRITICAL: timingSafeEqual defeated by || token !== expected short-circuit; xfail commit after implementation (rule 12). IMPORTANT: empty ALLOWED_UIDS silently bypasses allowlist (fails open); firebase-admin version conflict with B1 (^12 vs ^13.8).
- 2026-04-18 R12: PR #151 re-review (d2e1e23, b679a38). CRITICAL resolved (plan violation netted out by main merge). Still open: env-guard self-defeating test (IMPORTANT); @vitest/runner redundant dep (IMPORTANT); @vitest/ui unused (suggestion).
- 2026-04-18 R13: PR #154 (B3 signed URLs). Changes requested. IMPORTANT: xfail test passes "output" as ArtifactKind (invalid — not in union, objectPath returns .undefined ext); Storage() instantiated per-call (should be module singleton). V4 + 15min TTL correct. xfail ordering correct.
- 2026-04-18 R14: PR #147 re-review (A1). LGTM. /monitoring server-level 404 correct defence-in-depth. it.failing correct post-C1. tsconfig __tests__ exclude correct.
- 2026-04-18 R15: PR #153 re-review (F1+F2 auth). LGTM. All criticals+importants resolved. timingSafeEqual-only compare correct; byte-length check present; xfail ordering fixed; allowlist fails closed; firebase-admin ^13.8.0. Residual: unnamed app (suggestion); commit prefix still chore: not feat:.
- 2026-04-18 R16: PR #151 re-review (70c05fe). LGTM. All findings resolved: @vitest/runner removed, @vitest/ui removed, env-guard moved to setupFiles (vi.stubGlobal in beforeAll — actually enforces hermetic invariant now).
- 2026-04-18 R17: PR #154 re-review (B3). LGTM. ArtifactKind fixed to "screenshot"; Storage singleton at module scope. Path format changed to <artifactId>-<kind>.<ext> — acceptable, ADR §3 unspecific on filename format.
- 2026-04-18 R18: PR #154 re-review (R18 — artifactId path, singleton, xfail kind, rule 12). LGTM.
- 2026-04-18 R19: PR #148 re-review (fe54233). LGTM. firebaseauth.admin removed; POSIX bucket iteration fixed (set --; for BUCKET do).
- 2026-04-18 R20: PR #169 (D1 report-run.sh). IMPORTANT: pipe subshell drops artifact uploads (echo|while — wait is no-op); undeclared node dependency. Suggestions: Date.now()+random ID collision; bats skip ≠ it.fails semantics.
- 2026-04-18 R21: PR #159 (I1 dashboards.sh). CRITICAL: AR_REPO="gcr.io" wrong (use <region>-docker.pkg.dev); IMPORTANT: #!/usr/bin/env bash + pipefail violates rule 10; IMPORTANT: --allow-unauthenticated undocumented.
- 2026-04-18 R22: PR #165 (C2 pre-commit hook). IMPORTANT: require('./' + pkg_json) CWD-relative — silently skips TDD packages if git runs from subdirectory. Suggestion: grep fallback fragile for multiline JSON.
- 2026-04-18 R23: PR #161 (C2 verify-only). LGTM. require uses absolute path (correct). Suggestion: staged-file simulation shallow.
- 2026-04-18 R24: PR #169 re-review (5dfaa4cb). LGTM. Pipe subshell fixed (here-doc); node guard added.
- 2026-04-18 R25: PR #146 re-review (J1 post-template-collision). LGTM. afa0eb2 drops Testing section; 2 files clean.
- 2026-04-18 R26: PR #152 re-review (G1 xfail flip). LGTM. 6 passing RTL tests; /monitoring/* correct. Dead renderAt function (suggestion).
- 2026-04-18 R27: PR #170 (xfail cluster item 1). LGTM. health flip + firestore-rules.xfail uses it.fails correctly.
- 2026-04-18 R28: PR #153 re-review (1b6389f). LGTM. Viktor converted it.failing xfails to real passing supertest tests — correct.
- 2026-04-18 R29: PR #177 (D2 POST /api/runs). IMPORTANT: no Firestore batch size guard (500-write cap); IMPORTANT: batch.commit() before signed-URL generation — partial-write hazard if GCS throws. Suggestion: required field validation. API drift check clean.
- 2026-04-18 R30: PR #180 (I1 fix). CRITICAL resolved (gcr.io→AR). IMPORTANT: pipefail still present (rule 10); IMPORTANT: missing --service-account on gcloud run deploy (I2 IAM bindings won't apply).
- 2026-04-18 R31: PR #154 re-review (459c5cb). it.fails fix confirmed on signed-urls.xfail. IMPORTANT: unit-tests.yml added out-of-scope with 2 bugs (CWD-relative require; npm instead of pnpm for dashboards).
- 2026-04-18 R32 (fresh session): PR #154 re-review (2b452e9). LGTM. All B3 checklist items clean: V4 + 15min TTL + singleton storage + artifactId in path + valid ArtifactKind + it.fails + QA-Waiver. CI systemic failure (infra issue, not PR-specific).
- 2026-04-18 R33 (fresh session): PR #180 re-review (74e31ce). LGTM. All I1-fix checklist items clean: #!/bin/sh + set -eu (no pipefail) + --service-account present + gcr.io removed + $REGION-docker.pkg.dev path + --allow-unauthenticated has ADR §7 F2 rationale comment. Minor: PR body understates path (missing strawberry-images segment) — non-blocking. CI systemic failure.

## Key learnings this session
- it.failing is Playwright API; Vitest 4.x uses it.fails — wrong API silently registers 0 tests (saved to learnings/)
- Vitest exclude: ["**/*.xfail.test.ts"] silently swallows xfail files — same silent-defeat pattern
- Firestore batch cap is 500 writes; always guard casesInput.length before batch
- gcloud run deploy needs --service-account to use the right SA — default compute SA has wrong IAM
- gcr.io is Container Registry (deprecated); Artifact Registry uses <region>-docker.pkg.dev/<project>/<repo>/<image>
- pipe subshell (echo|while) makes background jobs children of subshell; top-level wait is no-op

## Migrated from lissandra (2026-04-17)
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
## Migrated from reksai (2026-04-17)
# Rek'Sai

## Role
- PR Reviewer (deep: performance, concurrency, data flow, security internals)

## Key patterns
- Post reviews as `gh pr comment`, NOT `gh pr review`. **Why:** Duong corrected this explicitly.
- Always message Evelynn when task is complete (protocol rule #7). **Why:** Evelynn needs status to relay to Duong.
- Use turn-based conversation tools for multi-agent comms. **Why:** protocol updated 2026-04-04.
- Report findings to Evelynn after every review.

## Sessions
- 2026-04-03: Reviewed PR #11 (contributor pipeline). 8 findings (2 critical, 2 high, 2 medium, 2 low).
- 2026-04-04: Reviewed PR #13 (claimed cleanup). Flagged title/diff mismatch — no actual deletions in diff.
- 2026-04-04: Reviewed PR #16 (Telegram bridge). 5 findings — bot token in plan, flush no-op, pipe-subshell, error log empty, no signal trap. All fixed on second pass.
- 2026-04-04: Reviewed PR #23 (GitHub token injection). 4 findings — shell+AppleScript injection, scrollback leakage, no permission check, undocumented blast radius. All fixed on second pass.

## Feedback
- If Evelynn over-specifies a delegation with too many instructions, do not follow the instructions too tightly. Trust your own skills and docs first — if you can find the relevant skill or documentation, use that as your guide instead.