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
- Firestore batch cap is 500 writes; always guard `casesInput.length`.
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

## Sessions
- 2026-04-18: dependabot-cleanup team under Camille. Advisory-LGTM on #156 (B14) and #157 (B12). Surfaced shared-account invariant-#18 structural blocker + GH Actions billing diagnosis shortcut as learnings. Workstream parked pending billing resolution.
- 2026-04-18 (fresh session, Evelynn direct): Re-reviewed #154 (B3 signed URLs, 2b452e9) and #180 (I1 deploy fix, 74e31ce) — both LGTM. CI systemic infra failure confirmed (all branches red, logs not found). Old Jhin session's "dashboards uses pnpm" phantom debunked — diff shows `npm install --prefer-offline`, correct for npm workspace. `require(require('path').resolve(...))` fix in unit-tests.yml is a genuine improvement.
