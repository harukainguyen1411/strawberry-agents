# PR #79 review — retro-dashboard Phase 2+3 xfail bundle

**Date:** 2026-04-26
**Repo:** strawberry-agents (personal concern)
**Author lane:** Rakan (xfail) + Xayah (test plan)
**Verdict:** REQUEST CHANGES — one critical (`require` in pure ESM .mjs), four important, five suggestions
**Auth:** `scripts/reviewer-auth.sh --lane senna gh pr review 79 --request-changes` as `strawberry-reviewers-2` (clean, no fallback needed)

## Critical finding worth keeping in pattern library

**`require('path').dirname` in a `.mjs` file shadowing a named import.** This was acknowledged in the PR body as "Viktor will resolve cleanly during impl wiring." That framing is wrong: xfail-test correctness under Rule 12 belongs to the xfail commit, not the impl that flips it green. A test that crashes in `before()` setup never asserts the invariant it's documented to guard — it converts to a `ReferenceError`-shaped pass-by-default once the skip guard flips off, *unless* `node:test` correctly reports setup failures (it does, but the failure mode is opaque — "ReferenceError" is not the diagnostic the plan demands).

Pattern to flag in future Rakan PRs: any `.mjs` file containing a `require(` token, OR a function declaration whose name matches an imported symbol — these are likely shadowing bugs. Quick grep:
```bash
grep -lE "require\(['\"]" tools/**/__tests__/*.mjs
```

## Self-confirming snapshot footgun

Three sites in this PR (render-html-phase2.test.mjs, render-lock-tile.test.mjs, e2e-phase3.bats) use the pattern:

```js
if (!existsSync(snapPath)) { writeFileSync(snapPath, actual, 'utf8'); return; }
```

First green run captures whatever the impl emits as the golden — the test cannot fail because the assertion records itself. The conventional fix is to require an explicit `UPDATE_SNAPSHOTS=1` env to write; otherwise `assert.fail("snapshot missing")`. This is the #1 footgun for xfail→green flips on snapshot tests, more dangerous than vacuous-pass-via-skip because there's no `IMPL_EXISTS` guard catching it.

## "ALLOWED set declared but never positively asserted" pattern

`queries-coordinator-weekly.test.mjs:73-88` declares an `ALLOWED` set of 12 column names, then only asserts `!keys.has('skeleton_only')` — never that all 12 ALLOWED columns are *present*. Compare to the sibling `queries-decision-rollup.test.mjs:78-87` which correctly asserts `extra` columns (anything not in ALLOWED) are empty. The asymmetric assertion family (positive presence vs negative extras) is a useful checklist for any "shape contract" test:

- Extras must be empty: `Object.keys(row).filter(k => !ALLOWED.has(k))` deep-equals `[]`
- Required must be present: every member of `ALLOWED` is in `Object.keys(row)`
- Both, ideally — or just deep-equal the row against a contract object

## Vacuous-pass-via-internal-early-return

Distinct from the bats `vacuous-pass-via-source-failure` pattern in the 2026-04-19 learning. This is a node:test variant:

```js
describe('TP3.T4-A', { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {
  for (const val of OFF_VALUES) {
    it(`...val=${val}`, () => {
      if (!qualityGrader?.gradeDispatchEvents) return;  // <-- silent pass on missing export
      // ...assertions
    });
  }
});
```

Module exists, `IMPL_EXISTS=true`, describe runs — but the *named export* could be missing. The internal `if (!fn) return` silently passes the test. Fix: assert the export at module load (top-level `if (IMPL_EXISTS) { assert.ok(mod.gradeDispatchEvents) }`) so the whole file fails-loud rather than five subtests passing mute.

## Shell injection in test infra — low-risk but real

Five sites use `duckdb -c "$(cat '${SQL_PATH}')"`. Test-controlled paths today, but:
- macOS `os.tmpdir()` returns `/var/folders/...` (no quotes)
- Windows `os.tmpdir()` can contain spaces or apostrophes in user names
- SQL files routinely contain single quotes (the SQL string delimiter)

The `cat '${PATH}'` form is double-fragile. Cleaner alternatives:
1. Pass SQL via stdin: `execSync('duckdb -json', { input: sql })`
2. `spawnSync('duckdb', ['-json', '-c', sql, eventsPath], { shell: false })` — no shell at all
3. Use the duckdb node SDK directly

This is the same family as the `_lib.sh` deploy-script gate from 2026-04-19 — "test infra runs unsanitized substitution" is a recurring smell across the repo.

## Auth-lane verification — clean on personal concern

`scripts/reviewer-auth.sh --lane senna gh api user --jq .login` returns `strawberry-reviewers-2` immediately (no fallback to Lucian's lane). Branch is in personal concern (strawberry-agents, not missmp/*), so the cross-repo collaborator gap from PR #62 / PR #109 (work-concern) does not apply here. Standard formal-review path works.

## Time

~50 min total — ~15 min reading 15 test files, ~10 min cross-checking with the plan §Test plan tasks, ~15 min drafting the review body, ~5 min review submit + closeout. Slightly long because the bundle is unusually large (3430 additions) and the test files were dense.
