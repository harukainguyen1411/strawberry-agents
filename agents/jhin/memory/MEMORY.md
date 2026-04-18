## Role
PR reviewer — surface logic, security, edge cases. Sonnet executor.

## Protocol
- Post review as `gh pr comment` (never `gh pr review --approve` — see shared-account learning 2026-04-18).
- Report structured findings back to requesting teammate (Camille/Evelynn/etc.) via SendMessage.
- Always `git fetch origin` before reading PR branch state.

## Key Knowledge
- **Shared-account GH blocker**: all agents operate under `harukainguyen1411`; `gh pr review --approve` refused. Use advisory-LGTM-via-`gh pr comment`. See learnings/2026-04-18-shared-account-invariant-18-blocker.md.
- **GH Actions billing diagnosis**: all-PRs-red + empty logs + no compute ran → billing, not workflows. Check first.
- `it.fails` is Vitest 4; `it.failing` is Playwright — wrong API silently registers 0 tests.
- Firestore batch cap is 500 writes; guard must count ALL writes: `1 + cases + 2*artifacts > 500` — cases-only guard misses artifact docs + case-backfill updates.
- `gcloud run deploy` needs `--service-account` — default compute SA has wrong IAM.
- Artifact Registry uses `<region>-docker.pkg.dev/<project>/<repo>/<image>` — `gcr.io` is deprecated Container Registry.
- `timingSafeEqual` defeated by `||` short-circuit when lengths differ — byte-length equality required first.
- `cert("")` silently fails on Cloud Run; use ADC.
- `roles/firebaseauth.admin` is over-privileged for token verification (no IAM needed).

## Recurring review patterns
- Path-prefix validation on worker-consumed user fields (path traversal).
- Idempotency guards on Firestore trigger handlers (at-least-once delivery).
- HMAC verification uses raw body bytes, not re-serialized `req.body`.
- Router routes missing `requiresAuth` meta bypass global guard.
- `setInterval` in Vue composables needs unmount cleanup.
- Pipe subshell (`echo|while`) makes background jobs children of subshell; top-level `wait` is no-op.

## Stale-view protocol (established 2026-04-18)
5 phantom findings in one session from reading local working tree. Fix: always `git fetch origin` + `git show origin/<branch>:path`. Never read local paths or carry file content between review rounds. If a teammate disputes a finding, re-fetch and re-verify before posting.

## Sessions
- 2026-04-18 (S1): dependabot-cleanup team under Camille. Advisory-LGTM on #156/#157. Shared-account invariant-#18 blocker + GH Actions billing diagnosis surfaced.
- 2026-04-18 (S2): test-dashboard Phase 1 workstream (R18–R40). LGTMs: #146–#148, #152–#154, #161, #165, #169–#170, #175, #177, #180, #182. Rule-18 violation caught on #159 (zero-review admin merge, bad AR host landed on main — escalated to Evelynn). Stale-view protocol established. Partial-write hazard + batch cap formula patterns added to knowledge base.
