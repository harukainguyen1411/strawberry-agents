# PR #93 r2 — incomplete fix on a sibling file with the same bug class

**Date:** 2026-04-26
**PR:** #93 (T.P2.3 decision-rollup, Viktor)
**Round:** 2
**Verdict:** CHANGES_REQUESTED
**SHA reviewed:** 71d1e2df

## The catch

Round 1 flagged B1: JSDoc-glob early-termination at `lib/sources.mjs:9` — `agents/*/memory/...` contains `*/` which closes the comment block. Fix commit message claimed "two sites in sources.mjs" patched. True — but the same bug was also in `tools/retro/ingest.mjs:11`, the actual production CLI entry point (per its `#!/usr/bin/env node` shebang).

`ingest.mjs` is the CLI the dashboard depends on. Module-load `ReferenceError: memory is not defined` → CLI completely broken. The decision-ingest regression (14/14 green) does not catch it because it imports `scanDecisionLogs` from `lib/sources.mjs` directly and never spawns the CLI.

## The downstream finding (B2 wrong-baseline claim)

Viktor flagged 5 failures in `regression-pr88-fixes.test.mjs` (C1/C2/I4/I5) as "pre-existing, not introduced by this PR". I verified by checking out only `tools/retro/ingest.mjs` from `main` (PR head everywhere else) and re-running the suite:

| Test | PR HEAD | main ingest.mjs only |
|---|---|---|
| C1, C2, I4 | FAIL | PASS |
| I3 | PASS | PASS |
| I5 | FAIL | FAIL |

C1/C2/I4 all spawn `node tools/retro/ingest.mjs` via `execSync` and crash at module load. Only I5 is genuinely pre-existing. **Author's "pre-existing" claim was wrong by a factor of 4.**

## Lessons

1. **When a fix patches "every site of bug X", grep the entire diff scope for the bug pattern, not just the file the round-1 reviewer cited.** Round 1 cited `lib/sources.mjs:9`; the fix author trusted the citation and missed the sibling site in `ingest.mjs`. A 5-second `grep -n 'agents/\*' tools/retro/**/*.mjs` would have surfaced both.
2. **Production-CLI entry-points need their own smoke test.** Module-load works through different import paths in the test harness vs. CLI invocation. `node tools/retro/ingest.mjs --help` (or `node -e "import(...)"`) is a 1-second sanity check that catches this entire bug class.
3. **"5 pre-existing failures" is a baseline claim — verify it.** When an author says "these are pre-existing", run the suite against the actual baseline (`git checkout main -- <minimal-set>`) and compare. The cost is one stash + checkout + test run; the value is catching incomplete fixes.
4. **Subprocess execSync in test harnesses hides module-load bugs.** When a test calls `execSync('node ./bin.mjs ...')`, a module-load crash surfaces as a generic "Command failed" with stderr — easy to misread as "pre-existing flake". Always inspect stderr text, not just exit code.

## Pattern

> When the fix message says "patched all sites" but the bug class is a *syntax* one (JSDoc glob, regex anchor, escape char), grep the entire diff scope for the pattern before trusting the count. Author may have only patched the cited site.

Review URL: https://github.com/harukainguyen1411/strawberry-agents/pull/93#pullrequestreview-4177163413
