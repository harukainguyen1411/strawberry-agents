---
date: 2026-04-25
concern: work
pr: missmp/company-os#32
verdict: COMMENT (advisory; recommend merge with two follow-ups)
review_url: https://github.com/missmp/company-os/pull/32#issuecomment-4318159746
---

# PR #32 Wave D ship — review of a8a7300 (6-pre-existing-failure resolution)

## Top findings

1. **Falsified xfail root-cause comment on smoke `test_post_session_returns_201`.**
   The xfail reason claims `_mem_store.clear()` (from the autouse conftest fixture)
   "clears owner_uid/owner_email that the Slack trigger previously seeded" on the
   live service. Mechanically impossible: the conftest fixture only runs in the
   local pytest process; the live `POST /session` route at `main.py:2050-2080`
   hardcodes `owner_uid=""` / `owner_email=""` (no Slack-trigger seed exists).
   Future-engineer hazard: chasing a phantom root cause. Recommended honest
   rewrite: "smoke regression on POST /session — root cause TBD, T.P1.X."

2. **In-memory fallback in `session.create_session()` is a production silent-
   failure mode.** Old contract: raise `RuntimeError("Firestore unavailable")`.
   New contract: silently write to module-level `_mem_store` dict and return.
   In production, `get_db()` returns None when `firestore.Client(...)` raised
   at first invocation (transient creds/network) — pod-local ghost session,
   user's auth-exchange GET hits a different pod → 404, no Firestore-down
   signal. Recommended fix: gate behind explicit env flag for dev/test only.

3. **`xfail(strict=True)` on a `skipif`-gated test is a CI no-op.** The smoke
   class is `pytest.mark.skipif(not BASE_URL)` and CI doesn't set BASE_URL —
   strict never fires. Documenting only.

## Cleared

- `shortcode` reclassification (forbidden → allowed in `_UPDATABLE_FIELDS`):
  honest. T.P1.11 adds it as a factory build-output field alongside `buildId`,
  `projectUrl`, `demoUrl`. Not config/identity.
- `test_create_session_raises_when_db_unavailable` → in-memory-return: shape
  matches actual code. The contract change itself is finding 2, but the test
  honestly reflects the new behavior.
- Three T.P1.8 projectId-persistence xfails: pending-impl, not Wave-D
  regressions. Not masking anything that worked before.
- Auth-exchange Loop 2c claim-on-first-touch: transactional, raced_claim →
  403 with diagnosable detail, cookies HttpOnly + SameSite=strict + Secure.
- `FACTORY_REAL_BUILD`: single read site (`main.py:2688`), default `"0"`, NOT
  in `deploy.sh --set-env-vars`. Cleanly deletable post-soak.
- Secrets/.env: only `.env.example` templates committed; no `api_key`/token/
  private-key additions in the diff.

## Methodology notes

- **God-PR review with 303k +diff / 483 files / 100 commits**: don't try to
  diff the whole thing. Focus the review on (a) the most recent commit Sona
  flagged (`a8a7300`), (b) the contracts touched by it (session.py,
  test_session.py, test_smoke.py), (c) the routes most exposed to regression
  by upstream waves (auth-exchange, POST /session), and (d) the deploy
  surface (deploy.sh + .env.* files). That covers the high-signal area in
  ~5 file reads instead of 483.

- **Cross-checking xfail "suspected root cause" comments**: read the
  fixture's clearing code and the route's create_session call site in
  parallel. If the fixture is test-process-only (autouse conftest) and the
  route hardcodes the value the comment claims is "cleared," the comment is
  wrong by construction. Cheap two-grep verification.

- **Spotting silent-failure contract changes**: when a previously fail-loud
  branch (raise) becomes fall-through (silent return), check whether the
  branch is reachable in production. `get_db() is None` IS reachable in
  production (firestore.Client constructor catches Exception → returns
  None). The test convenience reuses the production path → production
  inherits the silent fallback.

## Auth path used

Work-scope: `scripts/post-reviewer-comment.sh --pr 32 --repo missmp/company-os
--file <body>`. Posts under `duongntd99`. Anonymity scan rejected first
attempt because the body referenced a previous-author by agent-name; rewrote
to neutral phrasing ("the `a8a7300` xfail / contract resolution"), retried,
posted clean. Sign-off `-- reviewer`.
