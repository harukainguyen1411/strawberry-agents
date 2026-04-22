# PR #69 — Firebase auth frontend sign-in UI review

**Repo:** `missmp/company-os` (work concern)
**Branch:** `feat/firebase-auth-2b-frontend-signin` → `feat/demo-studio-v3`
**Verdict:** advisory LGTM, 3 important notes, 4 suggestions, no blockers.

## Summary of findings

Focus areas: frontend auth flow correctness, token handling, XSS, CSRF stance.

- Server backbone (Loop 2a, PR #65, already merged) uses HttpOnly + Secure + SameSite=Strict on `ds_session`, which structurally closes CSRF on `/auth/login` and `/auth/logout`. No CSRF token needed in frontend. `/auth/config` returns only public Firebase values (apiKey, authDomain, projectId) — public by design, gated by domain allowlist server-side.
- Error surface is XSS-safe (all paths use `.textContent`).

**Important findings:**
1. Popup-cancelled error path has fallthrough `throw new Error('Sign-in cancelled')` that masks all unknown errors — real failures (network, account-collision, SDK error) display as "cancelled".
2. Hardcoded `@missmp.tech` in frontend 403 message — server domain is env-driven (`ALLOWED_EMAIL_DOMAIN`), so this drifts in non-prod projects.
3. Silent `/auth/logout` failure leaves server cookie intact; user thinks they signed out but next page load reverts to signed-in state.

**Suggestions:**
- Race in `onAuthReady` probe — serial `getCurrentUser()` calls on repeat `onAuthStateChanged` events can resolve out of order.
- `role="alert"` + `hidden` class may miss screen-reader announcements on repeat errors.
- ES module imports from gstatic CDN have no SRI — known browser limitation, noted for future hardening.
- All 19 "e2e" tests are source-text grep assertions; real browser/emulator tests deferred. PR description overstates coverage.

## Process notes

- Task greeting was `[concern: work]` — repo lives in `~/Documents/Work/mmp/workspace/feat-firebase-2b/` (worktree) on `missmp/company-os`.
- Reviewer-auth (`strawberry-reviewers-2`) has no access to `missmp/company-os`; its scope is `harukainguyen1411/*` (personal strawberry repos). Writing verdict to `/tmp/senna-pr-69-verdict.md` per the task's Yuumi-fallback instruction is the correct path for work-concern code review.
- TDD gate validated: `test:` commit (f476b09) precedes `feat:` commit (5b9c41c).

## Takeaway

Review against the server backbone first when reviewing frontend auth — knowing SameSite=Strict is in place on POSTs materially changes the CSRF analysis. Had I not checked `main.py`'s `/auth/login` and `/auth/logout` handlers, I might have asked for a frontend CSRF token that the architecture doesn't need.
