---
date: 2026-04-26
pr: 88
verdict: changes-requested
review_url: https://github.com/harukainguyen1411/strawberry-agents/pull/88#pullrequestreview-PRR_kwDOSGFeXc74988N
---

# PR #88 — T.P2.2 feedback-rollup SQL + ingest extension (Viktor)

## Context

Phase-2 dashboard work: feedback-rollup card. Routes feedback events through a sidecar
`feedback-events.jsonl` (annotated `-- events-source:` in SQL) to keep the main
`events.jsonl` schema invariant. New `runDuckDBQueryWithFileDb()` passes the events file
as DuckDB's database argument so SQL can use `FROM file`. New `resolveQueryEventsSource()`
in `render.mjs` routes annotated queries.

## Findings (request-changes)

### Critical

1. **`feedback-events.jsonl` stale-output bug** — ingest writes the file conditionally
   on `feedbackEvents.length > 0` but never deletes a previously-written one. After a
   re-ingest with all feedback removed, the stale file is silently consumed, dashboard
   reports phantom data. Fix: `unlinkSync` on the empty branch (or always-write with
   a guard in `runDuckDBQueryWithFileDb` for the empty-jsonl case).

2. **DuckDB schema-inference fragility** — `MAX(created)::VARCHAR` only renders as
   `YYYY-MM-DD HH:MM:SS` because all-ISO fixtures cause TIMESTAMP inference. A single
   malformed `date:` in production flips the column to VARCHAR and the format silently
   changes to `2026-04-22T14:30:00.000Z`. Fix: validate `fm.date` matches strict
   `YYYY-MM-DD` regex AND pin SQL output with `strftime(MAX(CAST(created AS TIMESTAMP)),
   '%Y-%m-%d %H:%M:%S')`.

### Important

3. Path-traversal hardening for `events-source:` regex (`\S+`). Today repo-trusted, but
   `-- events-source: ../../etc/passwd` is a future vector if SQL ever becomes
   user-influenced. Add basename validation (`/^[A-Za-z0-9._-]+\.jsonl$/`).

4. mtime-cache key `feedback-index` only stores `INDEX.md` mtime, but the scanner
   reads every other `*.md`. Phase-2 incremental mode will miss individual-file changes
   unless INDEX.md is also touched. Either aggregate max(mtime) across `feedback/*.md`
   (excluding INDEX.md) or document the dependency inline.

5. `stateToStatus` default → 'open' silently inflates open counts on typo'd `state:`
   values. Comment acknowledges the trade-off but no stderr diagnostic is emitted.

### Suggestions

- `feedback-events.jsonl` fixture is byte-identical dup of `feedback-rollup-events.jsonl`
  with zero call-sites — drop or wire to e2e.
- SQL comment claims `latest_entry_ts` is the raw `created` string; it is actually a
  reformatted TIMESTAMP cast.
- `parseFrontmatter` quote-strip regex strips mismatched outer quotes (e.g. `"foo'` →
  `foo`). Acceptable for in-house format.
- `time:` field exists in real feedback files but is dropped (hardcoded T00:00:00.000Z).
- `events-source:` regex should be line-anchored (`^--\s*events-source:` multiline) to
  avoid future false positives in comment blocks or string literals.

### Tests

- TP2.T1-A/B/C/D xfail-first ordering honored (Rule 12 OK).
- No unit test for `parseFeedbackIndex` itself (frontmatter parser, state mapping,
  date validation, malformed entries).
- No unit test for `resolveQueryEventsSource` (no-annotation, missing-file, present-file).

## Phase-1 regression check (explicit ask)

Verified intact. `resolveQueryEventsSource` returns the default eventsPath + useFileDb=false
when no annotation is present, preserving the byte-identical Phase-1 path. PR body
confirms TP1.T2/T5/render-html/invariant-plan-stage/invariant-wall-active green.

## Patterns

- **DuckDB schema-inference is implicitly format-coupled**: when SQL casts MAX(timestamp)
  to VARCHAR, the output format depends on whether DuckDB inferred TIMESTAMP or VARCHAR
  for the source column. Always pin output format with `strftime` for cross-input stability.
- **Conditional-write + no-cleanup = silent stale state**: a file that's only written
  when N>0 must be deleted when N=0, or downstream consumers will silently use last-run
  data.
- **Sidecar sources need stale-data hygiene**: any `-- events-source:` redirect must
  handle the "source file from previous run is now invalid" case.

## Identity / lane discipline

User said "use `--lane strawberry-reviewers-2`" but the script accepts `--lane senna`
(reviewer-auth.sh maps lanes to identities). Initial verbatim invocation rejected by
both the framework permission system and the script itself. Resolution: the user's
language was descriptive — `senna` lane → `strawberry-reviewers-2` identity. Verified
via `gh api user` post-invocation: returned `strawberry-reviewers-2`.
