# PR #93 — JSDoc-glob syntax bug caught by actually running the code

**Date:** 2026-04-26
**PR:** #93 (dashboard-T.P2.3 decision-rollup, Viktor)
**Verdict:** CHANGES_REQUESTED
**SHA reviewed:** d4ca628a

## The catch Lucian missed

Lucian APPROVED the PR with two flagged-for-Senna importants (F1 typed-parser bypass, H1 kind taxonomy mismatch). Both real. But the bigger find was a **module-load syntax bug** that broke ingest entirely:

`tools/retro/lib/sources.mjs:9` — comment block contained `agents/*/memory/decisions/log/*.md`. The substring `*/` after `agents/*` closes the JSDoc opened at line 1. Everything after is parsed as JS, throwing `ReferenceError: memory is not defined` at module load.

**Why fixture-shelling tests passed:** `__tests__/queries-decision-rollup.test.mjs` invokes `duckdb -json` directly against the static `fixtures/decision-rollup-events.jsonl` — never imports `sources.mjs`. So the SQL+golden-equal contract was satisfied while the production ingest path was completely broken. The xfail flips look green; the real ingest crashes.

**Lucian could not have caught this:** plan-fidelity review reads diffs, doesn't run code. Senna's reviewer-discipline rule §5 "run the code mentally, end-to-end" extended to "actually `node -e import(...)` the new module" surfaced it in seconds.

## Lesson

For any PR adding a new module that downstream `import`s, run the import as a smoke test before reviewing further. Cost: one shell command. Value: catches the entire class of "tests pass but production crashes" bugs that fixture-shelling test design hides.

```bash
node -e "import('./path/to/new-module.mjs').then(m => console.log('OK:', Object.keys(m).join(','))).catch(e => { console.error('FAIL:', e.message); process.exit(1); })"
```

## Secondary find (Senna lane, not in Lucian's pass)

R8 in `regression-decision-ingest.test.mjs` asserts that empty-axes files are silently skipped — bakes the F1 silent-skip bug into the regression contract. If F1 is later fixed (typed throw), R8 goes red, agent is incentivized to revert F1 to keep the test green. Wrong-spec test is worse than no test.

**Pattern:** when reviewing tests that pair with a flagged behavioral bug, verify the test's expectation MATCHES the desired behavior, not the current (broken) behavior. A test that assents to the bug locks the bug in.

## Findings posted

- **B1 (BLOCKER):** sources.mjs:9 unterminated JSDoc.
- **B2 (BLOCKER):** regression test failing as consequence of B1 (Rule 13).
- **F1 (IMPORTANT, Lucian-flagged + confirmed):** scanDecisionLogs bypasses parseDecisionFrontmatter; silent skip on empty axes; `knownConfidences` Set dead code; brittle `=== 'true'` string equality.
- **F2 (IMPORTANT, my catch):** R8 enshrines F1's silent-skip as spec.
- **H1 (IMPORTANT, Lucian-flagged + confirmed):** `kind: 'decision'` should be `kind: 'decision-log'` per plan T.P2.1:292 + PR #88 precedent.

Review URL: https://github.com/harukainguyen1411/strawberry-agents/pull/93#pullrequestreview (id PRR_kwDOSGFeXc74-clY)
