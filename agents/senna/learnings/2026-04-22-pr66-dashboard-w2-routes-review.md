# PR #66 — demo-dashboard W2 routes (missmp/company-os, work-concern)

**Session:** 2026-04-22
**Concern:** work
**Repo:** missmp/company-os
**Branch:** feat/demo-dashboard-w2-routes → feat/demo-studio-v3
**Verdict:** ADVISORY LGTM (non-blocking)
**Review channel:** verdict file (`/tmp/senna-pr-66-verdict.md`) — `strawberry-reviewers-2` still ungated on missmp/* (S27+ gap, now ~10 sessions)

## Scope under review

4 commits on a fresh branch (not an inflated-scope case): Vi xfail skeletons (504dcfe) → Viktor route impl (b7e9bc7) → auth helper copies (79479fd) → xfail flips (aaa830f). +3193/−6 across 9 files. Routes: 8 migrated from S1 `tools/demo-studio-v3/main.py` into new `tools/demo-dashboard/main.py`. test-results storage nominally moved to Firestore collection `demo-studio-test-results`.

## Top findings

- **IMP-1 (narrative)**: Task brief said "dual-write per OQ4 — S1 writer still live"; plan §OQ4 line 162 actually resolved OQ4 as "Freeze — simplest and the window is short." **No dual-write is occurring**. S1 still writes JSON files; dashboard reads an empty Firestore collection. Not a code bug — matches plan — but task-brief framing is wrong.
- **IMP-2 (shape regression)**: Dashboard `/api/test-results` + `/api/test-run-history` return `{results|runs: [<raw doc>, <raw doc>, ...]}`. S1 returned a single enriched dict with `total`, `tests`, `components`, etc. When T.W3.3 wires the S1 writer, UI clients expecting S1 shape break. No ordering, no limit — unbounded `stream()` will scale badly. Zero UI consumers today (verified via `grep api/test-results`).
- **IMP-3 (log hygiene)**: Three `_log.error("... error=%s", exc)` sites for Firestore errors — may leak resource-path context in error messages. Matches S1 pattern so migration-faithful; call out as S28 follow-up.
- **S7 (suggested upgrade to IMP)**: `managed_sessions_terminate` returns `"terminated": true` but the handler only logs; no Anthropic-stop, no DB update (deferred to W4). Misleading claim.

## What's clean

- Rule 12 chain verified via commit timestamps.
- 19/19 tests green locally + verified double `importlib.reload(main)` (reloadability per Vi constraint 3).
- `service_health_proxy` byte-for-byte equivalent to S1.
- INTERNAL_SECRET guard fail-closed on unset env; `hmac.compare_digest` prevents timing leak.
- Module-level `db = None` + lifespan reassignment is correct.
- Tests non-vacuous: call-identity assertions (`assert_called_once_with("demo-studio-test-results")`), positive+negative auth pairs.

## New patterns captured

1. **Task-brief claim vs plan body**: when reviewer sees a "dual-write" claim but plan says "freeze", always diff the two. Plans have multiple OQ blocks with competing drafts; the locked resolution wins — not the surface text.
2. **`list[doc.to_dict() for doc in stream()]`** is a shape-regression smell when migrating from an enriched `_normalize` + `_enrich` reader. Check for ordering + limit clauses + enrichment delta. Without `.limit()` on a grow-only collection, ship is a perf-bomb waiting for the writer.
3. **`"terminated": true` response without side-effect**: a gate-kept endpoint that pretends to do the thing but doesn't is worse than no endpoint. Prefer `"terminated": false, "reason": "deferred_to_Wn"` when wiring is deferred across waves.
4. **Duplicated `hmac.compare_digest` helper** (inline in main.py + copied in auth.py) is drift-bomb-on-import: one fix won't propagate.
5. **Copy-auth module with unresolved `from session import get_db`** where `session.py` isn't in the service — ImportError at first call. Copy the dep graph, or mark the module as dead-until-W4.

## Reviewer-auth state

`strawberry-reviewers-2` still missing `missmp/company-os` access. 10 consecutive sessions (S27–S39 work-concern reviews) blocked from state-bearing approvals. Prioritize for Sona — this is a standing blocker on every missmp PR.

## Memory patch

- Append to MEMORY.md Sessions list as S40 (2026-04-22): PR #66 dashboard-split W2 routes, advisory LGTM, patterns above.
- Reinforce stale-framing check: always read plan OQ block before trusting task-brief OQ summary.
