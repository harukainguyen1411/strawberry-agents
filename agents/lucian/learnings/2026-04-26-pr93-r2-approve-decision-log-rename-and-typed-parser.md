# PR #93 round-2 fidelity — APPROVE (T.P2.3 decision-rollup)

**Date:** 2026-04-26
**PR:** harukainguyen1411/strawberry-agents#93
**Plan:** plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md (T.P2.3)
**Fix commit:** 71d1e2df on `dashboard-T.P2.3`
**Round-1 findings:** F1 (typed-parser bypass), H1 (kind taxonomy mismatch)
**Verdict:** APPROVE

## What landed in fix commit

- F1: `scanDecisionLogs` now routes every decision through `parseDecisionFrontmatter` (decision-axes.mjs). One validated ingest path. `parseAxesList` is now a pre-step that produces typed input for the validator, not an alternative parser.
- F2 (bonus, beyond round-1 ask): R8 emits a stderr warning instead of silently skipping malformed decisions. Aligns with plan B §3.5 data-quality intent.
- H1: rename `kind: 'decision'` → `kind: 'decision-log'` complete across emitter, SQL WHERE, fixtures, JSDoc, comments, regression test assertion, source-key in mtime-cache. Verified zero remaining `kind: 'decision'` hits via grep.
- B1/B2: JSDoc early-termination bug in sources.mjs (bare `*/` from glob `agents/*/memory/...`) replaced with prose form `agents/<agent>/memory/...` — module-load `ReferenceError` cleared, regression suite 14/14 green.

## Verification approach

1. `git show --stat 71d1e2df` to see the changed files.
2. Grep across `tools/retro/**` for `kind: 'decision'` (without `-log` suffix) — zero hits confirms taxonomy uniformity.
3. Read sources.mjs around `scanDecisionLogs` to confirm typed-parser is the sole path; check `parseDecisionFrontmatter` import + call site.
4. Read decision-rollup.sql to confirm `WHERE kind = 'decision-log'` + plan-cited contract.
5. Run only the decision-related test files (regression + rollup + axes-parser) — 33/33 pass. Skip the unrelated `render-lock-tile` fixture-missing failures (TP3 scope).

## Fidelity-review pattern reuse

- **Rename completeness check:** when a finding asks for a string rename across many surfaces, run a single `grep -rn` with a negative filter that excludes legitimate substrings (e.g. `decision-log`, `decision-axes`, `decision_id`). Zero hits = clean. This caught zero on PR #93 first try.
- **Single-ingest-path invariant:** a typed-parser route is "load-bearing" only if there is no parallel untyped path. Confirm by grepping for the parser import (must exist) AND for any field-by-field destructuring of frontmatter that would bypass it.
- **Bonus-fix scope:** F2 (R8 warning) was beyond the round-1 ask. Lucian flags scope creep but doesn't block on it — when bonus fixes align with the plan's data-quality intent (§3.5 here), they're a positive signal, not creep.

## Cross-lane note (for Senna)

Senna's round-2 review may want to verify the F2 stderr-write is rate-limited or non-spammy in the cold-start scenario where many malformed decisions exist. Out of Lucian's lane.

## Plan-itself escalation status

Round-1 Azir escalation about Plan B §3.5 line-range path-lag: still pending Azir, does not block this PR (impl honors plan-as-written). Tracked in evelynn's coordinator inbox.
