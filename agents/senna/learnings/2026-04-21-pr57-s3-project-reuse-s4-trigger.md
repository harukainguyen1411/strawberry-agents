# PR #57 — S3 project-reuse + S4 auto-trigger (company-os) review

Date: 2026-04-21
Repo: missmp/company-os
PR: https://github.com/missmp/company-os/pull/57
Head: 5d9f57b
Base: feat/demo-studio-v3
Author: duongntd99 (Duong) — review posted as COMMENTED (self-author constraint)
Verdict: would-be CHANGES_REQUESTED for C1 + I1 on a non-author identity; posted as
comment due to self-author constraint + reviewer lane lacking missmp org access.

## Review method (repeat)

- Worktree already materialized at `/private/tmp/s3-feat-worktree` (HEAD 5d9f57b) by the
  implementing agent — reused it instead of adding another worktree.
- Three S3-specific commits 94f9013 / f861dfd / 5d9f57b confirmed via
  `git log --oneline origin/feat/demo-studio-v3..HEAD -- tools/demo-factory/` — exactly 3,
  clean perimeter (50 other commits in the PR are BD/SE/MAL/MAD migration; Duong accepted that scope).
- Rule-12 sequencing verified: xfail scaffold commit precedes impl precedes flip on the branch.
- Ran the full demo-factory suite locally 3 consecutive times: 66 passed, 0 failed, 0 flaky.

## Top findings

### C1 — httpx HTTPStatusError str() leaks URL with query string

`_trigger_s4` logs `logger.warning("S4 trigger attempt %d failed: %s", attempt, exc)` where
`exc` is whatever `resp.raise_for_status()` raised. Reproduced independently:

```python
>>> str(httpx.HTTPStatusError(...))
"Server error '500 Internal Server Error' for url 'http://example.com/v?secret=abcdef123'\n..."
```

Today's `S4_VERIFY_URL` is a plain Cloud Run URL so the blast radius is small, but the
moment anyone rotates to a GCP signed URL or presigned trigger, every 5xx retry leaks the
signature to Cloud Logging. This is a class of bug worth remembering: **Python exception
`str()` methods routinely include full URLs**. Check `httpx.HTTPStatusError`,
`requests.HTTPError`, `aiohttp.ClientResponseError`, `urllib.error.HTTPError`.

Fix pattern: log `exc.__class__.__name__` + status code, or a redacted `scheme+host+path`
derived from `urlsplit`. Never log `str(exc)` when the exc might be an HTTP error type.

### I1 — In-memory dict where plan prescribes Firestore → silent 404 on container restart

ADR explicitly called for Firestore collection `demo-factory-projects`; implementation
shipped `_projects: dict[str, dict] = {}` with an honest `# stub` comment. On Cloud Run
with min-instances=0, every idle-scale-down invalidates every previously-returned
projectId → the S1 iterate-rebuild flow returns 404 silently after ~15 min idle.

This straddles Lucian's plan-fidelity lane and my code-quality lane because the failure
mode is real and dangerous even though "it matches the plan" if you squint at "stub".
Pattern: **when an implementation ships a stub for a store-backed contract, quality review
must enumerate the runtime failure modes triggered by the stub, not just flag "not
implemented".**

### I2 — `_should_fail_build` module-level seam is a prod attack primitive

Function only exists to let tests `patch.object(m, "_should_fail_build", return_value=True)`.
In prod it always returns False. Anyone with Python process access (sidecar, `/dev/mem`,
bad dependency) can flip it and silently fail every build. Seam should be a conftest
fixture, not a prod function.

Pattern for future reviews: **grep for module-level functions whose only callers are
tests**. They're often low-risk convenience seams, but occasionally expose an attacker
primitive proportional to their side-effect surface (here: deterministic build failure).

### S1 — `delays = [1, 2, 4]` with `if attempt < len(delays): sleep(delay)` → 4 is dead

Classic retry-table footgun: declaring N delays but the loop skips the sleep after the
final attempt. Net effect is N-1 sleeps. Either the ADR wanted 4 attempts (loop was wrong)
or 3 attempts (list has a dead element). Always reconcile the delay-list length against
the attempt count.

## What the PR got right

- Auth posture on new routes matches existing `/v1/build` (`Depends(_require_auth)` on all three).
- Structured `_log()` calls never include Authorization header or token.
- httpx client properly `async with`-scoped — no connection leak.
- TestClient-compatible BackgroundTasks choice is correct; tests wait for background completion deterministically.
- httpx `timeout=10.0` bounds the worst-case retry path at ~33s.
- xfail flip diff was clean — @XFAIL removed on exactly the 10 passing cases, no strict-xpass failures.
- `uuid.uuid4().hex[:12]` random projectIds eliminate the TOCTOU concern on the dict lookup.

## Meta-observations

- Reviewer lane `strawberry-reviewers-2` has no access to missmp/company-os; work-concern
  PR reviews fall back to `duongntd99` (the active default). Since PR author is also
  `duongntd99`, review state is locked to COMMENTED. Task brief accounted for this
  ("Use `gh pr review 57 --comment --body-file -`"). Not a lane-separation violation —
  this is a work-concern repo outside the strawberry-agents review infrastructure.
- Senna persona signature at end of body kept per protocol. Pattern for future
  work-concern reviews: post as `duongntd99` with `--comment`, sign as `— Senna`.
