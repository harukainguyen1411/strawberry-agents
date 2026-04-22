# PR #32 config-leak fix — `list_recent_sessions` vs `/sessions` endpoint drift

Date: 2026-04-22
Repo: missmp/company-os
PR: #32 (feat/demo-studio-v3)
Verdict: REQUEST-CHANGES (one important drift)

## Pattern — "migrated-the-helper, missed-the-endpoint" drift

PR migrated `session.py::list_recent_sessions` to resolve brand via S2 fetch, good tests, clean Rule 12 chain. But `git grep list_recent_sessions` in non-test files shows ZERO callers — the function is dead code. Meanwhile `@app.get("/sessions")` at main.py:2817 is the LIVE endpoint the dashboard uses, and it was not touched: still reads `config.brand/insuranceLine/market` directly from the session doc. After the fix, new docs have no `config` blob, so the dashboard list silently blanks brand/line/market for all new sessions.

**Review checklist for "migrate reader X off legacy-field pattern" PRs:**
1. `git grep -n <migrated-function-name>` in non-test files to verify it's live.
2. `git grep -nE 'config|<legacy-field>' <module>` for ALL parallel readers that might still reference the legacy shape.
3. Flag `/*.get|@app.get` routes specifically — they're usually the live wire.
4. Dead helper + live endpoint drift is the default hazard shape: author tests the helper they touched, CI passes, endpoint silently regresses at first post-merge request.

## Pattern — response-shape ambiguity across callers

Same PR: `config_mgmt_client.fetch_config` is called in four places with TWO different assumptions:
- main.py:1917 + 2727: `cfg_payload.get("config", {}).get("brand")` — nested shape
- main.py:3086 + new session.py:144: `s2.get("brand")` — flat shape

Test mocks the flat shape. If nested is actually canonical, new function is vacuous and tests lie. Always read the service client's docstring / schema — if silent, flag and ask. Client module should lock the return shape in its docstring.

## Pattern — T7 "wipe" scripts worth reviewing even when not executed

PR includes `scripts/wipe_staging_sessions.py` with `--confirm` gate, 500-batch, idempotent. Correct. But the script deletes EVERY doc in the collection, not just leak-shaped docs. For the plan's stated "96 leaked docs, all disposable" assumption that's fine — but a pre-flight that reports schema fingerprint of first N docs would catch the operator's mistake if any non-leaked doc exists (e.g. post-fix test session, stray QA doc). Worth suggesting even when non-blocking.

## Pattern — hardcoded invariants breed dead branches

T3 replaces `version = session.get("factoryVersion", 1)` with `version = 2`. Downstream `if version >= 2: … else: trigger_factory(v1)` is now dead code. When a field becomes a constant, grep for conditional branches keyed on that field and drop them — dead v1 branches confuse future readers and leave the v1 import live.

## Pattern — `_UPDATE_ALLOWLIST` additions for fields the write path doesn't use

T5 added `config_id → configId` to `session_store._UPDATE_ALLOWLIST`. Correct defense-in-depth. BUT `session.py::create_session` writes `configId` directly to Firestore without routing through `session_store.update_session`, so the allowlist entry is a no-op for the create path. Load-bearing only for hypothetical future callers. One-line comment clarifying the split would help readers — allowlist additions in split-module codebases are often defensive-only.

## Pattern — `requests` calls with no timeout inside ThreadPoolExecutor

New `list_recent_sessions` submits `config_mgmt_client.fetch_config` (sync `requests.get` with no `timeout=` kwarg) to a ThreadPoolExecutor. One stuck S2 host pins a pool thread forever; `as_completed()` blocks; `future.result()` has no timeout either. Latent because the function is dead, but the moment it's wired it becomes a runtime hang primitive. Always flag `requests.<method>` without timeout inside concurrent futures as a blocker-waiting-to-happen.

## Reviewer-auth — missmp/* gap (S27+) still open

Confirmed again at 2026-04-22: `strawberry-reviewers-2` lane returns `GraphQL: Could not resolve to a Repository with the name 'missmp/company-os'` on direct `gh pr view`. Contingency path is to write verdict to `/tmp/senna-pr-<n>-verdict.md` and let Yuumi post as a comment under duongntd99. No state-bearing review possible until Sona clears the access. Tracking count: S27, S28, S29, S30, S31, S32, S33, S34, S37 (S35 posted no GitHub review, scope-fenced only; S36/S38 were strawberry-agents). Now S39. Nine consecutive sessions on missmp/* without formal reviewer-state capability — worth prioritizing.
