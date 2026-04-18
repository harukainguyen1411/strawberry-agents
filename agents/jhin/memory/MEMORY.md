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

- `beforeUserCreated` fires only on account creation, not every sign-in. Use `beforeSignIn` when the requirement is "block all unauthorized sign-ins".
- Cold-start cache pattern: the module-level variable must be written after the Firestore read — null-checking it without populating it is a dead cache.

## Recurring review patterns
- Bats xfail vacuous-pass: `source` fails non-zero when lib absent → `status -ne 0` test passes without exercising the function. Guard with `[ -f "${LIB}" ] || return 1`.
- bats `$stderr` only populated with `run --separate-stderr` (bats-core 1.5+); bare `$stderr` assertions are no-ops.
- Constant-equality assertions fail the "not a tautology" TDD criterion — need to test function behaviour, not string values.
- `package.json` deploy scripts bypass static grep gates that only scan `scripts/deploy/**`.
- repo-root detection via `command -v` is fragile when tools are on system PATH; prefer `BASH_SOURCE[0]`-relative.

- Path-prefix validation on worker-consumed user fields (path traversal).
- Idempotency guards on Firestore trigger handlers (at-least-once delivery).
- HMAC verification uses raw body bytes, not re-serialized `req.body`.
- Router routes missing `requiresAuth` meta bypass global guard.
- `setInterval` in Vue composables needs unmount cleanup.
- Pipe subshell (`echo|while`) makes background jobs children of subshell; top-level `wait` is no-op.
- npm lockfile version pin check: cross-check package.json spec (no caret), lockfile workspace spec (no caret), and `node_modules/<pkg>.version` resolved entry. All three must match for the pin to be real.
- age armor does not expose the recipient public key in human-readable form — verifying the recipient requires decryption or out-of-band confirmation from the author.

## Stale-view protocol (established 2026-04-18)
5 phantom findings in one session from reading local working tree. Fix: always `git fetch origin` + `git show origin/<branch>:path`. Never read local paths or carry file content between review rounds. If a teammate disputes a finding, re-fetch and re-verify before posting.

## Sessions
- 2026-04-19 (S8): PR #35 REQUEST_CHANGES: CORS origin check missing on GET /health — any cross-origin page can probe server presence; POST /refresh is correctly guarded. Concurrent-refresh race and orphaned-child-on-SIGTERM noted as suggestions. PR #37 REQUEST_CHANGES: `open` in scripts/usage-dashboard/sbu.sh is macOS-only, violates CLAUDE.md rule 10; must move to scripts/mac/ or add cross-platform open helper or get plan override. Silent nohup failure and shallow PID liveness test noted as suggestions.
- 2026-04-19 (S7): PR #29 LGTM (advisory). PR #32 REQUEST_CHANGES: (1) `cachedEmails` module-level var never populated — dead cache, every call hits Firestore; (2) `beforeUserCreated` used instead of plan-specified `beforeSignIn`; (3) no test for `onSignIn` handler itself. PR #33 LGTM (advisory): security rules core correct (cross-user, enum, immutability, config-deny); `meta/{docId}` fully client-writable is accepted v0 risk; snapshots/digests server-write-only not tested.
- 2026-04-19 (S6): PR #25 re-review APPROVE. All blockers resolved: impl commit d52f1b9 present, T4 uses run --separate-stderr, T8b has early-guard, DL_REPO_ROOT hardened with T9a/T9b regressions, check-no-raw-age.sh awk multiline fix confirmed, G2 exclusion narrowed, package.json bare deploy removed. Filter chain fragility noted as acceptable. PR #26 REQUEST_CHANGES: (1) "permission-denied" test name is a lie — test calls makeRequest(undefined) which hits unauthenticated path, not permission-denied; (2) package-lock.json resolves vitest to 4.1.4 not 4.0.18 — pin broken. PR #28 COMMENT_ONLY: structurally correct but recipient key not independently verifiable from armor text; merge.mjs + merge.test.mjs are out-of-scope for P1.3.
- 2026-04-19 (S5): PR #25 (P1.2 _lib.sh xfail suite) + PR #26 (P1.4 Vitest proof-of-life). Both REQUEST_CHANGES. PR #25: impl commit d52f1b9 does not exist — branch has only the xfail commit; T8b vacuous-pass hazard (missing guard); T4 stderr assertion no-op without `run --separate-stderr`. PR #26: BEE_INTRO_MESSAGE is a string constant — fails "not a tautology" criterion; vitest@4.0.18 version needs verification; coverage block without @vitest/coverage-v8 dep.
- 2026-04-19 (S4): PR #19 chore/a7-add-cursor-skills. REQUEST CHANGES. reference.md blob SHA diverged from base af2edbc0 — 4 inline `# gitleaks:allow` comments added beyond verbatim scope. 3 other files exact match. CI failures pre-existing (Firebase secret missing, lint errors in unrelated router files). Rule 18 enforced — did not merge.
- 2026-04-18 (S3): PR #183 Orianna gate bugfixes. APPROVED. Bug A ([0-9]* anchor) + Bug B (awk suppress_next). Merge blocked by GH Actions billing suspension (all checks fail in 2-3s, no compute). Posted advisory comment. Rule 18 enforced — did not merge red.
- 2026-04-18 (S1): dependabot-cleanup team under Camille. Advisory-LGTM on #156/#157. Shared-account invariant-#18 blocker + GH Actions billing diagnosis surfaced.
- 2026-04-18 (S2): test-dashboard Phase 1 workstream (R18–R40). LGTMs: #146–#148, #152–#154, #161, #165, #169–#170, #175, #177, #180, #182. Rule-18 violation caught on #159 (zero-review admin merge, bad AR host landed on main — escalated to Evelynn). Stale-view protocol established. Partial-write hazard + batch cap formula patterns added to knowledge base.

## Archive Note

Commit SHAs prior to 2026-04-19 resolve against `Duongntd/strawberry` (archive, 90-day retention through 2026-07-18).
