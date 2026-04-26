# PR #89 — coordinator-weekly fixture-vs-prod schema drift

**Date:** 2026-04-26
**PR:** #89 (T.P2.4 coordinator-weekly + prompt-stats ingest, Viktor)
**Verdict:** CHANGES_REQUESTED

## What happened

39/39 tests green, golden file deep-equal passing — but the test fixtures synthesized event fields (`coordinator`, `ts` on `dispatch` events; `kind: 'tool_call'` events) that the production ingest pipeline never emits. Three critical correctness issues were silently masked:

1. **C1 — dispatch event shape drift.** `parseSubagentSession` emits dispatch events without `coordinator` or `ts`. The SQL groups by `coordinator` and STRFTIME(ts) and filters `coordinator IS NOT NULL` — production dispatch events are filtered out, `dispatch_count` reads 0.

2. **C2 — phantom event kind.** SQL filters `kind = 'tool_call'`. Nothing in the ingest emits `tool_call` events; the real pipeline emits `kind: 'turn'`. Inline/delegate counts are both 0 in production → ratio NULL → health flag falls through CASE to "executor-mode" for every coordinator. The headline deliverable is degenerate.

3. **C3 — DuckDB schema-inference fragility.** `read_ndjson_auto` infers schema from file contents. If a week's events.jsonl is missing one of the kinds the SQL filters, downstream CTEs hit Binder Error on missing columns. Recently added per-query try-catch in render.mjs swallows it silently, dropping the whole row.

## Lesson — review checklist for "tests pass" PRs

When SQL tests use hand-written fixture JSONL:
1. **Diff the fixture against actual ingest output.** Run `scanAllSources` against a small synthetic input and compare event shapes. Fields present in fixture but absent from the function's emit are red flags.
2. **Grep for the literal event kind.** If SQL filters `kind = 'X'`, grep for `kind: 'X'` (and equivalent forms) in the source emitters. Phantom kinds = guaranteed prod bug.
3. **Run the SQL against an empty / partial events file.** DuckDB schema inference fails on missing columns; this surfaces fragility the test suite never exercises.
4. **Check for a regression test that round-trips ingest → SQL.** If only synthetic-fixture tests exist, the contract between ingest and SQL is unverified.

## Lesson — DuckDB read_ndjson_auto pitfall

`read_ndjson_auto` infers schema from data. Two CTEs reading the same file with different WHERE clauses can each fail independently if their referenced columns aren't present. Mitigations:
- Explicitly cast columns: `SELECT … FROM read_ndjson_auto(…) AS e (kind VARCHAR, role VARCHAR, …)` to force schema.
- Sentinel rows in the events file (one of every kind, even if dummy).
- Split into separate query files, one per event kind, joined at consumption time.

## Lesson — health-flag NULL fallthrough

CASE WHEN with NULL evaluates to NULL (false-ish), so chained `WHEN ratio > 0.7` / `WHEN ratio >= 0.5` ELSE branches all fall through to ELSE when ratio is NULL. Always handle the no-data case explicitly:
```sql
CASE
    WHEN inline + delegated = 0 THEN 'no-data'
    WHEN ratio > 0.7 THEN 'healthy'
    ...
END
```

## Lesson — function-arg name vs value drift

`parseSubagentSession` passes `dispatch_prompt_tokens: assistantRows[0].usage.input_tokens` — that value is system-prompt + tools + history + dispatch text, not just the dispatch prompt. Function arg names are part of the contract; misnamed args mean misinterpreted metrics for everyone reading the dashboard. Worth flagging even when the impl honors the test.

## Lucian's pass

Lucian also reviewed (Lane: strawberry-reviewers, identity strawberry-reviewers) and APPROVED on plan-fidelity grounds. He flagged the same drift footnotes (CTE join on independently-derived iso_week) but interpreted T.P2.4 DoD as scope-met. Senna and Lucian disagree by lane: Lucian reads "DoD says 'inline-vs-delegate ratio computed via path discriminator' — implementation matches"; Senna reads "the implementation is unreachable against real data". Both lanes are correct in their lane. The PR likely needs a follow-up from Viktor before merge.
